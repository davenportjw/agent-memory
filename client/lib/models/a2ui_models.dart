import 'objective_milestone.dart';

/// A2UI Protocol Data Models conforming to https://a2ui.org specification (v0.9+).
///
/// Under A2UI, the host client statically defines the component catalog (`lorecraft_catalog.json`),
/// while the local or cloud agent dynamically outputs declarative UI surfaces.
/// Interactivity dispatches client-to-server action events back to the agentic runtime.

class A2UIAction {
  final String surfaceId;
  final String componentId;
  final String actionId;
  final String intent; // "local_dialogue", "visual_synthesis", "inspect_state"
  final Map<String, dynamic> parameters;

  const A2UIAction({
    required this.surfaceId,
    required this.componentId,
    required this.actionId,
    this.intent = 'local_dialogue',
    this.parameters = const {},
  });

  Map<String, dynamic> toJson() => {
    'surfaceId': surfaceId,
    'componentId': componentId,
    'actionId': actionId,
    'intent': intent,
    'parameters': parameters,
  };

  factory A2UIAction.fromJson(Map<String, dynamic> json) {
    return A2UIAction(
      surfaceId: json['surfaceId'] as String? ?? '',
      componentId: json['componentId'] as String? ?? '',
      actionId: json['actionId'] as String? ?? '',
      intent: json['intent'] as String? ?? 'local_dialogue',
      parameters: json['parameters'] != null
          ? Map<String, dynamic>.from(json['parameters'] as Map)
          : const {},
    );
  }
}

class A2UIChoiceItem {
  final String id;
  final String label;
  final String intent; // "local_dialogue", "visual_synthesis", "inspect_state"
  final String? description;
  final String? consequence;
  final String? prompt;
  final bool requiresCloud;

  const A2UIChoiceItem({
    required this.id,
    required this.label,
    this.intent = 'local_dialogue',
    this.description,
    this.consequence,
    this.prompt,
    this.requiresCloud = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'label': label,
    'intent': intent,
    if (description != null) 'description': description,
    if (consequence != null) 'consequence': consequence,
    if (prompt != null) 'prompt': prompt,
    'requiresCloud': requiresCloud,
  };

  factory A2UIChoiceItem.fromJson(Map<String, dynamic> json) {
    final rawRequiresCloud = json['requiresCloud'];
    final bool requiresCloud = rawRequiresCloud == true ||
        rawRequiresCloud == 'true' ||
        (json['intent'] == 'visual_synthesis');

    return A2UIChoiceItem(
      id: (json['id'] ?? json['choiceId'] ?? 'choice_${DateTime.now().microsecondsSinceEpoch}').toString(),
      label: (json['label'] ?? json['title'] ?? json['action'] ?? json['name'] ?? '').toString(),
      intent: (json['intent'] ?? (requiresCloud ? 'visual_synthesis' : 'local_dialogue')).toString(),
      description: (json['description'] ?? json['desc'] ?? json['details'] ?? json['summary'])?.toString(),
      consequence: (json['consequence'] ?? json['outcome'] ?? json['result'])?.toString(),
      prompt: (json['prompt'] ?? json['query'] ?? json['userPrompt'] ?? json['actionPrompt'] ?? json['label'])?.toString(),
      requiresCloud: requiresCloud,
    );
  }
}

class A2UIComponent {
  final String id;
  final String type; // Card, Text, Badge, Button, ChoiceGroup, Slider, ImageCanvas, Divider, Row, Column
  final Map<String, dynamic> properties;
  final List<String> childrenIds;

  const A2UIComponent({
    required this.id,
    required this.type,
    this.properties = const {},
    this.childrenIds = const [],
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type,
    'properties': properties,
    'childrenIds': childrenIds,
  };

  factory A2UIComponent.fromJson(Map<String, dynamic> json) {
    final rawChildren = json['childrenIds'] ?? json['children'];
    return A2UIComponent(
      id: json['id'] as String? ?? '',
      type: json['type'] as String? ?? 'Text',
      properties: json['properties'] != null
          ? Map<String, dynamic>.from(json['properties'] as Map)
          : const {},
      childrenIds: (rawChildren as List<dynamic>?)
              ?.map((e) => e is Map ? (e['id']?.toString() ?? '') : e.toString())
              .where((s) => s.isNotEmpty)
              .toList() ??
          const [],
    );
  }
}

class A2UISurface {
  final String surfaceId;
  final String catalogId;
  final String? rootComponentId;
  final List<A2UIComponent> components;

  const A2UISurface({
    required this.surfaceId,
    this.catalogId = 'a2ui:org:lorecraft:v1',
    this.rootComponentId,
    this.components = const [],
  });

  A2UIComponent? get rootComponent {
    if (components.isEmpty) return null;
    if (rootComponentId != null && rootComponentId!.isNotEmpty) {
      final found = findComponent(rootComponentId!);
      if (found != null) return found;
    }
    return components.first;
  }

  A2UIComponent? findComponent(String id) {
    for (final c in components) {
      if (c.id == id) return c;
    }
    return null;
  }

  Map<String, dynamic> toJson() => {
    'surfaceId': surfaceId,
    'catalogId': catalogId,
    if (rootComponentId != null) 'rootComponentId': rootComponentId,
    'components': components.map((c) => c.toJson()).toList(),
  };

  factory A2UISurface.fromJson(Map<String, dynamic> json) {
    final rawComps = json['components'] as List<dynamic>? ?? [];
    return A2UISurface(
      surfaceId: json['surfaceId'] as String? ?? '',
      catalogId: json['catalogId'] as String? ?? 'a2ui:org:lorecraft:v1',
      rootComponentId: json['rootComponentId'] as String?,
      components: rawComps
          .map((c) => A2UIComponent.fromJson(Map<String, dynamic>.from(c as Map)))
          .toList(),
    );
  }

  /// Convenience factory to generate a proactive turn surface with narrative context,
  /// clear objective goals (answering what to do & why), dilemma choices (local dialogue + cloud visual synthesis),
  /// Convenience factory to generate a proactive turn surface with narrative context,
  /// clear objective goals (answering what to do & why), dilemma choices (local dialogue + cloud visual synthesis),
  /// optional sliders, and Game Master Arbiter assessment commentary.
  factory A2UISurface.createProactiveTurn({
    required String surfaceId,
    String? objectiveTitle,
    String? objectiveContext,
    String? stageCue,
    String? spokenLine,
    required List<A2UIChoiceItem> choices,
    String? sliderLabel,
    double sliderValue = 50.0,
    String? sliderUnit,
    String? gameMasterCommentary,
    String? arbiterModelName,
    String? phaseBadge,
    bool isVictory = false,
    ObjectiveMilestoneEvent? milestoneEvent,
    String? completedObjectiveId,
    String? completedObjectiveTitle,
  }) {
    final components = <A2UIComponent>[];
    final rootChildren = <String>[];

    // 1. Game Master Arbiter attribution badge & tactical commentary (Model 2)
    if (arbiterModelName != null && arbiterModelName.isNotEmpty) {
      rootChildren.add('arbiter_badge');
      components.add(A2UIComponent(
        id: 'arbiter_badge',
        type: 'Badge',
        properties: {
          'label': 'GAME MASTER ARBITER • $arbiterModelName',
          'tone': 'cloud',
          'icon': 'sparkles',
        },
      ));
    }

    if (gameMasterCommentary != null && gameMasterCommentary.isNotEmpty) {
      rootChildren.add('arbiter_commentary');
      components.add(A2UIComponent(
        id: 'arbiter_commentary',
        type: 'Text',
        properties: {
          'text': gameMasterCommentary,
          'variant': 'body',
          'color': 'default',
        },
      ));
    }

    // 2. Game Moment: Strategic Milestone / Mission Objective Completion
    if (milestoneEvent != null || (completedObjectiveTitle != null && completedObjectiveTitle.isNotEmpty)) {
      final title = milestoneEvent?.title ?? completedObjectiveTitle!;
      final desc = milestoneEvent?.description ??
          'Strategic milestone confirmed. Mission Dossier tactical intelligence updated.';
      final factionStr = milestoneEvent != null
          ? 'Faction: ${milestoneEvent.faction} (${milestoneEvent.repDelta}) · Source: ${milestoneEvent.memorySource}'
          : 'Mission Intelligence Updated · Strategic Campaign Priority';

      rootChildren.add('milestone_card');
      components.add(A2UIComponent(
        id: 'milestone_card',
        type: 'Card',
        properties: {
          'variant': isVictory ? 'cloud_accent' : 'edge_accent',
          'padding': 10,
        },
        childrenIds: [
          'milestone_badge',
          'milestone_title',
          'milestone_desc',
          'milestone_meta',
          'milestone_btn',
        ],
      ));

      components.add(A2UIComponent(
        id: 'milestone_badge',
        type: 'Badge',
        properties: {
          'label': '🏆 STRATEGIC OBJECTIVE COMPLETED • MISSION DOSSIER UPDATED',
          'tone': isVictory ? 'cloud' : 'edge',
          'icon': 'shield',
        },
      ));

      components.add(A2UIComponent(
        id: 'milestone_title',
        type: 'Text',
        properties: {
          'text': title,
          'variant': 'subheading',
          'color': 'default',
        },
      ));

      components.add(A2UIComponent(
        id: 'milestone_desc',
        type: 'Text',
        properties: {
          'text': desc,
          'variant': 'body',
          'color': 'default',
        },
      ));

      components.add(A2UIComponent(
        id: 'milestone_meta',
        type: 'Text',
        properties: {
          'text': factionStr,
          'variant': 'caption',
          'color': 'muted',
        },
      ));

      components.add(A2UIComponent(
        id: 'milestone_btn',
        type: 'Button',
        properties: {
          'label': 'Inspect Mission Dossier ➔',
          'actionId': 'open_dossier',
          'intent': 'inspect_dossier',
          'tone': isVictory ? 'cloud' : 'edge',
          'payload': {
            'objectiveId': completedObjectiveId ?? '',
            'title': title,
          },
        },
      ));
    }

    if (stageCue != null && stageCue.isNotEmpty) {
      rootChildren.add('cue_text');
      components.add(A2UIComponent(
        id: 'cue_text',
        type: 'Text',
        properties: {
          'text': stageCue,
          'variant': 'stage_cue',
          'color': 'muted',
        },
      ));
    }

    if (spokenLine != null && spokenLine.isNotEmpty) {
      rootChildren.add('spoken_text');
      components.add(A2UIComponent(
        id: 'spoken_text',
        type: 'Text',
        properties: {
          'text': spokenLine,
          'variant': 'body',
          'color': 'default',
        },
      ));
    }

    if (objectiveTitle != null || objectiveContext != null) {
      final effTitle = objectiveTitle ?? 'Tactical Dilemma';
      final effContext = objectiveContext ?? 'Consider your course of action:';
      final prefix = phaseBadge != null ? '[$phaseBadge] ' : '';

      rootChildren.add('objective_badge');
      components.add(A2UIComponent(
        id: 'objective_badge',
        type: 'Badge',
        properties: {
          'label': '${prefix}CURRENT OBJECTIVE: $effTitle',
          'tone': isVictory ? 'cloud' : 'edge',
          'icon': isVictory ? 'sparkles' : 'shield',
        },
      ));

      rootChildren.add('objective_text');
      components.add(A2UIComponent(
        id: 'objective_text',
        type: 'Text',
        properties: {
          'text': effContext,
          'variant': 'body',
          'color': 'default',
        },
      ));
    }

    if (choices.isNotEmpty) {
      rootChildren.add('choice_group');
      components.add(A2UIComponent(
        id: 'choice_group',
        type: 'ChoiceGroup',
        properties: {
          'items': choices.map((c) => c.toJson()).toList(),
        },
      ));
    }

    if (sliderLabel != null) {
      rootChildren.add('dilemma_slider');
      components.add(A2UIComponent(
        id: 'dilemma_slider',
        type: 'Slider',
        properties: {
          'label': sliderLabel,
          'min': 0.0,
          'max': 100.0,
          'value': sliderValue,
          'unit': sliderUnit ?? '',
          'actionId': 'adjust_slider',
        },
      ));
    }

    // Insert the container card at index 0 as root
    components.insert(
      0,
      A2UIComponent(
        id: 'root_card',
        type: 'Card',
        properties: {
          'variant': isVictory ? 'cloud_accent' : 'edge_accent',
          'padding': 12,
        },
        childrenIds: rootChildren,
      ),
    );

    return A2UISurface(
      surfaceId: surfaceId,
      components: components,
    );
  }

  /// Convenience factory for cloud-generated visual synthesis surface.
  factory A2UISurface.createVisualSynthesisSurface({
    required String surfaceId,
    required String imageBase64,
    required String prompt,
    required String caption,
    required int latencyMs,
    required int egressBytes,
    String modelAttribution = 'Nano Banana 2 Lite (gemini-3.1-flash-lite-image)',
  }) {
    return A2UISurface(
      surfaceId: surfaceId,
      components: [
        A2UIComponent(
          id: 'root_canvas_card',
          type: 'Card',
          properties: {
            'variant': 'cloud_accent',
            'padding': 12,
          },
          childrenIds: ['visual_badge', 'visual_canvas', 'caption_text'],
        ),
        A2UIComponent(
          id: 'visual_badge',
          type: 'Badge',
          properties: {
            'label': '☁️ CLOUD SYNTHESIZED • $modelAttribution • ${latencyMs}ms',
            'tone': 'cloud',
            'icon': 'cloud',
          },
        ),
        A2UIComponent(
          id: 'visual_canvas',
          type: 'ImageCanvas',
          properties: {
            'imageBase64': imageBase64,
            'prompt': prompt,
            'caption': caption,
            'aspectRatio': '1:1',
            'latencyMs': latencyMs,
            'egressBytes': egressBytes,
            'modelAttribution': modelAttribution,
          },
        ),
        A2UIComponent(
          id: 'caption_text',
          type: 'Text',
          properties: {
            'text': caption,
            'variant': 'caption',
            'color': 'muted',
          },
        ),
      ],
    );
  }
}
