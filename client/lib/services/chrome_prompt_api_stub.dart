import 'dart:async';
import '../models/routing_decision.dart';
import 'chrome_prompt_status.dart';

class ChromePromptApiImpl {
  bool get isAvailable => false;
  bool get isActive => false;
  bool get needsDownload => false;
  bool get isDownloading => false;
  String get modelName => 'Gemini Nano (Chrome Built-in AI)';
  String? get errorMessage => null;
  String? get instructions => null;

  Future<ChromePromptStatus> checkAvailability() async {
    return const ChromePromptStatus(
      isAvailable: false,
      isDownloaded: false,
      status: 'unsupported_platform',
      modelName: 'Gemini Nano (Chrome Built-in AI)',
      contextWindow: 0,
      errorMessage:
          'Chrome Built-in AI requires Google Chrome 131+ with chrome://flags/#prompt-api enabled and >= 22 GB free disk space.',
    );
  }

  Future<bool> createLanguageModel({void Function(int loaded, int total)? onProgress}) async {
    return false;
  }

  Stream<String> streamPrompt({
    required String prompt,
    required void Function(ExecutionTelemetry telemetry) onComplete,
    void Function(String error)? onError,
  }) {
    onError?.call(
      'Chrome Prompt API is only supported in Google Chrome web runtime.',
    );
    throw UnsupportedError(
      'Chrome Prompt API is only supported in Google Chrome web runtime.',
    );
  }
}
