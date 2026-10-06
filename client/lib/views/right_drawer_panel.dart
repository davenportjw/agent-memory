import 'package:flutter/material.dart';
import '../models/routing_decision.dart';
import '../models/edge_memory_bundle.dart';
import '../theme/sepia_theme.dart';
import 'widgets/telemetry_card.dart';

class RightDrawerPanel extends StatelessWidget {
  final IntentPillData? selectedPill;
  final ExecutionTelemetry? latestTelemetry;
  final List<MemoryAnchor> recalledAnchors;
  final CircuitBreakerState circuitBreakerState;
  final int consecutiveFailures;
  final VoidCallback onResetCircuitBreaker;
  final VoidCallback onToggleDrawer;

  const RightDrawerPanel({
    super.key,
    required this.selectedPill,
    this.latestTelemetry,
    required this.recalledAnchors,
    required this.circuitBreakerState,
    required this.consecutiveFailures,
    required this.onResetCircuitBreaker,
    required this.onToggleDrawer,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 320,
      decoration: const BoxDecoration(
        color: SepiaTheme.canvas,
        border: Border(
          left: BorderSide(color: SepiaTheme.border, width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drawer Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: const BoxDecoration(
              color: SepiaTheme.paper,
              border: Border(bottom: BorderSide(color: SepiaTheme.border)),
            ),
            child: Row(
              children: [
                const Icon(Icons.insights_rounded, size: 16, color: SepiaTheme.ink),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'CONTEXTUAL INSPECTOR',
                    style: SepiaTheme.sans(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  splashRadius: 16,
                  onPressed: onToggleDrawer,
                  tooltip: 'Collapse Inspector',
                ),
              ],
            ),
          ),

          // Drawer Scrollable Body
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: [
                // Section 1: Selected Intent Pill Deep Dive
                _buildSectionHeader('SELECTED INTENT PILL DETAILS'),
                const SizedBox(height: 6),
                _buildSelectedPillCard(),

                const SizedBox(height: 16),
                // Section 2: Recalled Durable Memory Anchors
                _buildSectionHeader('RECALLED MEMORY ANCHORS'),
                const SizedBox(height: 6),
                _buildRecalledAnchorsList(),

                const SizedBox(height: 16),
                // Section 3: Live Telemetry
                _buildSectionHeader('EXECUTION METRICS'),
                const SizedBox(height: 6),
                latestTelemetry != null
                    ? TelemetryCard(telemetry: latestTelemetry!)
                    : Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: SepiaTheme.paperSubtle,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: SepiaTheme.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'AWAITING LIVE PROMPT EXECUTION',
                              style: SepiaTheme.mono(fontSize: 10, fontWeight: FontWeight.w700, color: SepiaTheme.inkMuted),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'No prompt executed yet. Submit a message in the Assistant Workspace to measure live TTFT, throughput (tps), RAM allocation, and cloud egress bytes.',
                              style: SepiaTheme.sans(fontSize: 11, color: SepiaTheme.inkSecondary),
                            ),
                          ],
                        ),
                      ),

                const SizedBox(height: 16),
                // Section 4: Circuit Breaker State
                _buildSectionHeader('NETWORK CIRCUIT BREAKER'),
                const SizedBox(height: 6),
                _buildCircuitBreakerCard(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 10,
          color: SepiaTheme.inkMuted,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            title,
            style: SepiaTheme.mono(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: SepiaTheme.inkMuted,
              letterSpacing: 0.5,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildSelectedPillCard() {
    if (selectedPill == null) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: SepiaTheme.paper,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: SepiaTheme.borderSubtle),
        ),
        child: Text(
          'Select any Intent Pill in the chat workspace to inspect rule triggers, PII scrubbing deltas, and memory state.',
          style: SepiaTheme.sans(fontSize: 12, color: SepiaTheme.inkMuted),
        ),
      );
    }

    final pill = selectedPill!;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: SepiaTheme.paper,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: SepiaTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: pill.route == ExecutionRoute.EDGE_LOCAL
                      ? SepiaTheme.sageBg
                      : pill.route == ExecutionRoute.CLOUD_ESCALATE
                          ? SepiaTheme.amberBg
                          : SepiaTheme.terracottaBg,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  pill.route.key,
                  style: SepiaTheme.mono(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: pill.route == ExecutionRoute.EDGE_LOCAL
                        ? SepiaTheme.sage
                        : pill.route == ExecutionRoute.CLOUD_ESCALATE
                            ? SepiaTheme.amber
                            : SepiaTheme.terracotta,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  pill.ruleId,
                  style: SepiaTheme.mono(fontSize: 11, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            pill.intentLabel,
            style: SepiaTheme.sans(fontSize: 13, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            'Policy Justification:',
            style: SepiaTheme.sans(fontSize: 11, fontWeight: FontWeight.w600, color: SepiaTheme.inkSecondary),
          ),
          Text(
            pill.justificationRule,
            style: SepiaTheme.sans(fontSize: 12, color: SepiaTheme.inkSecondary),
          ),
          const SizedBox(height: 8),
          Text(
            'Memory Pipeline Delta:',
            style: SepiaTheme.sans(fontSize: 11, fontWeight: FontWeight.w600, color: SepiaTheme.inkSecondary),
          ),
          Text(
            pill.memoryDelta,
            style: SepiaTheme.mono(fontSize: 11, color: SepiaTheme.ink),
          ),
          if (pill.isFallback) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: SepiaTheme.amberBg,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: SepiaTheme.amberBorder, width: 1.2),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.swap_calls_rounded, size: 14, color: SepiaTheme.amber),
                      const SizedBox(width: 6),
                      Text(
                        'FALLBACK DETECTED',
                        style: SepiaTheme.mono(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: SepiaTheme.amber,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    pill.fallbackReason ??
                        'Local Chrome Built-in AI (window.ai) is not available or enabled in this browser session. Automatically escalated to Gemini 3.8 Flash on Google Cloud.',
                    style: SepiaTheme.sans(fontSize: 11, color: SepiaTheme.ink, height: 1.35),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'To enable on-device Gemini Nano in Chrome:\n'
                    '1. Navigate to chrome://flags/#prompt-api (or #prompt-api-for-gemini-nano) -> set to "Enabled"\n'
                    '2. Ensure >= 22 GB free disk space on startup drive (Chrome evicts models if free space < 10 GB)\n'
                    '3. Restart Chrome and verify download in chrome://on-device-internals\n'
                    '(Note: Legacy flag #optimization-guide-on-device-model has been deprecated and removed in modern Chrome)',
                    style: SepiaTheme.mono(fontSize: 9, color: SepiaTheme.inkSecondary),
                  ),
                ],
              ),
            ),
          ],
          if (pill.detectedPii.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: SepiaTheme.terracottaBg,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: SepiaTheme.terracottaBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '🔒 Detected & Scrubbed Entities (${pill.detectedPii.length}):',
                    style: SepiaTheme.mono(fontSize: 10, fontWeight: FontWeight.w700, color: SepiaTheme.terracotta),
                  ),
                  const SizedBox(height: 4),
                  ...pill.detectedPii.map(
                    (p) => Text('• $p', style: SepiaTheme.mono(fontSize: 10, color: SepiaTheme.terracotta)),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRecalledAnchorsList() {
    if (recalledAnchors.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: SepiaTheme.paper,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: SepiaTheme.borderSubtle),
        ),
        child: Text(
          'No durable memory anchors currently active.',
          style: SepiaTheme.sans(fontSize: 12, color: SepiaTheme.inkMuted),
        ),
      );
    }

    return Column(
      children: recalledAnchors.take(3).map((anchor) {
        return Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: SepiaTheme.paper,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: SepiaTheme.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      '#${anchor.key}',
                      style: SepiaTheme.mono(fontSize: 11, fontWeight: FontWeight.w700, color: SepiaTheme.amber),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: SepiaTheme.paperSubtle,
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Text(
                      anchor.category,
                      style: SepiaTheme.mono(fontSize: 8, color: SepiaTheme.inkMuted),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                anchor.distilledContext,
                style: SepiaTheme.sans(fontSize: 11, color: SepiaTheme.inkSecondary),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCircuitBreakerCard() {
    Color statusColor;
    String statusText;
    switch (circuitBreakerState) {
      case CircuitBreakerState.CLOSED:
        statusColor = SepiaTheme.sage;
        statusText = 'CLOSED (Healthy)';
        break;
      case CircuitBreakerState.HALF_OPEN:
        statusColor = SepiaTheme.amber;
        statusText = 'HALF_OPEN (Probing)';
        break;
      case CircuitBreakerState.OPEN:
        statusColor = SepiaTheme.terracotta;
        statusText = 'OPEN (Tripped - Edge Fallback Active)';
        break;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: SepiaTheme.paper,
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
                child: Text(
                  'State: $statusText',
                  style: SepiaTheme.mono(fontSize: 11, fontWeight: FontWeight.w700, color: statusColor),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(
                circuitBreakerState == CircuitBreakerState.CLOSED
                    ? Icons.check_circle_outline_rounded
                    : Icons.error_outline_rounded,
                size: 16,
                color: statusColor,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Consecutive Failures: $consecutiveFailures / 3',
            style: SepiaTheme.mono(fontSize: 10, color: SepiaTheme.inkSecondary),
          ),
          const SizedBox(height: 4),
          Text(
            'Target: Google Cloud Run (us-central1 / Vertex AI)',
            style: SepiaTheme.mono(fontSize: 9, color: SepiaTheme.inkMuted),
          ),
          if (circuitBreakerState != CircuitBreakerState.CLOSED) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.refresh_rounded, size: 14),
                label: const Text('Reset Circuit Breaker'),
                onPressed: onResetCircuitBreaker,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

