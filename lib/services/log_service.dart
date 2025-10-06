import 'package:flutter/foundation.dart';

/// Un servicio simple de logging en memoria para depuración.
class LogService {
  // Implementación de Singleton
  static final LogService _instance = LogService._internal();
  factory LogService() => _instance;
  LogService._internal();

  final List<String> _logs = [];

  List<String> get logs => List.unmodifiable(_logs);

  void log(String message) {
    final logMessage = '[${DateTime.now().toIso8601String()}] $message';
    debugPrint(logMessage); // También imprime en la consola de depuración
    _logs.insert(0, logMessage); // Añade al principio para ver los más nuevos primero
  }

  void clear() {
    _logs.clear();
  }
}
