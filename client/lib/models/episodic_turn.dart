class ExtractedEntity {
  final String entityType;
  final String entityValue;
  final double confidence;

  const ExtractedEntity({
    required this.entityType,
    required this.entityValue,
    this.confidence = 1.0,
  });

  Map<String, dynamic> toJson() => {
    'entity_type': entityType,
    'entity_value': entityValue,
    'confidence': confidence,
  };

  factory ExtractedEntity.fromJson(Map<String, dynamic> json) => ExtractedEntity(
    entityType: json['entity_type'] ?? 'UNKNOWN',
    entityValue: json['entity_value'] ?? '',
    confidence: (json['confidence'] as num?)?.toDouble() ?? 1.0,
  );
}

class EpisodicTurn {
  final String id;
  final String sessionId;
  final DateTime timestamp;
  final String userPrompt;
  final String modelResponse;
  final String route; // EDGE_LOCAL, EDGE_FALLBACK, CLOUD_ESCALATE
  final String modelName;
  final int latencyMs;
  final int ttftMs;
  final bool isPiiSanitized;
  final List<ExtractedEntity> entitiesExtracted;
  String status; // UNCONSOLIDATED, CONSOLIDATED

  EpisodicTurn({
    required this.id,
    required this.sessionId,
    required this.timestamp,
    required this.userPrompt,
    required this.modelResponse,
    required this.route,
    required this.modelName,
    required this.latencyMs,
    required this.ttftMs,
    required this.isPiiSanitized,
    required this.entitiesExtracted,
    this.status = 'UNCONSOLIDATED',
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'session_id': sessionId,
    'timestamp': timestamp.toIso8601String(),
    'user_prompt': userPrompt,
    'model_response': modelResponse,
    'route': route,
    'model_name': modelName,
    'latency_ms': latencyMs,
    'ttft_ms': ttftMs,
    'is_pii_sanitized': isPiiSanitized,
    'status': status,
    'entities_extracted': entitiesExtracted.map((e) => e.toJson()).toList(),
  };

  factory EpisodicTurn.fromJson(Map<String, dynamic> json) => EpisodicTurn(
    id: json['id'] ?? '',
    sessionId: json['session_id'] ?? '',
    timestamp: json['timestamp'] != null ? DateTime.parse(json['timestamp']) : DateTime.now(),
    userPrompt: json['user_prompt'] ?? '',
    modelResponse: json['model_response'] ?? '',
    route: json['route'] ?? 'EDGE_LOCAL',
    modelName: json['model_name'] ?? 'gemma-4-2b',
    latencyMs: json['latency_ms'] ?? 0,
    ttftMs: json['ttft_ms'] ?? 0,
    isPiiSanitized: json['is_pii_sanitized'] ?? false,
    status: json['status'] ?? 'UNCONSOLIDATED',
    entitiesExtracted: (json['entities_extracted'] as List<dynamic>?)
            ?.map((e) => ExtractedEntity.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [],
  );
}
