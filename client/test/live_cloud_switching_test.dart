@Timeout(Duration(seconds: 90))
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

import '../lib/services/switching_router_service.dart';
import '../lib/models/routing_decision.dart';

void main() {
  runLiveCloudSwitchingTests(test, (cond, [msg = 'Assertion failed']) => expect(cond, isTrue, reason: msg));
}

void runLiveCloudSwitchingTests(
  void Function(String name, dynamic Function() body) register,
  void Function(bool condition, [String message]) expect,
) {
  final router = SwitchingRouterService();
  final cloudRunBaseUrl = Platform.environment['CLOUD_BACKEND_URL'] ??
      const String.fromEnvironment('CLOUD_BACKEND_URL', defaultValue: 'https://distributed-ai-backend-834476222725.us-central1.run.app');

  register('Router switches to EDGE_LOCAL for sensitive/PII prompt (0 KB egress)', () {
    final result = router.evaluateRoute(
      prompt: 'Contact alice@corp.internal or call 555-0199 about SQLite indexing',
    );
    expect(result.route == ExecutionRoute.EDGE_LOCAL, 'Expected EDGE_LOCAL route');
    expect(result.detectedPii.length == 2, 'Expected 2 PII entities detected');
    expect(result.requiresRedaction, 'Expected redaction required');
  });

  register('Router switches to CLOUD_ESCALATE for complex cross-session reasoning', () {
    final result = router.evaluateRoute(
      prompt: 'How does our decision on int4 quantization reconcile with the historical context of memory budgets?',
    );
    expect(result.route == ExecutionRoute.CLOUD_ESCALATE, 'Expected CLOUD_ESCALATE route');
    expect(result.requiresDurableMemories, 'Expected durable memories required');
  });

  register('Router switches to CLOUD_ESCALATE when prompt exceeds 4096 tokens', () {
    final longPrompt = 'Architecture design analysis: ' + ('word ' * 4200);
    final result = router.evaluateRoute(prompt: longPrompt);
    expect(result.route == ExecutionRoute.CLOUD_ESCALATE, 'Expected CLOUD_ESCALATE for >4096 tokens');
    expect(result.ruleId == 'RULE_CONTEXT_LIMIT_EXCEEDED', 'Expected RULE_CONTEXT_LIMIT_EXCEEDED');
  });

  register('Live Cloud Run probe: /api/memory/bundle returns valid JSON under 50 KB budget', () async {
    final client = HttpClient();
    final request = await client.getUrl(Uri.parse('$cloudRunBaseUrl/api/memory/bundle'));
    final response = await request.close();
    expect(response.statusCode == 200, 'Expected HTTP 200 from live bundle endpoint');

    final body = await response.transform(utf8.decoder).join();
    final jsonMap = jsonDecode(body) as Map<String, dynamic>;
    expect(jsonMap.containsKey('bundle_version'), 'Bundle missing bundle_version');
    expect(jsonMap.containsKey('size_bytes'), 'Bundle missing size_bytes');

    final sizeBytes = jsonMap['size_bytes'] as int;
    expect(sizeBytes < 51200, 'Bundle exceeded 50 KB budget: $sizeBytes bytes');
    client.close();
  });

  register('Live Cloud Run probe: /api/chat triggers Gemini 3.8 Flash escalation', () async {
    final client = HttpClient();
    final request = await client.postUrl(Uri.parse('$cloudRunBaseUrl/api/chat'));
    request.headers.set('Content-Type', 'application/json');
    request.write(jsonEncode({
      'prompt': 'Summarize the durable memory consolidation policy in one sentence.',
      'session_id': 'sess_dart_e2e_probe'
    }));

    final response = await request.close();
    expect(response.statusCode == 200, 'Expected HTTP 200 from live chat endpoint');

    final body = await response.transform(utf8.decoder).join();
    final jsonMap = jsonDecode(body) as Map<String, dynamic>;
    expect(jsonMap['model'] == 'gemini-3.8-flash', 'Expected model gemini-3.8-flash');
    expect(jsonMap['route'] == 'CLOUD_ESCALATE', 'Expected route CLOUD_ESCALATE');
    expect((jsonMap['text'] as String).isNotEmpty, 'Response text was empty');
    client.close();
  });

  register('Live Cloud Run probe: /api/eval/benchmark scores completion via LLM judge', () async {
    final client = HttpClient();
    final request = await client.postUrl(Uri.parse('$cloudRunBaseUrl/api/eval/benchmark'));
    request.headers.set('Content-Type', 'application/json');
    request.write(jsonEncode({
      'benchmark_id': 'BENCH_01_PII_EXTRACT',
      'prompt': "Extract action items and redact contact details: 'Contact alice@example.org or call 555-0199 to finalize the SQLite WASM caching migration before Friday.'",
      'edge_completion': "- Finalize SQLite WASM caching migration\n- Meet the Friday deadline\n- Contact [REDACTED_EMAIL] or call [REDACTED_PHONE] for access credentials\n\nPrivacy Guarantee: Executed 100% on-device with 0 bytes cloud egress.",
      'ttft_ms': 31,
      'latency_ms': 48
    }));

    final response = await request.close();
    expect(response.statusCode == 200, 'Expected HTTP 200 from live eval benchmark');

    final body = await response.transform(utf8.decoder).join();
    final jsonMap = jsonDecode(body) as Map<String, dynamic>;
    expect(jsonMap['judge_model'] == 'gemini-3.8-flash', 'Expected judge gemini-3.8-flash');
    expect(jsonMap['passed'] == true, 'Expected benchmark to pass');
    expect((jsonMap['overall_score'] as num) >= 4.0, 'Expected score >= 4.0');
    client.close();
  });
}
