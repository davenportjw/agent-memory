import 'package:flutter_test/flutter_test.dart';
import '../lib/models/routing_decision.dart';
import '../lib/services/chrome_prompt_api_service.dart';
import '../lib/services/local_execution_manager.dart';

void main() {
  runLocalExecutionTests(test, (cond, [msg = 'Assertion failed']) => expect(cond, isTrue, reason: msg));
}

void runLocalExecutionTests(
  void Function(String name, dynamic Function() body) test,
  void Function(bool condition, [String message]) expect,
) {
  test('Local Execution: ChromePromptApiService non-web stub behavior', () async {
    final chromeService = ChromePromptApiService();
    final isAvail = await chromeService.checkAvailability();
    expect(isAvail == false, 'Chrome Prompt API must report false in VM test environment');
    expect(chromeService.isAvailable == false, 'Service isAvailable property must be false');

    bool threwUnsupported = false;
    try {
      chromeService.streamPrompt(
        prompt: 'Test prompt',
        onComplete: (_) {},
      );
    } on UnsupportedError catch (e) {
      threwUnsupported = true;
      expect(
        e.message?.contains('only supported in Google Chrome web runtime') == true,
        'Error message must indicate Chrome web runtime requirement',
      );
    }
    expect(threwUnsupported, 'streamPrompt must throw UnsupportedError on non-web VM');
  });

  test('Local Execution: LocalExecutionManager defaults and auto engine resolution', () async {
    final manager = LocalExecutionManager();
    expect(manager.selectedEngine == EdgeEngineSelection.auto, 'Default selection must be auto');

    await manager.init();
    expect(manager.isGeminiNanoAvailable == false, 'Gemini Nano unavailable in VM CLI environment');
    expect(manager.isGemmaAvailable == true, 'Gemma 4 must be available locally');
    expect(manager.activeEngine == ActiveEdgeEngine.gemma4, 'Auto mode must resolve to Gemma 4 when Chrome AI unavailable');
    expect(manager.activeEngineName.contains('Gemma 4'), 'Active engine name must reflect Gemma 4');
    expect(manager.activeRamMb == 1240.5, 'Active RAM must report Gemma 4 int4 memory usage (1240.5 MB)');
  });

  test('Local Execution: Engine switching and enforcement', () {
    final manager = LocalExecutionManager();
    
    // Switch to geminiNano
    manager.selectedEngine = EdgeEngineSelection.geminiNano;
    expect(manager.activeEngine == ActiveEdgeEngine.geminiNano, 'Active engine must switch to geminiNano');
    expect(manager.activeEngineName.contains('Gemini Nano'), 'Active engine name must reflect Gemini Nano');
    expect(manager.activeEngineDisplayShortName == 'Gemini Nano', 'Display short name should be Gemini Nano');
    expect(manager.isActiveEngineReady == false, 'Gemini Nano in VM stub is not active/ready');
    expect(manager.activeRamMb == 850.0, 'Active RAM must report Gemini Nano memory (~850 MB)');

    // Switch to gemma4
    manager.selectedEngine = EdgeEngineSelection.gemma4;
    expect(manager.activeEngine == ActiveEdgeEngine.gemma4, 'Active engine must switch to gemma4');
    expect(manager.activeEngineName.contains('Gemma 4'), 'Active engine name must reflect Gemma 4');
    expect(manager.activeEngineDisplayShortName == 'Gemma 4', 'Display short name should be Gemma 4');
    expect(manager.isActiveEngineReady == false, 'Gemma weights not loaded yet');
    expect(manager.activeRamMb == 1240.5, 'Active RAM must report Gemma 4 memory');
  });

  test('Local Execution: Execute on device via active Gemma 4 engine enforces weight residency', () async {
    final manager = LocalExecutionManager();
    await manager.init();
    expect(manager.activeEngine == ActiveEdgeEngine.gemma4, 'Expected active engine to be gemma4');
    expect(!manager.isGemmaWeightsLoaded, 'Gemma weights must not be marked loaded before user loads them');

    bool threwUnloaded = false;
    try {
      final stream = manager.executeOnDevice(
        prompt: 'Extract action items: Contact alice@example.org before Friday.',
        onComplete: (_) {},
        onError: (err) {
          threwUnloaded = true;
          expect(err.contains('Gemma 4 model weights are not loaded'), 'Error must prompt to load Gemma weights');
        },
      );
      await for (final _ in stream) {}
    } catch (e) {
      threwUnloaded = true;
      expect(e is StateError, 'Should throw StateError when model weights are not loaded');
    }

    expect(threwUnloaded, 'Inference must reject on-device execution without resident weights');
  });

  test('Local Execution: Gemini Nano selection in non-web environment throws when allowFallback=false', () {
    final manager = LocalExecutionManager();
    manager.selectedEngine = EdgeEngineSelection.geminiNano;

    bool threw = false;
    try {
      manager.executeOnDevice(
        prompt: 'Testing direct invocation',
        onComplete: (_) {},
        allowFallback: false,
      );
    } on UnsupportedError {
      threw = true;
    }

    expect(threw, 'Invoking Gemini Nano on non-web VM with allowFallback=false must throw UnsupportedError');
  });

  test('Local Execution: Gemini Nano unready seamlessly falls back to Gemma 4 engine', () async {
    final manager = LocalExecutionManager();
    manager.selectedEngine = EdgeEngineSelection.geminiNano;

    // Verify engine resolution falls back to Gemma 4
    expect(manager.isGeminiNanoAvailable == false, 'Nano is unavailable on non-web VM');
    expect(manager.isGemmaAvailable == true, 'Gemma 4 is available as edge engine');

    bool threwUnloaded = false;
    try {
      final stream = manager.executeOnDevice(
        prompt: 'Summarize meeting notes',
        onComplete: (_) {},
        onError: (err) {
          threwUnloaded = true;
        },
        allowFallback: true,
      );
      await for (final _ in stream) {}
    } catch (_) {
      threwUnloaded = true;
    }

    expect(threwUnloaded, 'Fallback to Gemma 4 must enforce weight residency without silent mocks');
  });

  test('Local Execution: Auto engine selection marks auto fallback telemetry and selects Gemma 4', () async {
    final manager = LocalExecutionManager();
    manager.selectedEngine = EdgeEngineSelection.auto;
    await manager.init();

    expect(manager.activeEngine == ActiveEdgeEngine.gemma4, 'Auto selection must resolve to Gemma 4 when Nano unready');
    expect(manager.activeEngineName.contains('Gemma 4'), 'Active engine name must reflect Gemma 4');
  });

  test('Local Execution: IntentPillData copyWith and ExecutionTelemetry fallback serialization', () {
    final pill = IntentPillData(
      id: 'pill-1',
      intentLabel: 'Local Fast Intent [Gemini Nano]',
      justificationRule: 'RULE-1',
      memoryDelta: 'Delta context: 10 chars',
      route: ExecutionRoute.EDGE_LOCAL,
      ruleId: 'RULE-1',
      detectedPii: const [],
      tokenCount: 50,
      timestamp: DateTime.now(),
      isFallback: false,
    );

    final updated = pill.copyWith(
      intentLabel: 'Local Fast Intent [Gemma 4 int4 - Fallback]',
      isFallback: true,
      fallbackReason: 'Gemini Nano unready in Chrome',
    );

    expect(updated.id == 'pill-1', 'ID must remain identical');
    expect(updated.intentLabel == 'Local Fast Intent [Gemma 4 int4 - Fallback]', 'Label must update');
    expect(updated.isFallback == true, 'isFallback must be true');
    expect(updated.fallbackReason == 'Gemini Nano unready in Chrome', 'Fallback reason must match');

    final telemetry = ExecutionTelemetry(
      ttftMs: 25,
      totalLatencyMs: 80,
      tokensGenerated: 42,
      throughputTps: 35.0,
      ramUsageMb: 1240.5,
      cloudEgressKb: 0.0,
      modelName: 'Gemma 4 int4',
      circuitBreakerState: CircuitBreakerState.CLOSED,
      isFallback: true,
      fallbackReason: 'On-device fallback',
    );

    final json = telemetry.toJson();
    expect(json['isFallback'] == true, 'isFallback must serialize to JSON');
    expect(json['fallbackReason'] == 'On-device fallback', 'fallbackReason must serialize to JSON');
  });

  test('Local Execution: createLanguageModel and download state on ChromePromptApiService', () async {
    final chromeService = ChromePromptApiService();
    expect(chromeService.needsDownload == false, 'needsDownload must be false on non-web');
    expect(chromeService.isDownloading == false, 'isDownloading must be false on non-web');
    expect(chromeService.isActive == false, 'isActive must be false on non-web');

    final success = await chromeService.createLanguageModel();
    expect(success == false, 'createLanguageModel must return false on non-web environment');

    final manager = LocalExecutionManager();
    final mgrSuccess = await manager.createLanguageModel();
    expect(mgrSuccess == false, 'manager.createLanguageModel must return false on non-web environment');
  });
}
