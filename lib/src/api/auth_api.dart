import 'dart:async';
import 'dart:convert';
import 'package:controller/src/api/api_helper.dart';
import 'package:controller/src/api/token_manager.dart';
import 'package:controller/src/config/app_config.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Clase que gestiona las operaciones de autenticación a través de la API.
class AuthApi {
  /// URL base de la API, obtenida desde la configuración de la aplicación.
  static String baseUrl = AppConfig.apiBaseUrl;

  /// Registra un usuario en la aplicación.
  ///
  /// Parámetros:
  /// - `name`: Nombre del usuario.
  /// - `email`: Correo electrónico del usuario.
  /// - `password`: Contraseña del usuario.
  /// - `countryCode`: Código de país (opcional).
  /// - `phoneNumber`: Número de teléfono (opcional).
  ///
  /// Retorna un mapa con la respuesta de la API.
  static Future<Map<String, dynamic>> registerUser(
    String name,
    String email,
    String password, {
    String? countryCode,
    String? phoneNumber,
  }) async {
    final url = Uri.parse('${baseUrl}auth/register');

    // Crear el cuerpo de la solicitud
    final Map<String, dynamic> requestBody = {
      'sName': name,
      'sEmail': email,
      'sPassword': password,
    };

    // Añadir los campos opcionales si no son nulos
    if (countryCode != null && countryCode.isNotEmpty) {
      requestBody['sLada'] = '+$countryCode';
    }

    if (phoneNumber != null && phoneNumber.isNotEmpty) {
      requestBody['sPhoneNumber'] = phoneNumber;
    }

    // Debug print de la petición
    print('REGISTER REQUEST: ${json.encode(requestBody)}');

    final response = await ApiHelper.handleRequest(
      http.post(
        url,
        body: json.encode(requestBody),
        headers: {'Content-Type': 'application/json'},
      ),
    );
    return response;
  }

  /// Inicia sesión con las credenciales del usuario.
  ///
  /// Parámetros:
  /// - `email`: Correo electrónico del usuario.
  /// - `password`: Contraseña del usuario.
  ///
  /// Retorna un mapa con la respuesta de la API.
  static Future<Map<String, dynamic>> loginUser(
    String email,
    String password,
  ) async {
    final url = Uri.parse('${baseUrl}auth/login');
    final response = await ApiHelper.handleRequest(
      http.post(
        url,
        body: json.encode({'sEmail': email, 'sPassword': password}),
        headers: {'Content-Type': 'application/json'},
      ),
      isLoginRequest: true, // Indica que es una solicitud de inicio de sesión.
    );
    return response;
  }

  /// Actualiza el nombre del usuario autenticado.
  ///
  /// Parámetros:
  /// - `newName`: Nuevo nombre del usuario.
  ///
  /// Retorna un mapa con la respuesta de la API.
  static Future<Map<String, dynamic>> updateUserName(String newName) async {
    return updateUserInfo(name: newName);
  }

  /// Actualiza la información del usuario (nombre y/o teléfono).
  ///
  /// Parámetros:
  /// - `name`: Nombre del usuario (opcional).
  /// - `countryCode`: Código de país (opcional, ej: +52).
  /// - `phoneNumber`: Número de teléfono sin código de país (opcional).
  ///
  /// Retorna un mapa con la respuesta de la API.
  static Future<Map<String, dynamic>> updateUserInfo({
    String? name,
    String? countryCode,
    String? phoneNumber,
  }) async {
    final url = Uri.parse('$baseUrl/session/user/updateinfo');
    final prefs = await SharedPreferences.getInstance();

    // Verifica si el token es válido antes de continuar.
    bool validToken = await ApiHelper.validateToken();
    if (!validToken) {
      return {'success': false, 'type': 'SESSION_EXPIRED'};
    }

    // Construir el body con los campos proporcionados
    Map<String, dynamic> body = {};
    
    // Si se está actualizando el teléfono pero no se proporciona nombre, 
    // intentar obtenerlo de SharedPreferences
    if (name != null) {
      body['sName'] = name;
    } else if ((countryCode != null || phoneNumber != null)) {
      // Si se actualiza el teléfono sin nombre, obtener el nombre actual
      final userInfo = prefs.getString('user_info');
      if (userInfo != null) {
        final userJson = json.decode(userInfo);
        final currentName = userJson['sName'];
        if (currentName != null) {
          body['sName'] = currentName;
        }
      }
    }
    
    if (countryCode != null && countryCode.isNotEmpty) {
      // Asegurar que el código de país tenga el formato correcto
      body['sLada'] = countryCode.startsWith('+') ? countryCode : '+$countryCode';
    }
    if (phoneNumber != null && phoneNumber.isNotEmpty) {
      body['sPhoneNumber'] = phoneNumber;
    }

    final token = prefs.getString(TokenManager.TOKEN_KEY);
    final response = await ApiHelper.handleRequest(
      http.post(
        url,
        body: json.encode(body),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token'
        },
      ),
    );
    
    return response;
  }

  /// Actualiza el número de teléfono del usuario.
  /// Intenta con diferentes formatos de campo para compatibilidad con el backend.
  static Future<Map<String, dynamic>> updatePhoneNumber(
      String countryCode, String phoneNumber, {String? userName}) async {
    final url = Uri.parse('$baseUrl/session/user/updateinfo');
    final prefs = await SharedPreferences.getInstance();

    // Verifica si el token es válido antes de continuar.
    bool validToken = await ApiHelper.validateToken();
    if (!validToken) {
      return {'success': false, 'type': 'SESSION_EXPIRED'};
    }

    // Usar el nombre proporcionado o intentar obtenerlo de SharedPreferences
    String? currentName = userName;
    if (currentName == null || currentName.isEmpty) {
      final userInfo = prefs.getString('user_info');
      if (userInfo != null) {
        final userJson = json.decode(userInfo);
        currentName = userJson['sName'];
      }
    }
    
    // Si aún no tenemos nombre, retornar error
    if (currentName == null || currentName.isEmpty) {
      return {
        'success': false, 
        'message': 'No se pudo obtener el nombre del usuario. Por favor, actualice su nombre primero.'
      };
    }

    // Formatear el código de país
    final formattedCountryCode = countryCode.startsWith('+') ? countryCode : '+$countryCode';

    // Intentar con el formato que usa el registro, SIEMPRE incluyendo el nombre
    Map<String, dynamic> body = {
      'sLada': formattedCountryCode,
      'sPhoneNumber': phoneNumber,
      'sName': currentName, // currentName nunca es null aquí
    };


    final token = prefs.getString(TokenManager.TOKEN_KEY);
    var response = await ApiHelper.handleRequest(
      http.post(
        url,
        body: json.encode(body),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token'
        },
      ),
    );

    
    // Verificar el statusCode para determinar el éxito
    final statusCode = response['statusCode'];
    final isSuccess = statusCode == 200 || statusCode == 201 || response['success'] == true;
    
    // Si la respuesta fue exitosa con sLada, retornar inmediatamente
    if (isSuccess) {
      // Asegurar que success sea true en la respuesta
      response['success'] = true;
      return response;
    }

    // Si no funciona con sLada, intentar con sCountryCode
    if (response['success'] != true) {
      body = {
        'sCountryCode': formattedCountryCode,
        'sPhoneNumber': phoneNumber,
        'sName': currentName, // currentName nunca es null aquí
      };


      response = await ApiHelper.handleRequest(
        http.post(
          url,
          body: json.encode(body),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token'
          },
        ),
      );

    }

    return response;
  }

  /// Registra el token de Firebase Cloud Messaging (FCM) para notificaciones push.
  ///
  /// Parámetros:
  /// - `fcmToken`: Token de FCM del dispositivo.
  ///
  /// Retorna un mapa con la respuesta de la API.
  static Future<Map<String, dynamic>> registerFcmToken(String fcmToken) async {
    final url = Uri.parse('${baseUrl}session/user/suscribe');
    final prefs = await SharedPreferences.getInstance();

    // Verifica si el token es válido antes de continuar.
    bool validToken = await ApiHelper.validateToken();
    if (!validToken) {
      return {'success': false, 'type': 'SESSION_EXPIRED'};
    }

    final token = prefs.getString(TokenManager.TOKEN_KEY);
    final response = await ApiHelper.handleRequest(
      http.post(
        url,
        body: json.encode({'sIdProvider': fcmToken}),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token'
        },
      ),
    );
    return response;
  }

  /// Elimina la cuenta del usuario autenticado.
  ///
  /// Retorna un mapa con la respuesta de la API.
  static Future<Map<String, dynamic>> deleteAccount() async {
    final url = Uri.parse('$baseUrl/session/user/delete');
    final prefs = await SharedPreferences.getInstance();

    // Verifica si el token es válido antes de continuar.
    bool validToken = await ApiHelper.validateToken();
    if (!validToken) {
      return {'success': false, 'type': 'SESSION_EXPIRED'};
    }

    final token = prefs.getString(TokenManager.TOKEN_KEY);
    final refreshToken = prefs.getString(TokenManager.REFRESH_TOKEN_KEY);

    // Extrae las últimas 5 letras del token de actualización.
    final deleteWord = refreshToken!.substring(refreshToken.length - 5);

    final response = await ApiHelper.handleRequest(
      http.delete(
        url,
        body: json.encode({
          'refreshToken': refreshToken,
          'deleteWord': deleteWord,
        }),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token'
        },
      ),
    );
    return response;
  }
}
