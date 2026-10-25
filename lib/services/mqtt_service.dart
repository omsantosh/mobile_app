import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import '../models/device_state.dart';

class MqttService extends ChangeNotifier {
  MqttServerClient? _client;
  bool _isConnected = false;
  bool _isConnecting = false;
  String _activeDeviceId = '';
  DeviceState? _currentState;
  StreamSubscription? _subscription;
  Map<String, dynamic>? _lastIrEvent;

  bool get isConnected => _isConnected;
  bool get isConnecting => _isConnecting;
  String get activeDeviceId => _activeDeviceId;
  DeviceState? get currentState => _currentState;
  Map<String, dynamic>? get lastIrEvent => _lastIrEvent;

  Future<bool> connect({
    required String broker,
    int port = 1883,
    required String clientId,
    String? username,
    String? password,
    required String deviceId,
  }) async {
    _activeDeviceId = deviceId.trim();
    _isConnecting = true;
    notifyListeners();

    try {
      // 1. Try standard TCP (port 1883)
      debugPrint('Connecting to MQTT broker $broker:$port via TCP...');
      bool ok = await _tryConnect(
        broker: broker,
        port: port,
        clientId: clientId,
        username: username,
        password: password,
        useWebSocket: false,
      );

      // 2. If TCP fails, fallback to Secure WebSocket (wss://...:8884/mqtt)
      if (!ok) {
        debugPrint('TCP failed, trying secure WSS 8884...');
        ok = await _tryConnect(
          broker: broker,
          port: 8884,
          clientId: '${clientId}_wss',
          username: username,
          password: password,
          useWebSocket: true,
        );
      }

      return ok;
    } catch (e) {
      debugPrint('Error in connect: $e');
      return false;
    } finally {
      _isConnecting = false;
      notifyListeners();
    }
  }

  Future<bool> _tryConnect({
    required String broker,
    required int port,
    required String clientId,
    String? username,
    String? password,
    required bool useWebSocket,
  }) async {
    try {
      _subscription?.cancel();
      _subscription = null;

      if (_client != null) {
        try {
          _client!.autoReconnect = false;
          _client!.onDisconnected = null;
          _client!.onConnected = null;
          _client!.disconnect();
        } catch (_) {}
        _client = null;
      }

      final host = broker
          .replaceAll('ws://', '')
          .replaceAll('wss://', '')
          .replaceAll('/mqtt', '')
          .replaceAll('http://', '')
          .replaceAll('https://', '')
          .trim();

      if (useWebSocket) {
        _client = MqttServerClient('wss://$host/mqtt', clientId);
        _client!.port = port;
        _client!.useWebSocket = true;
        _client!.websocketProtocols = MqttClientConstants.protocolsSingleDefault;
      } else {
        _client = MqttServerClient(host, clientId);
        _client!.port = port;
      }

      _client!.logging(on: false);
      _client!.keepAlivePeriod = 30;
      _client!.autoReconnect = true;
      _client!.onConnected = _onClientConnected;
      _client!.onDisconnected = _onClientDisconnected;

      final connMessage = MqttConnectMessage()
          .withClientIdentifier(clientId)
          .startClean();

      if (username != null && username.isNotEmpty) {
        connMessage.authenticateAs(username, password ?? '');
      }

      _client!.connectionMessage = connMessage;

      final status = await _client!.connect();

      if (status != null && status.state == MqttConnectionState.connected) {
        debugPrint('Connected to MQTT broker ($host:$port, ws: $useWebSocket)');
        _isConnected = true;
        _setupSubscriptions();
        notifyListeners();
        return true;
      } else {
        debugPrint('MQTT connection status was not connected: ${status?.state}');
        return false;
      }
    } catch (e) {
      debugPrint('MQTT Connection attempt error ($broker:$port, ws: $useWebSocket): $e');
      return false;
    }
  }

  void _onClientConnected() {
    _isConnected = true;
    _setupSubscriptions();
    notifyListeners();
  }

  void _onClientDisconnected() {
    _isConnected = false;
    _isConnecting = false;
    if (_currentState != null) {
      _currentState = _currentState!.copyWith(isOnline: false);
    }
    notifyListeners();
  }

  void _setupSubscriptions() {
    if (_client == null || _client!.connectionStatus?.state != MqttConnectionState.connected) {
      return;
    }

    final statusTopic = 'home/$_activeDeviceId/status';
    final stateTopic = 'home/$_activeDeviceId/state';
    final irTopic = 'home/$_activeDeviceId/ir/status';

    _client!.subscribe(statusTopic, MqttQos.atLeastOnce);
    _client!.subscribe(stateTopic, MqttQos.atLeastOnce);
    _client!.subscribe(irTopic, MqttQos.atLeastOnce);

    _subscription?.cancel();
    _subscription = _client!.updates?.listen((List<MqttReceivedMessage<MqttMessage>> messages) {
      for (var msg in messages) {
        final recMess = msg.payload as MqttPublishMessage;
        final payload = MqttPublishPayload.bytesToStringAsString(recMess.payload.message);

        if (msg.topic == statusTopic) {
          final isOnline = payload.trim().toLowerCase() == 'online';
          if (_currentState != null) {
            _currentState = _currentState!.copyWith(isOnline: isOnline);
          } else {
            _currentState = DeviceState(
              deviceId: _activeDeviceId,
              isOnline: isOnline,
              relayStates: [0, 0, 0, 0],
            );
          }
          notifyListeners();
        } else if (msg.topic == stateTopic) {
          try {
            final Map<String, dynamic> data = jsonDecode(payload);
            _currentState = DeviceState.fromJson(data, isOnline: true);
            notifyListeners();
          } catch (e) {
            debugPrint('Error parsing state JSON: $e');
          }
        } else if (msg.topic == irTopic) {
          try {
            final Map<String, dynamic> data = jsonDecode(payload);
            _lastIrEvent = data;
            notifyListeners();
          } catch (e) {
            debugPrint('Error parsing IR event: $e');
          }
        }
      }
    });
  }

  void toggleRelay(int channel) {
    if (!_isConnected || _client == null) return;
    if (_currentState != null) {
      final updatedList = List<int>.from(_currentState!.relayStates);
      final idx = channel - 1;
      if (idx >= 0 && idx < updatedList.length) {
        updatedList[idx] = updatedList[idx] == 1 ? 0 : 1;
        _currentState = _currentState!.copyWith(relayStates: updatedList);
        notifyListeners();
      }
    }
    final topic = 'home/$_activeDeviceId/set';
    final payload = jsonEncode({'channel': channel, 'toggle': true});
    _publish(topic, payload);
  }

  void setRelay(int channel, int state) {
    if (!_isConnected || _client == null) return;
    if (_currentState != null) {
      final updatedList = List<int>.from(_currentState!.relayStates);
      final idx = channel - 1;
      if (idx >= 0 && idx < updatedList.length) {
        updatedList[idx] = state;
        _currentState = _currentState!.copyWith(relayStates: updatedList);
        notifyListeners();
      }
    }
    final topic = 'home/$_activeDeviceId/set';
    final payload = jsonEncode({'channel': channel, 'state': state});
    _publish(topic, payload);
  }

  void setAllRelays(int state) {
    if (!_isConnected || _client == null) return;
    if (_currentState != null) {
      final count = _currentState!.relayStates.isNotEmpty ? _currentState!.relayStates.length : 4;
      final updatedList = List<int>.filled(count, state);
      _currentState = _currentState!.copyWith(relayStates: updatedList);
      notifyListeners();
    }
    final topic = 'home/$_activeDeviceId/set';
    final payload = jsonEncode({'all': state});
    _publish(topic, payload);
  }

  void triggerScene(SceneModel scene) {
    if (!_isConnected || _client == null) return;
    final topic = 'home/$_activeDeviceId/scene';
    final payload = jsonEncode({
      'name': scene.name,
      'actions': scene.actions.map((a) => a.toJson()).toList(),
    });
    _publish(topic, payload);
  }

  void syncSchedules(List<ScheduleModel> schedules) {
    if (!_isConnected || _client == null) return;
    final topic = 'home/$_activeDeviceId/schedules/set';
    final payload = jsonEncode({
      'schedules': schedules.map((s) => s.toJson()).toList(),
    });
    _publish(topic, payload);
  }

  void startCountdownTimer(int channel, int durationSeconds, int targetState) {
    if (!_isConnected || _client == null) return;
    final topic = 'home/$_activeDeviceId/timer';
    final payload = jsonEncode({
      'channel': channel,
      'seconds': durationSeconds,
      'state': targetState,
    });
    _publish(topic, payload);
  }

  void startIrLearning(int target) {
    if (!_isConnected || _client == null) return;
    final topic = 'home/$_activeDeviceId/ir/learn';
    final payload = jsonEncode({'target': target});
    _publish(topic, payload);
  }

  void clearIrCode(int target) {
    if (!_isConnected || _client == null) return;
    final topic = 'home/$_activeDeviceId/ir/clear';
    final payload = jsonEncode({'target': target});
    _publish(topic, payload);
  }

  void updateRoomName(String newRoomName) {
    if (!_isConnected || _client == null) return;
    if (_currentState != null) {
      _currentState = _currentState!.copyWith(roomName: newRoomName);
      notifyListeners();
    }
    final topic = 'home/$_activeDeviceId/config/set';
    final payload = jsonEncode({'room': newRoomName});
    _publish(topic, payload);
  }

  void updateRelayConfig(int channel, String name, String icon) {
    if (!_isConnected || _client == null) return;
    if (_currentState != null) {
      final names = List<String>.from(_currentState!.relayNames);
      final icons = List<String>.from(_currentState!.relayIcons);
      final idx = channel - 1;
      while (names.length <= idx) names.add('Relay ${names.length + 1}');
      while (icons.length <= idx) icons.add('light');
      names[idx] = name;
      icons[idx] = icon;
      _currentState = _currentState!.copyWith(relayNames: names, relayIcons: icons);
      notifyListeners();
    }
    final topic = 'home/$_activeDeviceId/config/set';
    final payload = jsonEncode({'channel': channel, 'name': name, 'icon': icon});
    _publish(topic, payload);
  }

  void _publish(String topic, String payload) {
    final builder = MqttClientPayloadBuilder();
    builder.addString(payload);
    _client?.publishMessage(topic, MqttQos.atLeastOnce, builder.payload!);
  }

  void disconnect() {
    _subscription?.cancel();
    _subscription = null;
    _client?.disconnect();
    _isConnected = false;
    _isConnecting = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _client?.disconnect();
    super.dispose();
  }
}
