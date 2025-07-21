import 'dart:async';
import 'dart:io';
import 'package:controller/src/api/desk_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:controller/src/controllers/desk/desk_controller.dart';
import 'package:controller/src/widgets/backround_blur.dart';
import 'package:controller/src/widgets/buttons/buttons.dart';
import 'package:open_settings_plus/core/open_settings_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:iconsax/iconsax.dart';
import '../../controllers/desk/desk_service_config.dart';
import '../home/home_screen.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  List<ScanResult> _scanResults = [];
  bool _isScanning = false;
  BluetoothAdapterState _adapterState = BluetoothAdapterState.unknown;

  late StreamSubscription<List<ScanResult>> _scanResultsSubscription;
  late StreamSubscription<bool> _isScanningSubscription;
  late StreamSubscription<BluetoothAdapterState> _adapterStateSubscription;

  bool _hasValidServices(ScanResult result) {
    var services = result.advertisementData.serviceUuids;
    if (services.isEmpty) return false;
    for (var service in services) {
      String fullUuid = service.str.toLowerCase();
      if (DeskServiceConfig.configurations.any((config) => config.serviceUuid == fullUuid)) {
        return true;
      }
    }
    return false;
  }

  @override
  void initState() {
    super.initState();
    _initializeBluetooth();
  }

  void _initializeBluetooth() {
    _adapterStateSubscription = FlutterBluePlus.adapterState.listen((state) {
      if (mounted) {
        setState(() => _adapterState = state);
        if (state == BluetoothAdapterState.on) onScanPressed();
      }
    });

    _isScanningSubscription = FlutterBluePlus.isScanning.listen((state) {
      if (mounted) setState(() => _isScanning = state);
    });

    _scanResultsSubscription = FlutterBluePlus.scanResults.listen((results) {
      if (mounted) {
        setState(() {
          _scanResults = results
              .where((r) => _hasValidServices(r) && r.device.advName.isNotEmpty)
              .toList();
        });
      }
    }, onError: (e) {
      if (mounted) _showErrorDialog(AppLocalizations.of(context)!.allowPermissions);
    });
  }

  @override
  void dispose() {
    FlutterBluePlus.stopScan();
    _adapterStateSubscription.cancel();
    _isScanningSubscription.cancel();
    _scanResultsSubscription.cancel();
    super.dispose();
  }

  Future<void> onScanPressed() async {
    try {
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 5));
    } catch (e) {
      if (mounted) _showErrorDialog(AppLocalizations.of(context)!.allowPermissions);
    }
  }

  Future<void> onConnectPressed(BluetoothDevice device) async {
    _showConnectingDialog();
    try {
      DeskApi.registerDeskDevice(device.advName, device.remoteId.str, '1');
      await device.connect(timeout: const Duration(seconds: 15));
      if (mounted) {
        Navigator.of(context).pop();
        context.read<DeskController>().setDevice(device);
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const HomeScreen()),
              (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        _showConnectionErrorDialog();
      }
    }
  }

  void onSkipPressed() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const HomeScreen()),
          (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return BackgroundBlur(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          // --- SOLUCIÓN: Lógica de navegación explícita ---
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            // En lugar de pop(), navegamos a HomeScreen y limpiamos la pila de rutas
            onPressed: () => Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (context) => const HomeScreen()),
                  (route) => false,
            ),
          ),
          backgroundColor: Colors.transparent,
          centerTitle: true,
          title: Text(AppLocalizations.of(context)!.findDevices, style: const TextStyle(fontWeight: FontWeight.bold)),
          actions: [
            if (_adapterState == BluetoothAdapterState.on && !_isScanning)
              IconButton(
                icon: const Icon(Iconsax.refresh),
                onPressed: onScanPressed,
              ),
          ],
        ),
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isScanning) return _buildScanningView();
    if (_adapterState == BluetoothAdapterState.off) return _buildBluetoothOffView();
    if (_scanResults.isEmpty) return _buildNoResultsView();
    return _buildResultsListView();
  }

  // --- Widgets de Estado (sin cambios) ---
  Widget _buildScanningView() { return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [CircularProgressIndicator(color: Theme.of(context).primaryColor), const SizedBox(height: 20), Text(AppLocalizations.of(context)!.scanning, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))])); }
  Widget _buildBluetoothOffView() { return Center(child: Padding(padding: const EdgeInsets.all(24.0), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Iconsax.bluetooth, size: 80, color: Colors.grey), const SizedBox(height: 24), Text(AppLocalizations.of(context)!.enableBluetooth, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold), textAlign: TextAlign.center), const SizedBox(height: 12), Text("Please enable Bluetooth to find and connect to your devices.", style: TextStyle(fontSize: 16, color: Colors.grey[600], height: 1.5), textAlign: TextAlign.center), const SizedBox(height: 24), RoundedButton(text: AppLocalizations.of(context)!.enableBluetooth, onPressed: () { if (Platform.isAndroid) FlutterBluePlus.turnOn(); else const OpenSettingsPlusIOS().bluetooth(); })]))); }
  Widget _buildNoResultsView() { return Center(child: Padding(padding: const EdgeInsets.all(24.0), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Iconsax.bluetooth, size: 80, color: Colors.grey), const SizedBox(height: 24), Text(AppLocalizations.of(context)!.noDevicesFound, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold), textAlign: TextAlign.center), const SizedBox(height: 12), Text("Make sure your device is turned on and nearby.", style: TextStyle(fontSize: 16, color: Colors.grey[600], height: 1.5), textAlign: TextAlign.center), const SizedBox(height: 24), RoundedButton(text: AppLocalizations.of(context)!.findDevices, onPressed: onScanPressed), TextButton(onPressed: onSkipPressed, child: Text(AppLocalizations.of(context)!.skip, style: TextStyle(color: Theme.of(context).primaryColor)))]))); }

  Widget _buildResultsListView() {
    return RefreshIndicator(
      onRefresh: onScanPressed,
      child: ListView.builder(
        padding: const EdgeInsets.all(8.0),
        itemCount: _scanResults.length,
        itemBuilder: (context, index) {
          return ScanResultTile(
            result: _scanResults[index],
            onTap: () => onConnectPressed(_scanResults[index].device),
          );
        },
      ),
    );
  }

  // --- Diálogos de Alerta (sin cambios) ---
  Future<void> _showErrorDialog(String message) async { showDialog(context: context, builder: (context) => AlertDialog(icon: const Icon(Iconsax.warning_2, size: 40), title: Text(AppLocalizations.of(context)!.permissions), content: Text(message), actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(AppLocalizations.of(context)!.cancel)), FilledButton(onPressed: () {Navigator.of(context).pop(); if (Platform.isAndroid) openAppSettings(); else const OpenSettingsPlusIOS().bluetooth();}, child: Text(AppLocalizations.of(context)!.goToSettings))])); }
  Future<void> _showConnectingDialog() async { showDialog(context: context, barrierDismissible: false, builder: (context) => AlertDialog(content: Column(mainAxisSize: MainAxisSize.min, children: [const SizedBox(height: 16), CircularProgressIndicator(color: Theme.of(context).primaryColor), const SizedBox(height: 24), Text(AppLocalizations.of(context)!.connecting, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), const SizedBox(height: 8)]))); }
  Future<void> _showConnectionErrorDialog() async { showDialog(context: context, builder: (context) => AlertDialog(icon: Icon(Iconsax.danger, size: 40, color: Colors.red[400]), title: Text(AppLocalizations.of(context)!.connectionError), content: Text(AppLocalizations.of(context)!.connectionErrorMessageBT), actions: [FilledButton(onPressed: () => Navigator.of(context).pop(), child: Text(AppLocalizations.of(context)!.close))])); }
}


// --- WIDGETS RESTAURADOS Y REDISEÑADOS ---

class ScanResultTile extends StatefulWidget {
  const ScanResultTile({super.key, required this.result, this.onTap});
  final ScanResult result;
  final VoidCallback? onTap;

  @override
  State<ScanResultTile> createState() => _ScanResultTileState();
}

class _ScanResultTileState extends State<ScanResultTile> {
  // Lógica interna sin cambios
  BluetoothConnectionState _connectionState = BluetoothConnectionState.disconnected;
  late StreamSubscription<BluetoothConnectionState> _connectionStateSubscription;

  @override
  void initState() {
    super.initState();
    _connectionStateSubscription = widget.result.device.connectionState.listen((state) {
      if (mounted) setState(() => _connectionState = state);
    });
  }

  @override
  void dispose() {
    _connectionStateSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Restauramos tu ExpansionTile original dentro de una Card rediseñada
    return Card(
      elevation: 2,
      shadowColor: Colors.black.withOpacity(0.1),
      margin: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 8.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
          child: Icon(Iconsax.bluetooth, color: Theme.of(context).primaryColor),
        ),
        title: Text(widget.result.device.advName, style: const TextStyle(fontWeight: FontWeight.bold)),
        trailing: ElevatedButton(
          onPressed: widget.result.advertisementData.connectable ? widget.onTap : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).primaryColor,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
          ),
          child: Text(AppLocalizations.of(context)!.connect),
        ),
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Divider(),
                Text("Device ID: ${widget.result.device.remoteId.str}"),
                const SizedBox(height: 8),
                Text("RSSI: ${widget.result.rssi} dBm"),
              ],
            ),
          )
        ],
      ),
    );
  }
}