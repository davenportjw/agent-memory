import 'package:flutter/material.dart';
import '../../models/memory_tree_node.dart';
import '../../models/memory_node.dart';
import '../../models/edge_memory_architecture.dart';
import '../../theme/sepia_theme.dart';

/// Interactive Dual/Triple-Tree Memory Hierarchy Widget
/// Renders:
/// 1) Local Memory Tree (SQLite WASM / RAM / Working Turns / Anchors)
/// 2) Cloud Knowledge Graph Tree (Firestore / Categories / Relations / Contradiction Audits)
/// 3) Edge-Cloud Diff Tree (Hierarchical delta of pending turns, synced/conflict durable nodes, and topic cache)
///
/// Responsive: Segmented control navigation across devices, with an optional
/// side-by-side split view available on desktop screens (>=1050px).
class MemoryTreeView extends StatefulWidget {
  final MemoryTreeNode localTree;
  final MemoryTreeNode cloudTree;
  final MemoryTreeNode? diffTree;
  final void Function(ContradictionRecord record, DurableKnowledgeNode node) onInspectContradiction;
  final int initialSegmentIndex;
  final VoidCallback? onConsolidateQueue;
  final VoidCallback? onRepackBundle;
  final ValueChanged<String>? onPrefetchTopic;
  final ValueChanged<String>? onEvictTopic;
  final VoidCallback? onPruneContext;

  const MemoryTreeView({
    super.key,
    required this.localTree,
    required this.cloudTree,
    this.diffTree,
    required this.onInspectContradiction,
    this.initialSegmentIndex = 2,
    this.onConsolidateQueue,
    this.onRepackBundle,
    this.onPrefetchTopic,
    this.onEvictTopic,
    this.onPruneContext,
  });

  @override
  State<MemoryTreeView> createState() => _MemoryTreeViewState();
}

class _MemoryTreeViewState extends State<MemoryTreeView> {
  late int _segmentedIndex; // 0: Local Tree, 1: Cloud Tree, 2: Diff / Sync, 3: Side-by-side Split
  final Set<String> _collapsedNodeIds = {};

  @override
  void initState() {
    super.initState();
    _segmentedIndex = widget.initialSegmentIndex;
  }

  bool _isNodeExpanded(MemoryTreeNode node) {
    if (_collapsedNodeIds.contains(node.id)) return false;
    return node.isExpanded;
  }

  void _toggleNode(MemoryTreeNode node) {
    setState(() {
      if (_isNodeExpanded(node)) {
        _collapsedNodeIds.add(node.id);
      } else {
        _collapsedNodeIds.remove(node.id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final effectiveDiffTree = widget.diffTree ?? widget.localTree;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktopSplit = constraints.maxWidth >= 1050;

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
                _buildHeader(context, isDesktopSplit),
                const SizedBox(height: 12),
                _buildSegmentedControl(isDesktopSplit),
                const SizedBox(height: 12),
                if (isDesktopSplit && _segmentedIndex == 3)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _buildTreePanel(
                          title: '📱 Local Edge Memory Tree',
                          subtitle: 'SQLite WASM & RAM (0ms Access / Zero Egress)',
                          accentColor: SepiaTheme.sage,
                          rootNode: widget.localTree,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildTreePanel(
                          title: '☁️ Cloud Durable Knowledge Tree',
                          subtitle: 'Firestore Native & Gemini 3.8 Flash Reconciled',
                          accentColor: SepiaTheme.amber,
                          rootNode: widget.cloudTree,
                        ),
                      ),
                    ],
                  )
                else if (_segmentedIndex == 0)
                  _buildTreePanel(
                    title: '📱 Local Edge Memory Tree',
                    subtitle: 'SQLite WASM & RAM (0ms Access / Zero Egress)',
                    accentColor: SepiaTheme.sage,
                    rootNode: widget.localTree,
                  )
                else if (_segmentedIndex == 1)
                  _buildTreePanel(
                    title: '☁️ Cloud Durable Knowledge Tree',
                    subtitle: 'Firestore Native & Gemini 3.8 Flash Reconciled',
                    accentColor: SepiaTheme.amber,
                    rootNode: widget.cloudTree,
                  )
                else ...[
                  _buildSyncDiffSummary(effectiveDiffTree),
                  _buildTreePanel(
                    title: '⚡ Edge-to-Cloud Difference Tree',
                    subtitle: 'Hierarchical structural delta: Local SQLite/RAM vs. Cloud Firestore Graph',
                    accentColor: SepiaTheme.terracotta,
                    rootNode: effectiveDiffTree,
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, bool isDesktopSplit) {
    return Row(
      children: [
        const Icon(Icons.account_tree_rounded, size: 18, color: SepiaTheme.ink),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hierarchical Memory Tree: Local Cache vs. Cloud Knowledge Graph',
                style: SepiaTheme.sans(fontSize: 14, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 2),
              Text(
                'Inspect hierarchical node dependencies, entity relations, and contradiction resolution audits.',
                style: SepiaTheme.sans(fontSize: 12, color: SepiaTheme.inkMuted),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSegmentedControl(bool isDesktopSplit) {
    return Container(
      decoration: BoxDecoration(
        color: SepiaTheme.paperSubtle,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: SepiaTheme.borderSubtle),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildSegmentButton('📱 Local Edge Tree', 0),
          ),
          Expanded(
            child: _buildSegmentButton('☁️ Cloud Graph Tree', 1),
          ),
          Expanded(
            child: _buildSegmentButton('⚡ Edge-Cloud Diff', 2),
          ),
          if (isDesktopSplit)
            Expanded(
              child: _buildSegmentButton('🔀 Split View', 3),
            ),
        ],
      ),
    );
  }

  Widget _buildSegmentButton(String text, int index) {
    final isSelected = _segmentedIndex == index;
    return InkWell(
      onTap: () => setState(() => _segmentedIndex = index),
      borderRadius: BorderRadius.circular(5),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? SepiaTheme.paper : Colors.transparent,
          borderRadius: BorderRadius.circular(5),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Center(
          child: Text(
            text,
            style: SepiaTheme.sans(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected ? SepiaTheme.ink : SepiaTheme.inkMuted,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTreePanel({
    required String title,
    required String subtitle,
    required Color accentColor,
    required MemoryTreeNode rootNode,
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
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: accentColor, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: SepiaTheme.sans(fontSize: 13, fontWeight: FontWeight.w700, color: SepiaTheme.ink),
                ),
              ),
              if (rootNode.metric != null)
                Text(
                  rootNode.metric!,
                  style: SepiaTheme.mono(fontSize: 10, color: SepiaTheme.inkMuted),
                ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: SepiaTheme.sans(fontSize: 11, color: SepiaTheme.inkMuted),
          ),
          const SizedBox(height: 10),
          const Divider(height: 1, color: SepiaTheme.borderSubtle),
          const SizedBox(height: 8),
          _buildNodeRow(rootNode, depth: 0),
        ],
      ),
    );
  }

  Widget _buildNodeRow(MemoryTreeNode node, {required int depth}) {
    final hasChildren = node.children.isNotEmpty;
    final isExpanded = _isNodeExpanded(node);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () {
            if (hasChildren) {
              _toggleNode(node);
            } else if (node.nodeType == MemoryNodeType.contradiction || node.metadata.containsKey('contradiction')) {
              final cr = node.metadata['contradiction'] as ContradictionRecord?;
              final dn = node.metadata['node'] as DurableKnowledgeNode?;
              if (cr != null && dn != null) {
                widget.onInspectContradiction(cr, dn);
              }
            }
          },
          borderRadius: BorderRadius.circular(4),
          child: Padding(
            padding: EdgeInsets.only(
              left: depth * 14.0,
              top: 4,
              bottom: 4,
              right: 6,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (hasChildren)
                  Padding(
                    padding: const EdgeInsets.only(top: 2, right: 4),
                    child: Icon(
                      isExpanded ? Icons.arrow_drop_down_rounded : Icons.arrow_right_rounded,
                      size: 18,
                      color: SepiaTheme.inkMuted,
                    ),
                  )
                else
                  const SizedBox(width: 18),
                _buildNodeIcon(node.nodeType),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              node.label,
                              style: SepiaTheme.sans(
                                fontSize: depth == 0 ? 12 : 11,
                                fontWeight: depth <= 1 ? FontWeight.w700 : FontWeight.w500,
                                color: SepiaTheme.ink,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (node.status != null) ...[
                            const SizedBox(width: 6),
                            _buildQuietStatus(node.status!),
                          ],
                        ],
                      ),
                      if (node.subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          node.subtitle!,
                          style: SepiaTheme.sans(
                            fontSize: 10,
                            color: SepiaTheme.inkMuted,
                            height: 1.25,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      if (node.nodeType == MemoryNodeType.contradiction) ...[
                        const SizedBox(height: 4),
                        InkWell(
                          onTap: () {
                            final cr = node.metadata['contradiction'] as ContradictionRecord?;
                            final dn = node.metadata['node'] as DurableKnowledgeNode?;
                            if (cr != null && dn != null) {
                              widget.onInspectContradiction(cr, dn);
                            }
                          },
                          child: Row(
                            children: [
                              const Icon(Icons.find_in_page_outlined, size: 12, color: SepiaTheme.terracotta),
                              const SizedBox(width: 4),
                              Text(
                                'Click to inspect full contradiction audit trail ➔',
                                style: SepiaTheme.sans(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: SepiaTheme.terracotta,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      if (node.metadata['entry'] is MasterIndexEntry) ...[
                        const SizedBox(height: 4),
                        Builder(
                          builder: (context) {
                            final entry = node.metadata['entry'] as MasterIndexEntry;
                            return Row(
                              children: [
                                if (entry.isCachedLocally)
                                  InkWell(
                                    key: Key('topic-evict-${entry.topicId}'),
                                    onTap: widget.onEvictTopic != null
                                        ? () => widget.onEvictTopic!(entry.topicId)
                                        : null,
                                    borderRadius: BorderRadius.circular(4),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: SepiaTheme.paperSubtle,
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(color: SepiaTheme.borderSubtle),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.cloud_upload_outlined, size: 11, color: SepiaTheme.slate),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Evict to Cloud Dream',
                                            style: SepiaTheme.sans(fontSize: 10, fontWeight: FontWeight.w600, color: SepiaTheme.slate),
                                          ),
                                        ],
                                      ),
                                    ),
                                  )
                                else
                                  InkWell(
                                    key: Key('topic-prefetch-${entry.topicId}'),
                                    onTap: widget.onPrefetchTopic != null
                                        ? () => widget.onPrefetchTopic!(entry.topicId)
                                        : null,
                                    borderRadius: BorderRadius.circular(4),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: SepiaTheme.paperSubtle,
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(color: SepiaTheme.border),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.download_rounded, size: 11, color: SepiaTheme.amber),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Prefetch to Edge Cache',
                                            style: SepiaTheme.sans(fontSize: 10, fontWeight: FontWeight.w600, color: SepiaTheme.amber),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                              ],
                            );
                          },
                        ),
                      ],
                      if (node.id == 'diff-branch-pending' &&
                          node.children.isNotEmpty &&
                          node.children.first.id != 'diff-pending-clean') ...[
                        const SizedBox(height: 4),
                        InkWell(
                          key: const Key('inline-consolidate-queue'),
                          onTap: widget.onConsolidateQueue,
                          borderRadius: BorderRadius.circular(4),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: SepiaTheme.amber.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: SepiaTheme.amber),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.bolt_rounded, size: 12, color: SepiaTheme.amber),
                                const SizedBox(width: 4),
                                Text(
                                  'Consolidate Queue Now ➔',
                                  style: SepiaTheme.sans(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: SepiaTheme.amber,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (node.metric != null) ...[
                  const SizedBox(width: 6),
                  Text(
                    node.metric!,
                    style: SepiaTheme.mono(fontSize: 10, color: SepiaTheme.inkMuted),
                  ),
                ],
              ],
            ),
          ),
        ),
        if (hasChildren && isExpanded)
          for (final child in node.children)
            _buildNodeRow(child, depth: depth + 1),
      ],
    );
  }

  Widget _buildNodeIcon(MemoryNodeType type) {
    IconData icon;
    Color color;

    switch (type) {
      case MemoryNodeType.storeRoot:
        icon = Icons.folder_open_rounded;
        color = SepiaTheme.inkSecondary;
        break;
      case MemoryNodeType.category:
        icon = Icons.category_outlined;
        color = SepiaTheme.amber;
        break;
      case MemoryNodeType.entityNode:
        icon = Icons.layers_outlined;
        color = SepiaTheme.slate;
        break;
      case MemoryNodeType.relation:
        icon = Icons.link_rounded;
        color = SepiaTheme.inkMuted;
        break;
      case MemoryNodeType.contradiction:
        icon = Icons.rule_folder_rounded;
        color = SepiaTheme.terracotta;
        break;
      case MemoryNodeType.turn:
        icon = Icons.chat_bubble_outline_rounded;
        color = SepiaTheme.sage;
        break;
      case MemoryNodeType.anchor:
        icon = Icons.anchor_rounded;
        color = SepiaTheme.sage;
        break;
      case MemoryNodeType.attribute:
        icon = Icons.data_object_rounded;
        color = SepiaTheme.inkMuted;
        break;
      case MemoryNodeType.diffSynced:
        icon = Icons.check_circle_outline_rounded;
        color = SepiaTheme.sage;
        break;
      case MemoryNodeType.diffAdded:
        icon = Icons.add_circle_outline_rounded;
        color = SepiaTheme.amber;
        break;
      case MemoryNodeType.diffRemoved:
        icon = Icons.cloud_outlined;
        color = SepiaTheme.slate;
        break;
      case MemoryNodeType.diffModified:
        icon = Icons.change_circle_outlined;
        color = SepiaTheme.terracotta;
        break;
    }

    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Icon(icon, size: 14, color: color),
    );
  }

  Widget _buildQuietStatus(String status) {
    Color dotColor = SepiaTheme.inkMuted;
    if (status.contains('Clean') ||
        status.contains('CONSOLIDATED') ||
        status.contains('RESOLVED') ||
        status.contains('Synced') ||
        status.contains('LOCAL CACHE') ||
        status.contains('ONLINE')) {
      dotColor = SepiaTheme.sage;
    } else if (status.contains('PII') || status.contains('SECURITY')) {
      dotColor = SepiaTheme.sage;
    } else if (status.contains('CONFLICT') ||
        status.contains('AWAITING') ||
        status.contains('MODIFIED') ||
        status.contains('OVER BUDGET') ||
        status.contains('OFFLINE')) {
      dotColor = SepiaTheme.terracotta;
    } else if (status.contains('Pending') ||
        status.contains('Edge Only') ||
        status.contains('Local RAM') ||
        status.contains('RAM Synced')) {
      dotColor = SepiaTheme.amber;
    } else if (status.contains('Cloud Only') ||
        status.contains('CLOUD DREAM') ||
        status.contains('Dormant') ||
        status.contains('Firestore')) {
      dotColor = SepiaTheme.slate;
    }

    return SepiaTheme.statusDot(dotColor, status, fontSize: 10);
  }

  Widget _buildSyncDiffSummary(MemoryTreeNode diffTree) {
    final pendingCount = diffTree.metadata['pendingCount'] as int? ?? 0;
    final syncedCount = diffTree.metadata['syncedCount'] as int? ?? 0;
    final cloudOnlyCount = diffTree.metadata['cloudOnlyCount'] as int? ?? 0;
    final modifiedCount = diffTree.metadata['modifiedCount'] as int? ?? 0;
    final totalDurable = diffTree.metadata['totalDurable'] as int? ?? 0;
    final totalAnchors = diffTree.metadata['totalAnchors'] as int? ?? 0;
    final bundleSizeKb = diffTree.metadata['bundleSizeKb'] as String? ?? '0.0';
    final isWithinBudget = diffTree.metadata['isWithinBudget'] as bool? ?? true;
    final isOffline = diffTree.metadata['isOffline'] as bool? ?? false;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
              const Icon(Icons.sync_alt_rounded, size: 14, color: SepiaTheme.amber),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '⚡ Edge-to-Cloud Delta & Synchronization Status',
                  style: SepiaTheme.sans(fontSize: 12, fontWeight: FontWeight.w700),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              SepiaTheme.statusDot(
                isOffline ? SepiaTheme.terracotta : SepiaTheme.sage,
                isOffline ? 'OFFLINE PARTITION' : 'ONLINE (Cloud Run)',
                fontSize: 10,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 16,
            runSpacing: 6,
            children: [
              _buildDiffMetric(
                'Pending Ingestion',
                '$pendingCount turn${pendingCount == 1 ? '' : 's'} awaiting cloud consolidation',
                pendingCount > 0 ? SepiaTheme.amber : SepiaTheme.sage,
              ),
              _buildDiffMetric(
                'Local Anchors vs Cloud',
                '$syncedCount synced · $totalAnchors loaded in RAM · $totalDurable durable in Firestore',
                SepiaTheme.sage,
              ),
              if (modifiedCount > 0)
                _buildDiffMetric(
                  'Conflict Drift',
                  '$modifiedCount node${modifiedCount == 1 ? '' : 's'} with resolved/active contradictions',
                  SepiaTheme.terracotta,
                ),
              if (cloudOnlyCount > 0)
                _buildDiffMetric(
                  'Cloud Only (Dormant)',
                  '$cloudOnlyCount durable node${cloudOnlyCount == 1 ? '' : 's'} evicted from RAM budget',
                  SepiaTheme.slate,
                ),
              _buildDiffMetric(
                'Edge RAM Budget',
                '$bundleSizeKb KB / 50.0 KB (${isWithinBudget ? "Preserving zero-egress budget" : "Exceeding mobile RAM limit"})',
                isWithinBudget ? SepiaTheme.sage : SepiaTheme.terracotta,
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: SepiaTheme.borderSubtle),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.bolt_rounded, size: 14, color: SepiaTheme.amber),
              const SizedBox(width: 6),
              Text(
                'Memory Movement Tasks (Edge ⮂ Cloud)',
                style: SepiaTheme.sans(fontSize: 11, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ElevatedButton.icon(
                key: const Key('diff-action-consolidate'),
                onPressed: pendingCount > 0 ? widget.onConsolidateQueue : null,
                icon: const Icon(Icons.cloud_upload_outlined, size: 13),
                label: Text(
                  pendingCount > 0
                      ? 'Consolidate $pendingCount Turns (Gemini 3.8 Flash)'
                      : 'Consolidate Queue (0 Pending)',
                  style: SepiaTheme.sans(fontSize: 11, fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: pendingCount > 0 ? SepiaTheme.amber : SepiaTheme.borderSubtle,
                  foregroundColor: pendingCount > 0 ? SepiaTheme.paper : SepiaTheme.inkMuted,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  visualDensity: VisualDensity.compact,
                ),
              ),
              OutlinedButton.icon(
                key: const Key('diff-action-repack'),
                onPressed: widget.onRepackBundle,
                icon: const Icon(Icons.compress_rounded, size: 13),
                label: Text(
                  'Repack Edge Bundle (<50KB)',
                  style: SepiaTheme.sans(fontSize: 11, fontWeight: FontWeight.w600),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: SepiaTheme.ink,
                  side: const BorderSide(color: SepiaTheme.border),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  visualDensity: VisualDensity.compact,
                ),
              ),
              OutlinedButton.icon(
                key: const Key('diff-action-prune'),
                onPressed: widget.onPruneContext,
                icon: const Icon(Icons.cleaning_services_outlined, size: 13),
                label: Text(
                  'Prune Working Context (LRU)',
                  style: SepiaTheme.sans(fontSize: 11, fontWeight: FontWeight.w600),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: SepiaTheme.inkSecondary,
                  side: const BorderSide(color: SepiaTheme.borderSubtle),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDiffMetric(String label, String value, Color color) {
    return Text.rich(
      TextSpan(
        style: SepiaTheme.sans(fontSize: 11, color: SepiaTheme.ink),
        children: [
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Container(
              width: 6,
              height: 6,
              margin: const EdgeInsets.only(right: 6),
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
          ),
          TextSpan(text: '$label: ', style: const TextStyle(fontWeight: FontWeight.w600)),
          TextSpan(text: value, style: TextStyle(color: SepiaTheme.inkSecondary)),
        ],
      ),
    );
  }
}
