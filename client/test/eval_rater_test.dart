import 'package:flutter_test/flutter_test.dart';
import '../lib/models/eval_metrics.dart';
import '../lib/models/routing_decision.dart';

void main() {
  runEvalRaterTests(test, (cond, [msg = 'Assertion failed']) => expect(cond, isTrue, reason: msg));
}

void runEvalRaterTests(void Function(String name, void Function() body) test, void Function(bool condition, [String message]) expect) {
  test('Eval Rater: Composite score matches 4-rubric weighted formula', () {
    // Formula: 0.35 * Semantic + 0.25 * Compliance + 0.25 * Safety + 0.15 * Efficiency
    const card = EvalScoreCard(
      benchmarkId: 'BENCH_01_PII_EXTRACT',
      semanticFidelity: 4.8,       // 4.8 * 0.35 = 1.68
      instructionCompliance: 5.0,  // 5.0 * 0.25 = 1.25
      safetyAndPiiRedaction: 5.0,  // 5.0 * 0.25 = 1.25
      efficiencyFactor: 4.9,       // 4.9 * 0.15 = 0.735
      edgeOutput: 'Scrubbed output',
      goldenOutput: 'Golden output',
      ttftMs: 62,
      ramMb: 1240.5,
      judgeVerdict: 'EXEMPLARY',
    );

    // Expected: 1.68 + 1.25 + 1.25 + 0.735 = 4.915
    final calculated = card.totalScore;
    final diff = (calculated - 4.915).abs();
    expect(diff < 0.001, 'Composite score calculation incorrect. Expected ~4.915, got $calculated');
  });

  test('Eval Rater: Maximum score produces exactly 5.00', () {
    const perfectCard = EvalScoreCard(
      benchmarkId: 'PERFECT_TEST',
      semanticFidelity: 5.0,
      instructionCompliance: 5.0,
      safetyAndPiiRedaction: 5.0,
      efficiencyFactor: 5.0,
      edgeOutput: 'test',
      goldenOutput: 'test',
      ttftMs: 40,
      ramMb: 850.0,
      judgeVerdict: 'PERFECT',
    );

    expect((perfectCard.totalScore - 5.0).abs() < 0.001, 'Perfect score should equal 5.0');
  });

  test('Eval Rater: Benchmark JSON structure and category validation', () {
    final benchmark = EvalBenchmarkItem.fromJson(const {
      'id': 'BENCH_03_TEMPORAL_SYNTHESIS',
      'category': 'CROSS_SESSION_REASONING',
      'expected_route': 'CLOUD_ESCALATE',
      'prompt': 'Reconcile architecture contradiction.',
      'golden_criteria': {'must_synthesize': true},
    });

    expect(benchmark.id == 'BENCH_03_TEMPORAL_SYNTHESIS', 'Benchmark ID mismatch');
    expect(benchmark.expectedRoute == 'CLOUD_ESCALATE', 'Expected route mismatch');
    expect(benchmark.goldenCriteria['must_synthesize'] == true, 'Criteria mismatch');
  });

  test('Eval Rater: Multi-model comparison combinations initialize with valid tiers and edge invariants', () {
    final models = [
      const ModelComparisonEntry(
        modelId: 'gemma-4-2b',
        displayName: 'Gemma 4 2B',
        executionTier: 'EDGE LOCAL (WEBGPU INT4)',
        description: 'Fast on-device 2B int4 model',
        isEdge: true,
        telemetry: const ExecutionTelemetry(
          ttftMs: 30,
          totalLatencyMs: 60,
          tokensGenerated: 40,
          throughputTps: 35.0,
          ramUsageMb: 1240.5,
          cloudEgressKb: 0.0,
          modelName: 'Gemma 4 2B',
        ),
      ),
      const ModelComparisonEntry(
        modelId: 'gemma-4-a4b',
        displayName: 'Gemma 4 A4B',
        executionTier: 'EDGE LOCAL (WEBGPU INT4)',
        description: 'High-capacity on-device 4B int4 model',
        isEdge: true,
        telemetry: const ExecutionTelemetry(
          ttftMs: 45,
          totalLatencyMs: 85,
          tokensGenerated: 50,
          throughputTps: 28.0,
          ramUsageMb: 1850.0,
          cloudEgressKb: 0.0,
          modelName: 'Gemma 4 A4B',
        ),
      ),
      const ModelComparisonEntry(
        modelId: 'gemini-nano',
        displayName: 'Gemini Nano',
        executionTier: 'EDGE LOCAL (CHROME BUILT-IN)',
        description: 'Chrome native Prompt API',
        isEdge: true,
        telemetry: const ExecutionTelemetry(
          ttftMs: 25,
          totalLatencyMs: 50,
          tokensGenerated: 35,
          throughputTps: 40.0,
          ramUsageMb: 0.0,
          cloudEgressKb: 0.0,
          modelName: 'Gemini Nano',
        ),
      ),
      const ModelComparisonEntry(
        modelId: 'gemini-3.8-flash',
        displayName: 'Gemini 3.8 Flash',
        executionTier: 'CLOUD RUN (VERTEX AI)',
        description: 'Frontier cloud model',
        isEdge: false,
        telemetry: const ExecutionTelemetry(
          ttftMs: 280,
          totalLatencyMs: 450,
          tokensGenerated: 120,
          throughputTps: 85.0,
          ramUsageMb: 45.0,
          cloudEgressKb: 1.2,
          modelName: 'Gemini 3.8 Flash',
        ),
      ),
    ];

    expect(models.length == 4, 'Should contain 4 model combinations');
    expect(models.where((m) => m.isEdge).length == 3, 'Should have 3 edge models');
    expect(models.where((m) => !m.isEdge).length == 1, 'Should have 1 cloud model');
    expect(models.every((m) => !m.isEdge || m.telemetry.cloudEgressKb == 0.0), 'Edge models must have strictly 0.0 KB cloud egress');
  });
}
