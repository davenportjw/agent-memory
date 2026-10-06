import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import '../models/routing_decision.dart';
import 'chrome_prompt_status.dart';

@JS('chromePromptAPIBridge')
external JSObject? get chromePromptAPIBridge;

class ChromePromptApiImpl {
  bool _isAvailable = false;
  String _modelName = 'Gemini Nano (Chrome Built-in AI)';
  ChromePromptStatus? _cachedStatus;

  bool get isAvailable => _isAvailable;
  bool get isActive => _cachedStatus?.isActive ?? false;
  bool get needsDownload => _cachedStatus?.needsDownload ?? false;
  bool get isDownloading => _cachedStatus?.isDownloading ?? false;
  String get modelName => _modelName;
  String? get errorMessage => _cachedStatus?.errorMessage;
  String? get instructions => _cachedStatus?.instructions;

  Future<ChromePromptStatus> checkAvailability() async {
    final bridge = chromePromptAPIBridge;
    if (bridge == null) {
      _isAvailable = false;
      _cachedStatus = const ChromePromptStatus(
        isAvailable: false,
        isDownloaded: false,
        status: 'no_bridge',
        modelName: 'Gemini Nano (Chrome Built-in AI)',
        contextWindow: 0,
        errorMessage:
            'window.chromePromptAPIBridge not detected in browser context. Verify Chrome 131+ with flags enabled.',
      );
      return _cachedStatus!;
    }

    try {
      final promise = bridge.callMethod('checkAvailability'.toJS) as JSPromise;
      final res = await promise.toDart as JSObject;

      final bool available = (res.getProperty('isAvailable'.toJS) as JSBoolean?)?.toDart ?? false;
      final bool downloaded = (res.getProperty('isDownloaded'.toJS) as JSBoolean?)?.toDart ?? false;
      final String status = (res.getProperty('status'.toJS) as JSString?)?.toDart ?? 'no';
      final String model = (res.getProperty('modelName'.toJS) as JSString?)?.toDart ?? 'Gemini Nano (Chrome Built-in AI)';
      final int contextWindow = (res.getProperty('contextWindow'.toJS) as JSNumber?)?.toDartInt ?? 0;
      final String? errorMsg = (res.getProperty('errorMessage'.toJS) as JSString?)?.toDart;
      final String? instr = (res.getProperty('instructions'.toJS) as JSString?)?.toDart;

      _isAvailable = available;
      _modelName = model;
      _cachedStatus = ChromePromptStatus(
        isAvailable: available,
        isDownloaded: downloaded,
        status: status,
        modelName: model,
        contextWindow: contextWindow,
        errorMessage: errorMsg,
        instructions: instr,
      );
      return _cachedStatus!;
    } catch (e) {
      _isAvailable = false;
      _cachedStatus = ChromePromptStatus(
        isAvailable: false,
        isDownloaded: false,
        status: 'error',
        modelName: 'Gemini Nano (Chrome Built-in AI)',
        contextWindow: 0,
        errorMessage: 'Failed to query Chrome Prompt API bridge: $e',
      );
      return _cachedStatus!;
    }
  }

  Future<bool> createLanguageModel({void Function(int loaded, int total)? onProgress}) async {
    final bridge = chromePromptAPIBridge;
    if (bridge == null) return false;

    try {
      JSFunction? progressCallback;
      if (onProgress != null) {
        progressCallback = ((JSNumber loaded, JSNumber total) {
          onProgress(loaded.toDartInt, total.toDartInt);
        }).toJS;
      }

      final promise = (progressCallback != null)
          ? bridge.callMethod('createLanguageModel'.toJS, progressCallback) as JSPromise
          : bridge.callMethod('createLanguageModel'.toJS) as JSPromise;

      final res = await promise.toDart as JSObject;
      final bool success = (res.getProperty('success'.toJS) as JSBoolean?)?.toDart ?? false;
      await checkAvailability();
      return success;
    } catch (e) {
      await checkAvailability();
      return false;
    }
  }

  Stream<String> streamPrompt({
    required String prompt,
    required void Function(ExecutionTelemetry telemetry) onComplete,
    void Function(String error)? onError,
  }) {
    final controller = StreamController<String>();
    final bridge = chromePromptAPIBridge;

    if (bridge == null) {
      const errorMsg =
          'Chrome Built-in AI (window.ai) is not available. Please enable flags in chrome://flags';
      onError?.call(errorMsg);
      controller.addError(errorMsg);
      controller.close();
      return controller.stream;
    }

    final onChunk = ((JSString chunk) {
      controller.add(chunk.toDart);
    }).toJS;

    final onDone = ((JSObject telemetry) {
      final ttft = (telemetry.getProperty('ttftMs'.toJS) as JSNumber?)?.toDartInt ?? 45;
      final totalLatency = (telemetry.getProperty('totalLatencyMs'.toJS) as JSNumber?)?.toDartInt ?? 150;
      final tokens = (telemetry.getProperty('tokenCount'.toJS) as JSNumber?)?.toDartInt ?? 1;
      final tps = (telemetry.getProperty('tps'.toJS) as JSNumber?)?.toDartDouble ?? 30.0;
      final model = (telemetry.getProperty('model'.toJS) as JSString?)?.toDart ?? 'Gemini Nano (Chrome Built-in AI)';

      final execTelemetry = ExecutionTelemetry(
        ttftMs: ttft,
        totalLatencyMs: totalLatency,
        tokensGenerated: tokens,
        throughputTps: tps,
        ramUsageMb: 850.0,
        cloudEgressKb: 0.0,
        modelName: model,
      );

      onComplete(execTelemetry);
      controller.close();
    }).toJS;

    final onErr = ((JSString error) {
      final errorMsg = error.toDart;
      onError?.call(errorMsg);
      controller.addError(errorMsg);
      controller.close();
    }).toJS;

    try {
      bridge.callMethod(
        'promptStreaming'.toJS,
        prompt.toJS,
        onChunk,
        onDone,
        onErr,
      );
    } catch (e) {
      final errorMsg = 'Failed to execute promptStreaming: $e';
      onError?.call(errorMsg);
      controller.addError(errorMsg);
      controller.close();
    }

    return controller.stream;
  }
}
