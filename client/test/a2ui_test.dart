import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:client/models/a2ui_models.dart';

void main() {
  group('A2UI Protocol Models', () {
    test('A2UIAction serializes and deserializes properly', () {
      final action = A2UIAction(
        surfaceId: 'surface_1',
        componentId: 'choice_group_1',
        actionId: 'select_choice',
        intent: 'visual_synthesis',
        parameters: {'choiceId': 'forge_aegis', 'prompt': 'Aegis shield'},
      );

      final jsonMap = action.toJson();
      expect(jsonMap['surfaceId'], 'surface_1');
      expect(jsonMap['componentId'], 'choice_group_1');
      expect(jsonMap['actionId'], 'select_choice');
      expect(jsonMap['intent'], 'visual_synthesis');
      expect(jsonMap['parameters']['choiceId'], 'forge_aegis');

      final restored = A2UIAction.fromJson(jsonMap);
      expect(restored.surfaceId, action.surfaceId);
      expect(restored.componentId, action.componentId);
      expect(restored.actionId, action.actionId);
      expect(restored.intent, action.intent);
      expect(restored.parameters['prompt'], 'Aegis shield');
    });

    test('A2UIChoiceItem serializes and deserializes properly', () {
      final choice = A2UIChoiceItem(
        id: 'inspect_box',
        label: 'Inspect Encrypted Lockbox',
        intent: 'visual_synthesis',
        description: 'Synthesizes visual concept art of the lockbox',
        prompt: 'A fantasy brass and obsidian cipher lockbox with glowing runes',
        requiresCloud: true,
      );

      final jsonMap = choice.toJson();
      expect(jsonMap['id'], 'inspect_box');
      expect(jsonMap['label'], 'Inspect Encrypted Lockbox');
      expect(jsonMap['intent'], 'visual_synthesis');
      expect(jsonMap['requiresCloud'], isTrue);

      final restored = A2UIChoiceItem.fromJson(jsonMap);
      expect(restored.id, choice.id);
      expect(restored.label, choice.label);
      expect(restored.requiresCloud, isTrue);
      expect(restored.prompt, contains('obsidian cipher lockbox'));
    });

    test('A2UISurface createProactiveTurn produces valid catalog tree', () {
      final surface = A2UISurface.createProactiveTurn(
        surfaceId: 'gideon_proactive_001',
        stageCue: 'Gideon hammers the molten ingot against the anvil...',
        spokenLine: 'State your business, traveler. The garrison needs steel.',
        choices: [
          A2UIChoiceItem(
            id: 'forge_aegis',
            label: 'Forge Commander\'s Aegis',
            intent: 'visual_synthesis',
            prompt: 'Gideon\'s masterwork steel and brass commander shield',
            requiresCloud: true,
          ),
          A2UIChoiceItem(
            id: 'barter_ore',
            label: 'Barter Ore Allocation',
            intent: 'local_dialogue',
            requiresCloud: false,
          ),
        ],
        sliderLabel: 'Ore Allocation Ratio',
        sliderValue: 65.0,
        sliderUnit: '%',
      );

      expect(surface.surfaceId, 'gideon_proactive_001');
      expect(surface.catalogId, 'a2ui:org:lorecraft:v1');
      expect(surface.components.length, 5); // Root card, cue, spoken, choices, slider

      final root = surface.rootComponent;
      expect(root, isNotNull);
      expect(root!.type, 'Card');
      expect(root.childrenIds.length, 4);

      final choiceComp = surface.findComponent('choice_group');
      expect(choiceComp, isNotNull);
      expect(choiceComp!.type, 'ChoiceGroup');
      final items = choiceComp.properties['items'] as List;
      expect(items.length, 2);

      final sliderComp = surface.findComponent('dilemma_slider');
      expect(sliderComp, isNotNull);
      expect(sliderComp!.type, 'Slider');
      expect(sliderComp.properties['value'], 65.0);

      // JSON round-trip
      final jsonStr = jsonEncode(surface.toJson());
      final decoded = A2UISurface.fromJson(jsonDecode(jsonStr) as Map<String, dynamic>);
      expect(decoded.surfaceId, surface.surfaceId);
      expect(decoded.components.length, surface.components.length);
    });

    test('A2UISurface createVisualSynthesisSurface produces valid visual canvas', () {
      final surface = A2UISurface.createVisualSynthesisSurface(
        surfaceId: 'visual_surface_001',
        imageBase64: 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
        prompt: 'Gideon Commander Aegis Shield',
        caption: 'Masterwork Aegis Shield synthesized via Nano Banana 2 Lite',
        latencyMs: 1420,
        egressBytes: 40960,
      );

      expect(surface.components.length, 4);
      final canvas = surface.findComponent('visual_canvas');
      expect(canvas, isNotNull);
      expect(canvas!.type, 'ImageCanvas');
      expect(canvas.properties['latencyMs'], 1420);
      expect(canvas.properties['egressBytes'], 40960);
      expect(canvas.properties['modelAttribution'], contains('Nano Banana 2 Lite'));
    });
  });
}
