import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/menu_page.dart'; // Import MenuPage
import 'screens/signup_screen.dart'; // Importar la nueva pantalla

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://webegmkgoelocauvwzzy.supabase.co', // reemplaza con tu URL de Supabase
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6IndlYmVnbWtnb2Vsb2NhdXZ3enp5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTc1MzkzNTcsImV4cCI6MjA3MzExNTM1N30.lCXN5XkQJMZRmupvzF5X0Yr-eWt4KUcdBW_sfMIkoAM', // reemplaza con tu anon key
  );

  runApp(const FlexiSuiteApp());
}

class FlexiSuiteApp extends StatelessWidget {
  const FlexiSuiteApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false, // Oculta la cinta de "Debug"
      title: 'FlexiSuite_App', // Título de la aplicación
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(),
        '/login': (context) => const LoginScreen(),
        '/menu': (context) => const MenuPage(), // No longer pass features
        '/signup': (context) => const SignUpScreen(),
      },
    );
  }
}
