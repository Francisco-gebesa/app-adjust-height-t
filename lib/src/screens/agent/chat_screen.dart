// lib/src/screens/agent/chat_screen.dart

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:controller/src/api/token_manager.dart';
import 'package:controller/src/config/app_config.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:uuid/uuid.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
// LIBRERÍA NUEVA
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

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
  String _language = 'es';
  String _testInit = '';

  // --- Variables para Grabar Audio y UI (AHORA CON LA LIBRERÍA `record`) ---
  bool _isListening = false;
  final TextEditingController _textController = TextEditingController();
  // Se reemplaza FlutterSoundRecorder por AudioRecorder
  final AudioRecorder _audioRecorder = AudioRecorder();
  String? _path;
  final FocusNode _focusNode = FocusNode();
  final GlobalKey _actionsButtonKey = GlobalKey();
  bool _isActionsMenuVisible = false;

  @override
  void initState() {
    super.initState();
    _initializeChat();
    _focusNode.addListener(() {
      if (mounted) {
        if (!_focusNode.hasFocus && _isActionsMenuVisible) {
          _hideActionsMenu();
        }
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    // Se asegura de liberar los recursos de la nueva librería
    _audioRecorder.dispose();
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _initializeChat() async {
    // La inicialización es más simple, solo pedimos permisos
    await Permission.microphone.request();

    _language = await _getLanguage();
    _testInit = _language == 'es'
        ? '¡Hola! Soy Ascend. ¿En qué puedo ayudarte hoy?'
        : 'Hello! I am Ascend. How can I assist you today?';

    _setFormattedDate();
    _addMessage(
      types.TextMessage(
        author: _bot,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        id: const Uuid().v4(),
        text: _testInit,
      ),
    );
    if (mounted) setState(() {});
  }

  void _setFormattedDate() {
    final now = DateTime.now();
    _formattedDate = _language == 'es'
        ? DateFormat("d 'de' MMMM 'de' yyyy", 'es_ES').format(now)
        : DateFormat("MMMM d, yyyy", 'en_US').format(now);
  }

  void _addMessage(types.Message message) {
    if (mounted) setState(() => _messages.insert(0, message));
  }

  // ******************** FUNCIÓN _startListening REESCRITA CON `record` ********************
  Future<void> _startListening() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        final tempDir = await getTemporaryDirectory();
        _path = '${tempDir.path}/temp_audio.m4a';

        // La configuración para grabar en m4a es más directa
        const config = RecordConfig(encoder: AudioEncoder.aacLc, sampleRate: 16000, numChannels: 1);

        await _audioRecorder.start(config, path: _path!);
        if (mounted) {
          setState(() => _isListening = true);
        }
      }
    } catch (e) {
      print("Error starting recorder: $e");
    }
  }
  // ******************** FIN DE LA FUNCIÓN ********************

  // ******************** FUNCIÓN _stopListening REESCRITA CON `record` ********************
  Future<void> _stopListening() async {
    try {
      final recordedFilePath = await _audioRecorder.stop();
      if (mounted) {
        setState(() => _isListening = false);
      }
      if (recordedFilePath != null) {
        _path = recordedFilePath;
        await _transcribeAudio();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isListening = false);
      }
      print("Error stopping recorder: $e");
    }
  }
  // ******************** FIN DE LA FUNCIÓN ********************

  Future<void> _transcribeAudio() async {
    if (_path == null || _path!.isEmpty) {
      print("[TRANSCRIPTION_DEBUG] Path is null or empty. Aborting.");
      return;
    }

    final apiKey = AppConfig.apiWhisper;
    final url = Uri.parse('https://api.openai.com/v1/audio/transcriptions');
    final audioFile = File(_path!);

    print("[TRANSCRIPTION_DEBUG] Starting transcription for file: ${_path!}");

    try {
      if (!await audioFile.exists()) {
        print("[TRANSCRIPTION_DEBUG] Error: Audio file does not exist.");
        return;
      }

      final fileLength = await audioFile.length();
      print("[TRANSCRIPTION_DEBUG] Audio file found. Length: $fileLength bytes.");
      if (fileLength < 1000) { // Aumentamos un poco el umbral para m4a
        print("[TRANSCRIPTION_DEBUG] Error: Audio file too short. Aborting.");
        return;
      }

      print("[TRANSCRIPTION_DEBUG] Preparing request to Whisper API...");
      final request = http.MultipartRequest('POST', url)
        ..headers['Authorization'] = 'Bearer $apiKey'
        ..files.add(await http.MultipartFile.fromPath('file', audioFile.path))
        ..fields['model'] = 'whisper-1';

      print("[TRANSCRIPTION_DEBUG] Sending request...");
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      print("[TRANSCRIPTION_DEBUG] Received response. Status: ${response.statusCode}");

      if (response.statusCode == 200) {
        final responseBody = jsonDecode(response.body);
        final transcript = responseBody['text'];
        print("[TRANSCRIPTION_DEBUG] API Success. Transcript: '$transcript'");

        if (transcript != null) {
          if (mounted) {
            setState(() {
              _textController.text = transcript;
              print("[TRANSCRIPTION_DEBUG] Text controller updated.");
            });
          }
        } else {
          print("[TRANSCRIPTION_DEBUG] Transcript is null.");
        }
      } else {
        print("[TRANSCRIPTION_DEBUG] API Error. Body: ${response.body}");
        final errorText = _language == 'es'
            ? 'Error del servidor de audio. Código ${response.statusCode}.'
            : 'Audio server error. Code ${response.statusCode}.';
        _addMessage(types.TextMessage(author: _bot, id: const Uuid().v4(), text: errorText));
      }
    } catch (e) {
      print("[TRANSCRIPTION_DEBUG] Exception: $e");
      final errorText = _language == 'es'
          ? 'Ocurrió un error al procesar el audio.'
          : 'An error occurred while processing the audio.';
      _addMessage(types.TextMessage(author: _bot, id: const Uuid().v4(), text: errorText));
    } finally {
      if (await audioFile.exists()) {
        await audioFile.delete();
        print("[TRANSCRIPTION_DEBUG] Temp file deleted.");
      }
    }
  }

  Future<void> _handleSendPressed(types.PartialText message) async {
    if (message.text.trim().isEmpty) return;
    final userMessage = types.TextMessage(
      author: _user,
      createdAt: DateTime.now().millisecondsSinceEpoch,
      id: const Uuid().v4(),
      text: message.text,
    );
    _addMessage(userMessage);
    if (mounted) setState(() => _isBotTyping = true);
    _textController.clear();
    await _sendRequest(prompt: message.text);
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
      'docx' => 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      _ => 'text/plain',
    };
    await _sendRequest(
      prompt: _language == 'es'
          ? 'Aquí tienes un documento llamado "${file.name}". Por favor, resúmelo o dime de qué trata.'
          : 'Here is a document named "${file.name}". Please summarize it or tell me what it is about.',
      fileBase64: base64Encode(bytes),
      fileMimeType: mimeType,
    );
  }

  Future<void> _sendRequest({
    required String prompt,
    String? fileBase64,
    String? fileMimeType,
  }) async {
    try {
      final jwt = await _getJwtToken();
      final uuid = await _loadUUID();
      final userId = await _getUserId();
      final tz = await _getTimezone();
      final language = await _getLanguage();
      final requestBody = {
        'session_id': _sessionId,
        'prompt': prompt,
        'file_base64': fileBase64,
        'file_mime_type': fileMimeType,
        'jwt_token': jwt,
        'uuid': uuid,
        'user_id': userId,
        'timezone': tz,
        'language': language,
      };

      final response = await http.post(
        Uri.parse(_backendUrl),
        headers: {'Content-Type': 'application/json'},
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
      // Manejar error
    } finally {
      if (mounted) setState(() => _isBotTyping = false);
    }
  }

  Future<String?> _getJwtToken() async =>
      (await SharedPreferences.getInstance()).getString(TokenManager.TOKEN_KEY);
  Future<String?> _loadUUID() async =>
      (await SharedPreferences.getInstance()).getString('sUUID') ?? 'noexiste';
  Future<int?> _getUserId() async => (await SharedPreferences.getInstance()).getInt('id');
  Future<String> _getTimezone() async => await FlutterTimezone.getLocalTimezone();

  Future<String> _getLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    final languageId = prefs.getInt('language') ?? 1;
    switch (languageId) {
      case 1:
        return 'es';
      case 2:
        return 'en';
      default:
        return 'es';
    }
  }

  void _toggleActionsMenu() {
    if (_focusNode.hasFocus) {
      _focusNode.unfocus();
    }
    setState(() => _isActionsMenuVisible = !_isActionsMenuVisible);
  }

  void _hideActionsMenu() {
    if (_isActionsMenuVisible) {
      setState(() => _isActionsMenuVisible = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return SafeArea(
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          scrolledUnderElevation: 1.0,
          elevation: 0.5,
          backgroundColor: theme.appBarTheme.backgroundColor,
          foregroundColor: theme.appBarTheme.iconTheme?.color,
          centerTitle: true,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'Ascend',
                style: TextStyle(
                    fontFamily: 'Airbnb',
                    fontWeight: FontWeight.w600,
                    fontSize: 18,
                    color: theme.textTheme.titleLarge?.color),
              ),
              if (_formattedDate.isNotEmpty)
                Text(
                  _formattedDate,
                  style: TextStyle(
                      fontFamily: 'Airbnb',
                      fontSize: 12,
                      color: theme.textTheme.bodySmall?.color?.withOpacity(0.7)),
                ),
            ],
          ),
        ),
        body: GestureDetector(
          onTap: () {
            _focusNode.unfocus();
            _hideActionsMenu();
          },
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 85.0),
                child: Chat(
                  onAttachmentPressed: null,
                  messages: _messages,
                  onSendPressed: (message) => _handleSendPressed(message),
                  user: _user,
                  customBottomWidget: _buildCustomInputBar(),
                  typingIndicatorOptions: TypingIndicatorOptions(typingUsers: _isBotTyping ? [_bot] : []),
                  theme: DefaultChatTheme(
                    backgroundColor: Colors.transparent,
                    primaryColor: theme.primaryColor,
                    secondaryColor: isDarkMode ? const Color(0xFF2E3D46) : const Color(0xFFF0F4F7),
                    sentMessageBodyTextStyle: const TextStyle(fontFamily: 'Airbnb', color: Colors.white, fontSize: 16),
                    receivedMessageBodyTextStyle: TextStyle(
                        fontFamily: 'Airbnb',
                        color: theme.textTheme.bodyLarge?.color ?? Colors.black87,
                        fontSize: 16),
                    messageBorderRadius: 20.0,
                    userNameTextStyle: TextStyle(
                        fontFamily: 'Airbnb',
                        color: theme.textTheme.bodyMedium?.color?.withOpacity(0.8),
                        fontWeight: FontWeight.bold),
                    userAvatarTextStyle: const TextStyle(fontFamily: 'Airbnb', color: Colors.white, fontSize: 12),
                    typingIndicatorTheme: TypingIndicatorTheme(
                      bubbleColor: Colors.transparent,
                      animatedCirclesColor: isDarkMode ? Colors.white70 : Colors.black54,
                      animatedCircleSize: 5,
                      bubbleBorder: BorderRadius.circular(20.0),
                      countAvatarColor: theme.primaryColor,
                      countTextColor: theme.colorScheme.onPrimary,
                      multipleUserTextStyle: const TextStyle(fontFamily: 'Airbnb'),
                    ),
                  ),
                ),
              ),
              if (_isActionsMenuVisible) _buildActionsMenuOverlay(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCustomInputBar() {
    final theme = Theme.of(context);
    final hasFocus = _focusNode.hasFocus;

    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(color: theme.scaffoldBackgroundColor),
        child: Row(
          children: [
            Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: theme.brightness == Brightness.dark
                      ? const Color(0xFF2E3D46)
                      : const Color(0xFFF0F4F7),
                  borderRadius: BorderRadius.circular(24),
                  border: hasFocus ? Border.all(color: theme.primaryColor.withOpacity(0.8)) : null,
                  boxShadow: hasFocus
                      ? [
                    BoxShadow(
                      color: theme.primaryColor.withOpacity(0.3),
                      blurRadius: 4,
                      spreadRadius: 1,
                    )
                  ]
                      : [],
                ),
                child: Row(
                  children: [
                    if (_isListening)
                      Padding(
                        padding: const EdgeInsets.only(left: 12.0),
                        child: VoiceWaveVisualizer(color: theme.primaryColor),
                      ),
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(left: _isListening ? 8 : 16),
                        child: TextField(
                          focusNode: _focusNode,
                          controller: _textController,
                          readOnly: _isListening,
                          style: TextStyle(fontFamily: 'Airbnb', color: theme.textTheme.bodyLarge?.color),
                          decoration: InputDecoration(
                            hintText: _isListening
                                ? (_language == 'es' ? 'Grabando...' : 'Recording...')
                                : (_language == 'es' ? 'Escribe un mensaje...' : 'Type a message...'),
                            hintStyle: TextStyle(fontFamily: 'Airbnb', color: theme.textTheme.bodySmall?.color),
                            border: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            filled: false,
                            contentPadding: const EdgeInsets.symmetric(vertical: 14.0),
                          ),
                          onTap: _hideActionsMenu,
                          onSubmitted: (text) => _handleSendPressed(types.PartialText(text: text)),
                        ),
                      ),
                    ),
                    if (!_isListening)
                      IconButton(
                        key: _actionsButtonKey,
                        icon: Icon(Icons.add_circle_outline, color: theme.iconTheme.color?.withOpacity(0.7)),
                        onPressed: _toggleActionsMenu,
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            _isListening
                ? IconButton(
              icon: Icon(Icons.stop_circle, color: theme.primaryColor, size: 30),
              onPressed: _stopListening,
            )
                : IconButton(
              icon: Icon(Icons.send, color: theme.primaryColor),
              onPressed: () => _handleSendPressed(types.PartialText(text: _textController.text)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionsMenuOverlay() {
    final theme = Theme.of(context);
    final renderBox = _actionsButtonKey.currentContext!.findRenderObject() as RenderBox;
    final position = renderBox.localToGlobal(Offset.zero, ancestor: Overlay.of(context)!.context.findRenderObject());

    return Positioned(
      right: MediaQuery.of(context).size.width - position.dx - renderBox.size.width + 10,
      bottom: MediaQuery.of(context).size.height - position.dy + 10,
      child: Material(
        elevation: 8.0,
        borderRadius: BorderRadius.circular(12),
        color: theme.brightness == Brightness.dark ? const Color(0xFF384852) : Colors.white,
        child: Container(
          width: 200,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.mic, color: theme.primaryColor),
                title: Text(_language == 'es' ? 'Grabar voz' : 'Record voice',
                    style: const TextStyle(fontFamily: 'Airbnb')),
                onTap: () {
                  _hideActionsMenu();
                  _startListening();
                },
              ),
              ListTile(
                leading: Icon(Icons.attach_file, color: theme.primaryColor),
                title: Text(_language == 'es' ? 'Adjuntar archivo' : 'Attach file',
                    style: const TextStyle(fontFamily: 'Airbnb')),
                onTap: () {
                  _hideActionsMenu();
                  _handleFileSelection();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class VoiceWaveVisualizer extends StatefulWidget {
  final Color color;

  const VoiceWaveVisualizer({
    super.key,
    required this.color,
  });

  @override
  State<VoiceWaveVisualizer> createState() => _VoiceWaveVisualizerState();
}

class _VoiceWaveVisualizerState extends State<VoiceWaveVisualizer> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          size: const Size(40, 25),
          painter: WavePainter(
            animationValue: _controller.value,
            color: widget.color,
          ),
        );
      },
    );
  }
}

class WavePainter extends CustomPainter {
  final double animationValue;
  final Color color;

  WavePainter({required this.animationValue, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    for (int i = 0; i < 3; i++) {
      final path = Path();
      final waveHeight = 5.0 + (i * 3.0);
      final phaseShift = animationValue * 2 * pi * (i % 2 == 0 ? 1 : -1);

      path.moveTo(0, size.height / 2);
      for (double x = 0; x <= size.width; x++) {
        final y = size.height / 2 + waveHeight * sin(x * 0.2 + phaseShift);
        path.lineTo(x, y);
      }
      canvas.drawPath(path, paint..color = color.withOpacity(1.0 - i * 0.3));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}