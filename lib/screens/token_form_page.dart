import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timezone/timezone.dart' as tz; // Importar para manejo de zonas horarias
import '../models/app_state.dart';
import 'package:flexisuite_shared/flexisuite_shared.dart';
import 'token_detail_screen.dart';
import '../services/log_service.dart';
import '../widgets/guest_list_modal.dart'; // Importar el nuevo modal

class TokenFormPage extends StatefulWidget {
  const TokenFormPage({super.key});

  @override
  _TokenFormPageState createState() => _TokenFormPageState();
}

class _TokenFormPageState extends State<TokenFormPage> {
  final _formKey = GlobalKey<FormState>();

  // Campos del formulario
  String _tokenType = 'Individual';
  String _name = '';
  String _cui = '';
  String _eventName = '';
  DateTime? _eventDate;
  TimeOfDay? _eventStartTime;
  TimeOfDay? _eventEndTime;
  List<String> _services = [];
  int _validityHours = 6;
  TimeOfDay? _recurrentStart;
  TimeOfDay? _recurrentEnd;
  DateTime? _recurrentStartDate;
  DateTime? _recurrentEndDate;
  String? _selectedServiceCategory;
  List<Map<String, String>> _eventGuests = [];

  List<dynamic> _tokens = []; // Lista de tokens creados
  bool _isLoading = true;
  final LogService _logService = LogService(); // Instancia del servicio de logs

  // Estado para el filtro de tokens
  int _selectedFilterIndex = 0; // 0: Vigentes, 1: Historial

  // Servicios básicos actualizados
  final Map<String, List<String>> serviceCategories = {
    'Telefonía': ['Tigo', 'Claro'], 
    'Energía/Agua': ['Energuate', 'Empresa Eléctrica','Agua Municipal'],
  };

  // Etiquetas para los tipos de token para mantener la lógica intacta.
  final Map<String, String> _tokenTypeLabels = {
    'Individual': 'Individual',
    'Servicios Básicos': 'Servicios',
    'Recurrente': 'Recurrente',
    'Eventos': 'Eventos',
  };

  @override
  void initState() {
    super.initState();
    _fetchTokens();
  }

  Future<void> _fetchTokens() async {
    final user = AppState.currentUser;
    if (user == null) return;

    _logService.log('Fetching tokens for user: ${user.id}, org: ${user.organizationId}');
    try {
      final response = await Supabase.instance.client.rpc(
        'get_tokens_json',
        params: {
          'p_user_id': user.id,
          'p_organization_id': user.organizationId,
        },
      );

      _logService.log('Received tokens response: ${response.toString()}');
      if (response == null || response is! List) {
        setState(() {
          _tokens = [];
          _isLoading = false;
        });
        return;
      }

      setState(() {
        _tokens = response;
        _isLoading = false;
      });
    } catch (error) {
      _logService.log('Error fetching tokens: $error');
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar los tokens: $error')));
      setState(() {
        _isLoading = false;
      });
    }
  }

  void showQR(String token) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('QR del Token'),
        content: QrImageView(
          data: token,
          version: QrVersions.auto,
          size: 180.0,
          embeddedImage: const AssetImage('assets/logo.png'),
          embeddedImageStyle: const QrEmbeddedImageStyle(size: Size(24, 24)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cerrar')),
        ],
      ),
    );
  }

  void copyToken(String token) {
    Clipboard.setData(ClipboardData(text: token));
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Token copiado al portapapeles')));
  }

  Future<void> saveToken() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      final user = AppState.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Error: Usuario no autenticado')));
        return;
      }

      // Para los tokens de eventos, construimos la fecha de expiración exacta.
      String? finalExpiresAt;
      if (_tokenType == 'Eventos' && _eventDate != null && _eventStartTime != null && _eventEndTime != null) {
        // 1. Obtener la zona horaria de la organización
        final orgLocation = tz.getLocation(AppState.organizationTimeZone);

        // 2. Crear la fecha y hora de fin del evento en la zona horaria de la organización
        final eventEndDateTimeInOrgZone = tz.TZDateTime(
          orgLocation,
          _eventDate!.year, _eventDate!.month, _eventDate!.day,
          _eventEndTime!.hour, _eventEndTime!.minute,
        );
        // 3. Convertir a UTC antes de enviar a la base de datos
        finalExpiresAt = eventEndDateTimeInOrgZone.toUtc().toIso8601String();
      } else if (_tokenType == 'Individual' || _tokenType == 'Servicios Básicos') {
        // Para tokens individuales/servicios, calculamos la expiración desde ahora en la zona horaria de la organización.
        final orgLocation = tz.getLocation(AppState.organizationTimeZone);
        final expiresAtInOrgZone = tz.TZDateTime.now(orgLocation).add(Duration(hours: _validityHours));
        finalExpiresAt = expiresAtInOrgZone.toUtc().toIso8601String();
      }

      final params = {
        'p_organization_id': user.organizationId,
        'p_user_id': user.id,
        'p_token_type': _tokenType,
        'p_guest_id': _tokenType == 'Servicios Básicos' ? _name : _cui,
        'p_guest_name': _name,
        'p_is_recurring': _tokenType == 'Recurrente',
        'p_daily_start': _recurrentStart != null ? '${_recurrentStart!.hour}:${_recurrentStart!.minute}' : null,
        'p_daily_end': _recurrentEnd != null ? '${_recurrentEnd!.hour}:${_recurrentEnd!.minute}' : null,
        'p_recurring_start_date': _recurrentStartDate?.toIso8601String(),
        'p_recurring_end_date': _recurrentEndDate?.toIso8601String(),
        'p_validity_hours': (_tokenType == 'Individual' || _tokenType == 'Servicios Básicos') ? _validityHours : null,
        'p_expires_at': finalExpiresAt, // Enviamos la fecha de expiración exacta.
        'p_max_accesses': _tokenType == 'Eventos' ? _eventGuests.length : 1, // Usamos la longitud de la lista de invitados
        'p_event_name': _tokenType == 'Eventos' ? _eventName : null,
        // Enviamos la lista directamente. El cliente de Supabase se encarga de serializarla a JSONB.
        'p_guests_json': _tokenType == 'Eventos' ? _eventGuests : null
      };

      try {
        _logService.log('Enviando parámetros a create_token_1a1: ${jsonEncode(params)}');
        await Supabase.instance.client.rpc('create_token_1a1', params: params);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Token para "${_tokenType == 'Eventos' ? _eventName : _name}" guardado exitosamente.')),
        );

        // --- INICIO: Lógica de reseteo del formulario ---
        setState(() {
          _formKey.currentState?.reset();
          _name = '';
          _cui = '';
          _eventName = '';
          _eventGuests.clear();
          _selectedServiceCategory = null;
          _services.clear();
        });
        _fetchTokens(); // Refresca la lista de tokens
        // --- FIN: Lógica de reseteo ---
      } catch (e) {
        _logService.log('Error al guardar el token: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: SelectableText('Error al guardar el token: $e')));
        }
      }
    }
  }

  Future<void> _showGuestManagementModal() async {
    await showDialog(
      context: context,
      builder: (_) => GuestListModal(
        // Pasamos la lista actual de invitados al modal.
        guests: _eventGuests,
        // Cuando el modal se confirma, actualizamos la lista principal.
        onConfirm: (updatedGuests) => setState(() => _eventGuests = updatedGuests),
      ),
    );
  }

  Widget _buildTokenTypeSelector() {
    final theme = Theme.of(context);

    // Buscamos la característica 'token_event' en el estado global.
    final eventFeature = AppState.userFeatures.firstWhere(
      (feature) => feature['feature_code'] == 'token_event',
      orElse: () => {'value': 'locked'}, // Si no se encuentra, se asume que está bloqueada.
    );
    final bool isEventFeatureUnlocked = eventFeature['value'] == 'unlocked';

    return Wrap(
      spacing: 8.0,
      runSpacing: 8.0,
      children: _tokenTypeLabels.entries.map((entry) {
        final type = entry.key;
        final label = entry.value;
        bool isSelected = _tokenType == type;

        // El botón "Eventos" se habilita solo si la característica está desbloqueada.
        final bool isButtonEnabled = (type == 'Eventos' && !isEventFeatureUnlocked) ? false : true;

        return ElevatedButton(
          onPressed: isButtonEnabled ? () {
            setState(() {
              _tokenType = type;
              // Si se selecciona "Eventos", inicializamos los valores de fecha y hora.
              if (type == 'Eventos') {
                _eventDate ??= DateTime.now();
                _eventStartTime ??= const TimeOfDay(hour: 0, minute: 0);
                _eventEndTime ??= const TimeOfDay(hour: 23, minute: 59);
              }
            });
          } : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: isSelected ? theme.colorScheme.primary : theme.colorScheme.surface.withOpacity(0.5),
            foregroundColor: isSelected ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            textStyle: theme.textTheme.bodySmall, // Usamos una fuente más pequeña
          ),
          child: Text(label),
        );
      }).toList(),
    );
  }

  Widget _buildValiditySelector() {
    final theme = Theme.of(context);
    return Wrap(
      spacing: 8.0,
      runSpacing: 8.0,
      children: [6, 12, 18, 24].map((hours) {
        bool isSelected = _validityHours == hours;
        return ElevatedButton(
          onPressed: () => setState(() => _validityHours = hours),
          style: ElevatedButton.styleFrom(
            backgroundColor: isSelected ? theme.colorScheme.primary : theme.colorScheme.surface.withOpacity(0.5),
            foregroundColor: isSelected ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            textStyle: theme.textTheme.bodySmall,
          ),
          child: Text('$hours horas'),
        );
      }).toList(),
    );
  }

  Widget _buildServiceCategorySelector() {
    final theme = Theme.of(context);
    return Wrap(
      spacing: 8.0,
      runSpacing: 8.0,
      children: serviceCategories.keys.map((category) {
        bool isSelected = _selectedServiceCategory == category;
        return ElevatedButton(
          onPressed: () => setState(() => _selectedServiceCategory = category),
          style: ElevatedButton.styleFrom(
            backgroundColor: isSelected ? theme.colorScheme.primary : theme.colorScheme.surface.withOpacity(0.5),
            foregroundColor: isSelected ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            textStyle: theme.textTheme.bodySmall,
          ),
          child: Text(category),
        );
      }).toList(),
    );
  }

  Widget _buildServiceSelector(String category) {
    final theme = Theme.of(context);
    return Wrap(
      spacing: 8.0,
      runSpacing: 8.0,
      children: serviceCategories[category]!.map((service) {
        bool isSelected = _services.contains(service);
        return ElevatedButton(
          onPressed: () {
            setState(() {
              _services = [service]; // Mutually exclusive
            });
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: isSelected ? theme.colorScheme.primary : theme.colorScheme.surface.withOpacity(0.5),
            foregroundColor: isSelected ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            textStyle: theme.textTheme.bodySmall,
          ),
          child: Text(service),
        );
      }).toList(),
    );
  }

  Widget _buildTokenGrid() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    final activeStatuses = ['green', 'orange', 'yellow'];
    final filteredTokens = _selectedFilterIndex == 0
        ? _tokens.where((t) => activeStatuses.contains(t['status_color'])).toList()
        : _tokens.where((t) => !activeStatuses.contains(t['status_color'])).toList();

    if (filteredTokens.isEmpty) {
      return Center(
        child: Text(_selectedFilterIndex == 0
            ? 'No tienes tokens vigentes.'
            : 'No hay historial de tokens.'),
      );
    }

    // Volvemos a un GridView con altura fija (mainAxisExtent) para garantizar estabilidad.
    return LayoutBuilder(
      builder: (context, constraints) {
        int crossAxisCount = constraints.maxWidth > 450 ? 2 : 1;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            mainAxisExtent: 260, // Altura fija y generosa para cada tarjeta
          ),
          itemCount: filteredTokens.length,
          itemBuilder: (context, index) => _buildTokenCard(filteredTokens[index]),
        );
      },
    );
  }

  Widget _buildTokenCard(Map<String, dynamic> token) {
    // Leemos el parámetro desde el estado global de la aplicación.
    final bool allowQrCodeDisplay = AppState.organizationParameters['ALLOW_QR_CODE_DISPLAY'] ?? false;

    String startDate = 'N/A';
    String endDate = 'N/A';

    if (token['is_recurring'] == true) {
      startDate = token['recurring_start_date'] != null
          ? '${DateFormat('dd/MM/yy').format(DateTime.parse(token['recurring_start_date']))} ${token['daily_start'] ?? ''}'
          : 'N/A';
      endDate = token['recurring_end_date'] != null
          ? '${DateFormat('dd/MM/yy').format(DateTime.parse(token['recurring_end_date']))} ${token['daily_end'] ?? ''}'
          : 'N/A';
    } else if (token['created_at'] != null) {
      final startDateTime = DateTime.parse(token['created_at'] as String);
      startDate = DateFormat('dd/MM/yy HH:mm').format(startDateTime);
      final validityHours = token['validity_hours'] as int? ?? 0;
      endDate = validityHours > 0
          ? DateFormat('dd/MM/yy HH:mm').format(startDateTime.add(Duration(hours: validityHours)))
          : 'N/A';
    }

    token['formatted_start_date'] = startDate;
    token['formatted_end_date'] = endDate;

    return GestureDetector(
      // --- INICIO: Lógica condicional para la navegación ---
      onTap: allowQrCodeDisplay
          ? () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => TokenDetailScreen(tokenData: token)),
              )
          : null, // Si es false, la tarjeta no es presionable.
      // --- FIN: Lógica condicional ---
      child: GlassCard(
        margin: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        token['guest_name'] ?? token['event_name'] ?? 'N/A',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        token['token_type'],
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                _buildStatusChip(token['status_color'] as String?),
              ],
            ),
            const Spacer(),
            // --- INICIO: Lógica condicional simple ---
            if (allowQrCodeDisplay)
              Center(
                child: QrImageView(
                  data: token['token_code'],
                  version: QrVersions.auto,
                  size: 100.0, // Tamaño original restaurado
                  embeddedImage: const AssetImage('web/favicon.png'),
                  embeddedImageStyle: const QrEmbeddedImageStyle(size: Size(20, 20)),
                ),
              ),
            const Spacer(),
            Center(
              child: SelectableText(
                token['token_code'],
                // Si el QR no se muestra, hacemos el texto más grande para ocupar el espacio.
                style: allowQrCodeDisplay
                    ? Theme.of(context).textTheme.bodyMedium?.copyWith(fontFamily: 'monospace')
                    : Theme.of(context).textTheme.headlineSmall?.copyWith(fontFamily: 'monospace', fontWeight: FontWeight.bold),
              ),
            ),
            const Divider(height: 20),
            Center(
              child: TextButton.icon(
                onPressed: () => copyToken(token['token_code']),
                icon: const Icon(Icons.copy, size: 16),
                label: const Text('Copiar Token'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(String? statusColor) {
    Color color;
    String label;
    switch (statusColor) {
      case 'green':
        color = AppColors.tokenActive.withOpacity(0.2);
        label = 'Activo';
        break;
      case 'orange':
      case 'yellow':
        color = AppColors.tokenExpiring.withOpacity(0.2);
        label = 'Expirando';
        break;
      case 'red':
        color = AppColors.tokenExpired.withOpacity(0.2);
        label = 'Expirado';
        break;
      case 'gray':
      default:
        color = AppColors.tokenRevoked.withOpacity(0.2);
        label = 'Usado/Revocado';
        break;
    }
    return Chip(
      label: Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold)),
      backgroundColor: color,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      visualDensity: VisualDensity.compact,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent, // Fondo transparente para que se vea el AppBackground
      body: AppBackground(
        child: Stack( // Usamos un Stack para superponer el título y el botón de atrás
          children: [
            // El contenido principal de la pantalla
            Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 600),
                child: SingleChildScrollView(
                  // Añadimos un padding superior para que el contenido no quede debajo del título flotante
                  padding: const EdgeInsets.fromLTRB(16.0, 80.0, 16.0, 16.0),
                  child: Column(
                    children: [
                      GlassCard(
                        child: Form(
                          key: _formKey,
                          child: Column(
                            children: [
                              _buildTokenTypeSelector(),
                              const SizedBox(height: 20),
                              if (_tokenType == 'Individual') ...[
                                TextFormField(
                                  decoration: const InputDecoration(labelText: 'Nombre del invitado'),
                                  validator: (val) => val == null || val.isEmpty ? 'Obligatorio' : null,
                                  onSaved: (val) => _name = val!,
                                ),
                                const SizedBox(height: 10),
                                TextFormField(
                                  decoration: const InputDecoration(labelText: 'CUI (DPI)'),
                                  validator: (val) => val == null || val.isEmpty ? 'Obligatorio' : null,
                                  onSaved: (val) => _cui = val!,
                                ),
                                const SizedBox(height: 10),
                                _buildValiditySelector(),
                              ],
                              if (_tokenType == 'Servicios Básicos') ...[
                                _buildServiceCategorySelector(),
                                if (_selectedServiceCategory != null) ...[
                                  const SizedBox(height: 10),
                                  _buildServiceSelector(_selectedServiceCategory!),
                                ],
                                const SizedBox(height: 10),
                                TextFormField(
                                  decoration: const InputDecoration(labelText: 'Nombre del contacto'),
                                  validator: (val) => val == null || val.isEmpty ? 'Obligatorio' : null,
                                  onSaved: (val) => _name = val!,
                                ),
                                const SizedBox(height: 10),
                              ],
                              if (_tokenType == 'Recurrente') ...[
                                const SizedBox(height: 10),
                                TextFormField(
                                  decoration: const InputDecoration(labelText: 'Nombre del contacto'),
                                  validator: (val) => val == null || val.isEmpty ? 'Obligatorio' : null,
                                  onSaved: (val) => _name = val!,
                                ),
                                const SizedBox(height: 10),
                                TextFormField(
                                  decoration: const InputDecoration(labelText: 'CUI (DPI)'),
                                  validator: (val) => val == null || val.isEmpty ? 'Obligatorio' : null,
                                  onSaved: (val) => _cui = val!,
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Expanded(
                                      child: InputDatePickerFormField(
                                        firstDate: DateTime.now(),
                                        lastDate: DateTime.now().add(const Duration(days: 365)),
                                        fieldLabelText: 'Fecha inicio',
                                        initialDate: _recurrentStartDate ?? DateTime.now(),
                                        onDateSaved: (val) => _recurrentStartDate = val,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: InputDatePickerFormField(
                                        firstDate: DateTime.now(),
                                        lastDate: DateTime.now().add(const Duration(days: 365)),
                                        fieldLabelText: 'Fecha fin',
                                        initialDate: _recurrentEndDate ?? DateTime.now(),
                                        onDateSaved: (val) => _recurrentEndDate = val,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextFormField(
                                        readOnly: true,
                                        decoration: const InputDecoration(labelText: 'Hora inicio'),
                                        onTap: () async {
                                          TimeOfDay? time = await showTimePicker(
                                            context: context,
                                            initialTime: TimeOfDay.now(),
                                          );
                                          if (time != null) setState(() => _recurrentStart = time);
                                        },
                                        controller: TextEditingController(
                                            text: _recurrentStart?.format(context) ?? ''),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: TextFormField(
                                        readOnly: true,
                                        decoration: const InputDecoration(labelText: 'Hora fin'),
                                        onTap: () async {
                                          TimeOfDay? time = await showTimePicker(
                                            context: context,
                                            initialTime: TimeOfDay.now(),
                                          );
                                          if (time != null) setState(() => _recurrentEnd = time);
                                        },
                                        controller: TextEditingController(
                                            text: _recurrentEnd?.format(context) ?? ''),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                              if (_tokenType == 'Eventos') ...[
                                TextFormField(
                                  decoration: const InputDecoration(labelText: 'Nombre del Evento'),
                                  validator: (val) => val == null || val.isEmpty ? 'El nombre del evento es obligatorio' : null,
                                  onSaved: (val) => _eventName = val!,
                                ),
                                const SizedBox(height: 10),
                                InputDatePickerFormField(
                                  firstDate: DateTime.now(),
                                  lastDate: DateTime.now().add(const Duration(days: 365)),
                                  fieldLabelText: 'Fecha del Evento',
                                  initialDate: _eventDate ?? DateTime.now(),
                                  onDateSaved: (val) => _eventDate = val,
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextFormField(
                                        readOnly: true,
                                        decoration: const InputDecoration(labelText: 'Hora inicio'),
                                        onTap: () async {
                                          TimeOfDay? time = await showTimePicker(context: context, initialTime: _eventStartTime ?? const TimeOfDay(hour: 0, minute: 0));
                                          if (time != null) setState(() => _eventStartTime = time);
                                        },
                                        controller: TextEditingController(text: (_eventStartTime ?? const TimeOfDay(hour: 0, minute: 0)).format(context)),
                                        validator: (val) => _eventStartTime == null ? 'Hora de inicio obligatoria' : null,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: TextFormField(
                                        readOnly: true,
                                        decoration: const InputDecoration(labelText: 'Hora fin'),
                                        onTap: () async {
                                          TimeOfDay? time = await showTimePicker(context: context, initialTime: _eventEndTime ?? const TimeOfDay(hour: 23, minute: 59));
                                          if (time != null) setState(() => _eventEndTime = time);
                                        },
                                        controller: TextEditingController(text: (_eventEndTime ?? const TimeOfDay(hour: 23, minute: 59)).format(context)),
                                        validator: (val) => _eventEndTime == null ? 'Hora de fin obligatoria' : null,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 20),
                                ElevatedButton.icon(
                                  onPressed: _showGuestManagementModal,
                                  icon: const Icon(Icons.upload_file),
                                  label: Text(
                                    _eventGuests.isEmpty ? 'Agregar Invitados' : 'Ver/Editar Lista (${_eventGuests.length} invitados)'
                                  ),
                                  style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.secondary),
                                )
                              ],
                              const SizedBox(height: 20),
                              ElevatedButton(
                                onPressed: _isLoading ? null : saveToken,
                                style: ElevatedButton.styleFrom(
                                  // Reducimos el padding para un botón más compacto
                                  padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 24.0),
                                ),
                                child: _isLoading
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                      )
                                    : const Text('Guardar Token'),
                                ),
                              const SizedBox(height: 20),
                            ],
                          ),
                        ),
                      ),
                      const Divider(height: 30),
                      FilterStrip(
                        options: const ['Vigentes', 'Historial'],
                        selectedIndex: _selectedFilterIndex,
                        onSelected: (index) {
                          setState(() {
                            _selectedFilterIndex = index;
                          });
                        },
                      ),
                      const SizedBox(height: 10),
                      // El GridView necesita estar dentro de un widget con altura definida.
                      // Usamos un Expanded dentro de un Column para darle el espacio restante.
                      // Como ya estamos en un SingleChildScrollView, esto no funcionará.
                      // La solución es no usar Expanded y dejar que el GridView tome su altura natural.
                      _buildTokenGrid(), 
                      const SizedBox(height: 50),
                    ],
                  ),
                ),
              ),
            ),
            // Título y botón de atrás superpuestos
            Positioned(
              top: 40,
              left: 0,
              right: 0,
              child: Row(
                children: [
                  IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.of(context).pop()),
                  Expanded(
                    child: Text(
                      'Crear Tokens de Ingreso',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  const SizedBox(width: 48), // Espacio para balancear el IconButton
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
