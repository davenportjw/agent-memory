import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:client/models/edge_memory_architecture.dart';
import 'package:client/models/episodic_turn.dart';
import 'package:client/models/memory_node.dart';
import 'package:client/services/local_memory_service.dart';
import 'package:client/theme/sepia_theme.dart';
import 'package:client/views/memory_lifecycle_studio.dart';
import 'package:client/views/widgets/memory_pattern_tester.dart';
import 'package:client/views/widgets/memory_tree_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget buildTestWidget(LocalMemoryService service) {
    return MaterialApp(
      theme: SepiaTheme.lightTheme,
      home: Scaffold(
        body: MemoryLifecycleStudio(
          memoryService: service,
        ),
      ),
    );
  }

  group('Memory Pane Actions E2E & Data Movement Suite', () {
    late LocalMemoryService memoryService;

    setUp(() {
      memoryService = LocalMemoryService();
    });

    testWidgets('Test Suite 1: Consolidate Queue drains pending turns into durable graph and updates diff tree', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1400, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      // 1. Seed 2 episodic turns into ingestion queue
      final turn1 = EpisodicTurn(
        id: 'ep-queue-001',
        sessionId: 'test-session-live',
        timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
        userPrompt: 'Extract tactical action items: Reinforce Sluice Gate 4B before twilight',
        modelResponse: '1. Action: Fortify sluice bulkhead\n2. Target: Sluice Gate 4B',
        route: 'EDGE_LOCAL',
        modelName: 'Gemma 4 int4',
        latencyMs: 88,
        ttftMs: 34,
        isPiiSanitized: true,
        entitiesExtracted: const [
          ExtractedEntity(entityType: 'LOCATION', entityValue: 'Sluice Gate 4B', confidence: 0.99),
          ExtractedEntity(entityType: 'TACTICAL', entityValue: 'Fortify bulkhead', confidence: 0.95),
        ],
        status: 'UNCONSOLIDATED',
      );

      final turn2 = EpisodicTurn(
        id: 'ep-queue-002',
        sessionId: 'test-session-live',
        timestamp: DateTime.now().subtract(const Duration(minutes: 2)),
        userPrompt: 'Security protocol update: Shadow Syndicate requires 12% grain tribute at Docks',
        modelResponse: 'Confirmed treaty treaty clause: 12% tribute acknowledged.',
        route: 'CLOUD_ESCALATE',
        modelName: 'Gemini 3.8 Flash',
        latencyMs: 240,
        ttftMs: 92,
        isPiiSanitized: true,
        entitiesExtracted: const [
          ExtractedEntity(entityType: 'FACTION', entityValue: 'Shadow Syndicate', confidence: 0.97),
          ExtractedEntity(entityType: 'TREATY_CLAUSE', entityValue: '12% grain tribute', confidence: 0.94),
        ],
        status: 'UNCONSOLIDATED',
      );

      memoryService.clearIngestionQueue();
      memoryService.seedIngestionTurn(turn1);
      memoryService.seedIngestionTurn(turn2);
      expect(memoryService.ingestionQueue.length, 2);

      final initialDurableCount = memoryService.durableNodes.length;

      // 2. Pump MemoryLifecycleStudio
      await tester.pumpWidget(buildTestWidget(memoryService));
      await tester.pumpAndSettle();

      // 3. Verify initial state shows pending turns in Diff Tree
      final consolidateButtonFinder = find.byKey(const Key('diff-action-consolidate'));
      expect(consolidateButtonFinder, findsOneWidget);
      final consolidateBtn = tester.widget<ElevatedButton>(consolidateButtonFinder);
      expect(consolidateBtn.onPressed, isNotNull);
      expect(find.textContaining('Consolidate 2 Turns'), findsOneWidget);
      expect(find.textContaining('2 pending'), findsWidgets);

      // 4. Tap diff-action-consolidate button
      await tester.tap(consolidateButtonFinder);
      await tester.pumpAndSettle();

      // 5. Verify queue drained to 0, durable nodes incremented, tree reflects clean state
      expect(memoryService.ingestionQueue.length, 0);
      expect(memoryService.durableNodes.length, greaterThan(initialDurableCount));

      // Tree summary updates to 0 pending and button disables
      expect(find.textContaining('0 pending'), findsWidgets);
      final updatedBtn = tester.widget<ElevatedButton>(consolidateButtonFinder);
      expect(updatedBtn.onPressed, isNull);
    });

    testWidgets('Test Suite 2: Repack Edge Bundle updates anchors and recalculates size budget', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1400, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestWidget(memoryService));
      await tester.pumpAndSettle();

      final initialAnchorsCount = memoryService.activeEdgeBundle?.anchors.length ?? 0;
      final initialSizeBytes = memoryService.activeEdgeBundle?.sizeBytes ?? 0;

      // 1. Mutate durable nodes by injecting a brand new architectural node
      final newNode = DurableKnowledgeNode(
        id: 'node-arch-metal',
        entityName: 'Apple Silicon Metal Engine',
        category: 'SYSTEM_ARCHITECTURE',
        summary: 'Enforce Metal GPU compute pipeline on macOS for high-speed int4 Gemma execution.',
        confidence: 0.99,
        relations: const [],
        sourceEpisodeIds: ['ep-arch-metal-01'],
        resolvedContradictions: const [],
        contradictionRecords: const [],
        lastUpdated: DateTime.now(),
      );
      memoryService.addDurableNode(newNode);
      await tester.pumpAndSettle();

      // 2. Trigger repack via diff-action-repack
      final repackFinder = find.byKey(const Key('diff-action-repack'));
      expect(repackFinder, findsOneWidget);
      await tester.tap(repackFinder);
      await tester.pumpAndSettle();

      // 3. Verify edge bundle contains updated anchors and recalculated sizeBytes
      final updatedBundle = memoryService.activeEdgeBundle;
      expect(updatedBundle, isNotNull);
      expect(updatedBundle!.anchors.length, greaterThan(initialAnchorsCount));
      expect(updatedBundle.anchors.any((a) => a.key == 'Apple Silicon Metal Engine'), isTrue);
      expect(updatedBundle.sizeBytes, greaterThan(initialSizeBytes));

      // 4. Verify budget meter reflects the new size
      final expectedMeterText = '${updatedBundle.sizeKb.toStringAsFixed(1)} KB / 50.0 KB';
      expect(find.textContaining(expectedMeterText), findsWidgets);
      expect(find.textContaining('Edge memory bundle repacked'), findsOneWidget);
    });

    testWidgets('Test Suite 3: Prune Working Context reduces turns, computes freed bytes, and enforces lower bound', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1400, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      // Default state has 2 turns
      expect(memoryService.workingContext.length, 2);

      await tester.pumpWidget(buildTestWidget(memoryService));
      await tester.pumpAndSettle();

      // Verify Cell 1 initially reports 2 turns loaded
      expect(find.text('2'), findsWidgets);

      final pruneButtonFinder = find.byKey(const Key('diff-action-prune'));
      expect(pruneButtonFinder, findsOneWidget);

      // 1. First Tap: Prune context
      await tester.tap(pruneButtonFinder);
      await tester.pumpAndSettle();

      // Working context reduced to 1 turn, freed bytes > 0, and Cell 1 shows 1
      expect(memoryService.workingContext.length, 1);
      expect(find.textContaining('Pruned working context: freed'), findsOneWidget);

      // Dismiss prior snackbar so consecutive minimum notification renders immediately
      ScaffoldMessenger.of(tester.element(pruneButtonFinder)).clearSnackBars();
      await tester.pumpAndSettle();

      // 2. Second Tap: Tap again when already at minimum (1 turn)
      await tester.tap(pruneButtonFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Context remains 1 turn, and SnackBar alerts minimum reached
      expect(memoryService.workingContext.length, 1);
      expect(find.text('ℹ️ Working context is already at minimum (1 turn retained).'), findsOneWidget);
    });

    testWidgets('Test Suite 4: Topic Eviction & Async Prefetch updates cache flags and handles offline error gracefully', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1400, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      // 1. Seed topic 'lore-factions' as locally cached
      memoryService.seedTopicEntry(
        topicId: 'lore-factions',
        title: 'Khar-Drak Factions & Political Treaties',
        category: 'TACTICAL_SECURITY',
        summaryScope: 'Treaties and standing alliances across Iron Vanguard, Shadow Syndicate, and Arcane Enclave.',
        isCachedLocally: true,
      );

      await tester.pumpWidget(buildTestWidget(memoryService));
      await tester.pumpAndSettle();

      // Verify initial cached state and evict button is visible
      final evictKey = const Key('topic-evict-lore-factions');
      final prefetchKey = const Key('topic-prefetch-lore-factions');

      expect(find.byKey(evictKey), findsOneWidget);
      expect(find.byKey(prefetchKey), findsNothing);
      expect(memoryService.masterIndex.entries.firstWhere((e) => e.topicId == 'lore-factions').isCachedLocally, isTrue);

      // 2. Evict cached topic
      await tester.ensureVisible(find.byKey(evictKey));
      await tester.tap(find.byKey(evictKey));
      await tester.pumpAndSettle();

      // Verify isCachedLocally is false, button changes to prefetch, and SnackBar appears
      expect(memoryService.masterIndex.entries.firstWhere((e) => e.topicId == 'lore-factions').isCachedLocally, isFalse);
      expect(find.byKey(evictKey), findsNothing);
      expect(find.byKey(prefetchKey), findsOneWidget);
      expect(find.textContaining('evicted to cloud dream storage'), findsOneWidget);

      // Dismiss prior snackbar so prefetch notification renders cleanly
      ScaffoldMessenger.of(tester.element(find.byKey(prefetchKey))).clearSnackBars();
      await tester.pumpAndSettle();

      // 3. Tap prefetch button
      await tester.ensureVisible(find.byKey(prefetchKey));
      await tester.tap(find.byKey(prefetchKey));
      await tester.pumpAndSettle();

      // Verify isCachedLocally becomes true and button changes back to Evict
      expect(memoryService.masterIndex.entries.firstWhere((e) => e.topicId == 'lore-factions').isCachedLocally, isTrue);
      expect(find.byKey(evictKey), findsOneWidget);
      expect(find.byKey(prefetchKey), findsNothing);
      expect(find.textContaining('prefetched from cloud dream into local SQLite cache'), findsOneWidget);

      // 4. Test offline partition mode error handling
      // First evict again while online
      ScaffoldMessenger.of(tester.element(find.byKey(evictKey))).clearSnackBars();
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(evictKey));
      await tester.tap(find.byKey(evictKey));
      await tester.pumpAndSettle();
      expect(find.byKey(prefetchKey), findsOneWidget);

      // Activate offline partition
      memoryService.simulateOfflinePartition(true);
      await tester.pumpAndSettle();

      // Clear snackbars before offline attempt
      ScaffoldMessenger.of(tester.element(find.byKey(prefetchKey))).clearSnackBars();
      await tester.pumpAndSettle();

      // Attempt prefetch in offline partition mode
      await tester.ensureVisible(find.byKey(prefetchKey));
      await tester.tap(find.byKey(prefetchKey));
      await tester.pumpAndSettle();

      // Verify graceful error presentation via SnackBar without crashing
      expect(find.textContaining('Failed to prefetch topic "lore-factions"'), findsOneWidget);
      expect(find.textContaining('offline partition is active'), findsOneWidget);
      expect(memoryService.masterIndex.entries.firstWhere((e) => e.topicId == 'lore-factions').isCachedLocally, isFalse);
    });

    testWidgets('Test Suite 5: Contradiction Rollback & Edge Parity restores prior directive and auto-repacks bundle', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1400, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      // 1. Add durable node for SQLite Architecture
      final sqliteNode = DurableKnowledgeNode(
        id: 'node-arch-sqlite',
        entityName: 'SQLite Architecture',
        category: 'SYSTEM_ARCHITECTURE',
        summary: 'Use SQLite Default Journaling',
        confidence: 0.96,
        relations: const [],
        sourceEpisodeIds: ['ep-sqlite-init'],
        resolvedContradictions: const [],
        contradictionRecords: const [],
        lastUpdated: DateTime.now(),
      );
      memoryService.addDurableNode(sqliteNode);

      // 2. Inject a non-FP16 contradiction: directive "Enforce SQLite WAL Mode", prior "Use SQLite Default Journaling"
      memoryService.simulateInjectContradiction(
        'SQLite Architecture',
        'Enforce SQLite WAL Mode',
        'WAL mode optimizes concurrent reader performance on Apple Silicon local storage.',
      );

      await tester.pumpWidget(buildTestWidget(memoryService));
      await tester.pumpAndSettle();

      // 3. Verify contradiction node appears in Diff Tree
      final contradictionNodeFinder = find.textContaining('Contradiction Audit: Use SQLite Default Journaling');
      expect(contradictionNodeFinder, findsOneWidget);

      // 4. Tap the contradiction audit item to open details dialog
      await tester.ensureVisible(contradictionNodeFinder);
      await tester.tap(contradictionNodeFinder);
      await tester.pumpAndSettle();

      // Dialog is open; verify contents and "Revert Resolution" CTA
      expect(find.text('CONTRADICTION RESOLUTION AUDIT'), findsOneWidget);
      expect(find.textContaining('Enforce SQLite WAL Mode'), findsWidgets);
      final revertButtonFinder = find.text('Revert Resolution');
      expect(revertButtonFinder, findsOneWidget);

      // 5. Tap "Revert Resolution"
      await tester.tap(revertButtonFinder);
      await tester.pumpAndSettle();

      // 6. Verify summary restored to prior directive, record removed, and edge bundle auto-repacked
      final updatedNode = memoryService.durableNodes.firstWhere((n) => n.id == 'node-arch-sqlite');
      expect(updatedNode.summary, contains('Use SQLite Default Journaling'));
      expect(updatedNode.contradictionRecords, isEmpty);

      // Verify edge bundle has been repacked with the restored context
      final anchor = memoryService.activeEdgeBundle?.anchors.firstWhere((a) => a.key == 'SQLite Architecture');
      expect(anchor, isNotNull);
      expect(anchor!.distilledContext, contains('Use SQLite Default Journaling'));

      // In Diff Tree, contradiction audit trail node is now removed
      expect(find.textContaining('Contradiction Audit: Use SQLite Default Journaling'), findsNothing);
      expect(find.textContaining('Reverted to prior directive'), findsWidgets);
    });

    testWidgets('Test Suite 6: Simulator Bench (MemoryPatternTester) verifies all state mutations and baseline reset', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1400, 3200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestWidget(memoryService));
      await tester.pumpAndSettle();

      final testerCardFinder = find.byType(MemoryPatternTester);
      expect(testerCardFinder, findsOneWidget);

      // 1. Test "1. Inject Contradictory Directive"
      final injectBtn = find.text('1. Inject Contradictory Directive');
      await tester.ensureVisible(injectBtn);
      await tester.tap(injectBtn);
      await tester.pumpAndSettle();

      expect(memoryService.simulationLogs.first, contains('[Contradiction Injected]'));
      expect(find.textContaining('Conflict detected on "Quantization Policy"'), findsWidgets);

      // 2. Test "2. Stress 50 KB Bundle Budget"
      final budgetBtn = find.text('2. Stress 50 KB Bundle Budget');
      await tester.ensureVisible(budgetBtn);
      await tester.tap(budgetBtn);
      await tester.pumpAndSettle();

      expect(memoryService.activeEdgeBundle!.isWithinBudget, isFalse);
      expect(memoryService.activeEdgeBundle!.sizeBytes, greaterThan(51200));

      // Verify budget meter turns terracotta and reports OVER BUDGET
      expect(find.text('OVER BUDGET (> 50 KB)'), findsOneWidget);

      final meterTextFinder = find.textContaining('/ 50.0 KB');
      expect(meterTextFinder, findsWidgets);

      // 3. Test "3. Toggle Offline Partition"
      final toggleOfflineBtn = find.text('3. Toggle Offline Partition');
      await tester.ensureVisible(toggleOfflineBtn);
      await tester.tap(toggleOfflineBtn);
      await tester.pumpAndSettle();

      expect(memoryService.isOfflinePartition, isTrue);
      // Verify tree health node updates
      expect(find.text('Local Edge Partition Active (Airgapped)'), findsOneWidget);
      expect(find.text('PARTITIONED (OFFLINE)'), findsOneWidget);

      // 4. Test "Reset Baseline"
      final resetBtn = find.text('Reset Baseline');
      await tester.ensureVisible(resetBtn);
      await tester.tap(resetBtn);
      await tester.pumpAndSettle();

      // Verify baseline restoration
      expect(memoryService.isOfflinePartition, isFalse);
      expect(memoryService.activeEdgeBundle!.isWithinBudget, isTrue);
      expect(memoryService.durableNodes.length, 6);
      expect(memoryService.workingContext.length, 2);
      expect(memoryService.ingestionQueue.length, 1);

      // Verify Diff Tree health status reset to Online and budget preserved
      expect(find.text('Cloud Run Synchronization Online'), findsOneWidget);
      expect(find.text('BUDGET PRESERVED (< 50 KB)'), findsOneWidget);
    });
  });
}
