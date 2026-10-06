import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:client/models/lorecraft_state.dart';
import 'package:client/models/routing_decision.dart';
import 'package:client/services/app_mode_service.dart';
import 'package:client/views/widgets/lorecraft_dialogue_card.dart';

void main() {
  group('LoreCraftDialogueCard Telemetry Modal Simple vs Everything Mode Tests', () {
    late AppModeService modeService;

    final dummyTurn = LoreDialogueTurn(
      id: 'turn_1',
      speakerName: 'Gideon',
      isNpc: true,
      stageCue: 'inspects clock gears',
      speechText: 'The brass escapement is intact.',
      route: ExecutionRoute.EDGE_LOCAL,
      modelName: 'Gemma 4 int4 (WebGPU)',
      latencyMs: 42,
      ttftMs: 28,
      egressBytes: 0,
      timestamp: DateTime.now(),
      memoryDelta: 'Updated foundry clock gear status',
      routeJustification: 'Local NPC banter with zero egress required',
    );

    setUp(() {
      modeService = AppModeService();
    });

    testWidgets('Simple mode shows 3-pillar focused telemetry dialog', (tester) async {
      modeService.setMode(AppDisplayMode.simple);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LoreCraftDialogueCard(turn: dummyTurn),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap on the telemetry badge
      final badgeFinder = find.textContaining('LOCAL EDGE');
      expect(badgeFinder, findsOneWidget);
      await tester.tap(badgeFinder);
      await tester.pumpAndSettle();

      // Simple mode shows 3-pillar header and focused metrics
      expect(find.text('⚡ Edge vs Cloud Telemetry'), findsOneWidget);
      expect(find.text('AI Execution Route'), findsOneWidget);
      expect(find.text('Speed (TTFT / Latency)'), findsOneWidget);
      expect(find.text('Cloud Network Egress'), findsOneWidget);
      expect(find.text('0.0 KB (Zero egress, 100% private)'), findsOneWidget);

      // Simple mode hides raw engineering rubric
      expect(find.text('Frame Budget Status'), findsNothing);
    });

    testWidgets('Everything mode shows full engineering telemetry dialog', (tester) async {
      modeService.setMode(AppDisplayMode.everything);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LoreCraftDialogueCard(turn: dummyTurn),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap on the telemetry badge
      final badgeFinder = find.textContaining('LOCAL EDGE');
      expect(badgeFinder, findsOneWidget);
      await tester.tap(badgeFinder);
      await tester.pumpAndSettle();

      // Everything mode shows full diagnostic header and rubric
      expect(find.text('Dialogue Frame Telemetry'), findsOneWidget);
      expect(find.text('Frame Budget Status'), findsOneWidget);
      expect(find.text('Time to First Token (TTFT)'), findsOneWidget);
    });
  });
}
