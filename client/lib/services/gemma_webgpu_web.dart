import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import '../models/routing_decision.dart';
import 'gemma_webgpu_stub.dart';

export 'gemma_webgpu_stub.dart' show GemmaWebGpuStatus;

@JS('gemmaWebGPUBridge')
external JSObject? get gemmaWebGPUBridge;

class GemmaWebGpuImpl {
  bool _hasWebGPU = false;
  bool _isReady = false;
  bool _isDownloading = false;
  int _loadedBytes = 0;
  int _totalBytes = 1572864000;
  double _progressPercent = 0.0;
  double _ramUsageMb = 0.0;
  String? _error;

  bool get hasWebGPU => _hasWebGPU;
  bool get isReady => _isReady;
  bool get isDownloading => _isDownloading;
  int get loadedBytes => _loadedBytes;
  int get totalBytes => _totalBytes;
  double get progressPercent => _progressPercent;
  double get ramUsageMb => _ramUsageMb;
  String? get error => _error;

  Future<GemmaWebGpuStatus> init() async {
    final bridge = gemmaWebGPUBridge;
    if (bridge == null) {
      _hasWebGPU = false;
      _isReady = false;
      _error = 'window.gemmaWebGPUBridge not found in browser window.';
      return GemmaWebGpuStatus(
        status: 'no_bridge',
        hasWebGPU: false,
        ready: false,
        error: _error,
      );
    }

    try {
      final promise = bridge.callMethod('init'.toJS) as JSPromise;
      final res = await promise.toDart as JSObject;

      _hasWebGPU = (res.getProperty('hasWebGPU'.toJS) as JSBoolean?)?.toDart ?? false;
      _isReady = (res.getProperty('ready'.toJS) as JSBoolean?)?.toDart ?? false;
      _isDownloading = (res.getProperty('isDownloading'.toJS) as JSBoolean?)?.toDart ?? false;
      _loadedBytes = (res.getProperty('loadedBytes'.toJS) as JSNumber?)?.toDartInt ?? 0;
      _totalBytes = (res.getProperty('totalBytes'.toJS) as JSNumber?)?.toDartInt ?? 1572864000;
      _progressPercent = (res.getProperty('progressPercent'.toJS) as JSNumber?)?.toDartDouble ?? 0.0;
      _ramUsageMb = (res.getProperty('ramUsageMb'.toJS) as JSNumber?)?.toDartDouble ?? 0.0;
      _error = (res.getProperty('error'.toJS) as JSString?)?.toDart;

      return GemmaWebGpuStatus(
        status: (res.getProperty('status'.toJS) as JSString?)?.toDart ?? 'uninitialized',
        ready: _isReady,
        isDownloading: _isDownloading,
        hasWebGPU: _hasWebGPU,
        loadedBytes: _loadedBytes,
        totalBytes: _totalBytes,
        progressPercent: _progressPercent,
        ramUsageMb: _ramUsageMb,
        error: _error,
      );
    } catch (e) {
      _error = e.toString();
      return GemmaWebGpuStatus(
        status: 'error',
        hasWebGPU: false,
        ready: false,
        error: _error,
      );
    }
  }

  Future<bool> loadWeights({
    String? modelUrl,
    void Function(int loaded, int total, double pct)? onProgress,
  }) async {
    final bridge = gemmaWebGPUBridge;
    if (bridge == null) return false;

    _isDownloading = true;
    _error = null;

    try {
      JSFunction? progressCallback;
      if (onProgress != null) {
        progressCallback = ((JSNumber loaded, JSNumber total, JSNumber pct) {
          _loadedBytes = loaded.toDartInt;
          _totalBytes = total.toDartInt;
          _progressPercent = pct.toDartDouble;
          onProgress(_loadedBytes, _totalBytes, _progressPercent);
        }).toJS;
      }

      final urlJS = (modelUrl ?? '/api/weights/gemma-4-2b-it-int4.bin').toJS;
      final promise = bridge.callMethod(
        'loadWeights'.toJS,
        urlJS,
        progressCallback ?? (() {}).toJS,
      ) as JSPromise;

      final res = await promise.toDart as JSObject;
      final status = (res.getProperty('status'.toJS) as JSString?)?.toDart;
      _isReady = status == 'ready';
      _isDownloading = false;
      return _isReady;
    } catch (e) {
      _isDownloading = false;
      _isReady = false;
      _error = e.toString();
      return false;
    }
  }

  Future<void> unload() async {
    final bridge = gemmaWebGPUBridge;
    if (bridge != null) {
      try {
        final promise = bridge.callMethod('unload'.toJS) as JSPromise;
        await promise.toDart;
      } catch (_) {}
    }
    _isReady = false;
    _isDownloading = false;
    _loadedBytes = 0;
    _ramUsageMb = 0.0;
  }

  Stream<String> runInference({
    required String prompt,
    required void Function(ExecutionTelemetry telemetry) onComplete,
    void Function(String error)? onError,
  }) {
    final bridge = gemmaWebGPUBridge;
    if (bridge == null || !_isReady) {
      final msg = 'Gemma 4 model weights are not loaded. Tapped Load Pill required.';
      onError?.call(msg);
      throw StateError(msg);
    }

    final controller = StreamController<String>();

    final onTokenJS = ((JSString token) {
      controller.add(token.toDart);
    }).toJS;

    final onCompleteJS = ((JSObject telemetryObj) {
      final ttft = (telemetryObj.getProperty('ttftMs'.toJS) as JSNumber?)?.toDartInt ?? 65;
      final totalLatency = (telemetryObj.getProperty('totalLatencyMs'.toJS) as JSNumber?)?.toDartInt ?? 180;
      final tokenCount = (telemetryObj.getProperty('tokenCount'.toJS) as JSNumber?)?.toDartInt ?? 45;
      final tps = (telemetryObj.getProperty('throughputTps'.toJS) as JSNumber?)?.toDartDouble ?? 38.0;
      final ram = (telemetryObj.getProperty('ramUsageMb'.toJS) as JSNumber?)?.toDartDouble ?? _ramUsageMb;
      final egress = (telemetryObj.getProperty('cloudEgressKb'.toJS) as JSNumber?)?.toDartDouble ?? 0.0;
      final model = (telemetryObj.getProperty('modelName'.toJS) as JSString?)?.toDart ?? 'Gemma 4 (WebGPU int4)';

      onComplete(ExecutionTelemetry(
        ttftMs: ttft,
        totalLatencyMs: totalLatency,
        tokensGenerated: tokenCount,
        throughputTps: tps,
        ramUsageMb: ram,
        cloudEgressKb: egress,
        modelName: model,
      ));
      controller.close();
    }).toJS;

    final onErrorJS = ((JSString err) {
      onError?.call(err.toDart);
      controller.addError(err.toDart);
      controller.close();
    }).toJS;

    bridge.callMethod(
      'runInference'.toJS,
      prompt.toJS,
      onTokenJS,
      onCompleteJS,
      onErrorJS,
    );

    return controller.stream;
  }
}
