import 'package:flutter/foundation.dart';

/// Represents a distinct strategic objective within an active campaign mission.
@immutable
class MissionObjective {
  final String id;
  final String title;
  final String description;
  final bool isCompleted;
  final String? targetFactionId;

  const MissionObjective({
    required this.id,
    required this.title,
    required this.description,
    this.isCompleted = false,
    this.targetFactionId,
  });

  MissionObjective copyWith({
    String? id,
    String? title,
    String? description,
    bool? isCompleted,
    String? targetFactionId,
  }) {
    return MissionObjective(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      isCompleted: isCompleted ?? this.isCompleted,
      targetFactionId: targetFactionId ?? this.targetFactionId,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'isCompleted': isCompleted,
    'targetFactionId': targetFactionId,
  };

  factory MissionObjective.fromJson(Map<String, dynamic> json) => MissionObjective(
    id: json['id'] as String,
    title: json['title'] as String,
    description: json['description'] as String,
    isCompleted: json['isCompleted'] as bool? ?? false,
    targetFactionId: json['targetFactionId'] as String?,
  );
}

/// Represents the strategic and political stakes of a specific faction in a mission.
@immutable
class FactionStake {
  final String factionId;
  final String factionName;
  final String stance;
  final String risk;
  final String opportunity;

  const FactionStake({
    required this.factionId,
    required this.factionName,
    required this.stance,
    required this.risk,
    required this.opportunity,
  });

  Map<String, dynamic> toJson() => {
    'factionId': factionId,
    'factionName': factionName,
    'stance': stance,
    'risk': risk,
    'opportunity': opportunity,
  };

  factory FactionStake.fromJson(Map<String, dynamic> json) => FactionStake(
    factionId: json['factionId'] as String,
    factionName: json['factionName'] as String,
    stance: json['stance'] as String,
    risk: json['risk'] as String,
    opportunity: json['opportunity'] as String,
  );
}

/// Represents an initial sector contact persona available to the player upon mission deployment.
@immutable
class SectorContact {
  final String npcId;
  final String name;
  final String title;
  final String regionId;
  final String regionName;
  final String briefing;
  final String openingTacticalDirective;

  const SectorContact({
    required this.npcId,
    required this.name,
    required this.title,
    required this.regionId,
    required this.regionName,
    required this.briefing,
    required this.openingTacticalDirective,
  });

  Map<String, dynamic> toJson() => {
    'npcId': npcId,
    'name': name,
    'title': title,
    'regionId': regionId,
    'regionName': regionName,
    'briefing': briefing,
    'openingTacticalDirective': openingTacticalDirective,
  };

  factory SectorContact.fromJson(Map<String, dynamic> json) => SectorContact(
    npcId: json['npcId'] as String,
    name: json['name'] as String,
    title: json['title'] as String,
    regionId: json['regionId'] as String,
    regionName: json['regionName'] as String,
    briefing: json['briefing'] as String,
    openingTacticalDirective: json['openingTacticalDirective'] as String,
  );
}

/// Overarching mission briefing presented to the Envoy before persona dialogue begins.
@immutable
class GameMission {
  final String id;
  final String title;
  final String subtitle;
  final String threatLevel;
  final String intelBriefing;
  final String harmonicResonatorStatus;
  final List<MissionObjective> primaryObjectives;
  final List<FactionStake> factionStakes;
  final List<SectorContact> sectorContacts;
  final String recommendedStartingNpcId;

  const GameMission({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.threatLevel,
    required this.intelBriefing,
    required this.harmonicResonatorStatus,
    required this.primaryObjectives,
    required this.factionStakes,
    required this.sectorContacts,
    this.recommendedStartingNpcId = 'gideon',
  });

  GameMission copyWith({
    String? id,
    String? title,
    String? subtitle,
    String? threatLevel,
    String? intelBriefing,
    String? harmonicResonatorStatus,
    List<MissionObjective>? primaryObjectives,
    List<FactionStake>? factionStakes,
    List<SectorContact>? sectorContacts,
    String? recommendedStartingNpcId,
  }) {
    return GameMission(
      id: id ?? this.id,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      threatLevel: threatLevel ?? this.threatLevel,
      intelBriefing: intelBriefing ?? this.intelBriefing,
      harmonicResonatorStatus: harmonicResonatorStatus ?? this.harmonicResonatorStatus,
      primaryObjectives: primaryObjectives ?? this.primaryObjectives,
      factionStakes: factionStakes ?? this.factionStakes,
      sectorContacts: sectorContacts ?? this.sectorContacts,
      recommendedStartingNpcId: recommendedStartingNpcId ?? this.recommendedStartingNpcId,
    );
  }

  /// Default campaign mission: The Aether-Core Rupture of Mount Khar-Drak.
  factory GameMission.defaultMission() {
    return const GameMission(
      id: 'mission-aether-rupture',
      title: 'OPERATION AETHER BREACH',
      subtitle: 'The Khar-Drak Subterranean Cataclysm',
      threatLevel: 'CRITICAL • LEVEL 4 ARCANE SURGE',
      intelBriefing:
          'Deep beneath Mount Khar-Drak, the ancient pre-cataclysm Aether-Core has suffered a catastrophic harmonic fracture. '
          'Superheated arcane magma is surging along three primary subterranean conduits, threatening to destabilize the mountain fortress, '
          'submerge the lower civilian aqueducts in toxic slag, and sever the ancient taproots of the Sylvan Canopy.\n\n'
          'As the Grand Council\'s Envoy, you carry the Harmonic Resonator. Each faction has mobilized with conflicting agendas:\n'
          '• The Iron Vanguard prepares to drop blast doors and seal the core, venting molten slag into the Undercity.\n'
          '• The Shadow Syndicate has discovered the purge plan and threatens sabotage to protect the lower quarter.\n'
          '• The Sylvan Enclave warns that sealing the vents will poison the World Tree\'s root network.\n\n'
          'Select your primary sector contact and deploy to negotiate, stabilize, or direct the crisis.',
      harmonicResonatorStatus: 'Harmonic Resonator: Synchronized • Local Resonance Frequency 14.8 MHz',
      primaryObjectives: [
        MissionObjective(
          id: 'obj-containment',
          title: 'Assess Core Breach Severity',
          description: 'Consult with High Artificer Gideon Stonehand at the Foundry to inspect bulkhead pressure gauges and forge defenses.',
          targetFactionId: 'vanguard',
        ),
        MissionObjective(
          id: 'obj-aqueduct',
          title: 'Investigate Undercity Conduits',
          description: 'Establish contact with Lyra Nightshade in the Undercity Vaults to verify flood water contamination and security ciphers.',
          targetFactionId: 'syndicate',
        ),
        MissionObjective(
          id: 'obj-resonance',
          title: 'Establish Canopy Harmonic Grounding',
          description: 'Coordinate with Arch-Botanist Elion Vane to ground volatile flux through living resonant crystalline flora.',
          targetFactionId: 'enclave',
        ),
      ],
      factionStakes: [
        FactionStake(
          factionId: 'vanguard',
          factionName: 'Iron Vanguard',
          stance: 'Fortify & Seal Blast Conduits',
          risk: 'Subterranean slag venting threatens lower civil districts.',
          opportunity: 'Secures high-carbon mithril armories and mountain citadel supremacy.',
        ),
        FactionStake(
          factionId: 'syndicate',
          factionName: 'Shadow Syndicate',
          stance: 'Expose Vanguard Negligence & Protect Aqueducts',
          risk: 'Unregulated lower vault pressure could trigger subterranean gas detonation.',
          opportunity: 'Liberates ancient runic tech and shatters Vanguard trade monopoly.',
        ),
        FactionStake(
          factionId: 'enclave',
          factionName: 'Sylvan Enclave',
          stance: 'Channel Arcane Flux into Living Leylines',
          risk: 'Toxic slag overflow will permanently blight ancient root springs.',
          opportunity: 'Harmonizes high-entropy aether into eternal regenerative growth.',
        ),
      ],
      sectorContacts: [
        SectorContact(
          npcId: 'gideon',
          name: 'Gideon Stonehand',
          title: 'High Artificer & Warmaster',
          regionId: 'foundry',
          regionName: 'Foundry of Khar-Drak',
          briefing: 'Holding the Upper Palisade against troll raids and magma overflows. Demands heavy ordnance and bulkhead containment.',
          openingTacticalDirective: 'Report to the Western Palisade to reinforce seismic bulkheads before thermal runaway.',
        ),
        SectorContact(
          npcId: 'lyra',
          name: 'Lyra Nightshade',
          title: 'Shadow Broker & Infiltrator',
          regionId: 'undercity',
          regionName: 'Undercity Vaults',
          briefing: 'Guarding subterranean sluice gates and black market conduits. Seeks proof of Vanguard sabotage.',
          openingTacticalDirective: 'Infiltrate the sunken sluice tunnels to inspect leaking runic conduit lines.',
        ),
        SectorContact(
          npcId: 'elion',
          name: 'Elion Vane',
          title: 'Arch-Botanist & Leyline Weaver',
          regionId: 'canopy',
          regionName: 'Whispering Canopy',
          briefing: 'Monitoring celestial alignment and root-spire resonance. Urges diplomatic balance and ecological grounding.',
          openingTacticalDirective: 'Climb the Keystone Spire to calibrate crystalline resonance array.',
        ),
      ],
      recommendedStartingNpcId: 'gideon',
    );
  }
}
