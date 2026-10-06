import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../lib/models/a2ui_models.dart';
import '../lib/views/widgets/lorecraft_dialogue_card.dart';
import '../lib/views/widgets/a2ui_surface_view.dart';
import '../lib/services/lorecraft_service.dart';
import '../lib/services/switching_router_service.dart';
import '../lib/services/gemma_edge_service.dart';
import '../lib/services/local_execution_manager.dart';
import '../lib/services/cloud_sse_client.dart';
import '../lib/services/local_memory_service.dart';

void main() {
  group('LoreCraft Dynamic Quest Progression & De-duplication Tests', () {
    late LoreCraftService service;

    setUp(() {
      final router = SwitchingRouterService();
      final edge = LocalExecutionManager(gemmaService: GemmaEdgeService());
      final cloud = CloudSseClient();
      final memory = LocalMemoryService();
      service = LoreCraftService(
        routerService: router,
        edgeManager: edge,
        cloudClient: cloud,
        memoryService: memory,
      );
    });

    test('Initial quest stage is 0 with unambiguous objective and context', () {
      expect(service.currentQuestStage, 0);
      expect(service.currentQuestGoal, contains('Equip Western Watch Post'));
      expect(service.currentQuestContext, contains('palisade'));

      final stages = service.getNpcQuestStages('gideon');
      expect(stages.length, 5);
      expect(stages[0].choices.length, 3);
      expect(stages[0].choices.first.consequence, isNotNull);
      expect(stages[0].choices.first.description, isNotNull);
    });

    test('Generative UI flag defaults to true and toggles properly', () {
      expect(service.hideTextIfGenerativeUi, isTrue);
      service.toggleHideTextIfGenerativeUi();
      expect(service.hideTextIfGenerativeUi, isFalse);
      service.toggleHideTextIfGenerativeUi();
      expect(service.hideTextIfGenerativeUi, isTrue);
    });

    testWidgets('LoreCraftDialogueCard always displays conversational speech text so the talking model is never hidden', (tester) async {
      final initialTurn = service.turns.first;
      expect(initialTurn.a2uiSurface, isNotNull);
      expect(initialTurn.speechText.isNotEmpty, isTrue);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: LoreCraftDialogueCard(
                turn: initialTurn,
                hideTextIfGenerativeUi: true,
              ),
            ),
          ),
        ),
      );

      // Conversational persona speech text MUST be visible so user always hears/reads the talking model
      expect(find.text(initialTurn.speakerName), findsOneWidget);
      expect(find.text(initialTurn.speechText), findsOneWidget);
      expect(find.byType(A2UISurfaceView), findsOneWidget);
    });

    testWidgets('LoreCraftDialogueCard shows outer text when hideTextIfGenerativeUi is false', (tester) async {
      final initialTurn = service.turns.first;
      expect(initialTurn.a2uiSurface, isNotNull);

      // Render with hideTextIfGenerativeUi = false (Verbose mode)
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: LoreCraftDialogueCard(
                turn: initialTurn,
                hideTextIfGenerativeUi: false,
              ),
            ),
          ),
        ),
      );

      // Outer speech text is visible alongside A2UI surface
      expect(find.text(initialTurn.speechText), findsOneWidget);
    });

    test('Executing an A2UI choice advances quest stage and removes completed action', () async {
      final initialStage = service.currentQuestStage;
      expect(initialStage, 0);

      // Trigger choice action
      final action = A2UIAction(
        surfaceId: 'surf-01',
        componentId: 'choice-group',
        actionId: 'select_choice',
        intent: 'local_dialogue',
        parameters: {
          'choiceId': 'barter_ore',
          'label': 'Barter Bog Iron Ore',
          'prompt': 'We brought three wagons of high-grade bog iron from the marshes.',
          'requiresCloud': false,
        },
      );

      await service.handleA2UIAction(action);

      // Verify progress
      final progress = service.getQuestProgress('gideon');
      expect(progress.completedActionIds.contains('barter_ore'), isTrue);
      expect(service.currentQuestStage, 1);
      expect(service.currentQuestGoal, contains('Direct Blacksmith Production'));

      // Generate new surface and verify choices are derived from Stage 1
      final nextSurface = service.generateNpcProactiveSurface('gideon');
      final choiceComp = nextSurface.components.firstWhere((c) => c.type == 'ChoiceGroup');
      final rawItems = choiceComp.properties['items'] as List<dynamic>;
      final choiceIds = rawItems.map((e) => (e as Map)['id'] as String).toList();
      expect(choiceIds, contains('forge_broadsword'));
      expect(choiceIds, contains('armor_billets'));
    });

    test('Lyra and Elion have independent 5-stage dynamic quest tracks', () {
      // Test Lyra
      service.setActiveNpc('lyra');
      expect(service.currentQuestStage, 0);
      expect(service.currentQuestGoal, contains('Slipway #4'));
      expect(service.currentQuestContext, contains('blockade runner'));
      expect(service.getNpcQuestStages('lyra').length, 5);

      // Test Elion
      service.setActiveNpc('elion');
      expect(service.currentQuestStage, 0);
      expect(service.currentQuestGoal, contains('Stabilize Lower Aqueduct'));
      expect(service.currentQuestContext, contains('Subterranean aquifer'));
      expect(service.getNpcQuestStages('elion').length, 5);
    });
  });
}
