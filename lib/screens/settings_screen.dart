import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    return const _ThemeSettingsContent();
  }
}

/// Widget que contiene las opciones de configuración del tema.
class _ThemeSettingsContent extends StatelessWidget {
  const _ThemeSettingsContent();

  @override
  Widget build(BuildContext context) {
    // Obtenemos la instancia del ThemeProvider para leer y cambiar el tema.
    final themeProvider = Provider.of<ThemeProvider>(context);

    return ListView(
      padding: const EdgeInsets.all(16.0),
      shrinkWrap: true, // Para que funcione bien dentro de un diálogo
      children: [
        Text(
          'Apariencia',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        RadioListTile<AppThemeOption>(
          title: const Text('Claro'),
          subtitle: const Text('Interfaz siempre clara.'),
          value: AppThemeOption.light,
          groupValue: themeProvider.appTheme,
          onChanged: (value) => themeProvider.setAppTheme(value!),
        ),
        RadioListTile<AppThemeOption>(
          title: const Text('Oscuro'),
          subtitle: const Text('Interfaz siempre oscura.'),
          value: AppThemeOption.dark,
          groupValue: themeProvider.appTheme,
          onChanged: (value) => themeProvider.setAppTheme(value!),
        ),
        RadioListTile<AppThemeOption>(
          title: const Text('FlexiSuite'),
          subtitle: const Text('Se adapta al sistema con los colores de la marca.'),
          value: AppThemeOption.flexiSuite,
          groupValue: themeProvider.appTheme,
          onChanged: (value) => themeProvider.setAppTheme(value!),
        ),
      ],
    );
  }
}
