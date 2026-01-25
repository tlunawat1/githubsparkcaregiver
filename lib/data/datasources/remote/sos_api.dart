import 'api_client.dart';

/// SOS event data from API
class SosEventData {
  final String id;
  final String dependentId;
  final String status;
  final DateTime triggeredAt;
  final DateTime? resolvedAt;
  final String? resolvedBy;
  final String? notes;
  final DateTime createdAt;
  final String? dependentName;
  final String? resolverName;

  SosEventData({
    required this.id,
    required this.dependentId,
    required this.status,
    required this.triggeredAt,
    this.resolvedAt,
    this.resolvedBy,
    this.notes,
    required this.createdAt,
    this.dependentName,
    this.resolverName,
  });

  factory SosEventData.fromJson(Map<String, dynamic> json) {
    return SosEventData(
      id: json['id'] as String,
      dependentId: json['dependentId'] as String,
      status: json['status'] as String,
      triggeredAt: DateTime.parse(json['triggeredAt'] as String),
      resolvedAt: json['resolvedAt'] != null
          ? DateTime.parse(json['resolvedAt'] as String)
          : null,
      resolvedBy: json['resolvedBy'] as String?,
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      dependentName: json['dependentName'] as String?,
      resolverName: json['resolverName'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'dependentId': dependentId,
        'status': status,
        'triggeredAt': triggeredAt.toIso8601String(),
        'resolvedAt': resolvedAt?.toIso8601String(),
        'resolvedBy': resolvedBy,
        'notes': notes,
        'createdAt': createdAt.toIso8601String(),
        'dependentName': dependentName,
        'resolverName': resolverName,
      };

  bool get isTriggered => status == 'triggered';
  bool get isResolved => status == 'resolved';
  bool get isCancelled => status == 'cancelled';
}

/// Trigger SOS response
class TriggerSosResponse {
  final String id;
  final String status;
  final DateTime triggeredAt;
  final String message;
  final int notifiedCaregivers;

  TriggerSosResponse({
    required this.id,
    required this.status,
    required this.triggeredAt,
    required this.message,
    required this.notifiedCaregivers,
  });

  factory TriggerSosResponse.fromJson(Map<String, dynamic> json) {
    return TriggerSosResponse(
      id: json['id'] as String,
      status: json['status'] as String,
      triggeredAt: DateTime.parse(json['triggeredAt'] as String),
      message: json['message'] as String? ?? '',
      notifiedCaregivers: json['notifiedCaregivers'] as int? ?? 0,
    );
  }
}

/// Resolve SOS response
class ResolveSosResponse {
  final bool success;
  final String message;
  final SosEventData? event;

  ResolveSosResponse({
    required this.success,
    required this.message,
    this.event,
  });

  factory ResolveSosResponse.fromJson(Map<String, dynamic> json) {
    return ResolveSosResponse(
      success: json['success'] as bool? ?? false,
      message: json['message'] as String? ?? '',
      event: json['event'] != null
          ? SosEventData.fromJson(json['event'] as Map<String, dynamic>)
          : null,
    );
  }
}

/// SOS API service
class SosApi {
  final ApiClient _client;

  SosApi(this._client);

  /// Get SOS events
  Future<List<SosEventData>> getSosEvents({
    String? dependentId,
    bool recentOnly = false,
  }) async {
    final queryParams = <String, String>{};
    if (dependentId != null) {
      queryParams['dependentId'] = dependentId;
    }
    if (recentOnly) {
      queryParams['recentOnly'] = 'true';
    }

    final response = await _client.get(
      '/api/sos',
      queryParameters: queryParams.isNotEmpty ? queryParams : null,
    );

    final data = response['data'] as List? ?? [];
    return data
        .map((json) => SosEventData.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Get active SOS event
  Future<SosEventData?> getActiveSosEvent({String? dependentId}) async {
    final queryParams = <String, String>{};
    if (dependentId != null) {
      queryParams['dependentId'] = dependentId;
    }

    final response = await _client.get(
      '/api/sos/active',
      queryParameters: queryParams.isNotEmpty ? queryParams : null,
    );

    // Response might be null or empty if no active SOS
    if (response.isEmpty || response['id'] == null) {
      return null;
    }

    return SosEventData.fromJson(response);
  }

  /// Trigger SOS alert
  Future<TriggerSosResponse> triggerSos({String? notes}) async {
    final response = await _client.post(
      '/api/sos',
      body: notes != null ? {'notes': notes} : null,
    );
    return TriggerSosResponse.fromJson(response);
  }

  /// Resolve SOS event
  Future<ResolveSosResponse> resolveSos({
    required String id,
    String? notes,
  }) async {
    final response = await _client.put(
      '/api/sos/$id/resolve',
      body: notes != null ? {'notes': notes} : null,
    );
    return ResolveSosResponse.fromJson(response);
  }

  /// Cancel SOS event (dependent only)
  Future<void> cancelSos(String id) async {
    await _client.put('/api/sos/$id/cancel');
  }
}
