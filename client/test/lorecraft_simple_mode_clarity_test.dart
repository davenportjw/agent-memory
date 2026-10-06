import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:client/views/lorecraft_studio.dart';
import 'package:client/views/widgets/lorecraft_canon_arbiter_card.dart';
import 'package:client/services/app_mode_service.dart';
import 'package:client/services/lorecraft_service.dart';
import 'package:client/services/switching_router_service.dart';
import 'package:client/services/gemma_edge_service.dart';
import 'package:client/services/local_execution_manager.dart';
import 'package:client/services/cloud_sse_client.dart';
import 'package:client/services/local_memory_service.dart';

void main() {
  group('LoreCraft Studio Clarity & Simple Mode Suite (TDD)', () {
    late AppModeService modeService;
    late SwitchingRouterService routerService;
    late GemmaEdgeService gemmaService;
    late LocalExecutionManager edgeManager;
    late CloudSseClient cloudClient;
    late LocalMemoryService memoryService;
    late LoreCraftService loreService;

    setUp(() {
      modeService = AppModeService();
      modeService.setMode(AppDisplayMode.simple);

      routerService = SwitchingRouterService();
      gemmaService = GemmaEdgeService();
      edgeManager = LocalExecutionManager(gemmaService: gemmaService);
      cloudClient = CloudSseClient();
      memoryService = LocalMemoryService();
      loreService = LoreCraftService(
        routerService: routerService,
        edgeManager: edgeManager,
        cloudClient: cloudClient,
        memoryService: memoryService,
      );
      loreService.completeBootState();
      loreService.acceptMission('gideon');
    });

    testWidgets('Simple mode hides dev buttons, cheat steppers, and rater rubrics', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LoreCraftStudio(
              loreService: loreService,
              isRightDrawerOpen: true,
              onNavigateToDestination: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Top bar: Dev knobs must be hidden
      expect(find.byKey(const Key('btn_revisit_boot_sequence')), findsNothing);
      expect(find.byKey(const Key('btn_open_game_memory_dev_tool')), findsNothing);
      expect(find.byKey(const Key('btn_toggle_genui_verbosity')), findsNothing);

      // Top bar: Core quest dossier must remain
      expect(find.byKey(const Key('btn_mission_dossier')), findsOneWidget);

      // Faction panel: Cheat steppers (-10/+10) must be hidden
      expect(find.byKey(const Key('btn_faction_sub_vanguard')), findsNothing);
      expect(find.byKey(const Key('btn_faction_add_vanguard')), findsNothing);

      // Left panel: Inspect in Memory Studio button must be hidden
      expect(find.byKey(const Key('btn_drawer_open_memory_studio')), findsNothing);

      // Right drawer: Canon & Arbiter scorecard must be hidden
      expect(find.byType(LoreCraftCanonArbiterCard), findsNothing);
    });

    testWidgets('Everything mode reveals dev buttons, cheat steppers, and rater rubrics', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      modeService.setMode(AppDisplayMode.everything);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LoreCraftStudio(
              loreService: loreService,
              isRightDrawerOpen: true,
              onNavigateToDestination: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Top bar: Dev knobs should now be visible
      expect(find.byKey(const Key('btn_revisit_boot_sequence')), findsOneWidget);
      expect(find.byKey(const Key('btn_open_game_memory_dev_tool')), findsOneWidget);
      expect(find.byKey(const Key('btn_toggle_genui_verbosity')), findsOneWidget);

      // Faction panel: Cheat steppers should be visible
      expect(find.byKey(const Key('btn_faction_sub_vanguard')), findsOneWidget);
      expect(find.byKey(const Key('btn_faction_add_vanguard')), findsOneWidget);

      // Left panel: Inspect in Memory Studio button should be visible
      expect(find.byKey(const Key('btn_drawer_open_memory_studio')), findsOneWidget);

      // Right drawer: Canon & Arbiter scorecard should be visible
      expect(find.byType(LoreCraftCanonArbiterCard), findsOneWidget);
    });
  });
}
