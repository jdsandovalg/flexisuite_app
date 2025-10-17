import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:flexisuite_shared/flexisuite_shared.dart';
import '../models/app_state.dart';
import 'package:table_calendar/table_calendar.dart'; // Importamos el nuevo paquete de calendario
import '../services/log_service.dart'; // Importar el servicio de logs
import '../models/amenity_model.dart';

class AmenityReservationPage extends StatefulWidget {
  const AmenityReservationPage({super.key});

  @override
  _AmenityReservationPageState createState() => _AmenityReservationPageState();
}

class _AmenityReservationPageState extends State<AmenityReservationPage> {
  bool _isLoading = true;
  List<Amenity> _amenities = [];
  List<Map<String, dynamic>> _myReservations = [];
  List<Map<String, dynamic>> _userProperties = [];
  String? _error;
  final LogService _logService = LogService(); // Instancia del servicio de logs

  // Estado para la vista seleccionada
  int _selectedViewIndex = 0; // 0: Reservar, 1: Mis Reservas

  // --- INICIO: Estado para el wizard de reserva ---
  int _reservationStep = 0; // 0: Calendario, 1: Detalles
  List<Map<String, dynamic>> _bookedReservationsForDay = [];
  bool _hasAcceptedTerms = false;
  // --- FIN: Estado para el wizard de reserva ---

  // Estado de la selección
  Amenity? _selectedAmenity;
  DateTime? _selectedDate;
  // Listas para las fechas ocupadas
  List<DateTime> _confirmedDates = [];
  List<DateTime> _pendingDates = [];

  final TextEditingController _eventNameController = TextEditingController();
  String? _selectedLocationId; // Cambiamos de user_location_fee_id a location_id
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  String? _timeValidationError;

  @override
  void initState() {
    super.initState();
    _fetchAmenities();
    _fetchMyReservations();
  }

  @override
  void dispose() {
    _eventNameController.dispose();
    super.dispose();
  }

  Future<void> _fetchAmenities() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final user = AppState.currentUser;
      if (user == null) throw Exception('Usuario no autenticado.');

      final response = await Supabase.instance.client.rpc(
        'get_amenities_for_organization',
        params: {'p_organization_id': user.organizationId},
      );

      if (mounted) {
        final amenitiesList = (response as List)
            .map((data) => Amenity.fromJson(data as Map<String, dynamic>))
            .toList();
        setState(() {
          // Solo cargamos las propiedades del usuario si aún no se han cargado.
          // Esto evita la duplicación de datos.
          if (_userProperties.isEmpty) {
            _fetchUserProperties();
          }
          _amenities = amenitiesList;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Error al cargar las amenidades: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _fetchUserProperties() async {
    try {
      final user = AppState.currentUser;
      if (user == null) throw Exception('Usuario no autenticado.');

      final response = await Supabase.instance.client.rpc(
        'get_user_properties',
        params: {
          'p_user_id': user.id,
          'p_organization_id': user.organizationId, // Añadimos el filtro de organización
        },
      );

      // --- INICIO: Log para depurar la carga de propiedades ---
      _logService.log('Respuesta de get_user_properties: $response');
      // --- FIN: Log ---

      if (mounted) {
        final properties = List<Map<String, dynamic>>.from(response);
        setState(() {
          _logService.log('Número de propiedades encontradas: ${properties.length}');
          _userProperties = properties;
          // Si solo hay una propiedad, la pre-seleccionamos.
          if (properties.length == 1) { 
            _selectedLocationId = properties.first['location_id'];
          }
        });
      }
    } catch (e) {
      if (mounted) {
        _logService.log('Error en _fetchUserProperties: $e');
        setState(() {
          _error = 'Error al cargar las propiedades del usuario: $e';
        });
      }
    }
  }

  Future<void> _fetchMyReservations() async {
    try {
      final user = AppState.currentUser;
      if (user == null) return;

      final response = await Supabase.instance.client.rpc(
        'manage_amenity_reservation',
        params: {
          'p_action': 'read',
          'p_user_id': user.id,
          // Pasamos null al resto de parámetros para que la firma coincida
          'p_amenity_id': null, 'p_start': null, 'p_end': null,
          'p_user_location_fee_id': null, 'p_event_name': null,
        },
      );

      if (mounted) {
        setState(() {
          _myReservations = List<Map<String, dynamic>>.from(response);
        });
      }
    } catch (e) {
      _logService.log('Error al cargar mis reservas: $e');
    }
  }

  Future<void> _fetchBookedDates(String amenityId) async {
    try {
      final response = await Supabase.instance.client.rpc(
        'get_booked_dates_for_amenity',
        params: {'p_amenity_id': amenityId},
      );

      // --- INICIO: Log para depurar fechas ocupadas ---
      _logService.log('Respuesta de get_booked_dates_for_amenity: $response');
      // --- FIN: Log ---

      if (mounted && response is List) {
        final confirmed = <DateTime>[];
        final pending = <DateTime>[];
        for (var item in response) {
          // Ahora usamos 'start_datetime' y lo convertimos a solo fecha para el marcador.
          final date = DateTime.parse(item['start_datetime']).toLocal();
          final dateOnly = DateTime(date.year, date.month, date.day);
          if (item['status'] == 'confirmed') {
            confirmed.add(dateOnly);
          } else if (item['status'] == 'pending') {
            pending.add(dateOnly);
          }
        }
        setState(() {
          _confirmedDates = confirmed;
          _pendingDates = pending;
          _logService.log('Fechas confirmadas cargadas: $_confirmedDates');
          _logService.log('Fechas pendientes cargadas: $_pendingDates');
        });
      }
    } catch (e) {
      _logService.log('Error al cargar fechas ocupadas: $e');
    }
  }

  void _updateBookedReservationsForDay(DateTime date) {
    final dateOnly = DateTime(date.year, date.month, date.day);
    final bookings = _myReservations
        .where((res) {
          final resDate = DateTime.parse(res['start_datetime']).toLocal();
          final resDateOnly = DateTime(resDate.year, resDate.month, resDate.day);
          return res['amenity_id'] == _selectedAmenity?.id &&
                 resDateOnly == dateOnly &&
                 (res['status'] == 'pending' || res['status'] == 'confirmed');
        })
        .toList();

    setState(() => _bookedReservationsForDay = bookings);
  }

  Future<void> _cancelReservation(String reservationId) async {
    final shouldCancel = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Cancelación'),
        content: const Text('¿Estás seguro de que deseas cancelar esta reserva?'),
        actions: [
          // La acción destructiva (cancelar) es un TextButton a la izquierda.
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
            child: const Text('Sí, Cancelar'),
          ),
          // La acción segura (No) es un ElevatedButton a la derecha, que recibe el foco por defecto.
          ElevatedButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('No')),
        ],
      ),
    );

    if (shouldCancel != true) return;

    setState(() => _isLoading = true);
    try {
      await Supabase.instance.client.rpc(
        'manage_amenity_reservation',
        params: {
          'p_action': 'cancel',
          'p_reservation_id': reservationId,
          // Pasamos null al resto de parámetros
          'p_amenity_id': null, 'p_user_id': null, 'p_start': null, 'p_end': null,
          'p_user_location_fee_id': null, 'p_event_name': null,
        },
      );
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reserva cancelada.'), backgroundColor: Colors.green));
      await _fetchMyReservations();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al cancelar la reserva: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _confirmReservation() async {
    // Añadimos la validación para la propiedad seleccionada
    // --- INICIO: Log de depuración para la validación ---
    _logService.log('--- Validando campos para la reserva ---');
    _logService.log('Amenidad seleccionada: ${_selectedAmenity?.name ?? 'null'}');
    _logService.log('Fecha seleccionada: ${_selectedDate?.toIso8601String() ?? 'null'}');
    _logService.log('Hora de inicio: ${_startTime?.format(context) ?? 'null'}');
    _logService.log('Hora de fin: ${_endTime?.format(context) ?? 'null'}');
    _logService.log('ID de propiedad seleccionada: ${_selectedLocationId ?? 'null'}');
    _logService.log('Nombre del evento: "${_eventNameController.text}" (está vacío: ${_eventNameController.text.isEmpty})');
    _logService.log('-----------------------------------------');
    // --- FIN: Log de depuración ---

    if (_selectedAmenity == null || _selectedDate == null || _startTime == null || _endTime == null || _selectedLocationId == null || _eventNameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Por favor, complete todos los campos.')));
      return;
    }

    final startDateTime = DateTime(_selectedDate!.year, _selectedDate!.month, _selectedDate!.day, _startTime!.hour, _startTime!.minute);
    final endDateTime = DateTime(_selectedDate!.year, _selectedDate!.month, _selectedDate!.day, _endTime!.hour, _endTime!.minute);

    if (endDateTime.isBefore(startDateTime)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('La hora de fin no puede ser anterior a la de inicio.')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = AppState.currentUser!;
      final params = {
        'p_action': 'create',
        'p_amenity_id': _selectedAmenity!.id,
        'p_user_id': user.id,
        'p_start': startDateTime.toIso8601String(),
        'p_end': endDateTime.toIso8601String(),
        'p_user_location_fee_id': _selectedLocationId, // Enviamos el ID de la propiedad
        'p_event_name': _eventNameController.text,
      };

      // --- INICIO: Log para depuración ---
      _logService.log('Llamando a RPC "manage_amenity_reservation" con parámetros: $params');
      // --- FIN: Log para depuración ---

      // --- INICIO: Log para depuración ---
      _logService.log('Llamando a RPC "manage_amenity_reservation" con parámetros: $params');
      // --- FIN: Log para depuración ---

      await Supabase.instance.client.rpc(
        'manage_amenity_reservation',
        params: params,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡Reserva creada con éxito! Se ha generado el cargo correspondiente.'),
            backgroundColor: Colors.green,
          ),
        );
        // Resetear el estado para permitir una nueva reserva
        setState(() {
          _selectedAmenity = null;
          _selectedDate = null;
          _eventNameController.clear();
          _selectedLocationId = _userProperties.length == 1 ? _userProperties.first['location_id'] : null;
          _startTime = null;
          _endTime = null;
          _isLoading = false;
          _hasAcceptedTerms = false;
          _reservationStep = 0; // Volvemos al primer paso
          _fetchMyReservations(); // Refrescamos la lista de "Mis Reservas"
        });
      }
    } catch (e) {
      // --- INICIO: Log para depuración del error ---
      _logService.log('Error al confirmar la reserva: ${e.toString()}');
      if (e is PostgrestException) {
        _logService.log('Detalles del error de Postgrest: code=${e.code}, message=${e.message}, details=${e.details}, hint=${e.hint}');
      }
      // --- FIN: Log para depuración del error ---

      // --- INICIO: Log para depuración del error ---
      _logService.log('Error al confirmar la reserva: ${e.toString()}');
      if (e is PostgrestException) {
        _logService.log('Detalles del error de Postgrest: code=${e.code}, message=${e.message}, details=${e.details}, hint=${e.hint}');
      }
      // --- FIN: Log para depuración del error ---

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: SelectableText('Error al crear la reserva: $e'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  void _onAmenitySelected(Amenity amenity) {
    setState(() {
      if (_selectedAmenity == amenity) {
        _selectedAmenity = null; // Si se toca de nuevo, se cierra
        _selectedDate = null;
        _hasAcceptedTerms = false;
        _reservationStep = 0;
        _confirmedDates.clear();
        _pendingDates.clear();
      } else {
        _selectedAmenity = amenity;
        _selectedDate = DateTime.now(); // Establecemos la fecha de hoy por defecto
        _eventNameController.clear();
        _selectedLocationId = _userProperties.length == 1 ? _userProperties.first['location_id'] : null;
        _hasAcceptedTerms = false;
        _fetchBookedDates(amenity.id); // Cargamos las fechas ocupadas para esta amenidad
      }
      _startTime = null;
      _endTime = null; 
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AppBackground(
        child: Stack(
          children: [
            _buildContent(),
            _buildAppBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Positioned(
      top: 40,
      left: 0,
      right: 0,
      child: Row(
        children: [ 
          IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.of(context).pop()),
          Expanded(
            child: Text(
              'Reservar Amenidad',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          const SizedBox(width: 48), // Espacio para balancear
        ],
      ),
    );
  }

  Widget _buildContent() {
    return Padding(
      padding: const EdgeInsets.only(top: 80.0), // Espacio para el AppBar
      child: Column(
        children: [
          FilterStrip(
            options: const ['Reservar', 'Mis Reservas'],
            selectedIndex: _selectedViewIndex,
            onSelected: (index) => setState(() => _selectedViewIndex = index),
          ),
          Expanded(
            child: IndexedStack(
              index: _selectedViewIndex,
              children: [
                _buildReservationCreationView(),
                _buildMyReservationsView(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- INICIO: Vistas para el IndexedStack ---

  Widget _buildReservationCreationView() {
    if (_isLoading && _amenities.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(child: Text(_error!));
    }
    if (_amenities.isEmpty) {
      return const Center(child: Text('No hay amenidades disponibles.'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _amenities.length,
      itemBuilder: (context, index) {
        final amenity = _amenities[index];
        final isSelected = _selectedAmenity == amenity;

        return GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- INICIO: Nuevo diseño de tarjeta de amenidad ---
              InkWell(
                onTap: () => _onAmenitySelected(amenity),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(child: Text(amenity.name, style: Theme.of(context).textTheme.titleMedium)),
                          Text('Q${amenity.pricePerBase.toStringAsFixed(0)}', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Horas incluidas'),
                          Text('${amenity.includedHours}', style: const TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Capacidad'),
                          Text('${amenity.capacity ?? 'N/A'}p', style: const TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              // --- FIN: Nuevo diseño ---
              if (isSelected) _buildExpandedView(amenity),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMyReservationsView() {
    if (_myReservations.isEmpty) {
      return const Center(child: Text('No tienes ninguna reserva.'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _myReservations.length,
      itemBuilder: (context, index) {
        final reservation = _myReservations[index];
        return _buildMyReservationCard(reservation);
      },
    );
  }

  Widget _buildMyReservationCard(Map<String, dynamic> reservation) {
    final theme = Theme.of(context);
    final eventName = reservation['event_name'] ?? 'Sin Nombre';
    final amenityName = _amenities.firstWhere((a) => a.id == reservation['amenity_id'], orElse: () => Amenity(id: '', organizationId: '', name: 'Amenidad Desconocida', includedHours: 0, pricePerBase: 0, amenityType: '', feeId: '')).name;
    final startDateTime = DateTime.parse(reservation['start_datetime']);
    final endDateTime = DateTime.parse(reservation['end_datetime']);
    final date = DateFormat('dd/MM/yyyy').format(startDateTime);
    final startTime = DateFormat('HH:mm').format(startDateTime);
    final endTime = DateFormat('HH:mm').format(endDateTime);
    final status = reservation['status'] as String? ?? 'pending';

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  eventName,
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              _buildStatusChip(status),
            ],
          ),
          const Divider(height: 16),
          Text('Amenidad: $amenityName'),
          Text('Fecha: $date de $startTime a $endTime'),
          const SizedBox(height: 4),
          Text(
            'Costo Total: Q${(reservation['total_amount'] as num? ?? 0).toStringAsFixed(2)}',
            style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          // Aquí podemos añadir los botones de acción en el futuro
          if (status == 'pending')
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (_isLoading) const CircularProgressIndicator() else
                TextButton(
                  onPressed: () {
                    final reservationId = reservation['reservation_id'] as String?;
                    if (reservationId != null) _cancelReservation(reservationId);
                  },
                  style: TextButton.styleFrom(foregroundColor: theme.colorScheme.error),
                  child: const Text('Cancelar'),
                ),
              ],
            ),
        ],
      ),
    );
  }

  // --- FIN: Vistas para el IndexedStack ---

  Widget _buildExpandedView(Amenity amenity) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(top: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(),
          if (amenity.description != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
              child: Text(amenity.description!, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
            ),
          // --- INICIO: Nueva sección de información y términos ---
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (amenity.pricePerExtraHour != null)
                  Text('Precio por hora extra: Q${amenity.pricePerExtraHour!.toStringAsFixed(2)}'),
                if (amenity.formattedUnavailableHours != null)
                  Text(amenity.formattedUnavailableHours!),
              ],
            ),
          ),
          CheckboxListTile(
            title: const Text('Acepto las condiciones del reglamento interno'),
            value: _hasAcceptedTerms,
            onChanged: (value) {
              setState(() {
                _hasAcceptedTerms = value ?? false;
              });
            },
            controlAffinity: ListTileControlAffinity.leading,
          ),
          // El wizard solo se muestra si se aceptan los términos
          if (_hasAcceptedTerms)
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              // --- INICIO: Lógica para la transición horizontal ---
              transitionBuilder: (Widget child, Animation<double> animation) {
                // Determina si el nuevo widget es el paso 2
                final isStep2 = child.key == const ValueKey('step2');
                // El offset inicial: desde la derecha si es el paso 2, desde la izquierda si es el paso 1.
                final begin = isStep2 ? const Offset(1.0, 0.0) : const Offset(-1.0, 0.0);
                const end = Offset.zero;
                final tween = Tween(begin: begin, end: end).chain(CurveTween(curve: Curves.easeInOut));
                final offsetAnimation = animation.drive(tween);

                return SlideTransition(
                  position: offsetAnimation,
                  child: child,
                );
              },
              // --- FIN: Lógica para la transición horizontal ---
              child: _reservationStep == 0
                  ? _buildStep1CalendarView(isDarkMode)
                  : _buildStep2DetailsView(),
            ),
          // --- FIN: Wizard de dos pasos ---
        ],
      ),
    );
  }

  // --- INICIO: Pasos del Wizard de Reserva ---

  void _validateSelectedTime() {
    if (_selectedAmenity == null || (_startTime == null && _endTime == null)) {
      setState(() => _timeValidationError = null);
      return;
    }

    final from = _selectedAmenity!.availableFromTime;
    final to = _selectedAmenity!.availableToTime;

    if (from != null && _startTime != null) {
      final startTimeDouble = _startTime!.hour + _startTime!.minute / 60.0;
      final fromDouble = from.hour + from.minute / 60.0;
      if (startTimeDouble < fromDouble) {
        setState(() => _timeValidationError = 'La hora de inicio no puede ser antes de las ${from.format(context)}.');
        return;
      }
    }

    if (to != null && _endTime != null) {
      final endTimeDouble = _endTime!.hour + _endTime!.minute / 60.0;
      final toDouble = to.hour + to.minute / 60.0;
      if (endTimeDouble > toDouble) {
        setState(() => _timeValidationError = 'La hora de fin no puede ser después de las ${to.format(context)}.');
        return;
      }
    }
    setState(() => _timeValidationError = null);
  }

  Widget _buildStep1CalendarView(bool isDarkMode) {
    return Column(
      key: const ValueKey('step1'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text('1. Selecciona Fecha y Hora', style: Theme.of(context).textTheme.titleMedium),
        ),
        _buildCalendar(isDarkMode),
        const SizedBox(height: 8),
        _buildBookedHoursList(),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildTimePicker('Inicio', _startTime, (time) {
                setState(() => _startTime = time);
                _validateSelectedTime();
              }),
              _buildTimePicker('Fin', _endTime, (time) {
                setState(() => _endTime = time);
                _validateSelectedTime();
              }),
            ],
          ),
        ),
        if (_timeValidationError != null)
          Padding(padding: const EdgeInsets.all(8.0), child: Text(_timeValidationError!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: (_selectedDate != null && _startTime != null && _endTime != null && _timeValidationError == null)
                  ? () => setState(() => _reservationStep = 1)
                  : null,
              child: const Text('Siguiente'),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStep2DetailsView() {
    return Column(
      key: const ValueKey('step2'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text('2. Completa los Detalles', style: Theme.of(context).textTheme.titleMedium),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _eventNameController,
                decoration: const InputDecoration(
                  labelText: 'Nombre del Evento',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(vertical: 12, horizontal: 16), // Hacemos el campo más compacto
                ),
                validator: (v) => v == null || v.isEmpty ? 'Obligatorio' : null,
              ),
              const SizedBox(height: 16),
              _buildPropertySelector(),
            ],
          ),
        ),
        if (_startTime != null && _endTime != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: _buildCostSummary(),
          ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Row(
            children: [
              // El botón "Atrás" ahora es un TextButton para que sea una acción secundaria.
              TextButton(
                onPressed: () => setState(() => _reservationStep = 0),
                child: const Text('Atrás'),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _confirmReservation,
                icon: _isLoading ? const SizedBox.shrink() : const Icon(Icons.check_circle_outline),
                label: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('Confirmar Reserva'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // --- FIN: Pasos del Wizard de Reserva ---

  Widget _buildCalendar(bool isDarkMode) {
    final theme = Theme.of(context);
    return TableCalendar(
      locale: 'es_ES', // Usamos español
      calendarFormat: CalendarFormat.week, // Mostramos solo una semana
      firstDay: DateTime.now().subtract(const Duration(days: 1)),
      lastDay: DateTime.now().add(const Duration(days: 90)),
      focusedDay: _selectedDate ?? DateTime.now(),
      selectedDayPredicate: (day) => isSameDay(_selectedDate, day),
      onDaySelected: (selectedDay, focusedDay) {
        setState(() {
          _selectedDate = selectedDay;
          _updateBookedReservationsForDay(selectedDay);
        });
      },
      // --- INICIO: Lógica para mostrar marcadores de eventos ---
      eventLoader: (day) {
        final dateOnly = DateTime(day.year, day.month, day.day);
        final events = [];
        if (_confirmedDates.contains(dateOnly)) events.add('confirmed'); // Marcador para confirmadas
        if (_pendingDates.contains(dateOnly)) events.add('pending'); // Marcador para pendientes
        return events;
      },
      // --- FIN: Lógica para mostrar marcadores de eventos ---
      calendarBuilders: CalendarBuilders(
        // Usamos el builder correcto para los marcadores
        markerBuilder: (context, date, events) {
          if (events.isNotEmpty) {
            return Positioned(
              right: 1,
              bottom: 1,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: events.map((event) {
                  return Container(
                    width: 6,
                    height: 6,
                    margin: const EdgeInsets.symmetric(horizontal: 0.5),
                    decoration: BoxDecoration(
                      color: event == 'confirmed' ? theme.colorScheme.error : theme.colorScheme.secondary,
                      shape: BoxShape.circle,
                    ),
                  );
                }).toList(),
              ),
            );
          }
          return null;
        },
      ),
      calendarStyle: CalendarStyle(
        selectedDecoration: BoxDecoration(
          color: theme.colorScheme.primary,
          shape: BoxShape.circle,
        ),
        todayDecoration: BoxDecoration(
          color: theme.colorScheme.primary.withOpacity(0.5),
          shape: BoxShape.circle,
        ),
      ),
      headerStyle: HeaderStyle(
        formatButtonVisible: false, // Ocultamos el botón de formato (semana/mes)
        titleCentered: true,
        titleTextStyle: theme.textTheme.titleMedium!,
      ),
    );
  }

  Widget _buildPropertySelector() {
    return DropdownButtonFormField<String>(
      isExpanded: true, // Evita el desbordamiento de texto largo.
      // --- INICIO: Lógica mejorada para el valor y el hint ---
      initialValue: _userProperties.any((p) => p['location_id'] == _selectedLocationId)
          ? _selectedLocationId
          : null,
      hint: _userProperties.isEmpty
          ? const Text('Cargando propiedades...')
          : const Text('Selecciona una propiedad'),
      // --- FIN: Lógica mejorada ---
      decoration: const InputDecoration(
        labelText: 'Asignar cargo a la propiedad',
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(vertical: 12, horizontal: 16), // Hacemos el campo más compacto
      ),
      items: _userProperties.map((prop) {
        return DropdownMenuItem(
          value: prop['location_id'] as String,
          child: Builder(builder: (context) {
            // --- INICIO: Lógica para acortar el texto de la ruta ---
            final fullPath = prop['location_path'] as String? ?? '';
            final parts = fullPath.split(' / ');
            // Mostramos las últimas 2 partes de la ruta si hay más de 2.
            final shortPath = parts.length > 2
                ? parts.sublist(parts.length - 2).join(' / ')
                : fullPath;
            return Text(shortPath, overflow: TextOverflow.ellipsis);
            // --- FIN: Lógica para acortar el texto ---
          }),
        );
      }).toList(),
      onChanged: _userProperties.isEmpty ? null : (value) => setState(() => _selectedLocationId = value),
      validator: (value) {
        if (_userProperties.isEmpty) return 'No hay propiedades para seleccionar.';
        if (value == null) return 'Debe seleccionar una propiedad.';
        return null;
      },
    );
  }

  Widget _buildBookedHoursList() {
    if (_bookedReservationsForDay.isEmpty) {
      return const SizedBox.shrink(); // No mostrar nada si no hay reservas
    }
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Horarios ocupados para este día:', style: theme.textTheme.bodySmall),
          const SizedBox(height: 4),
          ..._bookedReservationsForDay.map((res) {
            final start = DateFormat('HH:mm').format(DateTime.parse(res['start_datetime']).toLocal());
            final end = DateFormat('HH:mm').format(DateTime.parse(res['end_datetime']).toLocal());
            final status = res['status'] == 'confirmed' ? 'Confirmado' : 'Pendiente';
            return Text(
              '• $start - $end ($status)',
              style: theme.textTheme.bodyMedium?.copyWith(color: res['status'] == 'confirmed' ? theme.colorScheme.error : theme.colorScheme.secondary),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildTimePicker(String label, TimeOfDay? time, ValueChanged<TimeOfDay> onTimeChanged) {
    return Column(
      children: [
        Text(label),
        const SizedBox(height: 4), // Reducimos el espacio
        ElevatedButton(
          onPressed: () async {
            final pickedTime = await showTimePicker(
              context: context,
              initialTime: time ?? TimeOfDay.now(),
            );
            if (pickedTime != null) {
              onTimeChanged(pickedTime);
            }
          },
          // Hacemos el botón más compacto
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          child: Text(time?.format(context) ?? 'Elegir'),
        ),
      ],
    );
  }

  Widget _buildCostSummary() {
    final amenity = _selectedAmenity!;
    final start = DateTime(0, 1, 1, _startTime!.hour, _startTime!.minute);
    final end = DateTime(0, 1, 1, _endTime!.hour, _endTime!.minute);
    final duration = end.difference(start);

    if (duration.isNegative) {
      return const Text('La hora de fin debe ser posterior a la de inicio.', style: TextStyle(color: Colors.red));
    }

    final reservedHours = (duration.inMinutes / 60).ceil();
    final extraHours = (reservedHours - amenity.includedHours).clamp(0, 24);
    final extraHourCost = amenity.pricePerExtraHour ?? 0.0;
    final totalAmount = amenity.pricePerBase + (extraHours * extraHourCost);

    return GlassCard(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Resumen del Costo', style: Theme.of(context).textTheme.titleMedium, textAlign: TextAlign.center),
          const Divider(),
          _buildSummaryRow('Horas reservadas:', '$reservedHours'),
          _buildSummaryRow('Horas incluidas:', '${amenity.includedHours}'),
          _buildSummaryRow('Horas extra:', '$extraHours'),
          const Divider(),
          _buildSummaryRow(
            'Total a Pagar:',
            'Q${totalAmount.toStringAsFixed(2)}',
            isTotal: true,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isTotal = false}) {
    final style = isTotal
        ? Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold)
        : Theme.of(context).textTheme.bodyMedium;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          Text(value, style: style),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    String label;
    switch (status) {
      case 'confirmed':
        color = Colors.green.withOpacity(0.2);
        label = 'Confirmada';
        break;
      case 'cancelled':
        color = Colors.red.withOpacity(0.2);
        label = 'Cancelada';
        break;
      case 'pending':
      default:
        color = Colors.orange.withOpacity(0.2);
        label = 'Pendiente';
        break;
    }
    return Chip(
      label: Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
      backgroundColor: color,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      visualDensity: VisualDensity.compact,
    );
  }
}
