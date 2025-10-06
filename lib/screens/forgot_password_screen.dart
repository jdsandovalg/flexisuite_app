import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/app_dialogs.dart'; // Importar diálogos estandarizados
import 'package:flexisuite_shared/flexisuite_shared.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _isLoading = false;
  final _apiService = ApiService(Supabase.instance.client);

  Future<void> _sendResetLink() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Usamos el servicio centralizado para la llamada a la API.
      await _apiService.requestPasswordReset(_emailController.text);

      // Independientemente del resultado, mostramos un mensaje genérico por seguridad.
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('Revisa tu correo'),
            content: const Text(
                'Si existe una cuenta con ese correo, hemos enviado un enlace para restablecer tu contraseña.'),
            actions: [
              TextButton(
                autofocus: true,
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
      // Aunque la función de backend está diseñada para no fallar,
      // si ocurre un error de red o inesperado, lo manejamos aquí.
      if (mounted) {
        AppDialogs.showErrorDialog(context, 'Ocurrió un error al procesar tu solicitud. Por favor, intenta de nuevo.');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Recuperar Contraseña'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: AppBackground(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: GlassCard(
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      const Text(
                          'Ingresa tu correo electrónico y te enviaremos un enlace para restablecer tu contraseña.'),
                      const SizedBox(height: 20),
                      TextFormField(
                        controller: _emailController,
                        autofocus: true,
                        decoration: const InputDecoration(labelText: 'Correo electrónico'),
                        validator: (value) {
                          if (value == null || value.isEmpty || !value.contains('@')) {
                            return 'Ingrese un correo válido';
                          }
                          return null;
                        },
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 30),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _sendResetLink,
                          style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 15)),
                          child: _isLoading
                              ? const CircularProgressIndicator(color: Colors.white)
                              : const Text('Enviar Enlace'),
                        ),
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