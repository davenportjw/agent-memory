import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:client/services/switching_router_service.dart';
import 'package:client/services/local_execution_manager.dart';
import 'package:client/views/center_workspace.dart';
import 'package:client/views/widgets/gemma_load_pill.dart';

void main() {
  group('Assistant Workspace Top Header Responsive & Overlap Prevention Suite', () {
    late LocalExecutionManager manager;

    setUp(() async {
      manager = LocalExecutionManager();
      await manager.init();
    });

    Widget createTestableWorkspace({
      required double width,
      required double height,
      RouterModeOverride override = RouterModeOverride.auto,
    }) {
      return MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: width,
              height: height,
              child: CenterWorkspace(
                messages: const [],
                isGenerating: false,
                currentOverride: override,
                onOverrideChanged: (_) {},
                onSendMessage: (_) async {},
                selectedPill: null,
                onPillSelected: (_) {},
                onToggleDrawer: () {},
                isDrawerOpen: false,
                onClearChat: () {},
                edgeManager: manager,
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('renders full title and full pills when workspace is wide (1200px)', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createTestableWorkspace(width: 1200, height: 800));
      await tester.pumpAndSettle();

      // Full title should be visible
      expect(find.text('ASSISTANT SHELL // DUAL EDGE-CLOUD WORKSPACE'), findsOneWidget);
      expect(find.text('DEV TOOL'), findsOneWidget);

      // Full routing pill and Gemma pill labels
      expect(find.byType(GemmaLoadPill), findsOneWidget);
      expect(find.text('Load Gemma 4 2B (~1.46 GB)'), findsOneWidget);
      expect(find.textContaining('Auto'), findsOneWidget);

      // Verify no overflow errors
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders compact pills without overlapping when workspace is 640px (e.g. drawer open)', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      // 640px simulates CenterWorkspace width with 240px nav rail + 320px drawer open
      await tester.pumpWidget(createTestableWorkspace(width: 640, height: 800));
      await tester.pumpAndSettle();

      // Compact title should adapt
      expect(find.text('ASSISTANT SHELL'), findsOneWidget);

      // Compact Gemma pill and routing pill
      expect(find.byType(GemmaLoadPill), findsOneWidget);
      expect(find.text('Load Gemma 4'), findsOneWidget);
      expect(find.text('Auto'), findsOneWidget);

      // Clear chat and inspector icons must be present and interactable
      expect(find.byIcon(Icons.delete_outline_rounded), findsOneWidget);
      expect(find.byIcon(Icons.view_sidebar_outlined), findsOneWidget);

      // Verify no overflow errors
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders ultra-compact layout gracefully at 480px without overflow', (tester) async {
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createTestableWorkspace(width: 480, height: 600));
      await tester.pumpAndSettle();

      // Ultra-compact title
      expect(find.text('ASSISTANT'), findsOneWidget);

      // Action pills fit within space
      expect(find.byType(GemmaLoadPill), findsOneWidget);
      expect(find.text('Load Gemma 4'), findsOneWidget);
      expect(find.text('Auto'), findsOneWidget);

      // Verify no overflow errors
      expect(tester.takeException(), isNull);
    });

    testWidgets('routing pill displays correct compact label for cloud and offline overrides', (tester) async {
      tester.view.physicalSize = const Size(1000, 700);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      // Test Cloud override in 640px workspace
      await tester.pumpWidget(createTestableWorkspace(
        width: 640,
        height: 700,
        override: RouterModeOverride.enforceCloudFlash,
      ));
      await tester.pumpAndSettle();
      expect(find.text('Cloud'), findsOneWidget);

      // Test Offline override in 640px workspace
      await tester.pumpWidget(createTestableWorkspace(
        width: 640,
        height: 700,
        override: RouterModeOverride.simulateOffline,
      ));
      await tester.pumpAndSettle();
      expect(find.text('Offline'), findsOneWidget);
    });
  });
}
