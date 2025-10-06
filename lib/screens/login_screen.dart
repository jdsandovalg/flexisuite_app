import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'forgot_password_screen.dart';
import '../widgets/app_dialogs.dart';
import 'menu_page.dart';
import '../models/app_state.dart'; // Importar UserSessionProvider y UserModel
import 'signup_screen.dart'; // Importar la nueva pantalla
import 'package:flexisuite_shared/flexisuite_shared.dart'; // Importar para AppBackground y GlassCard
import 'restricted_access_screen.dart'; // Importar la nueva pantalla de acceso restringido
import '../services/log_service.dart'; // Importar el servicio de logs
import 'log_viewer_screen.dart'; // Importar la pantalla de logs

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
  int _logoTaps = 0; // Contador para el gesto oculto
  final _logService = LogService();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    final email = _emailController.text;
    final password = _passwordController.text;

    _logService.log('Iniciando intento de login para: $email');

    try {
      final result = await Supabase.instance.client.rpc(
        'validate_user_login',
        params: {
          'p_email': email,
          'p_password': password, // El nombre del parámetro ya es correcto, lo mantengo para claridad.
        },
      );

      if (mounted) {
        final data = result as Map<String, dynamic>? ?? {};
        _logService.log('Respuesta de Supabase: ${data.toString()}');

        if (data['success'] == true) {
          final profiles = List<Map<String, dynamic>>.from(data['profiles'] ?? []);

          if (profiles.isEmpty) {
            _logService.log('Error: Login exitoso pero sin perfiles de organización.');
            AppDialogs.showErrorDialog(context, 'No tienes asignada ninguna organización.');
          } else if (profiles.length == 1) {
            // Caso 1: Solo una organización, procedemos como antes.
            _logService.log('Login exitoso con un solo perfil.');
            _navigateToApp(profiles.first);
          } else {
            // Caso 2: Múltiples organizaciones, mostramos el selector.
            _logService.log('Múltiples perfiles detectados. Mostrando selector.');
            await _showOrganizationSelector(profiles);
          }
        } else {
          _logService.log('Fallo el login: ${data['message']?.toString()}');
          AppDialogs.showErrorDialog(context, data['message']?.toString() ?? 'Error desconocido');
        }
      }
    } catch (error) {
      _logService.log('Excepción capturada durante el login: ${error.toString()}');
      if (mounted) {
        AppDialogs.showErrorDialog(context, error.toString(), title: 'Error inesperado');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _navigateToApp(Map<String, dynamic> userProfile) async {
    final user = UserModel.fromJson(userProfile);
    AppState.currentUser = user;

    // Cargamos los parámetros de la organización seleccionada.
    try {
      final response = await Supabase.instance.client.rpc(
        'manage_org_parameters',
        params: {'p_action': 'list', 'p_org_id': user.organizationId},
      );

      // La función devuelve una lista de parámetros. La procesamos para crear un mapa.
      if (response is List) {
        final Map<String, dynamic> loadedParams = {};
        for (final param in response) {
          if (param is Map<String, dynamic>) {
            final paramId = param['parameter_id'] as String?;
            final dataType = param['data_type'] as String?;
            if (paramId != null && dataType != null) {
              // Asignamos el valor correcto según el tipo de dato.
              switch (dataType) {
                case 'boolean':
                  loadedParams[paramId] = param['value_boolean'];
                  break;
                case 'integer':
                  loadedParams[paramId] = param['value_integer'];
                  break;
                // Añadir más casos según los tipos de datos que uses.
                default:
                  loadedParams[paramId] = param['value_text'];
              }
            }
          }
        }
        AppState.organizationParameters = loadedParams;
        _logService.log('Parámetros de organización cargados: ${AppState.organizationParameters}');
      } else {
        _logService.log('Respuesta inesperada al cargar parámetros. Usando valores por defecto.');
        AppState.organizationParameters = {};
      }
    } catch (e) {
      _logService.log('Error al cargar parámetros de organización: $e. Usando valores por defecto.');
      AppState.organizationParameters = {}; // Resetear a vacío en caso de error.
      AppState.organizationTimeZone = 'UTC'; // Fallback
    }

    _logService.log('Navegando a la app. Rol del usuario: ${user.role}');

    if (user.role.toLowerCase() == 'resident') {
      // Reemplazamos toda la pila de navegación para forzar un refresco completo de la app.
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const MenuPage()),
        (Route<dynamic> route) => false, // Este predicado elimina todas las rutas anteriores.
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => RestrictedAccessScreen(
            userName: user.name,
            organizationName: user.organizationName,
          ),
        ),
      );
    }
  }

  Future<void> _showOrganizationSelector(List<Map<String, dynamic>> profiles) async {
    int? selectedIndex;

    // Ocultar el teclado si está abierto
    FocusScope.of(context).unfocus();

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        // Envolvemos el diálogo en nuestro AppBackground para mantener la consistencia visual.
        return AppBackground(
          child: Dialog(
            backgroundColor: Colors.transparent,
            elevation: 0,
            child: GlassCard(
              child: StatefulBuilder(
                builder: (context, setStateInDialog) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Selecciona tu Organización', style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 16),
                      ...List.generate(profiles.length, (index) {
                        final profile = profiles[index];
                        final orgName = profile['organization_name'] ?? 'Organización Desconocida';
                        final isSelected = selectedIndex == index;

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                          child: SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () {
                                setStateInDialog(() {
                                  selectedIndex = index;
                                });
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isSelected ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.surface.withOpacity(0.8),
                                foregroundColor: isSelected ? Theme.of(context).colorScheme.onPrimary : Theme.of(context).colorScheme.onSurface,
                              ),
                              child: Text(orgName),
                            ),
                          ),
                        );
                      }),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            style: TextButton.styleFrom(
                              foregroundColor: Theme.of(context).colorScheme.onSurface,
                            ),
                            onPressed: () => Navigator.of(dialogContext).pop(),
                            child: const Text('Cancelar'),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: selectedIndex == null ? null : () {
                              final selectedProfile = profiles[selectedIndex!];
                              _logService.log('Usuario seleccionó la organización: ${selectedProfile['organization_name']}');
                              Navigator.of(dialogContext).pop();
                              _navigateToApp(selectedProfile);
                            },
                            child: const Text('Ingresar'),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AppBackground(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: GlassCard(
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GestureDetector(
                        onTap: () {
                          setState(() => _logoTaps++);
                          if (_logoTaps >= 5) {
                            _logoTaps = 0;
                            Navigator.push(context, MaterialPageRoute(builder: (context) => const LogViewerScreen()));
                          }
                        },
                        child: Image.asset(
                          'assets/logo_login.png', // Usamos el logo específico para el login.
                          height: 60, // Reajustamos el tamaño al estar dentro
                        ),
                      ),
                      const SizedBox(height: 20),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextFormField(
                            controller: _emailController,
                            autofocus: true,
                            decoration: const InputDecoration(labelText: 'Correo electrónico', contentPadding: EdgeInsets.symmetric(vertical: 12, horizontal: 16)),
                            validator: (value) {
                              if (value == null || value.isEmpty || !value.contains('@')) {
                                return 'Ingrese un correo válido';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _passwordController,
                            decoration: const InputDecoration(labelText: 'Contraseña', contentPadding: EdgeInsets.symmetric(vertical: 12, horizontal: 16)),
                            obscureText: true,
                            onEditingComplete: _isLoading ? null : _login,
                          ),
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _login,
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 15),
                              ),
                              child: _isLoading
                                  ? const CircularProgressIndicator(color: Colors.white)
                                  : const Text("Ingresar"),
                            ),
                          ),
                          const SizedBox(height: 16), // Reducimos el espacio
                          // Usamos un Wrap para que los botones se ajusten si no caben en una línea
                          Wrap(
                            spacing: 12.0,
                            runSpacing: 8.0,
                            alignment: WrapAlignment.center,
                            children: [
                              ElevatedButton(
                                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ForgotPasswordScreen())),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: theme.colorScheme.surface.withOpacity(0.8),
                                  foregroundColor: theme.colorScheme.onSurface,
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  textStyle: theme.textTheme.bodySmall,
                                ),
                                child: const Text('Olvidé mi contraseña'),
                              ),
                              ElevatedButton(
                                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SignUpScreen())),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: theme.colorScheme.surface.withOpacity(0.8),
                                  foregroundColor: theme.colorScheme.onSurface,
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  textStyle: theme.textTheme.bodySmall,
                                ),
                                child: const Text('Crear Usuario'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          Text(
                            '© ${DateTime.now().year} Infosoft',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.7),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
