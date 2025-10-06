import 'package:flutter/material.dart';
import '../models/app_state.dart'; // Assuming this path

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _redirect();
  }

  Future<void> _redirect() async {
    // Esperamos un momento para que la UI se estabilice y para dar una sensación de carga.
    await Future.delayed(const Duration(seconds: 1));

    // Nuestra lógica es simple: si hay un usuario en el estado de la app, va al menú.
    // Si no, va al login. El login se encarga de poblar AppState.currentUser.
    if (AppState.currentUser != null) {
      _navigateToMenu();
    } else {
      _navigateToLogin();
    }
  }

  void _navigateToMenu() {
    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/menu');
    }
  }

  void _navigateToLogin() {
    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(), // Show a loading indicator
      ),
    );
  }
}
