/// Execution routes matching shared/routing_policy.json
enum ExecutionRoute {
  EDGE_LOCAL,
  EDGE_FALLBACK,
  CLOUD_ESCALATE,
}

extension ExecutionRouteExtension on ExecutionRoute {
  String get key {
    switch (this) {
      case ExecutionRoute.EDGE_LOCAL:
        return 'EDGE_LOCAL';
      case ExecutionRoute.EDGE_FALLBACK:
        return 'EDGE_FALLBACK';
      case ExecutionRoute.CLOUD_ESCALATE:
        return 'CLOUD_ESCALATE';
    }
  }

  String get displayName {
    switch (this) {
      case ExecutionRoute.EDGE_LOCAL:
        return 'Local Edge (On-Device)';
      case ExecutionRoute.EDGE_FALLBACK:
        return 'Offline Fallback (LiteRT CPU)';
      case ExecutionRoute.CLOUD_ESCALATE:
        return 'Cloud (Gemini 3.8 Flash)';
    }
  }
}

/// Circuit Breaker States
enum CircuitBreakerState {
  CLOSED,    // Normal healthy operation
  OPEN,      // Cloud tripping; routing all to EDGE_FALLBACK
  HALF_OPEN, // Testing cloud probe
}

/// Actionable Intent Pill Data
/// Every pill MUST convey:
/// 1) Resolved User Intent
/// 2) Policy Justification / Route
/// 3) Memory Delta
class IntentPillData {
  final String id;
  final String intentLabel;
  final String justificationRule;
  final String memoryDelta;
  final ExecutionRoute route;
  final String ruleId;
  final List<String> detectedPii;
  final int tokenCount;
  final DateTime timestamp;
  final bool isFallback;
  final String? fallbackReason;
  final Map<String, dynamic> metadata;

  const IntentPillData({
    required this.id,
    required this.intentLabel,
    required this.justificationRule,
    required this.memoryDelta,
    required this.route,
    required this.ruleId,
    this.detectedPii = const [],
    this.tokenCount = 0,
    required this.timestamp,
    this.isFallback = false,
    this.fallbackReason,
    this.metadata = const {},
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'intent_label': intentLabel,
    'justification_rule': justificationRule,
    'memory_delta': memoryDelta,
    'route': route.key,
    'rule_id': ruleId,
    'detected_pii': detectedPii,
    'token_count': tokenCount,
    'timestamp': timestamp.toIso8601String(),
    'is_fallback': isFallback,
    'fallback_reason': fallbackReason,
    'metadata': metadata,
  };

  factory IntentPillData.fromJson(Map<String, dynamic> json) {
    ExecutionRoute parsedRoute = ExecutionRoute.EDGE_LOCAL;
    if (json['route'] == 'EDGE_FALLBACK') {
      parsedRoute = ExecutionRoute.EDGE_FALLBACK;
    } else if (json['route'] == 'CLOUD_ESCALATE') {
      parsedRoute = ExecutionRoute.CLOUD_ESCALATE;
    }

    return IntentPillData(
      id: json['id'] ?? '',
      intentLabel: json['intent_label'] ?? 'General Query',
      justificationRule: json['justification_rule'] ?? '',
      memoryDelta: json['memory_delta'] ?? 'Local working context updated',
      route: parsedRoute,
      ruleId: json['rule_id'] ?? 'RULE_EDGE_DEFAULT_FAST',
      detectedPii: (json['detected_pii'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      tokenCount: json['token_count'] ?? 0,
      timestamp: json['timestamp'] != null ? DateTime.parse(json['timestamp']) : DateTime.now(),
      isFallback: json['is_fallback'] == true,
      fallbackReason: json['fallback_reason'] as String?,
      metadata: json['metadata'] ?? {},
    );
  }

  IntentPillData copyWith({
    String? id,
    String? intentLabel,
    String? justificationRule,
    String? memoryDelta,
    ExecutionRoute? route,
    String? ruleId,
    List<String>? detectedPii,
    int? tokenCount,
    DateTime? timestamp,
    bool? isFallback,
    String? fallbackReason,
    Map<String, dynamic>? metadata,
  }) {
    return IntentPillData(
      id: id ?? this.id,
      intentLabel: intentLabel ?? this.intentLabel,
      justificationRule: justificationRule ?? this.justificationRule,
      memoryDelta: memoryDelta ?? this.memoryDelta,
      route: route ?? this.route,
      ruleId: ruleId ?? this.ruleId,
      detectedPii: detectedPii ?? this.detectedPii,
      tokenCount: tokenCount ?? this.tokenCount,
      timestamp: timestamp ?? this.timestamp,
      isFallback: isFallback ?? this.isFallback,
      fallbackReason: fallbackReason ?? this.fallbackReason,
      metadata: metadata ?? this.metadata,
    );
  }
}

/// Live Execution Telemetry
class ExecutionTelemetry {
  final int ttftMs;
  final int totalLatencyMs;
  final int tokensGenerated;
  final double throughputTps;
  final double ramUsageMb;
  final double cloudEgressKb;
  final String modelName;
  final CircuitBreakerState circuitBreakerState;
  final bool isFallback;
  final String? fallbackReason;

  const ExecutionTelemetry({
    required this.ttftMs,
    required this.totalLatencyMs,
    required this.tokensGenerated,
    required this.throughputTps,
    required this.ramUsageMb,
    required this.cloudEgressKb,
    required this.modelName,
    this.circuitBreakerState = CircuitBreakerState.CLOSED,
    this.isFallback = false,
    this.fallbackReason,
  });

  factory ExecutionTelemetry.empty() => const ExecutionTelemetry(
    ttftMs: 0,
    totalLatencyMs: 0,
    tokensGenerated: 0,
    throughputTps: 0.0,
    ramUsageMb: 0.0,
    cloudEgressKb: 0.0,
    modelName: 'None',
    isFallback: false,
  );

  Map<String, dynamic> toJson() => {
    'ttft_ms': ttftMs,
    'total_latency_ms': totalLatencyMs,
    'tokens_generated': tokensGenerated,
    'throughput_tps': throughputTps,
    'ram_usage_mb': ramUsageMb,
    'cloud_egress_kb': cloudEgressKb,
    'model_name': modelName,
    'circuit_breaker': circuitBreakerState.name,
    'is_fallback': isFallback,
    'isFallback': isFallback,
    'fallback_reason': fallbackReason,
    'fallbackReason': fallbackReason,
  };
}
