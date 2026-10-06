import 'package:flutter/material.dart';
import 'routing_decision.dart';
import 'a2ui_models.dart';
import '../theme/sepia_theme.dart';

enum FactionAlignment {
  allied,
  neutral,
  strained,
  hostile,
}

class GameFaction {
  final String id;
  final String name;
  final int reputation; // -100 to 100
  final String description;
  final Color bannerColor;

  const GameFaction({
    required this.id,
    required this.name,
    required this.reputation,
    required this.description,
    required this.bannerColor,
  });

  FactionAlignment get alignment {
    if (reputation >= 50) return FactionAlignment.allied;
    if (reputation >= -10) return FactionAlignment.neutral;
    if (reputation >= -49) return FactionAlignment.strained;
    return FactionAlignment.hostile;
  }

  String get alignmentLabel {
    switch (alignment) {
      case FactionAlignment.allied:
        return 'Allied';
      case FactionAlignment.neutral:
        return 'Neutral';
      case FactionAlignment.strained:
        return 'Strained';
      case FactionAlignment.hostile:
        return 'Hostile';
    }
  }

  Color get alignmentColor {
    switch (alignment) {
      case FactionAlignment.allied:
        return SepiaTheme.sage;
      case FactionAlignment.neutral:
        return SepiaTheme.amber;
      case FactionAlignment.strained:
        return const Color(0xFFC07038);
      case FactionAlignment.hostile:
        return SepiaTheme.terracotta;
    }
  }

  GameFaction copyWith({int? reputation}) {
    return GameFaction(
      id: id,
      name: name,
      reputation: reputation ?? this.reputation,
      description: description,
      bannerColor: bannerColor,
    );
  }
}

class GameNpc {
  final String id;
  final String name;
  final String title;
  final String factionId;
  final String personalityPrompt;
  final String currentMood;
  final String voiceStyle;
  final IconData avatarIcon;
  final String location;

  const GameNpc({
    required this.id,
    required this.name,
    required this.title,
    required this.factionId,
    required this.personalityPrompt,
    required this.currentMood,
    required this.voiceStyle,
    required this.avatarIcon,
    required this.location,
  });

  String get regionId {
    switch (id) {
      case 'gideon':
        return 'foundry';
      case 'lyra':
        return 'docks';
      case 'elion':
        return 'spire';
      default:
        return 'foundry';
    }
  }
}

class WorldRegion {
  final String id;
  final String name;
  final String atmosphere;
  final String controllingFactionId;

  const WorldRegion({
    required this.id,
    required this.name,
    required this.atmosphere,
    required this.controllingFactionId,
  });
}

class LoreAnchor {
  final String id;
  final String key;
  final String category;
  final String distilledContext;

  const LoreAnchor({
    required this.id,
    required this.key,
    required this.category,
    required this.distilledContext,
  });
}

class LoreDialogueTurn {
  final String id;
  final String speakerName;
  final bool isNpc;
  final String stageCue;
  final String speechText;
  final DateTime timestamp;
  final ExecutionRoute route;
  final String modelName;
  final int ttftMs;
  final int latencyMs;
  final int egressBytes;
  final bool isStreaming;
  final bool isFallback;
  final String? fallbackReason;
  final Map<String, int>? reputationDelta;
  final A2UISurface? a2uiSurface;
  final String? visualImageBase64;
  final String? visualPrompt;
  final String? ruleId;
  final String? routeJustification;
  final String? memoryDelta;
  final bool isDynamicallyEscalated;
  final String? personaModelName;
  final String? arbiterModelName;
  final String? gameMasterCommentary;
  final bool isObjectiveCompleted;

  const LoreDialogueTurn({
    required this.id,
    required this.speakerName,
    required this.isNpc,
    required this.stageCue,
    required this.speechText,
    required this.timestamp,
    required this.route,
    required this.modelName,
    this.ttftMs = 0,
    this.latencyMs = 0,
    this.egressBytes = 0,
    this.isStreaming = false,
    this.isFallback = false,
    this.fallbackReason,
    this.reputationDelta,
    this.a2uiSurface,
    this.visualImageBase64,
    this.visualPrompt,
    this.ruleId,
    this.routeJustification,
    this.memoryDelta,
    this.isDynamicallyEscalated = false,
    this.personaModelName,
    this.arbiterModelName,
    this.gameMasterCommentary,
    this.isObjectiveCompleted = false,
  });

  bool get fpsCompliant => ttftMs <= 100;

  LoreDialogueTurn copyWith({
    String? stageCue,
    String? speechText,
    bool? isStreaming,
    int? ttftMs,
    int? latencyMs,
    int? egressBytes,
    String? modelName,
    ExecutionRoute? route,
    bool? isFallback,
    String? fallbackReason,
    Map<String, int>? reputationDelta,
    A2UISurface? a2uiSurface,
    String? visualImageBase64,
    String? visualPrompt,
    String? ruleId,
    String? routeJustification,
    String? memoryDelta,
    bool? isDynamicallyEscalated,
    String? personaModelName,
    String? arbiterModelName,
    String? gameMasterCommentary,
    bool? isObjectiveCompleted,
  }) {
    return LoreDialogueTurn(
      id: id,
      speakerName: speakerName,
      isNpc: isNpc,
      stageCue: stageCue ?? this.stageCue,
      speechText: speechText ?? this.speechText,
      timestamp: timestamp,
      route: route ?? this.route,
      modelName: modelName ?? this.modelName,
      ttftMs: ttftMs ?? this.ttftMs,
      latencyMs: latencyMs ?? this.latencyMs,
      egressBytes: egressBytes ?? this.egressBytes,
      isStreaming: isStreaming ?? this.isStreaming,
      isFallback: isFallback ?? this.isFallback,
      fallbackReason: fallbackReason ?? this.fallbackReason,
      reputationDelta: reputationDelta ?? this.reputationDelta,
      a2uiSurface: a2uiSurface ?? this.a2uiSurface,
      visualImageBase64: visualImageBase64 ?? this.visualImageBase64,
      visualPrompt: visualPrompt ?? this.visualPrompt,
      ruleId: ruleId ?? this.ruleId,
      routeJustification: routeJustification ?? this.routeJustification,
      memoryDelta: memoryDelta ?? this.memoryDelta,
      isDynamicallyEscalated: isDynamicallyEscalated ?? this.isDynamicallyEscalated,
      personaModelName: personaModelName ?? this.personaModelName,
      arbiterModelName: arbiterModelName ?? this.arbiterModelName,
      gameMasterCommentary: gameMasterCommentary ?? this.gameMasterCommentary,
      isObjectiveCompleted: isObjectiveCompleted ?? this.isObjectiveCompleted,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LoreDialogueTurn && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

class NpcQuestStage {
  final int stageIndex;
  final String objectiveTitle;
  final String objectiveContext;
  final List<A2UIChoiceItem> choices;
  final String sliderLabel;
  final double sliderValue;
  final String sliderUnit;

  const NpcQuestStage({
    required this.stageIndex,
    required this.objectiveTitle,
    required this.objectiveContext,
    required this.choices,
    required this.sliderLabel,
    this.sliderValue = 50.0,
    required this.sliderUnit,
  });
}

class NpcQuestProgress {
  final String npcId;
  int currentStageIndex;
  final Set<String> completedActionIds;
  double sliderValue;

  NpcQuestProgress({
    required this.npcId,
    this.currentStageIndex = 0,
    Set<String>? completedActionIds,
    this.sliderValue = 50.0,
  }) : completedActionIds = completedActionIds ?? <String>{};
}

class GameMasterAssessment {
  final String commentary;
  final double readinessDelta;
  final Map<String, int> factionDeltas;
  final bool isObjectiveCompleted;
  final List<A2UIChoiceItem> choices;
  final String arbiterModelName;

  const GameMasterAssessment({
    required this.commentary,
    required this.readinessDelta,
    required this.factionDeltas,
    required this.isObjectiveCompleted,
    required this.choices,
    required this.arbiterModelName,
  });
}

