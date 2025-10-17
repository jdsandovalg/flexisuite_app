import 'package:flutter/material.dart';
import 'dart:async'; // Importar para usar Timer
import '../models/app_state.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // Import Supabase
import 'package:intl/intl.dart'; // Importar para formatear fechas
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
  // --- INICIO: Estado para el carrusel de eventos ---
  List<Map<String, dynamic>> _approvedEvents = [];
  PageController? _pageController;
  Timer? _carouselTimer;
  int _carouselIntervalSeconds = 5; // Valor por defecto si no se encuentra el parámetro
  int _currentPage = 0;
  // --- FIN: Estado para el carrusel de eventos ---

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
    _pageController = PageController()..addListener(() {
      // Escuchamos los cambios de página para actualizar los indicadores
      setState(() => _currentPage = _pageController?.page?.round() ?? 0);
    });
    _fetchFeatures().then((_) {
      // Solo si las características se cargaron correctamente, buscamos los eventos.
      if (!_hasError) {
        _fetchApprovedEvents();
      }
    });
  }

  @override
  void dispose() {
    _pageController?.dispose();
    _carouselTimer?.cancel();
    super.dispose();
  }

  void _startCarouselTimer() {
    _carouselTimer?.cancel(); // Cancelamos cualquier timer anterior
    if (_approvedEvents.length > 1 && mounted) {
      final totalPages = _approvedEvents.length + 1; // +1 por la página de bienvenida
      _carouselTimer = Timer.periodic(Duration(seconds: _carouselIntervalSeconds), (timer) {
        if (_pageController != null && _pageController!.hasClients) {
          int nextPage = (_pageController!.page!.round() + 1) % totalPages;
          _pageController!.animateToPage(
            nextPage,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeInOut,
          );
        }
      });
    }
  }

  Future<void> _fetchFeatures() async {
    if (mounted) {
      setState(() {
      _isLoading = true;
      _hasError = false; // Reseteamos el error al reintentar
    });
    }

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
          // Buscamos el parámetro del intervalo del carrusel
          final intervalFeature = _features.firstWhere(
            (f) => f['feature_code'] == 'MAX_SECONDS_INTERVAL',
            orElse: () => {},
          );
          final intervalValue = int.tryParse(intervalFeature['value']?.toString() ?? '');
          if (intervalValue != null && intervalValue > 0) {
            _carouselIntervalSeconds = intervalValue;
            _logService.log('Intervalo del carrusel configurado a: $_carouselIntervalSeconds segundos.');
          }
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

  Future<void> _fetchApprovedEvents() async {
    try {
      _logService.log('Llamando a RPC: manage_community_event con p_action: approved');
      final user = AppState.currentUser;
      if (user == null) return;

      final response = await Supabase.instance.client.rpc(
        'manage_community_event',
        params: {
          'p_action': 'approved',
          'p_organization_id': user.organizationId,
          'p_created_by': null, // Se envía null como lo requiere la firma
        },
      );

      if (mounted) {
        setState(() {
          _approvedEvents = List<Map<String, dynamic>>.from(response);
        });
        _logService.log('Eventos aprobados recibidos: ${_approvedEvents.length}');
        _startCarouselTimer(); // Iniciamos el timer si hay más de un evento
      }
    } catch (e) {
      _logService.log('Error al cargar eventos aprobados: $e');
      if (mounted) {
        // No mostramos un error en pantalla para no ser intrusivos, solo lo logueamos.
        // setState(() => _approvedEvents = []);
      }
    }
    // No manejamos isLoading aquí para que la carga sea en segundo plano.
  }

  Widget _buildApprovedEventCard(Map<String, dynamic> event) {
    final theme = Theme.of(context);
    final title = event['title'] as String? ?? 'Evento sin título';
    final imageUrl = event['location_image'] as String?;
    final startDateTime = event['start_datetime'] != null ? DateTime.parse(event['start_datetime']) : null;
    final endDateTime = event['end_datetime'] != null ? DateTime.parse(event['end_datetime']) : null;

    final dateStr = startDateTime != null
        ? DateFormat('dd MMM, yyyy', 'es_ES').format(startDateTime)
        : 'Fecha no disponible';
    final startTimeStr = startDateTime != null ? DateFormat('HH:mm', 'es_ES').format(startDateTime) : '--:--';
    final endTimeStr = endDateTime != null ? DateFormat('HH:mm', 'es_ES').format(endDateTime) : '--:--';

    return GlassCard(
      margin: const EdgeInsets.symmetric(horizontal: 8.0), // Margen para espaciar las tarjetas en la lista
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (imageUrl != null)
            Expanded(
              flex: 3, // Dar más espacio a la imagen
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                child: Image.network(
                  imageUrl,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => const Center(child: Icon(Icons.image_not_supported_outlined, size: 40)),
                ),
              ),
            ),
          Expanded(
            flex: 2, // Espacio para el texto
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold), maxLines: 2, overflow: TextOverflow.ellipsis),
                  const Spacer(),
                  Row(
                    children: [
                      Icon(Icons.calendar_today_outlined, size: 14, color: theme.textTheme.bodySmall?.color),
                      const SizedBox(width: 6),
                      Text(dateStr, style: theme.textTheme.bodySmall),
                      const Spacer(), // Empuja el texto de la hora hacia la derecha
                      Text('$startTimeStr - $endTimeStr hrs', style: theme.textTheme.bodySmall),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Renombrado para reflejar que ahora es un carrusel de información general
  Widget _buildInfoCarousel() {
    // El número total de páginas es la página de bienvenida + los eventos.
    final totalPages = _approvedEvents.length + 1;

    return SizedBox(
      height: 240, // Aumentamos ligeramente la altura para dar espacio a los indicadores
      child: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              itemCount: totalPages,
              itemBuilder: (context, index) {
                // Si es la primera página, muestra la bienvenida.
                if (index == 0) {
                  return _buildWelcomePage();
                }
                // Para las demás páginas, muestra las tarjetas de eventos.
                // Se resta 1 al índice porque la lista de eventos no incluye la bienvenida.
                return _buildApprovedEventCard(_approvedEvents[index - 1]);
              },
            ),
          ),
          // Mostramos los indicadores solo si hay más de una página en total.
          if (totalPages > 1) ...[
            const SizedBox(height: 12), // Reducimos el espaciado para corregir el overflow
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(totalPages, (index) {
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 4.0),
                  height: 8.0,
                  // El indicador activo es más ancho.
                  width: _currentPage == index ? 24.0 : 8.0,
                  decoration: BoxDecoration(
                    // El indicador activo es más opaco.
                    color: Theme.of(context).colorScheme.primary.withOpacity(_currentPage == index ? 0.9 : 0.4),
                    borderRadius: BorderRadius.circular(12),
                  ),
                );
              }),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildWelcomePage() {
    return GlassCard(
      margin: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
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
      // CORRECCIÓN: Reemplazamos la columna por una llamada al nuevo carrusel unificado.
      // La lógica de bienvenida ahora vivirá dentro de este carrusel.
      child: _buildInfoCarousel(),
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
