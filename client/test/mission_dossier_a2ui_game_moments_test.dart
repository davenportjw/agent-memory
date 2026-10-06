import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../lib/models/a2ui_models.dart';
import '../lib/models/lorecraft_state.dart';
import '../lib/models/objective_milestone.dart';
import '../lib/models/routing_decision.dart';
import '../lib/services/cloud_sse_client.dart';
import '../lib/services/gemma_edge_service.dart';
import '../lib/services/local_execution_manager.dart';
import '../lib/services/local_memory_service.dart';
import '../lib/services/lorecraft_service.dart';
import '../lib/services/switching_router_service.dart';
import '../lib/views/lorecraft_studio.dart';
import '../lib/views/widgets/a2ui_surface_view.dart';
import '../lib/views/widgets/lorecraft_mission_briefing_card.dart';

void main() {
  group('Mission Dossier Auto-Update & A2UI Game Moments Tests', () {
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

    test('Selecting milestone A2UI action updates Mission Dossier objective to completed', () async {
      // Prior to milestone, obj-aqueduct is incomplete
      final initialAqueduct = service.activeMission.primaryObjectives
          .firstWhere((o) => o.id == 'obj-aqueduct');
      expect(initialAqueduct.isCompleted, isFalse);

      // Trigger cipher milestone via A2UI action
      await service.handleA2UIAction(const A2UIAction(
        surfaceId: 'test-surface',
        componentId: 'choice_cipher',
        actionId: 'select_choice',
        intent: 'local_dialogue',
        parameters: {
          'choiceId': 'dock_cipher',
          'label': 'Siphon Undercity Sluice Gate Ciphers',
          'prompt': 'Decrypting the sluice ciphers',
        },
      ));

      // Active mission primary objective must now be marked completed
      final updatedAqueduct = service.activeMission.primaryObjectives
          .firstWhere((o) => o.id == 'obj-aqueduct');
      expect(updatedAqueduct.isCompleted, isTrue);
      expect(service.activeMilestone?.title, 'Aqueduct Valve Ciphers Secured');
    });

    test('Advancing quest stages to climax/victory auto-completes sector objective in Dossier', () {
      final initialContainment = service.activeMission.primaryObjectives
          .firstWhere((o) => o.id == 'obj-containment');
      expect(initialContainment.isCompleted, isFalse);

      final stages = service.getNpcQuestStages('gideon');
      // Advance to climax
      for (var i = 0; i < stages.length - 2; i++) {
        service.advanceQuestStage('gideon');
      }

      final updatedContainment = service.activeMission.primaryObjectives
          .firstWhere((o) => o.id == 'obj-containment');
      expect(updatedContainment.isCompleted, isTrue);
    });

    test('generateNpcProactiveSurface constructs A2UI Game Moment Card when milestoneEvent is provided', () {
      final milestone = ObjectiveMilestoneEvent(
        id: 'ms-test-resonance',
        title: 'Keystone Spire Leyline Attuned',
        description: 'Harmonized aether-crystal prism at 1.618 delta harmonic.',
        faction: 'Sylvan Enclave',
        repDelta: '+4 Rep',
        memorySource: 'Local Edge Memory Cache (0ms)',
        latencyMs: 0,
        timestamp: DateTime.now(),
      );

      final surface = service.generateNpcProactiveSurface(
        'elion',
        milestoneEvent: milestone,
        completedObjectiveId: 'obj-resonance',
        completedObjectiveTitle: 'Keystone Spire Leyline Attuned',
      );

      // Verify the Game Moment Card component exists in surface
      final cardComp = surface.components.firstWhere((c) => c.id == 'milestone_card');
      expect(cardComp.type, 'Card');
      expect(cardComp.properties['variant'], 'edge_accent');

      // Verify celebratory badge
      final badgeComp = surface.components.firstWhere((c) => c.id == 'milestone_badge');
      expect(badgeComp.type, 'Badge');
      expect(badgeComp.properties['label'], contains('STRATEGIC OBJECTIVE COMPLETED'));
      expect(badgeComp.properties['icon'], 'shield');

      // Verify title & inspect dossier button
      final titleComp = surface.components.firstWhere((c) => c.id == 'milestone_title');
      expect(titleComp.properties['text'], 'Keystone Spire Leyline Attuned');

      final btnComp = surface.components.firstWhere((c) => c.id == 'milestone_btn');
      expect(btnComp.type, 'Button');
      expect(btnComp.properties['label'], 'Inspect Mission Dossier ➔');
      expect(btnComp.properties['actionId'], 'open_dossier');
      expect(btnComp.properties['intent'], 'inspect_dossier');
    });

    testWidgets('A2UISurfaceView renders Game Moment Card with Inspect Mission Dossier button', (tester) async {
      A2UIAction? dispatchedAction;

      final milestone = ObjectiveMilestoneEvent(
        id: 'ms-render-test',
        title: 'Foundry Slag Containment Reinforced',
        description: 'Emergency basalt divert locks engaged, shielding primary municipal cooling basins.',
        faction: 'Iron Vanguard',
        repDelta: '+4 Rep',
        memorySource: 'Local Edge Memory Cache (0ms)',
        latencyMs: 0,
        timestamp: DateTime.now(),
      );

      final surface = service.generateNpcProactiveSurface(
        'gideon',
        milestoneEvent: milestone,
        completedObjectiveId: 'obj-containment',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: A2UISurfaceView(
                surface: surface,
                onAction: (action) => dispatchedAction = action,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Ensure Game Moment Card content is visible
      expect(find.textContaining('STRATEGIC OBJECTIVE COMPLETED'), findsOneWidget);
      expect(find.text('Foundry Slag Containment Reinforced'), findsOneWidget);
      expect(find.textContaining('Emergency basalt divert locks engaged'), findsOneWidget);
      expect(find.textContaining('Iron Vanguard'), findsOneWidget);

      // Verify button and icon affordance
      final dossierBtn = find.text('Inspect Mission Dossier ➔');
      expect(dossierBtn, findsOneWidget);
      expect(find.byIcon(Icons.assignment_outlined), findsOneWidget);

      // Tap button and verify action dispatch
      await tester.tap(dossierBtn);
      await tester.pumpAndSettle();

      expect(dispatchedAction, isNotNull);
      expect(dispatchedAction!.actionId, 'open_dossier');
      expect(dispatchedAction!.intent, 'inspect_dossier');
    });

    testWidgets('Tapping Inspect Mission Dossier in LoreCraftStudio opens briefing modal with checkmark', (tester) async {
      service.completeBootState();
      service.acceptMission('lyra');
      // Complete obj-aqueduct on mission
      service.completeMissionObjective('obj-aqueduct');

      final milestone = ObjectiveMilestoneEvent(
        id: 'ms-aqueduct-live',
        title: 'Aqueduct Valve Ciphers Secured',
        description: 'Decrypted emergency bypass frequencies.',
        faction: 'Shadow Collective',
        repDelta: '+4 Rep',
        memorySource: 'Local Edge Memory Cache (0ms)',
        latencyMs: 0,
        timestamp: DateTime.now(),
      );

      // Add turn with proactive surface containing Game Moment Card
      final proactiveSurface = service.generateNpcProactiveSurface(
        'lyra',
        milestoneEvent: milestone,
        completedObjectiveId: 'obj-aqueduct',
      );

      service.turns.clear();
      service.turns.add(LoreDialogueTurn(
        id: 'turn-milestone-demo',
        speakerName: 'Lyra Nightshade',
        isNpc: true,
        stageCue: '*[nods in approval]*',
        speechText: 'The bypass frequencies are locked into our relay.',
        timestamp: DateTime.now(),
        route: ExecutionRoute.EDGE_LOCAL,
        modelName: 'Gemma 4 int4',
        a2uiSurface: proactiveSurface,
        isObjectiveCompleted: true,
      ));

      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: LoreCraftStudio(loreService: service),
        ),
      );
      await tester.pumpAndSettle();

      // Find the Inspect Mission Dossier button in the dialogue stream
      final inspectBtn = find.text('Inspect Mission Dossier ➔');
      expect(inspectBtn, findsOneWidget);

      // Tap the button to launch the Mission Dossier modal dialog
      await tester.tap(inspectBtn);
      await tester.pumpAndSettle();

      // Verify the Active Strategic Mission Dossier dialog opens
      expect(find.text('ACTIVE STRATEGIC MISSION DOSSIER'), findsOneWidget);
      expect(find.byType(LoreCraftMissionBriefingCard), findsOneWidget);

      // Verify that completed objective has the green checkmark
      expect(find.byIcon(Icons.check_circle), findsAtLeastNWidgets(1));
    });
  });
}
