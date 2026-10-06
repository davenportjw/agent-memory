import 'dart:async';
import '../models/routing_decision.dart';

class GemmaWebGpuStatus {
  final String status;
  final bool ready;
  final bool isDownloading;
  final bool hasWebGPU;
  final String model;
  final int loadedBytes;
  final int totalBytes;
  final double progressPercent;
  final double ramUsageMb;
  final String? error;

  const GemmaWebGpuStatus({
    this.status = 'unsupported',
    this.ready = false,
    this.isDownloading = false,
    this.hasWebGPU = false,
    this.model = 'gemma-4-2b-it-int4',
    this.loadedBytes = 0,
    this.totalBytes = 1572864000,
    this.progressPercent = 0.0,
    this.ramUsageMb = 0.0,
    this.error,
  });
}

class GemmaWebGpuImpl {
  bool get hasWebGPU => false;
  bool get isReady => false;
  bool get isDownloading => false;
  int get loadedBytes => 0;
  int get totalBytes => 1572864000;
  double get progressPercent => 0.0;
  String? get error => 'WebGPU is not supported in non-web runtime.';

  Future<GemmaWebGpuStatus> init() async {
    return const GemmaWebGpuStatus(
      status: 'unsupported_platform',
      hasWebGPU: false,
      ready: false,
      error: 'Gemma WebGPU engine requires Chrome WebGPU runtime.',
    );
  }

  Future<bool> loadWeights({
    String? modelUrl,
    void Function(int loaded, int total, double pct)? onProgress,
  }) async {
    return false;
  }

  Future<void> unload() async {}

  Stream<String> runInference({
    required String prompt,
    required void Function(ExecutionTelemetry telemetry) onComplete,
    void Function(String error)? onError,
  }) {
    onError?.call('WebGPU is only supported in browser environment.');
    throw UnsupportedError('WebGPU is only supported in browser environment.');
  }
}
