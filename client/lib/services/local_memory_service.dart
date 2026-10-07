import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../models/episodic_turn.dart';
import '../models/memory_node.dart';
import '../models/edge_memory_bundle.dart';
import '../models/memory_tree_node.dart';
import '../models/edge_memory_architecture.dart';

class LocalMemoryService {
  final List<void Function()> _listeners = [];

  void addListener(void Function() listener) => _listeners.add(listener);
  void removeListener(void Function() listener) => _listeners.remove(listener);

  void notifyListeners() {
    for (final l in List<void Function()>.from(_listeners)) {
      l();
    }
  }
  // 1. Working Context turns (Online local loop)
  final List<EpisodicTurn> _workingContext = [];

  // 2. Cloud Ingestion Queue (pending offline consolidation)
  final List<EpisodicTurn> _ingestionQueue = [];

  // 3. Durable Knowledge Graph nodes (Cloud consolidated state)
  final List<DurableKnowledgeNode> _durableNodes = [];

  // 4. Compact Edge Memory Bundle (< 50 KB)
  CompactEdgeMemoryBundle? _activeEdgeBundle;

  // 5. Four-Stage Edge Memory Architecture State
  late AgentBootState _bootState;
  late MasterIndex _masterIndex;
  late LocalEnvironmentalState _environmentalState;
  late CorePersonaDirectives _coreDirectives;
  final Map<String, MemoryTopicFile> _localTopicCache = {};
  TaskBoundContext? _activeTaskContext;
  final List<PrefetchEvent> _prefetchHistory = [];
  final List<DreamDeltaUpdate> _dreamSyncHistory = [];
  String? _activePrefetchedSceneId;
  final List<String> _activeSceneTopicIds = [];

  bool _isConsolidating = false;
  bool _isOfflinePartition = false;
  final List<String> _simulationLogs = [];

  LocalMemoryService() {
    _initializeDefaultMemoryState();
  }

  bool _isUsingPlatformTelemetry = false;
  static const MethodChannel _androidChannel = MethodChannel('com.example.client/gemma_edge');

  bool get isOfflinePartition => _isOfflinePartition;
  List<String> get simulationLogs => List.unmodifiable(_simulationLogs);
  bool get isUsingPlatformTelemetry => _isUsingPlatformTelemetry;

  List<EpisodicTurn> get workingContext => List.unmodifiable(_workingContext);
  List<EpisodicTurn> get ingestionQueue => List.unmodifiable(_ingestionQueue);
  List<DurableKnowledgeNode> get durableNodes => List.unmodifiable(_durableNodes);
  CompactEdgeMemoryBundle? get activeEdgeBundle => _activeEdgeBundle;
  bool get isConsolidating => _isConsolidating;

  // Edge Memory Architecture Getters
  AgentBootState get bootState => _bootState;
  MasterIndex get masterIndex => _masterIndex;
  LocalEnvironmentalState get environmentalState => _environmentalState;
  CorePersonaDirectives get coreDirectives => _coreDirectives;
  Map<String, MemoryTopicFile> get localTopicCache => Map.unmodifiable(_localTopicCache);
  TaskBoundContext? get activeTaskContext => _activeTaskContext;
  List<PrefetchEvent> get prefetchHistory => List.unmodifiable(_prefetchHistory);
  List<DreamDeltaUpdate> get dreamSyncHistory => List.unmodifiable(_dreamSyncHistory);
  String? get activePrefetchedSceneId => _activePrefetchedSceneId;
  List<String> get activeSceneTopicIds => List.unmodifiable(_activeSceneTopicIds);

  /// Returns working context turns filtered by session source:
  /// - null or empty or 'ALL': all turns
  /// - 'LORECRAFT': turns belonging to the LoreCraft game ('lorecraft-session-01' or containing 'lorecraft')
  /// - 'ASSISTANT': turns belonging to assistant/system prompts (not containing 'lorecraft')
  List<EpisodicTurn> getWorkingContextForSource(String? sourceFilter) {
    if (sourceFilter == null || sourceFilter.isEmpty || sourceFilter == 'ALL') {
      return List.unmodifiable(_workingContext);
    }
    if (sourceFilter == 'LORECRAFT') {
      return _workingContext.where((t) => t.sessionId.toLowerCase().contains('lorecraft')).toList();
    }
    if (sourceFilter == 'ASSISTANT') {
      return _workingContext.where((t) => !t.sessionId.toLowerCase().contains('lorecraft')).toList();
    }
    return List.unmodifiable(_workingContext);
  }

  /// Returns ingestion queue turns filtered by session source
  List<EpisodicTurn> getIngestionQueueForSource(String? sourceFilter) {
    if (sourceFilter == null || sourceFilter.isEmpty || sourceFilter == 'ALL') {
      return List.unmodifiable(_ingestionQueue);
    }
    if (sourceFilter == 'LORECRAFT') {
      return _ingestionQueue.where((t) => t.sessionId.toLowerCase().contains('lorecraft')).toList();
    }
    if (sourceFilter == 'ASSISTANT') {
      return _ingestionQueue.where((t) => !t.sessionId.toLowerCase().contains('lorecraft')).toList();
    }
    return List.unmodifiable(_ingestionQueue);
  }

  int get loreCraftWorkingTurnsCount =>
      _workingContext.where((t) => t.sessionId.toLowerCase().contains('lorecraft')).length;

  int get assistantWorkingTurnsCount =>
      _workingContext.where((t) => !t.sessionId.toLowerCase().contains('lorecraft')).length;

  /// Classification predicate: returns true if a durable node belongs to LoreCraft game domain
  bool isLoreCraftNode(DurableKnowledgeNode node) {
    if (node.id.toLowerCase().contains('lore')) return true;
    final cat = node.category.toUpperCase();
    if (cat.contains('LORE') || cat == 'WORLD_CANON' || cat == 'TACTICAL_SECURITY') {
      return true;
    }
    if (node.sourceEpisodeIds.any((id) => id.toLowerCase().contains('lore'))) {
      return true;
    }
    return false;
  }

  /// Classification predicate: returns true if a durable node belongs to Assistant shell domain
  bool isAssistantNode(DurableKnowledgeNode node) => !isLoreCraftNode(node);

  /// Classification predicate: returns true if an edge anchor belongs to LoreCraft game domain
  bool isLoreCraftAnchor(MemoryAnchor anchor) {
    if (anchor.anchorId.toLowerCase().contains('lore')) return true;
    final cat = anchor.category.toUpperCase();
    if (cat.contains('LORE') || cat == 'WORLD_CANON' || cat == 'TACTICAL_SECURITY') {
      return true;
    }
    return false;
  }

  /// Classification predicate: returns true if an edge anchor belongs to Assistant shell domain
  bool isAssistantAnchor(MemoryAnchor anchor) => !isLoreCraftAnchor(anchor);

  /// Classification predicate: returns true if a topic entry belongs to LoreCraft game domain
  bool isLoreCraftTopic(MasterIndexEntry entry) {
    if (entry.topicId.toLowerCase().contains('lore')) return true;
    final cat = entry.category.toUpperCase();
    if (cat.contains('LORE') || cat == 'WORLD_CANON' || cat == 'TACTICAL_SECURITY' || cat == 'ARTIFACT_SCHEMATICS') {
      return true;
    }
    return false;
  }

  /// Classification predicate: returns true if a topic entry belongs to Assistant shell domain
  bool isAssistantTopic(MasterIndexEntry entry) => !isLoreCraftTopic(entry);

  /// Returns durable knowledge nodes filtered by source: 'ALL', 'LORECRAFT', or 'ASSISTANT'
  List<DurableKnowledgeNode> getDurableNodesForSource(String? sourceFilter) {
    if (sourceFilter == null || sourceFilter.isEmpty || sourceFilter == 'ALL') {
      return List.unmodifiable(_durableNodes);
    }
    if (sourceFilter == 'LORECRAFT') {
      return _durableNodes.where(isLoreCraftNode).toList();
    }
    if (sourceFilter == 'ASSISTANT') {
      return _durableNodes.where(isAssistantNode).toList();
    }
    return List.unmodifiable(_durableNodes);
  }

  /// Returns edge anchors filtered by source: 'ALL', 'LORECRAFT', or 'ASSISTANT'
  List<MemoryAnchor> getEdgeAnchorsForSource(String? sourceFilter) {
    final anchors = _activeEdgeBundle?.anchors ?? [];
    if (sourceFilter == null || sourceFilter.isEmpty || sourceFilter == 'ALL') {
      return List.unmodifiable(anchors);
    }
    if (sourceFilter == 'LORECRAFT') {
      return anchors.where(isLoreCraftAnchor).toList();
    }
    if (sourceFilter == 'ASSISTANT') {
      return anchors.where(isAssistantAnchor).toList();
    }
    return List.unmodifiable(anchors);
  }

  /// Returns master index topics filtered by source: 'ALL', 'LORECRAFT', or 'ASSISTANT'
  List<MasterIndexEntry> getMasterIndexEntriesForSource(String? sourceFilter) {
    if (sourceFilter == null || sourceFilter.isEmpty || sourceFilter == 'ALL') {
      return List.unmodifiable(_masterIndex.entries);
    }
    if (sourceFilter == 'LORECRAFT') {
      return _masterIndex.entries.where(isLoreCraftTopic).toList();
    }
    if (sourceFilter == 'ASSISTANT') {
      return _masterIndex.entries.where(isAssistantTopic).toList();
    }
    return List.unmodifiable(_masterIndex.entries);
  }

  /// Total count of memory items for LoreCraft (working turns + queue + durable nodes + anchors)
  int getLoreCraftItemsCount() =>
      loreCraftWorkingTurnsCount +
      getIngestionQueueForSource('LORECRAFT').length +
      getDurableNodesForSource('LORECRAFT').length +
      getEdgeAnchorsForSource('LORECRAFT').length;

  /// Total count of memory items for Assistant (working turns + queue + durable nodes + anchors)
  int getAssistantItemsCount() =>
      assistantWorkingTurnsCount +
      getIngestionQueueForSource('ASSISTANT').length +
      getDurableNodesForSource('ASSISTANT').length +
      getEdgeAnchorsForSource('ASSISTANT').length;

  /// Total count of all memory items
  int getAllItemsCount() =>
      _workingContext.length +
      _ingestionQueue.length +
      _durableNodes.length +
      (_activeEdgeBundle?.anchors.length ?? 0);

  /// Appends a new episodic turn to local working context
  void commitTurn(EpisodicTurn turn) {
    _workingContext.insert(0, turn);
    if (turn.route == 'CLOUD_ESCALATE' || turn.status == 'UNCONSOLIDATED') {
      _ingestionQueue.add(turn);
    }
    notifyListeners();
  }

  String baseUrl = const String.fromEnvironment(
    'CLOUD_BACKEND_URL',
    defaultValue: 'https://distributed-ai-backend-834476222725.us-central1.run.app',
  );

  void setBaseUrl(String url) {
    baseUrl = url;
    notifyListeners();
  }

  /// Trigger offline cloud consolidation via Gemini 3.8 Flash on Cloud Run
  Future<ConsolidationResult> triggerOfflineConsolidation() async {
    if (_isConsolidating) {
      return const ConsolidationResult(success: false, errorMessage: 'Consolidation already running');
    }
    _isConsolidating = true;
    notifyListeners();

    try {
      final client = http.Client();

      // Step 1: Ingest pending turns to Cloud Run
      for (final episode in _ingestionQueue) {
        final ingestUri = Uri.parse('$baseUrl/api/memory/ingest');
        final ingestRes = await client.post(
          ingestUri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(episode.toJson()),
        );
        if (ingestRes.statusCode != 200) {
          throw Exception('Backend /api/memory/ingest failed: ${ingestRes.statusCode} ${ingestRes.body}');
        }
        episode.status = 'CONSOLIDATED';
      }

      // Step 2: Trigger Gemini 3.8 Flash offline consolidation loop on Cloud Run
      // Pass session_id: '' so server consolidates across all active sessions
      final consolidateUri = Uri.parse('$baseUrl/api/memory/consolidate');
      final consolidateRes = await client.post(
        consolidateUri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'session_id': '',
          'auto_publish_bundle': true,
        }),
      );

      if (consolidateRes.statusCode != 200) {
        throw Exception('Backend /api/memory/consolidate failed: ${consolidateRes.statusCode} ${consolidateRes.body}');
      }

      final data = jsonDecode(consolidateRes.body) as Map<String, dynamic>;
      final consolidatedNodes = (data['nodes'] as List<dynamic>?) ??
          (data['consolidated_nodes'] as List<dynamic>?) ??
          [];
      final turnsConsolidated = (data['consolidated_turns'] as num?)?.toInt() ?? _ingestionQueue.length;
      final nodesUpdatedCount = (data['nodes_updated'] as num?)?.toInt() ?? consolidatedNodes.length;

      for (final item in consolidatedNodes) {
        final m = item as Map<String, dynamic>;
        final node = DurableKnowledgeNode.fromJson(m);
        final existingIdx = _durableNodes.indexWhere((n) => n.entityName.toLowerCase() == node.entityName.toLowerCase());

        if (existingIdx >= 0) {
          _durableNodes[existingIdx] = node;
        } else {
          _durableNodes.insert(0, node);
        }
      }

      // Step 3: Fetch fresh compact edge bundle (< 50 KB budget) from Cloud Run
      final bundleUri = Uri.parse('$baseUrl/api/memory/bundle');
      final bundleRes = await client.get(bundleUri);
      if (bundleRes.statusCode == 200) {
        final bundleJson = jsonDecode(bundleRes.body) as Map<String, dynamic>;
        _activeEdgeBundle = CompactEdgeMemoryBundle.fromJson(bundleJson);
      }

      client.close();
      _ingestionQueue.clear();
      return ConsolidationResult(
        success: true,
        turnsConsolidated: turnsConsolidated,
        nodesUpdated: nodesUpdatedCount,
      );
    } catch (e) {
      // Local on-device fallback consolidation when offline or cloud unreachable
      final now = DateTime.now();
      int localNodesCreated = 0;
      for (final episode in _ingestionQueue) {
        if (episode.entitiesExtracted.isNotEmpty) {
          for (final entity in episode.entitiesExtracted) {
            final existingIdx = _durableNodes.indexWhere(
              (n) => n.entityName.toLowerCase() == entity.entityValue.toLowerCase(),
            );
            final node = DurableKnowledgeNode(
              id: 'node-local-${DateTime.now().millisecondsSinceEpoch}-${localNodesCreated++}',
              entityName: entity.entityValue,
              category: entity.entityType,
              summary: 'Consolidated on-device from episode ${episode.id}: ${episode.userPrompt}',
              confidence: entity.confidence,
              relations: const [],
              sourceEpisodeIds: [episode.id],
              resolvedContradictions: const [],
              contradictionRecords: const [],
              lastUpdated: now,
            );
            if (existingIdx >= 0) {
              _durableNodes[existingIdx] = node;
            } else {
              _durableNodes.insert(0, node);
            }
          }
        } else {
          final trimmedPrompt = episode.userPrompt.trim();
          final entityTitle = trimmedPrompt.length > 36 ? '${trimmedPrompt.substring(0, 36)}...' : trimmedPrompt;
          final existingIdx = _durableNodes.indexWhere(
            (n) => n.entityName.toLowerCase() == entityTitle.toLowerCase(),
          );
          final node = DurableKnowledgeNode(
            id: 'node-local-${DateTime.now().millisecondsSinceEpoch}-${localNodesCreated++}',
            entityName: entityTitle.isNotEmpty ? entityTitle : 'Local Episode Context',
            category: 'USER_PREFERENCE',
            summary: 'Consolidated on-device from episode ${episode.id}: ${episode.userPrompt}',
            confidence: 0.85,
            relations: const [],
            sourceEpisodeIds: [episode.id],
            resolvedContradictions: const [],
            contradictionRecords: const [],
            lastUpdated: now,
          );
          if (existingIdx >= 0) {
            _durableNodes[existingIdx] = node;
          } else {
            _durableNodes.insert(0, node);
          }
          localNodesCreated++;
        }
        episode.status = 'CONSOLIDATED';
      }
      final turnsDrained = _ingestionQueue.length;
      _ingestionQueue.clear();
      _activeEdgeBundle ??= CompactEdgeMemoryBundle(
        bundleVersion: 1,
        createdAt: now,
        totalAnchors: _durableNodes.length,
        sizeBytes: 1024,
        anchors: const [],
      );
      return ConsolidationResult(
        success: true,
        turnsConsolidated: turnsDrained,
        nodesUpdated: localNodesCreated,
        errorMessage: e.toString(),
        isOfflineFallback: true,
      );
    } finally {
      _isConsolidating = false;
      notifyListeners();
    }
  }

  void revertContradiction(String nodeId, String contradictionText) {
    final idx = _durableNodes.indexWhere((n) => n.id == nodeId);
    if (idx == -1) return;
    final node = _durableNodes[idx];
    final updatedContradictions = List<String>.from(node.resolvedContradictions)..remove(contradictionText);
    
    // If there's a matching record, we can revert the summary or note that it was reverted
    String newSummary = node.summary;
    final matchingRecord = node.contradictionRecords.where((r) => contradictionText.contains('FP16') || r.priorDirective.contains('FP16')).firstOrNull;
    if (matchingRecord != null) {
      newSummary = 'Reverted to prior directive: ${matchingRecord.priorDirective}';
    }

    final updatedRecords = node.contradictionRecords.where((r) => !r.priorDirective.contains('FP16')).toList();

    _durableNodes[idx] = DurableKnowledgeNode(
      id: node.id,
      entityName: node.entityName,
      category: node.category,
      summary: newSummary,
      confidence: node.confidence,
      relations: node.relations,
      sourceEpisodeIds: node.sourceEpisodeIds,
      resolvedContradictions: updatedContradictions,
      contradictionRecords: updatedRecords,
      lastUpdated: DateTime.now(),
    );
    notifyListeners();
  }

  void repackLocalEdgeBundle() {
    final List<MemoryAnchor> anchors = _durableNodes.take(16).map((node) {
      return MemoryAnchor(
        anchorId: 'anchor-${node.id}',
        key: node.entityName,
        category: node.category,
        distilledContext: node.summary.length > 80 ? '${node.summary.substring(0, 80)}...' : node.summary,
      );
    }).toList();

    final testBundle = {
      'bundle_version': (_activeEdgeBundle?.bundleVersion ?? 1) + 1,
      'created_at': DateTime.now().toIso8601String(),
      'total_anchors': anchors.length,
      'anchors': anchors.map((a) => a.toJson()).toList(),
    };
    final calculatedBytes = utf8.encode(jsonEncode(testBundle)).length;

    _activeEdgeBundle = CompactEdgeMemoryBundle(
      bundleVersion: (_activeEdgeBundle?.bundleVersion ?? 1) + 1,
      createdAt: DateTime.now(),
      totalAnchors: anchors.length,
      sizeBytes: calculatedBytes,
      anchors: anchors,
    );
    notifyListeners();
  }

  /// Prunes working context turns beyond retainCount, returning actual freed bytes.
  int pruneWorkingContext({int retainCount = 5}) {
    if (_workingContext.length <= retainCount) {
      return 0;
    }
    int freedBytes = 0;
    while (_workingContext.length > retainCount) {
      final removed = _workingContext.removeLast();
      freedBytes += utf8.encode(removed.userPrompt + removed.modelResponse).length + 128;
    }
    notifyListeners();
    return freedBytes;
  }

  String mapCategory(String entityType) {
    switch (entityType) {
      case 'DATABASE_ENGINE':
      case 'LOCAL_STORAGE':
        return 'SYSTEM_ARCHITECTURE';
      case 'DEADLINE':
        return 'ROADMAP_DECISION';
      case 'AI_MODEL':
        return 'SYSTEM_ARCHITECTURE';
      case 'BUDGET_LIMIT':
        return 'SECURITY_POLICY';
      default:
        return 'USER_PREFERENCE';
    }
  }

  // ==========================================
  // Memory Pattern Simulator Methods
  // ==========================================

  /// Injects a conflicting directive into the durable knowledge graph,
  /// simulating conflict detection and resolution via Gemini 3.8 Flash.
  void simulateInjectContradiction(String entityName, String conflictingDirective, String rationale) {
    var target = _durableNodes.firstWhere(
      (n) => n.entityName.toLowerCase() == entityName.toLowerCase(),
      orElse: () => _durableNodes.first,
    );

    final record = ContradictionRecord(
      id: 'cr-sim-${DateTime.now().millisecondsSinceEpoch}',
      priorDirective: target.summary,
      activeDirective: conflictingDirective,
      rationale: rationale,
      resolvedAt: DateTime.now(),
    );

    final updated = DurableKnowledgeNode(
      id: target.id,
      entityName: target.entityName,
      category: target.category,
      summary: conflictingDirective,
      confidence: 0.97,
      relations: target.relations,
      sourceEpisodeIds: [...target.sourceEpisodeIds, 'ep-sim-${DateTime.now().millisecondsSinceEpoch}'],
      resolvedContradictions: [...target.resolvedContradictions, 'Superseded: ${target.summary}'],
      contradictionRecords: [...target.contradictionRecords, record],
      lastUpdated: DateTime.now(),
    );

    final index = _durableNodes.indexWhere((n) => n.id == target.id);
    if (index != -1) {
      _durableNodes[index] = updated;
    }

    _simulationLogs.insert(
      0,
      '[Contradiction Injected] Conflict detected on "${target.entityName}". Evaluated with Gemini 3.8 Flash offline loop. Superseded prior directive; created audit record ${record.id}.',
    );

    repackLocalEdgeBundle();
    notifyListeners();
  }

  /// Stresses the memory budget by injecting heavy policy anchors,
  /// testing whether the bundle exceeds or preserves the 50 KB ceiling.
  void simulateBudgetPressure(int additionalAnchorsCount) {
    final newAnchors = List<MemoryAnchor>.from(_activeEdgeBundle?.anchors ?? []);
    for (int i = 1; i <= additionalAnchorsCount; i++) {
      newAnchors.add(MemoryAnchor(
        anchorId: 'anchor-pressure-$i',
        key: 'Simulated Heavy Policy Directive #$i',
        category: 'SYSTEM_ARCHITECTURE',
        distilledContext: 'Enterprise compliance rule #$i requiring extensive schema validation, token bounds, and multi-turn parameter checks on device.',
      ));
    }

    final testBundle = {
      'bundle_version': (_activeEdgeBundle?.bundleVersion ?? 1) + 1,
      'created_at': DateTime.now().toIso8601String(),
      'total_anchors': newAnchors.length,
      'anchors': newAnchors.map((a) => a.toJson()).toList(),
    };
    final calculatedBytes = utf8.encode(jsonEncode(testBundle)).length;

    _activeEdgeBundle = CompactEdgeMemoryBundle(
      bundleVersion: (_activeEdgeBundle?.bundleVersion ?? 1) + 1,
      createdAt: DateTime.now(),
      totalAnchors: newAnchors.length,
      sizeBytes: calculatedBytes,
      anchors: newAnchors,
    );

    _simulationLogs.insert(
      0,
      '[Budget Pressure] Added $additionalAnchorsCount anchors. Bundle size: ${_activeEdgeBundle?.sizeKb.toStringAsFixed(1)} KB / 50.0 KB (Limit: ${_activeEdgeBundle?.isWithinBudget == true ? 'PRESERVED' : 'EXCEEDED'}).',
    );
    notifyListeners();
  }

  /// Toggles simulated offline network partition.
  void simulateOfflinePartition(bool toggle) {
    _isOfflinePartition = toggle;
    _simulationLogs.insert(
      0,
      '[Network State] ${toggle ? 'OFFLINE (Local Edge Partition Active - 0 Cloud Egress)' : 'ONLINE (Cloud Run Synchronization Restored)'}.',
    );
    notifyListeners();
  }

  /// Resets all memory structures, simulation logs, and offline state to baseline defaults.
  void resetSimulation() {
    _simulationLogs.clear();
    _isOfflinePartition = false;
    _durableNodes.clear();
    _workingContext.clear();
    _ingestionQueue.clear();
    _localTopicCache.clear();
    _prefetchHistory.clear();
    _dreamSyncHistory.clear();
    _activePrefetchedSceneId = null;
    _activeSceneTopicIds.clear();
    _activeTaskContext = null;
    _initializeDefaultMemoryState();
    _simulationLogs.insert(0, '[Reset] Memory state, boot index, and edge bundle reset to default baseline.');
    notifyListeners();
  }

  // ==========================================
  // Hierarchical Memory Tree Builders
  // ==========================================

  /// Builds a hierarchical representation of Local Memory (SQLite / RAM)
  MemoryTreeNode getLocalMemoryTree({String? sourceFilter}) {
    final turns = getWorkingContextForSource(sourceFilter);
    final queue = getIngestionQueueForSource(sourceFilter);
    final anchors = getEdgeAnchorsForSource(sourceFilter);

    final workingChildren = turns.map((t) {
      return MemoryTreeNode(
        id: 'turn-${t.id}',
        label: t.userPrompt,
        subtitle: t.modelResponse,
        nodeType: MemoryNodeType.turn,
        status: t.isPiiSanitized ? 'PII Scrubbed' : 'Clean',
        metric: '${t.latencyMs}ms (${t.modelName})',
        children: t.entitiesExtracted.map((e) => MemoryTreeNode(
          id: 'entity-${t.id}-${e.entityType}',
          label: '${e.entityType}: ${e.entityValue}',
          subtitle: 'Confidence: ${(e.confidence * 100).toInt()}%',
          nodeType: MemoryNodeType.attribute,
          metric: '${(e.confidence * 100).toInt()}%',
        )).toList(),
        metadata: {'turn': t},
      );
    }).toList();

    final queueChildren = queue.map((q) {
      return MemoryTreeNode(
        id: 'queue-${q.id}',
        label: q.userPrompt,
        subtitle: 'Status: ${q.status} · Route: ${q.route}',
        nodeType: MemoryNodeType.turn,
        status: 'AWAITING CONSOLIDATION',
        metric: '${q.entitiesExtracted.length} entities',
        metadata: {'turn': q},
      );
    }).toList();

    final anchorChildren = anchors.map((a) {
      return MemoryTreeNode(
        id: 'anchor-${a.anchorId}',
        label: a.key,
        subtitle: a.distilledContext,
        nodeType: MemoryNodeType.anchor,
        status: a.category,
        metric: 'Loaded in RAM',
        metadata: {'anchor': a},
      );
    }).toList();

    final filterLabel = (sourceFilter != null && sourceFilter.isNotEmpty && sourceFilter != 'ALL')
        ? ' · [$sourceFilter Filter]'
        : '';

    return MemoryTreeNode(
      id: 'local-root',
      label: 'Client Local Memory (SQLite WASM / RAM)$filterLabel',
      subtitle: 'Zero cloud egress storage & active prompt anchors',
      nodeType: MemoryNodeType.storeRoot,
      metric: '${turns.length} turns · ${_activeEdgeBundle?.sizeKb.toStringAsFixed(1)} KB cache',
      children: [
        MemoryTreeNode(
          id: 'local-working-context',
          label: 'Active Working Context (${turns.length} turns)',
          subtitle: 'Volatile scratchpad & recent conversational turns',
          nodeType: MemoryNodeType.category,
          children: workingChildren,
        ),
        MemoryTreeNode(
          id: 'local-ingestion-queue',
          label: 'Pending Ingestion Queue (${queue.length} items)',
          subtitle: 'Sanitized turns awaiting asynchronous cloud batch consolidation',
          nodeType: MemoryNodeType.category,
          children: queueChildren,
        ),
        MemoryTreeNode(
          id: 'local-edge-bundle',
          label: 'Loaded Edge Memory Anchors (${anchorChildren.length} anchors)',
          subtitle: 'Distilled long-term anchors for zero-latency prompt grounding',
          nodeType: MemoryNodeType.category,
          metric: '${_activeEdgeBundle?.sizeKb.toStringAsFixed(1)} KB / 50.0 KB',
          children: anchorChildren,
        ),
      ],
    );
  }

  /// Builds a hierarchical representation of Cloud Knowledge Graph (Firestore)
  MemoryTreeNode getCloudKnowledgeTree({String? sourceFilter}) {
    final nodes = getDurableNodesForSource(sourceFilter);
    final Map<String, List<DurableKnowledgeNode>> grouped = {};
    for (final node in nodes) {
      grouped.putIfAbsent(node.category, () => []).add(node);
    }

    final categoryChildren = grouped.entries.map((entry) {
      final categoryNodes = entry.value.map((n) {
        final relationChildren = n.relations.map((r) => MemoryTreeNode(
          id: 'rel-${n.id}-${r.targetNodeId}',
          label: '${r.predicate} ➔ ${r.targetNodeId}',
          subtitle: 'Directed relational edge in knowledge graph',
          nodeType: MemoryNodeType.relation,
        )).toList();

        final contradictionChildren = n.contradictionRecords.map((cr) => MemoryTreeNode(
          id: 'cr-${cr.id}',
          label: 'Contradiction Audit: ${cr.priorDirective}',
          subtitle: 'Active: ${cr.activeDirective} · Rationale: ${cr.rationale}',
          nodeType: MemoryNodeType.contradiction,
          status: 'RESOLVED',
          metadata: {'contradiction': cr, 'node': n},
        )).toList();

        return MemoryTreeNode(
          id: 'durable-${n.id}',
          label: n.entityName,
          subtitle: n.summary,
          nodeType: MemoryNodeType.entityNode,
          status: n.resolvedContradictions.isNotEmpty ? 'RESOLVED CONFLICT' : 'CONSOLIDATED',
          metric: '${(n.confidence * 100).toInt()}% confidence',
          children: [
            ...relationChildren,
            ...contradictionChildren,
          ],
          metadata: {'node': n},
        );
      }).toList();

      return MemoryTreeNode(
        id: 'cat-${entry.key}',
        label: entry.key,
        subtitle: '${categoryNodes.length} consolidated knowledge entities',
        nodeType: MemoryNodeType.category,
        children: categoryNodes,
      );
    }).toList();

    final filterLabel = (sourceFilter != null && sourceFilter.isNotEmpty && sourceFilter != 'ALL')
        ? ' · [$sourceFilter Filter]'
        : '';

    return MemoryTreeNode(
      id: 'cloud-root',
      label: 'Cloud Firestore Durable Knowledge Graph (/durable_nodes)$filterLabel',
      subtitle: 'Cross-session semantic memory consolidated via Gemini 3.8 Flash',
      nodeType: MemoryNodeType.storeRoot,
      metric: '${nodes.length} nodes',
      children: categoryChildren,
    );
  }

  /// Builds a hierarchical structural diff tree comparing Local Edge state to Cloud Firestore state.
  MemoryTreeNode getEdgeCloudDiffTree({String? sourceFilter}) {
    final edgeAnchors = getEdgeAnchorsForSource(sourceFilter);
    final queueTurns = getIngestionQueueForSource(sourceFilter);
    final durableNodes = getDurableNodesForSource(sourceFilter);
    final topicEntries = getMasterIndexEntriesForSource(sourceFilter);

    // Group durable nodes by category
    final Map<String, List<DurableKnowledgeNode>> cloudByCategory = {};
    for (final node in durableNodes) {
      cloudByCategory.putIfAbsent(node.category, () => []).add(node);
    }

    int syncedCount = 0;
    int modifiedCount = 0;
    int cloudOnlyCount = 0;
    int edgeOnlyCount = queueTurns.length;

    // 1. Pending Ingestion Branch (Edge Only turns)
    final List<MemoryTreeNode> pendingChildren = queueTurns.map((turn) {
      return MemoryTreeNode(
        id: 'diff-turn-${turn.id}',
        label: turn.userPrompt,
        subtitle: 'Stored in SQLite WASM/RAM · Pending cloud consolidation batch (${turn.route})',
        nodeType: MemoryNodeType.diffAdded,
        status: 'Edge Only (Pending)',
        metric: '${turn.latencyMs}ms (${turn.modelName})',
        children: turn.entitiesExtracted.map((e) => MemoryTreeNode(
          id: 'diff-entity-${turn.id}-${e.entityType}',
          label: '${e.entityType}: ${e.entityValue}',
          subtitle: 'Confidence: ${(e.confidence * 100).toInt()}% · Pending Firestore index',
          nodeType: MemoryNodeType.attribute,
          status: 'Pending Index',
          metric: '${(e.confidence * 100).toInt()}%',
        )).toList(),
        metadata: {'turn': turn},
      );
    }).toList();

    final pendingBranch = MemoryTreeNode(
      id: 'diff-branch-pending',
      label: 'Local Ingestion Queue (${queueTurns.length} turns awaiting cloud)',
      subtitle: 'Volatile local episodes pending asynchronous batch consolidation to Firestore',
      nodeType: MemoryNodeType.category,
      metric: '${queueTurns.length} pending',
      children: pendingChildren.isNotEmpty
          ? pendingChildren
          : [
              MemoryTreeNode(
                id: 'diff-pending-clean',
                label: 'All local turns consolidated',
                subtitle: 'Zero pending episodes in local ingestion queue',
                nodeType: MemoryNodeType.diffSynced,
                status: 'Clean',
                metric: '0 pending',
              ),
            ],
    );

    // 2. Durable Knowledge vs. Edge Anchors Comparison (Grouped by Category)
    final Set<String> matchedAnchorIds = {};
    final List<MemoryTreeNode> categoryBranches = [];

    final allCategories = Set<String>.from(cloudByCategory.keys)
      ..addAll(edgeAnchors.map((a) => a.category));

    for (final cat in allCategories) {
      final durableInCat = cloudByCategory[cat] ?? [];
      final anchorsInCat = edgeAnchors.where((a) => a.category == cat).toList();

      final List<MemoryTreeNode> entityDiffNodes = [];

      for (final durableNode in durableInCat) {
        // Match anchor by name or ID
        final matchingAnchor = edgeAnchors.where((a) =>
            a.key.toLowerCase() == durableNode.entityName.toLowerCase() ||
            a.anchorId == 'anchor-${durableNode.id}').firstOrNull;

        if (matchingAnchor != null) {
          matchedAnchorIds.add(matchingAnchor.anchorId);
          final hasContradiction = durableNode.contradictionRecords.isNotEmpty ||
              durableNode.resolvedContradictions.isNotEmpty;

          if (hasContradiction) {
            modifiedCount++;
            entityDiffNodes.add(MemoryTreeNode(
              id: 'diff-durable-${durableNode.id}',
              label: '${durableNode.entityName} (Conflict Resolved)',
              subtitle: 'Cloud active: "${durableNode.summary}" | Edge anchor: "${matchingAnchor.distilledContext}"',
              nodeType: MemoryNodeType.diffModified,
              status: 'MODIFIED / CONFLICT',
              metric: 'RAM Synced',
              metadata: {
                'node': durableNode,
                if (durableNode.contradictionRecords.isNotEmpty)
                  'contradiction': durableNode.contradictionRecords.last,
              },
              children: [
                MemoryTreeNode(
                  id: 'diff-sub-anchor-${matchingAnchor.anchorId}',
                  label: '📱 Local Edge Anchor: ${matchingAnchor.key}',
                  subtitle: 'Distilled Context: "${matchingAnchor.distilledContext}"',
                  nodeType: MemoryNodeType.anchor,
                  status: 'Local RAM',
                  metric: 'Loaded',
                ),
                MemoryTreeNode(
                  id: 'diff-sub-cloud-${durableNode.id}',
                  label: '☁️ Cloud Durable Node: ${durableNode.entityName}',
                  subtitle: 'Summary: "${durableNode.summary}" (${(durableNode.confidence * 100).toInt()}% confidence)',
                  nodeType: MemoryNodeType.entityNode,
                  status: 'Firestore',
                  metric: '${durableNode.relations.length} relations',
                  children: durableNode.relations.map((r) => MemoryTreeNode(
                    id: 'diff-rel-${durableNode.id}-${r.targetNodeId}',
                    label: '${r.predicate} ➔ ${r.targetNodeId}',
                    subtitle: 'Directed relational edge in Firestore knowledge graph',
                    nodeType: MemoryNodeType.relation,
                  )).toList(),
                ),
                ...durableNode.contradictionRecords.map((cr) => MemoryTreeNode(
                  id: 'diff-cr-${cr.id}',
                  label: 'Contradiction Audit: ${cr.priorDirective}',
                  subtitle: 'Active: ${cr.activeDirective} · Rationale: ${cr.rationale}',
                  nodeType: MemoryNodeType.contradiction,
                  status: 'RESOLVED',
                  metadata: {'contradiction': cr, 'node': durableNode},
                )),
              ],
            ));
          } else {
            syncedCount++;
            entityDiffNodes.add(MemoryTreeNode(
              id: 'diff-durable-${durableNode.id}',
              label: durableNode.entityName,
              subtitle: 'Synchronized in RAM anchor: "${matchingAnchor.distilledContext}"',
              nodeType: MemoryNodeType.diffSynced,
              status: 'Synced',
              metric: 'In RAM',
              metadata: {'node': durableNode},
              children: [
                MemoryTreeNode(
                  id: 'diff-sub-anchor-${matchingAnchor.anchorId}',
                  label: '📱 Local Edge Anchor: ${matchingAnchor.key}',
                  subtitle: 'Context: "${matchingAnchor.distilledContext}"',
                  nodeType: MemoryNodeType.anchor,
                  status: 'Local RAM',
                  metric: '0ms Grounding',
                ),
                MemoryTreeNode(
                  id: 'diff-sub-cloud-${durableNode.id}',
                  label: '☁️ Cloud Durable Node: ${durableNode.entityName}',
                  subtitle: 'Summary: "${durableNode.summary}" · Source Episodes: ${durableNode.sourceEpisodeIds.length}',
                  nodeType: MemoryNodeType.entityNode,
                  status: 'Firestore',
                  metric: '${(durableNode.confidence * 100).toInt()}% conf',
                  children: durableNode.relations.map((r) => MemoryTreeNode(
                    id: 'diff-rel-${durableNode.id}-${r.targetNodeId}',
                    label: '${r.predicate} ➔ ${r.targetNodeId}',
                    subtitle: 'Directed relational edge in knowledge graph',
                    nodeType: MemoryNodeType.relation,
                  )).toList(),
                ),
              ],
            ));
          }
        } else {
          // Cloud only (evicted from edge bundle to maintain <50KB budget)
          cloudOnlyCount++;
          entityDiffNodes.add(MemoryTreeNode(
            id: 'diff-durable-${durableNode.id}',
            label: '${durableNode.entityName} (Cloud Only)',
            subtitle: 'Durable in Firestore; evicted from local edge RAM cache to preserve 50 KB budget',
            nodeType: MemoryNodeType.diffRemoved,
            status: 'Cloud Only (Dormant)',
            metric: 'Evicted from RAM',
            metadata: {'node': durableNode},
            children: [
              MemoryTreeNode(
                id: 'diff-sub-cloud-${durableNode.id}',
                label: '☁️ Cloud Durable: ${durableNode.entityName}',
                subtitle: 'Summary: "${durableNode.summary}" · Stored in /durable_nodes',
                nodeType: MemoryNodeType.entityNode,
                status: 'Firestore Native',
                metric: '${(durableNode.confidence * 100).toInt()}% conf',
              ),
            ],
          ));
        }
      }

      // Check for unmatched edge anchors in this category
      for (final anchor in anchorsInCat) {
        if (!matchedAnchorIds.contains(anchor.anchorId)) {
          edgeOnlyCount++;
          entityDiffNodes.add(MemoryTreeNode(
            id: 'diff-anchor-${anchor.anchorId}',
            label: '${anchor.key} (Edge Anchor Only)',
            subtitle: 'Loaded in local RAM bundle; no corresponding durable node in Firestore',
            nodeType: MemoryNodeType.diffAdded,
            status: 'Edge Only',
            metric: 'RAM Loaded',
            metadata: {'anchor': anchor},
          ));
        }
      }

      if (entityDiffNodes.isNotEmpty) {
        categoryBranches.add(MemoryTreeNode(
          id: 'diff-cat-$cat',
          label: '$cat (${entityDiffNodes.length} nodes)',
          subtitle: 'Category parity across local cache and cloud graph',
          nodeType: MemoryNodeType.category,
          children: entityDiffNodes,
        ));
      }
    }

    final durableBranch = MemoryTreeNode(
      id: 'diff-branch-durable',
      label: 'Durable Knowledge vs. Edge Anchors ($syncedCount synced, $modifiedCount conflicts, $cloudOnlyCount dormant)',
      subtitle: 'Comparison between ${durableNodes.length} cloud durable nodes and ${edgeAnchors.length} active edge anchors',
      nodeType: MemoryNodeType.category,
      children: categoryBranches,
    );

    // 3. Topic Cache Delta (Four-Stage Architecture)
    final localCachedTopics = topicEntries.where((e) => e.isCachedLocally).toList();
    final cloudDreamTopics = topicEntries.where((e) => !e.isCachedLocally).toList();

    final topicChildren = topicEntries.map((entry) {
      if (entry.isCachedLocally) {
        return MemoryTreeNode(
          id: 'diff-topic-${entry.topicId}',
          label: '📄 ${entry.title}',
          subtitle: 'Cached locally in SQLite WASM (0ms access, zero egress)',
          nodeType: MemoryNodeType.diffSynced,
          status: 'LOCAL CACHE',
          metric: '${entry.tokenEstimate} tokens',
          metadata: {'entry': entry},
        );
      } else {
        return MemoryTreeNode(
          id: 'diff-topic-${entry.topicId}',
          label: '☁️ ${entry.title}',
          subtitle: 'Remote cloud dream storage; requires on-demand prefetch via HTTP',
          nodeType: MemoryNodeType.diffRemoved,
          status: 'CLOUD DREAM ONLY',
          metric: '${entry.tokenEstimate} tokens',
          metadata: {'entry': entry},
        );
      }
    }).toList();

    final topicBranch = MemoryTreeNode(
      id: 'diff-branch-topics',
      label: 'Topic Cache Delta (${localCachedTopics.length} local / ${cloudDreamTopics.length} cloud dream)',
      subtitle: 'Master index entries partitioning local SQLite cache from remote dream storage',
      nodeType: MemoryNodeType.category,
      children: topicChildren,
    );

    // 4. Synchronization Health & Network Delta
    final healthBranch = MemoryTreeNode(
      id: 'diff-branch-health',
      label: 'Synchronization Health & Partition State',
      subtitle: 'Real-time transport and budget status',
      nodeType: MemoryNodeType.category,
      children: [
        MemoryTreeNode(
          id: 'diff-net-state',
          label: _isOfflinePartition ? 'Local Edge Partition Active (Airgapped)' : 'Cloud Run Synchronization Online',
          subtitle: _isOfflinePartition
              ? 'All mutations restricted to local device. 0 egress allowed.'
              : 'Connected to Cloud Run backend at $baseUrl',
          nodeType: _isOfflinePartition ? MemoryNodeType.diffModified : MemoryNodeType.diffSynced,
          status: _isOfflinePartition ? 'OFFLINE' : 'ONLINE',
          metric: _isOfflinePartition ? 'Airgapped' : 'Active',
        ),
        MemoryTreeNode(
          id: 'diff-budget-state',
          label: 'Edge Bundle Memory Footprint',
          subtitle: '${_activeEdgeBundle?.sizeKb.toStringAsFixed(1) ?? "0.0"} KB / 50.0 KB (${(_activeEdgeBundle?.isWithinBudget ?? true) ? "Preserving zero-egress budget" : "Exceeding mobile RAM limit"})',
          nodeType: (_activeEdgeBundle?.isWithinBudget ?? true) ? MemoryNodeType.diffSynced : MemoryNodeType.diffModified,
          status: (_activeEdgeBundle?.isWithinBudget ?? true) ? 'Clean' : 'OVER BUDGET',
          metric: '${_activeEdgeBundle?.sizeKb.toStringAsFixed(1) ?? "0.0"} KB',
        ),
      ],
    );

    final totalDurable = durableNodes.length;
    final totalAnchors = edgeAnchors.length;
    final bundleSizeKb = _activeEdgeBundle?.sizeKb.toStringAsFixed(1) ?? '0.0';
    final isWithinBudget = _activeEdgeBundle?.isWithinBudget ?? true;

    final filterLabel = (sourceFilter != null && sourceFilter.isNotEmpty && sourceFilter != 'ALL')
        ? ' · [$sourceFilter Filter]'
        : '';

    final filterSubtitle = (sourceFilter != null && sourceFilter.isNotEmpty && sourceFilter != 'ALL')
        ? 'Filtered by $sourceFilter · Local SQLite/RAM vs. Cloud Firestore Graph'
        : 'Hierarchical structural delta: Local SQLite/RAM vs. Cloud Firestore Graph';

    return MemoryTreeNode(
      id: 'diff-root',
      label: 'Edge-to-Cloud Memory Difference Tree$filterLabel',
      subtitle: filterSubtitle,
      nodeType: MemoryNodeType.storeRoot,
      metric: '$syncedCount synced · ${queueTurns.length} pending · $cloudOnlyCount cloud-only · $modifiedCount conflicts',
      metadata: {
        'pendingCount': queueTurns.length,
        'syncedCount': syncedCount,
        'cloudOnlyCount': cloudOnlyCount,
        'modifiedCount': modifiedCount,
        'edgeOnlyCount': edgeOnlyCount,
        'totalDurable': totalDurable,
        'totalAnchors': totalAnchors,
        'bundleSizeKb': bundleSizeKb,
        'isWithinBudget': isWithinBudget,
        'isOffline': _isOfflinePartition,
      },
      children: [
        pendingBranch,
        durableBranch,
        topicBranch,
        healthBranch,
      ],
    );
  }

  void _initializeDefaultMemoryState() {
    // Seed initial durable knowledge graph nodes
    _durableNodes.addAll([
      DurableKnowledgeNode(
        id: 'node-arch-01',
        entityName: 'Quantization Policy',
        category: 'SYSTEM_ARCHITECTURE',
        summary: 'Enforce int4 quantization on Gemma 4 to fit within 2 GB client RAM limits.',
        confidence: 0.99,
        relations: [
          const NodeRelation(predicate: 'CONSTRAINS', targetNodeId: 'node-arch-02')
        ],
        sourceEpisodeIds: ['ep-seed-01', 'ep-seed-02'],
        resolvedContradictions: ['Superseded FP16 trial from Q2 roadmap'],
        contradictionRecords: [
          ContradictionRecord(
            id: 'cr-01',
            priorDirective: 'Planned FP16 trial in Q2 roadmap for high-precision inference',
            activeDirective: 'Enforce int4 quantization on Gemma 4 to fit within 2 GB client RAM limits',
            rationale: 'int4 quantization supersedes earlier FP16 roadmap trial to prevent macOS memory panics and comply with Android LiteRT 1.4 GB RAM ceilings.',
            resolvedAt: DateTime.now().subtract(const Duration(hours: 12)),
          ),
        ],
        lastUpdated: DateTime.now().subtract(const Duration(hours: 12)),
      ),
      DurableKnowledgeNode(
        id: 'node-arch-02',
        entityName: 'Edge Bundle Budget',
        category: 'SECURITY_POLICY',
        summary: 'Compact memory bundle size is strictly capped at 50 KB for instant mobile hydration.',
        confidence: 0.98,
        relations: [
          const NodeRelation(predicate: 'APPLIES_TO', targetNodeId: 'node-arch-01')
        ],
        sourceEpisodeIds: ['ep-seed-03'],
        resolvedContradictions: [],
        lastUpdated: DateTime.now().subtract(const Duration(hours: 24)),
      ),
      DurableKnowledgeNode(
        id: 'node-pref-03',
        entityName: 'Zero Cloud Egress for PII',
        category: 'SECURITY_POLICY',
        summary: 'Prompts with detected credentials, emails, or SSNs must execute 100% on-device.',
        confidence: 1.0,
        relations: [],
        sourceEpisodeIds: ['ep-seed-04'],
        resolvedContradictions: [],
        lastUpdated: DateTime.now().subtract(const Duration(hours: 48)),
      ),
      DurableKnowledgeNode(
        id: 'node-road-04',
        entityName: 'Android LiteRT CPU Fallback',
        category: 'ROADMAP_DECISION',
        summary: 'On Android Virtual Devices lacking physical NPU, deploy LiteRT CPU inference for functional parity.',
        confidence: 0.95,
        relations: [
          const NodeRelation(predicate: 'IMPLEMENTS', targetNodeId: 'node-arch-01')
        ],
        sourceEpisodeIds: ['ep-seed-05'],
        resolvedContradictions: ['Replaced AICore requirement on emulator'],
        lastUpdated: DateTime.now().subtract(const Duration(hours: 72)),
      ),
      DurableKnowledgeNode(
        id: 'node-lore-01',
        entityName: 'Aether-Core Resonance',
        category: 'WORLD_CANON',
        summary: 'Subterranean Foundry Aether-Core operates at critical frequency (432 Hz). Excess flux requires venting into aqueducts or keystone grounding.',
        confidence: 0.99,
        relations: [
          const NodeRelation(predicate: 'REGULATES', targetNodeId: 'node-lore-02')
        ],
        sourceEpisodeIds: ['ep-lore-001'],
        resolvedContradictions: [],
        lastUpdated: DateTime.now().subtract(const Duration(hours: 6)),
      ),
      DurableKnowledgeNode(
        id: 'node-lore-02',
        entityName: 'Undercity Sluice Gate Treaty',
        category: 'TACTICAL_SECURITY',
        summary: 'Shadow Syndicate maintains encrypted valve ciphers preventing dwarf slag dumping into residential drinking ducts.',
        confidence: 0.96,
        relations: [
          const NodeRelation(predicate: 'IMPACTS', targetNodeId: 'node-lore-01')
        ],
        sourceEpisodeIds: ['ep-lore-001'],
        resolvedContradictions: [],
        lastUpdated: DateTime.now().subtract(const Duration(hours: 18)),
      ),
    ]);

    // Initial compact edge bundle computed with real byte length
    final initialAnchors = [
      const MemoryAnchor(
        anchorId: 'anchor-01',
        key: 'Quantization Policy',
        category: 'SYSTEM_ARCHITECTURE',
        distilledContext: 'Enforce int4 on Gemma 4 for < 1.3 GB RAM headroom.',
      ),
      const MemoryAnchor(
        anchorId: 'anchor-02',
        key: 'Edge Bundle Budget',
        category: 'SECURITY_POLICY',
        distilledContext: 'Compact memory bundle strictly <= 50 KB.',
      ),
      const MemoryAnchor(
        anchorId: 'anchor-03',
        key: 'Zero Cloud Egress for PII',
        category: 'SECURITY_POLICY',
        distilledContext: 'Scrub contact info; keep private notes on-device.',
      ),
      const MemoryAnchor(
        anchorId: 'anchor-04',
        key: 'LiteRT CPU Fallback',
        category: 'ROADMAP_DECISION',
        distilledContext: 'Android Emulator uses LiteRT CPU pipeline.',
      ),
      const MemoryAnchor(
        anchorId: 'anchor-lore-01',
        key: 'Aether-Core Resonance',
        category: 'WORLD_CANON',
        distilledContext: 'Subterranean Aether-Core operates at 432 Hz; requires harmonic venting.',
      ),
      const MemoryAnchor(
        anchorId: 'anchor-lore-02',
        key: 'Sluice Gate Ciphers',
        category: 'TACTICAL_SECURITY',
        distilledContext: 'Shadow Syndicate holds encrypted bypass keys for Khar-Drak flood valves.',
      ),
    ];
    final initMap = {
      'bundle_version': 1,
      'created_at': DateTime.now().toIso8601String(),
      'total_anchors': initialAnchors.length,
      'anchors': initialAnchors.map((a) => a.toJson()).toList(),
    };
    final trueBytes = utf8.encode(jsonEncode(initMap)).length;
    _activeEdgeBundle = CompactEdgeMemoryBundle(
      bundleVersion: 1,
      createdAt: DateTime.now().subtract(const Duration(minutes: 30)),
      totalAnchors: initialAnchors.length,
      sizeBytes: trueBytes,
      anchors: initialAnchors,
    );

    // Initial working context with both LoreCraft game turns and assistant turns
    _workingContext.addAll([
      EpisodicTurn(
        id: 'ep-lore-001',
        sessionId: 'lorecraft-session-01',
        timestamp: DateTime.now().subtract(const Duration(minutes: 2)),
        userPrompt: 'Consult Gideon regarding Subterranean Aether-Core pressure threshold',
        modelResponse: 'Envoy, the blast bulkheads groan under 432 Hz resonance. If we do not vent into the aqueducts, the mountain splits.',
        route: 'EDGE_LOCAL',
        modelName: 'Gemma 4 int4',
        latencyMs: 82,
        ttftMs: 38,
        isPiiSanitized: true,
        entitiesExtracted: [
          const ExtractedEntity(entityType: 'NPC', entityValue: 'Gideon Ironhand', confidence: 1.0),
          const ExtractedEntity(entityType: 'REGION', entityValue: 'Subterranean Foundry', confidence: 1.0),
          const ExtractedEntity(entityType: 'FACTION', entityValue: 'Iron Vanguard', confidence: 0.98),
        ],
        status: 'UNCONSOLIDATED',
      ),
      EpisodicTurn(
        id: 'ep-001',
        sessionId: 'session-live',
        timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
        userPrompt: 'Extract action items: Contact alice@example.org before Friday',
        modelResponse: '1. Action: Finalize SQLite WASM migration\n2. PII Sanitized: alice@example.org',
        route: 'EDGE_LOCAL',
        modelName: 'Gemma 4 2B (WebGPU int4)',
        latencyMs: 142,
        ttftMs: 62,
        isPiiSanitized: true,
        entitiesExtracted: [
          const ExtractedEntity(entityType: 'DEADLINE', entityValue: 'Friday', confidence: 0.96),
          const ExtractedEntity(entityType: 'DATABASE_ENGINE', entityValue: 'SQLite WASM', confidence: 0.98),
        ],
        status: 'UNCONSOLIDATED',
      ),
    ]);

    _ingestionQueue.add(_workingContext.first);

    // Initial 4-stage edge memory architecture state
    _environmentalState = LocalEnvironmentalState.defaultState();
    _coreDirectives = CorePersonaDirectives.defaultDirectives();
    _masterIndex = MasterIndex.defaultIndex();
    _bootState = AgentBootState.initial().copyWith(
      environmentalState: _environmentalState,
      masterIndex: _masterIndex,
      coreDirectives: _coreDirectives,
    );

    for (final e in _masterIndex.entries) {
      if (e.isCachedLocally && _groundTruthTopics.containsKey(e.topicId)) {
        _localTopicCache[e.topicId] = _groundTruthTopics[e.topicId]!;
      }
    }
  }

  // ==========================================
  // Pattern 1: On-Load (The Boot State)
  // ==========================================

  /// Synchronizes live hardware telemetry directly from the host operating system.
  /// On Android, queries Android OS BatteryManager, ConnectivityManager, and Build info.
  Future<bool> syncPlatformTelemetry() async {
    try {
      final res = await _androidChannel.invokeMapMethod<String, dynamic>('getDeviceTelemetry');
      if (res != null) {
        final double? battery = (res['batteryLevel'] as num?)?.toDouble();
        final bool? charging = res['isCharging'] as bool?;
        final String? netStatus = res['networkStatus'] as String?;
        final String? engine = res['hardwareEngine'] as String?;

        _environmentalState = _environmentalState.copyWith(
          batteryLevel: battery ?? _environmentalState.batteryLevel,
          isCharging: charging ?? _environmentalState.isCharging,
          networkStatus: netStatus ?? _environmentalState.networkStatus,
          hardwareEngine: engine ?? _environmentalState.hardwareEngine,
        );
        _bootState = _bootState.copyWith(environmentalState: _environmentalState);
        _isUsingPlatformTelemetry = true;
        _simulationLogs.insert(
          0,
          '[OS Telemetry] Synced live hardware vitals from Android OS: '
          'Battery ${((_environmentalState.batteryLevel) * 100).toInt()}% (${_environmentalState.isCharging ? "AC" : "Battery"}), '
          'Network ${_environmentalState.networkStatus}, Engine: ${_environmentalState.hardwareEngine}.',
        );
        notifyListeners();
        return true;
      }
    } catch (_) {
      // Platform channel unavailable (e.g. Web/Desktop without platform channel or unit tests)
    }
    return false;
  }

  /// Spins up the edge agent by loading only the absolute minimum context required:
  /// Core Directives, Master Index (TOC map from cloud dream), and Environmental State.
  Future<AgentBootState> bootEdgeAgent({LocalEnvironmentalState? overrideEnv}) async {
    final stopwatch = Stopwatch()..start();
    if (overrideEnv != null) {
      _environmentalState = overrideEnv;
    }

    // Fast local device initialization
    await Future.delayed(const Duration(milliseconds: 15));
    stopwatch.stop();

    _bootState = _bootState.copyWith(
      isBooted: true,
      bootTimestamp: DateTime.now(),
      bootDurationMs: stopwatch.elapsedMilliseconds,
      environmentalState: _environmentalState,
      masterIndex: _masterIndex,
      coreDirectives: _coreDirectives,
    );

    _simulationLogs.insert(
      0,
      '[Boot] Edge agent booted in ${stopwatch.elapsedMilliseconds}ms. Loaded minimum context: '
      'Directives (${_coreDirectives.allocatedTokens} tokens), Master Index (${_masterIndex.calculatedSizeBytes} bytes, ${_masterIndex.totalTopicCount} topics), '
      'Environmental State (${_environmentalState.networkStatus}, ${_environmentalState.hardwareEngine}). Total boot footprint: ${_bootState.bootFootprintBytes} bytes.',
    );
    notifyListeners();
    return _bootState;
  }

  /// Toggles simulated battery state between 100% AC and 12% Low Power Unplugged.
  void toggleBatterySimulation() {
    final current = _environmentalState;
    final isLow = current.batteryLevel <= 0.15;
    final nextBattery = isLow ? 1.0 : 0.12;
    final nextCharging = isLow ? true : false;

    _environmentalState = current.copyWith(
      batteryLevel: nextBattery,
      isCharging: nextCharging,
    );

    _bootState = _bootState.copyWith(
      environmentalState: _environmentalState,
    );

    final policy = _bootState.routingPolicy;
    _simulationLogs.insert(
      0,
      '[Hardware Triage] Battery state shifted to ${(nextBattery * 100).toInt()}% (${nextCharging ? "AC CONNECTED" : "BATTERY DISCHARGING"}). '
      'Active Policy: ${policy.displayName}. ${policy.plainEnglishDescription}',
    );
    notifyListeners();
  }

  /// Toggles simulated network state between ONLINE_WIFI and OFFLINE_AIRGAPPED.
  void toggleNetworkSimulation() {
    final current = _environmentalState;
    final isOffline = current.networkStatus == 'OFFLINE_AIRGAPPED';
    final nextNetwork = isOffline ? 'ONLINE_WIFI' : 'OFFLINE_AIRGAPPED';

    _environmentalState = current.copyWith(
      networkStatus: nextNetwork,
    );
    _isOfflinePartition = !isOffline;

    _bootState = _bootState.copyWith(
      environmentalState: _environmentalState,
    );

    final policy = _bootState.routingPolicy;
    _simulationLogs.insert(
      0,
      '[Hardware Triage] Network state shifted to $nextNetwork. '
      'Active Policy: ${policy.displayName}. ${policy.plainEnglishDescription}',
    );
    notifyListeners();
  }

  // ==========================================
  // Pattern 2: Conditionally (Just-In-Time Context)
  // ==========================================

  /// Tool-triggered fetching: Paginates specific topic from local cache or cloud into working context.
  Future<MemoryTopicFile> fetchMemoryTopic(String topicId) async {
    // 1. Check local cache first
    if (_localTopicCache.containsKey(topicId)) {
      final cached = _localTopicCache[topicId]!;
      _simulationLogs.insert(
        0,
        '[JIT Fetch] CACHE HIT: Retrieved topic "$topicId" (${cached.byteSize} bytes, ~${cached.tokenEstimate} tokens) from local memory.',
      );
      return cached;
    }

    if (_isOfflinePartition) {
      throw StateError('Cannot fetch uncached topic "$topicId" while offline partition is active.');
    }

    // 2. Fetch from ground truth repository
    final topic = _groundTruthTopics[topicId];
    if (topic == null) {
      throw ArgumentError('Unknown memory topic ID: "$topicId"');
    }

    // Fast cloud retrieval simulation
    await Future.delayed(const Duration(milliseconds: 35));

    _localTopicCache[topicId] = topic;

    // Update Master Index entry cache flag
    final updatedEntries = _masterIndex.entries.map((e) {
      if (e.topicId == topicId) {
        return e.copyWith(isCachedLocally: true);
      }
      return e;
    }).toList();

    _masterIndex = _masterIndex.copyWith(entries: updatedEntries);
    _bootState = _bootState.copyWith(masterIndex: _masterIndex);

    _simulationLogs.insert(
      0,
      '[JIT Fetch] TOOL CALL: fetch_memory_topic(topic_id="$topicId"). Fetched ${topic.byteSize} bytes (~${topic.tokenEstimate} tokens) and paged into local memory cache.',
    );
    notifyListeners();
    return topic;
  }

  /// Evicts a specific topic from local edge cache on-demand.
  /// Updates Master Index cache flag to false and logs the memory eviction event.
  bool evictMemoryTopic(String topicId) {
    if (!_localTopicCache.containsKey(topicId)) {
      return false;
    }
    final topic = _localTopicCache.remove(topicId);

    // Update Master Index entry cache flag
    final updatedEntries = _masterIndex.entries.map((e) {
      if (e.topicId == topicId) {
        return e.copyWith(isCachedLocally: false);
      }
      return e;
    }).toList();

    _masterIndex = _masterIndex.copyWith(entries: updatedEntries);
    _bootState = _bootState.copyWith(masterIndex: _masterIndex);

    _simulationLogs.insert(
      0,
      '[JIT Evict] EVICTED: Removed topic "$topicId" (${topic?.byteSize ?? 0} bytes, ~${topic?.tokenEstimate ?? 0} tokens) from local memory cache.',
    );
    notifyListeners();
    return true;
  }

  /// Evicts all locally cached topics, restoring local edge memory to base directives.
  int evictAllLocalTopics() {
    final count = _localTopicCache.length;
    if (count == 0) return 0;

    int totalBytes = 0;
    int totalTokens = 0;
    for (final topic in _localTopicCache.values) {
      totalBytes += topic.byteSize;
      totalTokens += topic.tokenEstimate;
    }

    _localTopicCache.clear();

    final updatedEntries = _masterIndex.entries.map((e) {
      return e.copyWith(isCachedLocally: false);
    }).toList();

    _masterIndex = _masterIndex.copyWith(entries: updatedEntries);
    _bootState = _bootState.copyWith(masterIndex: _masterIndex);

    _simulationLogs.insert(
      0,
      '[JIT Evict All] EVICTED ALL: Purged $count cached topic(s) ($totalBytes bytes, ~$totalTokens tokens) from local memory. Restored to base directives.',
    );
    notifyListeners();
    return count;
  }

  /// Task-Bound Context Window: Injects topic memory during task execution,
  /// then immediately evicts and drops it to keep the context window small.
  Future<T> executeTaskWithBoundContext<T>({
    required String taskId,
    required String taskName,
    required List<String> topicIds,
    required Future<T> Function() action,
  }) async {
    final List<MemoryTopicFile> loadedTopics = [];
    for (final id in topicIds) {
      final t = await fetchMemoryTopic(id);
      loadedTopics.add(t);
    }

    final injectedTokens = loadedTopics.fold<int>(0, (sum, t) => sum + t.tokenEstimate);

    _activeTaskContext = TaskBoundContext(
      taskId: taskId,
      taskName: taskName,
      injectedTopics: loadedTopics,
      startTime: DateTime.now(),
      baseContextTokens: _coreDirectives.allocatedTokens,
      taskContextTokens: injectedTokens,
      isEvicted: false,
    );

    _simulationLogs.insert(
      0,
      '[Task Context Bound] Workflow "$taskName" ($taskId) initiated. Injected ${loadedTopics.length} topic(s) (+${injectedTokens} tokens). Total active context: ${_activeTaskContext!.totalContextTokens} tokens.',
    );
    notifyListeners();

    try {
      final result = await action();
      return result;
    } finally {
      // IMMEDIATE EVICTION RULE: Drop injected context when task completes!
      _activeTaskContext = _activeTaskContext?.copyWith(
        isEvicted: true,
        endTime: DateTime.now(),
      );

      _simulationLogs.insert(
        0,
        '[Task Context Evicted] Task "$taskId" completed. Injected context (+${injectedTokens} tokens) dropped immediately. Active context restored to base ${_coreDirectives.allocatedTokens} tokens.',
      );
      notifyListeners();
    }
  }

  // ==========================================
  // Pattern 3: Pre-Emptive Caching (The Predictive Load)
  // ==========================================

  /// Pre-emptively fetches context files into local memory before user prompts when a state/scene shift occurs.
  /// When transitioning between scenes, previously prefetched scene topics are evicted from local cache
  /// to enforce bounded edge memory limits and eliminate stale context leakage.
  Future<PrefetchEvent> triggerStatePrefetch({
    required String stateTrigger,
    required List<String> topicIds,
    String? sceneId,
    bool evictPreviousSceneTopics = true,
  }) async {
    final stopwatch = Stopwatch()..start();
    int newlyCachedBytes = 0;
    int prefetchedCount = 0;
    int evictedBytes = 0;
    final List<String> evictedTopicIds = [];

    // 1. Evict previous scene topics if shifting between scenes
    if (evictPreviousSceneTopics && _activeSceneTopicIds.isNotEmpty) {
      for (final prevTid in _activeSceneTopicIds) {
        // Evict if not needed in the new scene
        if (!topicIds.contains(prevTid)) {
          if (_localTopicCache.containsKey(prevTid)) {
            final evictedTopic = _localTopicCache.remove(prevTid);
            if (evictedTopic != null) {
              evictedBytes += evictedTopic.byteSize;
            }
            evictedTopicIds.add(prevTid);
          }
        }
      }

      if (evictedTopicIds.isNotEmpty) {
        _simulationLogs.insert(
          0,
          '[Predictive Eviction] Scene shift: evicted ${evictedTopicIds.length} previous scene topic(s) ($evictedBytes B: ${evictedTopicIds.join(", ")}) from local cache to maintain bounded edge footprint.',
        );
      }
    }

    // 2. Prefetch new scene topics
    for (final tid in topicIds) {
      if (!_localTopicCache.containsKey(tid)) {
        final t = _groundTruthTopics[tid];
        if (t != null) {
          _localTopicCache[tid] = t;
          newlyCachedBytes += t.byteSize;
          prefetchedCount++;
        }
      }
    }

    // 3. Update master index cache flags:
    // Mark target topicIds as true; mark evictedTopicIds as false
    final updatedEntries = _masterIndex.entries.map((e) {
      if (topicIds.contains(e.topicId)) {
        return e.copyWith(isCachedLocally: true);
      } else if (evictedTopicIds.contains(e.topicId)) {
        return e.copyWith(isCachedLocally: false);
      }
      return e;
    }).toList();

    _masterIndex = _masterIndex.copyWith(entries: updatedEntries);

    // 4. Update environmental state sector if sceneId or stateTrigger maps to a known sector
    String? newSector;
    if (sceneId != null) {
      if (sceneId == 'foundry') {
        newSector = 'subterranean_foundry';
      } else if (sceneId == 'docks') {
        newSector = 'sunken_docks';
      } else if (sceneId == 'spire') {
        newSector = 'keystone_spire';
      }
    } else {
      final lower = stateTrigger.toLowerCase();
      if (lower.contains('foundry')) {
        newSector = 'subterranean_foundry';
      } else if (lower.contains('dock')) {
        newSector = 'sunken_docks';
      } else if (lower.contains('spire')) {
        newSector = 'keystone_spire';
      }
    }

    if (newSector != null) {
      _environmentalState = _environmentalState.copyWith(currentSector: newSector);
    }

    _activePrefetchedSceneId = sceneId;
    _activeSceneTopicIds.clear();
    _activeSceneTopicIds.addAll(topicIds);

    _bootState = _bootState.copyWith(
      masterIndex: _masterIndex,
      environmentalState: _environmentalState,
    );

    stopwatch.stop();

    final status = prefetchedCount > 0
        ? 'PREFETCHED'
        : (evictedTopicIds.isNotEmpty ? 'TRANSITIONED' : 'ALREADY_CACHED');

    final event = PrefetchEvent(
      id: 'prefetch-${DateTime.now().millisecondsSinceEpoch}',
      stateTrigger: stateTrigger,
      sceneId: sceneId,
      targetTopicIds: topicIds,
      evictedTopicIds: evictedTopicIds,
      timestamp: DateTime.now(),
      status: status,
      latencyMs: stopwatch.elapsedMilliseconds,
      bytesCached: newlyCachedBytes,
      bytesEvicted: evictedBytes,
    );

    _prefetchHistory.insert(0, event);

    final evictMsg = evictedTopicIds.isNotEmpty
        ? ' Evicted ${evictedTopicIds.length} former topic(s) ($evictedBytes B: ${evictedTopicIds.join(", ")}).'
        : '';
    _simulationLogs.insert(
      0,
      '[Predictive Prefetch] State Shift: "$stateTrigger". Prefetched $prefetchedCount new topic(s) ($newlyCachedBytes B) into local memory.$evictMsg Latency: ${event.latencyMs}ms. Zero-latency 0ms local query readiness confirmed.',
    );
    notifyListeners();
    return event;
  }

  // ==========================================
  // Pattern 4: Asynchronous Syncs (The "Morning After")
  // ==========================================

  /// Receives overnight cloud dream consolidation delta, overwrites Master Index,
  /// and invalidates deprecated/modified local cached topic files.
  Future<DreamDeltaUpdate> applyDreamDeltaSync({DreamDeltaUpdate? customDelta}) async {
    final now = DateTime.now();
    final delta = customDelta ?? DreamDeltaUpdate(
      deltaId: 'delta-dream-${now.millisecondsSinceEpoch}',
      syncTimestamp: now,
      source: 'Cloud Dream Daemon (Overnight Consolidation 03:00 AM)',
      newMasterIndexVersion: _masterIndex.version + 1,
      updatedEntries: [
        MasterIndexEntry(
          topicId: 'iron_vanguard_ciphers',
          title: 'Iron Vanguard Valve Ciphers [Consolidated v${_masterIndex.version + 1}]',
          category: 'TACTICAL_SECURITY',
          summaryScope: 'Updated emergency bypass codes following Foundry breach reconciliation.',
          byteSize: 3620,
          tokenEstimate: 410,
          versionHash: 'hash-ivg-v${_masterIndex.version + 1}-reconciled',
          isCachedLocally: false, // Invalidated for re-cache
          lastUpdated: now,
        ),
      ],
      deprecatedTopicIds: ['old_subterranean_outpost_log'],
      conflictsResolvedCount: 2,
      invalidatedCachedTopicIds: ['iron_vanguard_ciphers'],
    );

    // 1. Invalidate and purge stale local cache files
    for (final invalidTopicId in delta.invalidatedCachedTopicIds) {
      _localTopicCache.remove(invalidTopicId);
    }

    // 2. Overwrite Master Index with updated entries and remove deprecated topics
    final entryMap = <String, MasterIndexEntry>{
      for (final e in _masterIndex.entries) e.topicId: e,
    };

    // Remove deprecated
    for (final dep in delta.deprecatedTopicIds) {
      entryMap.remove(dep);
    }

    // Update modified
    for (final updated in delta.updatedEntries) {
      entryMap[updated.topicId] = updated;
    }

    _masterIndex = MasterIndex(
      version: delta.newMasterIndexVersion,
      generatedBy: delta.source,
      generatedAt: delta.syncTimestamp,
      entries: entryMap.values.toList(),
    );

    _bootState = _bootState.copyWith(masterIndex: _masterIndex);
    _dreamSyncHistory.insert(0, delta);

    _simulationLogs.insert(
      0,
      '[Dream Delta Sync] Overwrote Master Index to v${delta.newMasterIndexVersion}. '
      'Purged/invalidated ${delta.invalidatedCachedTopicIds.length} stale local cache file(s). '
      'Pruned ${delta.deprecatedTopicIds.length} deprecated topics. Cloud resolved ${delta.conflictsResolvedCount} contradictions.',
    );
    notifyListeners();
    return delta;
  }

  static final Map<String, MemoryTopicFile> _groundTruthTopics = {
    'iron_vanguard_ciphers': MemoryTopicFile(
      topicId: 'iron_vanguard_ciphers',
      title: 'Iron Vanguard Valve Ciphers',
      category: 'TACTICAL_SECURITY',
      fullContent: '### Iron Vanguard Emergency Slag Valve Ciphers\n'
          '- **Master Frequency**: 432.8 MHz acoustic harmonic resonance.\n'
          '- **Hydraulic Bypass Seal**: Turn primary copper valve 90° clockwise, engage secondary tungsten damper.\n'
          '- **Security Code**: `KHAR-DRAK-VALVE-774-SIGMA`.\n'
          '- **Operational Mandate**: Never open valve when core pressure exceeds 180 Bar unless municipal evacuation is confirmed by Forge Master Gideon Stonehand.',
      versionHash: 'hash-ivg-99a',
      lastConsolidatedAt: DateTime.now().subtract(const Duration(hours: 3)),
      byteSize: 3420,
      tags: ['ciphers', 'vanguard', 'valves', 'foundry', 'security'],
    ),
    'undercity_sluice_bypass': MemoryTopicFile(
      topicId: 'undercity_sluice_bypass',
      title: 'Undercity Sluice Drainage Grid',
      category: 'WORLD_CANON',
      fullContent: '### Undercity Sluice Drainage Grid Map\n'
          '- **Subterranean Aqueduct Labyrinth**: Built in the Third Age of Khar-Drak, connects Lake Oakhaven to the deep municipal cooling basins.\n'
          '- **Submerged Channel 4B**: High-velocity runoff channel passing beneath Lyra Nightshade’s enclave.\n'
          '- **Structural Integrity**: Compromised at Junction 12 due to volcanic seismic tremors.',
      versionHash: 'hash-slc-41b',
      lastConsolidatedAt: DateTime.now().subtract(const Duration(hours: 3)),
      byteSize: 4180,
      tags: ['aqueduct', 'sluice', 'undercity', 'docks', 'water'],
    ),
    'keystone_spire_harmonics': MemoryTopicFile(
      topicId: 'keystone_spire_harmonics',
      title: 'Keystone Spire Leyline Harmonics',
      category: 'ARTIFACT_SCHEMATICS',
      fullContent: '### Keystone Spire Leyline Resonance Calibration\n'
          '- **Resonant Core**: Aether-crystal prism vibrating at delta harmonic 1.618.\n'
          '- **Stabilization Sequence**: Align northern refraction lens with the Zenith Sun; pulse arcane capacitor at 12ms intervals.\n'
          '- **Critical Hazard**: Misalignment causes an uncontrolled cascading surge across the lower wards.',
      versionHash: 'hash-ksp-18c',
      lastConsolidatedAt: DateTime.now().subtract(const Duration(hours: 3)),
      byteSize: 3890,
      tags: ['spire', 'arcane', 'harmonics', 'enclave', 'stabilization'],
    ),
    'envoy_diplomatic_treaties': MemoryTopicFile(
      topicId: 'envoy_diplomatic_treaties',
      title: 'Grand Council Tripartite Treaties',
      category: 'USER_PREFERENCES',
      fullContent: '### Grand Council Tripartite Accords (Consolidated)\n'
          '- **Article I**: The Iron Vanguard retains sole martial jurisdiction over the Upper Foundry and Slag Ramparts.\n'
          '- **Article II**: The Shadow Syndicate operates maritime trade across Oakhaven Docks unmolested, conditioned on 12% grain tribute.\n'
          '- **Article III**: The Arcane Enclave oversees Keystone Spire and all leyline taps, reporting directly to Envoy triage.',
      versionHash: 'hash-trt-04d',
      lastConsolidatedAt: DateTime.now().subtract(const Duration(hours: 3)),
      byteSize: 2950,
      tags: ['treaties', 'diplomacy', 'factions', 'council', 'envoy'],
    ),
    'volcanic_slag_thresholds': MemoryTopicFile(
      topicId: 'volcanic_slag_thresholds',
      title: 'Volcanic Slag Thermal Tolerances',
      category: 'TACTICAL_SECURITY',
      fullContent: '### Volcanic Slag & Thermal Metallurgy\n'
          '- **Melting Point**: Khar-Drak basalt slag liquefies at 1,480°C.\n'
          '- **Blast Wall Tolerance**: Reinforced obsidian-iron alloy sustains direct lava immersion for up to 48 minutes.\n'
          '- **Cooling Protocol**: Quench with subterranean aquifer water via Sluice 4B; rapid cooling induces crystalline fracturing.',
      versionHash: 'hash-vsl-77e',
      lastConsolidatedAt: DateTime.now().subtract(const Duration(hours: 3)),
      byteSize: 2640,
      tags: ['thermal', 'slag', 'foundry', 'tolerances', 'safety'],
    ),
    'smuggler_cipher_routes': MemoryTopicFile(
      topicId: 'smuggler_cipher_routes',
      title: 'Shadow Syndicate Contraband Bypasses',
      category: 'TACTICAL_SECURITY',
      fullContent: '### Shadow Syndicate Clandestine Waterway Routes\n'
          '- **Sub-Wharf Drain 7**: Accessed beneath Pier 3 using a three-tap knock on the cast-iron grating.\n'
          '- **Dead Drop Vaults**: Sealed waterproof lockers anchored beneath the floating pontoon bridges.\n'
          '- **Lyra\'s Cipher**: Runes inscribed in luminous algae indicate safe tide windows for navigation.',
      versionHash: 'hash-smg-22f',
      lastConsolidatedAt: DateTime.now().subtract(const Duration(hours: 3)),
      byteSize: 3120,
      tags: ['syndicate', 'smugglers', 'routes', 'docks', 'covert'],
    ),
    'ancient_grove_roots': MemoryTopicFile(
      topicId: 'ancient_grove_roots',
      title: 'Ancient Sylvan Grove Living Roots',
      category: 'WORLD_CANON',
      fullContent: '### Sylvan Grove Deep Root Conduits\n'
          '- **Arcane Absorption**: Ironwood taproots absorb excess electromagnetic radiation from volcanic conduits.\n'
          '- **Sap Conductivity**: Petrified amber sap acts as a natural dielectric buffer for uncontrolled arcane lightning.\n'
          '- **Historical Notes**: The First Sentinels planted the grove during the Great Calamity to ground the mountain.',
      versionHash: 'hash-grv-33g',
      lastConsolidatedAt: DateTime.now().subtract(const Duration(hours: 3)),
      byteSize: 3500,
      tags: ['grove', 'roots', 'sylvan', 'nature', 'arcane'],
    ),
    'envoy_hardware_limits': MemoryTopicFile(
      topicId: 'envoy_hardware_limits',
      title: 'Envoy Edge Hardware Constraints',
      category: 'USER_PREFERENCES',
      fullContent: '### Edge Hardware Governance Invariants\n'
          '- **Compute Engine**: Apple Silicon M-Series WebGPU / LiteRT int4 execution.\n'
          '- **RAM Boundary**: Maximum 5 turns working context before pruning; edge bundle capped strictly at 50 KB.\n'
          '- **Thermal Guardrail**: Evict task-bound context immediately upon action completion to prevent memory pressure panics.',
      versionHash: 'hash-hwd-88h',
      lastConsolidatedAt: DateTime.now().subtract(const Duration(hours: 3)),
      byteSize: 2100,
      tags: ['hardware', 'limits', 'apple_silicon', 'weblite', 'budget'],
    ),
  };
}
