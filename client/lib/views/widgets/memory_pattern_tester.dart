import 'package:flutter/material.dart';
import '../../theme/sepia_theme.dart';

/// Memory Pattern Tester & Behavior Simulator
/// Allows developers and users to test:
/// 1) Injected Contradictory Directives (resolving conflicts via Gemini 3.8 Flash offline loop)
/// 2) Memory Budget Saturation (testing 50 KB edge bundle invariants)
/// 3) Offline Partition (testing local SQLite working memory resilience with 0 cloud egress)
class MemoryPatternTester extends StatelessWidget {
  final VoidCallback onInjectContradiction;
  final VoidCallback onBudgetPressure;
  final VoidCallback onToggleOffline;
  final VoidCallback onReset;
  final bool isOffline;
  final List<String> simulationLogs;

  const MemoryPatternTester({
    super.key,
    required this.onInjectContradiction,
    required this.onBudgetPressure,
    required this.onToggleOffline,
    required this.onReset,
    required this.isOffline,
    required this.simulationLogs,
  });

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
                _buildHeader(context),
                const SizedBox(height: 12),
                if (isMobile)
                  _buildMobileActions()
                else
                  _buildDesktopActions(),
                const SizedBox(height: 14),
                _buildLogConsole(),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.science_outlined, size: 18, color: SepiaTheme.ink),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Memory Pattern Simulator: Test Invariants & State Transitions',
                style: SepiaTheme.sans(fontSize: 14, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 2),
              Text(
                'Mutate memory conditions to test contradiction reconciliation, budget preservation, and offline resilience.',
                style: SepiaTheme.sans(fontSize: 12, color: SepiaTheme.inkMuted),
              ),
            ],
          ),
        ),
        if (isOffline)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: SepiaTheme.terracottaBg,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: SepiaTheme.terracotta),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off_rounded, size: 12, color: SepiaTheme.terracotta),
                const SizedBox(width: 4),
                Text(
                  'PARTITIONED (OFFLINE)',
                  style: SepiaTheme.mono(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: SepiaTheme.terracotta,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildDesktopActions() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        OutlinedButton.icon(
          onPressed: onInjectContradiction,
          icon: const Icon(Icons.rule_folder_rounded, size: 16, color: SepiaTheme.terracotta),
          label: const Text('1. Inject Contradictory Directive'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            side: const BorderSide(color: SepiaTheme.border),
          ),
        ),
        OutlinedButton.icon(
          onPressed: onBudgetPressure,
          icon: const Icon(Icons.speed_rounded, size: 16, color: SepiaTheme.amber),
          label: const Text('2. Stress 50 KB Bundle Budget'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            side: const BorderSide(color: SepiaTheme.border),
          ),
        ),
        OutlinedButton.icon(
          onPressed: onToggleOffline,
          icon: Icon(
            isOffline ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
            size: 16,
            color: isOffline ? SepiaTheme.sage : SepiaTheme.terracotta,
          ),
          label: Text(isOffline ? '3. Restore Online Mode' : '3. Toggle Offline Partition'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            side: BorderSide(color: isOffline ? SepiaTheme.sage : SepiaTheme.border),
          ),
        ),
        TextButton.icon(
          onPressed: onReset,
          icon: const Icon(Icons.refresh_rounded, size: 16, color: SepiaTheme.inkMuted),
          label: Text(
            'Reset Baseline',
            style: SepiaTheme.sans(fontSize: 12, fontWeight: FontWeight.w600, color: SepiaTheme.inkMuted),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton.icon(
          onPressed: onInjectContradiction,
          icon: const Icon(Icons.rule_folder_rounded, size: 16, color: SepiaTheme.terracotta),
          label: const Text('Inject Contradictory Directive'),
        ),
        const SizedBox(height: 6),
        OutlinedButton.icon(
          onPressed: onBudgetPressure,
          icon: const Icon(Icons.speed_rounded, size: 16, color: SepiaTheme.amber),
          label: const Text('Stress 50 KB Bundle Budget'),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onToggleOffline,
                icon: Icon(
                  isOffline ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
                  size: 16,
                  color: isOffline ? SepiaTheme.sage : SepiaTheme.terracotta,
                ),
                label: Text(isOffline ? 'Online' : 'Offline'),
              ),
            ),
            const SizedBox(width: 8),
            TextButton.icon(
              onPressed: onReset,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Reset'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLogConsole() {
    return Container(
      width: double.infinity,
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
              const Icon(Icons.terminal_rounded, size: 14, color: SepiaTheme.inkSecondary),
              const SizedBox(width: 6),
              Text(
                'Simulator Event Log (Live Delta Output)',
                style: SepiaTheme.mono(fontSize: 11, fontWeight: FontWeight.w700, color: SepiaTheme.inkSecondary),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (simulationLogs.isEmpty)
            Text(
              'No simulation actions triggered yet. Click one of the test buttons above to mutate memory state.',
              style: SepiaTheme.mono(fontSize: 11, color: SepiaTheme.inkMuted),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 120),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: simulationLogs.length,
                separatorBuilder: (_, __) => const SizedBox(height: 4),
                itemBuilder: (context, index) {
                  final log = simulationLogs[index];
                  Color logColor = SepiaTheme.inkSecondary;
                  if (log.contains('[Contradiction')) {
                    logColor = SepiaTheme.terracotta;
                  } else if (log.contains('[Budget')) {
                    logColor = SepiaTheme.amber;
                  } else if (log.contains('[Network')) {
                    logColor = SepiaTheme.sage;
                  }

                  return Text(
                    log,
                    style: SepiaTheme.mono(fontSize: 10, color: logColor, height: 1.3),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
