import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'package:controller/src/controllers/routines/routine_controller.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:controller/routes/app_routes.dart';
import 'package:controller/src/api/auth_api.dart';
import 'package:controller/src/api/error_handler.dart';
import 'package:controller/src/api/token_manager.dart';
import 'package:controller/src/api/user_api.dart';
import 'package:controller/src/data/models/user.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import '../../../routes/settings_routes.dart';
import '../../widgets/toast_service.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('Mensaje recibido en segundo plano: ${message.messageId}');
}

/// Controlador encargado de manejar toda la autenticación y gestión de usuarios.
///
/// Provee funcionalidades para:
/// * Registro e inicio de sesión con email/password
/// * Autenticación con Google y Apple
/// * Gestión del perfil de usuario
/// * Manejo de tokens y datos de sesión
/// * Gestión de notificaciones push
class AuthController with ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Estado del usuario
  User? _firebaseUser;
  UserModel? _userInfo;
  bool _isLoading = false;
  bool _isDeleting = false;
  String? _token;

  bool get isLoading => _isLoading;
  User? get firebaseUser => _firebaseUser;
  UserModel? get userInfo => _userInfo;
  String? get token => _token;

  //notifications
  /// Inicializa las notificaciones push para el usuario.
  ///
  /// Solicita permisos y configura los handlers para diferentes estados:
  /// * Primer plano (onMessage)
  /// * App abierta desde notificación (onMessageOpenedApp)
  /// * Segundo plano (onBackgroundMessage)
  ///
  /// [context] Contexto necesario para mostrar mensajes al usuario
  Future<void> initializeNotifications(BuildContext context) async {
    FirebaseMessaging messaging = FirebaseMessaging.instance;

    // Solicitar permisos
    NotificationSettings settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('Permisos otorgados para las notificaciones push');

      String? token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        print('FCM Token: $token');
        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setString('fcmToken', token);
        prefs.setBool('notificationsEnabled', true);

        final response = await AuthApi.registerFcmToken(token);
        if (!response['success']) {
          print('Error al registrar el token FCM');
        } else {
          print('Token FCM registrado correctamente');
        }
      }

      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        print('Mensaje recibido en primer plano: ${message.notification}');
        HapticFeedback.vibrate();
        if (message.notification!.title == 'Sedentarismo' ||
            message.notification!.title == 'Sedentary') {
          //No hacer nada
        } else {
          context.read<RoutineController>().stopRoutine();
          ToastService.showInfo(context, message.notification!.title!,
              description: message.notification!.body!,
              alignment: Alignment.topCenter,
              duration: const Duration(seconds: 2));
        }
      });

      //onMessageOpenedApp
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        print('Mensaje recibido al abrir la app: ${message.notification}');
        HapticFeedback.vibrate();
        if (message.notification!.title == 'Sedentarismo' ||
            message.notification!.title == 'Sedentary') {
          //No hacer nada
        } else {
          context.read<RoutineController>().stopRoutine();
          ToastService.showInfo(context, message.notification!.title!,
              description: message.notification!.body!,
              alignment: Alignment.topCenter,
              duration: const Duration(seconds: 2));
        }
      });

      //onBackgroundMessage
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    } else {
      print('Permisos denegados para las notificaciones push');
      SharedPreferences prefs = await SharedPreferences.getInstance();
      prefs.setBool('notificationsEnabled', false);
    }
  }


  /// Actualiza el estado de `isLoading` y notifica
  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  /// Actualiza el estado de `_isDeleting` y notifica
  void _setDeleting(bool value) {
    _isDeleting = value;
    notifyListeners();
  }

  /// Carga los datos del usuario desde `SharedPreferences`
  Future<void> loadUserData() async {
    _firebaseUser = _auth.currentUser;
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString('name');
    final email = prefs.getString('email');
    final id = prefs.getInt('id');
    final weight = prefs.getDouble('weight');
    final height = prefs.getDouble('height');
    final phoneNumber = prefs.getString('phoneNumber');
    final countryCode = prefs.getString('countryCode');
    _userInfo = UserModel(
        name: name,
        email: email,
        id: id,
        weight: weight,
        height: height,
        phoneNumber: phoneNumber,
        countryCode: countryCode);
    notifyListeners();
  }

  /// Guarda los datos del usuario en `SharedPreferences`
  ///
  /// Almacena en SharedPreferences:
  /// * Datos básicos del usuario (id, nombre, email)
  /// * Preferencias (unidades, idioma, tema)
  /// * Tokens de autenticación
  /// * Datos de rutinas y memorias
  ///
  /// [user] Respuesta del servidor con los datos del usuario
  Future<void> _saveUserData(UserResponse user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('id', user.user!.id!);
    await prefs.setString('name', user.user!.name!);
    await prefs.setString('email', user.user!.email!);
    await prefs.setDouble('weight', user.user!.weight ?? 0);
    await prefs.setDouble('height', user.user!.height ?? 0);
    await prefs.setInt('measurementUnit', user.user!.idMeasureType ?? 0);
    await prefs.setInt('language', user.user!.iIdLanguage ?? 1);
    await prefs.setInt('themeMode', user.user!.iViewMode ?? 1);
    await prefs.setBool(
        'sedentaryNotification', user.user!.bSedentaryNotification ?? false);
    _userInfo = user.user;
    if (user.token != null && user.refreshToken != null) {
      await TokenManager.saveTokens(
        token: user.token!.result!,
        tokenExpiry: DateTime.now().add(
          Duration(seconds: user.token!.expiresIn!),
        ),
        refreshToken: user.refreshToken!.result!,
        refreshTokenExpiry: DateTime.now().add(
          Duration(seconds: user.refreshToken!.expiresIn!),
        ),
      );
    }

    if (user.user!.objMemories != null) {
      List<ObjMemory> memories = user.user!.objMemories!;
      for (int i = 0; i < memories.length; i++) {
        if (memories[i].iOrder != null && memories[i].dHeightInch != null) {
          if (memories[i].iOrder == 1) {
            await prefs.setDouble('memory1', memories[i].dHeightInch!);
          }
          if (memories[i].iOrder == 2) {
            await prefs.setDouble('memory2', memories[i].dHeightInch!);
          }
          if (memories[i].iOrder == 3) {
            await prefs.setDouble('memory3', memories[i].dHeightInch!);
          }
        }
      }
    }

    if (user.user!.objRoutine != null) {
      ObjRoutine routine = user.user!.objRoutine!;
      await prefs.setInt('routineId', routine.iId!);
      await prefs.setInt('routineDuration', routine.iDurationSecondsTarget!);
      await prefs.setString(
          'routineStartTime', routine.dtStartDate!.toIso8601String());
    }

    if (user.user!.lastRoutine != null) {
      LastRoutine routine = user.user!.lastRoutine!;
      await prefs.setInt('routineId', routine.iId!);
      await prefs.setInt('routineDuration', routine.iDurationSeconds!);
    }
    notifyListeners();
  }

  /// Actualiza el nombre del usuario en el almacenamiento local.
  ///
  /// [name] Nuevo nombre del usuario
  Future<void> updateName(String name) async {
    _userInfo!.name = name;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('name', name);
    notifyListeners();
  }

  /// Borra los datos del usuario de `SharedPreferences`
  Future<void> _clearUserData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    _userInfo = null;
    _firebaseUser = null;
    notifyListeners();
  }

  /// Registro con email y contraseña en Firebase
  ///
  /// [email] Email del usuario
  /// [password] Contraseña del usuario
  /// [name] Nombre del usuario
  /// [context] Contexto para mostrar mensajes
  /// [countryCode] Código de país para el número de teléfono
  /// [phoneNumber] Número de teléfono del usuario
  ///
  /// Retorna true si el registro fue exitoso
  Future<bool> signUp(
      String email, String password, String name, BuildContext context,
      {String? countryCode, String? phoneNumber}) async {
    try {
      _setLoading(true);
      final userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);

      final response = await AuthApi.registerUser(
        name,
        email,
        userCredential.user!.uid,
        countryCode: countryCode,
        phoneNumber: phoneNumber,
      );

      // Debug print de la respuesta
      print('REGISTER RESPONSE: ${response['data']}');

      if (response['success']) {
        _firebaseUser = userCredential.user;
        await _auth.currentUser!.updateDisplayName(name);
        UserResponse userResponse = userResponseFromJson(response['data']);
        
        // Debug: Imprimir el token JWT
        if (userResponse.token != null) {
          print('\n🔐 ===== TOKEN JWT (Sign Up) =====');
          print('Token: ${userResponse.token!.result}');
          print('Expires in: ${userResponse.token!.expiresIn} seconds');
          
          // Decodificar y mostrar el contenido del JWT
          try {
            final decodedToken = JwtDecoder.decode(userResponse.token!.result!);
            print('Decoded JWT: ${json.encode(decodedToken)}');
          } catch (e) {
            print('Error decodificando JWT: $e');
          }
          print('🔐 =============================\n');
        }
        
        SharedPreferences prefs = await SharedPreferences.getInstance();
        prefs.setBool("newUser", true);
        await _saveUserData(userResponse);
        return true;
      } else {
        ToastService.showError(
            context,
            response['type'] != null
                ? ErrorHandler.getErrorMessage(response['type'], context)
                : json.decode(response['error'])['message']);
        userCredential.user!.delete();
        return false;
      }
    } on FirebaseAuthException catch (e) {
      ToastService.showError(
          context, _firebaseAuthErrorMessage(e.code, context));
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Inicio de sesión con email y contraseña en Firebase
  ///
  /// [email] Email del usuario
  /// [password] Contraseña del usuario
  /// [context] Contexto para mostrar mensajes
  ///
  /// Retorna true si el inicio de sesión fue exitoso
  Future<bool> login(
      String email, String password, BuildContext context) async {
    try {
      _setLoading(true);
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Verificar información en base de datos
      var response = await AuthApi.loginUser(email, userCredential.user!.uid);
      if (response['success']) {
        log(response['data'].toString());
        _firebaseUser = userCredential.user;
        SharedPreferences prefs = await SharedPreferences.getInstance();
        prefs.setBool("newUser", false);
        UserResponse userResponse = userResponseFromJson(response['data']);
        print(response['data']);
        
        // Debug: Imprimir el token JWT
        if (userResponse.token != null) {
          print('\n🔐 ===== TOKEN JWT =====');
          print('Token: ${userResponse.token!.result}');
          print('Expires in: ${userResponse.token!.expiresIn} seconds');
          
          // Decodificar y mostrar el contenido del JWT
          try {
            final decodedToken = JwtDecoder.decode(userResponse.token!.result!);
            print('Decoded JWT: ${json.encode(decodedToken)}');
          } catch (e) {
            print('Error decodificando JWT: $e');
          }
          print('🔐 ==================\n');
        }
        
        _userInfo = userResponse.user;
        await _saveUserData(userResponse);
        notifyListeners();
        return true;
      } else {
        ToastService.showError(
            context,
            response['type'] != null
                ? ErrorHandler.getErrorMessage(response['type'], context)
                : json.decode(response['error'])['message']);

        return false;
      }
    } on FirebaseAuthException catch (e) {
      ToastService.showError(
          context, _firebaseAuthErrorMessage(e.code, context));
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Realiza autenticación usando la cuenta de Google.
  ///
  /// [context] Contexto para mostrar mensajes
  ///
  /// Retorna true si la autenticación fue exitosa
  Future<bool> signInWithGoogle(BuildContext context) async {
    try {
      _setLoading(true);
      GoogleSignIn googleSignIn = GoogleSignIn();
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      if (googleUser != null) {
        UserCredential userCredential =
            await _auth.signInWithCredential(GoogleAuthProvider.credential(
          idToken: (await googleUser.authentication).idToken,
          accessToken: (await googleUser.authentication).accessToken,
        ));

        if (userCredential.user == null) {
          return false;
        }

        //if user is not registered
        if (userCredential.additionalUserInfo!.isNewUser) {
          final response = await AuthApi.registerUser(
              googleUser.displayName ?? googleUser.email,
              googleUser.email,
              googleUser.id);

          if (response['success']) {
            UserResponse userResponse = userResponseFromJson(response['data']);
            await _saveUserData(userResponse);
            SharedPreferences prefs = await SharedPreferences.getInstance();
            prefs.setBool("newUser", true);
            Navigator.pushNamedAndRemoveUntil(
                context, SettingsRoutes.tutorial, (route) => false);

            return true;
          } else {
            ToastService.showError(
                context,
                response['type'] != null
                    ? ErrorHandler.getErrorMessage(response['type'], context)
                    : json.decode(response['error'])['message']);
            return false;
          }
        } else {
          //if user is already registered
          final response =
              await AuthApi.loginUser(googleUser.email, googleUser.id);

          if (response['success']) {
            UserResponse userResponse = userResponseFromJson(response['data']);
            print(response['data']);
            
            // Debug: Imprimir el token JWT
            if (userResponse.token != null) {
              print('\n🔐 ===== TOKEN JWT (Google Login) =====');
              print('Token: ${userResponse.token!.result}');
              print('Expires in: ${userResponse.token!.expiresIn} seconds');
              
              // Decodificar y mostrar el contenido del JWT
              try {
                final decodedToken = JwtDecoder.decode(userResponse.token!.result!);
                print('Decoded JWT: ${json.encode(decodedToken)}');
              } catch (e) {
                print('Error decodificando JWT: $e');
              }
              print('🔐 ================================\n');
            }
            
            SharedPreferences prefs = await SharedPreferences.getInstance();
            prefs.setBool("newUser", false);
            await _saveUserData(userResponse);
            Navigator.pushNamedAndRemoveUntil(
                context, AppRoutes.home, (route) => false);
            return true;
          } else {
            ToastService.showError(
                context,
                response['type'] != null
                    ? ErrorHandler.getErrorMessage(response['type'], context)
                    : json.decode(response['error'])['message']);
            return false;
          }
        }
      } else {
        return false;
      }
    } finally {
      _setLoading(false);
    }
  }

  /// Realiza autenticación usando la cuenta de Apple.
  ///
  /// [context] Contexto para mostrar mensajes
  ///
  /// Retorna true si la autenticación fue exitosa
  Future<bool> signInWithApple(BuildContext context) async {
    try {
      _setLoading(true);
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      final OAuthProvider oAuthProvider = OAuthProvider('apple.com');
      final credential = oAuthProvider.credential(
        idToken: appleCredential.identityToken,
        accessToken: appleCredential.authorizationCode,
      );

      final userCredential = await _auth.signInWithCredential(credential);

      if (userCredential.user == null) {
        return false;
      }

      final identityToken = appleCredential.identityToken;
      String? email;

      //if user is not registered
      if (userCredential.additionalUserInfo!.isNewUser) {
        if (identityToken != null) {
          final data = JwtDecoder.decode(identityToken);
          email = data['email'] as String?;
        }

        final response = await AuthApi.registerUser(
            appleCredential.givenName ?? email!.split('@').first,
            email ?? appleCredential.email!,
            appleCredential.userIdentifier!);

        if (response['success']) {
          UserResponse userResponse = userResponseFromJson(response['data']);
          await _saveUserData(userResponse);
          SharedPreferences prefs = await SharedPreferences.getInstance();
          prefs.setBool("newUser", true);
          Navigator.pushNamedAndRemoveUntil(
              context, SettingsRoutes.tutorial, (route) => false);
          return true;
        } else {
          ToastService.showError(
              context,
              response['type'] != null
                  ? ErrorHandler.getErrorMessage(response['type'], context)
                  : json.decode(response['error'])['message']);
          return false;
        }
      } else {
        if (identityToken != null) {
          final data = JwtDecoder.decode(identityToken);
          email = data['email'] as String?;
        }
        //if user is already registered
        final response = await AuthApi.loginUser(
            email ?? appleCredential.email!, appleCredential.userIdentifier!);

        if (response['success']) {
          UserResponse userResponse = userResponseFromJson(response['data']);
          await _saveUserData(userResponse);
          SharedPreferences prefs = await SharedPreferences.getInstance();
          prefs.setBool("newUser", false);
          Navigator.pushNamedAndRemoveUntil(
              context, AppRoutes.home, (route) => false);
          return true;
        } else {
          ToastService.showError(
              context,
              response['type'] != null
                  ? ErrorHandler.getErrorMessage(response['type'], context)
                  : json.decode(response['error'])['message']);
          return false;
        }
      }
    } finally {
      _setLoading(false);
    }
  }

  /// Cierra la sesión del usuario actual.
  ///
  /// Limpia los datos locales y cierra sesión en Firebase.
  Future<void> logout() async {
    await _clearUserData();
    await _auth.signOut();
  }

  /// Cambia el nombre del usuario actual.
  ///
  /// [newName] Nuevo nombre del usuario
  /// [context] Contexto para mostrar mensajes
  Future<void> changeName(String newName, BuildContext context) async {
    try {
      _setLoading(true);
      await _auth.currentUser!.updateDisplayName(newName);
      final response = await AuthApi.updateUserInfo(name: newName);

      if (response['success']) {
        await updateName(newName);
      } else {
        if (context.mounted) {
          ToastService.showError(
              context,
              response['type'] != null
                  ? ErrorHandler.getErrorMessage(response['type'], context)
                  : json.decode(response['error'])['message']);
        }
      }
    } finally {
      _setLoading(false);
    }
  }

  /// Envía un email para restablecer la contraseña.
  ///
  /// [email] Email del usuario
  /// [context] Contexto para mostrar mensajes
  Future<void> sendPasswordResetEmail(
      String email, BuildContext context) async {
    try {
      _setLoading(true);
      await _auth.sendPasswordResetEmail(email: email);
      if (context.mounted) {
        ToastService.showSuccess(
            context, AppLocalizations.of(context)!.resetPasswordEmailSent);
      }
    } on FirebaseAuthException catch (e) {
      if (context.mounted) {
        ToastService.showError(
            context, _firebaseAuthErrorMessage(e.code, context));
      }
    } finally {
      _setLoading(false);
    }
  }

  /// Actualiza el número de teléfono del usuario.
  ///
  /// [countryCode] Código de país (ej: +52)
  /// [phoneNumber] Número de teléfono sin código de país
  /// [context] Contexto para mostrar mensajes
  Future<void> updatePhoneNumber(
      String countryCode, String phoneNumber, BuildContext context) async {
    try {
      _setLoading(true);
      final currentUserName = _userInfo?.name ?? "";
      final response = await AuthApi.updatePhoneNumber(
        countryCode,
        phoneNumber,
        userName: currentUserName,
      );
      final isSuccess =
          response['success'] == true || response['success'] == 'true';
      if (isSuccess) {
        _userInfo!.countryCode = countryCode;
        _userInfo!.phoneNumber = phoneNumber;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('countryCode', countryCode);
        await prefs.setString('phoneNumber', phoneNumber);

        ToastService.showSuccess(
            context, AppLocalizations.of(context)!.phoneNumberUpdated);
      } else {
        if (context.mounted) {
          ToastService.showError(
              context,
              response['message'] ??
                  AppLocalizations.of(context)!.errorUpdatingPhone);
        }
      }
    } catch (e) {
      if (context.mounted) {
        ToastService.showError(
            context, AppLocalizations.of(context)!.errorUpdatingPhone);
      }
    } finally {
      _setLoading(false);
      notifyListeners();
    }
  }

  /// Elimina la cuenta del usuario actual.
  ///
  /// [context] Contexto para mostrar mensajes
  ///
  /// Retorna true si la eliminación fue exitosa
  Future<bool> deleteAccount(BuildContext context) async {
    try {
      _setDeleting(true);
      final response = await AuthApi.deleteAccount();

      if (response['success']) {
        return true;
      } else {
        if (context.mounted) {
          ToastService.showError(
              context,
              response['type'] != null
                  ? ErrorHandler.getErrorMessage(response['type'], context)
                  : json.decode(response['error'])['message']);
        }
        return false;
      }
    } finally {
      _setDeleting(false);
    }
  }

  /// Traduce los códigos de error de Firebase a mensajes legibles.
  ///
  /// [code] Código de error de Firebase
  /// [context] Contexto para obtener traducciones
  ///
  /// Retorna el mensaje de error traducido
  String _firebaseAuthErrorMessage(String code, BuildContext context) {
    switch (code) {
      case 'email-already-in-use':
        return AppLocalizations.of(context)!.emailAlreadyInUse;
      case 'network-request-failed':
        return AppLocalizations.of(context)!.socketException;
      case 'wrong-password':
        return AppLocalizations.of(context)!.wrongPassword;
      case 'user-not-found':
        return AppLocalizations.of(context)!.userNotFound;
      case 'weak-password':
        return AppLocalizations.of(context)!.weakPassword;
      case 'INVALID_LOGIN_CREDENTIALS':
        return AppLocalizations.of(context)!.invalidLoginCredentials;
      case 'invalid-credential':
        return AppLocalizations.of(context)!.invalidLoginCredentials;
      case 'too-many-requests':
        return AppLocalizations.of(context)!.toManyRequests;
      default:
        return AppLocalizations.of(context)!.unknownException;
    }
  }
}
