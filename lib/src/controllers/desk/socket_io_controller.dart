import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:shared_preferences/shared_preferences.dart';
import './desk_controller.dart';
import '../../config/app_config.dart';
import '../../api/token_manager.dart';

class DeskSocketService extends ChangeNotifier {
  final DeskController desk;
  final String baseUrl = AppConfig.apiBaseUrl;

  io.Socket? _socket;
  bool _connected = false; // ← flag interno

  bool get isConnected => _connected;

  DeskSocketService(this.desk) {
    print('🏭 [DeskSocketService] Servicio creado para DeskController');
  }

  void connect({required String sUUID}) async {
    print('\n🔌 [DeskSocketService] ==== INICIANDO CONEXIÓN SOCKET.IO ====');
    print('🔌 [DeskSocketService] sUUID recibido: $sUUID');
    
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(TokenManager.TOKEN_KEY);
    print('🔌 [DeskSocketService] Token: ${token != null ? 'Presente (${token.substring(0, 10)}...)' : 'AUSENTE'}');
    
    print('🔌 [DeskSocketService] Conectando a: https://api.gebesa-app.com');
    print('🔌 [DeskSocketService] Path: /socket.io');
    print('🔌 [DeskSocketService] Transports: [websocket, polling]');
    
    _socket = io.io(
      'https://api.gebesa-app.com',
      io.OptionBuilder()
        .setPath('/socket.io')          // sin barra final extra
        .setTransports(['websocket', 'polling'])   // o deja polling + websocket si hay proxys
        .setQuery(token != null ? {'token': token} : {})
        .build(),
    );
    
    print('🔌 [DeskSocketService] Socket creado, configurando event listeners...');

    _socket!
      ..onConnect((_) {
        _connected = true;
        print('\n✅ [DeskSocketService] ¡¡SOCKET CONECTADO EXITOSAMENTE!!');
        print('📤 [DeskSocketService] Emitiendo evento joinDesk con sUUID: $sUUID');
        _socket!.emit('joinDesk', sUUID);
        print('✅ [DeskSocketService] joinDesk emitido');
        notifyListeners();
      })
      ..onDisconnect((_) {
        _connected = false;
        print('\n🛑 [DeskSocketService] Socket DESCONECTADO');
        notifyListeners();
      })
      ..onConnectError((e) {
        print('\n❗ [DeskSocketService] ERROR DE CONEXIÓN');
        print('❗ [DeskSocketService] Error: $e');
        print('❗ [DeskSocketService] Tipo: ${e.runtimeType}');
      })
      ..onError((e) {
        print('\n❗ [DeskSocketService] ERROR DEL SOCKET');
        print('❗ [DeskSocketService] Error: $e');
        print('❗ [DeskSocketService] Tipo: ${e.runtimeType}');
      })
      ..on('desk:height', (data) {
        print('\n📥 [DeskSocketService] ===== EVENTO desk:height RECIBIDO =====');
        print('📥 [DeskSocketService] Data completa: $data');
        print('📥 [DeskSocketService] Tipo de data: ${data.runtimeType}');
        
        try {
          // ⬇️ Cambio clave: convertimos a num y luego a int
          final target = (data['targetMm'] as num).toInt();
          final cmdId  = (data['cmdId']   as num).toInt();

          print('🎯 [DeskSocketService] targetMm parseado: $target mm');
          print('🎯 [DeskSocketService] cmdId parseado: $cmdId');
          print('🎯 [DeskSocketService] Llamando a desk.moveToHeight($target)...');

          desk.moveToHeight(target);
          
          print('📤 [DeskSocketService] Enviando ACK para cmdId: $cmdId');
          _socket!.emit('desk:ack', {'cmdId': cmdId});
          print('✅ [DeskSocketService] ACK enviado exitosamente');
          print('📥 [DeskSocketService] ===== FIN PROCESAMIENTO desk:height =====\n');
        } catch (e) {
          print('❌ [DeskSocketService] ERROR procesando desk:height');
          print('❌ [DeskSocketService] Error: $e');
          print('❌ [DeskSocketService] Stack trace: ${StackTrace.current}');
        }
      })
      ..connect();
    
    print('🔌 [DeskSocketService] Socket.connect() llamado');
    print('🔌 [DeskSocketService] Esperando conexión...\n');
  }

  @override
  void dispose() {
    _socket?.dispose();
    super.dispose();
  }
}
