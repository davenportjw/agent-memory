import 'package:flutter/material.dart';
import '../services/lorecraft_service.dart';
import '../theme/sepia_theme.dart';
import 'widgets/lorecraft_dialogue_card.dart';
import 'widgets/lorecraft_faction_panel.dart';
import 'widgets/lorecraft_canon_arbiter_card.dart';
import 'widgets/lorecraft_mission_briefing_card.dart';
import 'widgets/lorecraft_router_dial.dart';
import 'widgets/lorecraft_foresight_pill.dart';
import 'widgets/objective_milestone_toast.dart';
import 'lorecraft_boot_page_view.dart';
import '../services/app_mode_service.dart';

import 'shell_layout.dart';

class LoreCraftStudio extends StatefulWidget {
  final LoreCraftService loreService;
  final void Function(ShellNavDestination destination)? onNavigateToDestination;
  final bool? isRightDrawerOpen;
  final VoidCallback? onToggleRightDrawer;

  const LoreCraftStudio({
    super.key,
    required this.loreService,
    this.onNavigateToDestination,
    this.isRightDrawerOpen,
    this.onToggleRightDrawer,
  });

  @override
  State<LoreCraftStudio> createState() => _LoreCraftStudioState();
}

class _LoreCraftStudioState extends State<LoreCraftStudio> {
  final TextEditingController _promptController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isRightDrawerOpen = true;
  bool _isLeftPanelOpen = true;

  // Collapsible section states for Left Panel
  bool _isRegionExpanded = true;
  bool _isNpcsExpanded = true;
  bool _isFactionsExpanded = true;
  bool _isRouterExpanded = true;
  bool _isBudgetExpanded = true;

  @override
  void initState() {
    super.initState();
    widget.loreService.addListener(_onServiceChanged);
  }

  void _onServiceChanged() {
    if (mounted) {
      setState(() {});
      _scrollToBottom();
    }
  }

  @override
  void dispose() {
    widget.loreService.removeListener(_onServiceChanged);
    _promptController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _handleSend(String text) {
    if (text.trim().isEmpty) return;
    widget.loreService.sendPlayerAction(text.trim());
    _promptController.clear();
  }

  void _showMissionDossierDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: SepiaTheme.canvas,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: SepiaTheme.border, width: 1.5),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820, maxHeight: 780),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: const BoxDecoration(
                  color: SepiaTheme.paper,
                  border: Border(bottom: BorderSide(color: SepiaTheme.border)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.shield_outlined, size: 16, color: SepiaTheme.amber),
                        const SizedBox(width: 8),
                        Text(
                          'ACTIVE STRATEGIC MISSION DOSSIER',
                          style: SepiaTheme.mono(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.0,
                            color: SepiaTheme.ink,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18, color: SepiaTheme.inkMuted),
                      tooltip: 'Close Dossier',
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: LoreCraftMissionBriefingCard(
                  mission: widget.loreService.activeMission,
                  onAcceptMission: (npcId) {
                    Navigator.of(ctx).pop();
                    widget.loreService.acceptMission(npcId);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppModeService(),
      builder: (context, _) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final isCompact = constraints.maxWidth < 1100;
            final showRightDrawer = widget.onToggleRightDrawer == null && _isRightDrawerOpen && !isCompact;

            return Scaffold(
              backgroundColor: SepiaTheme.canvas,
              body: Row(
                children: [
                  // Left Panel: World Context & Character Roster
                  if (_isLeftPanelOpen) ...[
                    SizedBox(
                      width: 280,
                      child: _buildLeftPanel(context),
                    ),
                    const VerticalDivider(width: 1, thickness: 1, color: SepiaTheme.border),
                  ],

                  // Center Panel: Interactive Dialogue Stream
                  Expanded(
                    child: _buildCenterPanel(context),
                  ),

                  // Right Panel: Living Lore & Canon Arbiter Drawer
                  if (showRightDrawer) ...[
                    const VerticalDivider(width: 1, thickness: 1, color: SepiaTheme.border),
                    SizedBox(
                      width: 300,
                      child: _buildRightPanel(context),
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildCollapsibleSectionHeader({
    required Key key,
    required String title,
    required bool isExpanded,
    required VoidCallback onToggle,
    String? trailingBadge,
  }) {
    return InkWell(
      key: key,
      onTap: onToggle,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0),
        child: Row(
          children: [
            Icon(
              isExpanded ? Icons.keyboard_arrow_down_rounded : Icons.keyboard_arrow_right_rounded,
              size: 16,
              color: SepiaTheme.inkMuted,
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                title,
                style: SepiaTheme.sans(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0,
                  color: SepiaTheme.inkMuted,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (trailingBadge != null) ...[
              const SizedBox(width: 4),
              Text(
                trailingBadge,
                style: SepiaTheme.mono(fontSize: 9, color: SepiaTheme.inkMuted),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLeftPanel(BuildContext context) {
    final s = widget.loreService;

    return Container(
      color: SepiaTheme.paper,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with Collapse Button
            Row(
              children: [
                const Icon(Icons.auto_stories, color: SepiaTheme.amber, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'LORECRAFT ENGINE',
                    style: SepiaTheme.sans(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.0,
                      color: SepiaTheme.ink,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  key: const Key('btn_collapse_lorecraft_left_panel'),
                  icon: const Icon(Icons.chevron_left_rounded, size: 20, color: SepiaTheme.inkMuted),
                  tooltip: 'Collapse Left Panel',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  splashRadius: 16,
                  onPressed: () => setState(() => _isLeftPanelOpen = false),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Distributed Game AI Studio',
              style: SepiaTheme.sans(fontSize: 12, color: SepiaTheme.inkMuted),
            ),
            const SizedBox(height: 12),
            const Divider(color: SepiaTheme.border, height: 1),
            const SizedBox(height: 12),

            // Active Region (Collapsible)
            _buildCollapsibleSectionHeader(
              key: const Key('header_section_region'),
              title: 'CURRENT REGION',
              isExpanded: _isRegionExpanded,
              onToggle: () => setState(() => _isRegionExpanded = !_isRegionExpanded),
            ),
            if (_isRegionExpanded) ...[
              const SizedBox(height: 6),
              Container(
                key: const Key('active_region_card'),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: SepiaTheme.paperSubtle,
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
                            s.activeRegion.name,
                            style: SepiaTheme.sans(fontSize: 13, fontWeight: FontWeight.w700, color: SepiaTheme.ink),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text('● Active', style: SepiaTheme.sans(fontSize: 10, color: SepiaTheme.sage, fontWeight: FontWeight.w600)),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(s.activeRegion.atmosphere, style: SepiaTheme.sans(fontSize: 11, color: SepiaTheme.inkMuted, height: 1.3)),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 14),

            // NPC Roster Selector (Collapsible)
            _buildCollapsibleSectionHeader(
              key: const Key('header_section_npcs'),
              title: 'ACTIVE NPC DIALOGUE',
              isExpanded: _isNpcsExpanded,
              trailingBadge: '${s.npcs.length}',
              onToggle: () => setState(() => _isNpcsExpanded = !_isNpcsExpanded),
            ),
            if (_isNpcsExpanded) ...[
              const SizedBox(height: 6),
              Column(
                key: const Key('npc_roster_list'),
                children: s.npcs.map((npc) {
                  final isSelected = npc.id == s.activeNpcId;

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3.0),
                    child: InkWell(
                      onTap: () => s.setActiveNpc(npc.id),
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected ? SepiaTheme.paperSubtle : Colors.transparent,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: isSelected ? SepiaTheme.amber : SepiaTheme.border.withValues(alpha: 0.5),
                            width: isSelected ? 1.5 : 1.0,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(npc.avatarIcon, size: 18, color: isSelected ? SepiaTheme.amber : SepiaTheme.inkMuted),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(npc.name, style: SepiaTheme.sans(fontSize: 12, fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500, color: SepiaTheme.ink)),
                                  Text('${npc.title} • ${npc.currentMood}', style: SepiaTheme.sans(fontSize: 10, color: SepiaTheme.inkMuted)),
                                ],
                              ),
                            ),
                            if (isSelected) const Icon(Icons.check, size: 14, color: SepiaTheme.amber),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
            const SizedBox(height: 14),

            // Faction Standings (Collapsible)
            _buildCollapsibleSectionHeader(
              key: const Key('header_section_factions'),
              title: 'FACTION STANDINGS',
              isExpanded: _isFactionsExpanded,
              trailingBadge: '${s.factions.length}',
              onToggle: () => setState(() => _isFactionsExpanded = !_isFactionsExpanded),
            ),
            if (_isFactionsExpanded) ...[
              const SizedBox(height: 6),
              LoreCraftFactionPanel(
                factions: s.factions,
                onAdjustReputation: (id, delta) => s.adjustReputation(id, delta),
              ),
            ],
            const SizedBox(height: 14),

            // Firebase AI Router Stance Dial (Collapsible)
            _buildCollapsibleSectionHeader(
              key: const Key('header_section_router'),
              title: 'FIREBASE AI ROUTER',
              isExpanded: _isRouterExpanded,
              onToggle: () => setState(() => _isRouterExpanded = !_isRouterExpanded),
            ),
            if (_isRouterExpanded) ...[
              const SizedBox(height: 6),
              LoreCraftRouterDial(
                selectedMode: s.routerModeOverride,
                onModeSelected: (mode) => s.setRouterModeOverride(mode),
              ),
            ],
            const SizedBox(height: 14),

            // Compact Edge Memory Bundle Meter (Collapsible)
            _buildCollapsibleSectionHeader(
              key: const Key('header_section_budget'),
              title: 'EDGE LORE BUNDLE',
              isExpanded: _isBudgetExpanded,
              trailingBadge: '${(s.worldBundleSizeBytes / 1024).toStringAsFixed(1)} KB',
              onToggle: () => setState(() => _isBudgetExpanded = !_isBudgetExpanded),
            ),
            if (_isBudgetExpanded) ...[
              const SizedBox(height: 6),
              _buildMemoryBudgetMeter(s),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCenterPanel(BuildContext context) {
    final s = widget.loreService;

    if (!s.hasCompletedBoot) {
      return LoreCraftBootPageView(
        loreService: s,
        memoryService: s.memoryService,
      );
    }

    if (!s.hasAcceptedMission) {
      return Column(
        children: [
          // Scene Top Bar with Mission Mode indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
            decoration: const BoxDecoration(
              color: SepiaTheme.paper,
              border: Border(bottom: BorderSide(color: SepiaTheme.border, width: 1.0)),
            ),
            child: Row(
              children: [
                IconButton(
                  key: const Key('btn_toggle_lorecraft_left_panel'),
                  icon: Icon(_isLeftPanelOpen ? Icons.menu_open_rounded : Icons.menu_rounded, size: 18, color: SepiaTheme.ink),
                  tooltip: _isLeftPanelOpen ? 'Collapse Left Panel' : 'Expand Left Panel',
                  padding: const EdgeInsets.only(right: 8),
                  constraints: const BoxConstraints(),
                  splashRadius: 16,
                  onPressed: () => setState(() => _isLeftPanelOpen = !_isLeftPanelOpen),
                ),
                Expanded(
                  child: Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: SepiaTheme.amber.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'PRE-DEPLOYMENT BRIEFING',
                          style: SepiaTheme.mono(fontSize: 11, fontWeight: FontWeight.w700, color: SepiaTheme.ink),
                        ),
                      ),
                      Text(
                        'Select Sector Contact',
                        style: SepiaTheme.sans(fontSize: 12, color: SepiaTheme.inkMuted),
                      ),
                      InkWell(
                        key: const Key('btn_revisit_boot_sequence_briefing'),
                        onTap: () => s.resetToBootState(),
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: SepiaTheme.amber.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: SepiaTheme.amber.withValues(alpha: 0.5),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.bolt, size: 13, color: SepiaTheme.amber),
                              const SizedBox(width: 4),
                              Text(
                                'BOOT SEQUENCE',
                                style: SepiaTheme.mono(fontSize: 10, fontWeight: FontWeight.w700, color: SepiaTheme.ink),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Text(
                        '0.0 KB Cloud Egress',
                        style: SepiaTheme.mono(fontSize: 11, fontWeight: FontWeight.w700, color: SepiaTheme.sage),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Mission Briefing Card
          Expanded(
            child: LoreCraftMissionBriefingCard(
              mission: s.activeMission,
              onAcceptMission: (initialNpcId) {
                s.acceptMission(initialNpcId);
              },
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        // Scene Top Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
          decoration: const BoxDecoration(
            color: SepiaTheme.paper,
            border: Border(bottom: BorderSide(color: SepiaTheme.border, width: 1.0)),
          ),
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    key: const Key('btn_toggle_lorecraft_left_panel'),
                    icon: Icon(_isLeftPanelOpen ? Icons.menu_open_rounded : Icons.menu_rounded, size: 18, color: SepiaTheme.ink),
                    tooltip: _isLeftPanelOpen ? 'Collapse Left Panel' : 'Expand Left Panel',
                    padding: const EdgeInsets.only(right: 8),
                    constraints: const BoxConstraints(),
                    splashRadius: 16,
                    onPressed: () => setState(() => _isLeftPanelOpen = !_isLeftPanelOpen),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: SepiaTheme.amber.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'NPC: ${s.activeNpc.name}',
                      style: SepiaTheme.sans(fontSize: 12, fontWeight: FontWeight.w700, color: SepiaTheme.ink),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                  const SizedBox(width: 8),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 180),
                    child: Text(
                      '${s.activeNpc.title} (${s.activeRegion.name})',
                      style: SepiaTheme.sans(fontSize: 13, color: SepiaTheme.inkMuted),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                ],
              ),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (!AppModeService().isSimple) ...[
                    InkWell(
                      key: const Key('btn_revisit_boot_sequence'),
                      onTap: () => s.resetToBootState(),
                      borderRadius: BorderRadius.circular(14),
                      child: Tooltip(
                        message: 'Inspect Edge Envoy Boot Architecture & Memory Lifecycle',
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: SepiaTheme.amber.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: SepiaTheme.amber.withValues(alpha: 0.5),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.bolt,
                                size: 13,
                                color: SepiaTheme.amber,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'BOOT SEQUENCE',
                                style: SepiaTheme.mono(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: SepiaTheme.ink,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  InkWell(
                    key: const Key('btn_mission_dossier'),
                    onTap: () => _showMissionDossierDialog(context),
                    borderRadius: BorderRadius.circular(14),
                    child: Tooltip(
                      message: 'Inspect Active Strategic Mission Briefing Dossier',
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: SepiaTheme.amber.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: SepiaTheme.amber.withValues(alpha: 0.5),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.shield_outlined,
                              size: 13,
                              color: SepiaTheme.amber,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'MISSION DOSSIER',
                              style: SepiaTheme.mono(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: SepiaTheme.ink,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (!AppModeService().isSimple && widget.onNavigateToDestination != null) ...[
                    const SizedBox(width: 8),
                    InkWell(
                      key: const Key('btn_open_game_memory_dev_tool'),
                      onTap: () => widget.onNavigateToDestination!(ShellNavDestination.memoryStudio),
                      borderRadius: BorderRadius.circular(14),
                      child: Tooltip(
                        message: 'Developer Diagnostic: Inspect live game turns and canon nodes in Memory Studio',
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: SepiaTheme.paperSubtle,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: SepiaTheme.border,
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.account_tree_outlined,
                                size: 13,
                                color: SepiaTheme.slate,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'DEV MEMORY ➔',
                                style: SepiaTheme.mono(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: SepiaTheme.slate,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                  if (!AppModeService().isSimple) ...[
                    const SizedBox(width: 8),
                    InkWell(
                      key: const Key('btn_toggle_genui_verbosity'),
                      onTap: () => s.toggleHideTextIfGenerativeUi(),
                      borderRadius: BorderRadius.circular(14),
                      child: Tooltip(
                        message: s.hideTextIfGenerativeUi
                            ? 'Generative UI Text: Hiding redundant outer speech'
                            : 'Generative UI Text: Showing redundant outer speech',
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: s.hideTextIfGenerativeUi
                                ? SepiaTheme.sage.withValues(alpha: 0.15)
                                : SepiaTheme.paperSubtle,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: s.hideTextIfGenerativeUi
                                  ? SepiaTheme.sage
                                  : SepiaTheme.border,
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                s.hideTextIfGenerativeUi
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                size: 13,
                                color: s.hideTextIfGenerativeUi
                                    ? SepiaTheme.sage
                                    : SepiaTheme.inkMuted,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                s.hideTextIfGenerativeUi ? 'GEN-UI CLEAN' : 'GEN-UI VERBOSE',
                                style: SepiaTheme.mono(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: s.hideTextIfGenerativeUi
                                      ? SepiaTheme.sage
                                      : SepiaTheme.inkMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(width: 8),
                  Text(
                    '⚡ < 60ms Edge TTFT (0 KB)',
                    style: SepiaTheme.mono(fontSize: 11, fontWeight: FontWeight.w700, color: SepiaTheme.sage),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    key: const Key('btn_toggle_living_lore_inspector'),
                    icon: Icon((widget.isRightDrawerOpen ?? _isRightDrawerOpen) ? Icons.menu_open : Icons.menu, size: 20, color: SepiaTheme.inkMuted),
                    tooltip: 'Toggle Living Lore Inspector',
                    onPressed: () {
                      if (widget.onToggleRightDrawer != null) {
                        widget.onToggleRightDrawer!();
                      } else {
                        setState(() {
                          _isRightDrawerOpen = !_isRightDrawerOpen;
                        });
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
        ),

        // Objective Milestone Toast (Real-time tactical feedback)
        if (s.activeMilestone != null)
          ObjectiveMilestoneToast(
            key: ValueKey(s.activeMilestone!.id),
            event: s.activeMilestone!,
            onDismiss: () => s.dismissMilestone(),
          ),

        // Active Quest Goal Ribbon (Unambiguous Stage, Objectives & Context)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
          decoration: BoxDecoration(
            color: SepiaTheme.paperSubtle,
            border: const Border(bottom: BorderSide(color: SepiaTheme.border, width: 1.0)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 2),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: SepiaTheme.amber.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: SepiaTheme.amber.withValues(alpha: 0.4), width: 1),
                ),
                child: Text(
                  s.isMissionVictory
                      ? 'VICTORY ACCORD'
                      : 'STAGE ${s.currentQuestStage + 1}/${s.getNpcQuestStages(s.activeNpc.id).length}',
                  style: SepiaTheme.mono(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: SepiaTheme.ink,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.flag_outlined, size: 14, color: SepiaTheme.ink),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            s.currentQuestGoal,
                            style: SepiaTheme.sans(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: SepiaTheme.ink,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      s.currentQuestContext,
                      style: SepiaTheme.sans(
                        fontSize: 11.5,
                        color: SepiaTheme.inkMuted,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        if (s.isGeneratingOptions)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 7.0),
            decoration: BoxDecoration(
              color: SepiaTheme.amber.withValues(alpha: 0.12),
              border: const Border(bottom: BorderSide(color: SepiaTheme.border)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(strokeWidth: 2, color: SepiaTheme.amber),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    '⚡ On-Device Gemma 4 int4 synthesizing dynamic next-turn cards... (0.0 KB egress)',
                    style: SepiaTheme.mono(fontSize: 11, fontWeight: FontWeight.w700, color: SepiaTheme.ink),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

        // Dialogue History Stream
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.all(16.0),
            itemCount: s.turns.length,
            itemBuilder: (ctx, idx) {
              return LoreCraftDialogueCard(
                turn: s.turns[idx],
                onA2UIAction: (action) {
                  if (action.actionId == 'open_dossier' || action.intent == 'inspect_dossier') {
                    _showMissionDossierDialog(context);
                  } else {
                    s.handleA2UIAction(action);
                  }
                },
                isCloudGenerating: s.isCloudImageGenerating,
                cloudGeneratingStatus: s.cloudImageStatus,
                hideTextIfGenerativeUi: s.hideTextIfGenerativeUi,
              );
            },
          ),
        ),


        // Input Box
        Container(
          padding: const EdgeInsets.all(12.0),
          decoration: const BoxDecoration(
            color: SepiaTheme.paper,
            border: Border(top: BorderSide(color: SepiaTheme.border, width: 1.0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              LoreCraftForesightPill(
                promptController: _promptController,
                loreService: s,
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _promptController,
                      enabled: !s.isExecuting && !s.isCloudImageGenerating,
                      style: SepiaTheme.sans(fontSize: 14, color: SepiaTheme.ink),
                      decoration: InputDecoration(
                        hintText: s.isCloudImageGenerating
                            ? 'Synthesizing visual asset via Nano Banana 2 Lite...'
                            : 'Speak with ${s.activeNpc.name}... (e.g. "Generate concept art of Forge Aegis" or "Trade raw ore")',
                        hintStyle: SepiaTheme.sans(fontSize: 13, color: SepiaTheme.inkMuted),
                        filled: true,
                        fillColor: SepiaTheme.paperSubtle,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: const BorderSide(color: SepiaTheme.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: const BorderSide(color: SepiaTheme.amber, width: 1.5),
                        ),
                      ),
                      onSubmitted: _handleSend,
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: (s.isExecuting || s.isCloudImageGenerating) ? null : () => _handleSend(_promptController.text),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: s.isCloudImageGenerating ? SepiaTheme.azure : SepiaTheme.amber,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    icon: (s.isExecuting || s.isCloudImageGenerating)
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.send, size: 16),
                    label: Text(
                      s.isCloudImageGenerating
                          ? 'Rendering...'
                          : (s.isExecuting ? 'Thinking...' : 'Send'),
                      style: SepiaTheme.sans(fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRightPanel(BuildContext context) {
    final s = widget.loreService;

    return Container(
      color: SepiaTheme.paper,
      padding: const EdgeInsets.all(14.0),
      child: ListView(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'LIVING LORE & ARBITER',
                  style: SepiaTheme.sans(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.0,
                    color: SepiaTheme.ink,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 16, color: SepiaTheme.inkMuted),
                tooltip: 'Close Drawer',
                onPressed: () {
                  setState(() {
                    _isRightDrawerOpen = false;
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text('Real-time Grounding & Memory Verification', style: SepiaTheme.sans(fontSize: 11, color: SepiaTheme.inkMuted)),
          const SizedBox(height: 12),
          const Divider(color: SepiaTheme.border, height: 1),
          const SizedBox(height: 12),

          // Canon & Voice Arbiter Card
          if (!AppModeService().isSimple) ...[
            LoreCraftCanonArbiterCard(
              rating: s.latestCanonRating,
            ),
            const SizedBox(height: 14),
          ],

          // Grounding Memory Anchors (< 50 KB Bundle)
          Text(
            'ACTIVE WORLD STATE ANCHORS (< 50 KB)',
            style: SepiaTheme.sans(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.8, color: SepiaTheme.inkMuted),
          ),
          const SizedBox(height: 6),
          ...s.worldAnchors.map((a) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 6.0),
              child: Container(
                padding: const EdgeInsets.all(8.0),
                decoration: BoxDecoration(
                  color: SepiaTheme.paperSubtle,
                  borderRadius: BorderRadius.circular(4),
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
                            a.key,
                            style: SepiaTheme.mono(fontSize: 11, fontWeight: FontWeight.w700, color: SepiaTheme.amber),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(a.category, style: SepiaTheme.sans(fontSize: 9, color: SepiaTheme.inkMuted)),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(a.distilledContext, style: SepiaTheme.sans(fontSize: 11, color: SepiaTheme.ink, height: 1.3)),
                  ],
                ),
              ),
            );
          }),

          const SizedBox(height: 10),

          // Active Rumors
          Text(
            'REGIONAL RUMORS',
            style: SepiaTheme.sans(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.8, color: SepiaTheme.inkMuted),
          ),
          const SizedBox(height: 6),
          ...s.activeRumors.map((r) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 4.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('● ', style: TextStyle(color: SepiaTheme.amber, fontSize: 10)),
                  Expanded(
                    child: Text(r, style: SepiaTheme.sans(fontSize: 11, color: SepiaTheme.inkMuted, height: 1.3)),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }


  Widget _buildMemoryBudgetMeter(LoreCraftService s) {
    final bytes = s.worldBundleSizeBytes;
    const maxBytes = 51200; // 50 KB
    final ratio = (bytes / maxBytes).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(10.0),
      decoration: BoxDecoration(
        color: SepiaTheme.paperSubtle,
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
                  'EDGE LORE BUNDLE',
                  style: SepiaTheme.sans(fontSize: 10, fontWeight: FontWeight.w700, color: SepiaTheme.inkMuted),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                '${(bytes / 1024).toStringAsFixed(1)} KB / 50.0 KB',
                style: SepiaTheme.mono(fontSize: 10, fontWeight: FontWeight.w600, color: SepiaTheme.sage),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: ratio,
              backgroundColor: SepiaTheme.paper,
              valueColor: const AlwaysStoppedAnimation<Color>(SepiaTheme.sage),
              minHeight: 5,
            ),
          ),
          if (!AppModeService().isSimple && widget.onNavigateToDestination != null) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                key: const Key('btn_drawer_open_memory_studio'),
                icon: const Icon(Icons.account_tree_outlined, size: 13),
                label: const Text('INSPECT IN MEMORY STUDIO ➔', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: SepiaTheme.slate,
                  side: const BorderSide(color: SepiaTheme.border),
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                ),
                onPressed: () => widget.onNavigateToDestination!(ShellNavDestination.memoryStudio),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
