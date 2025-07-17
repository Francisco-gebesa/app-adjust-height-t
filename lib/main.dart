/// Aplicación Controller - Punto de entrada principal
///
/// Esta aplicación permite controlar escritorios ajustables mediante Bluetooth
/// y gestionar rutinas de trabajo. Integra:
/// - Autenticación con Firebase
/// - Control Bluetooth de escritorios
/// - Gestión de rutinas y estadísticas
/// - Soporte multiidioma
/// - Temas claro/oscuro
import 'package:controller/src/controllers/statistics/statistics_controller.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:controller/firebase_options.dart';
import 'package:controller/routes/auth_routes.dart';
import 'package:controller/src/controllers/auth/auth_controller.dart';
import 'package:controller/src/controllers/network/connectivity_controller.dart';
import 'package:controller/src/controllers/user/user_controller.dart';
import 'package:controller/src/config/style/app_theme.dart';
import 'package:controller/src/controllers/desk/bluetooth_controller.dart';
import 'package:controller/src/controllers/desk/desk_controller.dart';
import 'package:controller/src/controllers/agent/agent_controller.dart';
import 'package:provider/provider.dart';
import 'package:toastification/toastification.dart';
import 'routes/app_routes.dart';
import 'src/controllers/routines/routine_controller.dart';
import 'src/controllers/settings/language_controller.dart';
import 'src/controllers/settings/measurement_controller.dart';
import 'src/controllers/settings/theme_controller.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:controller/src/controllers/desk/socket_io_controller.dart';
import 'package:permission_handler/permission_handler.dart';

/// Inicializa la aplicación y sus dependencias
///
/// Configura:
/// 1. Firebase
/// 2. Orientación de pantalla
/// 3. Splash screen nativo
/// 4. Providers para estado global
Future<void> main() async {
  // Inicialización del binding de Flutter
  var binding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: binding);

  // =========================================================================
  // === CAMBIO 1: El código de permisos ya estaba aquí, lo cual es perfecto. ===
  // === No se necesita añadir nada más aquí para los permisos.             ===
  // =========================================================================
  WidgetsFlutterBinding.ensureInitialized();
  await Permission.camera.request();
  await Permission.microphone.request();

  // Configuración de Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Forzar orientación vertical
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  // Delay para mostrar splash
  await Future.delayed(const Duration(seconds: 2));
  FlutterNativeSplash.remove();

  // Iniciar app con providers
  runApp(MultiProvider(
    providers: [
      // ... (Tus providers se mantienen exactamente igual)
      ChangeNotifierProvider(create: (_) => ThemeController()),
      ChangeNotifierProvider(create: (_) => LanguageController()),
      ChangeNotifierProvider(create: (_) => BluetoothController()),
      ChangeNotifierProvider(create: (_) => DeskController()),
      ChangeNotifierProvider(
        create: (context) => DeskSocketService(context.read<DeskController>()),
      ),
      ChangeNotifierProvider(create: (_) => MeasurementController()),
      ChangeNotifierProvider(create: (_) => UserController()),
      ChangeNotifierProvider(create: (_) => AuthController()),
      ChangeNotifierProvider(create: (_) => ConnectivityController()),
      ChangeNotifierProvider(create: (_) => RoutineController()),
      ChangeNotifierProvider(create: (_) => StatisticsController()),
      ChangeNotifierProvider(create: (_) => AgentController()),
    ],
    child: const MyApp(),
  ));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    var themeController = Provider.of<ThemeController>(context);
    var languageController = Provider.of<LanguageController>(context);

    // =========================================================================
    // === CAMBIO 2: Lógica para actualizar las barras del sistema dinámicamente ===
    // =========================================================================
    // Este código se ejecuta cada vez que el tema cambia, asegurando que
    // las barras del sistema siempre coincidan con el tema actual.

    // Determina si el modo oscuro está activo, respetando la configuración del sistema
    final isDarkMode = themeController.themeMode == ThemeMode.dark ||
        (themeController.themeMode == ThemeMode.system &&
            MediaQuery.of(context).platformBrightness == Brightness.dark);

    // Define el estilo de las barras basado en el tema
    final systemUiStyle = isDarkMode
        ? SystemUiOverlayStyle(
      // Para tema oscuro:
      statusBarColor: AppTheme.darkTheme.scaffoldBackgroundColor,
      statusBarIconBrightness: Brightness.light, // Iconos claros
      systemNavigationBarColor: AppTheme.darkTheme.scaffoldBackgroundColor,
      systemNavigationBarIconBrightness: Brightness.light, // Iconos claros
    )
        : SystemUiOverlayStyle(
      // Para tema claro:
      statusBarColor: AppTheme.lightTheme.scaffoldBackgroundColor,
      statusBarIconBrightness: Brightness.dark, // Iconos oscuros
      systemNavigationBarColor: AppTheme.lightTheme.scaffoldBackgroundColor,
      systemNavigationBarIconBrightness: Brightness.dark, // Iconos oscuros
    );

    // Aplica el estilo
    SystemChrome.setSystemUIOverlayStyle(systemUiStyle);

    return ToastificationWrapper(
      child: MaterialApp(
        builder: (BuildContext context, Widget? child) {
          return MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: const TextScaler.linear(0.95),
            ),
            child: child!,
          );
        },
        title: 'Gebesa Desk Controller',
        debugShowCheckedModeBanner: false,
        locale: languageController.currentLocale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: themeController.themeMode,
        initialRoute: AuthRoutes.checkAuth,
        routes: AppRoutes.getRoutes(),
      ),
    );
  }
}