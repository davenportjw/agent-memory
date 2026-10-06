import 'package:flutter/material.dart';
import '../../models/game_mission.dart';
import '../../theme/sepia_theme.dart';

/// Mission briefing card presented to the Envoy prior to persona dialogue.
///
/// Complies with UI Clarity & TDD standards:
/// - Explicit affordance: What is this? Why does it matter? What happens next?
/// - Zero false affordances: Every button, radio card, and chip has an active handler.
/// - Distraction-free sepia aesthetic with clear visual hierarchy.
class LoreCraftMissionBriefingCard extends StatefulWidget {
  final GameMission mission;
  final void Function(String initialNpcId) onAcceptMission;

  const LoreCraftMissionBriefingCard({
    super.key,
    required this.mission,
    required this.onAcceptMission,
  });

  @override
  State<LoreCraftMissionBriefingCard> createState() => _LoreCraftMissionBriefingCardState();
}

class _LoreCraftMissionBriefingCardState extends State<LoreCraftMissionBriefingCard> {
  late String _selectedNpcId;

  @override
  void initState() {
    super.initState();
    _selectedNpcId = widget.mission.recommendedStartingNpcId;
  }

  @override
  Widget build(BuildContext context) {
    final mission = widget.mission;
    final selectedContact = mission.sectorContacts.firstWhere(
      (c) => c.npcId == _selectedNpcId,
      orElse: () => mission.sectorContacts.first,
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top Banner: Classified Mission Header
              Container(
                padding: const EdgeInsets.all(20.0),
                decoration: BoxDecoration(
                  color: SepiaTheme.paper,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: SepiaTheme.border, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isNarrow = constraints.maxWidth < 600;
                        final headerLeft = Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: SepiaTheme.amber.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.shield_outlined,
                                color: SepiaTheme.amber,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'GRAND COUNCIL STRATEGIC DIRECTIVE',
                                    style: SepiaTheme.mono(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 1.2,
                                      color: SepiaTheme.inkMuted,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    mission.title,
                                    style: SepiaTheme.sans(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.5,
                                      color: SepiaTheme.ink,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 2,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );

                        final threatBadge = Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: SepiaTheme.terracotta.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: SepiaTheme.terracotta.withValues(alpha: 0.5),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.warning_amber_rounded, size: 14, color: SepiaTheme.terracotta),
                              const SizedBox(width: 5),
                              Text(
                                mission.threatLevel,
                                style: SepiaTheme.mono(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                  color: SepiaTheme.terracotta,
                                ),
                              ),
                            ],
                          ),
                        );

                        if (isNarrow) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              headerLeft,
                              const SizedBox(height: 10),
                              threatBadge,
                            ],
                          );
                        }

                        return Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: headerLeft),
                            const SizedBox(width: 12),
                            threatBadge,
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 14),
                    Text(
                      mission.subtitle,
                      style: SepiaTheme.sans(
                        fontSize: 14,
                        fontStyle: FontStyle.italic,
                        fontWeight: FontWeight.w600,
                        color: SepiaTheme.inkMuted,
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Resonator Status Bar
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: SepiaTheme.paperSubtle,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: SepiaTheme.border),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.sensors, size: 16, color: SepiaTheme.sage),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              mission.harmonicResonatorStatus,
                              style: SepiaTheme.mono(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: SepiaTheme.ink,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: SepiaTheme.sage.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'READY TO DEPLOY',
                              style: SepiaTheme.mono(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                                color: SepiaTheme.sage,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // Crisis Intelligence Dossier
              Container(
                padding: const EdgeInsets.all(18.0),
                decoration: BoxDecoration(
                  color: SepiaTheme.paper,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: SepiaTheme.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.article_outlined, size: 16, color: SepiaTheme.amber),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'TACTICAL CRISIS INTELLIGENCE',
                            style: SepiaTheme.sans(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                              color: SepiaTheme.ink,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      mission.intelBriefing,
                      style: SepiaTheme.sans(
                        fontSize: 13,
                        color: SepiaTheme.ink,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // Primary Mission Objectives
              Container(
                padding: const EdgeInsets.all(18.0),
                decoration: BoxDecoration(
                  color: SepiaTheme.paper,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: SepiaTheme.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.checklist_rounded, size: 16, color: SepiaTheme.sage),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'PRIMARY STRATEGIC OBJECTIVES',
                            style: SepiaTheme.sans(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                              color: SepiaTheme.ink,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ...mission.primaryObjectives.map((obj) => _buildObjectiveTile(obj)),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // Faction Stakes Breakdown
              Container(
                padding: const EdgeInsets.all(18.0),
                decoration: BoxDecoration(
                  color: SepiaTheme.paper,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: SepiaTheme.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.balance, size: 16, color: SepiaTheme.inkMuted),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'FACTION STAKES & AGENDAS',
                            style: SepiaTheme.sans(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                              color: SepiaTheme.ink,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isNarrow = constraints.maxWidth < 650;
                        if (isNarrow) {
                          return Column(
                            children: mission.factionStakes
                                .map((s) => Padding(
                                      padding: const EdgeInsets.only(bottom: 10.0),
                                      child: _buildFactionStakeCard(s),
                                    ))
                                .toList(),
                          );
                        }
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: mission.factionStakes
                              .map((s) => Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 4.0),
                                      child: _buildFactionStakeCard(s),
                                    ),
                                  ))
                              .toList(),
                        );
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // Sector Contact Persona Selection
              Container(
                padding: const EdgeInsets.all(18.0),
                decoration: BoxDecoration(
                  color: SepiaTheme.paper,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: SepiaTheme.amber.withValues(alpha: 0.5), width: 1.5),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.person_pin_circle_outlined, size: 18, color: SepiaTheme.amber),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'SELECT INITIAL SECTOR CONTACT & ENTRY POINT',
                            style: SepiaTheme.sans(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                              color: SepiaTheme.ink,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Choose which faction persona you will consult first upon arriving in Khar-Drak:',
                      style: SepiaTheme.sans(fontSize: 12, color: SepiaTheme.inkMuted),
                    ),
                    const SizedBox(height: 14),
                    ...mission.sectorContacts.map((contact) => _buildContactRadioCard(contact)),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Primary Deployment CTA Button
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: SepiaTheme.amber.withValues(alpha: 0.25),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  key: const Key('btn_accept_mission_and_deploy'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: SepiaTheme.amber,
                    foregroundColor: Colors.black87,
                    padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 24.0),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                  ),
                  onPressed: () {
                    widget.onAcceptMission(_selectedNpcId);
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.rocket_launch_outlined, size: 20),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          'ACCEPT MISSION & DEPLOY TO ${selectedContact.regionName.toUpperCase()}',
                          style: SepiaTheme.sans(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.8,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.arrow_forward, size: 18),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),
              Center(
                child: Text(
                  'Deploying initiates on-device Gemma 4 dynamic dialogue turn engine with 0.0 KB cloud egress.',
                  style: SepiaTheme.mono(fontSize: 11, color: SepiaTheme.inkMuted),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildObjectiveTile(MissionObjective obj) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8.0),
      padding: const EdgeInsets.all(10.0),
      decoration: BoxDecoration(
        color: SepiaTheme.paperSubtle,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: SepiaTheme.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            obj.isCompleted ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 16,
            color: obj.isCompleted ? SepiaTheme.sage : SepiaTheme.inkMuted,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  obj.title,
                  style: SepiaTheme.sans(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: SepiaTheme.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  obj.description,
                  style: SepiaTheme.sans(
                    fontSize: 12,
                    color: SepiaTheme.inkMuted,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFactionStakeCard(FactionStake stake) {
    final Color badgeColor = stake.factionId == 'vanguard'
        ? SepiaTheme.amber
        : (stake.factionId == 'syndicate' ? SepiaTheme.terracotta : SepiaTheme.sage);

    return Container(
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: SepiaTheme.paperSubtle,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: SepiaTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: badgeColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: badgeColor.withValues(alpha: 0.4)),
            ),
            child: Text(
              stake.factionName.toUpperCase(),
              style: SepiaTheme.mono(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: SepiaTheme.ink,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            stake.stance,
            style: SepiaTheme.sans(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: SepiaTheme.ink,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Risk: ${stake.risk}',
            style: SepiaTheme.sans(
              fontSize: 11,
              color: SepiaTheme.terracotta,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Opportunity: ${stake.opportunity}',
            style: SepiaTheme.sans(
              fontSize: 11,
              color: SepiaTheme.sage,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactRadioCard(SectorContact contact) {
    final isSelected = _selectedNpcId == contact.npcId;

    return InkWell(
      key: Key('radio_contact_${contact.npcId}'),
      onTap: () {
        setState(() {
          _selectedNpcId = contact.npcId;
        });
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10.0),
        padding: const EdgeInsets.all(12.0),
        decoration: BoxDecoration(
          color: isSelected ? SepiaTheme.amber.withValues(alpha: 0.1) : SepiaTheme.paperSubtle,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? SepiaTheme.amber : SepiaTheme.border,
            width: isSelected ? 1.8 : 1.0,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2.0),
              child: Icon(
                isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                size: 18,
                color: isSelected ? SepiaTheme.amber : SepiaTheme.inkMuted,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      Text(
                        contact.name,
                        style: SepiaTheme.sans(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: SepiaTheme.ink,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: SepiaTheme.paper,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: SepiaTheme.border),
                        ),
                        child: Text(
                          contact.regionName,
                          style: SepiaTheme.mono(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: SepiaTheme.inkMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    contact.title,
                    style: SepiaTheme.sans(
                      fontSize: 11.5,
                      color: SepiaTheme.inkMuted,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    contact.briefing,
                    style: SepiaTheme.sans(
                      fontSize: 12,
                      color: SepiaTheme.ink,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.arrow_right_alt, size: 14, color: SepiaTheme.amber),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'Opening Directive: ${contact.openingTacticalDirective}',
                          style: SepiaTheme.sans(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: SepiaTheme.ink,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
