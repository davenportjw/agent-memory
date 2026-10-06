import 'package:flutter/material.dart';
import '../../theme/sepia_theme.dart';

/// Interactive Request/Response Lifecycle Diagram
/// Visualizes the end-to-end flow between Edge Working Memory,
/// Short-Term Local SQLite, Cloud Consolidation, and Edge Bundle Hydration.
/// Responsive: Renders as a horizontal pipeline on desktop (>=700px)
/// and a vertical chronological stepper on mobile/devices (<700px).
class MemoryRequestResponseDiagram extends StatelessWidget {
  final int selectedStageIndex;
  final ValueChanged<int> onStageSelected;
  final bool isOffline;

  const MemoryRequestResponseDiagram({
    super.key,
    required this.selectedStageIndex,
    required this.onStageSelected,
    this.isOffline = false,
  });

  static const List<_StageSpec> _stages = [
    _StageSpec(
      index: 0,
      shortTitle: '1. Working Memory',
      domain: 'EDGE (RAM)',
      hardware: 'Gemma 4 int4 Attention Window',
      detail: 'Volatile scratchpad & prompt anchors (<60ms TTFT)',
      isOnline: true,
      icon: Icons.memory_rounded,
      accentColor: SepiaTheme.sage,
      bgAccent: SepiaTheme.sageBg,
    ),
    _StageSpec(
      index: 1,
      shortTitle: '2. Short-Term Memory',
      domain: 'EDGE (SQLite)',
      hardware: 'Local Device SQLite / Room DB',
      detail: 'Episodic turns & PII scrubbing (Zero cloud egress)',
      isOnline: true,
      icon: Icons.security_rounded,
      accentColor: SepiaTheme.sage,
      bgAccent: SepiaTheme.sageBg,
    ),
    _StageSpec(
      index: 2,
      shortTitle: '3. Cloud Consolidation',
      domain: 'CLOUD (Cloud Run)',
      hardware: 'Vertex AI Gemini 3.8 Flash',
      detail: 'Asynchronous entity extraction & contradiction audit',
      isOnline: false,
      icon: Icons.hub_rounded,
      accentColor: SepiaTheme.amber,
      bgAccent: SepiaTheme.amberBg,
    ),
    _StageSpec(
      index: 3,
      shortTitle: '4. Durable Edge Distill',
      domain: 'CLOUD -> EDGE',
      hardware: 'Cloud Firestore & Bundle Packer',
      detail: 'Compact memory bundle strictly < 50 KB synced to edge',
      isOnline: false,
      icon: Icons.cloud_sync_rounded,
      accentColor: SepiaTheme.terracotta,
      bgAccent: SepiaTheme.terracottaBg,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 700;

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
                _buildHeader(context, isMobile),
                const SizedBox(height: 14),
                if (isMobile)
                  _buildVerticalStepper(context)
                else
                  _buildHorizontalPipeline(context),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, bool isMobile) {
    return Row(
      children: [
        const Icon(Icons.alt_route_rounded, size: 18, color: SepiaTheme.ink),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'End-to-End Memory Lifecycle & Egress Flow',
                style: SepiaTheme.sans(fontSize: 14, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 2),
              Text(
                'Interactive request trace: click any stage to inspect execution details and memory state.',
                style: SepiaTheme.sans(fontSize: 12, color: SepiaTheme.inkMuted),
              ),
            ],
          ),
        ),
        if (!isMobile) ...[
          SepiaTheme.statusDot(SepiaTheme.sage, 'Online Loop (<100ms)'),
          const SizedBox(width: 14),
          SepiaTheme.statusDot(SepiaTheme.amber, 'Offline Loop (Gemini 3.8)'),
        ],
      ],
    );
  }

  Widget _buildHorizontalPipeline(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < _stages.length; i++) ...[
          Expanded(
            child: _buildStageCard(_stages[i], isCompact: false),
          ),
          if (i < _stages.length - 1)
            Padding(
              padding: const EdgeInsets.only(top: 32, left: 4, right: 4),
              child: Icon(
                Icons.arrow_forward_rounded,
                size: 16,
                color: SepiaTheme.inkMuted.withValues(alpha: 0.6),
              ),
            ),
        ],
      ],
    );
  }

  Widget _buildVerticalStepper(BuildContext context) {
    return Column(
      children: [
        for (int i = 0; i < _stages.length; i++) ...[
          _buildStageCard(_stages[i], isCompact: true),
          if (i < _stages.length - 1)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  const SizedBox(width: 20),
                  Container(
                    width: 2,
                    height: 14,
                    color: SepiaTheme.border,
                  ),
                ],
              ),
            ),
        ],
      ],
    );
  }

  Widget _buildStageCard(_StageSpec stage, {required bool isCompact}) {
    final isSelected = selectedStageIndex == stage.index;

    return InkWell(
      onTap: () => onStageSelected(stage.index),
      borderRadius: BorderRadius.circular(6),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isSelected ? stage.bgAccent.withValues(alpha: 0.5) : SepiaTheme.paperSubtle,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected ? stage.accentColor : SepiaTheme.borderSubtle,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(stage.icon, size: 16, color: stage.accentColor),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    stage.shortTitle,
                    style: SepiaTheme.sans(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                      color: isSelected ? stage.accentColor : SepiaTheme.ink,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  stage.domain,
                  style: SepiaTheme.mono(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: stage.accentColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              stage.hardware,
              style: SepiaTheme.mono(
                fontSize: 10,
                color: SepiaTheme.inkSecondary,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 3),
            Text(
              stage.detail,
              style: SepiaTheme.sans(
                fontSize: 11,
                color: SepiaTheme.inkMuted,
                height: 1.25,
              ),
              maxLines: isCompact ? 2 : 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _StageSpec {
  final int index;
  final String shortTitle;
  final String domain;
  final String hardware;
  final String detail;
  final bool isOnline;
  final IconData icon;
  final Color accentColor;
  final Color bgAccent;

  const _StageSpec({
    required this.index,
    required this.shortTitle,
    required this.domain,
    required this.hardware,
    required this.detail,
    required this.isOnline,
    required this.icon,
    required this.accentColor,
    required this.bgAccent,
  });
}
