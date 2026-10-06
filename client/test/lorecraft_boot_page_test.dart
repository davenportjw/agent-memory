import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../lib/services/lorecraft_service.dart';
import '../lib/services/switching_router_service.dart';
import '../lib/services/gemma_edge_service.dart';
import '../lib/services/local_execution_manager.dart';
import '../lib/services/cloud_sse_client.dart';
import '../lib/services/local_memory_service.dart';
import '../lib/models/edge_memory_architecture.dart';
import '../lib/views/lorecraft_boot_page_view.dart';

void main() {
  group('LoreCraftBootPageView Architecture & TDD Suite', () {
    late LoreCraftService loreService;
    late LocalMemoryService memoryService;

    setUp(() {
      final router = SwitchingRouterService();
      final edge = LocalExecutionManager(gemmaService: GemmaEdgeService());
      final cloud = CloudSseClient();
      memoryService = LocalMemoryService();
      loreService = LoreCraftService(
        routerService: router,
        edgeManager: edge,
        cloudClient: cloud,
        memoryService: memoryService,
      );
    });

    testWidgets('Renders header, 4 memory pattern sections, and hardware telemetry', (tester) async {
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LoreCraftBootPageView(
              loreService: loreService,
              memoryService: memoryService,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Header & Subtitle
      expect(find.text('ENVOY EDGE BOOT ARCHITECTURE'), findsOneWidget);
      expect(find.textContaining('Minimum Context Hydration & Lifecycle Governance'), findsOneWidget);

      // Verify Hardware Telemetry
      expect(find.textContaining('BATTERY:'), findsWidgets);
      expect(find.textContaining('ONLINE'), findsWidgets);
      expect(find.textContaining('Apple Silicon'), findsWidgets);
      expect(find.textContaining('PASSED (< 4 KB)'), findsOneWidget);

      // Verify 4 Architecture Pattern Titles
      expect(find.textContaining('1. On-Load (The Boot State)'), findsOneWidget);
      expect(find.textContaining('2. Conditionally (Just-In-Time Context)'), findsOneWidget);
      expect(find.textContaining('3. Pre-Emptive Caching (The Predictive Load)'), findsOneWidget);
      expect(find.textContaining('4. Asynchronous Syncs (The "Morning After")'), findsOneWidget);

      // Verify Primary CTA
      expect(find.byKey(const Key('btn_enter_world')), findsOneWidget);
    });

    testWidgets('Pattern 2: Tool-triggered fetch loads topic into local cache', (tester) async {
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LoreCraftBootPageView(
              loreService: loreService,
              memoryService: memoryService,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final fetchBtnFinder = find.byKey(const Key('btn_fetch_topic_undercity_sluice_bypass'));
      await tester.ensureVisible(fetchBtnFinder);
      await tester.tap(fetchBtnFinder);
      await tester.pumpAndSettle();

      // Check topic is now cached in memoryService
      expect(memoryService.localTopicCache.containsKey('undercity_sluice_bypass'), isTrue);
      expect(find.textContaining('CACHED LOCALLY'), findsWidgets);
    });

    testWidgets('Pattern 2: Task-Bound context expands and evicts upon completion', (tester) async {
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LoreCraftBootPageView(
              loreService: loreService,
              memoryService: memoryService,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final execTaskFinder = find.byKey(const Key('btn_exec_task_context'));
      await tester.ensureVisible(execTaskFinder);
      await tester.tap(execTaskFinder);
      await tester.pumpAndSettle();

      expect(memoryService.activeTaskContext, isNotNull);
      expect(memoryService.activeTaskContext!.isEvicted, isTrue);
      expect(find.textContaining('EVICTED'), findsWidgets);
    });

    testWidgets('Pattern 3: State-based prefetch loads domain context on region shift', (tester) async {
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LoreCraftBootPageView(
              loreService: loreService,
              memoryService: memoryService,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final prefetchDocksFinder = find.byKey(const Key('btn_prefetch_docks'));
      await tester.ensureVisible(prefetchDocksFinder);
      await tester.tap(prefetchDocksFinder);
      await tester.pumpAndSettle();

      expect(memoryService.prefetchHistory.isNotEmpty, isTrue);
      expect(memoryService.prefetchHistory.first.stateTrigger, contains('Oakhaven Docks'));
      expect(find.textContaining('PREFETCH COMPLETE'), findsWidgets);
    });

    testWidgets('Pattern 4: Cloud Dream 3 AM delta sync updates Master Index and invalidates cache', (tester) async {
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      // Pre-cache iron_vanguard_ciphers to verify invalidation
      await memoryService.fetchMemoryTopic('iron_vanguard_ciphers');
      expect(memoryService.localTopicCache.containsKey('iron_vanguard_ciphers'), isTrue);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LoreCraftBootPageView(
              loreService: loreService,
              memoryService: memoryService,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final applyDreamFinder = find.byKey(const Key('btn_apply_dream_delta'));
      await tester.ensureVisible(applyDreamFinder);
      await tester.tap(applyDreamFinder);
      await tester.pumpAndSettle();

      expect(memoryService.masterIndex.version, greaterThanOrEqualTo(2));
      expect(memoryService.dreamSyncHistory.isNotEmpty, isTrue);
      expect(memoryService.localTopicCache.containsKey('iron_vanguard_ciphers'), isFalse);
      expect(find.textContaining('MASTER INDEX v5'), findsWidgets);
    });

    testWidgets('Primary CTA enters world and completes boot state', (tester) async {
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LoreCraftBootPageView(
              loreService: loreService,
              memoryService: memoryService,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(loreService.hasCompletedBoot, isFalse);

      final enterBtnFinder = find.byKey(const Key('btn_enter_world'));
      await tester.ensureVisible(enterBtnFinder);
      await tester.tap(enterBtnFinder);
      await tester.pumpAndSettle();

      expect(loreService.hasCompletedBoot, isTrue);
    });

    testWidgets('Interactive Environmental Sandbox: Toggling battery shifts policy to Low Power', (tester) async {
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LoreCraftBootPageView(
              loreService: loreService,
              memoryService: memoryService,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(memoryService.bootState.routingPolicy, equals(EdgeRoutingPolicy.fullPerformance));
      expect(find.textContaining('FULL PERFORMANCE'), findsWidgets);

      final batteryToggleFinder = find.byKey(const Key('btn_toggle_battery_sim'));
      await tester.ensureVisible(batteryToggleFinder);
      await tester.tap(batteryToggleFinder);
      await tester.pumpAndSettle();

      expect(memoryService.environmentalState.batteryLevel, lessThanOrEqualTo(0.15));
      expect(memoryService.bootState.routingPolicy, equals(EdgeRoutingPolicy.lowPower));
      expect(find.textContaining('LOW POWER'), findsWidgets);
    });

    testWidgets('Interactive Environmental Sandbox: Toggling network shifts policy to Offline Air-Gapped', (tester) async {
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LoreCraftBootPageView(
              loreService: loreService,
              memoryService: memoryService,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final netToggleFinder = find.byKey(const Key('btn_toggle_network_sim'));
      await tester.ensureVisible(netToggleFinder);
      await tester.tap(netToggleFinder);
      await tester.pumpAndSettle();

      expect(memoryService.environmentalState.networkStatus, equals('OFFLINE_AIRGAPPED'));
      expect(memoryService.bootState.routingPolicy, equals(EdgeRoutingPolicy.offlineAirgapped));
      expect(find.textContaining('AIR-GAPPED OFFLINE'), findsWidgets);
    });
  });
}
