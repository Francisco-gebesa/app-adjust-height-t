import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:uuid/uuid.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';

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
  final _bot = const types.User(id: 'bot', firstName: 'Clara');
  final String _backendUrl = 'http://192.168.20.52:8000/api/v1/chat';
  bool _isBotTyping = false;
  String _formattedDate = '';

  @override
  void initState() {
    super.initState();
    _setFormattedDate();
    _addMessage(
      types.TextMessage(
        author: _bot,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        id: const Uuid().v4(),
        text: '¡Hola! Soy Clara. ¿En qué puedo ayudarte hoy?',
      ),
    );
  }

  // --- Funciones de Lógica ---

  void _setFormattedDate() {
    final now = DateTime.now();
    _formattedDate = DateFormat("d 'de' MMMM 'de' yyyy", 'es_ES').format(now);
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
                label: const Text('Elegir imágenes'),
              ),
              TextButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _handleFileSelection();
                },
                icon: const Icon(Icons.folder_open),
                label: const Text('Elegir documento'),
              ),
            ],
          ),
        ),
      ),
    );
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
      final response = await http.post(
        Uri.parse(_backendUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'session_id': _sessionId,
          'prompt': prompt,
          'image_base64': imageBase64,
          'image_mime_type': mimeType,
          'file_base64': fileBase64,
          'file_mime_type': fileMimeType,
        }),
      );

      if (mounted) {
        if (response.statusCode == 200) {
          final responseBody = jsonDecode(utf8.decode(response.bodyBytes));
          _addMessage(
            types.TextMessage(
              author: _bot,
              createdAt: DateTime.now().millisecondsSinceEpoch,
              id: const Uuid().v4(),
              text: responseBody['reply'],
            ),
          );
        } else {
          _addMessage(
            types.TextMessage(
              author: _bot,
              createdAt: DateTime.now().millisecondsSinceEpoch,
              id: const Uuid().v4(),
              text: 'Lo siento, hubo un error. Código: ${response.statusCode}',
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
            text: 'Error de red. Asegúrate de que el backend esté corriendo.',
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
              hintText: 'Message', 
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
          ),
        ),
      ),
    );
  }
}



