import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../lib/models/objective_milestone.dart';
import '../lib/services/lorecraft_service.dart';
import '../lib/services/switching_router_service.dart';
import '../lib/services/gemma_edge_service.dart';
import '../lib/services/local_execution_manager.dart';
import '../lib/services/cloud_sse_client.dart';
import '../lib/services/local_memory_service.dart';
import '../lib/views/widgets/objective_milestone_toast.dart';

void main() {
  group('ObjectiveMilestoneToast Widget Tests', () {
    testWidgets('Renders milestone toast with title, faction pill, and memory citation', (tester) async {
      bool dismissed = false;
      final milestone = ObjectiveMilestoneEvent(
        id: 'ms_test_cipher',
        title: 'Aqueduct Valve Ciphers Secured',
        description: 'Calibrated hydraulic telemetry for Undercity Sluice Gate 4.',
        faction: 'Undercity Syndicate',
        repDelta: '+4 REP',
        timestamp: DateTime.now(),
        memorySource: 'undercity_sluice_bypass (Topic Index)',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ObjectiveMilestoneToast(
              event: milestone,
              onDismiss: () => dismissed = true,
              autoDismissDuration: const Duration(seconds: 10),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('OBJECTIVE MILESTONE REACHED'), findsOneWidget);
      expect(find.text('Aqueduct Valve Ciphers Secured'), findsOneWidget);
      expect(find.textContaining('Undercity Sluice Gate 4'), findsOneWidget);
      expect(find.textContaining('UNDERCITY SYNDICATE (+4 REP)'), findsOneWidget);
      expect(find.textContaining('undercity_sluice_bypass (Topic Index)'), findsOneWidget);

      final dismissButton = find.byKey(const Key('btn_dismiss_milestone_toast'));
      expect(dismissButton, findsOneWidget);
      await tester.tap(dismissButton);
      await tester.pumpAndSettle();

      expect(dismissed, isTrue);
    });

    test('LoreCraftService triggers and dismisses milestone accurately', () {
      final router = SwitchingRouterService();
      final edge = LocalExecutionManager(gemmaService: GemmaEdgeService());
      final cloud = CloudSseClient();
      final memory = LocalMemoryService();
      final loreService = LoreCraftService(
        routerService: router,
        edgeManager: edge,
        cloudClient: cloud,
        memoryService: memory,
      );

      expect(loreService.activeMilestone, isNull);

      final event = ObjectiveMilestoneEvent(
        id: 'ms_keystone',
        title: 'Keystone Spire Leyline Attuned',
        description: 'Attuned resonance array at 432 Hz.',
        faction: 'Sovereign Enclave',
        repDelta: '+4 REP',
        timestamp: DateTime.now(),
        memorySource: 'keystone_spire_harmonics (Topic Index)',
      );

      loreService.triggerMilestone(event);
      expect(loreService.activeMilestone, isNotNull);
      expect(loreService.activeMilestone!.title, equals('Keystone Spire Leyline Attuned'));

      loreService.dismissMilestone();
      expect(loreService.activeMilestone, isNull);
    });
  });
}
