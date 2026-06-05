import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/whatsapp_rule.dart';

/// API service for the WhatsApp Rules backend.
///
/// Base URL  : https://baap-tunnel-13-201-117-192.nip.io
/// Endpoints :
///   GET    /whatsapp/rules          → list all rules
///   POST   /whatsapp/rules          → create a rule
///   PUT    /whatsapp/rules/{id}     → full update (all fields)
///   PATCH  /whatsapp/rules/{id}     → partial update (e.g. toggle is_active)
///   DELETE /whatsapp/rules/{id}     → delete a rule
class WhatsAppRulesApi {
  WhatsAppRulesApi._();

  static const String _baseUrl = 'https://baap-tunnel-13-201-117-192.nip.io';
  static const String _rulesPath = '/whatsapp/rules';

  static const Map<String, String> _defaultHeaders = {
    'accept': 'application/json',
    'content-type': 'application/json',
    // Skip ngrok browser-warning redirect (nip.io tunnel behaves similarly)
    'ngrok-skip-browser-warning': 'true',
  };

  // ── LIST ──────────────────────────────────────────────────────────────────

  /// Fetches all WhatsApp rules from the server.
  ///
  /// Returns an empty list on 404 (no rules yet).
  static Future<List<WhatsAppRule>> fetchRules() async {
    final uri = Uri.parse('$_baseUrl$_rulesPath');
    late http.Response response;

    try {
      response = await http
          .get(uri, headers: _defaultHeaders)
          .timeout(const Duration(seconds: 15));
    } catch (e) {
      throw WhatsAppRulesException('Network error while fetching rules.\n($e)');
    }

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
  ///
  /// [payload] must contain:
  ///   rule_name, trigger_type, condition, send_to, channels,
  ///   phone_number, custom_message, send_time, is_active
  static Future<WhatsAppRule> createRule(Map<String, dynamic> payload) async {
    final uri = Uri.parse('$_baseUrl$_rulesPath');
    late http.Response response;

    try {
      response = await http
          .post(uri, headers: _defaultHeaders, body: jsonEncode(payload))
          .timeout(const Duration(seconds: 15));
    } catch (e) {
      throw WhatsAppRulesException('Network error while creating rule.\n($e)');
    }

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

  // ── TOGGLE (PUT is_active) ────────────────────────────────────────────────

  /// Toggles the `is_active` flag of a rule.
  ///
  /// The server only supports PUT (not PATCH), so the full rule payload is
  /// sent with only `is_active` flipped.
  static Future<WhatsAppRule> toggleRule(
    WhatsAppRule rule, {
    required bool isActive,
  }) async {
    final payload = rule.toJson()..['is_active'] = isActive;
    return updateRule(rule.id, payload);
  }

  // ── UPDATE (full PUT) ────────────────────────────────────────────────────

  /// Performs a full update on a rule via PUT (replaces all editable fields).
  ///
  /// Required fields in [payload]:
  ///   rule_name, trigger_type, condition, send_to, channels,
  ///   phone_number, custom_message, send_time, is_active
  static Future<WhatsAppRule> updateRule(
    int id,
    Map<String, dynamic> payload,
  ) async {
    final uri = Uri.parse('$_baseUrl$_rulesPath/$id');
    late http.Response response;

    try {
      response = await http
          .put(uri, headers: _defaultHeaders, body: jsonEncode(payload))
          .timeout(const Duration(seconds: 15));
    } catch (e) {
      throw WhatsAppRulesException('Network error while updating rule.\n($e)');
    }

    if (response.statusCode == 200 || response.statusCode == 201) {
      try {
        return WhatsAppRule.fromJson(
          jsonDecode(response.body) as Map<String, dynamic>,
        );
      } catch (e) {
        throw WhatsAppRulesException(
          'Rule updated but response could not be parsed.\n($e)',
        );
      }
    }

    throw WhatsAppRulesException(
      'Failed to update rule (${response.statusCode}): ${response.body}',
    );
  }

  // ── DELETE ────────────────────────────────────────────────────────────────

  /// Deletes a rule by id.
  static Future<void> deleteRule(int id) async {
    final uri = Uri.parse('$_baseUrl$_rulesPath/$id');
    late http.Response response;

    try {
      response = await http
          .delete(uri, headers: _defaultHeaders)
          .timeout(const Duration(seconds: 15));
    } catch (e) {
      throw WhatsAppRulesException('Network error while deleting rule.\n($e)');
    }

    if (response.statusCode == 200 ||
        response.statusCode == 204 ||
        response.statusCode == 201) {
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
