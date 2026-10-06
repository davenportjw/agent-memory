import 'routing_decision.dart';

class EvalBenchmarkItem {
  final String id;
  final String category;
  final String expectedRoute;
  final String prompt;
  final Map<String, dynamic> goldenCriteria;

  const EvalBenchmarkItem({
    required this.id,
    required this.category,
    required this.expectedRoute,
    required this.prompt,
    required this.goldenCriteria,
  });

  factory EvalBenchmarkItem.fromJson(Map<String, dynamic> json) => EvalBenchmarkItem(
    id: json['id'] ?? '',
    category: json['category'] ?? '',
    expectedRoute: json['expected_route'] ?? 'EDGE_LOCAL',
    prompt: json['prompt'] ?? '',
    goldenCriteria: json['golden_criteria'] ?? {},
  );
}

class EvalScoreCard {
  final String benchmarkId;
  final String modelId;
  final double semanticFidelity;       // 1.0 - 5.0 (weight 0.35)
  final double instructionCompliance;  // 1.0 - 5.0 (weight 0.25)
  final double safetyAndPiiRedaction;  // 1.0 - 5.0 (weight 0.25)
  final double efficiencyFactor;       // 1.0 - 5.0 (weight 0.15)
  final String edgeOutput;
  final String goldenOutput;
  final int ttftMs;
  final double ramMb;
  final String judgeVerdict;

  const EvalScoreCard({
    required this.benchmarkId,
    this.modelId = '',
    required this.semanticFidelity,
    required this.instructionCompliance,
    required this.safetyAndPiiRedaction,
    required this.efficiencyFactor,
    required this.edgeOutput,
    required this.goldenOutput,
    required this.ttftMs,
    required this.ramMb,
    required this.judgeVerdict,
  });

  /// Total weighted score according to docs/eval_rater_guide.md:
  /// Total Score = 0.35 * SemanticFidelity + 0.25 * InstructionCompliance + 0.25 * SafetyPII + 0.15 * EfficiencyFactor
  double get totalScore {
    return (0.35 * semanticFidelity) +
        (0.25 * instructionCompliance) +
        (0.25 * safetyAndPiiRedaction) +
        (0.15 * efficiencyFactor);
  }

  Map<String, dynamic> toJson() => {
    'benchmark_id': benchmarkId,
    'model_id': modelId,
    'semantic_fidelity': semanticFidelity,
    'instruction_compliance': instructionCompliance,
    'safety_and_pii_redaction': safetyAndPiiRedaction,
    'efficiency_factor': efficiencyFactor,
    'total_score': totalScore,
    'edge_output': edgeOutput,
    'golden_output': goldenOutput,
    'ttft_ms': ttftMs,
    'ram_mb': ramMb,
    'judge_verdict': judgeVerdict,
  };
}

/// Represents an active model combination in the Multi-Model Test Bench.
class ModelComparisonEntry {
  final String modelId;
  final String displayName;
  final String executionTier;
  final String description;
  final bool isEdge;
  final bool isEnabled;
  final String responseText;
  final ExecutionTelemetry telemetry;
  final EvalScoreCard? scoreCard;
  final bool isExecuting;
  final String? error;

  const ModelComparisonEntry({
    required this.modelId,
    required this.displayName,
    required this.executionTier,
    required this.description,
    required this.isEdge,
    this.isEnabled = true,
    this.responseText = '',
    required this.telemetry,
    this.scoreCard,
    this.isExecuting = false,
    this.error,
  });

  ModelComparisonEntry copyWith({
    String? responseText,
    ExecutionTelemetry? telemetry,
    EvalScoreCard? scoreCard,
    bool? isExecuting,
    bool? isEnabled,
    String? error,
  }) {
    return ModelComparisonEntry(
      modelId: modelId,
      displayName: displayName,
      executionTier: executionTier,
      description: description,
      isEdge: isEdge,
      isEnabled: isEnabled ?? this.isEnabled,
      responseText: responseText ?? this.responseText,
      telemetry: telemetry ?? this.telemetry,
      scoreCard: scoreCard ?? this.scoreCard,
      isExecuting: isExecuting ?? this.isExecuting,
      error: error,
    );
  }
}
