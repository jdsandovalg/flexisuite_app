import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'dart:convert'; // Importar la librería para JSON
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flexisuite_web/models/app_state.dart';
import 'package:flexisuite_web/widgets/profile_photo_picker.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = true;
  Map<String, dynamic> _profileData = {};
  List<Map<String, dynamic>> _locations = [];
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

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    // Listeners para validar contraseñas en tiempo real
    _passwordController.addListener(_validatePasswords);
    _confirmPasswordController.addListener(_validatePasswords);
  }

  void _validatePasswords() {
    setState(() {}); // Forzar reconstrucción del widget para actualizar el ícono
  }

  Future<void> _loadInitialData() async {
    try {
      await Future.wait([
        _loadProfileData(),
        // _loadLocations(), // Ya no es necesario cargar todas las ubicaciones
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

  Future<void> _loadLocations() async {
    final result = await Supabase.instance.client.rpc(
      'get_locations_tree', // <-- REVERTIDO: Volvemos a la función original
      params: {
        'p_organization_id': AppState.currentUser!.organizationId,
      },
    );

    if (mounted) {
      // La función ahora devuelve un único objeto jsonb que contiene la lista.
      // Necesitamos decodificarlo si no es ya una lista.
      List<dynamic> locationsData = [];
      if (result is String) {
        locationsData = json.decode(result) as List<dynamic>;
      } else if (result is List) {
        locationsData = result;
      }
      final locations = locationsData.map((e) => e as Map<String, dynamic>)
          .toList();
      setState(() {
        _locations = locations;
        // Asegurarse de que la ubicación del perfil se mantenga seleccionada
        if (_profileData.containsKey('location_id')) {
          _selectedLocationId = _profileData['location_id'];
        }
      });
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
        // Si el resultado es una lista (como se espera de una función que devuelve TABLE), tomamos el primer elemento.
        _profileData = result.first as Map<String, dynamic>;
      } else if (result is String && result.isNotEmpty) {
        // Si devuelve un string JSON, lo decodificamos.
        _profileData = (json.decode(result) as List).first as Map<String, dynamic>;
      } else if (result is Map) {
        _profileData = result as Map<String, dynamic>;
      } else {
        throw Exception("Unexpected data format from server: $result");
      }

      _firstNameController.text = _profileData['first_name'] ?? '';
      _lastNameController.text = _profileData['last_name'] ?? '';
      _birthDateController.text = _profileData['birth_date'] ?? '';
      _bioController.text = _profileData['bio'] ?? '';
      _photoUrlController.text = _profileData['photo_url'] ?? '';
      _emailController.text = _profileData['email'] ?? '';
      _phoneController.text = _profileData['phone'] ?? '';
      _selectedLocationId = _profileData['location_id'];
      _condoController.text = _profileData['condo'] ?? '';
      _floorController.text = _profileData['floor'] ?? '';
      _unitNumberController.text = _profileData['unit_number'] ?? '';
      _isPrivate = _profileData['is_private'] ?? false;
      _chatOptIn = _profileData['chat_opt_in'] ?? false;

      // Decodificar el campo location_path si es un string JSON
      final locationPathValue = _profileData['location_path'];
      if (locationPathValue is String && locationPathValue.startsWith('{')) {
        final decodedPath = json.decode(locationPathValue);
        _locationPathController.text = decodedPath['path_text'] ?? 'No asignada';
      } else {
        _locationPathController.text = locationPathValue ?? 'No asignada';
      }
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final paramsToSend = {
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
      print('Enviando parámetros a manage_user_profile: $paramsToSend');

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
        Navigator.of(context).pop();
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: SelectableText('Error al guardar el perfil: $error'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _uploadProfilePicture(Uint8List fileBytes, String fileName) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final bucket = Supabase.instance.client.storage.from('profile-pictures');
      final fileExt = fileName.split('.').last;
      final newFileName = '${AppState.currentUser!.id}.$fileExt';

      await bucket.uploadBinary(
        newFileName,
        fileBytes,
        fileOptions: FileOptions(upsert: true, contentType: 'image/$fileExt'),
      );

      final url = bucket.getPublicUrl(newFileName);

      if (mounted) {
        setState(() {
          _photoUrlController.text = url;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Foto de perfil actualizada.'),
            backgroundColor: Colors.green,
          ),
        );
        // Save the updated photo URL to the database
        print('Llamando a _saveProfile() desde _uploadProfilePicture...');
        await _saveProfile();
      }
    } catch (error) {
      print('Error en _uploadProfilePicture: $error');
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
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final editableInputDecoration = InputDecoration(
      border: const OutlineInputBorder(),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Editar Perfil'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
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
                        Card(
                          elevation: 2,
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Información Personal', style: Theme.of(context).textTheme.titleLarge),
                                const SizedBox(height: 16),
                                Row(children: [
                                  Expanded(child: TextFormField(
                                  controller: _firstNameController,
                                  decoration: editableInputDecoration.copyWith(labelText: 'Nombre'),
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
                                  decoration: editableInputDecoration.copyWith(labelText: 'Apellido'),
                                  )),
                                ],),
                                const SizedBox(height: 16),
                                TextFormField(
                                  controller: _emailController,
                                  decoration: editableInputDecoration.copyWith(labelText: 'Correo Electrónico'),
                                  readOnly: true,
                                ),
                                const SizedBox(height: 16),
                                TextFormField(
                                  controller: _birthDateController,
                                  decoration: editableInputDecoration.copyWith(labelText: 'Fecha de Nacimiento'),
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
                                  decoration: editableInputDecoration.copyWith(labelText: 'Teléfono'),
                                ),
                                const SizedBox(height: 16),
                                TextFormField(
                                  controller: _bioController,
                                  decoration: editableInputDecoration.copyWith(labelText: 'Biografía'),
                                  maxLines: 3,
                                ),
                              ],
                            ),
                          ),
                        ),
                        Card(
                          elevation: 2,
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Información de Residencia', style: Theme.of(context).textTheme.titleLarge),
                                const SizedBox(height: 16),
                                TextFormField(
                                  controller: _locationPathController,
                                  decoration: editableInputDecoration.copyWith(
                                    labelText: 'Ubicación',
                                    filled: true, // Color de fondo para indicar que no es editable
                                    fillColor: Colors.grey[200],
                                  ),
                                  style: const TextStyle(fontSize: 12), // Reducir el tamaño de la fuente
                                  readOnly: true, // Hacer el campo de solo lectura
                                ),
                                const SizedBox(height: 16),
                                TextFormField(
                                  controller: _condoController,
                                  decoration: editableInputDecoration.copyWith(labelText: 'Condominio'),
                                ),
                                const SizedBox(height: 16),
                                Row(children: [
                                  Expanded(child: TextFormField(
                                    controller: _floorController,
                                    decoration: editableInputDecoration.copyWith(labelText: 'Piso'),
                                  )),
                                  const SizedBox(width: 16),
                                  Expanded(child: TextFormField(
                                    controller: _unitNumberController,
                                    decoration: editableInputDecoration.copyWith(labelText: 'Número de Unidad/Casa'),
                                  )),
                                ],),
                              ],
                            ),
                          ),
                        ),
                        Card(
                          elevation: 2,
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Seguridad y Privacidad', style: Theme.of(context).textTheme.titleLarge),
                                const SizedBox(height: 16),
                                TextFormField(
                                  controller: _passwordController,
                                  decoration: editableInputDecoration.copyWith(
                                    labelText: 'Nueva Contraseña (dejar en blanco para no cambiar)',
                                    helperText: 'Mínimo 8 caracteres, 1 mayúscula, 1 minúscula, 1 número y 1 símbolo (!@#\$&*~).',
                                    helperMaxLines: 2,
                                  ),
                                  obscureText: true,
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return null; // No validar si está vacío
                                    }

                                    // Regex para validar contraseña fuerte
                                    String pattern = r'^(?=.*?[A-Z])(?=.*?[a-z])(?=.*?[0-9])(?=.*?[!@#\$&*~]).{8,}$';
                                    RegExp regExp = RegExp(pattern);

                                    if (!regExp.hasMatch(value)) {
                                      return 'Debe tener 8+ caracteres, mayúscula, minúscula, número y símbolo.';
                                    }

                                    // if (value.length < 8) return 'Debe tener al menos 8 caracteres.';
                                    // if (!value.contains(RegExp(r'[A-Z]'))) return 'Debe tener al menos una mayúscula.';
                                    // if (!value.contains(RegExp(r'[a-z]'))) return 'Debe tener al menos una minúscula.';
                                    // if (!value.contains(RegExp(r'[0-9]'))) return 'Debe tener al menos un número.';
                                    // if (!value.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) return 'Debe tener al menos un símbolo especial.';

                                    // Si el campo de confirmar contraseña no está vacío, valida que coincidan
                                    if (_confirmPasswordController.text.isNotEmpty && value != _confirmPasswordController.text) {
                                      return 'Las contraseñas no coinciden';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 16),
                                TextFormField(
                                  controller: _confirmPasswordController,
                                  decoration: editableInputDecoration.copyWith(
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

  @override
  void dispose() {
    _passwordController.removeListener(_validatePasswords);
    _confirmPasswordController.removeListener(_validatePasswords);
    // ... otros dispose
    super.dispose();
  }
}