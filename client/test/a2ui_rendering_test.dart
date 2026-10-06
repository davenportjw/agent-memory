import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:client/models/a2ui_models.dart';
import 'package:client/models/lorecraft_state.dart';
import 'package:client/models/routing_decision.dart';
import 'package:client/services/cloud_image_client.dart';
import 'package:client/services/cloud_sse_client.dart';
import 'package:client/services/local_execution_manager.dart';
import 'package:client/services/local_memory_service.dart';
import 'package:client/services/lorecraft_service.dart';
import 'package:client/services/switching_router_service.dart';
import 'package:client/views/widgets/a2ui_surface_view.dart';
import 'package:client/views/widgets/lorecraft_dialogue_card.dart';

// Test mock for CloudImageClient
class TestCloudImageClient extends CloudImageClient {
  bool wasCalled = false;
  String? lastPrompt;

  @override
  Future<CloudImageResult> generateImage({
    required String prompt,
    List<String>? contextAnchors,
    String? aspectRatio,
    String? sessionId,
  }) async {
    wasCalled = true;
    lastPrompt = prompt;
    // 1x1 transparent PNG in base64
    const validBase64 =
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=';
    return CloudImageResult(
      imageBase64: validBase64,
      prompt: prompt,
      modelId: 'gemini-3.1-flash-lite-image',
      latencyMs: 1250,
      egressBytes: 450,
      mimeType: 'image/jpeg',
      generatedAt: DateTime.now().toIso8601String(),
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('A2UI Surface & Dialogue Card Rendering Tests', () {
    testWidgets('Renders proactive turn with local vs cloud choice tags', (tester) async {
      final surface = A2UISurface.createProactiveTurn(
        surfaceId: 'proactive-test-01',
        stageCue: '*[calibrates forge tongs]*',
        spokenLine: 'State your trade inquiry before sundown.',
        choices: const [
          A2UIChoiceItem(
            id: 'forge_aegis',
            label: "Forge Commander's Aegis",
            intent: 'visual_synthesis',
            prompt: 'Masterwork commander aegis shield concept art',
            requiresCloud: true,
          ),
          A2UIChoiceItem(
            id: 'barter_ore',
            label: 'Barter Bog Iron Ore',
            intent: 'local_dialogue',
            prompt: 'We brought raw bog iron ore.',
            requiresCloud: false,
          ),
        ],
        sliderLabel: 'Fuel Allocation',
        sliderValue: 50.0,
      );

      A2UIAction? dispatchedAction;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: A2UISurfaceView(
              surface: surface,
              onAction: (action) {
                dispatchedAction = action;
              },
            ),
          ),
        ),
      );

      // Verify choice labels rendered
      expect(find.text("Forge Commander's Aegis"), findsOneWidget);
      expect(find.text('Barter Bog Iron Ore'), findsOneWidget);

      // Verify clear visual tags: CLOUD for visual synthesis, EDGE for dialogue
      expect(find.text('CLOUD'), findsOneWidget);
      expect(find.text('EDGE'), findsOneWidget);

      // Tap cloud synthesis choice
      await tester.tap(find.text("Forge Commander's Aegis"));
      await tester.pump();

      expect(dispatchedAction, isNotNull);
      expect(dispatchedAction!.intent, 'visual_synthesis');
      expect(dispatchedAction!.parameters['choiceId'], 'forge_aegis');
      expect(dispatchedAction!.parameters['requiresCloud'], true);
    });

    testWidgets('Renders synthesized visual canvas with Nano Banana 2 Lite telemetry', (tester) async {
      const samplePng =
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=';

      final surface = A2UISurface.createVisualSynthesisSurface(
        surfaceId: 'visual-test-01',
        imageBase64: samplePng,
        prompt: 'Concept art of an ancient dwarven broadsword',
        caption: 'Forge Masterpiece',
        latencyMs: 1180,
        egressBytes: 520,
        modelAttribution: 'Nano Banana 2 Lite (gemini-3.1-flash-lite-image)',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: A2UISurfaceView(surface: surface),
            ),
          ),
        ),
      );

      // Verify prompt text rendered
      expect(find.text('Prompt: "Concept art of an ancient dwarven broadsword"'), findsOneWidget);
      expect(find.text('Forge Masterpiece'), findsWidgets);
      expect(find.textContaining('Nano Banana 2 Lite'), findsWidgets);
    });

    testWidgets('LoreCraftDialogueCard renders cloud badge with Azure styling for visual turn', (tester) async {
      final turn = LoreDialogueTurn(
        id: 'turn-visual-test',
        speakerName: 'Gideon (Cloud Nano Banana 2 Lite)',
        isNpc: true,
        stageCue: '*[materializes visual blueprint]*',
        speechText: 'Visual artifact materialized from Cloud Run.',
        timestamp: DateTime.now(),
        route: ExecutionRoute.CLOUD_ESCALATE,
        modelName: 'Nano Banana 2 Lite',
        latencyMs: 1250,
        egressBytes: 450,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LoreCraftDialogueCard(turn: turn),
          ),
        ),
      );

      expect(find.text('☁️ CLOUD ESCALATED • Nano Banana 2 Lite • 1250ms'), findsOneWidget);

      // Tap affordance to inspect frame telemetry
      await tester.tap(find.text('☁️ CLOUD ESCALATED • Nano Banana 2 Lite • 1250ms'));
      await tester.pumpAndSettle();

      expect(find.text('Dialogue Frame Telemetry'), findsOneWidget);
      expect(find.text('1250 ms'), findsOneWidget);
      expect(find.text('Cloud Visual Task (~1.2s)'), findsOneWidget);
      expect(find.text('450 bytes'), findsOneWidget);
    });
  });

  group('LoreCraftService Visual Synthesis & Routing Tests', () {
    test('triggerVisualSynthesis executes two-step pipeline: cloud image then local model turn', () async {
      final testClient = TestCloudImageClient();
      final router = SwitchingRouterService();
      final memory = LocalMemoryService();
      final edge = LocalExecutionManager();
      final cloudSse = CloudSseClient();

      final service = LoreCraftService(
        routerService: router,
        edgeManager: edge,
        cloudClient: cloudSse,
        memoryService: memory,
        cloudImageClient: testClient,
      );

      expect(service.turns.length, 1); // Seed greeting turn

      await service.triggerVisualSynthesis(
        "Masterwork fantasy steel and brass commander aegis shield",
        caption: "Forge Commander's Aegis",
      );

      expect(testClient.wasCalled, isTrue);
      // Turn count: Seed greeting turn + Step 1 Cloud visual turn + Step 2 Local model turn = 3
      expect(service.turns.length, 3);

      // Step 1: Cloud visual synthesis turn
      final visualTurn = service.turns[1];
      expect(visualTurn.route, ExecutionRoute.CLOUD_ESCALATE);
      expect(visualTurn.modelName, 'Nano Banana 2 Lite');
      expect(visualTurn.visualImageBase64, isNotNull);
      expect(visualTurn.visualImageBase64!.isNotEmpty, isTrue);
      expect(visualTurn.a2uiSurface, isNotNull);
      expect(visualTurn.speechText, "Forge Commander's Aegis");

      // Step 2: Local model on-device reaction turn
      final localTurn = service.turns.last;
      expect(localTurn.route, ExecutionRoute.EDGE_LOCAL);
      expect(localTurn.isNpc, isTrue);
      expect(localTurn.speakerName, 'Gideon Stonehand');
      expect(localTurn.speechText.isNotEmpty, isTrue);
      expect(localTurn.egressBytes, 0.0);
      expect(localTurn.a2uiSurface, isNotNull);
    });

    test('triggerVisualSynthesis with triggerLocalFollowUp: false isolates cloud step', () async {
      final testClient = TestCloudImageClient();
      final router = SwitchingRouterService();
      final memory = LocalMemoryService();
      final edge = LocalExecutionManager();
      final cloudSse = CloudSseClient();

      final service = LoreCraftService(
        routerService: router,
        edgeManager: edge,
        cloudClient: cloudSse,
        memoryService: memory,
        cloudImageClient: testClient,
      );

      expect(service.turns.length, 1);

      await service.triggerVisualSynthesis(
        "Masterwork fantasy steel and brass commander aegis shield",
        caption: "Forge Commander's Aegis",
        triggerLocalFollowUp: false,
      );

      expect(service.turns.length, 2);
      expect(service.turns.last.modelName, 'Nano Banana 2 Lite');
      expect(service.turns.last.route, ExecutionRoute.CLOUD_ESCALATE);
    });

    test('handleA2UIAction dispatches visual synthesis and advances with local follow-up turn', () async {
      final testClient = TestCloudImageClient();
      final router = SwitchingRouterService();
      final memory = LocalMemoryService();
      final edge = LocalExecutionManager();
      final cloudSse = CloudSseClient();

      final service = LoreCraftService(
        routerService: router,
        edgeManager: edge,
        cloudClient: cloudSse,
        memoryService: memory,
        cloudImageClient: testClient,
      );

      const action = A2UIAction(
        surfaceId: 'surf-01',
        componentId: 'choice-synth-01',
        actionId: 'select_choice',
        intent: 'visual_synthesis',
        parameters: {
          'prompt': 'Antique brass astrolabe concept art',
          'label': 'Synthesize Star Astrolabe',
          'requiresCloud': true,
        },
      );

      await service.handleA2UIAction(action);

      expect(testClient.wasCalled, isTrue);
      expect(testClient.lastPrompt, 'Antique brass astrolabe concept art');

      // Player action turn recorded
      final playerTurn = service.turns.firstWhere((t) => !t.isNpc);
      expect(playerTurn.speechText, 'Synthesize Star Astrolabe');

      // Step 1: Cloud visual synthesis turn exists
      final cloudTurn = service.turns.firstWhere((t) => t.modelName == 'Nano Banana 2 Lite');
      expect(cloudTurn.route, ExecutionRoute.CLOUD_ESCALATE);
      expect(cloudTurn.visualImageBase64, isNotNull);

      // Step 2: Local model next turn exists as the latest turn
      final localFollowUp = service.turns.last;
      expect(localFollowUp.route, ExecutionRoute.EDGE_LOCAL);
      expect(localFollowUp.isNpc, isTrue);
      expect(localFollowUp.speechText.isNotEmpty, isTrue);
      expect(localFollowUp.egressBytes, 0.0);
      expect(localFollowUp.a2uiSurface, isNotNull);
    });
  });

  group('Embedded A2UI Extraction & Sanitization Tests', () {
    testWidgets('LoreCraftDialogueCard extracts embedded markdown JSON choices, renders A2UISurfaceView interactively, and strips raw JSON code block', (tester) async {
      const rawTurnResponse = '''
*[lowers voice]*
```json
[
  {
    "id": "choice_edge_dialogue",
    "label": "Inquire about the dampeners' purpose",
    "description": "A cautious probe to understand the immediate tactical utility of the player's suggestion.",
    "consequence": "⚡ On-Device Gemma 4 • Conversational inquiry",
    "intent": "local_dialogue",
    "prompt": "Drop the sonic dampeners into the drainage channel. Can you clarify the precise advantage this maneuver offers against the Vanguard?",
    "requiresCloud": false
  },
  {
    "id": "choice_edge_tactical",
    "label": "Execute the dampener deployment",
    "description": "Directly implement the suggested tactical move to seal the intake.",
    "consequence": "⚡ On-Device Gemma 4 • Tactical physical action",
    "intent": "local_dialogue",
    "prompt": "Execute the dampener deployment immediately.",
    "requiresCloud": false
  },
  {
    "id": "choice_cloud_visual",
    "label": "Synthesize Undercity Sluice Blueprint",
    "description": "Render high-fidelity concept art of this tactical situation.",
    "consequence": "☁️ Cloud Nano Banana 2 Lite • 1024x1024 Concept Render",
    "intent": "visual_synthesis",
    "prompt": "Submerged aqueduct labyrinth beneath Khar-Drak",
    "requiresCloud": true
  }
]
```
''';

      final turn = LoreDialogueTurn(
        id: 'turn-lyra-edge-json',
        speakerName: 'Lyra Nightshade',
        isNpc: true,
        stageCue: '*[lowers voice]*',
        speechText: rawTurnResponse,
        timestamp: DateTime.now(),
        route: ExecutionRoute.EDGE_LOCAL,
        modelName: 'Gemma 4 int4',
        ttftMs: 1916,
        latencyMs: 1916,
        egressBytes: 0,
        a2uiSurface: null, // Initially null, exactly as reproduced in the user screenshot
      );

      A2UIAction? selectedAction;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: LoreCraftDialogueCard(
                turn: turn,
                onA2UIAction: (action) {
                  selectedAction = action;
                },
              ),
            ),
          ),
        ),
      );

      // 1. Verify A2UISurfaceView is dynamically hydrated and rendered
      expect(find.byType(A2UISurfaceView), findsOneWidget);

      // 2. Verify interactive choice labels are present
      expect(find.text("Inquire about the dampeners' purpose"), findsOneWidget);
      expect(find.text("Execute the dampener deployment"), findsOneWidget);
      expect(find.text("Synthesize Undercity Sluice Blueprint"), findsOneWidget);

      // 3. Verify EDGE vs CLOUD affordance tags
      expect(find.text('EDGE'), findsNWidgets(2));
      expect(find.text('CLOUD'), findsOneWidget);

      // 4. Verify stage cue is rendered properly
      expect(find.text('*[lowers voice]*'), findsOneWidget);

      // 5. CRITICAL: Verify that the raw JSON code block was stripped and is NOT displayed as raw body text
      expect(find.textContaining('```json'), findsNothing);
      expect(find.textContaining('"choice_edge_dialogue"'), findsNothing);
      expect(find.textContaining('requiresCloud'), findsNothing);

      // 6. Test interaction: tap the tactical action card
      await tester.tap(find.text("Inquire about the dampeners' purpose"));
      await tester.pump();

      expect(selectedAction, isNotNull);
      expect(selectedAction!.intent, 'local_dialogue');
      expect(selectedAction!.parameters['choiceId'], 'choice_edge_dialogue');
      expect(selectedAction!.parameters['requiresCloud'], false);
    });

    testWidgets('LoreCraftDialogueCard extracts full declarative A2UISurface JSON from speechText', (tester) async {
      const fullSurfaceJson = '''
Careful around the conduits.
```json
{
  "surfaceId": "surface-conduit-01",
  "rootComponentId": "root_card",
  "components": [
    {
      "id": "root_card",
      "type": "Card",
      "properties": { "variant": "edge_accent" },
      "children": ["badge_obj", "choice_grp"]
    },
    {
      "id": "badge_obj",
      "type": "Badge",
      "properties": { "label": "UNDERCITY POWER GRID", "variant": "sage" }
    },
    {
      "id": "choice_grp",
      "type": "ChoiceGroup",
      "properties": {
        "title": "TACTICAL ACTIONS",
        "choices": [
          {
            "id": "pylon_act",
            "label": "Reroute Pylon Coupling",
            "intent": "local_dialogue",
            "prompt": "Reroute the coupling now.",
            "requiresCloud": false
          }
        ]
      }
    }
  ]
}
```
''';

      final turn = LoreDialogueTurn(
        id: 'turn-surface-full',
        speakerName: 'Gideon Stonehand',
        isNpc: true,
        stageCue: '*[tightens gauntlet]*',
        speechText: fullSurfaceJson,
        timestamp: DateTime.now(),
        route: ExecutionRoute.EDGE_LOCAL,
        modelName: 'Gemma 4 int4',
        a2uiSurface: null,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: LoreCraftDialogueCard(turn: turn),
            ),
          ),
        ),
      );

      expect(find.byType(A2UISurfaceView), findsOneWidget);
      expect(find.text('UNDERCITY POWER GRID'), findsOneWidget);
      expect(find.text('Reroute Pylon Coupling'), findsOneWidget);
      expect(find.text('Careful around the conduits.'), findsOneWidget);
      expect(find.textContaining('```json'), findsNothing);
    });

    testWidgets('LoreCraftDialogueCard respects hideTextIfGenerativeUi flag', (tester) async {
      final surfaceWithSpeech = A2UISurface.createProactiveTurn(
        surfaceId: 'surf-hide-test',
        stageCue: '*[studies parchment]*',
        spokenLine: 'Redundant spoken line inside surface.',
        choices: const [
          A2UIChoiceItem(id: 'c1', label: 'Action A', intent: 'local_dialogue', requiresCloud: false),
        ],
      );

      final turn = LoreDialogueTurn(
        id: 'turn-hide-test',
        speakerName: 'Lyra',
        isNpc: true,
        stageCue: '*[studies parchment]*',
        speechText: 'Redundant spoken line inside surface.',
        timestamp: DateTime.now(),
        route: ExecutionRoute.EDGE_LOCAL,
        modelName: 'Gemma 4 int4',
        a2uiSurface: surfaceWithSpeech,
      );

      // When hideTextIfGenerativeUi is true (default)
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: LoreCraftDialogueCard(
                turn: turn,
                hideTextIfGenerativeUi: true,
              ),
            ),
          ),
        ),
      );

      // The spoken line is inside the A2UISurfaceView card, not duplicated outside
      expect(find.text('Redundant spoken line inside surface.'), findsOneWidget);

      // When hideTextIfGenerativeUi is false
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: LoreCraftDialogueCard(
                turn: turn,
                hideTextIfGenerativeUi: false,
              ),
            ),
          ),
        ),
      );

      // Visible both inside A2UISurfaceView and outer bubble
      expect(find.text('Redundant spoken line inside surface.'), findsNWidgets(2));
    });
  });
}
