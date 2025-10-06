import 'dart:ui';
import 'package:flutter/material.dart';

/// Un widget reutilizable que crea una tarjeta con efecto "glassmorphism".
/// Se adapta al tema claro/oscuro.
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;

  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16.0),
    this.margin = const EdgeInsets.symmetric(vertical: 8),
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    // --- INICIO: Mejoras visuales para más "brillo" ---
    // Colores para el gradiente que simula el reflejo del cristal.
    final gradientStartColor = isDarkMode ? Colors.white.withOpacity(0.1) : Colors.white.withOpacity(0.3); // Reducida opacidad
    final gradientEndColor = isDarkMode ? Colors.white.withOpacity(0.02) : Colors.white.withOpacity(0.1); // Reducida opacidad
    // Color para el borde que define mejor la tarjeta.
    final borderColor = isDarkMode ? Colors.white.withOpacity(0.15) : Colors.white.withOpacity(0.3); // Reducida opacidad
    // --- FIN: Mejoras visuales ---

    return ClipRRect(
      borderRadius: BorderRadius.circular(16.0), // Usar el mismo radio que el CardTheme
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          margin: margin,
          padding: padding,
          decoration: BoxDecoration(
            // Usamos un gradiente en lugar de un color sólido para dar un efecto de brillo.
            gradient: LinearGradient(
              colors: [gradientStartColor, gradientEndColor],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            // Añadimos un borde sutil para que la tarjeta resalte más.
            border: Border.all(
              color: borderColor,
              width: 1.2,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}
