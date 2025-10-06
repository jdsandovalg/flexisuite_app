import 'package:flutter/material.dart';

/// Una clase de utilidad para mostrar diálogos estandarizados en la aplicación.
class AppDialogs {
  /// Muestra un diálogo de error genérico.
  static Future<void> showErrorDialog(BuildContext context, String message, {String title = 'Error'}) {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SelectableText(message),
        actions: [
          TextButton(
            autofocus: true, // Pone el foco en el botón para poder presionar "Enter".
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  // Aquí se podrían añadir otros diálogos, como showConfirmationDialog, etc.
}