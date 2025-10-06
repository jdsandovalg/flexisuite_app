import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:flexisuite_shared/flexisuite_shared.dart';
import '../models/app_state.dart';
import 'package:table_calendar/table_calendar.dart';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import '../services/log_service.dart'; // Importar el servicio de logs

class CommunityEventsPage extends StatefulWidget {
  const CommunityEventsPage({Key? key}) : super(key: key);

  @override
  _CommunityEventsPageState createState() => _CommunityEventsPageState();
}

class _CommunityEventsPageState extends State<CommunityEventsPage> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _events = [];
  String? _error;
  final LogService _logService = LogService(); // Instancia del servicio de logs

  int _selectedViewIndex = 0; // 0: Mis Eventos, 1: Crear

  // --- INICIO: Estado para la creación de eventos ---
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _maxGuestsController = TextEditingController(text: '0');
  DateTime? _selectedEventDate;
  TimeOfDay? _selectedStartTime;
  TimeOfDay? _selectedEndTime;
  bool _isPublicEvent = true;
  int _creationStep = 0; // 0: Calendario, 1: Detalles, 2: Invitar
  List<Map<String, dynamic>> _eventsOnSelectedDate = [];
  Uint8List? _eventImageBytes;
  String? _eventImageName;
  // --- FIN: Estado para la creación de eventos ---
  // --- INICIO: Estado para invitar participantes ---
  List<Map<String, dynamic>> _invitees = [];
  Set<String> _selectedInvitees = {};
  String? _createdEventId; // Para guardar el ID del evento recién creado

  @override
  void initState() {
    super.initState();
    _fetchEvents();
  }

  Future<void> _fetchEvents() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final user = AppState.currentUser;
      if (user == null) throw Exception('Usuario no autenticado.');

      final response = await Supabase.instance.client.rpc(
        'manage_community_event',
        params: {
          'p_action': 'read',
          'p_organization_id': user.organizationId,
          // Pasamos null al resto de parámetros que no se usan en la acción 'read'
          'p_created_by': null,
        },
      );

      if (mounted) {
        setState(() {
          _events = List<Map<String, dynamic>>.from(response);
          _updateEventsOnSelectedDate(_selectedEventDate ?? DateTime.now());
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Error al cargar los eventos: $e';
          _isLoading = false;
        });
      }
    }
  }

  void _updateEventsOnSelectedDate(DateTime date) {
    final dateOnly = DateTime(date.year, date.month, date.day);
    final bookings = _events.where((event) {
      final eventDate = DateTime.parse(event['start_datetime']).toLocal();
      final eventDateOnly = DateTime(eventDate.year, eventDate.month, eventDate.day);
      return eventDateOnly == dateOnly;
    }).toList();
    setState(() => _eventsOnSelectedDate = bookings);
  }

  Future<void> _pickEventImage() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );

      if (result != null && result.files.first.bytes != null) {
        setState(() {
          _eventImageBytes = result.files.first.bytes!;
          _eventImageName = result.files.first.name;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al seleccionar la imagen: $e')));
      }
    }
  }

  Future<void> _createEventAndSendInvitations() async {
    if (_selectedEventDate == null || _selectedStartTime == null || _selectedEndTime == null || _titleController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Por favor, complete todos los campos obligatorios.')));
      return;
    }

    final startDateTime = DateTime(_selectedEventDate!.year, _selectedEventDate!.month, _selectedEventDate!.day, _selectedStartTime!.hour, _selectedStartTime!.minute);
    final endDateTime = DateTime(_selectedEventDate!.year, _selectedEventDate!.month, _selectedEventDate!.day, _selectedEndTime!.hour, _selectedEndTime!.minute);

    if (endDateTime.isBefore(startDateTime)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('La hora de fin no puede ser anterior a la de inicio.')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = AppState.currentUser!;
      String? imageUrl;

      // 1. Subir la imagen si existe
      if (_eventImageBytes != null && _eventImageName != null) {
        final fileExt = _eventImageName!.split('.').last;
        final filePath = 'community-events-images/${user.id}/${DateTime.now().millisecondsSinceEpoch}.$fileExt';
        
        await Supabase.instance.client.storage.from('community-events-images').uploadBinary(
          filePath,
          _eventImageBytes!,
          fileOptions: FileOptions(upsert: true, contentType: 'image/$fileExt'),
        );
        imageUrl = Supabase.instance.client.storage.from('community-events-images').getPublicUrl(filePath);
      }

      // 2. Llamar a la función RPC con la URL de la imagen (si se subió)
      final response = await Supabase.instance.client.rpc(
        'manage_community_event',
        params: {
          'p_action': 'create',
          'p_organization_id': user.organizationId,
          'p_created_by': user.id,
          'p_title': _titleController.text,
          'p_description': _descriptionController.text,
          'p_start_datetime': startDateTime.toIso8601String(),
          'p_end_datetime': endDateTime.toIso8601String(),
          'p_is_public': _isPublicEvent,
          'p_location_image': imageUrl,
          'p_maximum_guests': int.tryParse(_maxGuestsController.text) ?? 0,
        },
      );

      _logService.log('Respuesta de manage_community_event: $response');
      // Guardamos el ID del evento recién creado y avanzamos al siguiente paso
      if (mounted && response is List && response.isNotEmpty) {
        _createdEventId = response.first['event_id'];
        await _fetchInvitees();
        setState(() => _creationStep = 2);
      }

      if (mounted) {
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al crear el evento: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleEventCreationAndProceed() async {
    if (_selectedEventDate == null || _selectedStartTime == null || _selectedEndTime == null || _titleController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Por favor, complete todos los campos obligatorios.')));
      return;
    }

    final startDateTime = DateTime(_selectedEventDate!.year, _selectedEventDate!.month, _selectedEventDate!.day, _selectedStartTime!.hour, _selectedStartTime!.minute);
    final endDateTime = DateTime(_selectedEventDate!.year, _selectedEventDate!.month, _selectedEventDate!.day, _selectedEndTime!.hour, _selectedEndTime!.minute);

    if (endDateTime.isBefore(startDateTime)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('La hora de fin no puede ser anterior a la de inicio.')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = AppState.currentUser!;
      String? imageUrl;

      if (_eventImageBytes != null && _eventImageName != null) {
        final fileExt = _eventImageName!.split('.').last;
        final filePath = 'community-events-images/${user.id}/${DateTime.now().millisecondsSinceEpoch}.$fileExt';
        await Supabase.instance.client.storage.from('community-events-images').uploadBinary(
          filePath,
          _eventImageBytes!,
          fileOptions: FileOptions(upsert: true, contentType: 'image/$fileExt'),
        );
        imageUrl = Supabase.instance.client.storage.from('community-events-images').getPublicUrl(filePath);
      }

      final params = { 'p_action': 'create', 'p_organization_id': user.organizationId, 'p_created_by': user.id, 'p_title': _titleController.text, 'p_description': _descriptionController.text, 'p_start_datetime': startDateTime.toIso8601String(), 'p_end_datetime': endDateTime.toIso8601String(), 'p_is_public': _isPublicEvent, 'p_location_image': imageUrl, 'p_maximum_guests': int.tryParse(_maxGuestsController.text) ?? 0, };
      _logService.log('Llamando a manage_community_event con params: $params');

      final response = await Supabase.instance.client.rpc(
        'manage_community_event',
        params: {
          'p_action': 'create', 'p_organization_id': user.organizationId, 'p_created_by': user.id,
          'p_title': _titleController.text, 'p_description': _descriptionController.text,
          'p_start_datetime': startDateTime.toIso8601String(), 'p_end_datetime': endDateTime.toIso8601String(),
          'p_is_public': _isPublicEvent, 'p_location_image': imageUrl,
          'p_maximum_guests': int.tryParse(_maxGuestsController.text) ?? 0,
        },
      );

      if (mounted && response is List && response.isNotEmpty) {
        _createdEventId = response.first['event_id'];
        await _fetchInvitees();
        setState(() => _creationStep = 2);
      }
    } catch (e) {
      if (mounted) {
        _logService.log('Error en _handleEventCreationAndProceed: $e');
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al crear el evento: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchInvitees() async {
    try {
      final user = AppState.currentUser;
      if (user == null) return;

      final params = {'p_action': 'list_invitees', 'p_event_id': _createdEventId};
      _logService.log('Llamando a manage_community_event_participants con params: $params');

      final response = await Supabase.instance.client.rpc(
        'manage_community_event_participants',
        params: params,
      );
      _logService.log('Respuesta de list_invitees: $response');
      if (mounted) {
        setState(() => _invitees = List<Map<String, dynamic>>.from(response));
      }
    } catch (e) {
      if (mounted) {
        _logService.log('Error en _fetchInvitees: $e');
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al cargar la lista de invitados: $e')));
      }
    }
  }

  Future<void> _sendInvitationsAndFinish() async {
    if (_createdEventId == null) return;

    setState(() => _isLoading = true);
    try {
      if (_selectedInvitees.isNotEmpty) {
        final user = AppState.currentUser!;
        await Supabase.instance.client.rpc(
          'manage_community_event_participants',
          params: {
            'p_action': 'add',
            'p_event_id': _createdEventId,
            'p_user_ids': _selectedInvitees.toList(),
            'p_invited_by': user.id,
            'p_notes': '¡Hola! Te he invitado a ayudarme a organizar el evento "${_titleController.text}". ¿Te unes?',
          },
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Evento creado e invitaciones enviadas.'), backgroundColor: Colors.green));
        _resetCreationForm();
        await _fetchEvents();
      }
    } catch (e) {
      if (mounted) {
        _logService.log('Error en _sendInvitationsAndFinish: $e');
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al enviar invitaciones: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _resetCreationForm() {
    setState(() {
      _creationStep = 0;
      _titleController.clear();
      _descriptionController.clear();
      _maxGuestsController.text = '0';
      _selectedInvitees.clear();
      _createdEventId = null;
      _eventImageBytes = null;
      _eventImageName = null;
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
              'Eventos Comunitarios',
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
      padding: const EdgeInsets.only(top: 80.0),
      child: Column(
        children: [
          FilterStrip(
            options: const ['Mis Eventos', 'Crear'],
            selectedIndex: _selectedViewIndex,
            onSelected: (index) => setState(() => _selectedViewIndex = index),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(child: Text(_error!))
                    : _buildCurrentView(),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentView() {
    switch (_selectedViewIndex) {
      case 0:
        return _buildMyEventsView();
      case 1:
        return _buildCreateEventView();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildUpcomingEventsView() {
    // Filtramos solo los eventos públicos y confirmados
    final upcomingEvents = _events.where((e) => e['is_public'] == true && e['status'] == 'confirmed').toList();

    if (upcomingEvents.isEmpty) {
      return const Center(child: Text('No hay próximos eventos públicos.'));
    }
    
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: upcomingEvents.length,
      itemBuilder: (context, index) {
        final event = upcomingEvents[index];
        final startDate = DateFormat('dd MMM, yyyy').format(DateTime.parse(event['start_datetime']));
        final startTime = DateFormat('HH:mm').format(DateTime.parse(event['start_datetime']));
        final status = event['status'] as String? ?? 'pending';
        final statusText = status == 'confirmed' ? 'Confirmado' : (status == 'pending' ? 'Pendiente' : 'Cancelado');
        final statusColor = status == 'confirmed' ? Colors.green : (status == 'pending' ? Colors.orange : Colors.red);
        
        return GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (event['location_image'] != null)
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  child: Image.network(event['location_image'], height: 150, width: double.infinity, fit: BoxFit.cover),
                ),
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(event['title'], style: Theme.of(context).textTheme.titleLarge, overflow: TextOverflow.ellipsis),
                        ),
                        Chip(
                          label: Text(statusText, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                          backgroundColor: statusColor.withOpacity(0.2),
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text('Fecha: $startDate a las $startTime hrs'),
                    const SizedBox(height: 4),
                    Text(event['description'] ?? 'Sin descripción.', maxLines: 2, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMyEventsView() {
    final user = AppState.currentUser;
    if (user == null) return const Center(child: Text('Error de autenticación.'));

    final myEvents = _events.where((e) => e['created_by'] == user.id).toList();

    if (myEvents.isEmpty) {
      return const Center(child: Text('Aún no has creado ningún evento.'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: myEvents.length,
      itemBuilder: (context, index) {
        final event = myEvents[index];
        final startDate = DateFormat('dd MMM, yyyy').format(DateTime.parse(event['start_datetime']));
        final startTime = DateFormat('HH:mm').format(DateTime.parse(event['start_datetime']));
        final status = event['status'] as String? ?? 'pending';
        final statusText = status == 'confirmed' ? 'Confirmado' : (status == 'pending' ? 'Pendiente' : 'Cancelado');
        final statusColor = status == 'confirmed' ? Colors.green : (status == 'pending' ? Colors.orange : Colors.red);

        return GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (event['location_image'] != null)
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  child: Image.network(event['location_image'], height: 150, width: double.infinity, fit: BoxFit.cover),
                ),
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(event['title'], style: Theme.of(context).textTheme.titleLarge, overflow: TextOverflow.ellipsis),
                        ),
                        Chip(
                          label: Text(statusText, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                          backgroundColor: statusColor.withOpacity(0.2),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text('Fecha: $startDate a las $startTime hrs'),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCreateEventView() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      transitionBuilder: (Widget child, Animation<double> animation) {
        final isStep2 = child.key == const ValueKey('step2');
        final isStep3 = child.key == const ValueKey('step3');
        final begin = isStep2 || isStep3 ? const Offset(1.0, 0.0) : const Offset(-1.0, 0.0);
        const end = Offset.zero;
        final tween = Tween(begin: begin, end: end).chain(CurveTween(curve: Curves.easeInOut));
        return SlideTransition(position: animation.drive(tween), child: child);
      },
      child: _creationStep == 0 ? _buildStep1CalendarView() 
           : _creationStep == 1 ? _buildStep2DetailsView()
           : _buildStep3InviteView(),
    );
  }

  Widget _buildStep1CalendarView() {
    return SingleChildScrollView(
      key: const ValueKey('step1'),
      padding: const EdgeInsets.all(16),
      child: GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Paso 1: Selecciona Fecha y Hora', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            TableCalendar(
              locale: 'es_ES',
              calendarFormat: CalendarFormat.week,
              firstDay: DateTime.now().subtract(const Duration(days: 1)),
              lastDay: DateTime.now().add(const Duration(days: 365)),
              focusedDay: _selectedEventDate ?? DateTime.now(),
              selectedDayPredicate: (day) => isSameDay(_selectedEventDate, day),
              onDaySelected: (selectedDay, focusedDay) {
                setState(() {
                  _selectedEventDate = selectedDay;
                  _updateEventsOnSelectedDate(selectedDay);
                });
              },
              eventLoader: (day) => _events.where((e) => isSameDay(DateTime.parse(e['start_datetime']).toLocal(), day)).toList(),
            ),
            const SizedBox(height: 16),
            if (_eventsOnSelectedDate.isNotEmpty) ...[
              Text('Eventos para este día:', style: Theme.of(context).textTheme.bodySmall),
              ..._eventsOnSelectedDate.map((e) => Text('• ${e['title']} a las ${DateFormat('HH:mm').format(DateTime.parse(e['start_datetime']).toLocal())}')),
              const SizedBox(height: 16),
            ],
            Row(
              children: [
                Expanded(child: _buildTimePicker('Inicio', _selectedStartTime, (time) => setState(() => _selectedStartTime = time))),
                const SizedBox(width: 16),
                Expanded(child: _buildTimePicker('Fin', _selectedEndTime, (time) => setState(() => _selectedEndTime = time))),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: (_selectedEventDate != null && _selectedStartTime != null && _selectedEndTime != null && !_isLoading)
                    ? () => setState(() => _creationStep = 1)
                    : null,
                child: const Text('Siguiente'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep2DetailsView() {
    return SingleChildScrollView(
      key: const ValueKey('step2'),
      padding: const EdgeInsets.all(16),
      child: GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Paso 2: Detalles del Evento', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Título del Evento'),
              validator: (v) => v == null || v.isEmpty ? 'El título es obligatorio' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(labelText: 'Descripción (Opcional)'),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _maxGuestsController,
              decoration: const InputDecoration(labelText: 'Nº de Invitados Externos'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            // --- INICIO: Selector de imagen ---
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: _pickEventImage,
                  icon: const Icon(Icons.image_search),
                  label: const Text('Elegir Imagen'),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _eventImageName ?? 'Ninguna imagen seleccionada',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            // --- FIN: Selector de imagen ---
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Evento Público'),
              subtitle: const Text('Visible para todos en la comunidad.'),
              value: _isPublicEvent,
              onChanged: (value) => setState(() => _isPublicEvent = value),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                TextButton(onPressed: () => setState(() => _creationStep = 0), child: const Text('Atrás')),
                const Spacer(),
                ElevatedButton( // Ahora este botón avanza al paso 3
                  onPressed: _isLoading ? null : _handleEventCreationAndProceed,
                  child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('Siguiente'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep3InviteView() {
    return SingleChildScrollView(
      key: const ValueKey('step3'),
      padding: const EdgeInsets.all(16),
      child: GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Paso 3: Invitar Colaboradores (Opcional)', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            const Text('Selecciona a los residentes que te ayudarán a organizar el evento.'),
            const SizedBox(height: 16),
            if (_invitees.isEmpty)
              const Center(child: Text('No hay residentes con perfil público para invitar.'))
            else
              SizedBox(
                height: 300, // Altura fija para la lista
                child: ListView.builder(
                  itemCount: _invitees.length,
                  itemBuilder: (context, index) {
                    final invitee = _invitees[index];
                    final userId = invitee['user_id'] as String;
                    final isSelected = _selectedInvitees.contains(userId);
                    return CheckboxListTile(
                      title: Text(invitee['user_name'] ?? 'Usuario sin nombre'),
                      value: isSelected,
                      onChanged: (bool? value) {
                        setState(() {
                          if (value == true) {
                            _selectedInvitees.add(userId);
                          } else {
                            _selectedInvitees.remove(userId);
                          }
                        });
                      },
                    );
                  },
                ),
              ),
            const SizedBox(height: 24),
            Row(
              children: [
                TextButton(onPressed: () => setState(() => _creationStep = 1), child: const Text('Atrás')),
                const Spacer(),
                ElevatedButton(
                  onPressed: _isLoading ? null : _sendInvitationsAndFinish,
                  child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('Finalizar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimePicker(String label, TimeOfDay? time, ValueChanged<TimeOfDay> onTimeChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label),
        const SizedBox(height: 4),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () async {
              final pickedTime = await showTimePicker(
                context: context,
                initialTime: time ?? TimeOfDay.now(),
              );
              if (pickedTime != null) {
                onTimeChanged(pickedTime);
              }
            },
            // Eliminamos el estilo personalizado para que use el del tema global.
            child: Text(time?.format(context) ?? 'Elegir'),
          ),
        ),
      ],
    );
  }
}
