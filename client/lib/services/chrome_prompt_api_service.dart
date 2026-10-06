import 'dart:async';
import '../models/routing_decision.dart';
import 'chrome_prompt_status.dart';
import 'chrome_prompt_api_stub.dart'
    if (dart.library.js_interop) 'chrome_prompt_api_web.dart';

export 'chrome_prompt_status.dart';

/// ChromePromptApiService
/// Direct integration with Google Chrome's Built-in AI (Prompt API / Gemini Nano).
/// Complies with STRICT NEVER MOCK DIRECTIVE:
/// - Real hardware availability detection via window.chromePromptAPIBridge
/// - Streams true tokens when Gemini Nano is enabled
/// - Returns true availability status and error messages to enable UI fallbacks
class ChromePromptApiService {
  final ChromePromptApiImpl _impl = ChromePromptApiImpl();

  bool get isAvailable => _impl.isAvailable;
  bool get isActive => _impl.isActive;
  bool get needsDownload => _impl.needsDownload;
  bool get isDownloading => _impl.isDownloading;
  String get modelName => _impl.modelName;
  String? get errorMessage => _impl.errorMessage;
  String? get instructions => _impl.instructions;

  /// Probes system readiness and returns whether Chrome Built-in AI is available
  Future<bool> checkAvailability() async {
    final status = await checkAvailabilityStatus();
    return status.isAvailable;
  }

  /// Inspect system readiness and return standardized status object
  Future<ChromePromptStatus> checkAvailabilityStatus() async {
    return await _impl.checkAvailability();
  }

  /// Creates language model instance in Chrome, triggering download of weights if needed.
  Future<bool> createLanguageModel({void Function(int loaded, int total)? onProgress}) async {
    return await _impl.createLanguageModel(onProgress: onProgress);
  }

  /// Stream prompt completions from Chrome Gemini Nano
  Stream<String> streamPrompt({
    required String prompt,
    required void Function(ExecutionTelemetry telemetry) onComplete,
    void Function(String error)? onError,
  }) {
    return _impl.streamPrompt(
      prompt: prompt,
      onComplete: onComplete,
      onError: onError,
    );
  }
}
