class CriticalAlertPayload {
  final String alertId;
  final String type;
  final String? instanceId;
  final String? sosEventId;
  final String? dependentId;
  final String? dependentName;
  final String? route;

  const CriticalAlertPayload({
    required this.alertId,
    required this.type,
    this.instanceId,
    this.sosEventId,
    this.dependentId,
    this.dependentName,
    this.route,
  });

  factory CriticalAlertPayload.fromMap(Map<String, dynamic> data) {
    return CriticalAlertPayload(
      alertId: data['alertId'] as String? ?? '',
      type: data['type'] as String? ?? 'unknown',
      instanceId: data['instanceId'] as String?,
      sosEventId: data['sosEventId'] as String?,
      dependentId: data['dependentId'] as String?,
      dependentName: data['dependentName'] as String?,
      route: data['route'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        'alertId': alertId,
        'type': type,
        if (instanceId != null) 'instanceId': instanceId,
        if (sosEventId != null) 'sosEventId': sosEventId,
        if (dependentId != null) 'dependentId': dependentId,
        if (dependentName != null) 'dependentName': dependentName,
        if (route != null) 'route': route,
      };
}
