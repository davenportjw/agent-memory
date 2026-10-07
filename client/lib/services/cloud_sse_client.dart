import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/routing_decision.dart';
import '../models/edge_memory_bundle.dart';

class CloudSseClient {
  String baseUrl;
  bool isConnected = true;

  CloudSseClient({String? baseUrl})
      : baseUrl = baseUrl ??
            const String.fromEnvironment(
              'CLOUD_BACKEND_URL',
              defaultValue:
                  'https://distributed-ai-backend-834476222725.us-central1.run.app',
            );

  void setBaseUrl(String url) {
    baseUrl = url;
  }

  Stream<String> streamCloudCompletion({
    required String prompt,
    List<MemoryAnchor> injectedAnchors = const [],
    void Function(ExecutionTelemetry telemetry)? onComplete,
    void Function(dynamic error)? onError,
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
      String currentEvent = 'message';
      bool hasStreamError = false;
      String? streamErrorMessage;

      await for (final line in streamedResponse.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())) {
        final trimmed = line.trim();
        if (trimmed.isEmpty) {
          // Reset event name for the next SSE message
          currentEvent = 'message';
          continue;
        }

        // SSE comment, ignore
        if (trimmed.startsWith(':')) {
          continue;
        }

        // SSE event type specification (e.g. event: error)
        if (trimmed.startsWith('event:')) {
          currentEvent = trimmed.substring(6).trim();
          continue;
        }

        // SSE data field
        if (trimmed.startsWith('data:')) {
          final dataPayload = trimmed.substring(5).trim();

          // End of stream indicator
          if (dataPayload == '[DONE]') {
            break;
          }

          // Error event handling
          if (currentEvent == 'error') {
            hasStreamError = true;
            try {
              final parsed = jsonDecode(dataPayload) as Map<String, dynamic>;
              streamErrorMessage = parsed['error'] as String? ?? dataPayload;
            } catch (_) {
              streamErrorMessage = dataPayload;
            }
            break;
          }

          try {
            final parsed = jsonDecode(dataPayload) as Map<String, dynamic>;
            if (parsed.containsKey('error') && parsed['error'] != null) {
              hasStreamError = true;
              streamErrorMessage = parsed['error'].toString();
              break;
            }

            final textChunk = parsed['text'] as String? ?? '';
            if (textChunk.isNotEmpty) {
              if (ttftMs == null) {
                ttftMs = DateTime.now().difference(startTime).inMilliseconds;
              }
              tokenCount += textChunk.split(RegExp(r'\s+')).where((s) => s.isNotEmpty).length;
              fullResponseBuffer.write(textChunk);
              yield textChunk;
            }
          } catch (_) {
            // Only yield non-JSON payload if it is genuine text and not protocol syntax
            if (currentEvent != 'error' && !trimmed.startsWith('event:') && dataPayload != '[DONE]') {
              if (ttftMs == null) {
                ttftMs = DateTime.now().difference(startTime).inMilliseconds;
              }
              tokenCount++;
              yield dataPayload;
            }
          }
        }
      }

      client.close();

      if (hasStreamError) {
        final errText = streamErrorMessage ?? 'Cloud Run streaming inference error';
        throw Exception(errText);
      }

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

      if (onComplete != null) {
        onComplete(telemetry);
      }
    } catch (e) {
      if (onError != null) {
        onError(e);
      }
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
      if (data.containsKey('error') && data['error'] != null) {
        throw Exception('Cloud Run error: ${data['error']}');
      }
      return data['text'] as String? ?? '';
    } finally {
      client.close();
    }
  }
}

