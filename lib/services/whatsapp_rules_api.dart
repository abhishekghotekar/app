import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/whatsapp_rule.dart';
import 'auth_storage.dart';
import 'attendance_api.dart';

/// API service for the WhatsApp Rules backend.
///
/// Base URL  : https://baap-tunnel-13-201-117-192.nip.io
/// Endpoints :
///   GET    /whatsapp/rules          → list all rules
///   POST   /whatsapp/rules          → create a rule
///   DELETE /whatsapp/rules/{id}     → delete a rule
///
/// Note: The backend does not support PUT or PATCH. To update or toggle a rule,
/// we delete the existing rule and create a new one.
class WhatsAppRulesApi {
  WhatsAppRulesApi._();

  static const String _baseUrl = 'https://baap-tunnel.150-241-245-243.nip.io';
  static const String _rulesPath = '/whatsapp/rules';

  static const Map<String, String> _defaultHeaders = {
    'accept': 'application/json',
    'content-type': 'application/json',
    'ngrok-skip-browser-warning': 'true',
  };

  /// Builds the URL for a specific rule id.
  static Uri _ruleUri(String id) =>
      Uri.parse('$_baseUrl$_rulesPath/$id');

  // ── LIST ──────────────────────────────────────────────────────────────────

  /// Fetches all WhatsApp rules from the server.
  static Future<List<WhatsAppRule>> fetchRules() async {
    final uri = Uri.parse('$_baseUrl$_rulesPath');
    print('WhatsAppRulesApi: GET $uri');
    late http.Response response;

    try {
      response = await http
          .get(uri, headers: await _getHeaders())
          .timeout(const Duration(seconds: 15));
    } catch (e) {
      throw WhatsAppRulesException('Network error while fetching rules.\n($e)');
    }

    print('WhatsAppRulesApi: fetchRules → ${response.statusCode}');
    if (response.statusCode == 404) return [];

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw WhatsAppRulesException(
        'Failed to fetch rules (${response.statusCode}): ${response.body}',
      );
    }

    try {
      final List<dynamic> data = jsonDecode(response.body) as List<dynamic>;
      return data
          .whereType<Map<String, dynamic>>()
          .map(WhatsAppRule.fromJson)
          .toList();
    } catch (e) {
      throw WhatsAppRulesException('Failed to parse rules response.\n($e)');
    }
  }

  // ── CREATE ────────────────────────────────────────────────────────────────

  /// Creates a new rule.
  static Future<WhatsAppRule> createRule(Map<String, dynamic> payload) async {
    final uri = Uri.parse('$_baseUrl$_rulesPath');
    print('WhatsAppRulesApi: POST $uri');
    late http.Response response;

    try {
      response = await http
          .post(uri, headers: await _getHeaders(), body: jsonEncode(payload))
          .timeout(const Duration(seconds: 15));
    } catch (e) {
      throw WhatsAppRulesException('Network error while creating rule.\n($e)');
    }

    print('WhatsAppRulesApi: createRule → ${response.statusCode}');
    if (response.statusCode == 200 || response.statusCode == 201) {
      try {
        return WhatsAppRule.fromJson(
          jsonDecode(response.body) as Map<String, dynamic>,
        );
      } catch (e) {
        throw WhatsAppRulesException(
          'Rule created but response could not be parsed.\n($e)',
        );
      }
    }

    throw WhatsAppRulesException(
      'Failed to create rule (${response.statusCode}): ${response.body}',
    );
  }

  // ── TOGGLE (PATCH) ────────────────────────────────────────────────────────

  /// Toggles the `enabled` flag of a rule using the PATCH endpoint.
  static Future<WhatsAppRule> toggleRule(
    WhatsAppRule rule, {
    required bool isActive,
  }) async {
    final uri = Uri.parse('$_baseUrl$_rulesPath/${rule.id}/toggle');
    print('WhatsAppRulesApi: PATCH $uri');
    late http.Response response;

    try {
      response = await http
          .patch(
            uri,
            headers: _defaultHeaders,
            body: jsonEncode({'enabled': isActive}),
          )
          .timeout(const Duration(seconds: 15));
    } catch (e) {
      throw WhatsAppRulesException('Network error while toggling rule.\n($e)');
    }

    print('WhatsAppRulesApi: toggleRule ${rule.id} → ${response.statusCode}');

    if (response.statusCode == 200 || response.statusCode == 201) {
      try {
        return WhatsAppRule.fromJson(
          jsonDecode(response.body) as Map<String, dynamic>,
        );
      } catch (e) {
        throw WhatsAppRulesException(
          'Rule toggled but response could not be parsed.\n($e)',
        );
      }
    }

    throw WhatsAppRulesException(
      'Failed to toggle rule (${response.statusCode}): ${response.body}',
    );
  }

  // ── UPDATE (DELETE + POST) ────────────────────────────────────────────────

  /// Performs a full update on a rule. Since the backend only has POST and DELETE,
  /// we delete the old rule and create a new one with the updated values.
  static Future<WhatsAppRule> updateRule(
    String id,
    Map<String, dynamic> payload,
  ) async {
    print('WhatsAppRulesApi: Updating rule by deleting ID $id and recreating...');
    
    // 1. Delete the old rule
    try {
      await deleteRule(id);
    } catch (e) {
      print('WhatsAppRulesApi: Warning: failed to delete old rule $id: $e. Proceeding to create new one.');
    }

    // 2. Create the new rule
    return createRule(payload);
  }

  // ── DELETE ────────────────────────────────────────────────────────────────

  /// Deletes a rule by id.
  static Future<void> deleteRule(String id) async {
    final uri = _ruleUri(id);
    print('WhatsAppRulesApi: DELETE $uri');
    late http.Response response;

    try {
      response = await http
          .delete(uri, headers: await _getHeaders())
          .timeout(const Duration(seconds: 15));
    } catch (e) {
      throw WhatsAppRulesException('Network error while deleting rule.\n($e)');
    }

    print('WhatsAppRulesApi: deleteRule $id → ${response.statusCode}');

    if (response.statusCode == 200 ||
      response.statusCode == 201 ||
      response.statusCode == 202 ||
      response.statusCode == 204) {
      return; // success
    }

    throw WhatsAppRulesException(
      'Failed to delete rule (${response.statusCode}): ${response.body}',
    );
  }
}

/// Thrown when any WhatsApp Rules API call fails with a user-readable message.
class WhatsAppRulesException implements Exception {
  WhatsAppRulesException(this.message);
  final String message;

  @override
  String toString() => message;
}
