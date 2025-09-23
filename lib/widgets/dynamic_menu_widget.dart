import 'package:flexisuite_web/screens/token_form_page.dart';
import 'package:flutter/material.dart';
import 'package:flexisuite_web/screens/profile_screen.dart';
import 'package:flexisuite_web/screens/incident_form_page.dart';
import 'package:flexisuite_web/screens/fee_payment_report_page.dart';

class DynamicMenuWidget extends StatelessWidget {
  final List<Map<String, dynamic>> features;

  const DynamicMenuWidget({super.key, required this.features});

  // Helper function to get IconData from string
  IconData _getIconData(String? iconName, String? featureCode) {
    // Prioritize iconName from DB
    if (iconName != null && iconName.isNotEmpty) {
      switch (iconName.toLowerCase()) {
        case 'qr': return Icons.qr_code;
        case 'people': return Icons.people;
        case 'incident': return Icons.report_problem; // Icono para incidentes
        case 'ticketnew': return Icons.receipt; // Assuming ticket
        case 'asignar': return Icons.assignment;
        case 'pago': return Icons.payment;
        case 'revisarcuotabanco': return Icons.account_balance; // Or Icons.credit_card
        case 'perfil': return Icons.person;
        case 'dashboard': return Icons.dashboard;
        case 'settings': return Icons.settings;
        case 'report': return Icons.bar_chart;
        case 'add': return Icons.add;
        case 'lock': return Icons.lock;
        case 'unlock': return Icons.lock_open;
        default:
          return Icons.circle_outlined; // Fallback for unknown iconName
      }
    }
    // Derive from featureCode if iconName is null/empty
    else if (featureCode != null && featureCode.isNotEmpty) {
      switch (featureCode.toLowerCase()) {
        case 'dash_view':
          return Icons.dashboard;
        case 'user_list':
          return Icons.people;
        case 'settings':
          return Icons.settings;
        case 'rep_sales':
          return Icons.bar_chart;
        case 'user_add':
          return Icons.person_add;
        default:
          return Icons.circle_outlined; // Fallback for unknown featureCode
      }
    }
    return Icons.circle_outlined; // Default if both are null/empty
  }

  @override
  Widget build(BuildContext context) {
    // Filtrar solo features por 'unlocked' y 'is_menu_item = true'
    final List<Map<String, dynamic>> filteredFeatures = features.where((feature) {
      final String? value = feature['value'] as String?;
      final bool? isMenuItem = feature['is_menu_item'] as bool?;
      return value == 'unlocked' && isMenuItem == true;
    }).toList();

    return GridView.builder(
      padding: const EdgeInsets.all(16.0),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2, // 2 columnas
        crossAxisSpacing: 16.0,
        mainAxisSpacing: 16.0,
        childAspectRatio: 1.0, // Hacer los elementos cuadrados
      ),
      itemCount: filteredFeatures.length,
      itemBuilder: (context, index) {
        final f = filteredFeatures[index];
        final String featureName = f['feature_name'] as String? ?? 'Feature sin nombre';
        final String featureCode = f['feature_code'] as String? ?? 'CODE_UNKNOWN';
        final String? iconName = f['icon_name'] as String?;

        return ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.surface, // Changed to surface
            foregroundColor: Theme.of(context).colorScheme.onSurface, // Changed to onSurface
            padding: const EdgeInsets.symmetric(vertical: 15.0, horizontal: 16.0), // Adjusted padding
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)), // Keep rounded corners
            elevation: 4.0, // Increased elevation to make it stand out
          ),
          onPressed: () {
            if (featureCode == 'profile_resident') {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ProfileScreen()),
              );
            } else if (featureCode == 'token_create_simple') {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const TokenFormPage()),
              );
            } else if (featureCode == 'ticket_create') {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const IncidentFormPage()),
              );
            } else if (featureCode == 'cuota_reportar_pago') {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const FeePaymentReportPage()),
              );
            } else {
              print('Navegar a: $featureCode');
              // Navigator.pushNamed(context, '/$featureCode');
            }
          },
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(_getIconData(iconName, featureCode), size: 48.0),
              const SizedBox(height: 8.0),
              Text(
                featureName,
                textAlign: TextAlign.center,
                style: TextStyle( // Changed to default ElevatedButton text style
                  color: Theme.of(context).colorScheme.onSurface, // Changed to onSurface
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
