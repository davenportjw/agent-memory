import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../lib/models/routing_decision.dart';
import '../lib/models/edge_memory_bundle.dart';
import '../lib/services/lorecraft_service.dart';
import '../lib/services/switching_router_service.dart';
import '../lib/services/gemma_edge_service.dart';
import '../lib/services/local_execution_manager.dart';
import '../lib/services/cloud_sse_client.dart';
import '../lib/services/local_memory_service.dart';
import '../lib/views/right_drawer_panel.dart';
import '../lib/views/shell_layout.dart';

void main() {
  group('Contextual & LoreCraft Studio Inspector Tests', () {
    late LoreCraftService loreService;
    late List<MemoryAnchor> sampleAnchors;

    setUp(() {
      final router = SwitchingRouterService();
      final edge = LocalExecutionManager(gemmaService: GemmaEdgeService());
      final cloud = CloudSseClient();
      final memory = LocalMemoryService();
      loreService = LoreCraftService(
        routerService: router,
        edgeManager: edge,
        cloudClient: cloud,
        memoryService: memory,
      );

      sampleAnchors = const [
        MemoryAnchor(
          anchorId: 'anchor-01',
          key: 'Quantization Policy',
          category: 'SYSTEM_ARCHITECTURE',
          distilledContext: 'Enforce int4 on Gemma 4 for < 1.3 GB RAM headroom.',
        ),
        MemoryAnchor(
          anchorId: 'anchor-02',
          key: 'Edge Bundle Budget',
          category: 'SECURITY_POLICY',
          distilledContext: 'Compact memory bundle strictly <= 50 KB.',
        ),
        MemoryAnchor(
          anchorId: 'anchor-lore-01',
          key: 'Aether-Core Resonance',
          category: 'WORLD_CANON',
          distilledContext: 'Subterranean Aether-Core operates at 432 Hz.',
        ),
        MemoryAnchor(
          anchorId: 'anchor-lore-02',
          key: 'Sluice Gate Ciphers',
          category: 'TACTICAL_SECURITY',
          distilledContext: 'Shadow Syndicate holds encrypted bypass keys.',
        ),
      ];
    });

    testWidgets('Game World Mode: Renders living studio inspector with NPC, world anchors, and canon arbiter', (tester) async {
      tester.view.physicalSize = const Size(1200, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RightDrawerPanel(
              selectedPill: null,
              latestTelemetry: null,
              recalledAnchors: sampleAnchors,
              circuitBreakerState: CircuitBreakerState.CLOSED,
              consecutiveFailures: 0,
              onResetCircuitBreaker: () {},
              onToggleDrawer: () {},
              loreService: loreService,
              currentDestination: ShellNavDestination.loreCraftStudio,
            ),
          ),
        ),
      );

      // Verify Header
      expect(find.text('LORECRAFT STUDIO INSPECTOR'), findsOneWidget);
      expect(find.text('🏰 Game World'), findsOneWidget);
      expect(find.text('⚙️ AI Engine'), findsOneWidget);

      // Verify Section 1: Active NPC & Strategic Context
      expect(find.text('ACTIVE NPC & STRATEGIC CONTEXT'), findsOneWidget);
      expect(find.text('Gideon Stonehand'), findsOneWidget);
      expect(find.textContaining('Ironforge Foundry'), findsOneWidget);

      // Verify Section 2: World State Anchors (Should contain World Canon, NOT Quantization Policy)
      expect(find.text('ACTIVE WORLD STATE ANCHORS (< 50 KB)'), findsOneWidget);
      expect(find.text('#vanguard_iron_rations'), findsOneWidget);
      expect(find.text('Quantization Policy'), findsNothing);

      // Verify Section 3: Gameplay Performance & Memory Budget Meter
      expect(find.text('GAMEPLAY PERFORMANCE & MEMORY BUDGET'), findsOneWidget);
      expect(find.text('EDGE LORE BUNDLE METER'), findsOneWidget);
      expect(find.textContaining('50.0 KB'), findsOneWidget);
      expect(find.textContaining('ms'), findsWidgets);

      // Verify Section 4: Canon & Voice Arbiter Card
      expect(find.text('CANON & VOICE ARBITER SCORECARD'), findsOneWidget);
      expect(find.textContaining('Cloud Run: CLOSED'), findsOneWidget);
    });

    testWidgets('AI Engine Mode: Renders contextual inspector with engine runtime anchors and circuit breaker', (tester) async {
      tester.view.physicalSize = const Size(1200, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RightDrawerPanel(
              selectedPill: null,
              latestTelemetry: null,
              recalledAnchors: sampleAnchors,
              circuitBreakerState: CircuitBreakerState.CLOSED,
              consecutiveFailures: 0,
              onResetCircuitBreaker: () {},
              onToggleDrawer: () {},
              loreService: loreService,
              currentDestination: ShellNavDestination.assistant,
            ),
          ),
        ),
      );

      // Verify Header in assistant mode
      expect(find.text('CONTEXTUAL INSPECTOR'), findsOneWidget);

      // Verify Section 1: Selected Intent Pill
      expect(find.text('SELECTED INTENT PILL DETAILS'), findsOneWidget);

      // Verify Section 2: Recalled Engine Memory Anchors (Should contain Quantization Policy)
      expect(find.text('RECALLED ENGINE MEMORY ANCHORS'), findsOneWidget);
      expect(find.text('#Quantization Policy'), findsOneWidget);

      // Verify Section 3: Execution Metrics
      expect(find.text('EXECUTION METRICS'), findsOneWidget);

      // Verify Section 4: Network Circuit Breaker
      expect(find.text('NETWORK CIRCUIT BREAKER'), findsOneWidget);
      expect(find.text('State: CLOSED (Healthy)'), findsOneWidget);
    });

    testWidgets('Segmented Mode Switcher: Taps toggle seamlessly between Game World and AI Engine modes', (tester) async {
      tester.view.physicalSize = const Size(1200, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RightDrawerPanel(
              selectedPill: null,
              latestTelemetry: null,
              recalledAnchors: sampleAnchors,
              circuitBreakerState: CircuitBreakerState.CLOSED,
              consecutiveFailures: 0,
              onResetCircuitBreaker: () {},
              onToggleDrawer: () {},
              loreService: loreService,
              currentDestination: ShellNavDestination.assistant,
            ),
          ),
        ),
      );

      // Starts in AI Engine mode
      expect(find.text('CONTEXTUAL INSPECTOR'), findsOneWidget);
      expect(find.text('#Quantization Policy'), findsOneWidget);

      // Tap Game World tab
      await tester.tap(find.byKey(const Key('tab_inspector_game_world')));
      await tester.pumpAndSettle();

      // Now in Game World mode
      expect(find.text('LORECRAFT STUDIO INSPECTOR'), findsOneWidget);
      expect(find.text('Gideon Stonehand'), findsOneWidget);
      expect(find.text('#vanguard_iron_rations'), findsOneWidget);
      expect(find.text('#Quantization Policy'), findsNothing);

      // Tap AI Engine tab to return
      await tester.tap(find.byKey(const Key('tab_inspector_ai_engine')));
      await tester.pumpAndSettle();

      // Back in AI Engine mode
      expect(find.text('CONTEXTUAL INSPECTOR'), findsOneWidget);
      expect(find.text('#Quantization Policy'), findsOneWidget);
    });

    testWidgets('Affordance: onToggleDrawer callback fires when collapse button tapped', (tester) async {
      tester.view.physicalSize = const Size(1200, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      bool drawerToggled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RightDrawerPanel(
              selectedPill: null,
              latestTelemetry: null,
              recalledAnchors: sampleAnchors,
              circuitBreakerState: CircuitBreakerState.CLOSED,
              consecutiveFailures: 0,
              onResetCircuitBreaker: () {},
              onToggleDrawer: () => drawerToggled = true,
              loreService: loreService,
            ),
          ),
        ),
      );

      await tester.tap(find.byTooltip('Collapse Inspector'));
      await tester.pumpAndSettle();

      expect(drawerToggled, isTrue);
    });

    testWidgets('Affordance: Reset circuit breaker fires when tripped in Game World mode', (tester) async {
      tester.view.physicalSize = const Size(1200, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      bool resetFired = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RightDrawerPanel(
              selectedPill: null,
              latestTelemetry: null,
              recalledAnchors: sampleAnchors,
              circuitBreakerState: CircuitBreakerState.OPEN,
              consecutiveFailures: 3,
              onResetCircuitBreaker: () => resetFired = true,
              onToggleDrawer: () {},
              loreService: loreService,
              currentDestination: ShellNavDestination.loreCraftStudio,
            ),
          ),
        ),
      );

      final resetBtn = find.byKey(const Key('btn_reset_circuit_breaker_game'));
      expect(resetBtn, findsOneWidget);
      await tester.tap(resetBtn);
      await tester.pumpAndSettle();

      expect(resetFired, isTrue);
    });
  });
}
