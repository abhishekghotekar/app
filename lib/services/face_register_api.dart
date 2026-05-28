import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

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

  /// Change this to your current ngrok URL.
  static const String baseUrl =
      'https://mechanisms-papers-with-pocket.trycloudflare.com';

  /// The client (organisation) ID for all face API calls.
  static const String clientId = 'edb3ac03-5d77-45ac-a187-794ae63f1ef4';

  static Future<void> register({
    required String userId,
    required String clientId,
    required String fullName,
    required List<File> imageFiles,
  }) async {
    if (imageFiles.isEmpty) {
      throw FaceRegisterException('At least one face photo is required.');
    }

    final uri = Uri.parse('$baseUrl/face/register');

    final request = http.MultipartRequest('POST', uri)
      ..headers['accept'] = 'application/json'
      ..fields['employee_id'] = userId.trim()
      ..fields['client_id'] = clientId.trim()
      ..fields['full_name'] = fullName.trim();

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
    final uri = Uri.parse(
      '$baseUrl/face/client/$clientId/users/${Uri.encodeComponent(userId)}',
    );

    late http.Response response;
    try {
      response = await http
          .delete(
            uri,
            headers: {
              'accept': 'application/json',
              'ngrok-skip-browser-warning': 'true',
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
    // 1. Fetch all users (all registration statuses)
    late http.Response listResponse;
    try {
      final uri = Uri.parse('$baseUrl/face/client/$clientId/users').replace(
        queryParameters: {
          'page': '1',
          'limit': '200',
          'status': 'active',
          'registration_status': 'all',
        },
      );
      listResponse = await http
          .get(
            uri,
            headers: {
              'accept': 'application/json',
              'ngrok-skip-browser-warning': 'true',
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
