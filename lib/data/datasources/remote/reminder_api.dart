import 'api_client.dart';

/// Reminder data from API
class ReminderData {
  final String id;
  final String creatorId;
  final String dependentId;
  final String title;
  final String? description;
  final String? voiceNoteUrl;
  final String repeatPattern;
  final String? repeatDays;
  final int hour;
  final int minute;
  final String priority;
  final bool isActive;
  final DateTime startDate;
  final DateTime? endDate;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? creatorName;
  final String? dependentName;

  ReminderData({
    required this.id,
    required this.creatorId,
    required this.dependentId,
    required this.title,
    this.description,
    this.voiceNoteUrl,
    required this.repeatPattern,
    this.repeatDays,
    required this.hour,
    required this.minute,
    required this.priority,
    required this.isActive,
    required this.startDate,
    this.endDate,
    required this.createdAt,
    required this.updatedAt,
    this.creatorName,
    this.dependentName,
  });

  factory ReminderData.fromJson(Map<String, dynamic> json) {
    return ReminderData(
      id: json['id'] as String,
      creatorId: json['creatorId'] as String,
      dependentId: json['dependentId'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      voiceNoteUrl: json['voiceNoteUrl'] as String?,
      repeatPattern: json['repeatPattern'] as String,
      repeatDays: json['repeatDays'] as String?,
      hour: json['hour'] as int,
      minute: json['minute'] as int,
      priority: json['priority'] as String,
      isActive: json['isActive'] as bool? ?? true,
      startDate: DateTime.parse(json['startDate'] as String),
      endDate: json['endDate'] != null
          ? DateTime.parse(json['endDate'] as String)
          : null,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      creatorName: json['creatorName'] as String?,
      dependentName: json['dependentName'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'creatorId': creatorId,
        'dependentId': dependentId,
        'title': title,
        'description': description,
        'voiceNoteUrl': voiceNoteUrl,
        'repeatPattern': repeatPattern,
        'repeatDays': repeatDays,
        'hour': hour,
        'minute': minute,
        'priority': priority,
        'isActive': isActive,
        'startDate': startDate.toIso8601String(),
        'endDate': endDate?.toIso8601String(),
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'creatorName': creatorName,
        'dependentName': dependentName,
      };
}

/// Reminder API service
class ReminderApi {
  final ApiClient _client;

  ReminderApi(this._client);

  /// Get reminders (optionally filtered by dependent)
  Future<List<ReminderData>> getReminders({String? dependentId}) async {
    final queryParams = <String, String>{};
    if (dependentId != null) {
      queryParams['dependentId'] = dependentId;
    }

    final response = await _client.get(
      '/api/reminders',
      queryParameters: queryParams.isNotEmpty ? queryParams : null,
    );

    final data = response['data'] as List? ?? [];
    return data
        .map((json) => ReminderData.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Get a specific reminder by ID
  Future<ReminderData> getReminder(String id) async {
    final response = await _client.get('/api/reminders/$id');
    return ReminderData.fromJson(response);
  }

  /// Create a new reminder
  Future<ReminderData> createReminder({
    required String dependentId,
    required String title,
    String? description,
    String? voiceNoteUrl,
    required String repeatPattern,
    String? repeatDays,
    required int hour,
    required int minute,
    String priority = 'normal',
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final response = await _client.post(
      '/api/reminders',
      body: {
        'dependentId': dependentId,
        'title': title,
        if (description != null) 'description': description,
        if (voiceNoteUrl != null) 'voiceNoteUrl': voiceNoteUrl,
        'repeatPattern': repeatPattern,
        if (repeatDays != null) 'repeatDays': repeatDays,
        'hour': hour,
        'minute': minute,
        'priority': priority,
        if (startDate != null) 'startDate': startDate.toIso8601String(),
        if (endDate != null) 'endDate': endDate.toIso8601String(),
      },
    );
    return ReminderData.fromJson(response);
  }

  /// Update an existing reminder
  Future<ReminderData> updateReminder({
    required String id,
    String? title,
    String? description,
    String? voiceNoteUrl,
    String? repeatPattern,
    String? repeatDays,
    int? hour,
    int? minute,
    String? priority,
    bool? isActive,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final response = await _client.put(
      '/api/reminders/$id',
      body: {
        if (title != null) 'title': title,
        if (description != null) 'description': description,
        if (voiceNoteUrl != null) 'voiceNoteUrl': voiceNoteUrl,
        if (repeatPattern != null) 'repeatPattern': repeatPattern,
        if (repeatDays != null) 'repeatDays': repeatDays,
        if (hour != null) 'hour': hour,
        if (minute != null) 'minute': minute,
        if (priority != null) 'priority': priority,
        if (isActive != null) 'isActive': isActive,
        if (startDate != null) 'startDate': startDate.toIso8601String(),
        if (endDate != null) 'endDate': endDate.toIso8601String(),
      },
    );
    return ReminderData.fromJson(response);
  }

  /// Delete a reminder
  Future<void> deleteReminder(String id) async {
    await _client.delete('/api/reminders/$id');
  }

  /// Upload a voice note and return its URL
  Future<String> uploadVoiceNote(String filePath) async {
    final response = await _client.uploadFile(
      '/api/files/voice-notes',
      filePath,
      'file',
    );
    return response['url'] as String;
  }
}
