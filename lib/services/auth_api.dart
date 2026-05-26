import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/auth_session.dart';
import 'api_config.dart';

/// Thrown when login fails for a reason worth showing the user.
class AuthException implements Exception {
  AuthException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Calls the cloud Platform auth API.
class AuthApi {
  AuthApi._();

  static Future<LoginResult> login({
    required String email,
    required String password,
  }) async {
    final uri = Uri.parse('${ApiConfig.platformBaseUrl}${ApiConfig.loginPath}');

    late http.Response res;
    try {
      res = await http
          .post(
            uri,
            headers: const {
              'content-type': 'application/json',
              'accept': 'application/json',
            },
            body: jsonEncode({'email': email.trim(), 'password': password}),
          )
          .timeout(const Duration(seconds: 20));
    } catch (_) {
      throw AuthException('Network error. Please check your connection.');
    }

    Map<String, dynamic> body;
    try {
      body = jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {
      body = const {};
    }

    if (res.statusCode == 200) {
      return LoginResult.fromJson(body);
    }

    final serverMessage = body['message']?.toString() ?? body['detail']?.toString();
    if (res.statusCode == 400 || res.statusCode == 401) {
      throw AuthException(serverMessage ?? 'Invalid email or password.');
    }
    throw AuthException(serverMessage ?? 'Login failed (${res.statusCode}).');
  }
}
