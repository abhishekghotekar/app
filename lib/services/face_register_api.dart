import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'auth_storage.dart';
import 'attendance_api.dart';

/// Thrown when face registration fails with a user-readable message.
class FaceRegisterException implements Exception {
  FaceRegisterException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Calls the CVAI on-device face registration endpoint.
///
/// API: POST /face/register  (multipart/form-data)
/// Fields:
///   - employee_id  : user's backend id (UUID)
///   - client_id    : client / organisation ID
///   - full_name    : user's full name
///   - files        : one or more face image files
class FaceRegisterApi {
  FaceRegisterApi._();

  static Future<String?> _getToken() async {
    final token = await AuthStorage.accessToken();
    if (token == null || token.isEmpty || token == 'mock_access_token_from_skip_login') {
      return AttendanceApi.fallbackToken;
    }
    return token;
  }

  /// Change this to your current ngrok URL.
  static const String baseUrl = 'https://baap-tunnel.150-241-245-243.nip.io';

  /// The client (organisation) ID for all face API calls.
  static const String clientId = '571bf643-60d5-4e9c-9c99-b8a52ca1832a';

  static Map<String, dynamic>? _parseJwt(String token) {
    try {
      final parts = token.split('.');
      if (parts.length < 2) return null;
      String payload = parts[1];

      int padLength = 4 - (payload.length % 4);
      if (padLength < 4) {
        payload += '=' * padLength;
      }

      final decoded = utf8.decode(base64Url.decode(payload));
      return jsonDecode(decoded) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  static Future<String> getActiveClientId() async {
    try {
      final token = await AuthStorage.accessToken();
      if (token != null && token.isNotEmpty) {
        final decoded = _parseJwt(token);
        if (decoded != null && decoded.containsKey('clients')) {
          final clients = decoded['clients'] as Map<String, dynamic>?;
          if (clients != null && clients.isNotEmpty) {
            if (clients.containsKey(clientId)) {
              return clientId;
            }
            return clients.keys.first;
          }
        }
      }
    } catch (_) {}
    return clientId;
  }

  static Future<void> register({
    required String userId,
    required String clientId,
    required String fullName,
    required List<File> imageFiles,
    bool attendance = true,
    bool weapon = false,
    bool wanted = false,
  }) async {
    if (imageFiles.isEmpty) {
      throw FaceRegisterException('At least one face photo is required.');
    }

    final uri = Uri.parse('$baseUrl/face/register');

    final token = await _getToken();
    final request = http.MultipartRequest('POST', uri)
      ..headers['accept'] = 'application/json'
      ..headers['ngrok-skip-browser-warning'] = 'true';
    if (token != null) {
      request.headers['Authorization'] = 'Bearer $token';
    }
    request.fields['employee_id'] = userId.trim();
    request.fields['client_id'] = clientId.trim();
    request.fields['full_name'] = fullName.trim();
    request.fields['attendance'] = attendance.toString();
    request.fields['weapon'] = weapon.toString();
    request.fields['wanted'] = wanted.toString();

    for (final file in imageFiles) {
      request.files.add(await http.MultipartFile.fromPath('files', file.path));
    }

    late http.StreamedResponse streamed;
    try {
      streamed = await request.send().timeout(const Duration(seconds: 30));
    } catch (e) {
      throw FaceRegisterException(
        'Network error. Check your connection.\n($e)',
      );
    }

    final body = await streamed.stream.bytesToString();

    if (streamed.statusCode == 200 || streamed.statusCode == 201) {
      return; // success
    }

    throw FaceRegisterException(
      'Registration failed (${streamed.statusCode}):\n$body',
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Unregister
  // ─────────────────────────────────────────────────────────────────────────

  /// Deletes (un-registers) a single user's face data.
  ///
  /// API: DELETE /face/client/{clientId}/users/{userId}
  static Future<void> unregister({required String userId}) async {
    final activeClientId = await getActiveClientId();
    final uri = Uri.parse(
      '$baseUrl/face/client/$activeClientId/users/${Uri.encodeComponent(userId)}',
    );

    final token = await _getToken();
    late http.Response response;
    try {
      response = await http
          .delete(
            uri,
            headers: {
              'accept': 'application/json',
              'ngrok-skip-browser-warning': 'true',
              if (token != null) 'Authorization': 'Bearer $token',
            },
          )
          .timeout(const Duration(seconds: 30));
    } catch (e) {
      throw FaceRegisterException(
        'Network error while unregistering $userId.\n($e)',
      );
    }

    if (response.statusCode == 200 ||
        response.statusCode == 204 ||
        response.statusCode == 201) {
      return; // success
    }

    throw FaceRegisterException(
      'Unregister failed for $userId (${response.statusCode}):\n${response.body}',
    );
  }

  /// Fetches **all active users** (registered + unregistered) and
  /// calls [unregister] on each one sequentially.
  ///
  /// [onProgress] is called after each user is processed:
  ///   - `done`  : number successfully unregistered so far
  ///   - `total` : total users to process
  ///   - `error` : non-null if this specific user failed (skipped)
  static Future<UnregisterAllResult> unregisterAll({
    void Function(int done, int total, String? error)? onProgress,
  }) async {
    final activeClientId = await getActiveClientId();
    // 1. Fetch all users (all registration statuses)
    late http.Response listResponse;
    try {
      final uri = Uri.parse('$baseUrl/face/client/$activeClientId/users').replace(
        queryParameters: {
          'page': '1',
          'limit': '200',
          'status': 'active',
          'registration_status': 'all',
        },
      );
      final token = await _getToken();
      listResponse = await http
          .get(
            uri,
            headers: {
              'accept': 'application/json',
              'ngrok-skip-browser-warning': 'true',
              if (token != null) 'Authorization': 'Bearer $token',
            },
          )
          .timeout(const Duration(seconds: 30));
    } catch (e) {
      throw FaceRegisterException('Network error fetching user list.\n($e)');
    }

    if (listResponse.statusCode != 200 && listResponse.statusCode != 201) {
      throw FaceRegisterException(
        'Failed to fetch users (${listResponse.statusCode}):\n${listResponse.body}',
      );
    }

    // 2. Parse user ids
    final List<String> userIds = _parseUserIds(listResponse.body);
    final total = userIds.length;
    int done = 0;
    final errors = <String>[];

    // 3. Unregister each user
    for (final uid in userIds) {
      try {
        await unregister(userId: uid);
        done++;
        onProgress?.call(done, total, null);
      } catch (e) {
        final msg = e.toString();
        errors.add(msg);
        onProgress?.call(done, total, msg);
      }
    }

    return UnregisterAllResult(total: total, succeeded: done, errors: errors);
  }

  /// Parses a raw JSON body and extracts all user ids (UUIDs).
  static List<String> _parseUserIds(String body) {
    try {
      dynamic decoded = _jsonDecode(body);

      List<dynamic> items;
      if (decoded is List) {
        items = decoded;
      } else if (decoded is Map) {
        items =
            (decoded['data'] ?? decoded['users'] ?? decoded['results'] ?? [])
                as List;
      } else {
        return [];
      }

      return items
          .whereType<Map>()
          .map((m) {
            // Use backend 'id' (UUID) — same field used for register.
            final uid = (m['id'] ?? m['_id'] ?? m['uuid'] ?? '')
                .toString()
                .trim();
            return uid;
          })
          .where((id) => id.isNotEmpty && id != 'null')
          .toList();
    } catch (_) {
      return [];
    }
  }

  static dynamic _jsonDecode(String src) => jsonDecode(src);

  // ─────────────────────────────────────────────────────────────────────────
  // Config
  // ─────────────────────────────────────────────────────────────────────────

  /// Fetches the current face configurations.
  static Future<Map<String, bool>> getConfig() async {
    final uri = Uri.parse('$baseUrl/face/config');
    final token = await _getToken();
    try {
      final response = await http.get(
        uri,
        headers: {
          'accept': 'application/json',
          'ngrok-skip-browser-warning': 'true',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        return {
          'weapon_detection_enabled': decoded['weapon_detection_enabled'] as bool? ?? false,
          'wanted_detection_enabled': decoded['wanted_detection_enabled'] as bool? ?? false,
          'attendance_enabled': decoded['attendance_enabled'] as bool? ?? false,
        };
      }
    } catch (_) {}
    // Return default map if GET fails or is not implemented
    return {
      'weapon_detection_enabled': false,
      'wanted_detection_enabled': false,
      'attendance_enabled': true,
    };
  }

  /// Updates the face configurations.
  static Future<void> updateConfig({
    required bool weaponDetectionEnabled,
    required bool wantedDetectionEnabled,
    required bool attendanceEnabled,
  }) async {
    final uri = Uri.parse('$baseUrl/face/config');
    final token = await _getToken();
    final payload = {
      'weapon_detection_enabled': weaponDetectionEnabled,
      'wanted_detection_enabled': wantedDetectionEnabled,
      'attendance_enabled': attendanceEnabled,
    };

    late http.Response response;
    try {
      response = await http.post(
        uri,
        headers: {
          'accept': 'application/json',
          'content-type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 15));
    } catch (e) {
      throw FaceRegisterException('Network error while updating configuration.\n($e)');
    }

    if (response.statusCode == 200 || response.statusCode == 201) {
      return; // success
    }

    throw FaceRegisterException(
      'Failed to update configuration (${response.statusCode}):\n${response.body}',
    );
  }
}

/// Result returned by [FaceRegisterApi.unregisterAll].
class UnregisterAllResult {
  const UnregisterAllResult({
    required this.total,
    required this.succeeded,
    required this.errors,
  });

  final int total;
  final int succeeded;
  final List<String> errors;

  bool get hasErrors => errors.isNotEmpty;
  int get failed => total - succeeded;
}
