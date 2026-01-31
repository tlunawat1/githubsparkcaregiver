import 'package:intl/intl.dart';

import 'api_client.dart';

/// Reminder instance data from API
class ReminderInstanceData {
  final String id;
  final String reminderId;
  final DateTime scheduledTime;
  final String status;
  final DateTime? completedAt;
  final DateTime? snoozedUntil;
  final int escalationLevel;
  final DateTime createdAt;
  // Reminder details included for convenience
  final String? reminderTitle;
  final String? reminderDescription;
  final String? voiceNoteUrl;
  final String? priority;

  ReminderInstanceData({
    required this.id,
    required this.reminderId,
    required this.scheduledTime,
    required this.status,
    this.completedAt,
    this.snoozedUntil,
    required this.escalationLevel,
    required this.createdAt,
    this.reminderTitle,
    this.reminderDescription,
    this.voiceNoteUrl,
    this.priority,
  });

  factory ReminderInstanceData.fromJson(Map<String, dynamic> json) {
    return ReminderInstanceData(
      id: json['id'] as String,
      reminderId: json['reminderId'] as String,
      scheduledTime: DateTime.parse(json['scheduledTime'] as String),
      status: json['status'] as String,
      completedAt: json['completedAt'] != null
          ? DateTime.parse(json['completedAt'] as String)
          : null,
      snoozedUntil: json['snoozedUntil'] != null
          ? DateTime.parse(json['snoozedUntil'] as String)
          : null,
      escalationLevel: json['escalationLevel'] as int? ?? 0,
      createdAt: DateTime.parse(json['createdAt'] as String),
      reminderTitle: json['reminderTitle'] as String?,
      reminderDescription: json['reminderDescription'] as String?,
      voiceNoteUrl: json['voiceNoteUrl'] as String?,
      priority: json['priority'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'reminderId': reminderId,
        'scheduledTime': scheduledTime.toIso8601String(),
        'status': status,
        'completedAt': completedAt?.toIso8601String(),
        'snoozedUntil': snoozedUntil?.toIso8601String(),
        'escalationLevel': escalationLevel,
        'createdAt': createdAt.toIso8601String(),
        'reminderTitle': reminderTitle,
        'reminderDescription': reminderDescription,
        'voiceNoteUrl': voiceNoteUrl,
        'priority': priority,
      };
}

/// Reminder Instance API service
class ReminderInstanceApi {
  final ApiClient _client;

  ReminderInstanceApi(this._client);

  /// Get instances for a dependent on a specific date
  Future<List<ReminderInstanceData>> getInstances({
    required String dependentId,
    required DateTime date,
  }) async {
    // Format as local date string - server will interpret in its timezone
    final dateStr = DateFormat('yyyy-MM-dd').format(date);
    final response = await _client.get(
      '/api/reminder-instances',
      queryParameters: {
        'dependentId': dependentId,
        'date': dateStr,
      },
    );

    final data = response['data'] as List? ?? [];
    return data
        .map((json) => ReminderInstanceData.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Get all instances for a dependent (no date filter)
  Future<List<ReminderInstanceData>> getAllInstances({
    required String dependentId,
  }) async {
    final response = await _client.get(
      '/api/reminder-instances',
      queryParameters: {
        'dependentId': dependentId,
      },
    );

    final data = response['data'] as List? ?? [];
    return data
        .map((json) => ReminderInstanceData.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Get a single instance by ID
  Future<ReminderInstanceData> getInstance(String id) async {
    final response = await _client.get('/api/reminder-instances/$id');
    return ReminderInstanceData.fromJson(response);
  }

  /// Create a new instance
  Future<ReminderInstanceData> createInstance({
    required String reminderId,
    required DateTime scheduledTime,
  }) async {
    final response = await _client.post(
      '/api/reminder-instances',
      body: {
        'reminderId': reminderId,
        'scheduledTime': scheduledTime.toIso8601String(),
      },
    );
    return ReminderInstanceData.fromJson(response);
  }

  /// Mark an instance as completed
  Future<ReminderInstanceData> markCompleted(String id) async {
    final response = await _client.put('/api/reminder-instances/$id/complete');
    return ReminderInstanceData.fromJson(response);
  }

  /// Snooze an instance
  Future<ReminderInstanceData> snooze(String id, DateTime snoozedUntil) async {
    final response = await _client.put(
      '/api/reminder-instances/$id/snooze',
      body: {
        'snoozedUntil': snoozedUntil.toIso8601String(),
      },
    );
    return ReminderInstanceData.fromJson(response);
  }

  /// Mark an instance as missed
  Future<ReminderInstanceData> markMissed(String id) async {
    final response = await _client.put('/api/reminder-instances/$id/miss');
    return ReminderInstanceData.fromJson(response);
  }

  /// Escalate an instance
  Future<ReminderInstanceData> escalate(String id) async {
    final response = await _client.put('/api/reminder-instances/$id/escalate');
    return ReminderInstanceData.fromJson(response);
  }
}
