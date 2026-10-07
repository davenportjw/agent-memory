import 'package:flutter/material.dart';
import '../models/memory_node.dart';
import '../models/episodic_turn.dart';
import '../models/edge_memory_bundle.dart';
import '../services/local_memory_service.dart';
import '../theme/sepia_theme.dart';
import 'widgets/memory_request_response_diagram.dart';
import 'widgets/memory_notebook_cell.dart';
import 'widgets/memory_tree_view.dart';
import 'widgets/memory_pattern_tester.dart';

/// Memory Lifecycle Studio
/// Educational, transparent, and interactive workstation visualizing:
/// 1) Request/Response End-to-End Memory Lifecycle Diagram
/// 2) Computational Notebook Stages: Working Memory -> Ingestion Queue -> Cloud Consolidation -> Edge Bundle
/// 3) Hierarchical Dual-Tree: Local Edge Memory vs. Cloud Knowledge Graph
/// 4) Memory Pattern Simulator: Contradictions, Budget Saturation, and Offline Modes
class MemoryLifecycleStudio extends StatefulWidget {
  final LocalMemoryService memoryService;

  const MemoryLifecycleStudio({
    super.key,
    required this.memoryService,
  });

  @override
  State<MemoryLifecycleStudio> createState() => _MemoryLifecycleStudioState();
}

class _MemoryLifecycleStudioState extends State<MemoryLifecycleStudio> {
  int _selectedStageIndex = 0;
  final ScrollController _scrollController = ScrollController();
  String _selectedSourceFilter = 'ALL';
  bool _isMechanismsGuideExpanded = true;

  final GlobalKey _cell1Key = GlobalKey();
  final GlobalKey _cell2Key = GlobalKey();
  final GlobalKey _cell3Key = GlobalKey();
  final GlobalKey _cell4Key = GlobalKey();
  final GlobalKey _treeKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    widget.memoryService.addListener(_onServiceChanged);
  }

  @override
  void dispose() {
    widget.memoryService.removeListener(_onServiceChanged);
    _scrollController.dispose();
    super.dispose();
  }

  void _onServiceChanged() {
    if (mounted) setState(() {});
  }

  void _scrollToStage(int stageIndex) {
    setState(() => _selectedStageIndex = stageIndex);

    GlobalKey targetKey;
    switch (stageIndex) {
      case 0:
        targetKey = _cell1Key;
        break;
      case 1:
        targetKey = _cell2Key;
        break;
      case 2:
        targetKey = _cell3Key;
        break;
      case 3:
        targetKey = _cell4Key;
        break;
      default:
        targetKey = _treeKey;
        break;
    }

    final targetContext = targetKey.currentContext;
    if (targetContext != null) {
      Scrollable.ensureVisible(
        targetContext,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _handleConsolidate() async {
    final messenger = ScaffoldMessenger.of(context);
    final result = await widget.memoryService.triggerOfflineConsolidation();
    if (!mounted) return;

    if (!result.success) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('⚠️ Consolidation error: ${result.errorMessage ?? "Failed to reach backend"}'),
          backgroundColor: SepiaTheme.terracotta,
          duration: const Duration(seconds: 4),
        ),
      );
    } else if (result.turnsConsolidated == 0 && result.nodesUpdated == 0) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('ℹ️ Ingestion queue is empty. No new turns to consolidate.'),
          backgroundColor: SepiaTheme.amber,
          duration: Duration(seconds: 3),
        ),
      );
    } else if (result.isOfflineFallback) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            '⚠️ Cloud offline: Local fallback consolidated ${result.turnsConsolidated} turn${result.turnsConsolidated == 1 ? "" : "s"} into ${result.nodesUpdated} node${result.nodesUpdated == 1 ? "" : "s"}.',
          ),
          backgroundColor: SepiaTheme.amber,
          duration: const Duration(seconds: 4),
        ),
      );
    } else {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            '✅ Consolidated ${result.turnsConsolidated} turn${result.turnsConsolidated == 1 ? "" : "s"} into ${result.nodesUpdated} durable node${result.nodesUpdated == 1 ? "" : "s"} via Gemini 3.8 Flash.',
          ),
          backgroundColor: SepiaTheme.sage,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _handleRepackBundle() {
    widget.memoryService.repackLocalEdgeBundle();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✅ Edge memory bundle repacked and synchronized (<50KB budget).'),
        backgroundColor: SepiaTheme.sage,
        duration: Duration(seconds: 3),
      ),
    );
  }

  void _handlePrefetchTopic(String topicId) {
    widget.memoryService.fetchMemoryTopic(topicId);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('📥 Topic "$topicId" prefetched from cloud dream into local SQLite cache.'),
        backgroundColor: SepiaTheme.amber,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _handleEvictTopic(String topicId) {
    widget.memoryService.evictMemoryTopic(topicId);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('☁️ Topic "$topicId" evicted to cloud dream storage.'),
        backgroundColor: SepiaTheme.slate,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _handlePruneContext(BuildContext context) {
    widget.memoryService.pruneWorkingContext(retainCount: 3);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('🧹 Pruned working context: retained newest 3 turns (LRU).'),
        backgroundColor: SepiaTheme.sage,
        duration: Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bundle = widget.memoryService.activeEdgeBundle;
    final isWithinBudget = bundle?.isWithinBudget ?? true;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 700;

        return Scaffold(
          backgroundColor: SepiaTheme.canvas,
          body: SingleChildScrollView(
            controller: _scrollController,
            padding: EdgeInsets.all(isMobile ? 12 : 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Header & Edge Bundle Budget Meter
                _buildStudioHeader(bundle, isWithinBudget, isMobile),
                const SizedBox(height: 16),

                // Hero Workstation: Hierarchical Memory Tree & Edge-to-Cloud Diff View
                KeyedSubtree(
                  key: _treeKey,
                  child: MemoryTreeView(
                    localTree: widget.memoryService.getLocalMemoryTree(sourceFilter: _selectedSourceFilter),
                    cloudTree: widget.memoryService.getCloudKnowledgeTree(sourceFilter: _selectedSourceFilter),
                    diffTree: widget.memoryService.getEdgeCloudDiffTree(sourceFilter: _selectedSourceFilter),
                    initialSegmentIndex: 2, // ⚡ Edge-Cloud Diff is the hero star
                    onConsolidateQueue: widget.memoryService.isConsolidating ? null : _handleConsolidate,
                    onRepackBundle: _handleRepackBundle,
                    onPrefetchTopic: _handlePrefetchTopic,
                    onEvictTopic: _handleEvictTopic,
                    onPruneContext: () => _handlePruneContext(context),
                    onInspectContradiction: (cr, node) {
                      _showContradictionDetailsDialog(context, node, cr.priorDirective);
                    },
                  ),
                ),
                const SizedBox(height: 16),

                // Mechanism Guide: Creation, Redaction, Usage, Removal
                _buildMemoryMechanismsGuide(),
                const SizedBox(height: 16),

                // Section A: Interactive Request/Response Lifecycle Diagram
                MemoryRequestResponseDiagram(
                  selectedStageIndex: _selectedStageIndex,
                  onStageSelected: _scrollToStage,
                  isOffline: widget.memoryService.isOfflinePartition,
                ),
                const SizedBox(height: 16),

                // Section B: Detailed Memory Lifecycle Cells (Stages 1 to 4)
                _buildCell1WorkingMemory(),
                const SizedBox(height: 14),
                _buildCell2ShortTermMemory(),
                const SizedBox(height: 14),
                _buildCell3LongTermMemory(),
                const SizedBox(height: 14),
                _buildCell4EdgeBundle(bundle),
                const SizedBox(height: 16),

                // Section D: Memory Pattern Simulator Bench
                MemoryPatternTester(
                  onInjectContradiction: () {
                    widget.memoryService.simulateInjectContradiction(
                      'Quantization Policy',
                      'Switch edge inference to FP16 32-bit floats for higher mathematical precision.',
                      'Prototyping high-precision floats for scientific math tasks, evaluated against RAM ceiling.',
                    );
                  },
                  onBudgetPressure: () {
                    widget.memoryService.simulateBudgetPressure(15);
                  },
                  onToggleOffline: () {
                    widget.memoryService.simulateOfflinePartition(!widget.memoryService.isOfflinePartition);
                  },
                  onReset: () {
                    widget.memoryService.resetSimulation();
                  },
                  isOffline: widget.memoryService.isOfflinePartition,
                  simulationLogs: widget.memoryService.simulationLogs,
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStudioHeader(CompactEdgeMemoryBundle? bundle, bool isWithinBudget, bool isMobile) {
    final sizeKb = bundle?.sizeKb ?? 0.0;
    final budgetFraction = (sizeKb / 50.0).clamp(0.0, 1.0);

    return Card(
      color: SepiaTheme.paper,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: SepiaTheme.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: SepiaTheme.paperSubtle,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: SepiaTheme.borderSubtle),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.build_circle_outlined, size: 12, color: SepiaTheme.inkMuted),
                  const SizedBox(width: 6),
                  Text(
                    'DEVELOPER TOOL // SYSTEM DIAGNOSTIC',
                    style: SepiaTheme.mono(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      color: SepiaTheme.inkMuted,
                    ),
                  ),
                ],
              ),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Memory Lifecycle Studio',
                        style: SepiaTheme.sans(fontSize: 18, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Dual-loop memory pipeline: online edge scratchpad with 0 cloud egress synchronized to Firestore durable graphs.',
                        style: SepiaTheme.sans(fontSize: 12, color: SepiaTheme.inkSecondary),
                      ),
                    ],
                  ),
                ),
                if (!isMobile) ...[
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    onPressed: widget.memoryService.isConsolidating ? null : _handleConsolidate,
                    icon: widget.memoryService.isConsolidating
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.sync_rounded, size: 16),
                    label: Text(widget.memoryService.isConsolidating ? 'Consolidating...' : 'Consolidate (Cloud Run)'),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 14),

            // Invariant Budget Bar
            Row(
              children: [
                SepiaTheme.statusDot(
                  isWithinBudget ? SepiaTheme.sage : SepiaTheme.terracotta,
                  isWithinBudget ? 'BUDGET PRESERVED (< 50 KB)' : 'OVER BUDGET (> 50 KB)',
                  textColor: isWithinBudget ? SepiaTheme.sage : SepiaTheme.terracotta,
                ),
                const Spacer(),
                SepiaTheme.metricText('Size', '${sizeKb.toStringAsFixed(1)} KB / 50.0 KB'),
                const SizedBox(width: 12),
                SepiaTheme.metricText('Anchors', '${bundle?.totalAnchors ?? 0}'),
                const SizedBox(width: 12),
                SepiaTheme.metricText('Version', 'v${bundle?.bundleVersion ?? 1}'),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: budgetFraction,
                minHeight: 6,
                backgroundColor: SepiaTheme.paperSubtle,
                color: isWithinBudget ? SepiaTheme.sage : SepiaTheme.terracotta,
              ),
            ),

            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  'SOURCE FILTER:',
                  style: SepiaTheme.sans(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                    color: SepiaTheme.inkMuted,
                  ),
                ),
                _buildFilterPill(
                  label: 'ALL SOURCES (${widget.memoryService.getAllItemsCount()})',
                  isSelected: _selectedSourceFilter == 'ALL',
                  onTap: () => setState(() => _selectedSourceFilter = 'ALL'),
                ),
                _buildFilterPill(
                  label: '⚔ LORECRAFT GAME WORLD (${widget.memoryService.getLoreCraftItemsCount()})',
                  isSelected: _selectedSourceFilter == 'LORECRAFT',
                  onTap: () => setState(() => _selectedSourceFilter = 'LORECRAFT'),
                  icon: Icons.auto_stories_rounded,
                ),
                _buildFilterPill(
                  label: '💬 ASSISTANT SHELL (${widget.memoryService.getAssistantItemsCount()})',
                  isSelected: _selectedSourceFilter == 'ASSISTANT',
                  onTap: () => setState(() => _selectedSourceFilter = 'ASSISTANT'),
                  icon: Icons.chat_bubble_outline_rounded,
                ),
              ],
            ),

            if (isMobile) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: widget.memoryService.isConsolidating ? null : _handleConsolidate,
                  icon: widget.memoryService.isConsolidating
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.sync_rounded, size: 16),
                  label: Text(widget.memoryService.isConsolidating ? 'Consolidating...' : 'Consolidate (Cloud Run)'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFilterPill({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    IconData? icon,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? SepiaTheme.ink : SepiaTheme.paperSubtle,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? SepiaTheme.ink : SepiaTheme.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 12, color: isSelected ? SepiaTheme.paper : SepiaTheme.inkMuted),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: SepiaTheme.sans(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? SepiaTheme.paper : SepiaTheme.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMemoryMechanismsGuide() {
    return Card(
      color: SepiaTheme.paper,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: SepiaTheme.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: () => setState(() => _isMechanismsGuideExpanded = !_isMechanismsGuideExpanded),
              borderRadius: BorderRadius.circular(4),
              child: Row(
                children: [
                  const Icon(Icons.school_outlined, size: 16, color: SepiaTheme.amber),
                  const SizedBox(width: 8),
                  Text(
                    'HOW MEMORY WORKS: 4 CORE MECHANISMS',
                    style: SepiaTheme.sans(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      color: SepiaTheme.ink,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    _isMechanismsGuideExpanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                    size: 18,
                    color: SepiaTheme.inkMuted,
                  ),
                ],
              ),
            ),
            if (_isMechanismsGuideExpanded) ...[
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth > 900;
                  final cards = [
                    _buildMechanismCard(
                      stepNumber: '1',
                      title: 'Memory Creation',
                      icon: Icons.add_circle_outline_rounded,
                      color: SepiaTheme.sage,
                      headline: 'Turn Capture -> Working Context',
                      howItWorks:
                          'Player interaction or prompt is executed -> Structured into an EpisodicTurn with extracted entities (NPCs, Factions, Directives) -> Committed to local RAM (<2 GB ceiling) and queued into SQLite.',
                    ),
                    _buildMechanismCard(
                      stepNumber: '2',
                      title: 'PII Redaction',
                      icon: Icons.security_rounded,
                      color: SepiaTheme.terracotta,
                      headline: 'On-Device Scrubbing -> Route Lock',
                      howItWorks:
                          'Local regex detects credentials, phone numbers, or emails -> Replaces matches with [REDACTED_...] masks -> Router enforces EDGE_LOCAL lock ensuring 0 KB cloud egress.',
                    ),
                    _buildMechanismCard(
                      stepNumber: '3',
                      title: 'Memory Usage',
                      icon: Icons.auto_stories_rounded,
                      color: SepiaTheme.amber,
                      headline: 'Distilled Edge Bundle (<50 KB) Grounding',
                      howItWorks:
                          'Durable knowledge is distilled into compact anchors (<50 KB) -> Loaded into RAM -> Pre-injected into Gemma 4 system prompt at 0ms latency without cloud API overhead.',
                    ),
                    _buildMechanismCard(
                      stepNumber: '4',
                      title: 'Removal & Consolidation',
                      icon: Icons.cleaning_services_rounded,
                      color: SepiaTheme.slate,
                      headline: 'LRU Eviction + Cloud Run Harmonization',
                      howItWorks:
                          'Oldest turns are evicted from RAM via LRU. When online, pending queue syncs to Cloud Run where Gemini 3.8 Flash resolves contradictions into the immutable Firestore graph.',
                    ),
                  ];

                  if (isWide) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: cards
                          .map((c) => Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 4),
                                  child: c,
                                ),
                              ))
                          .toList(),
                    );
                  } else {
                    return Column(
                      children: cards
                          .map((c) => Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: c,
                              ))
                          .toList(),
                    );
                  }
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMechanismCard({
    required String stepNumber,
    required String title,
    required IconData icon,
    required Color color,
    required String headline,
    required String howItWorks,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: SepiaTheme.paperSubtle,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: SepiaTheme.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 18,
                height: 18,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                child: Text(
                  stepNumber,
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: SepiaTheme.sans(fontSize: 11, fontWeight: FontWeight.w700, color: SepiaTheme.ink),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(icon, size: 14, color: color),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            headline,
            style: SepiaTheme.mono(fontSize: 10, fontWeight: FontWeight.w600, color: color),
          ),
          const SizedBox(height: 4),
          Text(
            howItWorks,
            style: SepiaTheme.sans(fontSize: 11, color: SepiaTheme.inkSecondary, height: 1.35),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // Notebook Cells (Stages 1 to 4)
  // ==========================================

  Widget _buildCell1WorkingMemory() {
    final turns = widget.memoryService.getWorkingContextForSource(_selectedSourceFilter);

    return KeyedSubtree(
      key: _cell1Key,
      child: MemoryNotebookCell(
        cellIndex: 1,
        title: 'Working Memory (Active Context Window & Scratchpad)',
        domain: 'EDGE RAM',
        accentColor: SepiaTheme.sage,
        conceptSummary:
            'Working memory represents the active context window and immediate scratchpad of the Gemma 4 int4 model. It holds prompt tokens, immediate tool calls, and injected anchors for active execution (<60ms TTFT).',
        edgeConstraintDetail:
            'Bound to < 2 GB RAM headroom to prevent macOS watchdog panics and satisfy Android LiteRT 1.4 GB limits. Working memory cannot be flooded with raw multi-turn history.',
        actions: [
          OutlinedButton.icon(
            onPressed: () => _showPruneDialog(context),
            icon: const Icon(Icons.cleaning_services_rounded, size: 14),
            label: const Text('Prune Context (LRU)'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              textStyle: SepiaTheme.sans(fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ),
        ],
        liveContent: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SepiaTheme.statusDot(SepiaTheme.sage, 'Active Session Context'),
                const Spacer(),
                SepiaTheme.metricText('Turns Loaded', '${turns.length}'),
              ],
            ),
            const SizedBox(height: 8),
            if (turns.isEmpty)
              Text('No active working turns for source "$_selectedSourceFilter".',
                  style: SepiaTheme.sans(fontSize: 12, color: SepiaTheme.inkMuted))
            else
              for (final turn in turns) _buildTurnRow(turn),
          ],
        ),
      ),
    );
  }

  Widget _buildTurnRow(EpisodicTurn turn) {
    final isLoreCraft = turn.sessionId.toLowerCase().contains('lorecraft');
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: SepiaTheme.paperSubtle,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: SepiaTheme.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isLoreCraft ? SepiaTheme.amber.withValues(alpha: 0.15) : SepiaTheme.paper,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: isLoreCraft ? SepiaTheme.amber.withValues(alpha: 0.5) : SepiaTheme.borderSubtle,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isLoreCraft ? Icons.auto_stories_rounded : Icons.chat_bubble_outline_rounded,
                      size: 10,
                      color: isLoreCraft ? SepiaTheme.amber : SepiaTheme.inkMuted,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isLoreCraft ? '⚔ LORECRAFT GAME' : '💬 ASSISTANT',
                      style: SepiaTheme.mono(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: isLoreCraft ? SepiaTheme.amber : SepiaTheme.inkMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              SepiaTheme.statusDot(
                turn.isPiiSanitized ? SepiaTheme.sage : SepiaTheme.slate,
                turn.isPiiSanitized ? '🔒 PII Scrubbed' : '● Clean',
              ),
              const SizedBox(width: 8),
              Text(
                turn.id,
                style: SepiaTheme.mono(fontSize: 10, color: SepiaTheme.inkMuted),
              ),
              const Spacer(),
              Text(
                '${turn.latencyMs}ms (${turn.modelName})',
                style: SepiaTheme.mono(fontSize: 10, color: SepiaTheme.inkSecondary),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'User: ${turn.userPrompt}',
            style: SepiaTheme.sans(fontSize: 12, fontWeight: FontWeight.w600, color: SepiaTheme.ink),
          ),
          const SizedBox(height: 3),
          Text(
            'Model: ${turn.modelResponse}',
            style: SepiaTheme.sans(fontSize: 11, color: SepiaTheme.inkSecondary),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (turn.entitiesExtracted.isNotEmpty) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: turn.entitiesExtracted.map((e) {
                return Text(
                  '${e.entityType}: ${e.entityValue}',
                  style: SepiaTheme.mono(fontSize: 10, color: SepiaTheme.inkMuted),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCell2ShortTermMemory() {
    final queue = widget.memoryService.getIngestionQueueForSource(_selectedSourceFilter);

    return KeyedSubtree(
      key: _cell2Key,
      child: MemoryNotebookCell(
        cellIndex: 2,
        title: 'Short-Term Memory & Cloud Ingestion Queue',
        domain: 'EDGE SQLite -> CLOUD',
        accentColor: SepiaTheme.sage,
        conceptSummary:
            'Short-term memory stores episodic interaction turns locally in SQLite/IndexedDB across active sessions. It enforces the privacy gate: local regex and Gemma 4 scrub PII before turns queue for cloud transfer.',
        edgeConstraintDetail:
            'Zero Cloud Egress for PII: Raw contact info and credentials never leave local storage. Turns queued for cloud batch consolidation are strictly sanitized.',
        actions: [
          OutlinedButton.icon(
            onPressed: (queue.isEmpty || widget.memoryService.isConsolidating) ? null : _handleConsolidate,
            icon: widget.memoryService.isConsolidating
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: SepiaTheme.sage),
                  )
                : const Icon(Icons.cloud_upload_outlined, size: 14),
            label: Text(widget.memoryService.isConsolidating ? 'Draining...' : 'Drain Queue to Cloud'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              textStyle: SepiaTheme.sans(fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ),
        ],
        liveContent: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SepiaTheme.statusDot(SepiaTheme.amber, 'Awaiting Asynchronous Batch Consolidation'),
                const Spacer(),
                SepiaTheme.metricText('Pending Turns', '${queue.length}'),
              ],
            ),
            const SizedBox(height: 8),
            if (queue.isEmpty)
              Text('Ingestion queue is empty. All local turns consolidated.',
                  style: SepiaTheme.sans(fontSize: 12, color: SepiaTheme.inkMuted))
            else
              for (final item in queue)
                Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: SepiaTheme.paperSubtle,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: SepiaTheme.borderSubtle),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.hourglass_empty_rounded, size: 14, color: SepiaTheme.amber),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          item.userPrompt,
                          style: SepiaTheme.sans(fontSize: 11, fontWeight: FontWeight.w500),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        'Route: ${item.route}',
                        style: SepiaTheme.mono(fontSize: 10, color: SepiaTheme.inkMuted),
                      ),
                    ],
                  ),
                ),
          ],
        ),
      ),
    );
  }

  Widget _buildCell3LongTermMemory() {
    final nodes = widget.memoryService.getDurableNodesForSource(_selectedSourceFilter);

    return KeyedSubtree(
      key: _cell3Key,
      child: MemoryNotebookCell(
        cellIndex: 3,
        title: 'Long-Term Memory & Cloud Knowledge Graph',
        domain: 'CLOUD FIRESTORE',
        accentColor: SepiaTheme.amber,
        conceptSummary:
            'Long-term memory is the persistent semantic knowledge graph hosted in Cloud Firestore. Offline batch jobs powered by Gemini 3.8 Flash consolidate turns, merge duplicate entities, and reconcile factual contradictions.',
        edgeConstraintDetail:
            'Dual-Loop Synchronization: Expensive graph reconciliations run on Cloud Run L4 GPUs/CPUs. Distilled knowledge is compiled into compact bundles for zero-latency edge use.',
        actions: [
          OutlinedButton.icon(
            onPressed: widget.memoryService.isConsolidating ? null : _handleConsolidate,
            icon: widget.memoryService.isConsolidating
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: SepiaTheme.amber),
                  )
                : const Icon(Icons.auto_awesome_rounded, size: 14, color: SepiaTheme.amber),
            label: Text(widget.memoryService.isConsolidating ? 'Consolidating...' : 'Consolidate (Gemini 3.8 Flash)'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              textStyle: SepiaTheme.sans(fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ),
        ],
        liveContent: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SepiaTheme.statusDot(SepiaTheme.sage, 'Consolidated Durable Knowledge Entities'),
                const Spacer(),
                SepiaTheme.metricText('Total Nodes', '${nodes.length}'),
              ],
            ),
            const SizedBox(height: 8),
            for (final node in nodes) _buildDurableNodeItem(node),
          ],
        ),
      ),
    );
  }

  Widget _buildDurableNodeItem(DurableKnowledgeNode node) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: SepiaTheme.paperSubtle,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: SepiaTheme.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SepiaTheme.quietLabel(node.category, color: SepiaTheme.amber),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  node.entityName,
                  style: SepiaTheme.sans(fontSize: 13, fontWeight: FontWeight.w700),
                ),
              ),
              SepiaTheme.metricText('Confidence', '${(node.confidence * 100).toInt()}%'),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            node.summary,
            style: SepiaTheme.sans(fontSize: 12, color: SepiaTheme.inkSecondary),
          ),
          if (node.resolvedContradictions.isNotEmpty) ...[
            const SizedBox(height: 6),
            InkWell(
              onTap: () {
                _showContradictionDetailsDialog(context, node, node.resolvedContradictions.first);
              },
              borderRadius: BorderRadius.circular(4),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    const Icon(Icons.rule_folder_rounded, size: 14, color: SepiaTheme.terracotta),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Contradiction Resolved: ${node.resolvedContradictions.first}',
                        style: SepiaTheme.sans(fontSize: 11, fontWeight: FontWeight.w600, color: SepiaTheme.terracotta),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      'Inspect Audit Trail ➔',
                      style: SepiaTheme.sans(fontSize: 11, fontWeight: FontWeight.w700, color: SepiaTheme.terracotta),
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (node.relations.isNotEmpty) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              children: node.relations.map((r) {
                return Text(
                  '${r.predicate} ➔ ${r.targetNodeId}',
                  style: SepiaTheme.mono(fontSize: 10, color: SepiaTheme.inkMuted),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCell4EdgeBundle(CompactEdgeMemoryBundle? bundle) {
    final anchors = widget.memoryService.getEdgeAnchorsForSource(_selectedSourceFilter);

    return KeyedSubtree(
      key: _cell4Key,
      child: MemoryNotebookCell(
        cellIndex: 4,
        title: 'Compact Edge Memory Bundle Invariant (< 50 KB)',
        domain: 'CLOUD -> EDGE SYNC',
        accentColor: SepiaTheme.terracotta,
        conceptSummary:
            'The edge cannot query Firestore or execute expensive vector traversals during fast turns. The cloud packages the highest-priority anchors into a packed JSON payload strictly under 50 KB for zero-latency prompt hydration.',
        edgeConstraintDetail:
            'Strict 50 KB Payload Invariant: If durable knowledge grows beyond 50,000 bytes, lower-ranked anchors are pruned or compressed to guarantee instant hydration.',
        actions: [
          OutlinedButton.icon(
            onPressed: () {
              widget.memoryService.repackLocalEdgeBundle();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('✅ Edge memory bundle repacked and synchronized.'),
                  backgroundColor: SepiaTheme.sage,
                  duration: Duration(seconds: 3),
                ),
              );
            },
            icon: const Icon(Icons.archive_outlined, size: 14),
            label: const Text('Repack Local Edge Bundle'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              textStyle: SepiaTheme.sans(fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ),
        ],
        liveContent: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SepiaTheme.statusDot(SepiaTheme.sage, 'Loaded Anchors Ready for On-Device Prompt Grounding'),
                const Spacer(),
                SepiaTheme.metricText('Anchors', '${anchors.length}'),
              ],
            ),
            const SizedBox(height: 8),
            for (final anchor in anchors)
              Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: SepiaTheme.paperSubtle,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: SepiaTheme.borderSubtle),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.anchor_rounded, size: 14, color: SepiaTheme.sage),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                anchor.key,
                                style: SepiaTheme.sans(fontSize: 12, fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(width: 8),
                              SepiaTheme.quietLabel(anchor.category),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            anchor.distilledContext,
                            style: SepiaTheme.sans(fontSize: 11, color: SepiaTheme.inkSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // Dialogs & Modals
  // ==========================================

  void _showPruneDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: SepiaTheme.canvas,
        title: Text('Prune Working Context (LRU)', style: SepiaTheme.sans(fontSize: 16, fontWeight: FontWeight.w700)),
        content: Text(
          'Prunes local working context turns beyond the retain count (5 turns), freeing memory headroom while preserving recent episodic state.',
          style: SepiaTheme.sans(fontSize: 13, color: SepiaTheme.inkSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final freed = widget.memoryService.pruneWorkingContext(retainCount: 5);
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Pruned working context: freed $freed bytes.'),
                  backgroundColor: SepiaTheme.sage,
                  duration: const Duration(seconds: 3),
                ),
              );
            },
            child: const Text('Prune'),
          ),
        ],
      ),
    );
  }

  void _showContradictionDetailsDialog(BuildContext context, DurableKnowledgeNode node, String contradictionText) {
    ContradictionRecord? matchingRecord;
    for (final r in node.contradictionRecords) {
      if (r.priorDirective == contradictionText ||
          (contradictionText.contains('FP16') && r.priorDirective.contains('FP16'))) {
        matchingRecord = r;
        break;
      }
    }
    if (matchingRecord == null && node.contradictionRecords.isNotEmpty) {
      matchingRecord = node.contradictionRecords.first;
    }

    final priorDirective = matchingRecord?.priorDirective ?? contradictionText;
    final rationale = (matchingRecord != null && matchingRecord.rationale.isNotEmpty)
        ? matchingRecord.rationale
        : 'int4 quantization supersedes earlier FP16 roadmap trial to prevent macOS memory panics and comply with Android LiteRT 1.4 GB RAM ceilings.';

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: SepiaTheme.canvas,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: SepiaTheme.border),
        ),
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        actionsPadding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: SepiaTheme.amberBg,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(Icons.published_with_changes_rounded, size: 18, color: SepiaTheme.amber),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'CONTRADICTION RESOLUTION AUDIT',
                    style: SepiaTheme.sans(fontSize: 14, fontWeight: FontWeight.w700, color: SepiaTheme.ink),
                  ),
                  Text(
                    node.entityName,
                    style: SepiaTheme.mono(fontSize: 11, color: SepiaTheme.inkMuted),
                  ),
                ],
              ),
            ),
            SepiaTheme.quietLabel(node.category, color: SepiaTheme.amber),
          ],
        ),
        content: SizedBox(
          width: 540,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Active Rule
                Text(
                  'ACTIVE RULE (CURRENT INVARIANT)',
                  style: SepiaTheme.mono(fontSize: 10, fontWeight: FontWeight.w700, color: SepiaTheme.sage),
                ),
                const SizedBox(height: 4),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: SepiaTheme.paper,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: SepiaTheme.sageBorder),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.check_circle_outline_rounded, size: 16, color: SepiaTheme.sage),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          node.summary,
                          style: SepiaTheme.sans(fontSize: 12, fontWeight: FontWeight.w600, color: SepiaTheme.ink),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Superseded Directive
                Text(
                  'SUPERSEDED DIRECTIVE (PRIOR STATE)',
                  style: SepiaTheme.mono(fontSize: 10, fontWeight: FontWeight.w700, color: SepiaTheme.terracotta),
                ),
                const SizedBox(height: 4),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: SepiaTheme.terracottaBg.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: SepiaTheme.terracottaBorder),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.history_toggle_off_rounded, size: 16, color: SepiaTheme.terracotta),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          priorDirective,
                          style: SepiaTheme.sans(fontSize: 12, color: SepiaTheme.inkSecondary),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Consolidation Reasoning (Gemini 3.8 Flash)
                Text(
                  'CONSOLIDATION REASONING (GEMINI 3.8 FLASH)',
                  style: SepiaTheme.mono(fontSize: 10, fontWeight: FontWeight.w700, color: SepiaTheme.amber),
                ),
                const SizedBox(height: 4),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: SepiaTheme.paper,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: SepiaTheme.amberBorder),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.psychology_rounded, size: 16, color: SepiaTheme.amber),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          rationale,
                          style: SepiaTheme.sans(fontSize: 12, color: SepiaTheme.inkSecondary, height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Connected Episodes
                Text(
                  'CONNECTED EPISODES',
                  style: SepiaTheme.mono(fontSize: 10, fontWeight: FontWeight.w700, color: SepiaTheme.inkMuted),
                ),
                const SizedBox(height: 6),
                if (node.sourceEpisodeIds.isEmpty)
                  Text('No source episodes linked.', style: SepiaTheme.sans(fontSize: 11, color: SepiaTheme.inkMuted))
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: node.sourceEpisodeIds.map((epId) {
                      return Text(
                        epId,
                        style: SepiaTheme.mono(fontSize: 10, color: SepiaTheme.inkSecondary),
                      );
                    }).toList(),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            style: TextButton.styleFrom(foregroundColor: SepiaTheme.terracotta),
            onPressed: () {
              widget.memoryService.revertContradiction(node.id, contradictionText);
              Navigator.of(dialogCtx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Reverted to prior directive'),
                  backgroundColor: SepiaTheme.terracotta,
                  duration: Duration(seconds: 3),
                ),
              );
            },
            child: const Text('Revert Resolution'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('Keep Active Rule'),
          ),
        ],
      ),
    );
  }
}
