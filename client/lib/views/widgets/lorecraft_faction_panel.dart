import 'package:flutter/material.dart';
import '../../models/lorecraft_state.dart';
import '../../theme/sepia_theme.dart';

class LoreCraftFactionPanel extends StatelessWidget {
  final List<GameFaction> factions;
  final Function(String factionId, int delta)? onAdjustReputation;

  const LoreCraftFactionPanel({
    super.key,
    required this.factions,
    this.onAdjustReputation,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: SepiaTheme.paper,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: SepiaTheme.border, width: 1.0),
      ),
      padding: const EdgeInsets.all(12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'FACTION STANDINGS',
                  style: SepiaTheme.sans(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: SepiaTheme.inkMuted,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              InkWell(
                onTap: () => _showTreatyModal(context),
                borderRadius: BorderRadius.circular(4),
                child: const Padding(
                  padding: EdgeInsets.all(4.0),
                  child: Icon(Icons.info_outline, size: 16, color: SepiaTheme.inkMuted),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...factions.map((f) => _buildFactionItem(context, f)),
        ],
      ),
    );
  }

  Widget _buildFactionItem(BuildContext context, GameFaction f) {
    final progress = ((f.reputation + 100) / 200.0).clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  f.name,
                  style: SepiaTheme.sans(fontSize: 12, fontWeight: FontWeight.w600, color: SepiaTheme.ink),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(color: f.alignmentColor, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    f.alignmentLabel,
                    style: SepiaTheme.sans(fontSize: 10, fontWeight: FontWeight.w600, color: f.alignmentColor),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '(${f.reputation > 0 ? '+${f.reputation}' : '${f.reputation}'})',
                    style: SepiaTheme.mono(fontSize: 10, color: SepiaTheme.inkMuted),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: SepiaTheme.paperSubtle,
                    valueColor: AlwaysStoppedAnimation<Color>(f.alignmentColor),
                    minHeight: 5,
                  ),
                ),
              ),
              if (onAdjustReputation != null) ...[
                const SizedBox(width: 8),
                InkWell(
                  onTap: () => onAdjustReputation!(f.id, -10),
                  borderRadius: BorderRadius.circular(3),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      border: Border.all(color: SepiaTheme.border),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Text('-10', style: SepiaTheme.mono(fontSize: 9, color: SepiaTheme.inkMuted)),
                  ),
                ),
                const SizedBox(width: 4),
                InkWell(
                  onTap: () => onAdjustReputation!(f.id, 10),
                  borderRadius: BorderRadius.circular(3),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      border: Border.all(color: SepiaTheme.border),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Text('+10', style: SepiaTheme.mono(fontSize: 9, color: SepiaTheme.inkMuted)),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  void _showTreatyModal(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: SepiaTheme.paper,
        title: Text('Inter-Faction Treaties & Resource Pacts', style: SepiaTheme.sans(fontWeight: FontWeight.w700, fontSize: 16)),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: factions.map((f) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(f.name, style: SepiaTheme.sans(fontSize: 14, fontWeight: FontWeight.w700, color: f.bannerColor)),
                    const SizedBox(height: 2),
                    Text(f.description, style: SepiaTheme.sans(fontSize: 13, color: SepiaTheme.inkMuted, height: 1.35)),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Close', style: SepiaTheme.sans(color: SepiaTheme.ink, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
