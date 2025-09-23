import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flexisuite_web/models/app_state.dart'; // Assuming this path

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
    await Future.delayed(Duration.zero); // Ensure widget is mounted

    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      final AuthChangeEvent event = data.event;
      final Session? session = data.session;

      if (event == AuthChangeEvent.signedIn && session != null) {
        // Assuming AppState.currentUser is set in LoginScreen or similar
        // If not, you might need to fetch user data here
        _navigateToMenu();
      } else if (event == AuthChangeEvent.signedOut) {
        AppState.currentUser = null; // Clear current user on sign out
        _navigateToLogin();
      } else if (event == AuthChangeEvent.initialSession && session != null) {
        // Handle initial session if user is already logged in
        _navigateToMenu();
      } else if (event == AuthChangeEvent.initialSession && session == null) {
        // No initial session, navigate to login
        _navigateToLogin();
      }
    });
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
