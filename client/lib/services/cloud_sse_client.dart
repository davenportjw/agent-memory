import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/routing_decision.dart';
import '../models/edge_memory_bundle.dart';

class CloudSseClient {
  String baseUrl = const String.fromEnvironment(
    'CLOUD_BACKEND_URL',
    defaultValue: 'http://localhost:8080',
  );
  bool isConnected = true;

  Stream<String> streamCloudCompletion({
    required String prompt,
    required List<MemoryAnchor> injectedAnchors,
    required void Function(ExecutionTelemetry telemetry) onComplete,
    required void Function(dynamic error) onError,
  }) async* {
    final startTime = DateTime.now();
    int? ttftMs;

    try {
      final client = http.Client();
      final uri = Uri.parse('$baseUrl/api/chat');
      final requestBody = jsonEncode({
        'prompt': prompt,
        'session_id': 'sess_client_runtime_${DateTime.now().millisecondsSinceEpoch}',
        'injected_anchors': injectedAnchors.map((a) => a.key).toList(),
      });

      final request = http.Request('POST', uri)
        ..headers['Content-Type'] = 'application/json'
        ..headers['Accept'] = 'text/event-stream, application/json'
        ..body = requestBody;

      final streamedResponse = await client.send(request);

      if (streamedResponse.statusCode != 200) {
        throw Exception('Cloud Run returned HTTP ${streamedResponse.statusCode}');
      }

      var tokenCount = 0;
      final fullResponseBuffer = StringBuffer();

      await for (final line in streamedResponse.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())) {
        if (ttftMs == null) {
          ttftMs = DateTime.now().difference(startTime).inMilliseconds;
        }

        if (line.isEmpty) continue;

        String rawJson = line;
        if (line.startsWith('data: ')) {
          rawJson = line.substring(6).trim();
        }

        try {
          final parsed = jsonDecode(rawJson) as Map<String, dynamic>;
          final textChunk = parsed['text'] as String? ?? '';
          if (textChunk.isNotEmpty) {
            tokenCount += textChunk.split(RegExp(r'\s+')).where((s) => s.isNotEmpty).length;
            fullResponseBuffer.write(textChunk);
            yield textChunk;
          }
        } catch (_) {
          // If response was not JSON SSE, yield raw text chunk directly
          tokenCount++;
          yield line;
        }
      }

      client.close();

      final totalDurationMs = DateTime.now().difference(startTime).inMilliseconds;
      final durationSeconds = totalDurationMs > 0 ? (totalDurationMs / 1000.0) : 0.1;
      final tps = double.parse((tokenCount / durationSeconds).toStringAsFixed(1));
      final egressKb = double.parse(((requestBody.length) / 1024.0).toStringAsFixed(2));

      final telemetry = ExecutionTelemetry(
        ttftMs: ttftMs ?? totalDurationMs,
        totalLatencyMs: totalDurationMs,
        tokensGenerated: tokenCount,
        throughputTps: tps,
        ramUsageMb: 45.0,
        cloudEgressKb: egressKb,
        modelName: 'Gemini 3.8 Flash (Cloud Run)',
        circuitBreakerState: CircuitBreakerState.CLOSED,
      );

      onComplete(telemetry);
    } catch (e) {
      onError(e);
      rethrow;
    }
  }

  /// Sends a direct non-streaming JSON request to Cloud Run (/api/chat) powered by Gemini 3.8 Flash.
  Future<String> sendPrompt({
    required String prompt,
    String? systemInstruction,
    List<String> injectedAnchors = const [],
    String? sessionId,
  }) async {
    final client = http.Client();
    try {
      final uri = Uri.parse('$baseUrl/api/chat');
      final requestBody = jsonEncode({
        'prompt': prompt,
        'system_instruction': systemInstruction ?? '',
        'session_id': sessionId ?? 'sess_arbiter_${DateTime.now().millisecondsSinceEpoch}',
        'injected_anchors': injectedAnchors,
        'stream': false,
      });

      final response = await client.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: requestBody,
      );

      if (response.statusCode != 200) {
        throw Exception('Cloud Run returned HTTP ${response.statusCode}: ${response.body}');
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return data['text'] as String? ?? '';
    } finally {
      client.close();
    }
  }
}

