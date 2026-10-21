import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/mqtt_service.dart';

class IrRemoteScreen extends StatefulWidget {
  const IrRemoteScreen({Key? key}) : super(key: key);

  @override
  State<IrRemoteScreen> createState() => _IrRemoteScreenState();
}

class _IrRemoteScreenState extends State<IrRemoteScreen> {
  int? _activeLearningTarget; // null if not learning
  final Map<int, String> _learnedCodes = {};

  @override
  void initState() {
    super.initState();
    _loadSavedCodes();
  }

  Future<void> _loadSavedCodes() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      for (int i = 0; i < 4; i++) {
        final code = prefs.getString('ir_code_$i');
        if (code != null) _learnedCodes[i] = code;
      }
      final allOn = prefs.getString('ir_code_10');
      if (allOn != null) _learnedCodes[10] = allOn;
      final allOff = prefs.getString('ir_code_11');
      if (allOff != null) _learnedCodes[11] = allOff;
    });
  }

  Future<void> _saveCode(int target, String code) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('ir_code_$target', code);
    setState(() {
      _learnedCodes[target] = code;
      _activeLearningTarget = null;
    });
  }

  Future<void> _clearCode(int target) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('ir_code_$target');
    setState(() {
      _learnedCodes.remove(target);
    });
  }

  @override
  Widget build(BuildContext context) {
    final mqtt = Provider.of<MqttService>(context);
    final isOnline = mqtt.isConnected;

    // Listen for incoming learned event
    final irEvent = mqtt.lastIrEvent;
    if (irEvent != null && _activeLearningTarget != null) {
      if (irEvent['event'] == 'learned') {
        final target = irEvent['target'] as int?;
        final code = irEvent['code'] as String?;
        if (target != null && code != null && target == _activeLearningTarget) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _saveCode(target, code);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Successfully learned remote key ($code)!'),
                backgroundColor: Colors.teal,
              ),
            );
          });
        }
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('IR Remote Learning', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // How-to Info Banner
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.teal.withOpacity(0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.teal.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.settings_remote, color: Colors.teal, size: 32),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Use ANY Infrared Remote',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Point your TV, AC, or Set-top Box remote at the ESP32 receiver. Tap "Learn", then press any button on your remote.',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            if (_activeLearningTarget != null)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber),
                ),
                child: Row(
                  children: [
                    const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(color: Colors.amber, strokeWidth: 2.5),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        'Listening for IR Remote signal for ${_getTargetLabel(_activeLearningTarget!)}...\nPress the button on your remote now!',
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        setState(() => _activeLearningTarget = null);
                      },
                      child: const Text('Cancel', style: TextStyle(color: Colors.redAccent)),
                    ),
                  ],
                ),
              ),

            const Text(
              'Relay Channels',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),

            ...List.generate(4, (index) => _buildIrTargetCard(
              target: index,
              title: 'Relay ${index + 1}',
              icon: _getChannelIcon(index + 1),
              isOnline: isOnline,
              mqtt: mqtt,
            )),

            const SizedBox(height: 18),
            const Text(
              'Master Remote Actions',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),

            _buildIrTargetCard(
              target: 10,
              title: 'Master ALL ON',
              icon: Icons.flash_on,
              isOnline: isOnline,
              mqtt: mqtt,
            ),
            _buildIrTargetCard(
              target: 11,
              title: 'Master ALL OFF',
              icon: Icons.flash_off,
              isOnline: isOnline,
              mqtt: mqtt,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIrTargetCard({
    required int target,
    required String title,
    required IconData icon,
    required bool isOnline,
    required MqttService mqtt,
  }) {
    final hasCode = _learnedCodes.containsKey(target);
    final codeStr = _learnedCodes[target] ?? 'Not configured';
    final isLearningThis = _activeLearningTarget == target;

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: isLearningThis
              ? Colors.amber
              : (hasCode ? Colors.teal.withOpacity(0.5) : Colors.transparent),
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: hasCode ? Colors.teal.withOpacity(0.15) : Colors.grey.withOpacity(0.1),
              child: Icon(icon, color: hasCode ? Colors.teal : Colors.grey),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    hasCode ? 'Learned: $codeStr' : 'No IR button paired',
                    style: TextStyle(
                      fontSize: 12,
                      color: hasCode ? Colors.tealAccent : Colors.grey.shade500,
                      fontWeight: hasCode ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
            if (hasCode)
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 20, color: Colors.redAccent),
                tooltip: 'Clear',
                onPressed: isOnline
                    ? () {
                        mqtt.clearIrCode(target);
                        _clearCode(target);
                      }
                    : null,
              ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: isLearningThis ? Colors.amber : Colors.teal,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: (!isOnline || isLearningThis)
                  ? null
                  : () {
                      setState(() => _activeLearningTarget = target);
                      mqtt.startIrLearning(target);
                    },
              icon: Icon(isLearningThis ? Icons.hearing : Icons.sensors, size: 16),
              label: Text(
                isLearningThis ? 'Listening...' : (hasCode ? 'Re-learn' : 'Learn'),
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getTargetLabel(int target) {
    if (target < 4) return 'Relay ${target + 1}';
    if (target == 10) return 'ALL ON';
    if (target == 11) return 'ALL OFF';
    return 'Relay';
  }

  IconData _getChannelIcon(int channel) {
    switch (channel) {
      case 1:
        return Icons.lightbulb_outline;
      case 2:
        return Icons.power;
      case 3:
        return Icons.tv;
      case 4:
        return Icons.ac_unit;
      default:
        return Icons.electrical_services;
    }
  }
}
