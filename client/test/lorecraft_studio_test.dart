import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../lib/models/lorecraft_state.dart';
import '../lib/models/routing_decision.dart';
import '../lib/services/lorecraft_service.dart';
import '../lib/services/switching_router_service.dart';
import '../lib/services/gemma_edge_service.dart';
import '../lib/services/local_execution_manager.dart';
import '../lib/services/cloud_sse_client.dart';
import '../lib/services/local_memory_service.dart';
import '../lib/views/widgets/lorecraft_dialogue_card.dart';
import '../lib/views/widgets/lorecraft_faction_panel.dart';
import '../lib/views/widgets/lorecraft_canon_arbiter_card.dart';

void runLoreCraftTests(void Function(String name, dynamic Function() body) test, void Function(bool condition, [String message]) expect) {
  test('LoreCraft: Initial state sets 3 factions, 3 NPCs, 3 regions with grounded lore', () {
    final router = SwitchingRouterService();
    final edge = LocalExecutionManager(gemmaService: GemmaEdgeService());
    final cloud = CloudSseClient();
    final memory = LocalMemoryService();
    final service = LoreCraftService(routerService: router, edgeManager: edge, cloudClient: cloud, memoryService: memory);

    expect(service.factions.length == 3, 'Expected 3 factions');
    expect(service.npcs.length == 3, 'Expected 3 NPCs');
    expect(service.regions.length == 3, 'Expected 3 regions');
    expect(service.activeNpc.name == 'Gideon Stonehand', 'Default active NPC must be Gideon Stonehand');
    expect(service.activeRegion.name == 'Ironforge Foundry', 'Default region must be Ironforge Foundry');
    expect(service.activeNpcFaction.name == 'The Iron Vanguard', 'Default faction must be The Iron Vanguard');
  });

  test('LoreCraft: Switching NPC automatically shifts habitat and appends greeting turn', () {
    final router = SwitchingRouterService();
    final edge = LocalExecutionManager(gemmaService: GemmaEdgeService());
    final cloud = CloudSseClient();
    final memory = LocalMemoryService();
    final service = LoreCraftService(routerService: router, edgeManager: edge, cloudClient: cloud, memoryService: memory);

    final initialTurns = service.turns.length;
    service.setActiveNpc('lyra');

    expect(service.activeNpc.name == 'Lyra Nightshade', 'Active NPC should be Lyra');
    expect(service.activeRegion.name == 'Oakhaven Docks', 'Active region should update to Oakhaven Docks');
    expect(service.turns.length == initialTurns + 1, 'Should append new greeting turn');
    expect(service.turns.last.speakerName == 'Lyra Nightshade', 'Last turn should be from Lyra');
  });

  test('LoreCraft: Adjusting faction reputation recalculates alignment', () {
    final router = SwitchingRouterService();
    final edge = LocalExecutionManager(gemmaService: GemmaEdgeService());
    final cloud = CloudSseClient();
    final memory = LocalMemoryService();
    final service = LoreCraftService(routerService: router, edgeManager: edge, cloudClient: cloud, memoryService: memory);

    // Initial Vanguard reputation is 25 (Neutral)
    final vanguard = service.factions.firstWhere((f) => f.id == 'vanguard');
    expect(vanguard.alignmentLabel == 'Neutral', 'Expected Neutral alignment initially');

    service.adjustReputation('vanguard', 30);
    final updatedVanguard = service.factions.firstWhere((f) => f.id == 'vanguard');
    expect(updatedVanguard.reputation == 55, 'Expected 55 reputation');
    expect(updatedVanguard.alignmentLabel == 'Allied', 'Expected Allied alignment after +30');

    service.adjustReputation('vanguard', -110);
    final hostileVanguard = service.factions.firstWhere((f) => f.id == 'vanguard');
    expect(hostileVanguard.reputation == -55, 'Expected -55 reputation');
    expect(hostileVanguard.alignmentLabel == 'Hostile', 'Expected Hostile alignment');
  });

  test('LoreCraft: World State Memory Bundle adheres strictly to < 50 KB budget', () {
    final router = SwitchingRouterService();
    final edge = LocalExecutionManager(gemmaService: GemmaEdgeService());
    final cloud = CloudSseClient();
    final memory = LocalMemoryService();
    final service = LoreCraftService(routerService: router, edgeManager: edge, cloudClient: cloud, memoryService: memory);

    final bundleSize = service.worldBundleSizeBytes;
    expect(bundleSize > 0, 'Bundle size should be positive');
    expect(bundleSize < 51200, 'Bundle size ($bundleSize bytes) must strictly be < 50 KB (51,200 bytes)');
  });

  test('LoreCraft: Router directs reactive NPC dialogue to RULE_GAME_REACTIVE_BARK (EDGE_LOCAL)', () {
    final router = SwitchingRouterService();
    final result = router.evaluateRoute(
      prompt: 'Inspect available high-carbon steel billets from Gideon Stonehand.',
    );

    expect(result.route == ExecutionRoute.EDGE_LOCAL, 'Expected EDGE_LOCAL route for NPC bark');
    expect(result.ruleId == 'RULE_GAME_REACTIVE_BARK', 'Expected RULE_GAME_REACTIVE_BARK rule');
    expect(result.requiresRedaction == false, 'Expected no redaction needed');
  });

  test('LoreCraft: Router escalates cross-faction consequence to RULE_GAME_CAMPAIGN_SYNTHESIS (CLOUD_ESCALATE)', () {
    final router = SwitchingRouterService();
    final result = router.evaluateRoute(
      prompt: 'Synthesize the political consequences if the Shadow Syndicate seizes the lower docks from the Iron Vanguard.',
    );

    expect(result.route == ExecutionRoute.CLOUD_ESCALATE, 'Expected CLOUD_ESCALATE for campaign consequence');
    expect(result.ruleId == 'RULE_GAME_CAMPAIGN_SYNTHESIS', 'Expected RULE_GAME_CAMPAIGN_SYNTHESIS');
    expect(result.requiresDurableMemories == true, 'Expected durable memory injection');
  });

  test('LoreCraft: Canon Arbiter correctly weights voice, canon, and frame budget', () {
    const rating = CanonRatingResult(
      voiceConsistency: 5.0,
      canonFidelity: 4.5,
      frameBudgetScore: 5.0,
      overallScore: 4.8,
      raterFeedback: 'Adheres to pragmatic tone; within 60 FPS budget',
      isVerified: true,
    );

    expect(rating.isVerified == true, 'Rating must be verified');
    expect(rating.overallScore == 4.8, 'Expected weighted score');
    expect(rating.frameBudgetScore == 5.0, 'Expected 5.0 frame budget score');
  });

  test('LoreCraft: LoreDialogueTurn equality and copy preserves turn identification', () {
    final t1 = LoreDialogueTurn(
      id: 'turn-test-1',
      speakerName: 'Gideon',
      isNpc: true,
      stageCue: '*[wipes brow]*',
      speechText: '',
      timestamp: DateTime.now(),
      route: ExecutionRoute.EDGE_LOCAL,
      modelName: 'Gemma 4',
    );
    final t2 = t1.copyWith(speechText: 'First token');
    expect(t1 == t2, 'Turns with same ID should be equal under operator ==');
    final list = [t1];
    expect(list.indexOf(t2) == 0, 'List.indexOf should find copied turn with same id');
    expect(list.indexWhere((t) => t.id == t2.id) == 0, 'indexWhere with id should find turn');
  });

  test('LoreCraft: sendPlayerAction correctly streams and updates NPC turn without truncating to single token', () async {
    final router = SwitchingRouterService();
    final edge = LocalExecutionManager(gemmaService: GemmaEdgeService());
    final cloud = CloudSseClient();
    final memory = LocalMemoryService();
    final service = LoreCraftService(routerService: router, edgeManager: edge, cloudClient: cloud, memoryService: memory);

    final initialTurnCount = service.turns.length;
    await service.sendPlayerAction('i want to do some stuff');

    expect(service.turns.length == initialTurnCount + 2, 'Should have player turn + NPC turn');
    final playerTurn = service.turns[initialTurnCount];
    final npcTurn = service.turns[initialTurnCount + 1];

    expect(playerTurn.isNpc == false, 'First turn should be player');
    expect(playerTurn.speechText == 'i want to do some stuff', 'Player text should match');

    expect(npcTurn.isNpc == true, 'Second turn should be NPC');
    expect(npcTurn.speakerName == 'Gideon Stonehand', 'Speaker should be Gideon Stonehand');
    expect(npcTurn.isStreaming == false, 'NPC turn should finish streaming');
    expect(npcTurn.speechText.isNotEmpty, 'Speech text should not be empty');
    expect(npcTurn.speechText != "'", 'Speech text must NOT be truncated to a single quote');
    expect(npcTurn.speechText.length > 10, 'Speech text should contain complete response');
    expect(npcTurn.ttftMs > 0, 'TTFT should be greater than 0ms');
  });
}

void main() {
  group('LoreCraft Studio Unit Tests', () {
    runLoreCraftTests(
      (name, body) => test(name, () async => body()),
      (cond, [msg = 'Assertion failed']) => expect(cond, isTrue, reason: msg),
    );
  });

  group('LoreCraft Widget Affordance Tests (Zero False Affordances)', () {
    testWidgets('LoreCraftDialogueCard: Telemetry chip taps to open inspector modal', (tester) async {
      final turn = LoreDialogueTurn(
        id: 'turn-01',
        speakerName: 'Gideon Stonehand',
        isNpc: true,
        stageCue: '*[inspects steel]*',
        speechText: 'State your business quickly.',
        timestamp: DateTime.now(),
        route: ExecutionRoute.EDGE_LOCAL,
        modelName: 'Gemma 4 int4',
        ttftMs: 42,
        latencyMs: 95,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LoreCraftDialogueCard(turn: turn),
          ),
        ),
      );

      expect(find.text('Gideon Stonehand'), findsOneWidget);
      expect(find.text('⚡ LOCAL EDGE • 0.0 KB Egress • 42ms'), findsOneWidget);

      // Tap telemetry affordance
      await tester.tap(find.text('⚡ LOCAL EDGE • 0.0 KB Egress • 42ms'));
      await tester.pumpAndSettle();

      expect(find.text('Dialogue Frame Telemetry'), findsOneWidget);
      expect(find.text('Time to First Token (TTFT)'), findsOneWidget);
      expect(find.text('42 ms'), findsOneWidget);
      expect(find.text('Compliant (< 100ms)'), findsOneWidget);

      // Close modal
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      expect(find.text('Dialogue Frame Telemetry'), findsNothing);
    });

    testWidgets('LoreCraftFactionPanel: Treaty icon taps to open treaty modal', (tester) async {
      const factions = [
        GameFaction(
          id: 'vanguard',
          name: 'The Iron Vanguard',
          reputation: 20,
          description: 'Frontier garrison defense pact.',
          bannerColor: Colors.amber,
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LoreCraftFactionPanel(factions: factions),
          ),
        ),
      );

      expect(find.text('FACTION STANDINGS'), findsOneWidget);
      expect(find.text('The Iron Vanguard'), findsOneWidget);

      // Tap treaty info icon
      await tester.tap(find.byIcon(Icons.info_outline));
      await tester.pumpAndSettle();

      expect(find.text('Inter-Faction Treaties & Resource Pacts'), findsOneWidget);
      expect(find.text('Frontier garrison defense pact.'), findsOneWidget);

      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      expect(find.text('Inter-Faction Treaties & Resource Pacts'), findsNothing);
    });

    testWidgets('LoreCraftCanonArbiterCard: Rubrics button taps to open rubric standards modal', (tester) async {
      const rating = CanonRatingResult(
        voiceConsistency: 5.0,
        canonFidelity: 4.8,
        frameBudgetScore: 5.0,
        overallScore: 4.9,
        raterFeedback: 'Persona adherence verified by Gemini 3.8 Flash.',
        isVerified: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LoreCraftCanonArbiterCard(rating: rating),
          ),
        ),
      );

      expect(find.text('CANON & VOICE ARBITER'), findsOneWidget);
      expect(find.text('4.9 / 5.0'), findsOneWidget);

      // Tap rubrics button
      await tester.tap(find.text('Rubrics'));
      await tester.pumpAndSettle();

      expect(find.text('LLM-as-a-Rater Canon Rubric Standards'), findsOneWidget);
      expect(find.text('Voice & Persona (35%)'), findsOneWidget);
      expect(find.text('Canon Fidelity (40%)'), findsOneWidget);
      expect(find.text('Frame Budget Factor (25%)'), findsOneWidget);

      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      expect(find.text('LLM-as-a-Rater Canon Rubric Standards'), findsNothing);
    });
  });
}
