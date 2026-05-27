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
///   - employee_id  : unique user / roll ID
///   - client_id    : client / organisation ID
///   - full_name    : user's full name
///   - files        : one or more face image files
class FaceRegisterApi {
  FaceRegisterApi._();

  /// Change this to your current ngrok URL.
  static const String baseUrl = 'https://a447-103-112-11-19.ngrok-free.app';

  /// The client (organisation) ID for all face API calls.
  static const String clientId = '6cf65b7d-5400-4c84-a56d-c7bad2e3b79d';

  static Future<void> register({
    required String employeeId,
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
      ..fields['employee_id'] = employeeId.trim()
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
}
