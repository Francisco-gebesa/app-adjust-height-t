import 'dart:async';
import 'package:controller/src/controllers/desk/socket_io_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:controller/src/api/desk_api.dart';
import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../routines/routine_controller.dart';
import 'desk_service_config.dart';

class DeskController extends ChangeNotifier {
  bool _wsStarted = false; // evita dobles conexiones
  late DeskSocketService socketSvc;

  // Bluetooth connection properties
  BluetoothDevice? device;
  int? rssi;
  int? mtuSize;
  BluetoothConnectionState? connectionState =
      BluetoothConnectionState.disconnected;
  List<BluetoothService> services = [];
  bool isDiscoveringServices = false;
  bool isConnecting = false;
  bool isDisconnecting = false;
  late StreamSubscription<BluetoothConnectionState> connectionStateSubscription;
  late StreamSubscription<int> mtuSubscription;

  // Bluetooth characteristics
  BluetoothCharacteristic? targetCharacteristic;
  BluetoothCharacteristic? deviceInfoCharacteristic;
  BluetoothCharacteristic? reportCharacteristic;

  // Height properties
  double heightMM = 0;
  double minHeightMM = 0;
  double maxHeightMM = 0;
  double? heightIN = 0.0;
  List<int> heightHex = [0x00, 0x00];
  String connectionText = "";

  // UI control properties
  bool isPressed = false;
  bool isPressedDown = false;
  Timer? upTimer;
  Timer? downTimer;
  late DeskServiceConfig _config;
  AnimationController? _controller;
  double minHeight = 0;
  double maxHeight = 0;
  double progress = 0;
  int currentIndex = 1;
  String? deviceName = "";
  bool deviceReady = false;

  // Memory positions
  bool memory1Configured = false;
  bool memory2Configured = false;
  bool memory3Configured = false;
  int memorySlot = 0;

  // Timers
  Timer? _noDataTimer;
  Timer? _stableTimer;
  bool isStable = true;
  bool firstConnection = true;

  // Getter para acceder a las características
  String get serviceUuid => _config.serviceUuid;

  DeskController() {
    loadSavedName();
    socketSvc = DeskSocketService(this); // ← ¡YA inicializado!
  }

  /// Loads the saved device name from SharedPreferences
  Future<void> loadSavedName() async {
    final prefs = await SharedPreferences.getInstance();
    final savedName = prefs.getString('device_name');
    if (savedName != null) {
      deviceName = savedName;
      notifyListeners();
    }
  }

  Future<void> reconnect() async {
    if (device != null) {
      try {
        await device!.connect();
        print("Dispositivo reconectado exitosamente.");
      } catch (e) {
        print("Error al reconectar: $e");
      }
    }
  }

  void setDevice(BluetoothDevice? newDevice) {
    device = newDevice;
    if (device != null) {
      deviceName = device!.advName;
    } else {
      deviceName = "";
      deviceReady = false;
    }
    notifyListeners();
  }

  void listenToConnectionState(TickerProvider vsync, BuildContext context) {
    if (device == null) {
      deviceReady = true;
      notifyListeners();
      return;
    }

    connectionStateSubscription = device!.connectionState.listen((state) async {
      connectionState = state;
      notifyListeners();

      if (state == BluetoothConnectionState.connected && device != null) {
        try {
          await _discoverServices(context);

          _controller = AnimationController(
            duration: const Duration(milliseconds: 300),
            vsync: vsync,
          )..addListener(() {
              currentIndex = 1 + ((_controller!.value * 59).floor());
              notifyListeners();
            });
        } catch (e) {
          print('Error en listenToConnectionState: $e');
        }
      }

      deviceReady = true;
      notifyListeners();
    });
  }

  Future<void> _discoverServices(BuildContext context) async {
    if (device == null) {
      print('❌ Error: device es nulo en _discoverServices');
      return;
    }

    try {
      print('🔍 Descubriendo servicios...');
      List<BluetoothService> services = await device!.discoverServices();
      print('✅ Servicios descubiertos: ${services.length}');

      for (BluetoothService service in services) {
        // Buscar la configuración que coincida con este servicio
        DeskServiceConfig? config =
            DeskServiceConfig.getConfigForService(service.uuid.str);

        if (config == null) {
          continue;
        }

        // Encontramos una configuración válida, asignamos las características
        for (BluetoothCharacteristic characteristic
            in service.characteristics) {
          String charUuid = characteristic.uuid.str;

          // Asignar característica de estado normal (control)
          if (config.normalStateUuids.contains(charUuid) ?? false) {
            targetCharacteristic = characteristic;
          }

          // Asignar característica de reporte de estado (altura)
          if (config.reportStateUuids.contains(charUuid) ?? false) {
            reportCharacteristic = characteristic;
            if (characteristic.properties.notify) {
              print('  ℹ️ Setting up notifications...');
              await _listenForNotifications(context);

              _sendInitialCommand();
            }
            Future.delayed(const Duration(milliseconds: 200), () {
              requestHeightRange();
              // Solicitar el estado actual del escritorio para obtener la altura
              requestCurrentStatus();
              // Activar la pantalla del escritorio
              _activateDisplay();
              deviceReady = true;
              notifyListeners();
            });
          }

          // Asignar característica de información del dispositivo
          if (config.deviceInfoUuids.contains(charUuid) ?? false) {
            deviceInfoCharacteristic = characteristic;
            //set notify value to true only if the characteristic is fe63
            if (charUuid == 'fe63') {
              await characteristic.setNotifyValue(true);
            }
          }
        }

        // Si encontramos las características necesarias, salimos del loop
        if (reportCharacteristic != null &&
            targetCharacteristic != null &&
            deviceInfoCharacteristic != null) {
          print(
              '✅ Características encontradas para el servicio ${service.uuid.str}');
          break;
        }
      }

      if (reportCharacteristic == null || targetCharacteristic == null) {
        print('❌ No se encontraron las características necesarias');
        throw Exception('No se encontraron las características necesarias');
      }
    } catch (e) {
      print('❌ Error descubriendo servicios: $e');
      // No relanzamos la excepción para evitar que la app se cierre
    }
  }

  Future<void> _listenForNotifications(BuildContext context) async {
    if (reportCharacteristic != null) {
      print('🔔 Iniciando escucha de notificaciones');
      print('🔔 Report characteristic: ${reportCharacteristic!.uuid.str}');

      //set notify value to true
      await reportCharacteristic!.setNotifyValue(true);

      reportCharacteristic!.onValueReceived.listen((event) async {
        //reset timer
        _resetNoDataTimer(context);
        _resetStableTimer();

        if (event[0] == 0xF2 && event[1] == 0xF2 && event[2] == 0x07) {
          // Extraer los valores
          int max = (event[4] << 8) | event[5]; // Altura máxima en mm
          int min = (event[6] << 8) | event[7]; // Altura mínima en mm

          minHeightMM = min.toDouble();
          maxHeightMM = max.toDouble();

          heightMM = inchesToMm(heightIN!);

          print('Altura máxima: ${max / 25.4} in');
          print('Altura mínima: ${min / 25.4} in');

          SharedPreferences prefs = await SharedPreferences.getInstance();
          prefs.setDouble('maxHeightDesk', max / 25.4);
          prefs.setDouble('minHeightDesk', min / 25.4);

          maxHeight = max / 25.4;
          minHeight = min / 25.4;

          progress =
              calculateProgressPercentage(heightIN!, minHeight, maxHeight);
          firstConnection = false;
          notifyListeners();
          return;
        }

        // Obtener los valores de los bytes de altura
        final dataH = event[4];
        final dataL = event[5];

        // Convertir a hexadecimal y luego a decimal
        final hex = dataH.toRadixString(16).padLeft(2, '0') +
            dataL.toRadixString(16).padLeft(2, '0');
        final decimal = int.parse(hex, radix: 16);

        // Asumimos que el valor está en milímetros y lo convertimos a pulgadas
        final distance = decimal /
            10; // Divide por 10 para convertir a pulgadas si está en décimas de pulgada

        // Actualizar `heightIN`
        heightIN = distance;
        heightHex = [dataH, dataL];

        // Verificar si la altura está dentro del rango esperado
        if (heightIN! < minHeight || heightIN! > maxHeight) {
          return;
        }

        heightMM = inchesToMm(heightIN!);
        if (!_wsStarted) {
          socketSvc.connect(
            sUUID: device!.remoteId.str,
            // token: token,
          );
          final prefs = await SharedPreferences.getInstance();
          prefs.setString('sUUID', device!.remoteId.str);
          _wsStarted = true;
          print("SI ENTRO");
          print("UUID: ${device!.remoteId.str} - Nombre: ${device!.advName}");
                      if (await InternetConnection().hasInternetAccess) {
            final registerResponse = await DeskApi.registerDeskDevice(
              deviceName ?? "Desk",
              device!.remoteId.str,
              "1",
              minHeightMM: minHeightMM,
              maxHeightMM: maxHeightMM,
            );
            print(registerResponse);
          }
          final response = await DeskApi.setNewUUID(device!.advName, device!.remoteId.str, minHeightMM, maxHeightMM);
          print(response);
          if (response["success"]) {
            print("advN actualizado correctamente.");
          } else {
            print("Error al actualizar el UUID: ${response["message"]}");
          }
          
          // Solicitar estado actual después de la conexión inicial
          Future.delayed(const Duration(milliseconds: 500), () {
            requestCurrentStatus();
          });
        }

        print("Altura actual: $heightIN pulgadas");
        print("Altura actual: $heightMM mm");

        progress = calculateProgressPercentage(heightIN!, minHeight, maxHeight);

        notifyListeners();
      });
    }
  }

  void _resetNoDataTimer(BuildContext context) {
    _noDataTimer?.cancel();

    _noDataTimer = Timer(const Duration(seconds: 5), () async {
      print(
          "No se ha recibido información de altura en los últimos 5 segundos.");

      //send last height to api
      if (heightIN != 0.0) {
        await createMovementReport(context);
      }
    });
  }

  void _resetStableTimer() {
    _stableTimer?.cancel();
    isStable = false;
    notifyListeners();

    _stableTimer = Timer(const Duration(seconds: 1), () {
      isStable = true;
      notifyListeners();
    });
  }


  Future<void> createMovementReport(BuildContext context) async {
    if (await InternetConnection().hasInternetAccess) {
      var routineController =
          Provider.of<RoutineController>(context, listen: false);
      int idRoutine = -1;
      if (routineController.isActive) {
        SharedPreferences prefs = await SharedPreferences.getInstance();
        idRoutine = prefs.getInt('routineId') ?? -1;
      }

      await DeskApi.moveDeskToPosition(0, heightIN!, idRoutine)
          .then((response) {
        if (response['success']) {
          print("Se ha enviado la altura al servidor $heightIN");
        }
      });
    }
    memorySlot = 0;
    notifyListeners();
  }

  double calculateProgressPercentage(
      double heightIN, double minHeight, double maxHeight) {
    if (heightIN < minHeight) return 0.0; // Menor que la altura mínima.
    if (heightIN > maxHeight) return 100.0; // Mayor que la altura máxima.

    return ((heightIN - minHeight) / (maxHeight - minHeight)) * 100;
  }

  void _sendInitialCommand() {
    targetCharacteristic
        ?.write([0xF1, 0xF1, 0x07, 0x00, 0x07, 0x7E], withoutResponse: true);
  }

  void _activateDisplay() {
    // Enviar comando de movimiento mínimo para activar la pantalla
    // Primero un pequeño movimiento hacia arriba
    targetCharacteristic?.write([0xF1, 0xF1, 0x01, 0x00, 0x01, 0x7E], withoutResponse: true);
    
    // Después de 100ms, detener el movimiento
    Future.delayed(const Duration(milliseconds: 100), () {
      
      targetCharacteristic?.write([0xF1, 0xF1, 0x2B, 0x00, 0x2B, 0x7E], withoutResponse: true);
      print("🖥️ Pantalla del escritorio activada");
    });
  }

  void requestHeightRange() {
    // Comando para solicitar el rango de altura
    List<int> command = [0xF1, 0xF1, 0x0C, 0x00, 0x0C, 0x7E];
    targetCharacteristic!.write(command, withoutResponse: true);
  }

  void requestCurrentStatus() {
    // Comando para solicitar el estado actual (esto fuerza al escritorio a enviar la altura actual)
    // Usamos el mismo comando que se usa para detener el movimiento, que también reporta el estado
    List<int> command = [0xF1, 0xF1, 0x07, 0x00, 0x07, 0x7E];
    if (targetCharacteristic != null) {
      targetCharacteristic!.write(command, withoutResponse: true);
      print("📊 Solicitando estado actual del escritorio");
    }
  }

  void moveUp() {
    final data = [0xF1, 0xF1, 0x01, 0x00, 0x01, 0x7E];
    targetCharacteristic!.write(data, withoutResponse: true);
  }

  Future<void> reAddAdvertisedService() async {
    // Construir el campo de difusión (ADVData) para anunciar el servicio con UUID 0xFE60
    // Para un UUID de 16 bits, en little-endian: 0x60, 0xFE.
    // Usamos Type 0x02 para lista incompleta de UUID de 16 bits.
    // Formato: [Longitud, Type, Data...]
    List<int> advField = [0x03, 0x02, 0x60, 0xFE];

    // Calcular la longitud total: 1 byte para SaveFlag + longitud de advField (4 bytes)
    int advDataLength = 1 + advField.length; // 1 + 4 = 5

    // Armar el comando de configuración de datos de difusión (comando 0D)
    List<int> command = [0x01, 0xFC, 0x0D, advDataLength, 0x01];
    command.addAll(advField);

    print(
        "Comando para re-agregar advertised service: ${command.map((b) => b.toRadixString(16))}");

    // Enviar el comando a la característica correspondiente (normalmente la característica de configuración, por ejemplo, deviceInfoCharacteristic)
    await deviceInfoCharacteristic!.write(command, withoutResponse: false);

    // Se recomienda esperar un pequeño retardo y redescubrir servicios si es necesario
    await Future.delayed(const Duration(milliseconds: 500));
  }

  void moveDown() {
    final data = [0xF1, 0xF1, 0x02, 0x00, 0x02, 0x7E];
    targetCharacteristic!.write(data, withoutResponse: true);
  }

  Future<void> resetDevice() async {
    // Comando de reset: [0x01, 0xFC, 0x19, 0x01, 0x00]
    final resetCommand = [0x01, 0xFC, 0x19, 0x01, 0x00];

    // Enviar el comando utilizando la característica adecuada (por ejemplo, deviceInfoCharacteristic)
    await deviceInfoCharacteristic!.write(resetCommand, withoutResponse: false);

    print(
        "Comando de reset enviado: ${resetCommand.map((b) => b.toRadixString(16))}");
  }

  // Métodos específicos para cada tipo de dispositivo
  List<int> _convertNameForFF03(String name) {
    List<int> hexArray = List<int>.filled(name.length, 0);
    for (int i = 0; i < name.length; i++) {
      hexArray[i] = name.codeUnitAt(i);
    }
    return hexArray;
  }

  List<int> _createCommandForFF03(String name) {
    List<int> hexArray = _convertNameForFF03(name);
    print("Nombre convertido a hex (FF03): $hexArray");
    return hexArray;
  }

  List<int> _createCommandForFE63(String name) {
    List<int> nameBytes = name.codeUnits;

    if (nameBytes.length > 20) {
      throw Exception('El nombre debe tener entre 1 y 20 bytes.');
    }

    List<int> command = [0x01, 0xFC, 0x07, nameBytes.length];
    command.addAll(nameBytes);

    print("Comando final (FE63): $command");
    return command;
  }

  Future<void> requestName() async {
    if (deviceInfoCharacteristic == null) return;
    await deviceInfoCharacteristic!
        .write([0x01, 0xFC, 0x08, 0x00], withoutResponse: false);
  }

  Future<void> changeName(String name) async {
    if (deviceInfoCharacteristic == null) return;

    try {
      // Determinar qué característica estamos usando
      String charUuid = deviceInfoCharacteristic!.characteristicUuid.str;

      // Crear el comando según el tipo de característica
      List<int> command;
      bool withoutResponse = false;

      switch (charUuid) {
        case 'ff06':
          command = _createCommandForFF03(name);
          break;
        case 'fe63':
          command = _createCommandForFE63(name);
          withoutResponse = false;
          break;
        default:
          throw Exception('Característica no soportada: $charUuid');
      }

      // Enviar el comando
      await deviceInfoCharacteristic!
          .write(command, withoutResponse: false, allowLongWrite: true);

      await Future.delayed(const Duration(milliseconds: 500));

      // Guardar nombre en SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('device_name', name);

      deviceName = name;
      notifyListeners();
    } catch (e) {
      print('❌ Error al cambiar el nombre: $e');
    }
  }

  //move to specific height
  void moveToHeight(int mm) async {
    if (targetCharacteristic == null) {
      print("❌ Característica de destino no disponible");
      return;
    }

    if (device == null ||
        connectionState != BluetoothConnectionState.connected) {
      print("❌ Dispositivo no conectado - estado: $connectionState");
      return;
    }

    try {
      // Generar el comando con la altura deseada en pulgadas
      String hexStr = mm.toRadixString(16).padLeft(4, '0');

      List<int> bytes = [];
      for (int i = 0; i < hexStr.length; i += 2) {
        bytes.add(int.parse(hexStr.substring(i, i + 2), radix: 16));
      }

      print("📤 Comando generado para mover a $mm mm de altura: $bytes");

      List<int> command = periferial(bytes);

      // Enviar el comando al targetCharacteristic
      await targetCharacteristic!
          .write(command, withoutResponse: true, allowLongWrite: false);

      print("✅ Comando enviado exitosamente a la mesa");
    } catch (e) {
      print("❌ Error al enviar comando a la mesa: $e");
      // Intentar reconectar si hay error
      if (device != null) {
        try {
          await reconnect();
          print("🔄 Reintentando envío después de reconexión...");
          await Future.delayed(const Duration(milliseconds: 500));
          moveToHeight(mm);
        } catch (reconnectError) {
          print("❌ Error en reconexión: $reconnectError");
        }
      }
    }
  }

  List<int> periferial(List<int> hexValue) {
    List<int> periferialCommand = List.filled(8, 0);
    int checkSum = 0x00;

    periferialCommand[0] = 0xF1;
    periferialCommand[1] = 0xF1;
    periferialCommand[2] = 0x1B;
    periferialCommand[3] = 0x02;

    int highByte = hexValue[0];
    int lowByte = hexValue[1];

    periferialCommand[4] = highByte;
    periferialCommand[5] = lowByte;

    // Calcular el checksum
    for (int i = 2; i < 6; i++) {
      checkSum += periferialCommand[i];
    }
    periferialCommand[6] =
        checkSum & 0xFF; // Asegurarse de que el checksum esté dentro de 1 byte
    periferialCommand[7] = 0x7E;

    return periferialCommand;
  }

  List<int> inchToHex(double inch) {
    int inches = inch.round();

    // Convertir a milésimas de pulgada
    int milliInches = (inches * 25.5).toInt();

    // Convertir a cadena hexadecimal
    String hexStr = milliInches.toRadixString(16).padLeft(4, '0');

    List<int> bytes = [];
    for (int i = 0; i < hexStr.length; i += 2) {
      bytes.add(int.parse(hexStr.substring(i, i + 2), radix: 16));
    }

    return bytes;
  }

  // Métodos de conversión de unidades
  double hexToCm(int mm1, int mm2) {
    int heightMm = (mm1 << 8) | mm2;
    return heightMm / 10.0;
  }

  double hexToInches(int mm1, int mm2) {
    int heightMm = (mm1 << 8) | mm2;
    return heightMm / 25.4;
  }

  int cmToMm(double cm) {
    return (cm * 10).round();
  }

  double inchesToMm(double inches) {
    return inches * 25.4; // 1 inch = 25.4 mm (exact conversion)
  }

  int hexToMm(int dataH, int dataL) {
    return (dataH << 8) | dataL;
  }

  double mmToInches(double mm) {
    return mm / 25.4;
  }

  double mmToCm(double mm) {
    return mm / 10;
  }

  // Comandos de control
  void letGo() {
    final data = [0xF1, 0xF1, 0x0c, 0x00, 0x0c, 0x7E];
    targetCharacteristic!.write(data, withoutResponse: true);
  }

  void resetMemoryCofigured() {
    memory1Configured = false;
    memory2Configured = false;
    memory3Configured = false;
    notifyListeners();
  }

  // Métodos para configurar posiciones de memoria
  void setupMemory1() async {
    final data = [0xF1, 0xF1, 0x03, 0x00, 0x03, 0x7E];
    targetCharacteristic!.write(data, withoutResponse: true);
    memory1Configured = true;
    notifyListeners();

    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setDouble('memory1', heightIN!);

    if (await InternetConnection().hasInternetAccess) {
      DeskApi.saveMemoryDesk(1, heightIN!);
    }

    Future.delayed(const Duration(seconds: 2), () {
      memory1Configured = false;
      notifyListeners();
    });
  }

  void setupMemory2() async {
    final data = [0xF1, 0xF1, 0x04, 0x00, 0x04, 0x7E];
    targetCharacteristic!.write(data, withoutResponse: true);
    memory2Configured = true;
    notifyListeners();

    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setDouble('memory2', heightIN!);

    if (await InternetConnection().hasInternetAccess) {
      DeskApi.saveMemoryDesk(2, heightIN!);
    }

    Future.delayed(const Duration(seconds: 2), () {
      memory2Configured = false;
      notifyListeners();
    });
  }

  void setupMemory3() async {
    final data = [0xF1, 0xF1, 0x25, 0x00, 0x25, 0x7E];
    targetCharacteristic!.write(data, withoutResponse: true);
    memory3Configured = true;
    notifyListeners();

    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setDouble('memory3', heightIN!);

    if (await InternetConnection().hasInternetAccess) {
      DeskApi.saveMemoryDesk(3, heightIN!);
    }

    Future.delayed(const Duration(seconds: 2), () {
      memory3Configured = false;
      notifyListeners();
    });
  }

  void setupMemory4() {
    final data = [0xF1, 0xF1, 0x26, 0x00, 0x26, 0x7E];
    targetCharacteristic!.write(data, withoutResponse: true);
  }

  // Métodos para mover a posiciones de memoria
  void moveMemory1() {
    final data = [0xF1, 0xF1, 0x05, 0x00, 0x05, 0x7E];
    targetCharacteristic!.write(data, withoutResponse: true);
    memorySlot = 1;
    notifyListeners();
  }

  void moveMemory2() {
    final data = [0xF1, 0xF1, 0x06, 0x00, 0x06, 0x7E];
    targetCharacteristic!.write(data, withoutResponse: true);
    memorySlot = 2;
    notifyListeners();
  }

  void moveMemory3() {
    final data = [0xF1, 0xF1, 0x27, 0x00, 0x27, 0x7E];
    targetCharacteristic!.write(data, withoutResponse: true);
    memorySlot = 3;
    notifyListeners();
  }

  void moveMemory4() {
    final data = [0xF1, 0xF1, 0x28, 0x00, 0x28, 0x7E];
    targetCharacteristic!.write(data, withoutResponse: true);
    memorySlot = 4;
    notifyListeners();
  }

  // Comandos de parada
  void sendStopCommand() {
    List<int> data = [0xF1, 0xF1, 0x0A, 0x00, 0x0A, 0x7E];
    targetCharacteristic!.write(data, withoutResponse: true);
  }

  void sendEmergencyStopCommand(BluetoothCharacteristic characteristic) {
    List<int> data = [0xF1, 0xF1, 0x2B, 0x00, 0x2B, 0x7E];
    characteristic.write(data, withoutResponse: true);
  }

  // Timers para movimiento continuo
  void startUpTimer() {
    upTimer = Timer.periodic(const Duration(milliseconds: 200), (timer) {
      moveUp();
    });
  }

  void startDownTimer() {
    downTimer = Timer.periodic(const Duration(milliseconds: 200), (timer) {
      moveDown();
    });
  }

  void disconnect() {
    if (device == null) {
      return;
    }
    device!.disconnect();
    device = null;
    _controller!.reset();
    _controller!.dispose();
    //Dudas aqui tbh, no he calado lo suficiente
    _wsStarted = false;
    socketSvc.dispose();
    final prefs = SharedPreferences.getInstance();
    prefs.then((prefs) => prefs.remove('sUUID'));
    notifyListeners();
  }
}
