import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/mqtt_service.dart';
import 'ir_remote_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<Map<String, String>> _rooms = [
    {'name': 'Living Room', 'deviceId': 'ThaleSmart_E4B1F0'},
  ];
  int _selectedRoomIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadRooms();
  }

  Future<void> _loadRooms() async {
    final prefs = await SharedPreferences.getInstance();
    final roomsJson = prefs.getString('saved_rooms');
    final activeId = prefs.getString('device_id') ?? 'ThaleSmart_E4B1F0';

    if (roomsJson != null) {
      try {
        final List<dynamic> decoded = jsonDecode(roomsJson);
        setState(() {
          _rooms = decoded
              .map((r) => {
                    'name': (r['name'] ?? 'Room').toString(),
                    'deviceId': (r['deviceId'] ?? '').toString(),
                  })
              .toList();
        });
      } catch (e) {
        debugPrint('Error decoding rooms: $e');
      }
    }

    if (_rooms.isEmpty) {
      _rooms = [{'name': 'Living Room', 'deviceId': activeId}];
    }

    // Set selected index matching active device ID
    final idx = _rooms.indexWhere((r) => r['deviceId'] == activeId);
    if (idx != -1) {
      setState(() => _selectedRoomIndex = idx);
    }
  }

  Future<void> _saveRooms() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('saved_rooms', jsonEncode(_rooms));
  }

  void _switchRoom(int index) async {
    if (index < 0 || index >= _rooms.length) return;
    setState(() => _selectedRoomIndex = index);
    final room = _rooms[index];
    final deviceId = room['deviceId'] ?? '';
    final prefs = await SharedPreferences.getInstance();
    final broker = prefs.getString('mqtt_broker') ?? 'broker.hivemq.com';
    await prefs.setString('device_id', deviceId);

    if (mounted) {
      final mqtt = Provider.of<MqttService>(context, listen: false);
      final clientId = 'App_${DateTime.now().millisecondsSinceEpoch}';
      mqtt.connect(
        broker: broker,
        clientId: clientId,
        deviceId: deviceId,
      );
    }
  }

  void _showAddRoomDialog() {
    final nameCtrl = TextEditingController(text: 'Bedroom 1');
    final idCtrl = TextEditingController(text: 'SmartESP32_');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add New Room / Board'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Add another ESP32 board and assign it to a room in your house.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Room Name',
                hintText: 'e.g. Master Bedroom, Kitchen',
                prefixIcon: Icon(Icons.meeting_room_outlined),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: idCtrl,
              decoration: const InputDecoration(
                labelText: 'Device ID',
                hintText: 'e.g. SmartESP32_A1B2C3',
                prefixIcon: Icon(Icons.developer_board),
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final name = nameCtrl.text.trim();
              final id = idCtrl.text.trim();
              if (name.isNotEmpty && id.isNotEmpty) {
                setState(() {
                  _rooms.add({'name': name, 'deviceId': id});
                  _selectedRoomIndex = _rooms.length - 1;
                });
                _saveRooms();
                _switchRoom(_selectedRoomIndex);
                Navigator.pop(ctx);
              }
            },
            child: const Text('Add Room'),
          ),
        ],
      ),
    );
  }

  void _showEditRoomDialog(MqttService mqtt) {
    final current = _rooms[_selectedRoomIndex];
    final nameCtrl = TextEditingController(text: current['name']);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename Room'),
        content: TextField(
          controller: nameCtrl,
          decoration: const InputDecoration(
            labelText: 'Room Name',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final newName = nameCtrl.text.trim();
              if (newName.isNotEmpty) {
                setState(() {
                  _rooms[_selectedRoomIndex]['name'] = newName;
                });
                _saveRooms();
                mqtt.updateRoomName(newName);
                Navigator.pop(ctx);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showEditRelayDialog(int channel, String currentName, String currentIcon, MqttService mqtt) {
    final nameCtrl = TextEditingController(text: currentName);
    String selectedIcon = currentIcon;

    final List<Map<String, dynamic>> availableIcons = [
      {'key': 'light', 'label': 'Light', 'icon': Icons.lightbulb_outline},
      {'key': 'fan', 'label': 'Fan', 'icon': Icons.toys_outlined},
      {'key': 'tv', 'label': 'TV', 'icon': Icons.tv},
      {'key': 'ac', 'label': 'AC', 'icon': Icons.ac_unit},
      {'key': 'plug', 'label': 'Socket', 'icon': Icons.power},
      {'key': 'heater', 'label': 'Heater', 'icon': Icons.waves},
      {'key': 'night', 'label': 'Night', 'icon': Icons.bedtime_outlined},
    ];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: Text('Edit Relay $channel'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Appliance Name',
                    hintText: 'e.g. Ceiling Fan, Chandelier',
                    prefixIcon: Icon(Icons.edit),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Choose Icon:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: availableIcons.map((item) {
                    final isSel = selectedIcon == item['key'];
                    return ChoiceChip(
                      selected: isSel,
                      label: Text(item['label']),
                      avatar: Icon(item['icon'], size: 16, color: isSel ? Colors.white : Colors.teal),
                      selectedColor: Colors.teal,
                      onSelected: (val) {
                        if (val) setModalState(() => selectedIcon = item['key']);
                      },
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final newName = nameCtrl.text.trim();
                if (newName.isNotEmpty) {
                  mqtt.updateRelayConfig(channel, newName, selectedIcon);
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Updated Relay $channel to "$newName"!')),
                  );
                }
              },
              child: const Text('Save to Board'),
            ),
          ],
        ),
      ),
    );
  }

  void _showTimerDialog(BuildContext context, int channel, MqttService mqtt) {
    int selectedMinutes = 15;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('Set Timer for Relay $channel'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Automatically turn OFF after:'),
              const SizedBox(height: 16),
              DropdownButton<int>(
                value: selectedMinutes,
                isExpanded: true,
                items: [5, 10, 15, 30, 45, 60, 120]
                    .map((m) => DropdownMenuItem(
                          value: m,
                          child: Text('$m Minutes'),
                        ))
                    .toList(),
                onChanged: (val) {
                  if (val != null) setState(() => selectedMinutes = val);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                mqtt.startCountdownTimer(channel, selectedMinutes * 60, 0);
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Relay $channel timer set for $selectedMinutes mins!')),
                );
              },
              child: const Text('Start Timer'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mqtt = Provider.of<MqttService>(context);
    final state = mqtt.currentState;
    final isDeviceOnline = state?.isOnline ?? false;
    final isCloudConnected = mqtt.isConnected;
    final canControl = isCloudConnected;
    final relays = (state?.relayStates != null && state!.relayStates.isNotEmpty)
        ? state.relayStates
        : [0, 0, 0, 0];

    final currentRoom = _rooms.isNotEmpty && _selectedRoomIndex < _rooms.length
        ? _rooms[_selectedRoomIndex]
        : {'name': 'Living Room', 'deviceId': mqtt.activeDeviceId};

    final displayRoomName = (state?.roomName != null && state!.roomName.isNotEmpty)
        ? state.roomName
        : (currentRoom['name'] ?? 'Living Room');

    return Scaffold(
      appBar: AppBar(
        title: const Text('ThaleSmart', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_remote_outlined),
            tooltip: 'Configure IR Remote',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const IrRemoteScreen()),
              );
            },
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Row(
              children: [
                Icon(
                  Icons.circle,
                  size: 12,
                  color: isDeviceOnline
                      ? Colors.greenAccent
                      : (isCloudConnected ? Colors.tealAccent : Colors.redAccent),
                ),
                const SizedBox(width: 6),
                Text(
                  isDeviceOnline
                      ? 'Online'
                      : (isCloudConnected ? 'Connected' : 'Offline'),
                  style: TextStyle(
                    color: isDeviceOnline
                        ? Colors.greenAccent
                        : (isCloudConnected ? Colors.tealAccent : Colors.redAccent),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ROOM SELECTOR CHIPS
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  ...List.generate(_rooms.length, (idx) {
                    final isSel = idx == _selectedRoomIndex;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: FilterChip(
                        selected: isSel,
                        label: Text(_rooms[idx]['name'] ?? 'Room'),
                        avatar: Icon(
                          _getRoomIcon(_rooms[idx]['name'] ?? ''),
                          size: 16,
                          color: isSel ? Colors.white : Colors.teal,
                        ),
                        selectedColor: Colors.teal,
                        onSelected: (_) => _switchRoom(idx),
                      ),
                    );
                  }),
                  ActionChip(
                    avatar: const Icon(Icons.add, size: 16),
                    label: const Text('Add Room'),
                    onPressed: _showAddRoomDialog,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Active Room Title with Edit Name Button
            Row(
              children: [
                Text(
                  displayRoomName,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  tooltip: 'Rename Room',
                  onPressed: () => _showEditRoomDialog(mqtt),
                ),
                const Spacer(),
                Text(
                  'ID: ${mqtt.activeDeviceId}',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Status Telemetry Card
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _InfoItem(
                      icon: Icons.wifi,
                      label: 'Signal',
                      value: isDeviceOnline ? '${state?.rssi ?? 0} dBm' : '--',
                    ),
                    _InfoItem(
                      icon: Icons.network_check,
                      label: 'IP Address',
                      value: isDeviceOnline ? (state?.ip ?? 'N/A') : '--',
                    ),
                    _InfoItem(
                      icon: Icons.timer_outlined,
                      label: 'Uptime',
                      value: isDeviceOnline ? '${(state?.uptimeSec ?? 0) ~/ 3600}h' : '--',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Master Control Row
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: canControl ? () => mqtt.setAllRelays(1) : null,
                    icon: const Icon(Icons.flash_on),
                    label: const Text('ALL ON'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey.shade800,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: canControl ? () => mqtt.setAllRelays(0) : null,
                    icon: const Icon(Icons.flash_off),
                    label: const Text('ALL OFF'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            const Text(
              'Appliance Controls',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            // Relay Cards Grid (Adapts to 4 or 8 channels automatically)
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 14,
                childAspectRatio: 0.88,
              ),
              itemCount: relays.isNotEmpty ? relays.length : 4,
              itemBuilder: (context, index) {
                final channelNum = index + 1;
                final isOn = relays.isNotEmpty && relays[index] == 1;

                // Name & Icon from state or defaults
                final relayName = (state?.relayNames != null &&
                        index < state!.relayNames.length &&
                        state.relayNames[index].isNotEmpty)
                    ? state.relayNames[index]
                    : 'Relay $channelNum';

                final relayIconKey = (state?.relayIcons != null &&
                        index < state!.relayIcons.length &&
                        state.relayIcons[index].isNotEmpty)
                    ? state.relayIcons[index]
                    : _getDefaultIconKey(channelNum);

                return Card(
                  elevation: isOn ? 3 : 1,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: isOn ? Colors.teal : Colors.grey.withOpacity(0.2),
                      width: isOn ? 1.8 : 1.0,
                    ),
                  ),
                  color: isOn ? Colors.teal.withOpacity(0.12) : null,
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: canControl
                        ? () => mqtt.setRelay(channelNum, isOn ? 0 : 1)
                        : null,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header: Icon + Edit Name Button + Timer Button
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              CircleAvatar(
                                backgroundColor: isOn ? Colors.teal : Colors.grey.withOpacity(0.15),
                                radius: 20,
                                child: Icon(
                                  _parseApplianceIcon(relayIconKey),
                                  size: 20,
                                  color: isOn ? Colors.white : Colors.grey.shade400,
                                ),
                              ),
                              Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined, size: 18),
                                    tooltip: 'Rename',
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    color: Colors.grey,
                                    onPressed: () => _showEditRelayDialog(
                                      channelNum,
                                      relayName,
                                      relayIconKey,
                                      mqtt,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    icon: const Icon(Icons.timer_outlined, size: 20),
                                    tooltip: 'Timer',
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    color: isOn ? Colors.tealAccent : Colors.grey,
                                    onPressed: canControl
                                        ? () => _showTimerDialog(context, channelNum, mqtt)
                                        : null,
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const Spacer(),
                          // Center Info: Custom Relay Name + Status Text
                          Text(
                            relayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isOn ? 'ON' : 'OFF',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: isOn ? Colors.tealAccent : Colors.grey,
                            ),
                          ),
                          const Spacer(),
                          // Bottom: Interactive Switch
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                isOn ? 'Tap to turn OFF' : 'Tap to turn ON',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                              Switch(
                                value: isOn,
                                activeColor: Colors.teal,
                                onChanged: canControl
                                    ? (val) => mqtt.setRelay(channelNum, val ? 1 : 0)
                                    : null,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  IconData _getRoomIcon(String room) {
    final lower = room.toLowerCase();
    if (lower.contains('bed')) return Icons.bed_outlined;
    if (lower.contains('kitchen')) return Icons.kitchen_outlined;
    if (lower.contains('living')) return Icons.weekend_outlined;
    if (lower.contains('bath')) return Icons.bathtub_outlined;
    if (lower.contains('balcony') || lower.contains('garden')) return Icons.yard_outlined;
    return Icons.meeting_room_outlined;
  }

  String _getDefaultIconKey(int channel) {
    switch (channel) {
      case 1:
        return 'light';
      case 2:
        return 'plug';
      case 3:
        return 'tv';
      case 4:
        return 'ac';
      default:
        return 'light';
    }
  }

  IconData _parseApplianceIcon(String key) {
    switch (key.toLowerCase()) {
      case 'fan':
        return Icons.toys_outlined;
      case 'tv':
        return Icons.tv;
      case 'ac':
        return Icons.ac_unit;
      case 'plug':
      case 'socket':
        return Icons.power;
      case 'heater':
        return Icons.waves;
      case 'night':
        return Icons.bedtime_outlined;
      case 'light':
      default:
        return Icons.lightbulb_outline;
    }
  }
}

class _InfoItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoItem({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 22, color: Colors.teal),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 11)),
      ],
    );
  }
}
