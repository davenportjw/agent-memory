import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:client/views/shell_layout.dart';
import 'package:client/services/app_mode_service.dart';

void main() {
  group('ShellNav Simple vs Everything Mode Suite (TDD)', () {
    setUp(() {
      AppModeService().setMode(AppDisplayMode.simple);
    });

    testWidgets('In Simple mode, nav rail only shows core showcase items', (tester) async {
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

      // Mode slider should be present in header
      expect(find.byKey(const Key('btn_mode_simple')), findsOneWidget);
      expect(find.byKey(const Key('btn_mode_everything')), findsOneWidget);

      // Core showcase items must be present
      expect(find.text('LoreCraft Studio'), findsWidgets);
      expect(find.text('Edge Agent Boot'), findsWidgets);

      // Developer diagnostic views must NOT be in the navigation rail
      expect(find.text('Architecture Notebook'), findsNothing);
      expect(find.text('Memory Studio'), findsNothing);
      expect(find.text('Model Test Bench'), findsNothing);
      expect(find.text('Switching Policy'), findsNothing);
      expect(find.text('Feature Synthesizer'), findsNothing);
      expect(find.text('Assistant Workspace'), findsNothing);
    });

    testWidgets('Switching to Everything mode unlocks all 8 developer destinations', (tester) async {
      tester.view.physicalSize = const Size(1440, 1200);
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

      // Tap Everything Mode
      await tester.tap(find.byKey(const Key('btn_mode_everything')));
      await tester.pumpAndSettle();

      // All 8 destinations should now be visible in the nav rail
      expect(find.text('LoreCraft Studio'), findsWidgets);
      expect(find.text('Edge Agent Boot'), findsWidgets);
      expect(find.text('Architecture Notebook'), findsOneWidget);
      expect(find.text('Memory Studio'), findsOneWidget);
      expect(find.text('Model Test Bench'), findsOneWidget);
      expect(find.text('Switching Policy'), findsOneWidget);
      expect(find.text('Feature Synthesizer'), findsOneWidget);
      expect(find.text('Assistant Workspace'), findsOneWidget);

      // Switching back to Simple mode hides developer views again
      await tester.tap(find.byKey(const Key('btn_mode_simple')));
      await tester.pumpAndSettle();

      expect(find.text('Architecture Notebook'), findsNothing);
      expect(find.text('Memory Studio'), findsNothing);
      expect(find.text('Model Test Bench'), findsNothing);
      expect(find.text('Switching Policy'), findsNothing);
      expect(find.text('Feature Synthesizer'), findsNothing);
      expect(find.text('Assistant Workspace'), findsNothing);
    });
  });
}
