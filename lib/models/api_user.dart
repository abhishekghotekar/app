/// Represents a user returned by the
/// GET /face/client/{client_id}/users endpoint.
class ApiUser {
  const ApiUser({
    required this.id,
    required this.clientId,
    required this.fullName,
    required this.status,
    required this.registrationStatus,
    this.department,
    this.email,
    this.phone,
    this.faceCount,
    this.createdAt,
  });

  final String id;
  final String clientId;
  final String fullName;
  final String status;              // "active" | "inactive"
  final String registrationStatus; // "register" | "unregister"
  final String? department;
  final String? email;
  final String? phone;
  final int? faceCount;
  final String? createdAt;

  bool get isRegistered =>
      registrationStatus == 'registered' ||
      registrationStatus == 'register' ||
      registrationStatus == 'true';

  /// Initials for avatar (first letter of each word, max 2).
  String get initials {
    final parts = fullName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  factory ApiUser.fromJson(Map<String, dynamic> json) {
    String? parsedDept;
    final locDept = json['user_location_department'];
    if (locDept is List && locDept.isNotEmpty) {
      final first = locDept.first;
      if (first is Map<String, dynamic>) {
        final deptObj = first['department'];
        if (deptObj is Map<String, dynamic>) {
          parsedDept = deptObj['name']?.toString();
        }
      }
    }

    String? parsedClientId;
    final mappings = json['user_mappings'];
    if (mappings is List && mappings.isNotEmpty) {
      final first = mappings.first;
      if (first is Map<String, dynamic>) {
        final cliId = first['client_id'];
        if (cliId != null && cliId.toString().trim().toLowerCase() != 'null') {
          parsedClientId = cliId.toString();
        }
      }
    }

    final String finalId = _str(json, ['id', '_id', 'uuid']) ?? '';

    return ApiUser(
      id:                 finalId,
      clientId:           parsedClientId ?? _str(json, ['client_id', 'clientId']) ?? '571bf643-60d5-4e9c-9c99-b8a52ca1832a',
      fullName:           _str(json, ['full_name', 'fullName', 'name']) ?? 'Unknown',
      status:             _str(json, ['status']) ?? 'active',
      registrationStatus: _str(json, ['registration_status', 'registrationStatus']) ?? 'unregistered',
      department:         parsedDept ?? _str(json, ['department', 'dept']),
      email:              _str(json, ['email']),
      phone:              _str(json, ['phone', 'mobile', 'phone_number']),
      faceCount:          json['face_count'] as int? ??
                          json['faceCount']  as int? ??
                          json['enrolled_faces'] as int?,
      createdAt:          _str(json, ['created_at', 'createdAt']),
    );
  }

  // Helper: try multiple key names, return first non-null string value.
  static String? _str(Map<String, dynamic> json, List<String> keys) {
    for (final k in keys) {
      final v = json[k];
      if (v != null && v.toString().isNotEmpty) return v.toString();
    }
    return null;
  }
}

/// Paginated response wrapper from the users list endpoint.
class ApiUserPage {
  const ApiUserPage({
    required this.users,
    required this.total,
    required this.page,
    required this.limit,
  });

  final List<ApiUser> users;
  final int total;
  final int page;
  final int limit;

  bool get hasMore => users.length >= limit;

  factory ApiUserPage.fromJson(Map<String, dynamic> json) {
    // Handle both {data:[...]} and top-level list responses.
    List<dynamic> rawList;
    if (json.containsKey('data') && json['data'] is List) {
      rawList = json['data'] as List<dynamic>;
    } else if (json.containsKey('users') && json['users'] is List) {
      rawList = json['users'] as List<dynamic>;
    } else if (json.containsKey('results') && json['results'] is List) {
      rawList = json['results'] as List<dynamic>;
    } else {
      rawList = [];
    }

    final users = rawList
        .whereType<Map<String, dynamic>>()
        .map(ApiUser.fromJson)
        .toList();

    return ApiUserPage(
      users: users,
      total: json['total'] as int? ?? json['count'] as int? ?? users.length,
      page:  json['page']  as int? ?? 1,
      limit: json['limit'] as int? ?? users.length,
    );
  }

  /// For APIs that return a bare JSON array.
  factory ApiUserPage.fromList(List<dynamic> list) {
    final users = list
        .whereType<Map<String, dynamic>>()
        .map(ApiUser.fromJson)
        .toList();
    return ApiUserPage(users: users, total: users.length, page: 1, limit: users.length);
  }
}
