import 'package:flutter/material.dart';
import 'package:flexisuite_web/widgets/dynamic_menu_widget.dart';
import 'package:flexisuite_web/models/app_state.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // Import Supabase

class MenuPage extends StatefulWidget {
  const MenuPage({super.key}); // No longer requires features in constructor

  @override
  State<MenuPage> createState() => _MenuPageState();
}

class _MenuPageState extends State<MenuPage> {
  List<Map<String, dynamic>> _features = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchFeatures();
  }

  Future<void> _fetchFeatures() async {
    final user = AppState.currentUser;
    if (user == null) {
      // Handle case where user is not logged in (should not happen if SplashScreen works)
      setState(() {
        _isLoading = false;
      });
      return;
    }

    try {
      // Assuming a Supabase RPC function to get user features
      final response = await Supabase.instance.client.rpc(
        'get_user_plan_features', // Corrected RPC function name
        params: {'p_user_id': user.id}, // Only pass p_user_id as per previous usage
      );

      if (response != null && response is List) {
        setState(() {
          _features = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });
      } else {
        setState(() {
          _features = [];
          _isLoading = false;
        });
      }
    } catch (error) {
      print('Error fetching features: $error');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al cargar las características: $error')));
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = AppState.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: user != null
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(user.name, style: const TextStyle(fontSize: 16)),
                  Text(
                    '${user.organizationName} - ${user.role}',
                    style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                  ),
                ],
              )
            : const Text('Menú'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: DynamicMenuWidget(features: _features),
              ),
            ),
    );
  }
}
