import 'dart:convert';

class DeviceState {
  final String deviceId;
  final bool isOnline;
  final List<int> relayStates;
  final int rssi;
  final int uptimeSec;
  final String ip;
  final String roomName;
  final List<String> relayNames;
  final List<String> relayIcons;

  DeviceState({
    required this.deviceId,
    this.isOnline = false,
    required this.relayStates,
    this.rssi = 0,
    this.uptimeSec = 0,
    this.ip = '',
    this.roomName = 'Living Room',
    this.relayNames = const [],
    this.relayIcons = const [],
  });

  factory DeviceState.fromJson(Map<String, dynamic> json, {bool isOnline = true}) {
    List<int> relays = [];
    if (json['relays'] != null) {
      relays = List<int>.from(json['relays']);
    }
    List<String> names = [];
    if (json['names'] != null) {
      names = List<String>.from(json['names']);
    }
    List<String> icons = [];
    if (json['icons'] != null) {
      icons = List<String>.from(json['icons']);
    }
    return DeviceState(
      deviceId: json['device'] ?? '',
      isOnline: isOnline,
      relayStates: relays,
      rssi: json['wifi_rssi'] ?? 0,
      uptimeSec: json['uptime_sec'] ?? 0,
      ip: json['ip'] ?? '',
      roomName: json['room'] ?? 'Living Room',
      relayNames: names,
      relayIcons: icons,
    );
  }

  DeviceState copyWith({
    String? deviceId,
    bool? isOnline,
    List<int>? relayStates,
    int? rssi,
    int? uptimeSec,
    String? ip,
    String? roomName,
    List<String>? relayNames,
    List<String>? relayIcons,
  }) {
    return DeviceState(
      deviceId: deviceId ?? this.deviceId,
      isOnline: isOnline ?? this.isOnline,
      relayStates: relayStates ?? this.relayStates,
      rssi: rssi ?? this.rssi,
      uptimeSec: uptimeSec ?? this.uptimeSec,
      ip: ip ?? this.ip,
      roomName: roomName ?? this.roomName,
      relayNames: relayNames ?? this.relayNames,
      relayIcons: relayIcons ?? this.relayIcons,
    );
  }
}

class ScheduleModel {
  bool enabled;
  int days; // Bitmask: Bit 0 = Sun ... Bit 6 = Sat
  int hour;
  int minute;
  int channel;
  int action; // 0 = OFF, 1 = ON, 2 = TOGGLE

  ScheduleModel({
    required this.enabled,
    required this.days,
    required this.hour,
    required this.minute,
    required this.channel,
    required this.action,
  });

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'days': days,
        'hour': hour,
        'min': minute,
        'channel': channel,
        'action': action,
      };

  factory ScheduleModel.fromJson(Map<String, dynamic> json) => ScheduleModel(
        enabled: json['enabled'] ?? false,
        days: json['days'] ?? 127,
        hour: json['hour'] ?? 0,
        minute: json['min'] ?? 0,
        channel: json['channel'] ?? 1,
        action: json['action'] ?? 0,
      );
}

class SceneAction {
  final int channel;
  final int state;

  SceneAction({required this.channel, required this.state});

  Map<String, dynamic> toJson() => {
        'channel': channel,
        'state': state,
      };
}

class SceneModel {
  final String id;
  final String name;
  final String iconName;
  final List<SceneAction> actions;

  SceneModel({
    required this.id,
    required this.name,
    required this.iconName,
    required this.actions,
  });
}
