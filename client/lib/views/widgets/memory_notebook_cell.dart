import 'package:flutter/material.dart';
import '../../theme/sepia_theme.dart';

/// Computational Notebook-Style Stage Execution Cell
/// Displays:
/// 1) Cell Header with Stage index and Domain badge
/// 2) Educational explanation callout detailing cognitive concepts and edge AI constraints
/// 3) Live telemetry and memory items formatted with Quiet Typography
/// 4) Action controls for triggering stage operations
class MemoryNotebookCell extends StatefulWidget {
  final int cellIndex;
  final String title;
  final String domain;
  final Color accentColor;
  final String conceptSummary;
  final String edgeConstraintDetail;
  final Widget liveContent;
  final List<Widget> actions;
  final bool initialExpanded;

  const MemoryNotebookCell({
    super.key,
    required this.cellIndex,
    required this.title,
    required this.domain,
    required this.accentColor,
    required this.conceptSummary,
    required this.edgeConstraintDetail,
    required this.liveContent,
    this.actions = const [],
    this.initialExpanded = true,
  });

  @override
  State<MemoryNotebookCell> createState() => _MemoryNotebookCellState();
}

class _MemoryNotebookCellState extends State<MemoryNotebookCell> {
  late bool _isExpanded;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.initialExpanded;
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: SepiaTheme.paper,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: _isExpanded ? widget.accentColor.withValues(alpha: 0.5) : SepiaTheme.border,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cell Header
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: widget.accentColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'CELL [${widget.cellIndex}]',
                      style: SepiaTheme.mono(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: widget.accentColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.title,
                      style: SepiaTheme.sans(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: SepiaTheme.ink,
                      ),
                    ),
                  ),
                  Text(
                    widget.domain,
                    style: SepiaTheme.mono(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: SepiaTheme.inkMuted,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    _isExpanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                    size: 18,
                    color: SepiaTheme.inkMuted,
                  ),
                ],
              ),
            ),
          ),

          if (_isExpanded) ...[
            const Divider(height: 1, color: SepiaTheme.borderSubtle),

            // Educational Concept Callout
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: SepiaTheme.paperSubtle,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.lightbulb_outline_rounded, size: 14, color: widget.accentColor),
                      const SizedBox(width: 6),
                      Text(
                        'Cognitive Concept & Hardware Boundary',
                        style: SepiaTheme.sans(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: widget.accentColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.conceptSummary,
                    style: SepiaTheme.sans(fontSize: 12, color: SepiaTheme.inkSecondary, height: 1.3),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '⚡ Edge Constraint: ',
                        style: SepiaTheme.mono(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: SepiaTheme.inkSecondary,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          widget.edgeConstraintDetail,
                          style: SepiaTheme.sans(
                            fontSize: 11,
                            color: SepiaTheme.inkMuted,
                            height: 1.25,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Live Content Block
            Padding(
              padding: const EdgeInsets.all(14),
              child: widget.liveContent,
            ),

            // Actions Bar
            if (widget.actions.isNotEmpty) ...[
              const Divider(height: 1, color: SepiaTheme.borderSubtle),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                color: SepiaTheme.canvas,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: widget.actions,
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}
