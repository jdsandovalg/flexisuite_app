import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import '../models/app_state.dart';
import 'package:flexisuite_shared/flexisuite_shared.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import '../widgets/location_tree_dialog.dart';

class IncidentFormPage extends StatefulWidget {
  const IncidentFormPage({Key? key}) : super(key: key);

  @override
  _IncidentFormPageState createState() => _IncidentFormPageState();
}

class _IncidentFormPageState extends State<IncidentFormPage> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = true;

  // Form fields
  final _descriptionController = TextEditingController();
  String _priority = 'medium';
  final _locationPathController = TextEditingController();
  String _department = 'security';
  String? _selectedLocationId;
  String? _selectedAdminId;
  String? _selectedParentTicketId;
  bool _useGps = false; // Nuevo estado para el interruptor de GPS
  Position? _currentPosition; // Para almacenar la posición GPS
  bool _isFetchingLocation = false; // Para mostrar un indicador de carga

  // Data for dropdowns
  List<LocationNode> _locationTree = [];
  List<Map<String, dynamic>> _admins = [];
  List<Map<String, dynamic>> _tickets = [];

  // Opciones para los selectores
  final Map<String, String> _priorityOptions = {
    'low': 'Baja',
    'medium': 'Media',
    'high': 'Alta',
  };
  final Map<String, String> _departmentOptions = {
    'security': 'Seguridad',
    'maintenance': 'Mantenimiento',
    'ornament': 'Ornato',
    'other': 'Otro',
  };

  // Estado para el filtro de tickets
  int _selectedFilterIndex = 0; // 0: Abiertos, 1: En Progreso, 2: Cerrados

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    try {
      await Future.wait([
        _loadUserLocation(), // Usar la nueva función para cargar la ubicación del usuario
        _loadAllLocations(), // Cargar todas las ubicaciones para el selector
        _fetchAdmins(),
        _fetchTickets(),
      ]);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar datos iniciales: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _fetchTickets() async {
    final user = AppState.currentUser;
    if (user == null) return;

    try {
      final response = await Supabase.instance.client.rpc(
        'manage_ticket_resident',
        params: {
          'p_action': 'select',
          'p_creator_id': user.id,
          // Añadimos el ID de la organización para filtrar la lista de tickets
          'p_organization_id': user.organizationId,
        },
      );
      if (mounted && response is List) {
        setState(() {
          _tickets = List<Map<String, dynamic>>.from(response);
        });
      }
    } catch (error) {
      print('Error fetching tickets: $error');
    }
  }

  Future<void> _loadUserLocation() async {
    final user = AppState.currentUser;
    if (user == null) return;

    // Llamamos directamente a get_location_path usando el ID del usuario.
    // La función ahora puede resolver la ubicación principal desde user_location_fees.
    try {
      final pathResult = await Supabase.instance.client.rpc(
        'get_location_path',
        params: {
          'p_location_id': null, // Pasamos null para que use el p_user_id
          'p_user_id': user.id,
        },
      );
      final pathData = pathResult as Map<String, dynamic>?;
      // Asumimos que la ruta de IDs viene como un array de strings.
      final pathIds = List<String>.from(pathData?['path_ids'] ?? []);
      _selectedLocationId = pathIds.isNotEmpty ? pathIds.first : null; // El primer ID es el de la propiedad.
      _locationPathController.text = pathData?['path_text'] ?? 'Ubicación no encontrada';
    } catch (e) {
      _locationPathController.text = 'Error al obtener ubicación';
    }
  }

  Future<void> _loadAllLocations() async {
    final user = AppState.currentUser;
    if (user == null) return;

    try {
      final response = await Supabase.instance.client.rpc(
        'get_locations_tree', // Usamos la función existente que trae todo.
        params: {'p_organization_id': user.organizationId},
      );

      if (mounted) {
        final allLocations = List<Map<String, dynamic>>.from(response);
        // Filtramos en la app para quedarnos solo con las de nuestra organización.
        final orgSpecificLocations = allLocations.where((loc) => loc['organization_id'] == user.organizationId).toList();
        final tree = buildLocationTree(orgSpecificLocations);
        setState(() {
          _locationTree = tree;
        });
      }
    } catch (error) {
      print('Error cargando todas las ubicaciones: $error');
    }
  }

  Future<void> _fetchAdmins() async {
    final user = AppState.currentUser;
    if (user == null) return;

    // 1. Obtener los user_id de los administradores en la organización actual
    final adminIdsResponse = await Supabase.instance.client
        .from('users_organizations_rel')
        .select('user_id')
        .eq('organization_id', user.organizationId)
        .eq('role', 'admin');

    final adminIds = (adminIdsResponse as List).map((e) => e['user_id'] as String).toList();

    // 2. Buscar los detalles de esos usuarios administradores
    final result = await Supabase.instance.client
        .from('users')
        .select('id, first_name, last_name')
        .inFilter('id', adminIds);

    if (mounted) {
      setState(() {
        _admins = (result as List)
            .map((e) => {
                  'id': e['id'],
                  'name': '${e['first_name'] ?? ''} ${e['last_name'] ?? ''}'.trim()
                })
            .toList();
      });
    }
  }

  Future<void> _createTicket() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final user = AppState.currentUser!;
      await Supabase.instance.client.rpc(
        'manage_ticket_resident',
        params: {
          'p_action': 'insert',
          'p_organization_id': user.organizationId, // Añadimos el ID de la organización
          'p_description': _descriptionController.text,
          'p_priority': _priority, // Ya está en minúsculas
          'p_department': _department,
          'p_location_id': _selectedLocationId,
          'p_creator_id': user.id,
          'p_last_updated_by': user.id, // El creador es el último en actualizarlo.
          'p_assigned_admin_id': _selectedAdminId,
          'p_parent_ticket_id': _selectedParentTicketId,
          // --- INICIO: Añadir datos de GPS si están disponibles ---
          'p_latitude': _useGps && _currentPosition != null ? _currentPosition!.latitude : null,
          'p_longitude': _useGps && _currentPosition != null ? _currentPosition!.longitude : null,
          'p_location_accuracy_m': _useGps && _currentPosition != null ? _currentPosition!.accuracy.round() : null,
          'p_location_timestamp': _useGps && _currentPosition != null ? _currentPosition!.timestamp?.toIso8601String() : null,
          // El provider no lo estamos capturando por ahora, pero la BD lo soporta.
          'p_location_provider': null,
          // --- FIN: Añadir datos de GPS ---
        },
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Ticket creado exitosamente.'),
              backgroundColor: Colors.green),
        );
        _formKey.currentState?.reset();
        _descriptionController.clear();
        setState(() {
          _priority = 'medium';
          _department = 'security';
          _selectedLocationId = null;
          _selectedAdminId = null;
          _useGps = false;
          _currentPosition = null;
          _selectedParentTicketId = null;
        });
        await _fetchTickets(); // Volvemos a cargar los tickets para mostrar el nuevo.
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: SelectableText('Error al crear el ticket: $error'),
              backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildSelector({
    required String label,
    required String currentValue,
    required Map<String, String> options,
    required Function(String) onSelected,
  }) {
    // Usamos Wrap para que los botones se ajusten automáticamente al espacio.
    return Wrap(
      spacing: 8.0, // Espacio horizontal entre botones
      runSpacing: 8.0, // Espacio vertical entre filas de botones
      children: options.entries.map((entry) {
        bool isSelected = currentValue == entry.key;
        final theme = Theme.of(context);
        return ElevatedButton(
          onPressed: () => onSelected(entry.key),
          style: ElevatedButton.styleFrom(
            backgroundColor: isSelected ? theme.colorScheme.primary : theme.colorScheme.surface.withOpacity(0.5),
            foregroundColor: isSelected ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface,
            // Hacemos los botones más compactos
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            textStyle: theme.textTheme.bodySmall,
          ),
          child: Text(entry.value),
        );
      }).toList(),
    );
  }

  Future<void> _handleGpsSwitch(bool value) async {
    setState(() {
      _useGps = value;
      _currentPosition = null; // Reseteamos la posición al cambiar el switch
    });

    if (value) {
      setState(() => _isFetchingLocation = true);
      final position = await _getCurrentLocation();
      if (mounted) {
        setState(() {
          _currentPosition = position;
          _isFetchingLocation = false;
          if (position == null) {
            _useGps = false; // Si no se pudo obtener, apagamos el switch
          }
        });
      }
    }
  }

  Future<Position?> _getCurrentLocation() async {
    // 1. Pedir permisos
    var status = await Permission.locationWhenInUse.request();
    if (!status.isGranted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Permiso de ubicación denegado.')));
      }
      return null;
    }

    // 2. Chequear si el servicio está activado
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Por favor, activa el GPS de tu dispositivo.')));
      }
      return null;
    }

    // 3. Pedir la posición con alta precisión
    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
      );
    } catch (e) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Leemos el parámetro ALLOW_GPS desde el estado global de la aplicación.
    final bool allowGpsFeature = AppState.organizationParameters['ALLOW_GPS'] ?? false;
    return Scaffold(
      backgroundColor: Colors.transparent, // Fondo transparente para que se vea el AppBackground
      body: AppBackground(
        child: Stack( // Usamos un Stack para superponer el título y el botón de atrás
          children: [
            // El contenido principal de la pantalla
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: SingleChildScrollView(
                  // Añadimos un padding superior para que el contenido no quede debajo del título flotante
                  padding: const EdgeInsets.fromLTRB(16.0, 80.0, 16.0, 16.0),
                  child: Column(
                    children: [
                      // --- Formulario de Creación ---
                      GlassCard(
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              TextFormField(
                                controller: _descriptionController,
                                decoration: const InputDecoration(
                                  labelText: 'Descripción del Incidente',
                                ),
                                maxLines: 3,
                                validator: (v) => v == null || v.isEmpty ? 'La descripción es obligatoria' : null,
                              ),
                              const SizedBox(height: 16),
                              const Text('Prioridad', style: TextStyle(fontWeight: FontWeight.bold)),
                              const SizedBox(height: 8),
                              _buildSelector(
                                label: 'Prioridad',
                                currentValue: _priority,
                                options: _priorityOptions,
                                onSelected: (val) => setState(() => _priority = val)),
                              const SizedBox(height: 16),
                              const Text('Departamento', style: TextStyle(fontWeight: FontWeight.bold)),
                              const SizedBox(height: 8),
                              _buildSelector(
                                label: 'Departamento',
                                currentValue: _department,
                                options: _departmentOptions,
                                onSelected: (val) => setState(() => _department = val),
                              ),
                              const SizedBox(height: 16),
                              // --- INICIO: Interruptor de GPS ---
                              SwitchListTile(
                                title: const Text('Adjuntar mi ubicación GPS'),
                                subtitle: _currentPosition != null
                                    ? Text('Lat: ${_currentPosition!.latitude.toStringAsFixed(4)}, Lon: ${_currentPosition!.longitude.toStringAsFixed(4)}', style: Theme.of(context).textTheme.bodySmall)
                                    : null,
                                value: _useGps,
                                onChanged: allowGpsFeature ? _handleGpsSwitch : null, // Deshabilitado si ALLOW_GPS es false
                                secondary: _isFetchingLocation ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : null,
                              ),
                              const SizedBox(height: 16),
                              // --- FIN: Interruptor de GPS ---
                              // --- INICIO: Campo de Ubicación Mejorado ---
                              TextFormField(
                                controller: _locationPathController,
                                readOnly: true,
                                decoration: InputDecoration(
                                  labelText: 'Ubicación del Incidente',
                                  suffixIcon: const Icon(Icons.search),
                                  hintText: _locationPathController.text.isEmpty ? 'Seleccionar ubicación...' : '',
                                ),
                                onTap: () {
                                  _showLocationDialog();
                                },
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'La ubicación es obligatoria';
                                  }
                                  return null;
                                },
                              ),
                              // --- FIN: Campo de Ubicación Mejorado ---
                              const SizedBox(height: 16),
                              DropdownButtonFormField<String>(
                                value: _selectedAdminId,
                                decoration: const InputDecoration(labelText: 'Asignar a (Opcional)'),
                                items: _admins.map((admin) {
                                  return DropdownMenuItem(
                                    value: admin['id'] as String,
                                    child: Text(admin['name'] as String),
                                  );
                                }).toList(),
                                onChanged: (val) => setState(() => _selectedAdminId = val),
                              ),
                              const SizedBox(height: 24),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: _isLoading ? null : _createTicket,
                                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                                  child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('Crear Ticket'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const Divider(height: 40, thickness: 1),
                      // --- Filtro y Listado de Tickets ---
                      FilterStrip(
                        options: const ['Abiertos', 'En Progreso', 'Historial'],
                        selectedIndex: _selectedFilterIndex,
                        onSelected: (index) {
                          setState(() {
                            _selectedFilterIndex = index;
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      _isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : _buildTicketGrid(),
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
                      'Crear Incidente',
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

  Widget _buildTicketGrid() {
    final List<Map<String, dynamic>> filteredTickets;
    String emptyMessage;

    if (_selectedFilterIndex == 0) { // Abiertos
      filteredTickets = _tickets.where((t) => t['status'] == 'open').toList();
      emptyMessage = 'No hay tickets abiertos.';
    } else if (_selectedFilterIndex == 1) { // En Progreso
      filteredTickets = _tickets.where((t) => t['status'] == 'in_progress').toList();
      emptyMessage = 'No hay tickets en progreso.';
    } else { // Historial
      filteredTickets = _tickets.where((t) => t['status'] == 'closed' || t['status'] == 'resolved').toList();
      emptyMessage = 'No hay historial de tickets.';
    }

    if (filteredTickets.isEmpty) {
      return Center(
        child: Text(emptyMessage),
      );
    }

    // Volvemos a un ListView.builder para garantizar estabilidad y altura dinámica.
    // Es el estándar más robusto para listas de contenido variable.
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: filteredTickets.length,
      itemBuilder: (context, index) {
        final ticket = filteredTickets[index];
        // Añadimos un padding para separar las tarjetas.
        return Padding(
          padding: const EdgeInsets.only(bottom: 16.0),
          child: _buildTicketCard(ticket),
        );
      },
    );
  }

  Widget _buildTicketCard(Map<String, dynamic> ticket) {
    final createdAt = ticket['created_at'] != null
        ? DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(ticket['created_at']))
        : 'N/A';
    final priority = _priorityOptions[ticket['priority']] ?? ticket['priority'] ?? 'N/A';

    return GlassCard(
      margin: EdgeInsets.zero,
      child: IntrinsicHeight( // Asegura que la columna interna tenga una altura coherente.
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '#${ticket['ticket_code'] ?? 'S/C'}',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              Chip(
                label: Text(priority, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                backgroundColor: (ticket['priority'] == 'high' ? Colors.red : ticket['priority'] == 'medium' ? Colors.orange : Colors.green).withOpacity(0.2),
                padding: const EdgeInsets.symmetric(horizontal: 4),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            ticket['description'] ?? 'Sin descripción',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const Spacer(),
          Text('Ubicación: ${ticket['location_path'] ?? 'No especificada'}', style: Theme.of(context).textTheme.bodySmall),
          Text('Creado: $createdAt', style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
      ),
    );
  }

  void _showLocationDialog() async {
    final selectedNode = await showDialog<LocationNode>(
      context: context,
      builder: (context) => LocationTreeDialog(
        locationTree: _locationTree,
        allowParentSelection: true, // Permitir seleccionar nodos padres (áreas comunes)
      ),
    );

    if (selectedNode != null) {
      // Una vez seleccionado un nodo, obtenemos su path completo.
      try {
        final pathResult = await Supabase.instance.client.rpc(
          'get_location_path',
          params: {'p_location_id': selectedNode.id},
        );
        final pathData = pathResult as Map<String, dynamic>?;
        setState(() {
          _selectedLocationId = selectedNode.id;
          _locationPathController.text = pathData?['path_text'] ?? selectedNode.name;
        });
      } catch (e) { print('Error al obtener el path de la ubicación seleccionada: $e'); }
    }
  }
}
