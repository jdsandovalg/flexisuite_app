import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flexisuite_web/screens/menu_page.dart'; // New import
import 'package:flexisuite_web/models/app_state.dart'; // New import
import 'package:flexisuite_web/screens/signup_screen.dart'; // Importar la nueva pantalla
import 'package:flexisuite_web/screens/restricted_access_screen.dart'; // Importar la nueva pantalla de acceso restringido

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    final email = _emailController.text;
    final password = _passwordController.text;

    try {
      final result = await Supabase.instance.client.rpc(
        'validate_user_login',
        params: {
          'p_email': email,
          'p_password': password, // El nombre del parámetro ya es correcto, lo mantengo para claridad.
        },
      );

      if (mounted) {
        final data = result as Map<String, dynamic>;

        if (data['success'] == true) {
          // Login successful, parse and store user data
          if (data['user'] != null) { // Check if 'user' is not null
            final user = UserModel.fromJson(data['user'] as Map<String, dynamic>);
            AppState.currentUser = user;

            // --- INICIO DE LA VALIDACIÓN DE ROL ---
            if (user.role.toLowerCase() == 'resident') {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Bienvenido ${user.name}!'),
                ),
              );
              // Navegar al menú principal si es residente
              Navigator.pushReplacement( // Usar pushReplacement para que no pueda volver al login
                context,
                MaterialPageRoute(
                  builder: (context) => const MenuPage(),
                ),
              );
            } else {
              // Navegar a la pantalla de acceso restringido si no es residente
              Navigator.push(
                context, // 1. El contexto como primer argumento posicional
                MaterialPageRoute( // 2. La ruta como segundo argumento posicional
                  builder: (context) => RestrictedAccessScreen(
                    userName: user.name,
                    organizationName: user.organizationName,
                  ),
                ),
              );
            }
            // --- FIN DE LA VALIDACIÓN DE ROL ---
          } else {
            // Handle case where 'user' is null even if success is true
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Error de inicio de sesión'),
                content: const SelectableText('Datos de usuario incompletos.'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('OK'),
                  ),
                ],
              ),
            );
          }
        } else {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Error de inicio de sesión'),
              content: SelectableText(data['message']?.toString() ?? 'Error desconocido'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
      }
    } catch (error) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Error inesperado'),
            content: SelectableText(error.toString()),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
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
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Logo aquí
                  Image.asset(
                    'assets/logo.png',
                    height: 100, // Ajusta el tamaño según sea necesario
                  ),
                  const SizedBox(height: 20), // Espacio entre el logo y el campo de correo electrónico

                  TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(labelText: 'Correo electrónico'),
                    validator: (value) {
                      if (value == null || value.isEmpty || !value.contains('@')) {
                        return 'Ingrese un correo válido';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _passwordController,
                    decoration: const InputDecoration(labelText: 'Contraseña'),
                    obscureText: true,
                    onEditingComplete: _isLoading ? null : _login,
                  ),
                  const SizedBox(height: 30),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        if (!_isLoading) {
                          _login();
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 15),
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text("Ingresar"),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center, // Centrar el botón restante
                    children: [
                      TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const SignUpScreen()),
                          );
                        },
                        child: const Text("Crear Usuario"),
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
}
