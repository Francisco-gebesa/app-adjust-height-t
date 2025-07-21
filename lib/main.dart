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
/// 1. Binding de Widgets y Splash Screen
/// 2. Permisos de la aplicación
/// 3. Firebase
/// 4. Orientación de pantalla
/// 5. Providers para estado global
Future<void> main() async {
  // 1. Asegurar que Flutter esté inicializado y mantener el splash screen
  final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  // 2. Solicitar permisos críticos al inicio
  await _requestInitialPermissions();

  // 3. Inicializar Firebase para la autenticación y otros servicios
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // 4. Forzar la orientación vertical para una experiencia consistente
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  // 5. Pequeña pausa para asegurar que el splash se muestre correctamente
  await Future.delayed(const Duration(seconds: 2));
  FlutterNativeSplash.remove();

  // 6. Iniciar la aplicación con todos los proveedores de estado
  runApp(
    MultiProvider(
      providers: [
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
    ),
  );
}

/// Función auxiliar para agrupar la solicitud de permisos.
Future<void> _requestInitialPermissions() async {
  // Estos permisos son solicitados al inicio para asegurar que las
  // funcionalidades del agente estén listas cuando se necesiten.
  await [
    Permission.camera,
    Permission.microphone,
  ].request();
}


class MyApp extends StatelessWidget {
  const MyApp({super.key});

  /// Actualiza el estilo de las barras de estado y navegación del sistema
  /// para que coincida con el tema actual de la aplicación (claro/oscuro).
  void _updateSystemUi(BuildContext context, ThemeController themeController) {
    final isDarkMode = themeController.themeMode == ThemeMode.dark ||
        (themeController.themeMode == ThemeMode.system &&
            MediaQuery.of(context).platformBrightness == Brightness.dark);

    final style = isDarkMode
        ? SystemUiOverlayStyle.light.copyWith(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: AppTheme.darkTheme.scaffoldBackgroundColor,
    )
        : SystemUiOverlayStyle.dark.copyWith(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: AppTheme.lightTheme.scaffoldBackgroundColor,
    );

    SystemChrome.setSystemUIOverlayStyle(style);
  }

  @override
  Widget build(BuildContext context) {
    // Escuchamos los cambios en los controladores de tema e idioma
    final themeController = Provider.of<ThemeController>(context);
    final languageController = Provider.of<LanguageController>(context);

    // Aplicamos el estilo de la UI del sistema cada vez que el widget se reconstruye
    _updateSystemUi(context, themeController);

    return ToastificationWrapper(
      child: MaterialApp(
        title: 'Gebesa Desk Controller',
        debugShowCheckedModeBanner: false,
        // Configuración de localización
        locale: languageController.currentLocale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        // Configuración de temas
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: themeController.themeMode,
        // Configuración de rutas
        initialRoute: AuthRoutes.checkAuth,
        routes: AppRoutes.getRoutes(),
        // Builder para aplicar un escalado de texto global
        builder: (context, child) {
          return MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: const TextScaler.linear(0.95),
            ),
            child: child!,
          );
        },
      ),
    );
  }
}