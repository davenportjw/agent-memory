import 'package:flutter_test/flutter_test.dart';
import '../lib/models/routing_decision.dart';
import '../lib/services/switching_router_service.dart';

void main() {
  runSwitchingRouterTests(test, (cond, [msg = 'Assertion failed']) => expect(cond, isTrue, reason: msg));
}

void runSwitchingRouterTests(void Function(String name, void Function() body) test, void Function(bool condition, [String message]) expect) {
  test('Router: PII Detection routes to EDGE_LOCAL (RULE_STRICT_PRIVACY)', () {
    final router = SwitchingRouterService();
    final result = router.evaluateRoute(
      prompt: 'Contact alice@example.org or call 555-0199 for system credentials.',
    );

    expect(result.route == ExecutionRoute.EDGE_LOCAL, 'Expected EDGE_LOCAL route');
    expect(result.ruleId == 'RULE_STRICT_PRIVACY', 'Expected RULE_STRICT_PRIVACY');
    expect(result.requiresRedaction == true, 'Expected PII redaction requirement');
    expect(result.detectedPii.length >= 2, 'Expected at least 2 PII entities detected');
  });

  test('Router: PII Scrubber redacts emails, phones, SSNs, and API keys', () {
    final router = SwitchingRouterService();
    const raw = 'Send sk-1234567890abcdef1234567890abcdef to alice@test.com and 123-45-6789.';
    final scrubbed = router.scrubPii(raw);

    expect(!scrubbed.contains('alice@test.com'), 'Email was not redacted');
    expect(!scrubbed.contains('123-45-6789'), 'SSN was not redacted');
    expect(!scrubbed.contains('sk-1234567890abcdef1234567890abcdef'), 'API key was not redacted');
    expect(scrubbed.contains('[REDACTED_'), 'Sanitized placeholders missing');
  });

  test('Router: Long context (> 4096 tokens) escalates to CLOUD_ESCALATE', () {
    final router = SwitchingRouterService();
    final result = router.evaluateRoute(
      prompt: 'Summarize system requirements.',
      estimatedTokens: 5200,
    );

    expect(result.route == ExecutionRoute.CLOUD_ESCALATE, 'Expected CLOUD_ESCALATE');
    expect(result.ruleId == 'RULE_CONTEXT_LIMIT_EXCEEDED', 'Expected RULE_CONTEXT_LIMIT_EXCEEDED');
  });

  test('Router: Multi-hop and temporal synthesis routes to CLOUD_ESCALATE', () {
    final router = SwitchingRouterService();
    final result = router.evaluateRoute(
      prompt: 'How does our decision to enforce int4 quantization on Gemma 4 affect historical architecture alignment?',
    );

    expect(result.route == ExecutionRoute.CLOUD_ESCALATE, 'Expected CLOUD_ESCALATE');
    expect(result.ruleId == 'RULE_COMPLEXITY_ESCALATION', 'Expected RULE_COMPLEXITY_ESCALATION');
    expect(result.requiresDurableMemories == true, 'Expected durable memory injection');
  });

  test('Router: Offline network or tripped breaker triggers EDGE_FALLBACK', () {
    final router = SwitchingRouterService();
    final result = router.evaluateRoute(
      prompt: 'Perform routine check.',
      isNetworkOnline: false,
    );

    expect(result.route == ExecutionRoute.EDGE_FALLBACK, 'Expected EDGE_FALLBACK');
    expect(result.ruleId == 'RULE_CIRCUIT_BREAKER_OFFLINE', 'Expected RULE_CIRCUIT_BREAKER_OFFLINE');
  });

  test('Router: Fast single-turn query defaults to EDGE_LOCAL', () {
    final router = SwitchingRouterService();
    final result = router.evaluateRoute(
      prompt: 'Format this date string into ISO 8601.',
      estimatedTokens: 25,
      isNetworkOnline: true,
    );

    expect(result.route == ExecutionRoute.EDGE_LOCAL, 'Expected EDGE_LOCAL');
    expect(result.ruleId == 'RULE_EDGE_DEFAULT_FAST', 'Expected RULE_EDGE_DEFAULT_FAST');
  });

  test('Router: Manual mode overrides enforce target routes', () {
    final router = SwitchingRouterService();
    router.modeOverride = RouterModeOverride.enforceCloudFlash;
    final cloudResult = router.evaluateRoute(prompt: 'Quick test');
    expect(cloudResult.route == ExecutionRoute.CLOUD_ESCALATE, 'Expected CLOUD_ESCALATE on manual override');

    router.modeOverride = RouterModeOverride.enforceEdgeLocal;
    final edgeResult = router.evaluateRoute(prompt: 'Multi-hop temporal synthesis query');
    expect(edgeResult.route == ExecutionRoute.EDGE_LOCAL, 'Expected EDGE_LOCAL on manual override');
  });
}
