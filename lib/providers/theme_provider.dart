import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flexisuite_shared/flexisuite_shared.dart';

/// Enum para las opciones de tema que verá el usuario.
enum AppThemeOption {
  light,
  dark,
  flexiSuite,
}

class ThemeProvider with ChangeNotifier {
  AppThemeOption _appTheme = AppThemeOption.flexiSuite;

  static const String _themeKey = 'appTheme';

  ThemeProvider() {
    _loadTheme();
  }

  AppThemeOption get appTheme => _appTheme;

  ThemeMode get themeMode {
    switch (_appTheme) {
      case AppThemeOption.light:
        return ThemeMode.light;
      case AppThemeOption.dark:
        return ThemeMode.dark;
      case AppThemeOption.flexiSuite:
        return ThemeMode.system; // El tema FlexiSuite respeta el sistema
    }
  }

  AppPalette get appPalette {
    // Si el tema es FlexiSuite, usamos su paleta.
    // Para los temas Claro y Oscuro, usamos la paleta por defecto (neutral).
    return _appTheme == AppThemeOption.flexiSuite
        ? AppPalette.flexiSuite
        : AppPalette.neutral;
  }

  void setAppTheme(AppThemeOption theme) async {
    if (theme == _appTheme) return;

    _appTheme = theme;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    prefs.setInt(_themeKey, theme.index);
  }

  void _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final themeIndex = prefs.getInt(_themeKey) ?? AppThemeOption.flexiSuite.index;
    _appTheme = AppThemeOption.values[themeIndex];
    notifyListeners();
  }
}
