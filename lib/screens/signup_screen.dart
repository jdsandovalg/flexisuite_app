import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  // Controllers
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _addressController = TextEditingController();
  final _condoController = TextEditingController();
  final _floorController = TextEditingController();
  final _unitNumberController = TextEditingController();

  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Llamamos a la función manage_user_profile con la acción 'insert'
      await Supabase.instance.client.rpc(
        'manage_user_profile',
        params: {
          'p_action': 'insert',
          'p_email': _emailController.text,
          'p_password': _passwordController.text,
          'p_first_name': _firstNameController.text,
          'p_last_name': _lastNameController.text,
          'p_address': _addressController.text,
          'p_condo': _condoController.text,
          'p_floor': _floorController.text,
          'p_unit_number': _unitNumberController.text,
        },
      );

      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('Registro Exitoso'),
            content: const Text(
                'Tu cuenta ha sido creada. La administración revisará tu solicitud y te asignará a la organización. Serás notificado cuando puedas ingresar.'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop(); // Cierra el diálogo
                  Navigator.of(context).pop(); // Regresa a la pantalla de login
                },
                child: const Text('Entendido'),
              ),
            ],
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: SelectableText('Error en el registro: $error'),
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

  @override
  Widget build(BuildContext context) {
    // Unificar el estilo con la pantalla de perfil
    final inputDecoration = const InputDecoration(border: OutlineInputBorder());

    return Scaffold(
      appBar: AppBar(title: const Text('Crear Nueva Cuenta')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _firstNameController,
                                  decoration: inputDecoration.copyWith(labelText: 'Nombre'),
                                  validator: (v) => v!.isEmpty ? 'Campo requerido' : null,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: TextFormField(
                                  controller: _lastNameController,
                                  decoration: inputDecoration.copyWith(labelText: 'Apellido'),
                                  validator: (v) => v!.isEmpty ? 'Campo requerido' : null,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _emailController,
                            decoration: inputDecoration.copyWith(labelText: 'Correo Electrónico'),
                            keyboardType: TextInputType.emailAddress,
                            validator: (v) => v!.isEmpty || !v.contains('@') ? 'Correo inválido' : null,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _passwordController,
                            decoration: inputDecoration.copyWith(
                              labelText: 'Contraseña',
                              helperText: 'Mínimo 8 caracteres, con mayúscula, minúscula, número y símbolo.',
                              helperMaxLines: 2,
                            ),
                            obscureText: true,
                            validator: (value) {
                              if (value == null || value.isEmpty) return 'La contraseña es requerida';
                              String pattern = r'^(?=.*?[A-Z])(?=.*?[a-z])(?=.*?[0-9])(?=.*?[!@#\$&*~]).{8,}$';
                              if (!RegExp(pattern).hasMatch(value)) return 'La contraseña no cumple los requisitos.';
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _confirmPasswordController,
                            decoration: inputDecoration.copyWith(labelText: 'Confirmar Contraseña'),
                            obscureText: true,
                            validator: (v) {
                              if (v != _passwordController.text) return 'Las contraseñas no coinciden';
                              return null;
                            },
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
                            controller: _addressController,
                            decoration: inputDecoration.copyWith(labelText: 'Dirección'),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _condoController,
                            decoration: inputDecoration.copyWith(labelText: 'Condominio'),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(child: TextFormField(controller: _floorController, decoration: inputDecoration.copyWith(labelText: 'Piso'))),
                              const SizedBox(width: 16),
                              Expanded(child: TextFormField(controller: _unitNumberController, decoration: inputDecoration.copyWith(labelText: 'Número de Unidad/Casa'))),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _signUp,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text('Registrarme'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}