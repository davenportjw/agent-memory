import 'package:flutter/material.dart';
import '../models/routing_decision.dart';
import '../models/edge_memory_bundle.dart';
import '../services/lorecraft_service.dart';
import '../theme/sepia_theme.dart';
import 'shell_layout.dart';
import 'widgets/telemetry_card.dart';
import 'widgets/lorecraft_canon_arbiter_card.dart';
import '../services/app_mode_service.dart';

enum InspectorMode {
  gameWorld,
  aiEngine,
}

class RightDrawerPanel extends StatefulWidget {
  final IntentPillData? selectedPill;
  final ExecutionTelemetry? latestTelemetry;
  final List<MemoryAnchor> recalledAnchors;
  final CircuitBreakerState circuitBreakerState;
  final int consecutiveFailures;
  final VoidCallback onResetCircuitBreaker;
  final VoidCallback onToggleDrawer;
  final LoreCraftService? loreService;
  final ShellNavDestination? currentDestination;

  const RightDrawerPanel({
    super.key,
    required this.selectedPill,
    this.latestTelemetry,
    required this.recalledAnchors,
    required this.circuitBreakerState,
    required this.consecutiveFailures,
    required this.onResetCircuitBreaker,
    required this.onToggleDrawer,
    this.loreService,
    this.currentDestination,
  });

  @override
  State<RightDrawerPanel> createState() => _RightDrawerPanelState();
}

class _RightDrawerPanelState extends State<RightDrawerPanel> {
  late InspectorMode _activeMode;

  @override
  void initState() {
    super.initState();
    _activeMode = (widget.currentDestination == ShellNavDestination.loreCraftStudio)
        ? InspectorMode.gameWorld
        : InspectorMode.aiEngine;
  }

  @override
  void didUpdateWidget(covariant RightDrawerPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentDestination != oldWidget.currentDestination) {
      if (widget.currentDestination == ShellNavDestination.loreCraftStudio) {
        _activeMode = InspectorMode.gameWorld;
      } else if (oldWidget.currentDestination == ShellNavDestination.loreCraftStudio) {
        _activeMode = InspectorMode.aiEngine;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isGame = _activeMode == InspectorMode.gameWorld;

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
                Icon(
                  isGame ? Icons.auto_stories : Icons.insights_rounded,
                  size: 16,
                  color: SepiaTheme.amber,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isGame ? 'LORECRAFT STUDIO INSPECTOR' : 'CONTEXTUAL INSPECTOR',
                    style: SepiaTheme.sans(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                      color: SepiaTheme.ink,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  splashRadius: 16,
                  onPressed: widget.onToggleDrawer,
                  tooltip: 'Collapse Inspector',
                ),
              ],
            ),
          ),

          // Mode Switcher Segmented Pills
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: const BoxDecoration(
              color: SepiaTheme.paperSubtle,
              border: Border(bottom: BorderSide(color: SepiaTheme.border, width: 0.5)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    key: const Key('tab_inspector_game_world'),
                    onTap: () => setState(() => _activeMode = InspectorMode.gameWorld),
                    borderRadius: BorderRadius.circular(4),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      decoration: BoxDecoration(
                        color: isGame ? SepiaTheme.paper : Colors.transparent,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: isGame ? SepiaTheme.amber : Colors.transparent,
                          width: 1,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          '🏰 Game World',
                          style: SepiaTheme.sans(
                            fontSize: 11,
                            fontWeight: isGame ? FontWeight.w700 : FontWeight.w500,
                            color: isGame ? SepiaTheme.ink : SepiaTheme.inkMuted,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: InkWell(
                    key: const Key('tab_inspector_ai_engine'),
                    onTap: () => setState(() => _activeMode = InspectorMode.aiEngine),
                    borderRadius: BorderRadius.circular(4),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      decoration: BoxDecoration(
                        color: !isGame ? SepiaTheme.paper : Colors.transparent,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: !isGame ? SepiaTheme.amber : Colors.transparent,
                          width: 1,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          '⚙️ AI Engine',
                          style: SepiaTheme.sans(
                            fontSize: 11,
                            fontWeight: !isGame ? FontWeight.w700 : FontWeight.w500,
                            color: !isGame ? SepiaTheme.ink : SepiaTheme.inkMuted,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Drawer Scrollable Body
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: isGame ? _buildGameWorldSections() : _buildAiEngineSections(),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // GAME WORLD SECTIONS
  // ===========================================================================

  List<Widget> _buildGameWorldSections() {
    return [
      // Section 1: Active NPC & Strategic Context
      _buildSectionHeader('ACTIVE NPC & STRATEGIC CONTEXT'),
      const SizedBox(height: 6),
      _buildGameWorldContextCard(),

      const SizedBox(height: 16),
      // Section 2: Active World State Anchors (< 50 KB)
      _buildSectionHeader('ACTIVE WORLD STATE ANCHORS (< 50 KB)'),
      const SizedBox(height: 6),
      _buildGameWorldAnchorsList(),

      const SizedBox(height: 16),
      // Section 3: Gameplay Performance & Memory Budget
      _buildSectionHeader('GAMEPLAY PERFORMANCE & MEMORY BUDGET'),
      const SizedBox(height: 6),
      _buildGameMetricsAndBudgetCard(),

      if (!AppModeService().isSimple) ...[
        const SizedBox(height: 16),
        // Section 4: Canon & Voice Arbiter Scorecard
        _buildSectionHeader('CANON & VOICE ARBITER SCORECARD'),
        const SizedBox(height: 6),
        _buildGameArbiterAndBreakerCard(),
      ],
    ];
  }

  Widget _buildGameWorldContextCard() {
    final s = widget.loreService;
    if (s == null) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: SepiaTheme.paper,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: SepiaTheme.borderSubtle),
        ),
        child: Text(
          'Navigate to LoreCraft Studio to inspect active character persona, quest stage, and narrative consequences.',
          style: SepiaTheme.sans(fontSize: 12, color: SepiaTheme.inkMuted),
        ),
      );
    }

    final npc = s.activeNpc;
    final region = s.activeRegion;
    final totalStages = s.getNpcQuestStages(npc.id).length;
    final stageNum = s.currentQuestStage + 1;
    final lastNpcTurn = s.turns.where((t) => t.isNpc).isNotEmpty ? s.turns.lastWhere((t) => t.isNpc) : null;

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
              Icon(npc.avatarIcon, size: 20, color: SepiaTheme.amber),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      npc.name,
                      style: SepiaTheme.sans(fontSize: 13, fontWeight: FontWeight.w700, color: SepiaTheme.ink),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '${npc.title} • ${region.name}',
                      style: SepiaTheme.sans(fontSize: 11, color: SepiaTheme.inkMuted),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: SepiaTheme.amber.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'STAGE $stageNum / ${totalStages > 0 ? totalStages : 5}',
                  style: SepiaTheme.mono(fontSize: 9, fontWeight: FontWeight.w700, color: SepiaTheme.amber),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: SepiaTheme.paperSubtle,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              children: [
                const Icon(Icons.record_voice_over_outlined, size: 12, color: SepiaTheme.inkMuted),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Voice: ${npc.voiceStyle} • Mood: ${npc.currentMood}',
                    style: SepiaTheme.mono(fontSize: 10, color: SepiaTheme.inkSecondary),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          if (widget.selectedPill != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: SepiaTheme.paperSubtle,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: SepiaTheme.borderSubtle),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'SELECTED TURN INTENT',
                    style: SepiaTheme.mono(fontSize: 9, fontWeight: FontWeight.w700, color: SepiaTheme.amber),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    widget.selectedPill!.intentLabel,
                    style: SepiaTheme.sans(fontSize: 12, fontWeight: FontWeight.w600, color: SepiaTheme.ink),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Policy: ${widget.selectedPill!.ruleId} • Route: ${widget.selectedPill!.route.key}',
                    style: SepiaTheme.mono(fontSize: 10, color: SepiaTheme.inkMuted),
                  ),
                  if (widget.selectedPill!.memoryDelta.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      widget.selectedPill!.memoryDelta,
                      style: SepiaTheme.mono(fontSize: 10, color: SepiaTheme.ink),
                    ),
                  ],
                ],
              ),
            ),
          ] else if (lastNpcTurn != null) ...[
            const SizedBox(height: 8),
            Text(
              'LATEST DIALOGUE TURN:',
              style: SepiaTheme.mono(fontSize: 9, fontWeight: FontWeight.w700, color: SepiaTheme.inkMuted),
            ),
            const SizedBox(height: 2),
            Text(
              '${lastNpcTurn.stageCue} "${lastNpcTurn.speechText}"',
              style: SepiaTheme.sans(fontSize: 11, fontStyle: FontStyle.italic, color: SepiaTheme.inkSecondary),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildGameWorldAnchorsList() {
    final s = widget.loreService;

    // Collect all world anchors: combine loreService worldAnchors with any world anchors in recalledAnchors
    final List<Map<String, String>> anchorsToDisplay = [];

    if (s != null) {
      for (final a in s.worldAnchors) {
        anchorsToDisplay.add({
          'key': a.key,
          'category': a.category,
          'context': a.distilledContext,
        });
      }
    }

    for (final a in widget.recalledAnchors) {
      if (a.category == 'WORLD_CANON' ||
          a.category == 'FACTION_STATE' ||
          a.category == 'TACTICAL_SECURITY' ||
          a.category == 'WORLD_EVENT') {
        if (!anchorsToDisplay.any((item) => item['key'] == a.key)) {
          anchorsToDisplay.add({
            'key': a.key,
            'category': a.category,
            'context': a.distilledContext,
          });
        }
      }
    }

    if (anchorsToDisplay.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: SepiaTheme.paper,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: SepiaTheme.borderSubtle),
        ),
        child: Text(
          'No active world anchors bound to current scene context.',
          style: SepiaTheme.sans(fontSize: 12, color: SepiaTheme.inkMuted),
        ),
      );
    }

    return Column(
      children: anchorsToDisplay.take(4).map((anchor) {
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
                      '#${anchor['key']}',
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
                      anchor['category'] ?? 'WORLD_CANON',
                      style: SepiaTheme.mono(fontSize: 8, color: SepiaTheme.inkMuted),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                anchor['context'] ?? '',
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

  Widget _buildGameMetricsAndBudgetCard() {
    final s = widget.loreService;
    final bundleBytes = s?.worldBundleSizeBytes ?? 32180;
    final bundleKb = bundleBytes / 1024.0;
    final progress = (bundleKb / 50.0).clamp(0.0, 1.0);
    final lastNpcTurn = s?.turns.where((t) => t.isNpc).isNotEmpty == true ? s!.turns.lastWhere((t) => t.isNpc) : null;

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
                  'EDGE LORE BUNDLE METER',
                  style: SepiaTheme.mono(fontSize: 10, fontWeight: FontWeight.w700, color: SepiaTheme.ink),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '${bundleKb.toStringAsFixed(1)} KB / 50.0 KB',
                style: SepiaTheme.mono(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: progress > 0.9 ? SepiaTheme.terracotta : SepiaTheme.sage,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 5,
              backgroundColor: SepiaTheme.paperSubtle,
              valueColor: AlwaysStoppedAnimation<Color>(
                progress > 0.9 ? SepiaTheme.terracotta : SepiaTheme.sage,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Strict < 50 KB edge working memory limits. Fits within on-device NPU cache without cloud synchronization.',
            style: SepiaTheme.sans(fontSize: 10, color: SepiaTheme.inkMuted),
          ),
          const Divider(height: 16, color: SepiaTheme.borderSubtle),
          Wrap(
            spacing: 12,
            runSpacing: 6,
            alignment: WrapAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Dialogue TTFT', style: SepiaTheme.sans(fontSize: 10, color: SepiaTheme.inkMuted)),
                  const SizedBox(height: 2),
                  Text(
                    lastNpcTurn != null ? '${lastNpcTurn.ttftMs} ms' : '< 60 ms',
                    style: SepiaTheme.mono(fontSize: 11, fontWeight: FontWeight.w700, color: SepiaTheme.sage),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Cloud Egress', style: SepiaTheme.sans(fontSize: 10, color: SepiaTheme.inkMuted)),
                  const SizedBox(height: 2),
                  Text(
                    '0.0 KB',
                    style: SepiaTheme.mono(fontSize: 11, fontWeight: FontWeight.w700, color: SepiaTheme.sage),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Active Engine', style: SepiaTheme.sans(fontSize: 10, color: SepiaTheme.inkMuted)),
                  const SizedBox(height: 2),
                  Text(
                    lastNpcTurn?.modelName ?? 'Gemma 4 int4',
                    style: SepiaTheme.mono(fontSize: 10, fontWeight: FontWeight.w600, color: SepiaTheme.ink),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGameArbiterAndBreakerCard() {
    final s = widget.loreService;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LoreCraftCanonArbiterCard(
          rating: s?.latestCanonRating,
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: SepiaTheme.paperSubtle,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: SepiaTheme.borderSubtle),
          ),
          child: Row(
            children: [
              Icon(
                widget.circuitBreakerState == CircuitBreakerState.CLOSED
                    ? Icons.check_circle_rounded
                    : Icons.error_rounded,
                size: 13,
                color: widget.circuitBreakerState == CircuitBreakerState.CLOSED
                    ? SepiaTheme.sage
                    : SepiaTheme.terracotta,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Cloud Run: ${widget.circuitBreakerState.name} (${widget.consecutiveFailures}/3 fails)',
                  style: SepiaTheme.mono(fontSize: 9, color: SepiaTheme.inkSecondary),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (widget.circuitBreakerState != CircuitBreakerState.CLOSED)
                InkWell(
                  key: const Key('btn_reset_circuit_breaker_game'),
                  onTap: widget.onResetCircuitBreaker,
                  child: Text(
                    'RESET',
                    style: SepiaTheme.mono(fontSize: 9, fontWeight: FontWeight.w700, color: SepiaTheme.amber),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // AI ENGINE SECTIONS
  // ===========================================================================

  List<Widget> _buildAiEngineSections() {
    return [
      // Section 1: Selected Intent Pill Deep Dive
      _buildSectionHeader('SELECTED INTENT PILL DETAILS'),
      const SizedBox(height: 6),
      _buildSelectedPillCard(),

      const SizedBox(height: 16),
      // Section 2: Recalled Durable Memory Anchors
      _buildSectionHeader('RECALLED ENGINE MEMORY ANCHORS'),
      const SizedBox(height: 6),
      _buildEngineAnchorsList(),

      const SizedBox(height: 16),
      // Section 3: Live Telemetry
      _buildSectionHeader('EXECUTION METRICS'),
      const SizedBox(height: 6),
      widget.latestTelemetry != null
          ? TelemetryCard(telemetry: widget.latestTelemetry!)
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
    ];
  }

  Widget _buildSectionHeader(String title) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 10,
          color: SepiaTheme.amber,
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
    if (widget.selectedPill == null) {
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

    final pill = widget.selectedPill!;
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

  Widget _buildEngineAnchorsList() {
    // In AI engine mode, prioritize runtime system policies
    final engineAnchors = widget.recalledAnchors.where((a) {
      return a.category == 'SYSTEM_ARCHITECTURE' ||
          a.category == 'SECURITY_POLICY' ||
          a.category == 'ROADMAP_DECISION';
    }).toList();

    final anchorsToShow = engineAnchors.isNotEmpty ? engineAnchors : widget.recalledAnchors;

    if (anchorsToShow.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: SepiaTheme.paper,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: SepiaTheme.borderSubtle),
        ),
        child: Text(
          'No engine memory anchors currently active.',
          style: SepiaTheme.sans(fontSize: 12, color: SepiaTheme.inkMuted),
        ),
      );
    }

    return Column(
      children: anchorsToShow.take(4).map((anchor) {
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
    switch (widget.circuitBreakerState) {
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
                widget.circuitBreakerState == CircuitBreakerState.CLOSED
                    ? Icons.check_circle_outline_rounded
                    : Icons.error_outline_rounded,
                size: 16,
                color: statusColor,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Consecutive Failures: ${widget.consecutiveFailures} / 3',
            style: SepiaTheme.mono(fontSize: 10, color: SepiaTheme.inkSecondary),
          ),
          const SizedBox(height: 4),
          Text(
            'Target: Google Cloud Run (us-central1 / Vertex AI)',
            style: SepiaTheme.mono(fontSize: 9, color: SepiaTheme.inkMuted),
          ),
          if (widget.loreService != null) ...[
            const SizedBox(height: 2),
            Text(
              'Endpoint: ${widget.loreService!.cloudClient.baseUrl}',
              style: SepiaTheme.mono(fontSize: 8.5, color: SepiaTheme.azure),
              overflow: TextOverflow.ellipsis,
            ),
          ],
          if (widget.circuitBreakerState != CircuitBreakerState.CLOSED) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.refresh_rounded, size: 14),
                label: const Text('Reset Circuit Breaker'),
                onPressed: widget.onResetCircuitBreaker,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
