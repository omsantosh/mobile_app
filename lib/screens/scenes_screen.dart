import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/device_state.dart';
import '../services/mqtt_service.dart';

class ScenesScreen extends StatelessWidget {
  const ScenesScreen({Key? key}) : super(key: key);

  List<SceneModel> _getDefaultScenes() {
    return [
      SceneModel(
        id: 'movie_night',
        name: 'Movie Night',
        iconName: 'movie',
        actions: [
          SceneAction(channel: 1, state: 0),
          SceneAction(channel: 2, state: 1),
          SceneAction(channel: 3, state: 1),
          SceneAction(channel: 4, state: 0),
        ],
      ),
      SceneModel(
        id: 'all_off',
        name: 'Good Night (All Off)',
        iconName: 'bedtime',
        actions: [
          SceneAction(channel: 1, state: 0),
          SceneAction(channel: 2, state: 0),
          SceneAction(channel: 3, state: 0),
          SceneAction(channel: 4, state: 0),
        ],
      ),
      SceneModel(
        id: 'morning_wake',
        name: 'Morning Wakeup',
        iconName: 'wb_sunny',
        actions: [
          SceneAction(channel: 1, state: 1),
          SceneAction(channel: 2, state: 1),
          SceneAction(channel: 3, state: 0),
          SceneAction(channel: 4, state: 0),
        ],
      ),
      SceneModel(
        id: 'work_focus',
        name: 'Work Focus',
        iconName: 'laptop_mac',
        actions: [
          SceneAction(channel: 1, state: 1),
          SceneAction(channel: 2, state: 0),
          SceneAction(channel: 3, state: 1),
          SceneAction(channel: 4, state: 1),
        ],
      ),
    ];
  }

  IconData _getIconData(String name) {
    switch (name) {
      case 'movie':
        return Icons.local_movies_outlined;
      case 'bedtime':
        return Icons.bedtime_outlined;
      case 'wb_sunny':
        return Icons.wb_sunny_outlined;
      case 'laptop_mac':
        return Icons.laptop_chromebook;
      default:
        return Icons.auto_awesome;
    }
  }

  @override
  Widget build(BuildContext context) {
    final mqtt = Provider.of<MqttService>(context);
    final isOnline = (mqtt.currentState?.isOnline ?? false) || mqtt.isConnected;
    final scenes = _getDefaultScenes();

    return Scaffold(
      appBar: AppBar(
        title: const Text('One-Tap Scenes', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Automated Lighting & Power Presets',
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.separated(
                itemCount: scenes.length,
                separatorBuilder: (ctx, i) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final scene = scenes[index];

                  return Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 2,
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      leading: CircleAvatar(
                        radius: 24,
                        backgroundColor: Colors.teal.withOpacity(0.15),
                        child: Icon(_getIconData(scene.iconName), color: Colors.teal),
                      ),
                      title: Text(
                        scene.name,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      subtitle: Text(
                        'Controls ${scene.actions.length} channels simultaneously',
                        style: const TextStyle(fontSize: 12),
                      ),
                      trailing: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isOnline ? Colors.teal : Colors.grey,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: isOnline
                            ? () {
                                mqtt.triggerScene(scene);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Activated "${scene.name}" scene!'),
                                    duration: const Duration(seconds: 1),
                                  ),
                                );
                              }
                            : null,
                        child: const Text('Activate'),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
