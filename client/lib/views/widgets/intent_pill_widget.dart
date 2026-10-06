import 'package:flutter/material.dart';
import '../../models/routing_decision.dart';
import '../../theme/sepia_theme.dart';

/// Actionable Intent Pill Widget
/// Conveys:
/// 1) Resolved User Intent
/// 2) Policy Justification / Route
/// 3) Memory Delta
/// Clicking notifies and highlights details in the Right Drawer!
class IntentPillWidget extends StatelessWidget {
  final IntentPillData pillData;
  final bool isSelected;
  final VoidCallback onTap;

  const IntentPillWidget({
    super.key,
    required this.pillData,
    this.isSelected = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color border;
    Color textAccent;
    IconData icon;

    switch (pillData.route) {
      case ExecutionRoute.EDGE_LOCAL:
        if (pillData.ruleId == 'RULE_STRICT_PRIVACY') {
          bg = SepiaTheme.sageBg;
          border = isSelected ? SepiaTheme.sage : SepiaTheme.sageBorder;
          textAccent = SepiaTheme.sage;
          icon = Icons.lock_outline_rounded;
        } else {
          bg = SepiaTheme.slateBg;
          border = isSelected ? SepiaTheme.slate : SepiaTheme.slateBorder;
          textAccent = SepiaTheme.slate;
          icon = Icons.bolt_rounded;
        }
        break;
      case ExecutionRoute.EDGE_FALLBACK:
        bg = SepiaTheme.terracottaBg;
        border = isSelected ? SepiaTheme.terracotta : SepiaTheme.terracottaBorder;
        textAccent = SepiaTheme.terracotta;
        icon = Icons.cloud_off_rounded;
        break;
      case ExecutionRoute.CLOUD_ESCALATE:
        bg = SepiaTheme.amberBg;
        border = isSelected ? SepiaTheme.amber : SepiaTheme.amberBorder;
        textAccent = SepiaTheme.amber;
        icon = Icons.cloud_done_rounded;
        break;
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: border,
            width: isSelected ? 1.5 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: textAccent.withValues(alpha: 0.15),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  )
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Row 1: Intent & Route Header
            Row(
              children: [
                Icon(icon, size: 14, color: textAccent),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    pillData.intentLabel,
                    style: SepiaTheme.sans(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: textAccent,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (pillData.isFallback) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: SepiaTheme.terracottaBg,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: SepiaTheme.terracotta),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.swap_calls_rounded, size: 10, color: SepiaTheme.terracotta),
                        const SizedBox(width: 3),
                        Text(
                          'FALLBACK',
                          style: SepiaTheme.mono(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: SepiaTheme.terracotta,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                ],
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: border),
                  ),
                  child: Text(
                    pillData.route.key,
                    style: SepiaTheme.mono(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: textAccent,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            // Row 2: Policy Justification / Fallback Reason
            Text(
              pillData.isFallback
                  ? '⚠️ Fallback: ${pillData.fallbackReason ?? pillData.justificationRule}'
                  : '⚡ Policy: ${pillData.justificationRule}',
              style: SepiaTheme.sans(
                fontSize: 11,
                fontWeight: pillData.isFallback ? FontWeight.w600 : FontWeight.w400,
                color: pillData.isFallback ? SepiaTheme.amber : SepiaTheme.inkSecondary,
                height: 1.25,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            // Row 3: Memory Delta
            Row(
              children: [
                const Icon(Icons.memory_rounded, size: 11, color: SepiaTheme.inkMuted),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'Delta: ${pillData.memoryDelta}',
                    style: SepiaTheme.mono(
                      fontSize: 10,
                      color: SepiaTheme.inkMuted,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  isSelected ? '• Inspecting in Drawer' : 'Click to inspect ➔',
                  style: SepiaTheme.sans(
                    fontSize: 10,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? textAccent : SepiaTheme.inkMuted,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
