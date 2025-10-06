import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'dart:convert'; // Importar la librería para JSON
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../models/app_state.dart';
import 'package:flexisuite_shared/flexisuite_shared.dart'; // Importar el paquete compartido
import '../widgets/profile_photo_picker.dart';
import '../services/log_service.dart'; // Import LogService

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = true;
  final _logService = LogService(); // Instanciar LogService

  Map<String, dynamic> _profileData = {};
  List<Map<String, dynamic>> _accessCards = [];
  List<Map<String, dynamic>> _userFees = [];
  String? _selectedLocationId;

  // Controllers for form fields
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _birthDateController = TextEditingController();
  final _bioController = TextEditingController();
  final _photoUrlController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _condoController = TextEditingController();
  final _floorController = TextEditingController();
  final _unitNumberController = TextEditingController();
  final _passwordController = TextEditingController();
  final _locationPathController = TextEditingController(); // Controller para el nuevo campo
  final _confirmPasswordController = TextEditingController(); // Nuevo controlador
  bool _isPrivate = false;
  bool _chatOptIn = false;

  // Control para el ToggleButton
  int _selectedViewIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    // Listeners para validar contraseñas en tiempo real
    _passwordController.addListener(_validatePasswords);
    _confirmPasswordController.addListener(_validatePasswords);
  }

  @override
  void dispose() {
    _passwordController.removeListener(_validatePasswords);
    _confirmPasswordController.removeListener(_validatePasswords);
    // ... otros dispose
    super.dispose();
  }

  void _validatePasswords() {
    setState(() {}); // Forzar reconstrucción del widget para actualizar el ícono
  }

  Future<void> _loadInitialData() async {
    try {
      await Future.wait([
        _loadProfileData(),
        _fetchAccessCards(),
        _fetchUserFees(),
      ]);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: SelectableText('Error al cargar datos iniciales: $error'),
            backgroundColor: Colors.red,
          ),
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

  Future<void> _loadProfileData() async {
    final result = await Supabase.instance.client.rpc(
      'manage_user_profile',
      params: {
        'p_action': 'select',
        'p_user_id': AppState.currentUser!.id,
      },
    );
    if (mounted) {
      if (result is List && result.isNotEmpty) {
        _profileData = result.first as Map<String, dynamic>;
      } else {
        throw Exception("No se pudo cargar el perfil del usuario.");
      }
      _firstNameController.text = _profileData['first_name'] ?? '';
      _lastNameController.text = _profileData['last_name'] ?? '';
      _birthDateController.text = _profileData['birth_date'] ?? '';
      _bioController.text = _profileData['bio'] ?? '';
      _photoUrlController.text = _profileData['photo_url'] ?? '';
      _emailController.text = _profileData['email'] ?? '';
      _phoneController.text = _profileData['phone'] ?? '';
      _condoController.text = _profileData['condo'] ?? '';
      _floorController.text = _profileData['floor'] ?? '';
      _unitNumberController.text = _profileData['unit_number'] ?? '';
      _isPrivate = _profileData['is_private'] ?? false;
      _chatOptIn = _profileData['chat_opt_in'] ?? false;

      // Obtenemos la ubicación usando la nueva lógica
      try {
        final pathResult = await Supabase.instance.client.rpc(
          'get_location_path',
          params: {'p_location_id': null, 'p_user_id': AppState.currentUser!.id},
        );
        final pathData = pathResult as Map<String, dynamic>?;
        final pathIds = List<String>.from(pathData?['path_ids'] ?? []);
        _selectedLocationId = pathIds.isNotEmpty ? pathIds.first : null;
        _locationPathController.text = pathData?['path_text'] ?? 'Ubicación no encontrada';
      } catch (e) {
        _locationPathController.text = 'Error al obtener ubicación';
      }
      setState(() {});
    }
  }

  Future<void> _fetchAccessCards() async {
    final result = await Supabase.instance.client.rpc(
      'manage_access_cards',
      params: {
        'p_action': 'select',
        'p_user_id': AppState.currentUser!.id,
        'p_organization_id': AppState.currentUser!.organizationId,
        // Pasamos null al resto de parámetros para que la firma coincida.
        'p_card_id': null, 'p_vehicular_id': null, 'p_pedestrian_id': null, 'p_is_active': null, 'p_created_by': null,
      },
    );
    if (mounted) {
      setState(() => _accessCards = List<Map<String, dynamic>>.from(result));
    }
  }

  Future<void> _fetchUserFees() async {
    final result = await Supabase.instance.client.rpc(
      'get_user_fees',
      params: {
        'p_user_id': AppState.currentUser!.id,
        'p_organization_id': AppState.currentUser!.organizationId, // Añadimos el ID de la organización
      },
    );
    _logService.log('Calling get_user_fees with p_user_id: ${AppState.currentUser!.id}, p_organization_id: ${AppState.currentUser!.organizationId}');
    _logService.log('Raw response from get_user_fees: $result');

    if (mounted) {
      try {
        // Verificamos que el resultado sea una lista antes de intentar la conversión.
        if (result is List) {
          setState(() => _userFees = List<Map<String, dynamic>>.from(result));
        } else {
          _logService.log('Error: La respuesta de get_user_fees no es una lista. Tipo recibido: ${result.runtimeType}');
          setState(() => _userFees = []); // Asignamos una lista vacía para evitar errores.
        }
      } catch (e) {
        _logService.log('Error al procesar la respuesta de get_user_fees: $e');
      }
    }
  }

  Future<void> _uploadProfilePicture(Uint8List fileBytes, String fileName) async {
    setState(() => _isLoading = true);

    try {
      final bucket = Supabase.instance.client.storage.from('profile-pictures'); // No necesita user.id aquí
      final fileExt = fileName.split('.').last;
      final newFileName = '${AppState.currentUser!.id}.$fileExt';

      await bucket.uploadBinary(
        newFileName,
        fileBytes,
        fileOptions: const FileOptions(upsert: true),
      );

      final url = bucket.getPublicUrl(newFileName);

      if (mounted) {
        setState(() => _photoUrlController.text = url);
        await _saveProfile();
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: SelectableText('Error al subir la foto: $error'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() => _isLoading = true);

    try {
      final paramsToSend = { // No necesita user.id aquí
        'p_action': 'update',
        'p_user_id': AppState.currentUser!.id,
        'p_first_name': _firstNameController.text,
        'p_last_name': _lastNameController.text,
        'p_birth_date': _birthDateController.text.isNotEmpty ? _birthDateController.text : null,
        'p_bio': _bioController.text,
        'p_email': _emailController.text,
        'p_phone': _phoneController.text,
        'p_location_id': _selectedLocationId,
        'p_condo': _condoController.text,
        'p_floor': _floorController.text,
        'p_unit_number': _unitNumberController.text,
        'p_password': _passwordController.text.isNotEmpty ? _passwordController.text : null,
        'p_is_private': _isPrivate,
        'p_chat_opt_in': _chatOptIn,
        'p_photo_url': _photoUrlController.text,
        'p_profile_picture': _photoUrlController.text.isNotEmpty
            ? _photoUrlController.text.split('/').last.split('?').first
            : null,
      };

      await Supabase.instance.client.rpc(
        'manage_user_profile',
        params: paramsToSend,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Perfil actualizado correctamente.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: SelectableText('Error al guardar el perfil: $error'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildAccessCardsCarousel() {
    final theme = Theme.of(context);

    if (_accessCards.isEmpty) {
      return Center(
        child: GlassCard(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
          child: const Text(
            'No tienes tarjetas de acceso asignadas.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    // Cambiamos a un ListView vertical para que cada tarjeta ocupe el ancho completo.
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          itemCount: _accessCards.length,
          itemBuilder: (context, index) {
            final card = _accessCards[index];
            final bool isActive = card['is_active'] ?? false;
            return GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Vehicular: ${card['vehicular_id'] ?? 'N/A'}', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('Peatonal: ${card['pedestrian_id'] ?? 'N/A'}', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text('Estado: ', style: theme.textTheme.bodySmall),
                      Icon(isActive ? Icons.check_circle : Icons.cancel, color: isActive ? theme.colorScheme.primary : theme.colorScheme.error, size: 16),
                      Text(isActive ? ' Activa' : ' Inactiva', style: TextStyle(color: isActive ? theme.colorScheme.primary : theme.colorScheme.error, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildUserFeesCarousel() {
    final theme = Theme.of(context);

    if (_userFees.isEmpty) {
      return Center(
        child: GlassCard(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
          child: const Text(
            'No tienes cuotas asignadas.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    // Usamos Center y ConstrainedBox para mantener un ancho máximo consistente.
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          itemCount: _userFees.length, // Ahora _userFees es una lista de propiedades
          itemBuilder: (context, index) {
            final property = _userFees[index];
            final locationName = property['location_name'] ?? 'Propiedad sin nombre';
            final feesForProperty = List<Map<String, dynamic>>.from(property['fees'] ?? []);

            return GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Mostramos el nombre de la propiedad
                  Text(
                    locationName,
                    style: theme.textTheme.titleLarge?.copyWith(color: theme.colorScheme.primary),
                  ),
                  const Divider(height: 16),
                  // Si no hay cuotas para esta propiedad, mostramos un mensaje.
                  if (feesForProperty.isEmpty)
                    const Text('No hay cuotas asignadas a esta propiedad.')
                  else
                    // Usamos un Column para listar las cuotas de esta propiedad.
                    Column(
                      children: feesForProperty.map((fee) {
                        final bool isCurrent = fee['is_current'] ?? false;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(fee['fee_name'] ?? 'N/A', style: theme.textTheme.bodyLarge),
                                    Row(children: [
                                      Icon(isCurrent ? Icons.check_circle : Icons.cancel, color: isCurrent ? theme.colorScheme.primary : theme.colorScheme.error, size: 14),
                                      const SizedBox(width: 4),
                                      Text(isCurrent ? 'Vigente' : 'No Vigente', style: theme.textTheme.bodySmall?.copyWith(color: isCurrent ? theme.colorScheme.primary : theme.colorScheme.error)),
                                    ]),
                                  ],
                                ),
                              ),
                              Text(
                                'Q${(fee['fee_amount'] as num? ?? 0).toStringAsFixed(2)}',
                                style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent, // Fondo transparente para que se vea el AppBackground
      body: AppBackground(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Stack(
                children: [
                  // Contenido principal
                  Column(
                    children: [
                      const SizedBox(height: 80), // Espacio para el título flotante
                      FilterStrip(
                        options: const ['Perfil', 'Mis Tarjetas', 'Mis Cuotas'],
                        selectedIndex: _selectedViewIndex,
                        onSelected: (index) {
                          setState(() {
                            _selectedViewIndex = index;
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: IndexedStack(
                          index: _selectedViewIndex,
                          children: [
                            // Vista 0: Perfil General
                            SingleChildScrollView(
                              padding: const EdgeInsets.all(16),
                              child: Center(
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(maxWidth: 600),
                                  child: Form(
                                    key: _formKey,
                                    child: Column(
                                      children: [
                                        ProfilePhotoPicker(
                                          initialImageUrl: _photoUrlController.text,
                                          onPhotoPicked: (fileBytes, fileName) {
                                            _uploadProfilePicture(fileBytes, fileName);
                                          },
                                        ),
                                        const SizedBox(height: 24),
                                        GlassCard(
                                          child: Theme(
                                            data: Theme.of(context).copyWith(inputDecorationTheme: Theme.of(context).inputDecorationTheme),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text('Información Personal', style: Theme.of(context).textTheme.titleLarge),
                                                const SizedBox(height: 16),
                                                Row(children: [
                                                  Expanded(child: TextFormField(
                                                  controller: _firstNameController,
                                                  decoration: const InputDecoration(labelText: 'Nombre'),
                                                  validator: (value) {
                                                    if (value == null || value.isEmpty) {
                                                      return 'Este campo es requerido';
                                                    }
                                                    return null;
                                                  },
                                                  )),
                                                  const SizedBox(width: 16),
                                                  Expanded(child: TextFormField(
                                                  controller: _lastNameController,
                                                  decoration: const InputDecoration(labelText: 'Apellido'),
                                                  )),
                                                ],),
                                                const SizedBox(height: 16),
                                                TextFormField(
                                                  controller: _emailController,
                                                  decoration: const InputDecoration(labelText: 'Correo Electrónico'),
                                                  readOnly: true,
                                                ),
                                                const SizedBox(height: 16),
                                                TextFormField(
                                                  controller: _birthDateController,
                                                  decoration: const InputDecoration(labelText: 'Fecha de Nacimiento'),
                                                  onTap: () async {
                                                    FocusScope.of(context).requestFocus(FocusNode());
                                                    final date = await showDatePicker(
                                                      context: context,
                                                      initialDate: DateTime.now(),
                                                      firstDate: DateTime(1900),
                                                      lastDate: DateTime.now(),
                                                    );
                                                    if (date != null) {
                                                      _birthDateController.text = date.toIso8601String().split('T').first;
                                                    }
                                                  },
                                                ),
                                                const SizedBox(height: 16),
                                                TextFormField(
                                                  controller: _phoneController,
                                                  decoration: const InputDecoration(labelText: 'Teléfono'),
                                                ),
                                                const SizedBox(height: 16),
                                                TextFormField(
                                                  controller: _bioController,
                                                  decoration: const InputDecoration(labelText: 'Biografía'),
                                                  maxLines: 3,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        GlassCard(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text('Información de Residencia', style: Theme.of(context).textTheme.titleLarge),                                          
                                              TextFormField(
                                                controller: _condoController,
                                                decoration: const InputDecoration(labelText: 'Condominio'),
                                              ),
                                              const SizedBox(height: 16),
                                              Row(children: [
                                                Expanded(child: TextFormField(
                                                  controller: _floorController,
                                                  decoration: const InputDecoration(labelText: 'Piso'),
                                                )),
                                                const SizedBox(width: 16),
                                                Expanded(child: TextFormField(
                                                  controller: _unitNumberController,
                                                  decoration: const InputDecoration(labelText: 'Número de Unidad/Casa'),
                                                )),
                                              ],),
                                            ],
                                          ),
                                        ),
                                        GlassCard(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text('Seguridad y Privacidad', style: Theme.of(context).textTheme.titleLarge),
                                              const SizedBox(height: 16),
                                              TextFormField(
                                                controller: _passwordController,
                                                decoration: const InputDecoration(
                                                  labelText: 'Nueva Contraseña (dejar en blanco para no cambiar)',
                                                  helperText: 'Mínimo 8 caracteres, 1 mayúscula, 1 minúscula, 1 número y 1 símbolo (!@#\$&*~).',
                                                  helperMaxLines: 2,
                                                ),
                                                obscureText: true,
                                                validator: (value) {
                                                  if (value == null || value.isEmpty) {
                                                    return null; // No validar si está vacío
                                                  }
                                                  String pattern = r'^(?=.*?[A-Z])(?=.*?[a-z])(?=.*?[0-9])(?=.*?[!@#\$&*~]).{8,}$';
                                                  if (!RegExp(pattern).hasMatch(value)) {
                                                    return 'La contraseña no cumple los requisitos.';
                                                  }
                                                  if (_confirmPasswordController.text.isNotEmpty && value != _confirmPasswordController.text) {
                                                    return 'Las contraseñas no coinciden';
                                                  }
                                                  return null;
                                                },
                                              ),
                                              const SizedBox(height: 16),
                                              TextFormField(
                                                controller: _confirmPasswordController,
                                                decoration: InputDecoration(
                                                  labelText: 'Confirmar Nueva Contraseña',
                                                  suffixIcon: _buildPasswordMatchIcon(),
                                                ),
                                                obscureText: true,
                                                validator: (value) {
                                                  if (_passwordController.text.isNotEmpty && value != _passwordController.text) {
                                                    return 'Las contraseñas no coinciden';
                                                  }
                                                  return null;
                                                },
                                              ),
                                              const SizedBox(height: 16),
                                              CheckboxListTile(
                                                title: const Text('Cuenta Privada'),
                                                value: _isPrivate,
                                                onChanged: (value) {
                                                  setState(() {
                                                    _isPrivate = value ?? false;
                                                  });
                                                },
                                              ),
                                              CheckboxListTile(
                                                title: const Text('Recibir Notificaciones de Chat'),
                                                value: _chatOptIn,
                                                onChanged: (value) {
                                                  setState(() {
                                                    _chatOptIn = value ?? false;
                                                  });
                                                },
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 24),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.end,
                                          children: [
                                            TextButton(
                                              onPressed: () => Navigator.of(context).pop(),
                                              child: const Text('Cancelar'),
                                            ),
                                            const SizedBox(width: 10),
                                            ElevatedButton(
                                              onPressed: _isLoading ? null : _saveProfile,
                                              style: ElevatedButton.styleFrom(
                                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                                textStyle: const TextStyle(fontSize: 16),
                                              ),
                                              child: _isLoading
                                                  ? const CircularProgressIndicator(color: Colors.white)
                                                  : const Text('Guardar Cambios'),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            // Vista 1: Mis Tarjetas de Acceso
                              _buildAccessCardsCarousel(),
                            // Vista 2: Mis Cuotas
                            _buildUserFeesCarousel(),
                          ],
                        ),
                      ),
                    ],
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
                            'Editar Perfil',
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

  Widget? _buildPasswordMatchIcon() {
    if (_passwordController.text.isEmpty && _confirmPasswordController.text.isEmpty) {
      return null; // No mostrar ícono si ambos campos están vacíos
    }
    if (_passwordController.text.isNotEmpty &&
        _confirmPasswordController.text.isNotEmpty &&
        _passwordController.text == _confirmPasswordController.text) {
      return const Icon(Icons.check_circle, color: Colors.green); // Check verde
    } else {
      return const Icon(Icons.error, color: Colors.red); // Check rojo (o error)
    }
  }
}
