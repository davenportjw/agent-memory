import 'package:flutter_test/flutter_test.dart';
import 'package:client/models/edge_memory_architecture.dart';
import 'package:client/services/local_memory_service.dart';

void main() {
  group('Edge Memory Boot Architecture Suite', () {
    late LocalMemoryService memoryService;

    setUp(() {
      memoryService = LocalMemoryService();
    });

    test('Pattern 1: On-Load (The Boot State) loads only minimal context footprint', () async {
      // 1. Initial state before boot
      expect(memoryService.bootState.isBooted, isFalse);

      // 2. Spin up edge agent
      final bootState = await memoryService.bootEdgeAgent();

      expect(bootState.isBooted, isTrue);
      expect(bootState.bootDurationMs, greaterThanOrEqualTo(0));
      expect(bootState.isWithinBootBudget, isTrue);

      // Master Index ("The Map") footprint verification
      final index = bootState.masterIndex;
      expect(index.totalTopicCount, 8);
      expect(index.calculatedSizeBytes, lessThan(3000)); // Highly compressed < 3 KB

      // Core Directives & Persona inspection
      final directives = bootState.coreDirectives;
      expect(directives.personaName, 'Khar-Drak Grand Council Envoy');
      expect(directives.staticDirectives.length, greaterThanOrEqualTo(3));
      expect(directives.allocatedTokens, 256);

      // Local Environmental State inspection
      final env = bootState.environmentalState;
      expect(env.batteryLevel, 0.88);
      expect(env.networkStatus, 'ONLINE_WIFI');
      expect(env.currentSector, 'khar_drak_gates');
      expect(env.hardwareEngine, anyOf(contains('Android LiteRT'), contains('Apple Silicon')));
    });

    test('Pattern 2: Conditionally (Just-In-Time Context) executes tool fetch and task-bound eviction', () async {
      await memoryService.bootEdgeAgent();

      // Ensure 'undercity_sluice_bypass' is not cached initially
      final entryBefore = memoryService.masterIndex.entries
          .firstWhere((e) => e.topicId == 'undercity_sluice_bypass');
      expect(entryBefore.isCachedLocally, isFalse);
      expect(memoryService.localTopicCache.containsKey('undercity_sluice_bypass'), isFalse);

      // 1. Tool-Triggered Fetching: Agent requests historical topic
      final fetchedTopic = await memoryService.fetchMemoryTopic('undercity_sluice_bypass');

      expect(fetchedTopic.topicId, 'undercity_sluice_bypass');
      expect(fetchedTopic.fullContent, contains('Subterranean Aqueduct'));
      expect(memoryService.localTopicCache.containsKey('undercity_sluice_bypass'), isTrue);

      final entryAfter = memoryService.masterIndex.entries
          .firstWhere((e) => e.topicId == 'undercity_sluice_bypass');
      expect(entryAfter.isCachedLocally, isTrue);

      // 2. Task-Bound Context Window: Inject into context during task, drop upon completion
      bool wasContextExpandedDuringTask = false;
      int taskContextTokensObserved = 0;

      final taskResult = await memoryService.executeTaskWithBoundContext<String>(
        taskId: 'task-sluice-routing-01',
        taskName: 'Reroute Lower Aqueduct Slag Valve',
        topicIds: ['undercity_sluice_bypass'],
        action: () async {
          final activeContext = memoryService.activeTaskContext;
          expect(activeContext, isNotNull);
          expect(activeContext!.isEvicted, isFalse);
          wasContextExpandedDuringTask = true;
          taskContextTokensObserved = activeContext.totalContextTokens;
          expect(taskContextTokensObserved, greaterThan(256)); // Base (256) + Topic tokens
          return 'Valve sluice safely bypassed';
        },
      );

      expect(taskResult, 'Valve sluice safely bypassed');
      expect(wasContextExpandedDuringTask, isTrue);

      // Context must be evicted immediately upon task completion to keep context small
      expect(memoryService.activeTaskContext?.isEvicted, isTrue);
      expect(memoryService.activeTaskContext?.totalContextTokens, 256); // Dropped back to base
    });

    test('Pattern 3: Pre-Emptive Caching (The Predictive Load) caches context on state shift', () async {
      await memoryService.bootEdgeAgent();

      // Ensure 'volcanic_slag_thresholds' is not in local cache initially
      expect(memoryService.localTopicCache.containsKey('volcanic_slag_thresholds'), isFalse);

      // Simulate a state shift: User enters Subterranean Foundry
      final prefetchEvent = await memoryService.triggerStatePrefetch(
        stateTrigger: 'Location Shift: Arrived at Subterranean Foundry',
        topicIds: ['volcanic_slag_thresholds'],
      );

      expect(prefetchEvent.status, 'PREFETCHED');
      expect(prefetchEvent.targetTopicIds, contains('volcanic_slag_thresholds'));
      expect(memoryService.localTopicCache.containsKey('volcanic_slag_thresholds'), isTrue);

      // Subsequent query hits local cache with 0ms network latency
      final stopwatch = Stopwatch()..start();
      final topic = await memoryService.fetchMemoryTopic('volcanic_slag_thresholds');
      stopwatch.stop();

      expect(topic.topicId, 'volcanic_slag_thresholds');
      expect(stopwatch.elapsedMilliseconds, lessThan(10)); // Local cache hit
    });

    test('Pattern 4: Asynchronous Syncs (The Morning After) applies 3 AM delta and invalidates cache', () async {
      await memoryService.bootEdgeAgent();

      // Pre-cache 'iron_vanguard_ciphers' so we can verify its cache invalidation
      await memoryService.fetchMemoryTopic('iron_vanguard_ciphers');
      expect(memoryService.localTopicCache.containsKey('iron_vanguard_ciphers'), isTrue);

      // Cloud Dream Daemon finishes overnight consolidation and pushes a 3 AM delta
      final now = DateTime.now();
      final delta = DreamDeltaUpdate(
        deltaId: 'delta-dream-0300am-v5',
        syncTimestamp: now,
        source: 'Cloud Dream Daemon (Overnight Consolidation 03:00 AM)',
        newMasterIndexVersion: 5,
        updatedEntries: [
          MasterIndexEntry(
            topicId: 'iron_vanguard_ciphers',
            title: 'Iron Vanguard Valve Ciphers [Consolidated v5]',
            category: 'TACTICAL_SECURITY',
            summaryScope: 'Updated emergency bypass codes following Foundry breach reconciliation.',
            byteSize: 3600,
            tokenEstimate: 400,
            versionHash: 'hash-ivg-v5-reconciled',
            isCachedLocally: false, // Marked for fresh fetch
            lastUpdated: now,
          ),
        ],
        deprecatedTopicIds: ['old_deprecated_subterranean_lore'],
        conflictsResolvedCount: 3,
        invalidatedCachedTopicIds: ['iron_vanguard_ciphers'],
      );

      final result = await memoryService.applyDreamDeltaSync(customDelta: delta);

      expect(result.newMasterIndexVersion, 5);
      expect(memoryService.masterIndex.version, 5);

      // Invalidation: previously cached file must be invalidated/purged from local topic cache
      expect(memoryService.localTopicCache.containsKey('iron_vanguard_ciphers'), isFalse);

      // Master Index entry must be updated with consolidated title and hash
      final updatedEntry = memoryService.masterIndex.entries
          .firstWhere((e) => e.topicId == 'iron_vanguard_ciphers');
      expect(updatedEntry.title, contains('[Consolidated v5]'));
      expect(updatedEntry.versionHash, 'hash-ivg-v5-reconciled');
      expect(updatedEntry.isCachedLocally, isFalse);

      // History log recorded
      expect(memoryService.dreamSyncHistory.length, 1);
      expect(memoryService.dreamSyncHistory.first.conflictsResolvedCount, 3);
    });
  });
}
