import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/api_user.dart';
import 'face_register_api.dart';

/// Fetches the user list from the CVAI face API.
///
/// Endpoint: GET /face/client/{clientId}/users
/// Params  : page, limit, status, registration_status
class UserListApi {
  UserListApi._();

  /// [registrationStatus] → 'register' | 'unregister' | null (all)
  /// [status]            → 'active' | 'inactive' | null (all)
  static Future<ApiUserPage> fetchUsers({
    String? registrationStatus, // 'register' | 'unregister' | null
    String status = 'active',
    int page = 1,
    int limit = 100,
  }) async {
    final queryParams = <String, String>{
      'page': '$page',
      'limit': '$limit',
      'status': status,
      if (registrationStatus != null)
        'registration_status': registrationStatus,
    };

    final uri = Uri.parse(
      '${FaceRegisterApi.baseUrl}/face/client/${FaceRegisterApi.clientId}/users',
    ).replace(queryParameters: queryParams);

    late http.Response response;
    try {
      response = await http.get(
        uri,
        headers: {
          'accept': 'application/json',
          'ngrok-skip-browser-warning': 'true', // skip ngrok interstitial page
        },
      ).timeout(const Duration(seconds: 20));
    } catch (e) {
      throw UserListException('Network error: $e');
    }

    if (response.statusCode == 200 || response.statusCode == 201) {
      try {
        final decoded = jsonDecode(response.body);

        // Handle bare list response
        if (decoded is List) {
          return ApiUserPage.fromList(decoded);
        }

        // Handle object response {data:[...]} or {users:[...]}
        if (decoded is Map<String, dynamic>) {
          return ApiUserPage.fromJson(decoded);
        }

        return const ApiUserPage(users: [], total: 0, page: 1, limit: 100);
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
