import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/api_user.dart';
import 'face_register_api.dart';
import 'auth_storage.dart';
import 'attendance_api.dart';

/// Fetches the user list from the CVAI face API.
///
/// Endpoint: GET /face/client/{clientId}/users
/// Params  : page, limit, status, registration_status
///
/// Results are cached in memory after the first successful fetch.
/// Call [invalidateCache] to force a fresh network request.
class UserListApi {
  UserListApi._();

  // ── Static cache ───────────────────────────────────────────────────────────
  static List<ApiUser>? _cachedUsers;

  /// True when user list is already cached in memory (no network needed).
  static bool get isCached => _cachedUsers != null;

  /// Clears the cached user list so the next [fetchUsers] call hits the network.
  static void invalidateCache() => _cachedUsers = null;

  // ── Fetch ──────────────────────────────────────────────────────────────────
  /// [registrationStatus] → 'register' | 'unregister' | null (all)
  /// [status]            → 'active' | 'inactive' | null (all)
  ///
  /// If [forceRefresh] is false (default) and data is already cached,
  /// returns the cache immediately without hitting the network.
  static Future<ApiUserPage> fetchUsers({
    String? registrationStatus, // 'register' | 'unregister' | null
    String status = 'active',
    int page = 1,
    int limit = 100,
    bool forceRefresh = false,
  }) async {
    // Return cache if available and no filter overrides are active
    final useCache = !forceRefresh &&
        registrationStatus == null &&
        status == 'active' &&
        page == 1 &&
        limit == 100;

    if (useCache && _cachedUsers != null) {
      return ApiUserPage(
        users: _cachedUsers!,
        total: _cachedUsers!.length,
        page: 1,
        limit: _cachedUsers!.length,
      );
    }

    final queryParams = <String, String>{
      'page': '$page',
      'limit': '$limit',
      'status': status,
      if (registrationStatus != null)
        'registration_status': registrationStatus,
    };

    final token = await AuthStorage.accessToken().then((t) =>
        (t == null || t.isEmpty || t == 'mock_access_token_from_skip_login')
            ? AttendanceApi.fallbackToken
            : t);

    final activeClientId = await FaceRegisterApi.getActiveClientId();
    final uri = Uri.parse(
      '${FaceRegisterApi.baseUrl}/face/client/$activeClientId/users',
    ).replace(queryParameters: queryParams);

    late http.Response response;
    try {
      response = await http.get(
        uri,
        headers: {
          'accept': 'application/json',
          'ngrok-skip-browser-warning': 'true',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 20));
    } catch (e) {
      throw UserListException('Network error: $e');
    }

    if (response.statusCode == 200 || response.statusCode == 201) {
      try {
        final decoded = jsonDecode(response.body);

        ApiUserPage page0;

        // Handle bare list response
        if (decoded is List) {
          page0 = ApiUserPage.fromList(decoded);
        } else if (decoded is Map<String, dynamic>) {
          // Handle object response {data:[...]} or {users:[...]}
          page0 = ApiUserPage.fromJson(decoded);
        } else {
          page0 = const ApiUserPage(users: [], total: 0, page: 1, limit: 100);
        }

        // Store in cache only for the default (unfiltered) call
        if (useCache) _cachedUsers = page0.users;

        return page0;
      } catch (e) {
        throw UserListException('Failed to parse response: $e');
      }
    }

    throw UserListException(
        'Server error (${response.statusCode}): ${response.body}');
  }
}

/// Thrown when fetching users fails.
class UserListException implements Exception {
  UserListException(this.message);
  final String message;

  @override
  String toString() => message;
}
