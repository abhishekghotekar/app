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
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VyX2lkIjoiYTJhMjAzMzUtNmU1ZC00ODU5LTg0ODctM2Y0YzUzZGNmNjMzIiwidXNlcl90eXBlIjoiQWRtaW4iLCJjbGllbnRzIjp7IjVkODVjOTRkLWE4YTctNDQ5YS05MzljLTIxMjQwOTJjNzRhMCI6IjM0ZjA3MzYwLTMzMGYtNDU2Zi1hZDMxLWIwNDM3NTNkZWM5NyIsIjZjZjY1YjdkLTU0MDAtNGM4NC1hNTZkLWM3YmFkMmUzYjc5ZCI6IjRmNjRiNDFlLTI0OTItNGE0Ny1hZTQyLTI5YTA2ZGM3ZTU1NSIsImJhZDdjODM3LTZkNWQtNGRjMC1iNzA0LWVmOGI3NzM1MjQwYiI6IjFmNTczODJhLWVmMzgtNGUzNS05MTU3LTg0YmE1ZDhkMmU5MyIsImY0MGNmMjM5LTIyYTAtNDQ3NC05ZmVjLTVhNTNkOGYxNjg5YSI6ImRiZTZiOWU4LTMzMDAtNDAyNy04MGEwLTJkZWE1NzBhODMzNyIsImY2ZjhkMDUyLTg1YTAtNDdjYy1hYWE3LTY0ZWVkYzgyMTliMyI6IjFhMWFiMzQyLWRmM2EtNGQwNS04ZGYzLWEyNWFlMGUyYjg0YiJ9LCJ0b2tlbl92ZXJzaW9uIjowLCJpYXQiOjE3OTQ4OTM3NDIsImV4cCI6MTc5NTMyNTc0Mn0.d5IB0DlLRT2VdL9qNNwcIvfh9-DiSDK28G-cbH9cIjo';

  static String clientId = 'edb3ac03-5d77-45ac-a187-794ae63f1ef4';

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

    // Always use configured active client ID
    final String activeClientId = clientId;
    print('AttendanceApi: Target Client ID is: $activeClientId');

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
        print('AttendanceApi: Raw response body: ${response.body}');
        final dynamic decoded = jsonDecode(response.body);
        List<dynamic> data = [];
        if (decoded is List) {
          data = decoded;
        } else if (decoded is Map<String, dynamic>) {
          if (decoded['data'] is List) {
            data = decoded['data'] as List<dynamic>;
          } else if (decoded['data'] is Map<String, dynamic>) {
            final dataMap = decoded['data'] as Map<String, dynamic>;
            data = (dataMap['records'] ??
                    dataMap['items'] ??
                    dataMap['attendance'] ??
                    dataMap['users'] ??
                    []) as List<dynamic>;
          } else if (decoded['records'] is List) {
            data = decoded['records'] as List<dynamic>;
          } else if (decoded['items'] is List) {
            data = decoded['items'] as List<dynamic>;
          }
        }
        print('AttendanceApi: Successfully fetched ${data.length} records');
        return data
            .whereType<Map<String, dynamic>>()
            .map(
              (json) => AttendanceRecord.fromApiJson(
                json,
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

  /// Fetches attendance records for a specific user (studentId) over the last 14 days.
  static Future<List<AttendanceRecord>> fetchUserAttendance({
    required String userId,
  }) async {
    final now = DateTime.now();
    const daysToFetch = 14;
    final List<AttendanceRecord> userRecords = [];

    // Query in batches of 5 parallel requests to prevent connection flooding
    for (int i = 0; i < daysToFetch; i += 5) {
      final futures = <Future<List<AttendanceRecord>>>[];
      for (int j = i; j < i + 5 && j < daysToFetch; j++) {
        final queryDate = now.subtract(Duration(days: j));
        futures.add(
          fetchAttendance(date: queryDate, limit: 200).catchError((e) {
            print('AttendanceApi: Error fetching attendance for day $j: $e');
            return <AttendanceRecord>[];
          }),
        );
      }
      final results = await Future.wait(futures);
      for (final list in results) {
        userRecords.addAll(list.where((r) => r.studentId == userId));
      }
    }

    print(
      'AttendanceApi: Successfully gathered ${userRecords.length} records for user $userId across the last $daysToFetch days',
    );
    return userRecords;
  }
}
