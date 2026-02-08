import 'dart:convert';

class CriticalAlertPayload {
  final String alertId;
  final String type;
  final String title;
  final String body;
  final String? instanceId;
  final String? dependentId;
  final String? sosEventId;
  final String? route;
  final String? initiatedAt;

  const CriticalAlertPayload({
    required this.alertId,
    required this.type,
    required this.title,
    required this.body,
    this.instanceId,
    this.dependentId,
    this.sosEventId,
    this.route,
    this.initiatedAt,
  });

  factory CriticalAlertPayload.fromMap(Map<String, dynamic> data) {
    return CriticalAlertPayload(
      alertId: data['alertId']?.toString() ?? '',
      type: data['alertType']?.toString() ?? data['type']?.toString() ?? 'critical_alert',
      title: data['title']?.toString() ?? 'Critical Alert',
      body: data['body']?.toString() ?? '',
      instanceId: data['instanceId']?.toString(),
      dependentId: data['dependentId']?.toString(),
      sosEventId: data['sosEventId']?.toString(),
      route: data['route']?.toString(),
      initiatedAt: data['initiatedAt']?.toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'alertId': alertId,
      'alertType': type,
      'title': title,
      'body': body,
      'instanceId': instanceId,
      'dependentId': dependentId,
      'sosEventId': sosEventId,
      'route': route,
      'initiatedAt': initiatedAt,
    }..removeWhere((key, value) => value == null || value.toString().isEmpty);
  }

  String toJson() => json.encode(toMap());

  static CriticalAlertPayload? fromJson(String? jsonString) {
    if (jsonString == null || jsonString.isEmpty) return null;
    try {
      final data = json.decode(jsonString) as Map<String, dynamic>;
      return CriticalAlertPayload.fromMap(data);
    } catch (_) {
      return null;
    }
  }

  CriticalAlertPayload copyWith({
    String? alertId,
    String? type,
    String? title,
    String? body,
    String? instanceId,
    String? dependentId,
    String? sosEventId,
    String? route,
    String? initiatedAt,
  }) {
    return CriticalAlertPayload(
      alertId: alertId ?? this.alertId,
      type: type ?? this.type,
      title: title ?? this.title,
      body: body ?? this.body,
      instanceId: instanceId ?? this.instanceId,
      dependentId: dependentId ?? this.dependentId,
      sosEventId: sosEventId ?? this.sosEventId,
      route: route ?? this.route,
      initiatedAt: initiatedAt ?? this.initiatedAt,
    );
  }

  String get resolvedRoute {
    if (route != null && route!.isNotEmpty) {
      return route!;
    }
    if (type == 'sos' || type == 'sos_triggered') {
      return '/dependent/sos';
    }
    if (instanceId != null && instanceId!.isNotEmpty) {
      return '/dependent/reminder/$instanceId';
    }
    return '/dependent';
  }
}
