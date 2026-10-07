import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import '../lib/services/cloud_sse_client.dart';

void main() {
  group('CloudSseClient Protocol Parsing Tests', () {
    late HttpServer server;
    late String serverUrl;

    tearDown(() async {
      await server.close(force: true);
    });

    test('streamCloudCompletion: correctly handles event: error without leaking protocol tokens', () async {
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      serverUrl = 'http://${server.address.host}:${server.port}';

      server.listen((HttpRequest request) async {
        request.response.headers.contentType = ContentType('text', 'event-stream');
        request.response.headers.set('Cache-Control', 'no-cache');

        // Write an SSE error event frame
        request.response.write('event: error\n');
        request.response.write('data: {"error": "Resource exhausted: 429 Quota Exceeded"}\n\n');
        await request.response.flush();
        await request.response.close();
      });

      final client = CloudSseClient(baseUrl: serverUrl);
      final receivedTokens = <String>[];
      String? caughtError;
      bool onErrorCalled = false;

      try {
        final stream = client.streamCloudCompletion(
          prompt: 'Hello',
          onError: (err) {
            onErrorCalled = true;
            caughtError = err.toString();
          },
        );

        await for (final token in stream) {
          receivedTokens.add(token);
        }
      } catch (e) {
        caughtError ??= e.toString();
      }

      // 1. Verify that NO protocol tokens like "event: error" leaked into the token stream
      expect(receivedTokens, isEmpty, reason: 'event: error must never leak into speech tokens');

      // 2. Verify that onError was called and error contains quota exceeded message
      expect(onErrorCalled, isTrue);
      expect(caughtError, contains('429 Quota Exceeded'));
    });

    test('streamCloudCompletion: successfully decodes standard data chunks and ignores comments and [DONE]', () async {
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      serverUrl = 'http://${server.address.host}:${server.port}';

      server.listen((HttpRequest request) async {
        request.response.headers.contentType = ContentType('text', 'event-stream');

        // Comment
        request.response.write(': keep-alive\n\n');
        // Valid chunks
        request.response.write('data: {"text": "Iron "}\n\n');
        request.response.write('data: {"text": "and "}\n\n');
        request.response.write('data: {"text": "fire."}\n\n');
        // Done marker
        request.response.write('data: [DONE]\n\n');
        await request.response.flush();
        await request.response.close();
      });

      final client = CloudSseClient(baseUrl: serverUrl);
      final receivedTokens = <String>[];
      bool completed = false;

      final stream = client.streamCloudCompletion(
        prompt: 'Hello',
        onComplete: (telemetry) {
          completed = true;
        },
      );

      await for (final token in stream) {
        receivedTokens.add(token);
      }

      expect(receivedTokens.join(''), equals('Iron and fire.'));
      expect(completed, isTrue);
    });
  });
}
