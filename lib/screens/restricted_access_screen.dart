import 'package:flutter/material.dart';
import '../models/app_state.dart';

class RestrictedAccessScreen extends StatelessWidget {
  final String userName;
  final String organizationName;

  const RestrictedAccessScreen({
    super.key,
    required this.userName,
    required this.organizationName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'web/favicon.png',
                height: 100,
              ),
              const SizedBox(height: 16),
              Text(
                'Hola, $userName',
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              Text(
                organizationName,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              Text(
                'Acceso Restringido',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              const Text(
                'Esta aplicación móvil está diseñada exclusivamente para usuarios con perfil de Residente.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 8),
              const Text(
                'Por favor, comuníquese con el administrador de su condominio para más información.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () {
                  // Cierra esta pantalla y vuelve a la de login
                  Navigator.of(context).pop();
                },
                child: const Text('Cerrar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}