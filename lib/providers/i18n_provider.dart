import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class I18nProvider with ChangeNotifier {
  Locale _locale = const Locale('es'); // Idioma por defecto
  Map<String, dynamic> _translations = {};
  Map<String, String> _nativeLanguageNames = {}; // Para almacenar los nombres nativos
  List<Locale> _supportedLocales = [const Locale('es')]; // Inicia con un fallback

  Locale get locale => _locale;
  List<Locale> get supportedLocales => _supportedLocales;
  String getNativeLanguageName(String langCode) {
    return _nativeLanguageNames[langCode] ?? langCode.toUpperCase();
  }

  // Orquesta la inicialización: debe ser llamado explícitamente desde main.dart.
  Future<void> init() async {
    await _discoverLocales();
    // CORRECCIÓN: Cargamos el idioma y las traducciones directamente aquí.
    final prefs = await SharedPreferences.getInstance();
    final langCode = prefs.getString('language_code') ?? 'es';
    _locale = Locale(langCode);
    await _loadTranslations();
    // No es necesario notificar a los listeners aquí, ya que la UI aún no se ha construido.
  }

  // Cambia el idioma actual, carga las nuevas traducciones y guarda la preferencia.
  Future<void> setLocale(Locale newLocale) async {
    // La guarda ahora solo previene recargas innecesarias si el idioma ya está activo.
    if (_locale == newLocale) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language_code', newLocale.languageCode);

    _locale = newLocale;
    await _loadTranslations();
    notifyListeners(); // Notifica a los widgets para que se reconstruyan con el nuevo idioma.
  }

  // Carga el archivo JSON correspondiente al idioma actual.
  Future<void> _loadTranslations() async {
    try {
      String jsonString = await rootBundle.loadString('assets/locales/${_locale.languageCode}.json');
      _translations = json.decode(jsonString);
    } catch (e) {
      // Si el archivo no existe, cargamos el de español como fallback.
      String jsonString = await rootBundle.loadString('assets/locales/es.json');
      _translations = json.decode(jsonString);
    }
  }

  // Función de traducción que busca una clave como 'login.button'.
  String t(String key) {
    try {
      // Usamos un bucle 'for' en lugar de 'fold' para una navegación de mapa más segura.
      List<String> keys = key.split('.');
      dynamic currentValue = _translations;
      for (String k in keys) {
        if (currentValue is Map<String, dynamic>) {
          currentValue = currentValue[k];
        } else {
          // Si intentamos acceder a una clave en algo que no es un mapa, la clave no existe.
          return key;
        }
      }
      return currentValue is String ? currentValue : key;
    } catch (e) {
      return key; // Si la clave no se encuentra, devuelve la clave misma.
    }
  }

  // Descubre dinámicamente los idiomas disponibles leyendo los assets.
  Future<void> _discoverLocales() async {
    try {
      final manifestContent = await rootBundle.loadString('AssetManifest.json');
      final Map<String, dynamic> manifestMap = json.decode(manifestContent);

      final localePaths = manifestMap.keys
          .where((key) => key.startsWith('assets/locales/'))
          .where((key) => key.endsWith('.json'));

      final List<Locale> discoveredLocales = [];
      final Map<String, String> discoveredNames = {};

      for (final path in localePaths) {
        final langCode = path.split('/').last.replaceAll('.json', '');
        discoveredLocales.add(Locale(langCode));

        // Carga el archivo solo para obtener el nombre nativo.
        try {
          final jsonString = await rootBundle.loadString(path);
          final Map<String, dynamic> translations = json.decode(jsonString);
          final nativeName = translations['_meta']?['language']?['nativeName'] as String?;
          if (nativeName != null) {
            discoveredNames[langCode] = nativeName;
          }
        } catch (e) { /* Ignorar si el archivo no se puede leer o la clave no existe */ }
      }
      _supportedLocales = discoveredLocales;
      _nativeLanguageNames = discoveredNames;
    } catch (e) {
      // Si falla, nos quedamos con el fallback
      _supportedLocales = [const Locale('es')];
    }
  }
}