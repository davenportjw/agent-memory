import 'package:flutter/material.dart';
import '../../services/switching_router_service.dart';
import '../../theme/sepia_theme.dart';

/// LoreCraftRouterDial allows the player or developer to inspect and switch the Firebase AI routing stance.
/// Follows strict UI Clarity standards: zero false affordances, plain-English mode explanations.
class LoreCraftRouterDial extends StatelessWidget {
  final RouterModeOverride selectedMode;
  final ValueChanged<RouterModeOverride> onModeSelected;

  const LoreCraftRouterDial({
    super.key,
    required this.selectedMode,
    required this.onModeSelected,
  });

  void _showModeExplanationDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: SepiaTheme.paper,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: SepiaTheme.border, width: 1.5),
        ),
        title: Row(
          children: [
            const Icon(Icons.hub_outlined, color: SepiaTheme.amber, size: 20),
            const SizedBox(width: 8),
            Text(
              'Firebase AI Router Modes',
              style: SepiaTheme.sans(fontSize: 16, fontWeight: FontWeight.w700, color: SepiaTheme.ink),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: SepiaTheme.amberBg,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: SepiaTheme.amberBorder),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.cloud_sync, size: 16, color: SepiaTheme.amber),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Dynamic Control Plane: Routing policies & token ceilings are synchronized live via Firebase Remote Config (shared/routing_policy.json).',
                        style: SepiaTheme.sans(fontSize: 11, fontWeight: FontWeight.w600, color: SepiaTheme.ink),
                      ),
                    ),
                  ],
                ),
              ),
              _buildModeExplorationItem(
                title: 'Smart Auto (Default Dynamic Policy)',
                description:
                    'Dynamically evaluates every player input using priority rules. Fast dialogue barks and PII stay on-device (<60ms, 0 KB egress); multi-faction political synthesis escalates to Gemini 3.8 Flash; concept art offloads to Nano Banana 2 Lite.',
                badgeColor: SepiaTheme.sageBg,
                badgeBorder: SepiaTheme.sageBorder,
                badgeText: 'HYBRID ACTIVE',
                textColor: SepiaTheme.sage,
              ),
              const SizedBox(height: 12),
              _buildModeExplorationItem(
                title: 'Force Edge (Local Offline Stance)',
                description:
                    'Locks execution strictly to on-device Gemma 4 / Gemini Nano. Zero bytes leave your device. Ensures complete data privacy and uninterrupted offline gameplay, even without internet connectivity.',
                badgeColor: SepiaTheme.sageBg,
                badgeBorder: SepiaTheme.sageBorder,
                badgeText: '0 KB EGRESS',
                textColor: SepiaTheme.sage,
              ),
              const SizedBox(height: 12),
              _buildModeExplorationItem(
                title: 'Force Cloud (Frontier Reasoning Stance)',
                description:
                    'Routes all dialogue and world actions directly to Vertex AI Gemini 3.8 Flash on Cloud Run. Maximum political depth and cross-faction memory anchoring at the cost of network egress.',
                badgeColor: SepiaTheme.amberBg,
                badgeBorder: SepiaTheme.amberBorder,
                badgeText: 'VERTEX AI CLOUD',
                textColor: SepiaTheme.amber,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'Close',
              style: SepiaTheme.sans(fontWeight: FontWeight.w600, color: SepiaTheme.inkSecondary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeExplorationItem({
    required String title,
    required String description,
    required Color badgeColor,
    required Color badgeBorder,
    required String badgeText,
    required Color textColor,
  }) {
    return Container(
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: SepiaTheme.sans(fontSize: 13, fontWeight: FontWeight.w700, color: SepiaTheme.ink),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: badgeColor,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: badgeBorder),
                ),
                child: Text(
                  badgeText,
                  style: SepiaTheme.mono(fontSize: 9, fontWeight: FontWeight.w700, color: textColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: SepiaTheme.sans(fontSize: 12, color: SepiaTheme.inkSecondary, height: 1.35),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: SepiaTheme.paperSubtle,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: SepiaTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(Icons.router_outlined, size: 13, color: SepiaTheme.inkSecondary),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        'FIREBASE AI ROUTER',
                        style: SepiaTheme.mono(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: SepiaTheme.inkSecondary,
                          letterSpacing: 0.5,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.info_outline, size: 15, color: SepiaTheme.inkMuted),
                tooltip: 'Explain routing modes',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () => _showModeExplanationDialog(context),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: SepiaTheme.paper,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: SepiaTheme.borderSubtle),
            ),
            child: Row(
              children: [
                _buildSegmentButton(
                  title: 'Smart Auto',
                  mode: RouterModeOverride.auto,
                  icon: Icons.auto_awesome,
                ),
                const SizedBox(width: 2),
                _buildSegmentButton(
                  title: 'Force Edge',
                  mode: RouterModeOverride.enforceEdgeLocal,
                  icon: Icons.bolt,
                ),
                const SizedBox(width: 2),
                _buildSegmentButton(
                  title: 'Force Cloud',
                  mode: RouterModeOverride.enforceCloudFlash,
                  icon: Icons.cloud_outlined,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentButton({
    required String title,
    required RouterModeOverride mode,
    required IconData icon,
  }) {
    final isSelected = selectedMode == mode;
    return Expanded(
      child: InkWell(
        onTap: () => onModeSelected(mode),
        borderRadius: BorderRadius.circular(4),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 2),
          decoration: BoxDecoration(
            color: isSelected ? SepiaTheme.paperSubtle : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: isSelected ? SepiaTheme.border : Colors.transparent,
              width: 1.2,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 2,
                      offset: const Offset(0, 1),
                    )
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 11,
                color: isSelected ? SepiaTheme.ink : SepiaTheme.inkMuted,
              ),
              const SizedBox(width: 3),
              Flexible(
                child: Text(
                  title,
                  style: SepiaTheme.sans(
                    fontSize: 10,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? SepiaTheme.ink : SepiaTheme.inkMuted,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
