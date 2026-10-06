class ChromePromptStatus {
  final bool isAvailable;
  final bool isDownloaded;
  final String status;
  final String modelName;
  final int contextWindow;
  final String? errorMessage;
  final String? instructions;

  const ChromePromptStatus({
    required this.isAvailable,
    this.isDownloaded = false,
    required this.status,
    required this.modelName,
    this.contextWindow = 4096,
    this.errorMessage,
    this.instructions,
  });

  /// Indicates whether the model is downloaded and actively ready to run inference immediately
  bool get isActive =>
      isAvailable && (isDownloaded || status == 'available' || status == 'readily');

  /// Indicates whether the API is detected in Chrome (ready or downloadable)
  bool get isReady =>
      isAvailable &&
      (status == 'readily' ||
          status == 'available' ||
          status == 'after-download' ||
          status == 'downloadable');

  /// Model is available on device but needs LanguageModel.create() to download weights
  bool get needsDownload =>
      isAvailable &&
      !isActive &&
      (status == 'downloadable' || status == 'after-download');

  /// Model is actively downloading weights
  bool get isDownloading => status == 'downloading';

  @override
  String toString() =>
      'ChromePromptStatus(available: $isAvailable, active: $isActive, status: $status, model: $modelName)';
}
