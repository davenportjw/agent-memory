import 'package:flutter_test/flutter_test.dart';
import '../lib/services/gemma_edge_service.dart';

void main() {
  runGemmaEdgeTests(test, (cond, [msg = 'Assertion failed']) => expect(cond, isTrue, reason: msg));
}

void runGemmaEdgeTests(void Function(String name, void Function() body) test, void Function(bool condition, [String message]) expect) {
  test('Gemma Edge: Throws StateError when weights are uninitialized (Zero Mock Enforcement)', () async {
    final gemma = GemmaEdgeService();
    expect(!gemma.isModelLoaded, 'Model should not be marked loaded before weights are provided');

    var threwError = false;
    try {
      final stream = gemma.streamInference(
        prompt: 'Extract action items: Contact alice@example.org before Friday.',
        onComplete: (_) {},
        onError: (err) {
          threwError = true;
        },
      );
      await for (final _ in stream) {}
    } catch (e) {
      threwError = true;
      expect(e is StateError, 'Should throw StateError when on-device weights are not resident');
    }

    expect(threwError == true, 'Inference must reject execution when model weights are not loaded');
  });

  test('Gemma Edge: Extracts local system entities correctly', () {
    final gemma = GemmaEdgeService();
    final entities = gemma.extractEntitiesLocally(
      'Migrate to SQLite WASM cache and keep bundle < 50 KB before Friday deadline.',
    );

    final types = entities.map((e) => e.entityType).toList();
    expect(types.contains('DATABASE_ENGINE'), 'Should extract SQLite database engine');
    expect(types.contains('DEADLINE'), 'Should extract Friday deadline');
    expect(types.contains('BUDGET_LIMIT'), 'Should extract bundle budget limit');
  });

  test('Gemma Edge: Correctly reports variant memory consumption and hardware limits', () {
    final gemma = GemmaEdgeService();
    
    // Default variant
    expect(gemma.activeModelVariant == 'gemma-4-2b', 'Default variant should be gemma-4-2b');
    expect(gemma.activeRamUsageMb == 1240.5, 'Default variant should allocate 1240.5 MB');

    // Switch to larger variant
    gemma.selectVariant('gemma-4-a4b');
    expect(gemma.activeModelVariant == 'gemma-4-a4b', 'Active variant should switch to gemma-4-a4b');
    expect(gemma.activeRamUsageMb == 1850.0, 'a4b variant should allocate 1850.0 MB');
  });

  test('Gemma Edge: loadWeights contract reports truthful status on unsupported platforms', () async {
    final gemma = GemmaEdgeService();
    final status = await gemma.init();

    // In VM environment, WebGPU is unsupported and reports clean status
    expect(status.ready == false, 'VM environment must not report ready without real WebGPU');
    expect(!gemma.isModelLoaded, 'isModelLoaded should remain false in VM test environment');
  });
}
