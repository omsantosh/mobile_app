import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/mqtt_service.dart';
import 'services/ble_service.dart';
import 'screens/dashboard_screen.dart';
import 'screens/scenes_screen.dart';
import 'screens/schedules_screen.dart';
import 'screens/ble_provision_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => MqttService()),
        ChangeNotifierProvider(create: (_) => BleService()),
      ],
      child: const ThaleSmartApp(),
    ),
  );
}

class ThaleSmartApp extends StatelessWidget {
  const ThaleSmartApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ThaleSmart',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.teal,
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFF7F9FA),
        cardTheme: const CardThemeData(
          color: Colors.white,
          elevation: 2,
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.teal,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF121417),
      ),
      themeMode: ThemeMode.system,
      home: const MainNavigationShell(),
    );
  }
}

class MainNavigationShell extends StatefulWidget {
  const MainNavigationShell({Key? key}) : super(key: key);

  @override
  State<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends State<MainNavigationShell> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    DashboardScreen(),
    ScenesScreen(),
    SchedulesScreen(),
    BleProvisionScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _autoConnectIfSaved();
    });
  }

  Future<void> _autoConnectIfSaved() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedDevice = prefs.getString('device_id');
      final savedBroker = prefs.getString('mqtt_broker') ?? 'broker.hivemq.com';
      if (savedDevice != null && savedDevice.trim().isNotEmpty && mounted) {
        final mqtt = Provider.of<MqttService>(context, listen: false);
        if (!mqtt.isConnected) {
          final clientId = 'App_${DateTime.now().millisecondsSinceEpoch}';
          await mqtt.connect(
            broker: savedBroker.trim(),
            clientId: clientId,
            deviceId: savedDevice.trim(),
          );
        }
      }
    } catch (e) {
      debugPrint('Auto connect error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() => _currentIndex = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.auto_awesome_outlined),
            selectedIcon: Icon(Icons.auto_awesome),
            label: 'Scenes',
          ),
          NavigationDestination(
            icon: Icon(Icons.alarm_outlined),
            selectedIcon: Icon(Icons.alarm),
            label: 'Schedules',
          ),
          NavigationDestination(
            icon: Icon(Icons.bluetooth_searching),
            selectedIcon: Icon(Icons.bluetooth_connected),
            label: 'BLE Setup',
          ),
        ],
      ),
    );
  }
}
