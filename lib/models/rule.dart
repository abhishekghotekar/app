/// An automation rule that triggers alerts or reports.
class Rule {
  const Rule({
    required this.id,
    required this.name,
    required this.description,
    required this.schedule,
    required this.type, // "Time-based" or "Event-based"
    this.enabled = true,
    this.channels = const ['Push'],
    this.recipients = const ['Admin'],
  });

  final String id;
  final String name;
  final String description;
  final String schedule;
  final String type;
  final bool enabled;
  final List<String> channels;
  final List<String> recipients;
}
