import 'package:flutter/material.dart';

/// Un widget reutilizable que aplica el fondo degradado estándar de la aplicación.
/// Se adapta automáticamente al modo claro y oscuro.
class AppBackground extends StatelessWidget {
  final Widget child;

  const AppBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    // Ahora el gradiente se basa en los colores del tema actual.
    final gradient = LinearGradient(
      colors: [
        theme.colorScheme.background,
        theme.colorScheme.surface, // Usamos el color de superficie para crear un gradiente sutil.
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    return Container(
      decoration: BoxDecoration(gradient: gradient),
      child: child,
    );
  }
}