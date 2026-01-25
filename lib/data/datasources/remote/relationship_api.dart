import 'api_client.dart';
import 'user_api.dart';

/// Relationship data
class RelationshipData {
  final String id;
  final String caregiverId;
  final String dependentId;
  final String status;
  final String? linkingCode;
  final DateTime? codeExpiresAt;
  final String initiatedBy;
  final DateTime createdAt;
  final DateTime? verifiedAt;
  final UserSearchResult? caregiver;
  final UserSearchResult? dependent;

  RelationshipData({
    required this.id,
    required this.caregiverId,
    required this.dependentId,
    required this.status,
    this.linkingCode,
    this.codeExpiresAt,
    required this.initiatedBy,
    required this.createdAt,
    this.verifiedAt,
    this.caregiver,
    this.dependent,
  });

  factory RelationshipData.fromJson(Map<String, dynamic> json) {
    return RelationshipData(
      id: json['id'] as String,
      caregiverId: json['caregiverId'] as String,
      dependentId: json['dependentId'] as String,
      status: json['status'] as String,
      linkingCode: json['linkingCode'] as String?,
      codeExpiresAt: json['codeExpiresAt'] != null
          ? DateTime.parse(json['codeExpiresAt'] as String)
          : null,
      initiatedBy: json['initiatedBy'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      verifiedAt: json['verifiedAt'] != null
          ? DateTime.parse(json['verifiedAt'] as String)
          : null,
      caregiver: json['caregiver'] != null
          ? UserSearchResult.fromJson(json['caregiver'] as Map<String, dynamic>)
          : null,
      dependent: json['dependent'] != null
          ? UserSearchResult.fromJson(json['dependent'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'caregiverId': caregiverId,
        'dependentId': dependentId,
        'status': status,
        'linkingCode': linkingCode,
        'codeExpiresAt': codeExpiresAt?.toIso8601String(),
        'initiatedBy': initiatedBy,
        'createdAt': createdAt.toIso8601String(),
        'verifiedAt': verifiedAt?.toIso8601String(),
        'caregiver': caregiver?.toJson(),
        'dependent': dependent?.toJson(),
      };

  bool get isActive => status == 'active';
  bool get isPending => status == 'pending';
}

/// Pending link request data
class PendingLinkData {
  final String relationshipId;
  final String caregiverId;
  final String caregiverName;
  final String? caregiverAvatarUrl;
  final String status;
  final DateTime createdAt;

  PendingLinkData({
    required this.relationshipId,
    required this.caregiverId,
    required this.caregiverName,
    this.caregiverAvatarUrl,
    required this.status,
    required this.createdAt,
  });

  factory PendingLinkData.fromJson(Map<String, dynamic> json) {
    return PendingLinkData(
      relationshipId: json['relationshipId'] as String,
      caregiverId: json['caregiverId'] as String,
      caregiverName: json['caregiverName'] as String,
      caregiverAvatarUrl: json['caregiverAvatarUrl'] as String?,
      status: json['status'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}

/// Create relationship response
class CreateRelationshipResponse {
  final String id;
  final String status;
  final String? linkingCode;
  final DateTime? codeExpiresAt;
  final String message;

  CreateRelationshipResponse({
    required this.id,
    required this.status,
    this.linkingCode,
    this.codeExpiresAt,
    required this.message,
  });

  factory CreateRelationshipResponse.fromJson(Map<String, dynamic> json) {
    return CreateRelationshipResponse(
      id: json['id'] as String,
      status: json['status'] as String,
      linkingCode: json['linkingCode'] as String?,
      codeExpiresAt: json['codeExpiresAt'] != null
          ? DateTime.parse(json['codeExpiresAt'] as String)
          : null,
      message: json['message'] as String? ?? '',
    );
  }
}

/// Verify linking code response
class VerifyLinkingCodeResponse {
  final bool success;
  final String message;
  final RelationshipData? relationship;

  VerifyLinkingCodeResponse({
    required this.success,
    required this.message,
    this.relationship,
  });

  factory VerifyLinkingCodeResponse.fromJson(Map<String, dynamic> json) {
    return VerifyLinkingCodeResponse(
      success: json['success'] as bool? ?? false,
      message: json['message'] as String? ?? '',
      relationship: json['relationship'] != null
          ? RelationshipData.fromJson(
              json['relationship'] as Map<String, dynamic>)
          : null,
    );
  }
}

/// Relationship API service
class RelationshipApi {
  final ApiClient _client;

  RelationshipApi(this._client);

  /// Get all relationships for current user
  Future<List<RelationshipData>> getRelationships() async {
    final response = await _client.get('/api/relationships');
    final data = response['data'] as List? ?? [];
    return data
        .map((json) => RelationshipData.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Get pending link requests
  Future<List<PendingLinkData>> getPendingLinks() async {
    final response = await _client.get('/api/relationships/pending');
    final data = response['data'] as List? ?? [];
    return data
        .map((json) => PendingLinkData.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Create a new relationship (link request)
  Future<CreateRelationshipResponse> createRelationship({
    required String targetUserIdentifier,
    required String initiatedBy,
  }) async {
    final response = await _client.post(
      '/api/relationships',
      body: {
        'targetUserIdentifier': targetUserIdentifier,
        'initiatedBy': initiatedBy,
      },
    );
    return CreateRelationshipResponse.fromJson(response);
  }

  /// Verify linking code
  Future<VerifyLinkingCodeResponse> verifyLinkingCode({
    required String relationshipId,
    required String code,
  }) async {
    final response = await _client.post(
      '/api/relationships/$relationshipId/verify',
      body: {'code': code},
    );
    return VerifyLinkingCodeResponse.fromJson(response);
  }

  /// Get linking code for a relationship
  Future<Map<String, dynamic>> getLinkingCode(String relationshipId) async {
    return await _client.get('/api/relationships/$relationshipId/code');
  }

  /// Regenerate linking code
  Future<Map<String, dynamic>> regenerateLinkingCode(
      String relationshipId) async {
    return await _client
        .post('/api/relationships/$relationshipId/regenerate-code');
  }

  /// Delete/remove a relationship
  Future<void> deleteRelationship(String relationshipId) async {
    await _client.delete('/api/relationships/$relationshipId');
  }
}
