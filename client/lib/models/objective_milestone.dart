/// Represents a tactical mission milestone unlocked or satisfied through
/// player actions and edge memory retrieval.
class ObjectiveMilestoneEvent {
  final String id;
  final String title;
  final String description;
  final String faction;
  final String repDelta;
  final String memorySource;
  final int latencyMs;
  final DateTime timestamp;

  const ObjectiveMilestoneEvent({
    required this.id,
    required this.title,
    required this.description,
    required this.faction,
    required this.repDelta,
    required this.memorySource,
    this.latencyMs = 0,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'faction': faction,
    'rep_delta': repDelta,
    'memory_source': memorySource,
    'latency_ms': latencyMs,
    'timestamp': timestamp.toIso8601String(),
  };

  factory ObjectiveMilestoneEvent.fromJson(Map<String, dynamic> json) =>
      ObjectiveMilestoneEvent(
        id: json['id'] as String? ?? '',
        title: json['title'] as String? ?? '',
        description: json['description'] as String? ?? '',
        faction: json['faction'] as String? ?? 'Grand Council',
        repDelta: json['rep_delta'] as String? ?? '+4 Rep',
        memorySource: json['memory_source'] as String? ?? 'Local Edge Cache',
        latencyMs: json['latency_ms'] as int? ?? 0,
        timestamp: json['timestamp'] != null
            ? DateTime.parse(json['timestamp'] as String)
            : DateTime.now(),
      );
}
