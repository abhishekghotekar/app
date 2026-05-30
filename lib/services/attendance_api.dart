import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/attendance_record.dart';
import 'auth_storage.dart';

/// Calls the hierarchy-attendance cloud platform API.
class AttendanceApi {
  AttendanceApi._();

  static const String baseUrl = 'https://qa-new-platform.duckdns.org';

  // Fallback token for testing/development if local session is empty
  static const String fallbackToken =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VyX2lkIjoiZDRiMGIxZTktMDY1Ni00M2ZkLTlkNmEtZmIzYjViYmUzNWExIiwidXNlcl90eXBlIjoiQWRtaW4iLCJjbGllbnRzIjp7ImI1ZGE2ZWU5LTZjMDYtNGE0Ny05MjI4LTk2YjZkZDkzOGExOCI6ImUyMTA1MzNhLTcyMDEtNDQzNC05YTFmLTQxNzAxZjAwZTQ3NSIsIjZjZjY1YjdkLTU0MDAtNGM4NC1hNTZkLWM3YmFkMmUzYjc5ZCI6IjhmM2MxNzg5LTQxODYtNDI2NS1hZTExLWY1NjdkZDgxZDhjMSIsImYwNmNkMzVmLTBmNDgtNGE0Zi1iMDY5LTZjZGY3MDc2ZGE2OSI6IjlhZjE1MmM1LTA0YTctNGFmMS04Y2QzLTk3OTBiY2VjODBiNyIsIjE0Njc4MGRhLTFlNGItNGYwOC1iOGQxLTIxNDBjZTVhZjAyNyI6ImYxY2IzMTI1LTcyYzYtNDE5OS05YjI3LTg0NGM3MGY3NDEwZSIsImZkMzY1OGZjLThiMzQtNDVhMi05ZDk1LTkyN2Q4ODg5NTljMCI6IjRiOTVmZDM4LTk3MzMtNDQyZS04OWI2LWExZWJjODNmNWJkZSIsIjU4M2QwYTMxLTliZDMtNDFkOC04ZWViLTE3Yjg0YmFlZDk5YSI6ImJjNjBkZGRjLTBhZTctNDEzMS1hMDY1LThiY2IxY2JkZTFlNCIsImIwNGZkNTViLWExNjAtNDI4Ny1iNGJiLTI4MmNiNWI1MDk5ZiI6IjE4YTgzNjY0LTQ1ZjQtNDczNi1iYTBlLTlmNjNiOGE5ZGQ5YSIsImQ5YzI2MzhiLWMwNTctNGE4My04ODYzLWNkY2UxYzJkYzQ2MCI6ImMzOGI5YTJlLTdhYmQtNGE5My1iZmExLTJjODY0YTVhNTc3OCIsImJkMjNhMzBiLTgyMmQtNDQwOC1hNDgwLTlhZWNkMWNmODlmNCI6IjNlN2JkNTZiLTg0NGEtNGYyYy05NmMxLTcwZjA0MTIxZGFmZCIsIjJhMTdlNDI2LWQ1ZDItNGI5Ni1hNDU4LWI0OTE3ODRjMjNlOCI6IjE1MDEyYmQ5LWZhNjItNGNmZC1hMmY5LTk0ZWY2NTAyZTQwMCIsIjU3MWJmNjQzLTYwZDUtNGU5Yy05Yzk5LWI4YTUyY2ExODMyYSI6IjU4YmM1MGU0LTc0ZTEtNGVjNC05YzY5LTM0YTUzYjhjOWM5MCJ9LCJ0b2tlbl92ZXJzaW9uIjo0LCJpYXQiOjE3Nzk4NjcwMjUsImV4cCI6MTc3OTk1MzQyNX0.9-hNpvyyItp6jBjAXLMzAOYbMpmk8QqAQagIW1e7BwY';

  static const String clientId = '571bf643-60d5-4e9c-9c99-b8a52ca1832a';

  /// Helper: Decodes JWT payload to access fields (clients map, user_id)
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
    } catch (e) {
      print('AttendanceApi: Error parsing JWT payload: $e');
      return null;
    }
  }

  /// Fetches attendance records for the given date.
  /// If status is null, it fetches all records.
  static Future<List<AttendanceRecord>> fetchAttendance({
    required DateTime date,
    String? status, // 'P', 'A' or null (all).
    int page = 1,
    int limit = 1000,
  }) async {
    final dateStr =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

    // Get access token dynamically, fallback to standard dev token if empty
    String token = fallbackToken;
    try {
      print('AttendanceApi: Loading token from storage...');
      final sessionToken = await AuthStorage.accessToken();
      print(
        'AttendanceApi: Session token exists: ${sessionToken != null && sessionToken.isNotEmpty}',
      );
      if (sessionToken != null && sessionToken.isNotEmpty) {
        token = sessionToken;
      }
    } catch (e) {
      print('AttendanceApi: Error loading token from storage: $e');
    }

    // Get client ID dynamically from the JWT claims, fallback to standard clientId
    String activeClientId = clientId;
    try {
      final decoded = _parseJwt(token);
      if (decoded != null && decoded.containsKey('clients')) {
        final clients = decoded['clients'] as Map<String, dynamic>?;
        if (clients != null && clients.isNotEmpty) {
          // If the clients map contains our default client ID, use it. Otherwise, use the first client ID.
          if (clients.containsKey(clientId)) {
            activeClientId = clientId;
          } else {
            activeClientId = clients.keys.first;
          }
          print('AttendanceApi: Dynamic Client ID set: $activeClientId');
        }
      }
    } catch (e) {
      print('AttendanceApi: Error parsing dynamic client ID from token: $e');
    }

    final queryParams = <String, String>{
      'date_in_iso_format': dateStr,
      'page': '$page',
      'limit': '$limit',
      if (status != null) 'status': status,
    };

    final uri = Uri.parse(
      '$baseUrl/auth/api/attendance/client/$activeClientId/hierarchy-attendance',
    ).replace(queryParameters: queryParams);

    print('AttendanceApi: Sending GET to $uri');
    try {
      final response = await http
          .get(
            uri,
            headers: {
              'Accept': 'application/json, text/plain, */*',
              'Accept-Language': 'en-US,en;q=0.9',
              'Authorization': 'Bearer $token',
              'Origin': 'https://qa-platform.baap.company',
              'Referer': 'https://qa-platform.baap.company/',
              'User-Agent':
                  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/148.0.0.0 Safari/537.36',
            },
          )
          .timeout(const Duration(seconds: 15));

      print('AttendanceApi: HTTP response code: ${response.statusCode}');
      if (response.statusCode == 200 || response.statusCode == 201) {
        final Map<String, dynamic> decoded = jsonDecode(response.body);
        final List<dynamic> data = decoded['data'] as List<dynamic>? ?? [];
        print('AttendanceApi: Successfully fetched ${data.length} records');
        return data
            .map(
              (json) => AttendanceRecord.fromApiJson(
                json as Map<String, dynamic>,
                fallbackDate: date,
              ),
            )
            .toList();
      } else {
        print(
          'AttendanceApi: Bad response: ${response.statusCode} - ${response.body}',
        );
        throw Exception(
          'Failed to fetch attendance (${response.statusCode}): ${response.body}',
        );
      }
    } catch (e) {
      print('AttendanceApi: Exception during GET request: $e');
      rethrow;
    }
  }

  /// Fetches all attendance records for a specific user (studentId) over the last 15 days.
  static Future<List<AttendanceRecord>> fetchUserAttendance({
    required String userId,
  }) async {
    final List<Future<List<AttendanceRecord>>> futures = [];
    final now = DateTime.now();

    // Fetch records for the last 30 days in parallel using Future.wait
    for (int i = 0; i < 30; i++) {
      final queryDate = now.subtract(Duration(days: i));
      futures.add(
        fetchAttendance(date: queryDate).catchError((e) {
          print('AttendanceApi: Error fetching attendance for day $i: $e');
          return <AttendanceRecord>[];
        }),
      );
    }

    print(
      'AttendanceApi: Fetching user attendance for the last 30 days in parallel...',
    );
    final results = await Future.wait(futures);
    final List<AttendanceRecord> userRecords = [];
    for (final list in results) {
      final filtered = list.where((r) => r.studentId == userId);
      userRecords.addAll(filtered);
    }

    print(
      'AttendanceApi: Successfully gathered ${userRecords.length} records for user $userId across the last 30 days',
    );
    return userRecords;
  }
}
