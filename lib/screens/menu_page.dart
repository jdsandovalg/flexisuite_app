import 'package:flutter/material.dart';
import '../models/app_state.dart';
import '../providers/theme_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // Import Supabase
import 'package:flexisuite_shared/flexisuite_shared.dart'; // Importar para AnimatedMenu
import 'profile_screen.dart';
import 'token_form_page.dart';
import 'incident_form_page.dart';
import 'fee_payment_report_page.dart';
import 'amenity_reservation_page.dart'; // Importar la nueva pantalla de reservas
import 'community_events_page.dart'; // Importar la nueva pantalla de eventos
import 'settings_screen.dart'; // Importar la nueva pantalla de ajustes
import 'package:font_awesome_flutter/font_awesome_flutter.dart'; // Importar para los iconos
import '../services/log_service.dart'; // Importar el servicio de logs
import 'package:provider/provider.dart';

class MenuPage extends StatefulWidget {
  const MenuPage({super.key}); // No longer requires features in constructor

  @override
  State<MenuPage> createState() => _MenuPageState();
}

class _MenuPageState extends State<MenuPage> {
  List<Map<String, dynamic>> _features = [];
  bool _isLoading = true;
  bool _hasError = false; // Nuevo estado para manejar errores de carga
  // --- INICIO: Estado para la superposición de funcionalidades bloqueadas ---
  bool _isLockedFeatureOverlayVisible = false;
  Map<String, dynamic>? _selectedLockedFeature;
  // --- FIN: Estado para la superposición ---
  final LogService _logService = LogService(); // Instancia del servicio de logs

  // Mapa estático y COMPLETO que traduce el 'icon_name' de la base de datos
  // al objeto IconData que Flutter necesita. Este es nuestro "traductor" oficial.
  static final Map<String, IconData> _iconMap = {
    // Users
    'user': FontAwesomeIcons.user,
    'userCircle': FontAwesomeIcons.userCircle,
    'solidUserCircle': FontAwesomeIcons.solidUserCircle,
    'users': FontAwesomeIcons.users,
    'idCard': FontAwesomeIcons.idCard,
    'addressBook': FontAwesomeIcons.addressBook,
    'userGroup': FontAwesomeIcons.userGroup,
    'userTie': FontAwesomeIcons.userTie,
    'idBadge': FontAwesomeIcons.idBadge,
    // Finance
    'fileInvoiceDollar': FontAwesomeIcons.fileInvoiceDollar,
    'moneyBillWave': FontAwesomeIcons.moneyBillWave,
    'creditCard': FontAwesomeIcons.creditCard,
    'receipt': FontAwesomeIcons.receipt,
    'buildingColumns': FontAwesomeIcons.buildingColumns,
    'piggyBank': FontAwesomeIcons.piggyBank,
    'fileInvoice': FontAwesomeIcons.fileInvoice,
    // Access
    'qrcode': FontAwesomeIcons.qrcode,
    'ticket': FontAwesomeIcons.ticket,
    'key': FontAwesomeIcons.key,
    'doorOpen': FontAwesomeIcons.doorOpen,
    'doorClosed': FontAwesomeIcons.doorClosed,
    // UI & Actions
    'gears': FontAwesomeIcons.gears,
    'wrench': FontAwesomeIcons.wrench,
    'bell': FontAwesomeIcons.bell,
    'solidBell': FontAwesomeIcons.solidBell,
    'exclamationTriangle': FontAwesomeIcons.exclamationTriangle,
    'shieldHalved': FontAwesomeIcons.shieldHalved,
    'plus': FontAwesomeIcons.plus,
    'trash': FontAwesomeIcons.trash,
    'penToSquare': FontAwesomeIcons.penToSquare,
    'infoCircle': FontAwesomeIcons.infoCircle,
    'questionCircle': FontAwesomeIcons.questionCircle,
    'circleInfo': FontAwesomeIcons.circleInfo,
    'circleQuestion': FontAwesomeIcons.circleQuestion,
    'magnifyingGlass': FontAwesomeIcons.magnifyingGlass,
    'sliders': FontAwesomeIcons.sliders,
    'arrowRightFromBracket': FontAwesomeIcons.arrowRightFromBracket,
    // Events
    'calendarDays': FontAwesomeIcons.calendarDays,
    'users': FontAwesomeIcons.users, // Para 'Community_Events'
    'champagneGlasses': FontAwesomeIcons.champagneGlasses, // Para 'Hall_Reservations'
    'calendarCheck': FontAwesomeIcons.calendarCheck,
    // Places
    'mugSaucer': FontAwesomeIcons.mugSaucer,
    'building': FontAwesomeIcons.building,
    'car': FontAwesomeIcons.car,
    'locationDot': FontAwesomeIcons.locationDot,
    'mapPin': FontAwesomeIcons.mapPin,
    'route': FontAwesomeIcons.route,
    'personSwimming': FontAwesomeIcons.personSwimming,
    'dumbbell': FontAwesomeIcons.dumbbell,
    'tree': FontAwesomeIcons.tree,
    'peopleRoof': FontAwesomeIcons.peopleRoof,
    'personShelter': FontAwesomeIcons.personShelter,
    'squareParking': FontAwesomeIcons.squareParking,
    // Communication
    'comments': FontAwesomeIcons.comments,
    'paperPlane': FontAwesomeIcons.paperPlane,
    'phone': FontAwesomeIcons.phone,
    'bullhorn': FontAwesomeIcons.bullhorn,
    'envelope': FontAwesomeIcons.envelope,
    // Services
    'screwdriverWrench': FontAwesomeIcons.screwdriverWrench,
    'bolt': FontAwesomeIcons.bolt,
    'droplet': FontAwesomeIcons.droplet,
    'wifi': FontAwesomeIcons.wifi,
    'truckFast': FontAwesomeIcons.truckFast,
    // Health
    'heartPulse': FontAwesomeIcons.heartPulse,
    'briefcaseMedical': FontAwesomeIcons.briefcaseMedical,
    'houseMedical': FontAwesomeIcons.houseMedical,
    // Default
    'noIcon': FontAwesomeIcons.questionCircle,
  };

  @override
  void initState() {
    super.initState();
    _fetchFeatures(); // Ahora solo llamamos a una función
  }

  Future<void> _fetchFeatures() async {
    if (mounted) setState(() {
      _isLoading = true;
      _hasError = false; // Reseteamos el error al reintentar
    });

    final user = AppState.currentUser;
    if (user == null) {
      // Handle case where user is not logged in (should not happen if SplashScreen works)
      _logService.log('Error en _fetchFeatures: Usuario es nulo. No se pueden cargar características.');
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      const rpcName = 'get_user_plan_features';
      final params = {'p_user_id': user.id};
      _logService.log('Llamando a RPC: $rpcName con parámetros: $params');

      final response = await Supabase.instance.client.rpc(rpcName, params: params);

      // Log para depurar la lista de características recibidas
      _logService.log('Características recibidas de get_user_plan_features: ${response.toString()}');

      if (response != null && response is List) {
        setState(() {
          _features = List<Map<String, dynamic>>.from(response);
          AppState.userFeatures = _features; // Guardamos las características en el estado global.
          _hasError = false;
          _isLoading = false;
        });
      } else {
        _logService.log('Advertencia: La respuesta de $rpcName no fue una lista o fue nula.');
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (error) {
      _logService.log('Error crítico al llamar a RPC "get_user_plan_features". Error: ${error.toString()}');
      if (error is PostgrestException) {
        _logService.log('Detalles del error de Postgrest: code=${error.code}, message=${error.message}, details=${error.details}, hint=${error.hint}');
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error crítico al cargar menú: $error')),
        );
        setState(() {
          _hasError = true; // Marcamos que hubo un error
          _isLoading = false; // Dejamos de cargar para mostrar el estado de error
        });
      }
    }
  }

  // Mapa de rutas para una navegación más limpia y escalable.
  // Asocia un feature_code con la pantalla a la que debe navegar.
  static final Map<String, WidgetBuilder> _featureRoutes = {
    'token_create_simple': (context) => const TokenFormPage(),
    'ticket_create': (context) => const IncidentFormPage(),
    'cuota_reportar_pago': (context) => const FeePaymentReportPage(),
    // --- Añade aquí nuevas rutas a medida que implementes más pantallas ---
    'Hall_Reservations': (context) => const AmenityReservationPage(),
    'Community_Events': (context) => const CommunityEventsPage(),
  };

  @override
  Widget build(BuildContext context) {
    final user = AppState.currentUser;

    // Transformamos la lista de features para añadir el widget del ícono y el color
    final menuItems = _features
        .where((f) => f['is_menu_item'] == true)
        .map((feature) {
          final iconName = feature['icon_name'] as String?;
          final colorCode = feature['color_hex_code'] as String?;
          final isLocked = feature['value'] == 'locked';
          final iconColor = _colorFromHex(colorCode);
          final featureCode = feature['feature_code'] as String?;

          // Asignamos el ícono basado en el feature_code si el icon_name es nulo o no está en el mapa.
          final iconData = _iconMap[iconName] ?? _iconMap[featureCode] ?? FontAwesomeIcons.questionCircle;
          // El ícono ahora siempre es el correcto, pero se atenúa si está bloqueado.
          final finalIconWidget = FaIcon(iconData, size: 22, color: isLocked ? iconColor.withOpacity(0.5) : iconColor);


          return {
            ...feature,
            'icon': finalIconWidget, // El ícono ahora siempre es el correcto, solo cambia el color.
            'color': iconColor,
          };
        }).toList();

    return AppBackground(
      child: Stack( // Usamos un Stack para poder mostrar la capa de información superpuesta
        children: [
          Scaffold(
            backgroundColor: Colors.transparent,
            body: _buildBody(),
            bottomNavigationBar: _isLoading || _hasError ? null : _buildBottomNavBar(menuItems),
          ),
          // --- INICIO: Lógica de superposición mejorada ---
          // Capa 2: Oscurece el fondo cuando la tarjeta está visible.
          if (_isLockedFeatureOverlayVisible)
            // Usamos un GestureDetector que cubre toda la pantalla para detectar toques fuera de la tarjeta.
            // El Container es transparente, cumpliendo con la instrucción de "no opacar nada".
            GestureDetector( 
              onTap: _hideLockedFeatureOverlay,
              child: Container(color: Colors.transparent, child: _buildLockedFeatureCard()),
            ),
          // --- FIN: Lógica de superposición mejorada ---
        ],
      ),
    );
  }

  // --- INICIO: Métodos de construcción de UI refactorizados ---

  Widget _buildBody() {
    if (_isLoading) {
      return _buildLoading();
    }
    if (_hasError) {
      return _buildError();
    }
    return _buildMenu();
  }

  Widget _buildLoading() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 20),
          Text('Cargando menú...'),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: Colors.redAccent, size: 60),
          const SizedBox(height: 20),
          const Text('No se pudo cargar el menú', style: TextStyle(fontSize: 18)),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            icon: const Icon(Icons.refresh),
            label: const Text('Reintentar'),
            onPressed: _fetchFeatures,
          ),
        ],
      ),
    );
  }

  Widget _buildMenu() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset('assets/logo.png', height: 80),
          const SizedBox(height: 24),
          const Text(
            'Bienvenido',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNavBar(List<Map<String, dynamic>> menuItems) {
    final user = AppState.currentUser;
    if (menuItems.isEmpty) return const SizedBox.shrink();

    return Material(
      elevation: 8.0,
      color: Colors.transparent,
      child: GlassCard(
        margin: EdgeInsets.zero,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            ...menuItems.map((item) => Flexible(child: _buildNavBarItem(item))),
            Flexible(child: _buildProfilePopupMenu(user)),
          ],
        ),
      ),
    );
  }

  Widget _buildNavBarItem(Map<String, dynamic> item) {
    final iconWidget = item['icon'] as Widget;
    final isLocked = item['value'] == 'locked';
    final featureCode = item['feature_code'] as String;
    final featureName = item['feature_name'] as String;
    final shortDescription = item['short_description'] as String?;

    // Reemplazamos el FloatingActionButton por un widget más flexible.
    return Tooltip(
      message: featureName,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () {
          if (isLocked) {
            setState(() {
              _selectedLockedFeature = item;
              _isLockedFeatureOverlayVisible = true;
            });
          } else {
            final pageBuilder = _featureRoutes[featureCode];
            if (pageBuilder != null) {
              Navigator.push(context, MaterialPageRoute(builder: pageBuilder));
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Funcionalidad "$featureName" no implementada.')),
              );
            }
          }
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              iconWidget,
              if (shortDescription != null && shortDescription.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  shortDescription,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 8),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfilePopupMenu(UserModel? user) {
    return PopupMenuButton<String>(
      color: Theme.of(context).colorScheme.surface.withOpacity(0.95),
      tooltip: 'Más opciones',
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      onSelected: (value) => _onPopupMenuItemSelected(value),
      itemBuilder: (context) => _buildPopupMenuItems(context, user),
      child: const Padding(
        padding: EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [Icon(Icons.more_vert), SizedBox(height: 4), Text('Más', style: TextStyle(fontSize: 8))],
        ),
      ),
    );
  }

  // --- FIN: Métodos de construcción de UI refactorizados ---

  // --- INICIO: Widgets y métodos para la tarjeta informativa ---

  void _hideLockedFeatureOverlay() {
    setState(() {
      _isLockedFeatureOverlayVisible = false;
      _selectedLockedFeature = null;
    });
  }

  Widget _buildLockedFeatureCard() {
    if (_selectedLockedFeature == null) return const SizedBox.shrink();

    // Manejamos la posible errata en el nombre del campo 'locket_cta'
    final ctaText = _selectedLockedFeature!['locket_cta'] ?? _selectedLockedFeature!['locked_cta'] ?? '¡Desbloquéalo ahora!';

    return Center(
      child: GestureDetector(
        onTap: () {}, // Evita que el toque en la tarjeta la cierre.
        child: GlassCard(
          margin: const EdgeInsets.symmetric(horizontal: 24),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min, // La tarjeta se ajusta al contenido
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                _selectedLockedFeature!['locked_title'] ?? 'Funcionalidad Bloqueada',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const Divider(height: 32),
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.3),
                child: SingleChildScrollView(
                  child: Text(
                    _selectedLockedFeature!['locked_body'] ?? 'Esta funcionalidad no está disponible en tu plan actual. Contacta a soporte para más información.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(ctaText, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }

  // --- FIN: Widgets y métodos para la tarjeta informativa ---

  List<PopupMenuEntry<String>> _buildPopupMenuItems(BuildContext context, UserModel? user) {
    return <PopupMenuEntry<String>>[
      if (user != null) ...[
        PopupMenuItem<String>(
          enabled: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                user.name,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface,
                    ),
              ),
              Text(
                user.organizationName,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.7),
                    ),
              ),
            ],
          ),
        ),
        const PopupMenuDivider(),
      ],
      PopupMenuItem<String>(
        value: 'profile',
        child: Row(
          children: [
            Icon(Icons.account_circle,
                color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 12),
            Text(
              'Editar Perfil',
              style: TextStyle(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface),
            ),
          ],
        ),
      ),
      PopupMenuItem<String>(
        value: 'settings',
        child: Row(
          children: [
            Icon(Icons.color_lens,
                color:
                    Theme.of(context).colorScheme.secondary),
            const SizedBox(width: 12),
            Text(
              'Ajustes',
              style: TextStyle(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface),
            ),
          ],
        ),
      ),
      const PopupMenuDivider(),
      PopupMenuItem<String>(
        value: 'logout',
        child: Row(
          children: [
            const Icon(Icons.logout, color: Colors.redAccent),
            const SizedBox(width: 12),
            Text(
              'Cerrar Sesión',
              style: TextStyle(
                  color: Colors.redAccent),
            ),
          ],
        ),
      ),
    ];
  }

  void _onPopupMenuItemSelected(String value) async {
    switch (value) {
      case 'profile':
        Navigator.push(context, MaterialPageRoute(builder: (context) => const ProfileScreen()));
        break;
      case 'settings':
        _showSettingsModal();
        break;
      case 'logout':
        AppState.currentUser = null;
        await Supabase.instance.client.auth.signOut();
        if (context.mounted) {
          Navigator.of(context).pushReplacementNamed('/login');
        }
        break;
    }
  }

  void _showSettingsModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Permite que el contenido determine la altura
      backgroundColor: Colors.transparent, // Fondo transparente para que GlassCard funcione
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.4, // Altura inicial (40% de la pantalla)
        minChildSize: 0.2, // Altura mínima
        maxChildSize: 0.6, // Altura máxima
        expand: false,
        builder: (_, scrollController) => const GlassCard(
          child: SettingsScreen(),
        ),
      ),
    );
  }

  // Función auxiliar para convertir el código hexadecimal en un objeto Color
  Color _colorFromHex(String? hexCode) => Color(int.parse((hexCode ?? '#FFFFFF').replaceAll('#', 'FF'), radix: 16));
}
