import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:client/views/shell_layout.dart';
import 'package:client/views/lorecraft_studio.dart';
import 'package:client/services/lorecraft_service.dart';
import 'package:client/services/switching_router_service.dart';
import 'package:client/services/gemma_edge_service.dart';
import 'package:client/services/local_execution_manager.dart';
import 'package:client/services/cloud_sse_client.dart';
import 'package:client/services/local_memory_service.dart';

void main() {
  group('Collapsible Navigation Suite (TDD)', () {
    testWidgets('ShellLayout: Left navigation rail collapses to compact mode and expands back', (tester) async {
      // Set a larger desktop screen size to prevent mobile Drawer behavior
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: ShellLayout(),
        ),
      );
      await tester.pumpAndSettle();

      // Initially, Left Nav Rail is expanded
      expect(find.text('ANTIGRAVITY'), findsOneWidget);
      expect(find.text('DISTRIBUTED AI // CLIENT'), findsOneWidget);
      expect(find.text('LoreCraft Studio'), findsWidgets);
      expect(find.byKey(const Key('btn_collapse_shell_nav_rail')), findsOneWidget);

      // Tap collapse button
      await tester.tap(find.byKey(const Key('btn_collapse_shell_nav_rail')));
      await tester.pumpAndSettle();

      // Rail is now in compact mode: text is hidden, expand button is shown
      expect(find.text('ANTIGRAVITY'), findsNothing);
      expect(find.byKey(const Key('btn_expand_shell_nav_rail')), findsOneWidget);

      // Tap expand button to restore rail
      await tester.tap(find.byKey(const Key('btn_expand_shell_nav_rail')));
      await tester.pumpAndSettle();

      expect(find.text('ANTIGRAVITY'), findsOneWidget);
      expect(find.byKey(const Key('btn_collapse_shell_nav_rail')), findsOneWidget);
    });

    testWidgets('LoreCraftStudio: Left panel collapses and expands via header buttons', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

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
      service.completeBootState();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LoreCraftStudio(loreService: service),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Initially, LoreCraft left panel is open
      expect(find.text('LORECRAFT ENGINE'), findsOneWidget);
      expect(find.text('CURRENT REGION'), findsOneWidget);
      expect(find.byKey(const Key('btn_collapse_lorecraft_left_panel')), findsOneWidget);

      // Tap collapse button in LoreCraft left panel
      await tester.tap(find.byKey(const Key('btn_collapse_lorecraft_left_panel')));
      await tester.pumpAndSettle();

      // Left panel is collapsed
      expect(find.text('LORECRAFT ENGINE'), findsNothing);
      expect(find.byKey(const Key('btn_toggle_lorecraft_left_panel')), findsWidgets);

      // Tap toggle button in the center top bar to reopen left panel
      await tester.tap(find.byKey(const Key('btn_toggle_lorecraft_left_panel')).first);
      await tester.pumpAndSettle();

      // Left panel is restored
      expect(find.text('LORECRAFT ENGINE'), findsOneWidget);
      expect(find.text('CURRENT REGION'), findsOneWidget);
    });

    testWidgets('LoreCraftStudio: Left panel sections are individually collapsible', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

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
      service.completeBootState();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LoreCraftStudio(loreService: service),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check Region section collapse
      expect(find.text(service.activeRegion.atmosphere), findsOneWidget);
      await tester.tap(find.byKey(const Key('header_section_region')));
      await tester.pumpAndSettle();
      expect(find.text(service.activeRegion.atmosphere), findsNothing);

      // Re-expand Region section
      await tester.tap(find.byKey(const Key('header_section_region')));
      await tester.pumpAndSettle();
      expect(find.text(service.activeRegion.atmosphere), findsOneWidget);

      // Check NPC section collapse
      expect(find.text('Gideon Stonehand'), findsWidgets);
      await tester.tap(find.byKey(const Key('header_section_npcs')));
      await tester.pumpAndSettle();
      // Gideon is inside dialogue stream header too, but roster item is collapsed
      expect(find.byKey(const Key('npc_roster_list')), findsNothing);

      // Re-expand NPC section
      await tester.tap(find.byKey(const Key('header_section_npcs')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('npc_roster_list')), findsOneWidget);
    });
  });
}
