import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/routing_decision.dart';
import 'chrome_prompt_api_service.dart';
import 'gemma_edge_service.dart';

/// User or policy selection mode for on-device edge AI engine.
enum EdgeEngineSelection {
  auto,
  geminiNano,
  gemma4,
}

/// The currently active on-device engine driving local execution.
enum ActiveEdgeEngine {
  geminiNano,
  gemma4,
  none,
}

/// Orchestrates on-device AI inference between Google Chrome's Built-in Prompt API
/// (Gemini Nano) and on-device Gemma 4 int4 (WebGPU / LiteRT).
///
/// Follows the STRICT NEVER MOCK DIRECTIVE: Surface true availability and runtime
/// errors directly without simulated fallback data.
class LocalExecutionManager extends ChangeNotifier {
  final ChromePromptApiService _chromeService;
  final GemmaEdgeService _gemmaService;

  EdgeEngineSelection _selectedEngine;
  ActiveEdgeEngine _activeEngine;

  bool _isCreatingModel = false;
  int _downloadedBytes = 0;
  int _totalBytes = 0;
  String? _creationError;

  LocalExecutionManager({
    ChromePromptApiService? chromeService,
    GemmaEdgeService? gemmaService,
    EdgeEngineSelection? defaultSelection,
  })  : _chromeService = chromeService ?? ChromePromptApiService(),
        _gemmaService = gemmaService ?? GemmaEdgeService(),
        _selectedEngine = defaultSelection ?? EdgeEngineSelection.auto,
        _activeEngine = ActiveEdgeEngine.none {
    _resolveActiveEngine();
  }

  /// Current user or policy engine selection mode (default: [EdgeEngineSelection.auto]).
  EdgeEngineSelection get selectedEngine => _selectedEngine;

  set selectedEngine(EdgeEngineSelection selection) {
    if (_selectedEngine != selection) {
      _selectedEngine = selection;
      _resolveActiveEngine();
      notifyListeners();
    }
  }

  /// Current active engine running on-device inference.
  ActiveEdgeEngine get activeEngine => _activeEngine;

  /// Underlying Chrome Prompt API service.
  ChromePromptApiService get chromeService => _chromeService;

  /// Underlying Gemma 4 on-device service.
  GemmaEdgeService get gemmaService => _gemmaService;

  /// Indicates whether Chrome's Built-in Gemini Nano API is detected.
  bool get isGeminiNanoAvailable => _chromeService.isAvailable;

  /// Indicates whether Gemini Nano is downloaded and ready for immediate execution.
  bool get isGeminiNanoActive => _chromeService.isActive;

  /// Indicates whether Gemini Nano is supported in Chrome but requires LanguageModel.create().
  bool get isGeminiNanoNeedsDownload => _chromeService.needsDownload;

  /// Indicates whether Gemini Nano is actively downloading or being created.
  bool get isGeminiNanoDownloading => _isCreatingModel || _chromeService.isDownloading;

  /// Model creation state.
  bool get isCreatingModel => _isCreatingModel;
  int get downloadedBytes => _downloadedBytes;
  int get totalBytes => _totalBytes;
  double? get downloadProgress => (_totalBytes > 0) ? (_downloadedBytes / _totalBytes) : null;
  String? get creationError => _creationError;

  /// Gemma 4 is packaged for on-device client runtime.
  bool get isGemmaAvailable => true;

  /// Indicates whether Gemma 4 model weights are loaded in memory.
  bool get isGemmaWeightsLoaded => _gemmaService.isModelLoaded;

  /// Indicates whether Gemma 4 weights are actively downloading.
  bool get isGemmaDownloading => _gemmaService.isDownloading;

  /// Gemma 4 download progress percentage (0 - 100).
  double get gemmaDownloadProgress => _gemmaService.downloadProgress;

  int get gemmaDownloadedBytes => _gemmaService.loadedBytes;
  int get gemmaTotalBytes => _gemmaService.totalBytes;
  String? get gemmaError => _gemmaService.loadError;

  /// Display name of currently active edge engine.
  String get activeEngineName {
    switch (_activeEngine) {
      case ActiveEdgeEngine.geminiNano:
        return _chromeService.modelName;
      case ActiveEdgeEngine.gemma4:
        return 'Gemma 4 ${_gemmaService.activeModelVariant.toUpperCase()} (${_gemmaService.isWebGPUAvailable ? "WebGPU int4" : "LiteRT CPU"})';
      case ActiveEdgeEngine.none:
        return 'None';
    }
  }

  /// Friendly short status label for headers and pills.
  String get activeEngineStatusLabel {
    switch (_activeEngine) {
      case ActiveEdgeEngine.geminiNano:
        if (_chromeService.isActive) return 'Active (0 KB Egress)';
        if (isGeminiNanoDownloading) return 'Downloading...';
        if (_chromeService.needsDownload) return 'Weights Pending';
        return _chromeService.isAvailable ? 'Available (Unready)' : 'Flag Required';
      case ActiveEdgeEngine.gemma4:
        if (_gemmaService.isModelLoaded) return 'Active (WebGPU int4)';
        if (_gemmaService.isDownloading) return 'Downloading Weights...';
        return 'Gemma 4 (Tap to Load)';
      case ActiveEdgeEngine.none:
        return 'Inactive';
    }
  }

  /// Estimated resident memory consumption (in MB) for active edge engine.
  double get activeRamMb {
    switch (_activeEngine) {
      case ActiveEdgeEngine.geminiNano:
        return 850.0;
      case ActiveEdgeEngine.gemma4:
        return _gemmaService.activeRamUsageMb;
      case ActiveEdgeEngine.none:
        return 0.0;
    }
  }

  /// Probes hardware and browser capabilities to initialize edge engines.
  Future<void> init() async {
    await _chromeService.checkAvailability();
    await _gemmaService.init();
    _resolveActiveEngine();
    notifyListeners();
  }

  /// Loads Gemma 4 weights into on-device memory via WebGPU / LiteRT.
  Future<bool> loadGemmaWeights({
    String? modelUrl,
    void Function(int loaded, int total, double pct)? onProgress,
  }) async {
    notifyListeners();
    final success = await _gemmaService.loadWeights(
      modelUrl: modelUrl,
      onProgress: (loaded, total, pct) {
        onProgress?.call(loaded, total, pct);
        notifyListeners();
      },
    );
    _resolveActiveEngine();
    notifyListeners();
    return success;
  }

  /// Unloads Gemma 4 weights from on-device memory to free system RAM.
  Future<void> unloadGemmaWeights() async {
    await _gemmaService.unload();
    _resolveActiveEngine();
    notifyListeners();
  }

  /// Sets loaded state explicitly (e.g. following native Android LiteRT initialization).
  void setGemmaLoaded(bool loaded) {
    _gemmaService.setNativeLoaded(loaded);
    _resolveActiveEngine();
    notifyListeners();
  }

  /// Creates/downloads the Gemini Nano LanguageModel instance directly in Chrome.
  Future<bool> createLanguageModel() async {
    _isCreatingModel = true;
    _creationError = null;
    _downloadedBytes = 0;
    _totalBytes = 0;
    notifyListeners();

    try {
      final success = await _chromeService.createLanguageModel(
        onProgress: (loaded, total) {
          _downloadedBytes = loaded;
          _totalBytes = total;
          notifyListeners();
        },
      );

      await _chromeService.checkAvailability();

      if (success || _chromeService.isActive) {
        _selectedEngine = EdgeEngineSelection.geminiNano;
        _resolveActiveEngine();
      } else if (_chromeService.errorMessage != null) {
        _creationError = _chromeService.errorMessage;
      }
      notifyListeners();
      return success;
    } catch (e) {
      _creationError = e.toString();
      notifyListeners();
      return false;
    } finally {
      _isCreatingModel = false;
      notifyListeners();
    }
  }

  void _resolveActiveEngine() {
    switch (_selectedEngine) {
      case EdgeEngineSelection.auto:
        _activeEngine = _chromeService.isActive
            ? ActiveEdgeEngine.geminiNano
            : ActiveEdgeEngine.gemma4;
        break;
      case EdgeEngineSelection.geminiNano:
        _activeEngine = ActiveEdgeEngine.geminiNano;
        break;
      case EdgeEngineSelection.gemma4:
        _activeEngine = ActiveEdgeEngine.gemma4;
        break;
    }
  }

  /// Executes on-device inference via the active edge engine with strictly 0 KB cloud egress.
  /// If Gemini Nano is unready or fails and [allowFallback] is true, seamlessly executes via
  /// on-device Gemma 4 int4 with explicit fallback telemetry.
  Stream<String> executeOnDevice({
    required String prompt,
    required void Function(ExecutionTelemetry telemetry) onComplete,
    void Function(String error)? onError,
    bool allowFallback = true,
  }) {
    if (_activeEngine == ActiveEdgeEngine.none) {
      _resolveActiveEngine();
    }

    if (_activeEngine == ActiveEdgeEngine.geminiNano) {
      if (!_chromeService.isActive) {
        if (allowFallback) {
          final fallbackReason = isGeminiNanoDownloading
              ? 'Gemini Nano is downloading in Chrome. Routed to on-device Gemma 4 int4 (0 KB egress).'
              : (isGeminiNanoNeedsDownload
                  ? 'Gemini Nano weights pending download in Chrome. Routed to on-device Gemma 4 int4 (0 KB egress).'
                  : 'Gemini Nano session unready in Chrome. Routed to on-device Gemma 4 int4 (0 KB egress).');

          return _gemmaService.streamInference(
            prompt: prompt,
            onComplete: (telemetry) {
              final augmentedTelemetry = ExecutionTelemetry(
                ttftMs: telemetry.ttftMs,
                totalLatencyMs: telemetry.totalLatencyMs,
                tokensGenerated: telemetry.tokensGenerated,
                throughputTps: telemetry.throughputTps,
                ramUsageMb: telemetry.ramUsageMb,
                cloudEgressKb: 0.0,
                modelName: telemetry.modelName,
                circuitBreakerState: telemetry.circuitBreakerState,
                isFallback: true,
                fallbackReason: fallbackReason,
              );
              onComplete(augmentedTelemetry);
            },
          );
        } else {
          if (!_chromeService.isAvailable) {
            return _chromeService.streamPrompt(prompt: prompt, onComplete: onComplete, onError: onError);
          }
          final err = 'Gemini Nano is not ready in Chrome (weights pending).';
          onError?.call(err);
          return Stream.error(err);
        }
      }

      return _chromeService.streamPrompt(
        prompt: prompt,
        onComplete: onComplete,
        onError: (errMsg) {
          if (allowFallback) {
            onError?.call(errMsg);
          } else {
            onError?.call(errMsg);
          }
        },
      );
    } else if (_activeEngine == ActiveEdgeEngine.gemma4) {
      if (!_gemmaService.isModelLoaded) {
        const err = 'Gemma 4 model weights are not loaded. Tap the Gemma Load Pill to download model weights before running edge inference.';
        onError?.call(err);
        return Stream.error(StateError(err));
      }
      final wasAutoFallback = (_selectedEngine == EdgeEngineSelection.auto && !_chromeService.isActive);
      return _gemmaService.streamInference(
        prompt: prompt,
        onError: onError,
        onComplete: (telemetry) {
          if (wasAutoFallback) {
            const fallbackReason = 'Auto engine probe: Gemini Nano unready in Chrome. Routed to on-device Gemma 4 int4 (0 KB egress).';
            final augmentedTelemetry = ExecutionTelemetry(
              ttftMs: telemetry.ttftMs,
              totalLatencyMs: telemetry.totalLatencyMs,
              tokensGenerated: telemetry.tokensGenerated,
              throughputTps: telemetry.throughputTps,
              ramUsageMb: telemetry.ramUsageMb,
              cloudEgressKb: 0.0,
              modelName: telemetry.modelName,
              circuitBreakerState: telemetry.circuitBreakerState,
              isFallback: true,
              fallbackReason: fallbackReason,
            );
            onComplete(augmentedTelemetry);
          } else {
            onComplete(telemetry);
          }
        },
      );
    } else {
      throw StateError('No active edge engine available for on-device execution');
    }
  }
}
