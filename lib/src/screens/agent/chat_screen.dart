import 'dart:convert';
import 'dart:io';
import 'package:controller/src/api/token_manager.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:uuid/uuid.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  // --- Variables de estado ---
  final List<types.Message> _messages = [];
  final String _sessionId = const Uuid().v4();
  final _user = const types.User(id: 'user');
  final _bot = const types.User(id: 'bot', firstName: 'Ascend');
  final String _backendUrl = 'https://gebesa.app.n8n.cloud/webhook/c685cbe2-ea13-40f8-8dbc-0be198b';
  bool _isBotTyping = false;
  String _formattedDate = '';
  String _language = ''; // Idioma por defecto
  String _testInit = '';

  @override
  void initState() {
    super.initState();
    _initializeChat();
  }

  Future<void> _initializeChat() async {
     _language = await _getLanguage();
    if (_language == 'es') {
      _testInit = '¡Hola! Soy Ascend. ¿En qué puedo ayudarte hoy?';
    } else {
      _testInit = 'Hello! I am Ascend. How can I assist you today?';
    }
    _setFormattedDate();
    _addMessage(
      types.TextMessage(
        author: _bot,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        id: const Uuid().v4(),
        text: _testInit,
      ),
    );
  }

  // --- Funciones de Lógica ---

  void _setFormattedDate() {
    final now = DateTime.now();
    if (_language == 'es') {
      _formattedDate = DateFormat("d 'de' MMMM 'de' yyyy", 'es_ES').format(now);
    } else {
      _formattedDate = DateFormat("MMMM d, yyyy", 'en_US').format(now);
    }
  }

  void _addMessage(types.Message message) {
    if (mounted) {
      setState(() => _messages.insert(0, message));
    }
  }

  void _handleAttachmentPressed() {
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => SafeArea(
        child: SizedBox(
          height: 144,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _handleImageSelection();
                },
                icon: const Icon(Icons.photo_library),
                label: Text(_language == 'es' ? 'Elegir imágenes' : 'Choose images'),
              ),
              TextButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _handleFileSelection();
                },
                icon: const Icon(Icons.folder_open),
                label: Text(_language == 'es' ? 'Elegir documento' : 'Choose document'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<String?> _getJwtToken() async =>
    (await SharedPreferences.getInstance()).getString(TokenManager.TOKEN_KEY); // Asegúrate de que la KEY sea la correcta

  Future<String?> _loadUUID() async =>
      (await SharedPreferences.getInstance()).getString('sUUID') ?? 'noexiste';

  Future<int?> _getUserId() async =>
      (await SharedPreferences.getInstance()).getInt('id');

  Future<String> _getTimezone() async =>
      await FlutterTimezone.getLocalTimezone();
  
  Future<String> _getLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    final languageId = prefs.getInt('language') ?? 1;
    // Mapear el ID del idioma al código del idioma
    switch (languageId) {
      case 1:
        return 'es';
      case 2:
        return 'en';
      default:
        return 'es';
    }
  }

  Future<void> _handleImageSelection() async {
    final result = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (result == null) return;

    if (mounted) setState(() => _isBotTyping = true);

    final bytes = await result.readAsBytes();
    _addMessage(
      types.ImageMessage(
        author: _user,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        id: const Uuid().v4(),
        name: result.name,
        size: bytes.length,
        uri: result.path,
      ),
    );

    await _sendRequest(
      prompt: 'Analiza esta imagen, por favor.',
      imageBase64: base64Encode(bytes),
      mimeType: result.mimeType ?? 'image/jpeg',
    );
  }

  Future<void> _handleFileSelection() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'docx', 'txt'],
    );
    if (result == null || result.files.single.path == null) return;

    if (mounted) setState(() => _isBotTyping = true);

    final file = result.files.single;
    final bytes = await File(file.path!).readAsBytes();
    _addMessage(
      types.FileMessage(
        author: _user,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        id: const Uuid().v4(),
        name: file.name,
        size: file.size,
        uri: file.path!,
        mimeType: 'application/octet-stream',
      ),
    );

    final mimeType = switch (file.extension) {
      'pdf' => 'application/pdf',
      'docx' =>
          'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      _ => 'text/plain',
    };

    await _sendRequest(
      prompt:
          'Aquí tienes un documento llamado "${file.name}". Por favor, resúmelo o dime de qué trata.',
      fileBase64: base64Encode(bytes),
      fileMimeType: mimeType,
    );
  }

  Future<void> _handleSendPressed(types.PartialText message) async {
    final userMessage = types.TextMessage(
      author: _user,
      createdAt: DateTime.now().millisecondsSinceEpoch,
      id: const Uuid().v4(),
      text: message.text,
    );
    _addMessage(userMessage);

    if (mounted) setState(() => _isBotTyping = true);

    await _sendRequest(prompt: message.text);
  }

 Future<void> _sendRequest({
  required String prompt,
  String? imageBase64,
  String? mimeType,
  String? fileBase64,
  String? fileMimeType,
  }) async {
    try {
      // 1. Recuperamos todos los datos de sesión ANTES de enviar la petición
      final jwt = await _getJwtToken();
      final uuid = await _loadUUID();
      final userId = await _getUserId();
      final tz = await _getTimezone();
      final language = await _getLanguage();

      // Creamos el cuerpo de la petición
      final requestBody = {
        'session_id': _sessionId,
        'prompt': prompt,
        'image_base64': imageBase64,
        'image_mime_type': mimeType,
        'file_base64': fileBase64,
        'file_mime_type': fileMimeType,
        // 2. Añadimos los nuevos datos al mapa
        'jwt_token': jwt,
        'uuid': uuid,
        'user_id': userId,
        'timezone': tz,
        'language': language,
      };

      final response = await http.post(
        Uri.parse(_backendUrl),
        headers: {'Content-Type': 'application/json'},
        // 3. Enviamos el cuerpo completo en formato JSON
        body: jsonEncode(requestBody),
      );

      if (mounted) {
        if (response.statusCode == 200) {
          final responseBody = jsonDecode(utf8.decode(response.bodyBytes));
          _addMessage(
            types.TextMessage(
              author: _bot,
              createdAt: DateTime.now().millisecondsSinceEpoch,
              id: const Uuid().v4(),
              text: responseBody['output'],
            ),
          );
        } else {
          _addMessage(
            types.TextMessage(
              author: _bot,
              createdAt: DateTime.now().millisecondsSinceEpoch,
              id: const Uuid().v4(),
              text: _language == 'es' 
                ? 'Lo siento, algo salió mal. Por favor intenta de nuevo.'
                : 'Sorry, something went wrong. Please try again.',
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        _addMessage(
          types.TextMessage(
            author: _bot,
            createdAt: DateTime.now().millisecondsSinceEpoch,
            id: const Uuid().v4(),
            text: _language == 'es'
              ? 'No hay conexión a internet. Por favor verifica tu conexión.'
              : 'No internet connection. Please check your connection.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isBotTyping = false);
    }
  }

  // --- Construcción de la Interfaz de Usuario ---
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        scrolledUnderElevation: 1.0,
        elevation: 0.5,
        backgroundColor: theme.appBarTheme.backgroundColor,
        foregroundColor: theme.appBarTheme.iconTheme?.color,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ascend',
              style: TextStyle(
                fontFamily: 'Airbnb',
                fontWeight: FontWeight.w600,
                fontSize: 18,
                color: theme.textTheme.titleLarge?.color,
              ),
            ),
            if (_formattedDate.isNotEmpty)
              Text(
                _formattedDate,
                style: TextStyle(
                  fontFamily: 'Airbnb',
                  fontSize: 12,
                  color: theme.textTheme.bodySmall?.color?.withOpacity(0.7),
                ),
              ),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.only(bottom: 80.0),
        child: Chat(
          messages: _messages,
          onSendPressed: _handleSendPressed,
          onAttachmentPressed: _handleAttachmentPressed,
          user: _user,
          typingIndicatorOptions: TypingIndicatorOptions(
            typingUsers: _isBotTyping ? [_bot] : [],
          ),
          
          theme: DefaultChatTheme(
            backgroundColor: theme.scaffoldBackgroundColor,
            primaryColor: theme.primaryColor,
            secondaryColor: isDarkMode
                ? const Color(0xFF0FB5C3).withOpacity(0.1)
                : Colors.grey.withOpacity(0.1),
            // === CORRECCIÓN 1: Unificar color de fondo del input ===
            inputBackgroundColor: theme.scaffoldBackgroundColor,
            inputTextColor:
                theme.textTheme.bodyLarge?.color ?? Colors.black87,
            // === CORRECCIÓN 2: Modificar decoración del contenedor del input ===
            inputContainerDecoration: BoxDecoration(
              color: theme.scaffoldBackgroundColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.grey.withOpacity(0.5),
                width: 1.0,
              ),
              boxShadow: const [], // Quitar sombra para un look más limpio
            ),
            inputTextDecoration: InputDecoration(
              // Rellenamos el fondo para poder darle un color
              filled: true, 
              // ¡Lo hacemos transparente para que no tenga su propio color!
              fillColor: Colors.transparent, 
              // Le quitamos CUALQUIER borde
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              // Volvemos a poner el texto de placeholder porque lo hemos sobreescrito
              hintText: _language == 'es' ? 'Mensaje' : 'Message', 
              hintStyle: TextStyle(
                  color: Colors.grey.withOpacity(0.8),
                  fontFamily: 'Airbnb',
              ),
            ),
            inputPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            inputMargin:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            sendButtonIcon: Icon(Icons.send, color: theme.primaryColor),
            attachmentButtonIcon: Icon(Icons.attach_file,
                color: theme.iconTheme.color?.withOpacity(0.7)),
            sentMessageBodyTextStyle: const TextStyle(
                fontFamily: 'Airbnb', color: Colors.white, fontSize: 16),
            receivedMessageBodyTextStyle: TextStyle(
                fontFamily: 'Airbnb',
                color: theme.textTheme.bodyLarge?.color ?? Colors.black87,
                fontSize: 16),
            // === CORRECCIÓN 3: Asegurar bordes redondeados consistentes ===
            messageBorderRadius: 20.0,
            userNameTextStyle: TextStyle(
              fontFamily: 'Airbnb',
              color: theme.textTheme.bodyMedium?.color?.withOpacity(0.8),
              fontWeight: FontWeight.bold,
            ),
            userAvatarTextStyle: const TextStyle(
                fontFamily: 'Airbnb', color: Colors.white, fontSize: 12),
        
            typingIndicatorTheme: TypingIndicatorTheme(
              // 3 puntos
              animatedCirclesColor: isDarkMode ? Colors.white : Colors.black,
              animatedCircleSize: 6,                       // tamaño del punto
              // globo
              bubbleBorder: BorderRadius.circular(16),     // conserva el radio
              bubbleColor: Colors
                  .transparent,                            // <- ¡sin fondo!
              // contador de “+ N” (multi‑usuarios)
              countAvatarColor: theme.primaryColor,
              countTextColor: Colors.white,
              // estilo del texto “is typing…”
              multipleUserTextStyle: theme.textTheme.bodySmall!,
            ),  
          ),
        ),
      ),
    );
  }
}