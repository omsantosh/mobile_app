import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/ble_service.dart';
import '../services/mqtt_service.dart';

class BleProvisionScreen extends StatefulWidget {
  final VoidCallback? onNavigateToDashboard;
  const BleProvisionScreen({Key? key, this.onNavigateToDashboard}) : super(key: key);

  @override
  State<BleProvisionScreen> createState() => _BleProvisionScreenState();
}

class _BleProvisionScreenState extends State<BleProvisionScreen> {
  // BLE provisioning controllers
  final _ssidController = TextEditingController();
  final _passController = TextEditingController();
  final _brokerController = TextEditingController(text: 'broker.hivemq.com');
  final _portController = TextEditingController(text: '1883');
  final _userController = TextEditingController();
  final _mqttPassController = TextEditingController();

  // Quick Connect controllers (for already-provisioned boards)
  final _deviceIdController = TextEditingController(text: 'ThaleSmart_E4B1F0');
  final _quickBrokerController = TextEditingController(text: 'broker.hivemq.com');

  bool _obscureWifiPass = true;
  bool _isConnecting = false;
  bool _isQuickConnecting = false;

  @override
  void initState() {
    super.initState();
    _loadSavedDeviceId();
  }

  Future<void> _loadSavedDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('device_id');
    final savedBroker = prefs.getString('mqtt_broker') ?? 'broker.hivemq.com';
    final activeId = (saved != null && saved.isNotEmpty && !saved.startsWith('SmartESP'))
        ? saved
        : 'ThaleSmart_E4B1F0';
    setState(() {
      _deviceIdController.text = activeId;
      _quickBrokerController.text = savedBroker;
    });
  }

  Future<void> _saveDeviceId(String id, String broker) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('device_id', id);
    await prefs.setString('mqtt_broker', broker);

    final roomsJson = prefs.getString('saved_rooms');
    if (roomsJson != null) {
      try {
        final List<dynamic> decoded = jsonDecode(roomsJson);
        for (var r in decoded) {
          if (r is Map) {
            r['deviceId'] = id;
          }
        }
        await prefs.setString('saved_rooms', jsonEncode(decoded));
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _ssidController.dispose();
    _passController.dispose();
    _brokerController.dispose();
    _portController.dispose();
    _userController.dispose();
    _mqttPassController.dispose();
    _deviceIdController.dispose();
    _quickBrokerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ble = Provider.of<BleService>(context);
    final mqtt = Provider.of<MqttService>(context);
    final connectedDevice = ble.connectedDevice;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings & Setup', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─────────────────────────────────────────
            // SECTION 1: QUICK CONNECT (Already provisioned boards)
            // ─────────────────────────────────────────
            Container(
              decoration: BoxDecoration(
                color: Colors.teal.withOpacity(0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.teal.withOpacity(0.4)),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.cloud_done, color: Colors.teal),
                      const SizedBox(width: 8),
                      const Text(
                        'Quick Connect (Already Set Up Board)',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Enter your Device ID from the Serial Monitor to control your relays.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 14),

                  // Device ID field
                  TextField(
                    controller: _deviceIdController,
                    decoration: InputDecoration(
                      labelText: 'Device ID (from Serial Monitor)',
                      hintText: 'e.g. ThaleSmart_E4B1F0',
                      prefixIcon: const Icon(Icons.developer_board, color: Colors.teal),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Colors.teal),
                      ),
                      filled: true,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // MQTT Broker field
                  TextField(
                    controller: _quickBrokerController,
                    decoration: InputDecoration(
                      labelText: 'MQTT Broker',
                      prefixIcon: const Icon(Icons.cloud_outlined, color: Colors.teal),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Colors.teal),
                      ),
                      filled: true,
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Connection Status Row
                  if (mqtt.isConnected)
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 14),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.green, width: 1.5),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.check_circle, color: Colors.green, size: 22),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Connected to ${mqtt.activeDeviceId}!',
                                  style: const TextStyle(
                                    color: Colors.green,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green.shade700,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: () {
                              if (widget.onNavigateToDashboard != null) {
                                widget.onNavigateToDashboard!();
                              }
                            },
                            icon: const Icon(Icons.dashboard, size: 18),
                            label: const Text('Open Dashboard to Control Relays ➔', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: _isQuickConnecting
                          ? null
                          : () async {
                              final deviceId = _deviceIdController.text.trim();
                              final broker = _quickBrokerController.text.trim();
                              if (deviceId.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Please enter your Device ID!')),
                                );
                                return;
                              }
                              setState(() => _isQuickConnecting = true);
                              try {
                                await _saveDeviceId(deviceId, broker);
                                final clientId = 'ThaleSmart_${DateTime.now().millisecondsSinceEpoch}';
                                final ok = await mqtt.connect(
                                  broker: broker,
                                  clientId: clientId,
                                  deviceId: deviceId,
                                );
                                if (ok) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Connected to $deviceId! Switching to Dashboard...'),
                                      backgroundColor: Colors.teal,
                                      duration: const Duration(seconds: 2),
                                    ),
                                  );
                                  await Future.delayed(const Duration(milliseconds: 400));
                                  if (widget.onNavigateToDashboard != null && mounted) {
                                    widget.onNavigateToDashboard!();
                                  }
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Could not reach MQTT broker. Please check phone internet.'),
                                      backgroundColor: Colors.red,
                                      duration: Duration(seconds: 4),
                                    ),
                                  );
                                }
                              } catch (e) {
                                debugPrint('Quick connect error: $e');
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Error: $e'),
                                    backgroundColor: Colors.red,
                                    duration: const Duration(seconds: 4),
                                  ),
                                );
                              } finally {
                                if (mounted) {
                                  setState(() => _isQuickConnecting = false);
                                }
                              }
                            },
                      icon: _isQuickConnecting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Icon(Icons.cloud_upload_outlined),
                      label: Text(_isQuickConnecting ? 'Connecting...' : 'Connect to ThaleSmart'),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            // ─────────────────────────────────────────
            // SECTION 2: BLE PROVISIONING (New boards)
            // ─────────────────────────────────────────
            const Text(
              'Add a New ThaleSmart Board via Bluetooth',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const Text(
              'For first-time setup. Hold BOOT button on ThaleSmart board to enable BLE mode.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 12),

            if (connectedDevice != null)
              Card(
                color: Colors.teal.withOpacity(0.1),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  leading: const Icon(Icons.bluetooth_connected, color: Colors.teal),
                  title: Text(
                    'Paired to ${ble.connectedDevice?.platformName ?? "ThaleSmart"}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text('Status: ${ble.provisioningStatus}'),
                  trailing: TextButton(
                    onPressed: () => ble.disconnect(),
                    child: const Text('Disconnect', style: TextStyle(color: Colors.red)),
                  ),
                ),
              ),

            if (connectedDevice == null) ...[
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    children: [
                      TextField(
                        controller: _ssidController,
                        decoration: const InputDecoration(
                          labelText: 'Wi-Fi Network Name (SSID)',
                          prefixIcon: Icon(Icons.wifi),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _passController,
                        obscureText: _obscureWifiPass,
                        decoration: InputDecoration(
                          labelText: 'Wi-Fi Password',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(_obscureWifiPass ? Icons.visibility : Icons.visibility_off),
                            onPressed: () => setState(() => _obscureWifiPass = !_obscureWifiPass),
                          ),
                          border: const OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _brokerController,
                        decoration: const InputDecoration(
                          labelText: 'MQTT Broker',
                          prefixIcon: Icon(Icons.cloud_outlined),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue.shade700,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: _isConnecting
                              ? null
                              : () async {
                                  setState(() => _isConnecting = true);
                                  final ok = await ble.requestPermissions();
                                  if (ok) {
                                    ble.startScan();
                                  }
                                  setState(() => _isConnecting = false);
                                },
                          icon: const Icon(Icons.bluetooth_searching),
                          label: const Text('Scan & Pair New Board via Bluetooth'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              if (ble.scanResults.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text('Found Devices:', style: TextStyle(fontWeight: FontWeight.bold)),
                ...ble.scanResults.map((result) {
                  final name = result.device.platformName.isNotEmpty
                      ? result.device.platformName
                      : 'ThaleSmart Device';
                  return ListTile(
                    leading: const Icon(Icons.developer_board, color: Colors.teal),
                    title: Text(name),
                    subtitle: Text('Signal: ${result.rssi} dBm'),
                    trailing: ElevatedButton(
                      onPressed: () => ble.connectToDevice(result.device),
                      child: const Text('Pair'),
                    ),
                  );
                }),
              ],
            ],

            if (connectedDevice != null) ...[
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () async {
                    if (_ssidController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please enter your Wi-Fi SSID')),
                      );
                      return;
                    }
                    bool success = await ble.sendProvisioningData(
                      ssid: _ssidController.text.trim(),
                      password: _passController.text,
                      mqttBroker: _brokerController.text.trim(),
                      mqttPort: int.tryParse(_portController.text) ?? 1883,
                    );
                    if (success) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Wi-Fi credentials sent! ThaleSmart is connecting...'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.send_rounded),
                  label: const Text('Send Wi-Fi to ThaleSmart via Bluetooth'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
