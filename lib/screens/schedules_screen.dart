import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/device_state.dart';
import '../services/mqtt_service.dart';

class SchedulesScreen extends StatefulWidget {
  const SchedulesScreen({Key? key}) : super(key: key);

  @override
  State<SchedulesScreen> createState() => _SchedulesScreenState();
}

class _SchedulesScreenState extends State<SchedulesScreen> {
  final List<ScheduleModel> _schedules = [
    ScheduleModel(
      enabled: true,
      days: 127, // All days (1111111 in binary)
      hour: 6,
      minute: 30,
      channel: 1,
      action: 1, // Turn ON
    ),
    ScheduleModel(
      enabled: true,
      days: 127,
      hour: 23,
      minute: 0,
      channel: 1,
      action: 0, // Turn OFF
    ),
  ];

  final List<String> _dayNames = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

  void _showAddEditScheduleDialog([int? editIndex]) {
    final isEditing = editIndex != null;
    ScheduleModel sched = isEditing
        ? _schedules[editIndex]
        : ScheduleModel(enabled: true, days: 127, hour: 7, minute: 0, channel: 1, action: 1);

    TimeOfDay selectedTime = TimeOfDay(hour: sched.hour, minute: sched.minute);
    int selectedChannel = sched.channel;
    int selectedAction = sched.action;
    int daysBitmask = sched.days;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            top: 20,
            left: 20,
            right: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isEditing ? 'Edit Schedule' : 'New Schedule',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),

              // Time Picker Row
              ListTile(
                title: const Text('Execution Time'),
                subtitle: Text(
                  selectedTime.format(context),
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.teal),
                ),
                trailing: const Icon(Icons.access_time),
                onTap: () async {
                  final t = await showTimePicker(context: context, initialTime: selectedTime);
                  if (t != null) {
                    setModalState(() => selectedTime = t);
                  }
                },
              ),
              const Divider(),

              // Target Relay & Action
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      value: selectedChannel,
                      decoration: const InputDecoration(labelText: 'Target Appliance'),
                      items: List.generate(
                        8,
                        (i) => DropdownMenuItem(value: i + 1, child: Text('Relay ${i + 1}')),
                      ),
                      onChanged: (v) {
                        if (v != null) setModalState(() => selectedChannel = v);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      value: selectedAction,
                      decoration: const InputDecoration(labelText: 'Action'),
                      items: const [
                        DropdownMenuItem(value: 1, child: Text('Turn ON')),
                        DropdownMenuItem(value: 0, child: Text('Turn OFF')),
                        DropdownMenuItem(value: 2, child: Text('TOGGLE')),
                      ],
                      onChanged: (v) {
                        if (v != null) setModalState(() => selectedAction = v);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Repeat Days
              const Text('Repeat Days', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                children: List.generate(7, (dayIdx) {
                  final isSelected = (daysBitmask & (1 << dayIdx)) != 0;
                  return FilterChip(
                    label: Text(_dayNames[dayIdx]),
                    selected: isSelected,
                    selectedColor: Colors.teal.shade200,
                    onSelected: (selected) {
                      setModalState(() {
                        if (selected) {
                          daysBitmask |= (1 << dayIdx);
                        } else {
                          daysBitmask &= ~(1 << dayIdx);
                        }
                      });
                    },
                  );
                }),
              ),
              const SizedBox(height: 24),

              // Save Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    final newSched = ScheduleModel(
                      enabled: true,
                      days: daysBitmask,
                      hour: selectedTime.hour,
                      minute: selectedTime.minute,
                      channel: selectedChannel,
                      action: selectedAction,
                    );

                    setState(() {
                      if (isEditing) {
                        _schedules[editIndex] = newSched;
                      } else {
                        _schedules.add(newSched);
                      }
                    });

                    Navigator.pop(ctx);
                  },
                  child: Text(isEditing ? 'Save Changes' : 'Create Schedule'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDays(int bitmask) {
    if (bitmask == 127) return 'Everyday';
    if (bitmask == 62) return 'Weekdays (Mon-Fri)';
    if (bitmask == 65) return 'Weekends (Sat-Sun)';

    List<String> activeDays = [];
    for (int i = 0; i < 7; i++) {
      if ((bitmask & (1 << i)) != 0) {
        activeDays.add(_dayNames[i]);
      }
    }
    return activeDays.isEmpty ? 'None' : activeDays.join(', ');
  }

  @override
  Widget build(BuildContext context) {
    final mqtt = Provider.of<MqttService>(context);
    final isOnline = (mqtt.currentState?.isOnline ?? false) || mqtt.isConnected;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Autonomous Schedules', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.cloud_upload_outlined),
            tooltip: 'Sync Schedules to Board Flash',
            onPressed: isOnline
                ? () {
                    mqtt.syncSchedules(_schedules);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Schedules synced to ThaleSmart (Saved locally)!'),
                        backgroundColor: Colors.teal,
                      ),
                    );
                  }
                : null,
          ),
        ],
      ),
      body: _schedules.isEmpty
          ? const Center(
              child: Text('No schedules added yet. Tap + to create one!'),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _schedules.length,
              separatorBuilder: (ctx, i) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final s = _schedules[index];
                final timeStr =
                    '${s.hour.toString().padLeft(2, '0')}:${s.minute.toString().padLeft(2, '0')}';

                return Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 2,
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: CircleAvatar(
                      backgroundColor: Colors.teal.shade50,
                      radius: 24,
                      child: Text(
                        'R${s.channel}',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.teal),
                      ),
                    ),
                    title: Text(
                      timeStr,
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Action: ${s.action == 1 ? "TURN ON" : (s.action == 0 ? "TURN OFF" : "TOGGLE")}',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: s.action == 1 ? Colors.green : Colors.orange,
                          ),
                        ),
                        Text(_formatDays(s.days), style: const TextStyle(fontSize: 12)),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Switch(
                          value: s.enabled,
                          activeColor: Colors.teal,
                          onChanged: (val) {
                            setState(() => s.enabled = val);
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                          onPressed: () {
                            setState(() => _schedules.removeAt(index));
                          },
                        ),
                      ],
                    ),
                    onTap: () => _showAddEditScheduleDialog(index),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        onPressed: () => _showAddEditScheduleDialog(),
        icon: const Icon(Icons.add),
        label: const Text('Add Schedule'),
      ),
    );
  }
}
