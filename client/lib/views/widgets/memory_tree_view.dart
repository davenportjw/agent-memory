import 'package:flutter/material.dart';
import '../../models/memory_tree_node.dart';
import '../../models/memory_node.dart';
import '../../theme/sepia_theme.dart';

/// Interactive Dual-Tree Memory Hierarchy Widget
/// Renders:
/// 1) Local Memory Tree (SQLite WASM / RAM / Working Turns / Anchors)
/// 2) Cloud Knowledge Graph Tree (Firestore / Categories / Relations / Contradiction Audits)
///
/// Responsive: Side-by-side split pane on desktop (>=1100px) and a
/// Segmented Control / Stacked view on mobile/tablet devices (<1100px).
class MemoryTreeView extends StatefulWidget {
  final MemoryTreeNode localTree;
  final MemoryTreeNode cloudTree;
  final void Function(ContradictionRecord record, DurableKnowledgeNode node) onInspectContradiction;

  const MemoryTreeView({
    super.key,
    required this.localTree,
    required this.cloudTree,
    required this.onInspectContradiction,
  });

  @override
  State<MemoryTreeView> createState() => _MemoryTreeViewState();
}

class _MemoryTreeViewState extends State<MemoryTreeView> {
  int _segmentedIndex = 0; // 0: Local Tree, 1: Cloud Tree, 2: Diff / Sync
  final Set<String> _collapsedNodeIds = {};

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
                if (isDesktopSplit)
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
                else ...[
                  _buildSegmentedControl(),
                  const SizedBox(height: 12),
                  if (_segmentedIndex == 0)
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
                  else
                    _buildSyncDiffSummary(),
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

  Widget _buildSegmentedControl() {
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
            } else if (node.nodeType == MemoryNodeType.contradiction) {
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
                        Row(
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
    }

    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Icon(icon, size: 14, color: color),
    );
  }

  Widget _buildQuietStatus(String status) {
    Color dotColor = SepiaTheme.inkMuted;
    if (status.contains('Clean') || status.contains('CONSOLIDATED') || status.contains('RESOLVED')) {
      dotColor = SepiaTheme.sage;
    } else if (status.contains('PII') || status.contains('SECURITY')) {
      dotColor = SepiaTheme.sage;
    } else if (status.contains('CONFLICT') || status.contains('AWAITING')) {
      dotColor = SepiaTheme.terracotta;
    }

    return SepiaTheme.statusDot(dotColor, status, fontSize: 10);
  }

  Widget _buildSyncDiffSummary() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: SepiaTheme.paperSubtle,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: SepiaTheme.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '⚡ Edge-to-Cloud Delta & Synchronization Status',
            style: SepiaTheme.sans(fontSize: 13, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          _buildDiffRow('Local Unconsolidated Episodes', '1 turn pending cloud ingestion queue', SepiaTheme.amber),
          _buildDiffRow('Local Anchors vs. Cloud Nodes', '4 anchors loaded locally from 4 durable nodes', SepiaTheme.sage),
          _buildDiffRow('Edge Bundle Budget Footprint', '28.4 KB / 50.0 KB (Zero egress budget preserved)', SepiaTheme.sage),
          _buildDiffRow('Network Circuit Breaker State', 'CLOSED (Normal Cloud Run connectivity)', SepiaTheme.sage),
        ],
      ),
    );
  }

  Widget _buildDiffRow(String label, String value, Color dotColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: SepiaTheme.sans(fontSize: 12, color: SepiaTheme.ink),
                children: [
                  TextSpan(text: '$label: ', style: const TextStyle(fontWeight: FontWeight.w600)),
                  TextSpan(text: value, style: TextStyle(color: SepiaTheme.inkSecondary)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
