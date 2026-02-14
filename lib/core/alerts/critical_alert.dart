class CriticalAlertPayload {
  final String eventId;
  final String eventType;
  final String severity;
  final String title;
  final String body;
  final String? route;
  final String? instanceId;
  final String? sosEventId;
  final String? dependentId;
  final String? dependentName;
  final int? callTimeoutSeconds;
  final DateTime receivedAt;

  const CriticalAlertPayload({
    required this.eventId,
    required this.eventType,
    required this.severity,
    required this.title,
    required this.body,
    required this.receivedAt,
    this.route,
    this.instanceId,
    this.sosEventId,
    this.dependentId,
    this.dependentName,
    this.callTimeoutSeconds,
  });

  bool get isSosEvent =>
      eventType == 'sos' ||
      eventType == 'sos_triggered' ||
      eventType == 'critical_sos';

  static CriticalAlertPayload fromData(Map<String, dynamic> data) {
    final now = DateTime.now();
    final eventId =
        (data['eventId'] ?? data['sosEventId'] ?? data['instanceId'] ?? '${now.microsecondsSinceEpoch}')
            .toString();
    final eventType = (data['eventType'] ?? data['type'] ?? 'unknown').toString();
    final severity = (data['severity'] ?? (data['critical'] == 'true' ? 'critical' : 'normal')).toString();
    final title = (data['title'] ?? data['notificationTitle'] ?? 'Critical Alert').toString();
    final body = (data['body'] ?? data['notificationBody'] ?? '').toString();
    final callTimeoutSeconds =
        int.tryParse((data['callTimeoutSeconds'] ??
                data['callStyleTimeoutSeconds'] ??
                '')
            .toString());

    return CriticalAlertPayload(
      eventId: eventId,
      eventType: eventType,
      severity: severity,
      title: title,
      body: body,
      route: data['route']?.toString(),
      instanceId: data['instanceId']?.toString(),
      sosEventId: data['sosEventId']?.toString(),
      dependentId: data['dependentId']?.toString(),
      dependentName: data['dependentName']?.toString(),
      callTimeoutSeconds: callTimeoutSeconds,
      receivedAt: now,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'eventId': eventId,
      'eventType': eventType,
      'severity': severity,
      'title': title,
      'body': body,
      'route': route,
      'instanceId': instanceId,
      'sosEventId': sosEventId,
      'dependentId': dependentId,
      'dependentName': dependentName,
      'callTimeoutSeconds': callTimeoutSeconds?.toString(),
      'receivedAt': receivedAt.toIso8601String(),
    }..removeWhere((key, value) => value == null || value.toString().isEmpty);
  }

  bool get isCritical {
    final normalizedSeverity = severity.toLowerCase();
    final normalizedType = eventType.toLowerCase();
    return normalizedSeverity == 'critical' ||
        normalizedType.contains('sos') ||
        normalizedType.contains('urgent');
  }

  String resolveRoute({required String userRole}) {
    if (route != null && route!.isNotEmpty) {
      return route!;
    }

    if (isSosEvent) {
      return userRole == 'caregiver' ? '/caregiver' : '/dependent/sos';
    }

    if (instanceId != null && instanceId!.isNotEmpty) {
      return '/dependent/reminder/$instanceId';
    }

    return userRole == 'caregiver' ? '/caregiver' : '/dependent';
  }
}
