import 'package:flutter/material.dart';
import '../../models/routing_decision.dart';
import '../../theme/sepia_theme.dart';

class TelemetryCard extends StatelessWidget {
  final ExecutionTelemetry telemetry;
  final bool compact;

  const TelemetryCard({
    super.key,
    required this.telemetry,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return Wrap(
        spacing: 6,
        runSpacing: 4,
        children: [
          _buildChip(
            telemetry.modelName,
            SepiaTheme.ink,
          ),
          if (telemetry.isFallback)
            _buildChip(
              'FALLBACK',
              SepiaTheme.amber,
            ),
          _buildChip(
            'TTFT: ${telemetry.ttftMs}ms',
            telemetry.ttftMs < 100 ? SepiaTheme.sage : SepiaTheme.amber,
          ),
          _buildChip(
            '${telemetry.throughputTps} tps',
            SepiaTheme.inkSecondary,
          ),
          _buildChip(
            '${telemetry.tokensGenerated} toks',
            SepiaTheme.inkMuted,
          ),
          _buildChip(
            'RAM: ${telemetry.ramUsageMb.toStringAsFixed(0)}MB',
            SepiaTheme.inkSecondary,
          ),
          _buildChip(
            telemetry.cloudEgressKb == 0.0 ? '0 KB Egress (Local)' : '${telemetry.cloudEgressKb} KB Egress',
            telemetry.cloudEgressKb == 0.0 ? SepiaTheme.sage : SepiaTheme.amber,
          ),
        ],
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
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
              Text(
                'LIVE EXECUTION TELEMETRY',
                style: SepiaTheme.mono(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: SepiaTheme.inkMuted,
                  letterSpacing: 0.5,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (telemetry.isFallback) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: SepiaTheme.amberBg,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: SepiaTheme.amberBorder),
                      ),
                      child: Text(
                        'FALLBACK',
                        style: SepiaTheme.mono(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: SepiaTheme.amber,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                  ],
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: telemetry.cloudEgressKb == 0.0 ? SepiaTheme.sageBg : SepiaTheme.amberBg,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      telemetry.cloudEgressKb == 0.0 ? '100% ON-DEVICE' : 'CLOUD EGRESS',
                      style: SepiaTheme.mono(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: telemetry.cloudEgressKb == 0.0 ? SepiaTheme.sage : SepiaTheme.amber,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  label: 'TIME-TO-FIRST-TOKEN',
                  value: '${telemetry.ttftMs} ms',
                  accentColor: telemetry.ttftMs < 100 ? SepiaTheme.sage : SepiaTheme.amber,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMetricTile(
                  label: 'THROUGHPUT',
                  value: '${telemetry.throughputTps} tps',
                  accentColor: SepiaTheme.ink,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  label: 'CLIENT RAM FOOTPRINT',
                  value: '${telemetry.ramUsageMb.toStringAsFixed(1)} MB',
                  accentColor: SepiaTheme.inkSecondary,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMetricTile(
                  label: 'CLOUD EGRESS',
                  value: telemetry.cloudEgressKb == 0.0 ? '0.0 KB (Zero)' : '${telemetry.cloudEgressKb} KB',
                  accentColor: telemetry.cloudEgressKb == 0.0 ? SepiaTheme.sage : SepiaTheme.terracotta,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: SepiaTheme.paper,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: SepiaTheme.borderSubtle),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.memory_rounded, size: 12, color: SepiaTheme.inkMuted),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Engine: ${telemetry.modelName}',
                        style: SepiaTheme.mono(fontSize: 10, color: SepiaTheme.inkSecondary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '${telemetry.tokensGenerated} tokens',
                      style: SepiaTheme.mono(fontSize: 10, fontWeight: FontWeight.w600, color: SepiaTheme.ink),
                    ),
                  ],
                ),
                if (telemetry.isFallback && telemetry.fallbackReason != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Fallback: ${telemetry.fallbackReason}',
                    style: SepiaTheme.sans(fontSize: 9.5, color: SepiaTheme.amber, fontStyle: FontStyle.italic),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: SepiaTheme.paper,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: SepiaTheme.border),
      ),
      child: Text(
        text,
        style: SepiaTheme.mono(fontSize: 10, fontWeight: FontWeight.w500, color: color),
      ),
    );
  }

  Widget _buildMetricTile({required String label, required String value, required Color accentColor}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: SepiaTheme.paper,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: SepiaTheme.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: SepiaTheme.mono(fontSize: 8, fontWeight: FontWeight.w600, color: SepiaTheme.inkMuted),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: SepiaTheme.mono(fontSize: 13, fontWeight: FontWeight.w700, color: accentColor),
          ),
        ],
      ),
    );
  }
}
