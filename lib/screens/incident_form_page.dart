import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import '../models/app_state.dart';

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

  // Data for dropdowns
  List<Map<String, dynamic>> _locations = [];
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

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    try {
      await Future.wait([
        _loadUserLocation(), // Usar la nueva función para cargar la ubicación del usuario
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

    // Llama a manage_user_profile para obtener todos los datos, incluyendo el location_path
    final result = await Supabase.instance.client.rpc(
      'manage_user_profile',
      params: {
        'p_action': 'select',
        'p_user_id': user.id,
      },
    );

    if (mounted && result is List && result.isNotEmpty) {
      final profileData = result.first as Map<String, dynamic>;

      // Asignar el location_id para enviarlo al crear el ticket
      _selectedLocationId = profileData['location_id'];

      // Decodificar y mostrar el location_path, igual que en el perfil
      final locationPathValue = profileData['location_path'];
      if (locationPathValue is String && locationPathValue.startsWith('{')) {
        final decodedPath = json.decode(locationPathValue);
        _locationPathController.text = decodedPath['path_text'] ?? 'No asignada';
      } else {
        _locationPathController.text = locationPathValue ?? 'No asignada';
      }
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
          'p_description': _descriptionController.text,
          'p_priority': _priority, // Ya está en minúsculas
          'p_department': _department,
          'p_location_id': _selectedLocationId,
          'p_creator_id': user.id,
          'p_assigned_admin_id': _selectedAdminId,
          'p_parent_ticket_id': _selectedParentTicketId,
          // 'p_organization_id' ya no es necesario, se obtiene en el backend.
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
          _selectedParentTicketId = null;
        });
        await _fetchTickets(); // Refresh the list
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

  Color _getCardColor(String? color) {
    switch (color) {
      case 'green':
        return Colors.green.shade50;
      case 'yellow':
        return Colors.yellow.shade50;
      case 'orange':
        return Colors.orange.shade50;
      case 'red':
        return Colors.red.shade50;
      default:
        return Colors.white;
    }
  }

  Widget _buildSelector({
    required String label,
    required String currentValue,
    required Map<String, String> options,
    required Function(String) onSelected,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: options.entries.map((entry) {
        bool isSelected = currentValue == entry.key;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: ElevatedButton(
              onPressed: () => onSelected(entry.key),
              style: ElevatedButton.styleFrom(
                backgroundColor: isSelected ? Colors.blueAccent : Colors.grey[300],
                foregroundColor: isSelected ? Colors.white : Colors.black,
              ),
              child: Text(entry.value, textAlign: TextAlign.center),
            ),
          ),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Crear Incidente')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                // --- Formulario de Creación ---
                Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextFormField(
                        controller: _descriptionController,
                        decoration: const InputDecoration(
                          labelText: 'Descripción del Incidente',
                          border: OutlineInputBorder(),
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
                      TextFormField(
                        controller: _locationPathController,
                        decoration: const InputDecoration(
                          labelText: 'Ubicación (Automática)',
                          border: OutlineInputBorder(),
                          filled: true,
                          fillColor: Color.fromARGB(255, 240, 240, 240),
                        ),
                        enabled: false, // Deshabilitar el campo para que no sea editable
                        style: const TextStyle(fontSize: 12), // Reducir el tamaño de la fuente
                        readOnly: true,
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: _selectedAdminId,
                        decoration: const InputDecoration(labelText: 'Asignar a (Opcional)', border: OutlineInputBorder()),
                        items: _admins.map((admin) {
                          return DropdownMenuItem(
                            value: admin['id'] as String,
                            child: Text(admin['name'] as String),
                          );
                        }).toList(),
                        onChanged: (val) => setState(() => _selectedAdminId = val),
                      ),
                      const SizedBox(height: 16),
                      // Campo "Ticket Padre" deshabilitado y oculto por ahora.
                      // DropdownButtonFormField<String>(
                      //   value: _selectedParentTicketId,
                      //   decoration: const InputDecoration(labelText: 'Ticket Padre (Opcional)', border: OutlineInputBorder()),
                      //   items: _tickets.map((ticket) {
                      //     return DropdownMenuItem(
                      //       value: ticket['ticket_id'] as String,
                      //       child: Text('${ticket['ticket_code']} - ${ticket['description']}'),
                      //     );
                      //   }).toList(),
                      //   onChanged: (val) => setState(() => _selectedParentTicketId = val),
                      // ),
                      // const SizedBox(height: 24),
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
                const Divider(height: 40, thickness: 1),
                // --- Listado de Tickets ---
                const Text('Tickets Existentes', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _tickets.isEmpty
                        ? const Center(child: Text('No hay tickets creados.'))
                        : ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _tickets.length,
                            itemBuilder: (context, index) {
                              final ticket = _tickets[index];
                              final createdAt = ticket['created_at'] != null
                                  ? DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(ticket['created_at']))
                                  : 'N/A';
                              return Card(
                                color: _getCardColor(ticket['color'] as String?),
                                margin: const EdgeInsets.symmetric(vertical: 8),
                                child: ListTile(
                                  title: Text(
                                    '#${ticket['ticket_code'] ?? 'S/C'}: ${ticket['description'] ?? 'Sin descripción'}',
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const SizedBox(height: 4),
                                      Text('Estado: ${ticket['status'] ?? 'N/A'} | Prioridad: ${ticket['priority'] ?? 'N/A'}'),
                                      Text('Departamento: ${ticket['department'] ?? 'N/A'}'),
                                      Text('Creado: $createdAt'),
                                    ],
                                  ),
                                  isThreeLine: true,
                                ),
                              );
                            },
                          ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}