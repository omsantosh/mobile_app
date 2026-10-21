import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

class BleService extends ChangeNotifier {
  static const String serviceUuid = '4fafc201-1fb5-459e-8fcc-c5c9c331914b';
  static const String charWifiSsid = 'beb5483e-36e1-4688-b7f5-ea07361b26a8';
  static const String charWifiPass = 'beb5483e-36e1-4688-b7f5-ea07361b26a9';
  static const String charMqttConf = 'beb5483e-36e1-4688-b7f5-ea07361b26aa';
  static const String charStatus   = 'beb5483e-36e1-4688-b7f5-ea07361b26ab';

  List<ScanResult> _scanResults = [];
  bool _isScanning = false;
  BluetoothDevice? _connectedDevice;
  String _provisioningStatus = 'IDLE';

  List<ScanResult> get scanResults => _scanResults;
  bool get isScanning => _isScanning;
  BluetoothDevice? get connectedDevice => _connectedDevice;
  String get provisioningStatus => _provisioningStatus;

  Future<bool> requestPermissions() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ].request();

    return statuses.values.every((status) => status.isGranted);
  }

  void startScan() async {
    _scanResults.clear();
    _isScanning = true;
    notifyListeners();

    try {
      await FlutterBluePlus.startScan(
        withServices: [Guid(serviceUuid)],
        timeout: const Duration(seconds: 8),
      );

      FlutterBluePlus.scanResults.listen((results) {
        _scanResults = results;
        notifyListeners();
      });

      await Future.delayed(const Duration(seconds: 8));
      _isScanning = false;
      notifyListeners();
    } catch (e) {
      debugPrint('BLE Scan Error: $e');
      _isScanning = false;
      notifyListeners();
    }
  }

  Future<bool> connectToDevice(BluetoothDevice device) async {
    try {
      await device.connect(autoConnect: false);
      _connectedDevice = device;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('BLE Connect Error: $e');
      return false;
    }
  }

  Future<bool> sendProvisioningData({
    required String ssid,
    required String password,
    required String mqttBroker,
    int mqttPort = 1883,
    String mqttUser = '',
    String mqttPass = '',
  }) async {
    if (_connectedDevice == null) return false;

    try {
      List<BluetoothService> services = await _connectedDevice!.discoverServices();
      BluetoothService? targetService;

      for (var s in services) {
        if (s.uuid.toString().toLowerCase() == serviceUuid.toLowerCase()) {
          targetService = s;
          break;
        }
      }

      if (targetService == null) return false;

      BluetoothCharacteristic? cSsid;
      BluetoothCharacteristic? cPass;
      BluetoothCharacteristic? cMqtt;
      BluetoothCharacteristic? cStatus;

      for (var c in targetService.characteristics) {
        final uuid = c.uuid.toString().toLowerCase();
        if (uuid == charWifiSsid.toLowerCase()) cSsid = c;
        if (uuid == charWifiPass.toLowerCase()) cPass = c;
        if (uuid == charMqttConf.toLowerCase()) cMqtt = c;
        if (uuid == charStatus.toLowerCase()) cStatus = c;
      }

      if (cSsid == null || cPass == null || cMqtt == null) return false;

      // Subscribe to status notifications
      if (cStatus != null) {
        await cStatus.setNotifyValue(true);
        cStatus.onValueReceived.listen((value) {
          _provisioningStatus = utf8.decode(value);
          notifyListeners();
        });
      }

      // Write SSID
      await cSsid.write(utf8.encode(ssid));
      await Future.delayed(const Duration(milliseconds: 200));

      // Write Password
      await cPass.write(utf8.encode(password));
      await Future.delayed(const Duration(milliseconds: 200));

      // Write MQTT Config JSON
      final mqttPayload = jsonEncode({
        'broker': mqttBroker,
        'port': mqttPort,
        'user': mqttUser,
        'pass': mqttPass,
      });
      await cMqtt.write(utf8.encode(mqttPayload));

      _provisioningStatus = 'SENT_CREDENTIALS';
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Provisioning transmission error: $e');
      _provisioningStatus = 'ERROR';
      notifyListeners();
      return false;
    }
  }

  void disconnect() {
    _connectedDevice?.disconnect();
    _connectedDevice = null;
    _provisioningStatus = 'IDLE';
    notifyListeners();
  }
}
