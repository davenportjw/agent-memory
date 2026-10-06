import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

class CloudImageResult {
  final String imageBase64;
  final String mimeType;
  final String modelId;
  final String prompt;
  final int latencyMs;
  final int egressBytes;
  final String generatedAt;

  const CloudImageResult({
    required this.imageBase64,
    required this.mimeType,
    required this.modelId,
    required this.prompt,
    required this.latencyMs,
    required this.egressBytes,
    required this.generatedAt,
  });

  factory CloudImageResult.fromJson(Map<String, dynamic> json) {
    return CloudImageResult(
      imageBase64: json['image_base64'] as String? ?? '',
      mimeType: json['mime_type'] as String? ?? 'image/jpeg',
      modelId: json['model_id'] as String? ?? 'gemini-3.1-flash-lite-image',
      prompt: json['prompt'] as String? ?? '',
      latencyMs: (json['latency_ms'] as num?)?.toInt() ?? 0,
      egressBytes: (json['egress_bytes'] as num?)?.toInt() ?? 0,
      generatedAt: json['generated_at'] as String? ?? '',
    );
  }
}

/// CloudImageClient connects to the Cloud Run microservice endpoint `/api/image/generate`
/// powered by Vertex AI Nano Banana 2 Lite (gemini-3.1-flash-lite-image).
class CloudImageClient {
  String baseUrl;
  final http.Client _httpClient;

  CloudImageClient({
    String? baseUrl,
    http.Client? httpClient,
  })  : baseUrl = baseUrl ??
            const String.fromEnvironment(
              'CLOUD_BACKEND_URL',
              defaultValue: 'http://localhost:8080',
            ),
        _httpClient = httpClient ?? http.Client();

  Future<CloudImageResult> generateImage({
    required String prompt,
    List<String> contextAnchors = const [],
    String aspectRatio = '1:1',
    String? sessionId,
  }) async {
    final uri = Uri.parse('$baseUrl/api/image/generate');
    final body = jsonEncode({
      'prompt': prompt,
      'aspect_ratio': aspectRatio,
      'context_anchors': contextAnchors,
      'session_id': sessionId ?? 'sess_image_${DateTime.now().millisecondsSinceEpoch}',
    });

    final response = await _httpClient.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: body,
    );

    if (response.statusCode != 200) {
      String errMsg = 'HTTP ${response.statusCode}';
      try {
        final errJson = jsonDecode(response.body);
        if (errJson is Map && errJson.containsKey('error')) {
          errMsg = errJson['error'].toString();
        }
      } catch (_) {}
      throw Exception('Cloud image generation failed: $errMsg');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return CloudImageResult.fromJson(data);
  }
}
