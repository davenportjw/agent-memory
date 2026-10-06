import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../lib/models/game_mission.dart';
import '../lib/services/lorecraft_service.dart';
import '../lib/services/switching_router_service.dart';
import '../lib/services/gemma_edge_service.dart';
import '../lib/services/local_execution_manager.dart';
import '../lib/services/cloud_sse_client.dart';
import '../lib/services/local_memory_service.dart';
import '../lib/views/widgets/lorecraft_mission_briefing_card.dart';
import '../lib/views/lorecraft_boot_page_view.dart';
import '../lib/views/lorecraft_studio.dart';

void main() {
  group('GameMission Data Architecture Tests', () {
    test('Default mission initialization has required crisis narrative and 3 objectives', () {
      final mission = GameMission.defaultMission();
      expect(mission.id, 'mission-aether-rupture');
      expect(mission.title, 'OPERATION AETHER BREACH');
      expect(mission.threatLevel, contains('CRITICAL'));
      expect(mission.primaryObjectives.length, 3);
      expect(mission.factionStakes.length, 3);
      expect(mission.sectorContacts.length, 3);

      expect(mission.primaryObjectives.any((o) => o.id == 'obj-containment'), isTrue);
      expect(mission.primaryObjectives.any((o) => o.id == 'obj-aqueduct'), isTrue);
      expect(mission.primaryObjectives.any((o) => o.id == 'obj-resonance'), isTrue);
    });

    test('MissionObjective copyWith modifies completion status immutably', () {
      const obj = MissionObjective(
        id: 'test_obj',
        title: 'Stabilize Core',
        description: 'Test description',
        targetFactionId: 'vanguard',
      );
      expect(obj.isCompleted, isFalse);

      final completed = obj.copyWith(isCompleted: true);
      expect(completed.isCompleted, isTrue);
      expect(completed.title, 'Stabilize Core');
      expect(obj.isCompleted, isFalse);
    });
  });

  group('LoreCraftService Mission Lifecycle & Dynamic Choices Tests', () {
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

    test('Initial state requires mission acceptance prior to active dialogue', () {
      expect(service.hasAcceptedMission, isFalse);
      expect(service.activeMission.primaryObjectives.every((o) => !o.isCompleted), isTrue);
    });

    test('acceptMission deploys to selected contact and seeds crisis opening dialogue', () {
      service.acceptMission('lyra');
      expect(service.hasAcceptedMission, isTrue);
      expect(service.activeNpc.id, 'lyra');
      expect(service.activeRegion.id, 'docks');
      expect(service.turns.length, 1);
      expect(service.turns.first.speechText, contains('Quiet down, Envoy'));
      expect(service.turns.first.speakerName, 'Lyra Nightshade');
    });

    test('acceptMission with gideon seeds iron vanguard forge crisis dialogue', () {
      service.acceptMission('gideon');
      expect(service.hasAcceptedMission, isTrue);
      expect(service.activeNpc.id, 'gideon');
      expect(service.activeRegion.id, 'foundry');
      expect(service.turns.length, 1);
      expect(service.turns.first.speechText, contains('Aether-Core beneath the Foundry is cracking'));
    });

    test('completeMissionObjective updates objective state correctly', () {
      expect(service.activeMission.primaryObjectives.first.isCompleted, isFalse);
      service.completeMissionObjective('obj-containment');
      expect(
        service.activeMission.primaryObjectives.firstWhere((o) => o.id == 'obj-containment').isCompleted,
        isTrue,
      );
    });

    test('resetToMissionBriefing sets hasAcceptedMission back to false', () {
      service.acceptMission('elion');
      expect(service.hasAcceptedMission, isTrue);
      service.resetToMissionBriefing();
      expect(service.hasAcceptedMission, isFalse);
    });

    test('generateDynamicNextTurnOptions yields exactly 3 contextual cards', () async {
      final choices = await service.generateDynamicNextTurnOptions(
        npcId: 'gideon',
        latestDiscussion: 'The core pressure is rising rapidly near the thermal vents.',
        currentGoal: service.currentQuestGoal,
      );

      expect(choices.length, 3);
      // First 2 choices should be local dialogue on edge
      expect(choices[0].requiresCloud, isFalse);
      expect(choices[0].intent, 'local_dialogue');
      expect(choices[1].requiresCloud, isFalse);
      expect(choices[1].intent, 'local_dialogue');
      // Third choice should be cloud visual synthesis
      expect(choices[2].requiresCloud, isTrue);
      expect(choices[2].intent, 'visual_synthesis');
    });

    test('Dynamic option generation handles Lyra subterranean water context', () async {
      final choices = await service.generateDynamicNextTurnOptions(
        npcId: 'lyra',
        latestDiscussion: 'The toxic volcanic slag is threatening the municipal aqueduct valves.',
        currentGoal: service.currentQuestGoal,
      );

      expect(choices.length, 3);
      expect(choices.any((c) => c.label.contains('Valve Ciphers') || c.label.contains('Sluice')), isTrue);
      expect(choices.any((c) => c.intent == 'visual_synthesis'), isTrue);
    });
  });

  group('LoreCraftMissionBriefingCard Widget Tests', () {
    testWidgets('Renders crisis header, threat badge, objectives, and sector contacts', (tester) async {
      final mission = GameMission.defaultMission();
      String? acceptedNpcId;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LoreCraftMissionBriefingCard(
              mission: mission,
              onAcceptMission: (npcId) {
                acceptedNpcId = npcId;
              },
            ),
          ),
        ),
      );

      expect(find.textContaining('OPERATION AETHER BREACH'), findsOneWidget);
      expect(find.textContaining('CRITICAL • LEVEL 4 ARCANE SURGE'), findsOneWidget);
      expect(find.text('TACTICAL CRISIS INTELLIGENCE'), findsOneWidget);
      expect(find.text('PRIMARY STRATEGIC OBJECTIVES'), findsOneWidget);
      expect(find.text('FACTION STAKES & AGENDAS'), findsOneWidget);

      // Verify all 3 sector contacts are rendered
      expect(find.text('Gideon Stonehand'), findsOneWidget);
      expect(find.text('Lyra Nightshade'), findsOneWidget);
      expect(find.text('Elion Vane'), findsOneWidget);

      // Verify selecting Lyra changes selection and clicking CTA deploys to Lyra
      final lyraFinder = find.byKey(const Key('radio_contact_lyra'));
      await tester.ensureVisible(lyraFinder);
      await tester.tap(lyraFinder);
      await tester.pumpAndSettle();

      expect(find.textContaining('DEPLOY TO UNDERCITY VAULTS'), findsOneWidget);

      // Click Accept Mission CTA
      final deployFinder = find.byKey(const Key('btn_accept_mission_and_deploy'));
      await tester.ensureVisible(deployFinder);
      await tester.tap(deployFinder);
      await tester.pumpAndSettle();

      expect(acceptedNpcId, 'lyra');
    });
  });

  group('LoreCraftStudio Pre-Conversation & Dossier Integration Tests', () {
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

    testWidgets('Presents Boot Page on initial entry, then Mission Briefing upon Enter World, then Dialogue after acceptance', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: LoreCraftStudio(loreService: service),
        ),
      );
      await tester.pumpAndSettle();

      // Initial state: Boot Page is shown for first-time visitor
      expect(find.byType(LoreCraftBootPageView), findsOneWidget);
      expect(find.text('ENVOY EDGE BOOT ARCHITECTURE'), findsOneWidget);
      expect(service.hasCompletedBoot, isFalse);

      // Tap "INITIALIZE ENVOY & ENTER THE WORLD"
      final enterWorldFinder = find.byKey(const Key('btn_enter_world'));
      await tester.ensureVisible(enterWorldFinder);
      await tester.tap(enterWorldFinder);
      await tester.pumpAndSettle();

      // Now boot complete: Mission Briefing card is shown
      expect(service.hasCompletedBoot, isTrue);
      expect(find.byType(LoreCraftMissionBriefingCard), findsOneWidget);
      expect(find.text('PRE-DEPLOYMENT BRIEFING'), findsOneWidget);

      // Revisit boot sequence from briefing top bar
      final revisitBootFinder = find.byKey(const Key('btn_revisit_boot_sequence_briefing'));
      await tester.ensureVisible(revisitBootFinder);
      await tester.tap(revisitBootFinder);
      await tester.pumpAndSettle();

      // Verified: Returns to Boot Page
      expect(find.byType(LoreCraftBootPageView), findsOneWidget);
      expect(service.hasCompletedBoot, isFalse);

      // Enter world again to return to briefing
      await tester.ensureVisible(enterWorldFinder);
      await tester.tap(enterWorldFinder);
      await tester.pumpAndSettle();
      expect(find.byType(LoreCraftMissionBriefingCard), findsOneWidget);

      // Click "Accept Mission & Deploy to Foundry of Khar-Drak"
      final studioDeployFinder = find.byKey(const Key('btn_accept_mission_and_deploy'));
      await tester.ensureVisible(studioDeployFinder);
      await tester.tap(studioDeployFinder);
      await tester.pumpAndSettle();

      // Now accepted: Dialogue stream is rendered with Mission Dossier and Boot Sequence pills
      expect(service.hasAcceptedMission, isTrue);
      expect(find.text('MISSION DOSSIER'), findsOneWidget);
      expect(find.text('BOOT SEQUENCE'), findsOneWidget);
      expect(find.text('STAGE 1/5'), findsOneWidget);
      expect(service.turns.first.speechText, contains('Aether-Core beneath the Foundry is cracking'));

      // Tapping "MISSION DOSSIER" opens the dossier modal
      await tester.tap(find.byKey(const Key('btn_mission_dossier')));
      await tester.pumpAndSettle();

      expect(find.text('ACTIVE STRATEGIC MISSION DOSSIER'), findsOneWidget);
    });
  });
}
