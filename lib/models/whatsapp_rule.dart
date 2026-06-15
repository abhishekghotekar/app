/// Represents a WhatsApp notification rule returned by
/// GET /whatsapp/rules  (and POST /whatsapp/rules).
///
/// API shape:
/// {
///   "id": 12,
///   "rule_name": "Notify warden of absentees",
///   "trigger_type": "event_based" | "time_based",
///   "condition": "all" | "present" | "absent",
///   "send_to": ["admin"],
///   "channels": ["whatsapp"],
///   "phone_number": "+919373589526",
///   "custom_message": "Please check and take action.",
///   "send_time": "20:00",
///   "is_active": true,
///   "created_at": "2026-06-04T05:16:42.491939"
/// }
class WhatsAppRule {
  const WhatsAppRule({
    required this.id,
    required this.ruleName,
    required this.triggerType,
    required this.condition,
    required this.sendTo,
    required this.channels,
    required this.phoneNumber,
    required this.customMessage,
    required this.sendTime,
    required this.isActive,
    required this.createdAt,
  });

  final String id;
  final String ruleName;

  /// "time_based" or "event_based"
  final String triggerType;

  /// "all", "present", or "absent"
  final String condition;

  final List<String> sendTo;
  final List<String> channels;
  final String phoneNumber;
  final String customMessage;

  /// HH:mm, e.g. "20:00"
  final String sendTime;

  final bool isActive;
  final DateTime createdAt;

  // ── Helpers ──────────────────────────────────────────────────────────────

  bool get isTimeBased => triggerType == 'time_based';

  String get displayTrigger =>
      isTimeBased ? 'Time-based • $sendTime' : 'Event-based';

  String get displayCondition {
    switch (condition) {
      case 'present':
        return 'When present';
      case 'absent':
        return 'When absent';
      default:
        return 'All';
    }
  }

  // ── Serialisation ─────────────────────────────────────────────────────────

  factory WhatsAppRule.fromJson(Map<String, dynamic> json) {
    return WhatsAppRule(
      id: (json['id'] ?? '').toString(),
      ruleName: json['rule_name'] as String? ?? '',
      triggerType: json['trigger_type'] as String? ?? 'time_based',
      condition: json['condition'] as String? ?? 'all',
      sendTo: _toStringList(json['send_to']),
      channels: _toStringList(json['channels']),
      phoneNumber: json['phone_number'] as String? ?? '',
      customMessage: json['custom_message'] as String? ?? '',
      sendTime: json['send_time'] as String? ?? '09:00',
      isActive: json['enabled'] as bool? ?? json['is_active'] as bool? ?? true,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'rule_name': ruleName,
        'trigger_type': triggerType,
        'condition': condition,
        'send_to': sendTo,
        'channels': channels,
        'phone_number': phoneNumber,
        'custom_message': customMessage,
        'send_time': sendTime,
        'enabled': isActive,
        'is_active': isActive,
      };

  WhatsAppRule copyWith({bool? isActive}) => WhatsAppRule(
        id: id,
        ruleName: ruleName,
        triggerType: triggerType,
        condition: condition,
        sendTo: sendTo,
        channels: channels,
        phoneNumber: phoneNumber,
        customMessage: customMessage,
        sendTime: sendTime,
        isActive: isActive ?? this.isActive,
        createdAt: createdAt,
      );

  static List<String> _toStringList(dynamic v) {
    if (v is List) return v.map((e) => e.toString()).toList();
    return [];
  }
}
