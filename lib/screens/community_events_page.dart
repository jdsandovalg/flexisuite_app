import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:flexisuite_shared/flexisuite_shared.dart';
import '../models/app_state.dart';
import 'package:table_calendar/table_calendar.dart';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';

class CommunityEventsPage extends StatefulWidget {
  const CommunityEventsPage({Key? key}) : super(key: key);

  @override
  _CommunityEventsPageState createState() => _CommunityEventsPageState();
}

class _CommunityEventsPageState extends State<CommunityEventsPage> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _events = [];
  String? _error;

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

  Future<void> _fetchInvitees() async {
    try {
      final user = AppState.currentUser;
      if (user == null) return;

      final response = await Supabase.instance.client.rpc(
        'manage_community_event_participants',
        params: {
          'p_action': 'list_invitees',
          // Usamos un UUID temporal que no existe para que la función se ejecute
          // y nos devuelva todos los usuarios de la organización.
          'p_event_id': '00000000-0000-0000-0000-000000000000',
          'p_organization_id_override': user.organizationId,
        },
      );
      if (mounted) {
        setState(() => _invitees = List<Map<String, dynamic>>.from(response));
