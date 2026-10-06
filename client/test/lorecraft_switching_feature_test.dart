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
import '../lib/views/widgets/lorecraft_router_dial.dart';
import '../lib/views/widgets/lorecraft_foresight_pill.dart';
import '../lib/views/widgets/lorecraft_dialogue_card.dart';

void main() {
  group('LoreCraft Dynamic Switching Policy Feature Tests', () {
    test('LoreCraftService: previewRoute and mode override work dynamically', () {
      final router = SwitchingRouterService();
      final edge = LocalExecutionManager(gemmaService: GemmaEdgeService());
      final cloud = CloudSseClient();
      final memory = LocalMemoryService();
      final service = LoreCraftService(
        routerService: router,
        edgeManager: edge,
        cloudClient: cloud,
        memoryService: memory,
      );

      // Default preview
      final localPreview = service.previewRoute('What iron ingots do you have for sale?');
      expect(localPreview.route, ExecutionRoute.EDGE_LOCAL);
      expect(localPreview.ruleId, 'RULE_GAME_REACTIVE_BARK');

      // Campaign preview
      final campaignPreview = service.previewRoute(
        'Synthesize the political consequences if the Shadow Syndicate seizes the lower docks from the Iron Vanguard.',
      );
      expect(campaignPreview.route, ExecutionRoute.CLOUD_ESCALATE);
      expect(campaignPreview.ruleId, 'RULE_GAME_CAMPAIGN_SYNTHESIS');

      // Visual preview
      final visualPreview = service.previewRoute('Forge the masterwork aegis blueprint');
      expect(visualPreview.ruleId, 'RULE_GAME_VISUAL_SYNTHESIS');

      // Mode override
      service.setRouterModeOverride(RouterModeOverride.enforceEdgeLocal);
      expect(service.routerModeOverride, RouterModeOverride.enforceEdgeLocal);

      final forcedEdge = service.previewRoute(
        'Synthesize the political consequences if the Shadow Syndicate seizes the lower docks from the Iron Vanguard.',
      );
      expect(forcedEdge.route, ExecutionRoute.EDGE_LOCAL);
    });

    testWidgets('LoreCraftRouterDial: Renders plain-English modes and toggles override', (tester) async {
      RouterModeOverride currentOverride = RouterModeOverride.auto;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (ctx, setState) => LoreCraftRouterDial(
                selectedMode: currentOverride,
                onModeSelected: (RouterModeOverride mode) {
                  setState(() => currentOverride = mode);
                },
              ),
            ),
          ),
        ),
      );

      // Verify header & options
      expect(find.text('FIREBASE AI ROUTER'), findsOneWidget);
      expect(find.text('Smart Auto'), findsOneWidget);
      expect(find.text('Force Edge'), findsOneWidget);
      expect(find.text('Force Cloud'), findsOneWidget);

      // Tap info affordance (Zero False Affordance rule)
      await tester.tap(find.byIcon(Icons.info_outline));
      await tester.pumpAndSettle();

      expect(find.text('Firebase AI Router Modes'), findsOneWidget);
      expect(find.textContaining('Smart Auto (Default Dynamic Policy)'), findsOneWidget);

      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      expect(find.text('Firebase AI Router Modes'), findsNothing);

      // Tap 'Force Edge'
      await tester.tap(find.text('Force Edge'));
      await tester.pumpAndSettle();
      expect(currentOverride, RouterModeOverride.enforceEdgeLocal);

      // Tap 'Force Cloud'
      await tester.tap(find.text('Force Cloud'));
      await tester.pumpAndSettle();
      expect(currentOverride, RouterModeOverride.enforceCloudFlash);

      // Tap 'Smart Auto'
      await tester.tap(find.text('Smart Auto'));
      await tester.pumpAndSettle();
      expect(currentOverride, RouterModeOverride.auto);
    });

    testWidgets('LoreCraftForesightPill: Dynamically updates badge and opens routing dossier', (tester) async {
      final router = SwitchingRouterService();
      final edge = LocalExecutionManager(gemmaService: GemmaEdgeService());
      final cloud = CloudSseClient();
      final memory = LocalMemoryService();
      final service = LoreCraftService(
        routerService: router,
        edgeManager: edge,
        cloudClient: cloud,
        memoryService: memory,
      );

      final textController = TextEditingController(text: 'Trade iron ore');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LoreCraftForesightPill(
              promptController: textController,
              loreService: service,
            ),
          ),
        ),
      );

      // Initially evaluates reactive bark on Edge
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.textContaining('On-Device Gemma 4'), findsOneWidget);

      // Change text to visual synthesis
      textController.text = 'Forge the masterwork aegis blueprint';
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.textContaining('Nano Banana 2 Lite'), findsOneWidget);

      // Change text to campaign synthesis
      textController.text = 'Synthesize the political consequences if the Shadow Syndicate seizes the lower docks from the Iron Vanguard.';
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.textContaining('Gemini 3.8 Flash'), findsOneWidget);

      // Tap the pill to open the Firebase AI Routing Dossier (Zero False Affordance rule)
      await tester.tap(find.byType(LoreCraftForesightPill));
      await tester.pumpAndSettle();

      expect(find.text('Firebase AI Routing Dossier'), findsOneWidget);
      expect(find.text('Target Execution Route'), findsOneWidget);
      expect(find.text('Triggered Policy Rule'), findsOneWidget);
      expect(find.text('Memory Destination'), findsOneWidget);
      expect(find.text('QUICK ROUTE BENCHMARK PROBES'), findsOneWidget);
      expect(find.text('Bark: Steel Billets'), findsOneWidget);
      expect(find.text('Visual: Forge Aegis'), findsOneWidget);
      expect(find.text('Escalate: Syndicate Seizure'), findsOneWidget);

      // Tap 'Bark: Steel Billets' benchmark probe
      await tester.tap(find.text('Bark: Steel Billets'));
      await tester.pumpAndSettle();

      expect(find.text('Firebase AI Routing Dossier'), findsNothing);
      expect(textController.text, 'Inspect available high-carbon steel billets');
      expect(find.textContaining('On-Device Gemma 4'), findsOneWidget);
    });

    testWidgets('LoreCraftDialogueCard: Escalated turn displays dynamic escalation badge with inspection', (tester) async {
      final escalatedTurn = LoreDialogueTurn(
        id: 'turn-escalated-1',
        speakerName: 'Elion Vane',
        isNpc: true,
        stageCue: '*[consults celestial archives]*',
        speechText: 'The High Spire records indicate an ancient treaty binding the lower docks.',
        timestamp: DateTime.now(),
        route: ExecutionRoute.CLOUD_ESCALATE,
        modelName: 'Gemini 3.8 Flash',
        ruleId: 'RULE_GAME_CAMPAIGN_SYNTHESIS',
        routeJustification: 'Cross-faction consequence simulation requires multi-hop reasoning over durable lore graph.',
        memoryDelta: '+1 durable lore anchor to High Spire archives',
        isDynamicallyEscalated: true,
        ttftMs: 240,
        latencyMs: 1150,
        egressBytes: 2450,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LoreCraftDialogueCard(turn: escalatedTurn),
          ),
        ),
      );

      expect(find.text('Elion Vane'), findsOneWidget);
      expect(find.textContaining('DYNAMIC ESCALATION'), findsOneWidget);
      expect(find.textContaining('Gemini 3.8 Flash'), findsOneWidget);

      // Tap the telemetry badge to inspect
      await tester.tap(find.textContaining('DYNAMIC ESCALATION'));
      await tester.pumpAndSettle();

      expect(find.text('Dialogue Frame Telemetry'), findsOneWidget);
      expect(find.text('Execution Route'), findsOneWidget);
      expect(find.text('CLOUD_ESCALATE'), findsOneWidget);
      expect(find.text('Firebase AI Policy'), findsOneWidget);
      expect(find.text('RULE_GAME_CAMPAIGN_SYNTHESIS'), findsOneWidget);
      expect(find.text('Escalation Reason'), findsOneWidget);
      expect(find.text('Memory Delta'), findsOneWidget);

      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      expect(find.text('Dialogue Frame Telemetry'), findsNothing);
    });
  });
}
