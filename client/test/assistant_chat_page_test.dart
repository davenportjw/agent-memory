import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:client/models/message.dart';
import 'package:client/models/routing_decision.dart';
import 'package:client/services/switching_router_service.dart';
import 'package:client/services/local_execution_manager.dart';
import 'package:client/services/firebase_ai_policy_service.dart';
import 'package:client/views/center_workspace.dart';
import 'package:client/views/widgets/intent_pill_widget.dart';

void main() {
  group('Assistant Chat Page & Model / Firebase Routing Validation Suite', () {
    late LocalExecutionManager edgeManager;
    late SwitchingRouterService routerService;
    late FirebaseAiPolicyService policyService;

    setUp(() async {
      edgeManager = LocalExecutionManager();
      await edgeManager.init();

      policyService = FirebaseAiPolicyService();
      routerService = SwitchingRouterService(policyService: policyService);
    });

    Widget createAssistantHarness({
      required List<ChatMessage> messages,
      required RouterModeOverride currentOverride,
      required void Function(RouterModeOverride) onOverrideChanged,
      required Future<void> Function(String) onSendMessage,
      void Function()? onClearChat,
      void Function()? onToggleDrawer,
      bool isDrawerOpen = false,
      bool isGenerating = false,
    }) {
      return MaterialApp(
        home: Scaffold(
          body: CenterWorkspace(
            messages: messages,
            isGenerating: isGenerating,
            currentOverride: currentOverride,
            onOverrideChanged: onOverrideChanged,
            onSendMessage: onSendMessage,
            selectedPill: null,
            onPillSelected: (_) {},
            onToggleDrawer: onToggleDrawer ?? () {},
            isDrawerOpen: isDrawerOpen,
            onClearChat: onClearChat ?? () {},
            edgeManager: edgeManager,
            onEngineChanged: (engine) => edgeManager.selectedEngine = engine,
          ),
        ),
      );
    }

    testWidgets('Validates Assistant Chat Page renders messages, header pills, and input controls', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final messages = [
        ChatMessage(
          id: 'msg-1',
          sender: MessageSender.user,
          text: 'What are the active Firebase routing policies?',
          timestamp: DateTime.now().subtract(const Duration(seconds: 30)),
        ),
        ChatMessage(
          id: 'msg-2',
          sender: MessageSender.assistant,
          text: 'The Firebase AI policy defines priority-ranked rules for edge vs cloud routing.',
          timestamp: DateTime.now().subtract(const Duration(seconds: 25)),
          intentPill: IntentPillData(
            id: 'pill-1',
            intentLabel: 'Local Conversation',
            justificationRule: 'RULE_EDGE_DEFAULT_FAST',
            memoryDelta: 'Working session initialized',
            route: ExecutionRoute.EDGE_LOCAL,
            ruleId: 'RULE_EDGE_DEFAULT_FAST',
            timestamp: DateTime.now(),
          ),
          telemetry: const ExecutionTelemetry(
            ttftMs: 28,
            totalLatencyMs: 42,
            tokensGenerated: 16,
            throughputTps: 38.0,
            ramUsageMb: 1420.0,
            cloudEgressKb: 0.0,
            modelName: 'Gemma 4 int4 (LiteRT)',
          ),
        ),
      ];

      await tester.pumpWidget(createAssistantHarness(
        messages: messages,
        currentOverride: RouterModeOverride.auto,
        onOverrideChanged: (_) {},
        onSendMessage: (_) async {},
      ));
      await tester.pumpAndSettle();

      // Verify Header elements
      expect(find.text('ASSISTANT SHELL // DUAL EDGE-CLOUD WORKSPACE'), findsOneWidget);
      expect(find.text('DEV TOOL'), findsOneWidget);

      // Verify Messages rendered
      expect(find.text('What are the active Firebase routing policies?'), findsOneWidget);
      expect(find.textContaining('The Firebase AI policy defines priority-ranked rules'), findsOneWidget);

      // Verify Intent Pill in Assistant Turn
      expect(find.byType(IntentPillWidget), findsOneWidget);
      expect(find.text('Local Conversation'), findsOneWidget);

      // Verify Input TextField is ready
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('Validates model changing and routing policy overrides via Header Pill Popup', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      RouterModeOverride activeOverride = RouterModeOverride.auto;

      await tester.pumpWidget(StatefulBuilder(
        builder: (context, setState) {
          return createAssistantHarness(
            messages: const [],
            currentOverride: activeOverride,
            onOverrideChanged: (newOverride) {
              setState(() => activeOverride = newOverride);
            },
            onSendMessage: (_) async {},
          );
        },
      ));
      await tester.pumpAndSettle();

      // Open the Execution Routing PopupMenu
      final routingPillFinder = find.byKey(const Key('btn_execution_routing_pill'));
      expect(routingPillFinder, findsOneWidget);
      await tester.tap(routingPillFinder);
      await tester.pumpAndSettle();

      // Verify Menu Items for both Routing Policies and Engine Targets
      expect(find.text('Auto Policy (Dynamic Routing)'), findsOneWidget);
      expect(find.text('Enforce On-Device Local'), findsOneWidget);
      expect(find.text('Enforce Cloud Flash'), findsOneWidget);
      expect(find.text('Simulate Offline Network'), findsOneWidget);
      expect(find.text('Gemma 4 int4 (LiteRT/WebGPU)'), findsOneWidget);
      expect(find.text('Gemini Nano (Chrome Built-in AI)'), findsOneWidget);

      // Select Cloud Gemini 3.8 Flash Override
      await tester.tap(find.text('Enforce Cloud Flash'));
      await tester.pumpAndSettle();

      expect(activeOverride, equals(RouterModeOverride.enforceCloudFlash));

      // Re-open and select On-Device Engine Target: Gemini Nano
      await tester.tap(find.byKey(const Key('btn_execution_routing_pill')));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Gemini Nano (Chrome Built-in AI)'));
      await tester.pumpAndSettle();

      expect(edgeManager.selectedEngine, equals(EdgeEngineSelection.geminiNano));
    });

    testWidgets('Validates Firebase routing policy evaluation (RULE_STRICT_PRIVACY vs RULE_CONTEXT_LIMIT_EXCEEDED)', (tester) async {
      // 1. Verify RULE_STRICT_PRIVACY enforces EDGE_LOCAL when PII is present
      final piiEval = routerService.evaluateRoute(
        prompt: 'Please send credentials to security@davenport.corp immediately.',
      );
      expect(piiEval.route, equals(ExecutionRoute.EDGE_LOCAL));
      expect(piiEval.ruleId, equals('RULE_STRICT_PRIVACY'));
      expect(piiEval.requiresRedaction, isTrue);
      expect(piiEval.detectedPii.any((p) => p.contains('security@davenport.corp')), isTrue);

      // 2. Verify RULE_CONTEXT_LIMIT_EXCEEDED escalates to CLOUD_ESCALATE
      final tokenLimit = policyService.maxEdgeTokens;
      expect(tokenLimit, equals(4096));

      final hugePrompt = 'Token budget test: ' + ('reasoning ' * 4200);
      final hugeEval = routerService.evaluateRoute(prompt: hugePrompt);
      expect(hugeEval.route, equals(ExecutionRoute.CLOUD_ESCALATE));
      expect(hugeEval.ruleId, equals('RULE_CONTEXT_LIMIT_EXCEEDED'));

      // 3. Verify standard fast prompt routes to EDGE_LOCAL via RULE_EDGE_DEFAULT_FAST
      final fastEval = routerService.evaluateRoute(prompt: 'Hello, what is the server status?');
      expect(fastEval.route, equals(ExecutionRoute.EDGE_LOCAL));
      expect(fastEval.ruleId, equals('RULE_EDGE_DEFAULT_FAST'));
    });

    testWidgets('Validates typing sensitive prompt triggers live PII draft alert in Assistant workspace', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createAssistantHarness(
        messages: const [],
        currentOverride: RouterModeOverride.auto,
        onOverrideChanged: (_) {},
        onSendMessage: (_) async {},
      ));
      await tester.pumpAndSettle();

      // Enter sensitive text into prompt field
      await tester.enterText(find.byType(TextField), 'My token is AIzaSyD9x82j19f8x7a6b5c4d3e2f1 and contact is bob@corp.local');
      await tester.pumpAndSettle();

      // Verify PII Draft Alert Banner appears above input
      expect(find.textContaining('Privacy Guard Active'), findsOneWidget);
      expect(find.textContaining('zero cloud egress'), findsOneWidget);
    });
  });
}
