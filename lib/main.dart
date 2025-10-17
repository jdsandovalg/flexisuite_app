import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/menu_page.dart'; // Import MenuPage
import 'package:flexisuite_shared/flexisuite_shared.dart';
import 'package:provider/provider.dart'; // Importar provider
import 'providers/theme_provider.dart'; // Importar nuestro ThemeProvider
import 'providers/i18n_provider.dart'; // Importar nuestro I18nProvider
import 'package:flutter_localizations/flutter_localizations.dart'; // Para los delegados de localización
import 'screens/signup_screen.dart'; // Importar la nueva pantalla
import 'package:timezone/data/latest.dart' as tzdata; // Importar para inicializar la base de datos de zonas horarias
import 'package:timezone/timezone.dart' as tz; // Importar para manejar zonas horarias
import 'package:flutter_native_timezone/flutter_native_timezone.dart'; // Importar para obtener la zona horaria nativa
import 'package:intl/date_symbol_data_local.dart'; // <-- 1. AÑADE ESTA LÍNEA

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializar la base de datos de zonas horarias
  tzdata.initializeTimeZones();
  // Establecer la zona horaria local por defecto (se usará si no se especifica una de organización)
  tz.setLocalLocation(tz.getLocation(await FlutterNativeTimezone.getLocalTimezone()));

  // --- INICIO: CAMBIO REQUERIDO ---
  // Inicializa los datos de formato de fecha para el idioma español.
  await initializeDateFormatting('es_ES', null); 
  // --- FIN: CAMBIO REQUERIDO ---

  await Supabase.initialize(
    url: 'https://webegmkgoelocauvwzzy.supabase.co', // reemplaza con tu URL de Supabase
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6IndlYmVnbWtnb2Vsb2NhdXZ3enp5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTc1MzkzNTcsImV4cCI6MjA3MzExNTM1N30.lCXN5XkQJMZRmupvzF5X0Yr-eWt4KUcdBW_sfMIkoAM', // reemplaza con tu anon key
  );

  // --- INICIO: Inicialización explícita de proveedores ---
  final i18nProvider = I18nProvider();
  await i18nProvider.init(); // Esperamos a que cargue los idiomas y traducciones
  // --- FIN: Inicialización explícita ---

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => ThemeProvider()),
        ChangeNotifierProvider.value(value: i18nProvider), // Usamos la instancia ya inicializada
      ],
      child: const FlexiSuiteApp(),
    ),
  );
}

class FlexiSuiteApp extends StatelessWidget {
  const FlexiSuiteApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Usamos un Consumer para que el MaterialApp se reconstruya cuando cambie el tema.
    return Consumer2<ThemeProvider, I18nProvider>(
      builder: (context, themeProvider, i18nProvider, child) {
        return MaterialApp(
          theme: AppTheme.getTheme(themeProvider.appPalette, Brightness.light), // Genera el tema claro dinámicamente
          darkTheme: AppTheme.getTheme(themeProvider.appPalette, Brightness.dark), // Genera el tema oscuro dinámicamente
          themeMode: themeProvider.themeMode, // Usar el modo del tema del provider
          // --- INICIO: Integración de i18n ---
          locale: i18nProvider.locale,
          supportedLocales: i18nProvider.supportedLocales, // Usamos la lista dinámica del provider
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          // --- FIN: Integración de i18n ---
          debugShowCheckedModeBanner: false, // Oculta la cinta de "Debug"
          title: 'FlexiSuite_App', // Título de la aplicación
          initialRoute: '/', // Restaurar la ruta inicial normal
          routes: {
            '/': (context) => const SplashScreen(),
            '/login': (context) => const LoginScreen(),
            '/menu': (context) => const MenuPage(),
            '/signup': (context) => const SignUpScreen(),
          },
        );
      },
    );
  }
}
