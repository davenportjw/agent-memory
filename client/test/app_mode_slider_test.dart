import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:client/services/app_mode_service.dart';
import 'package:client/views/widgets/app_mode_slider.dart';

void main() {
  group('AppModeService & AppModeSlider TDD Tests', () {
    late AppModeService modeService;

    setUp(() {
      modeService = AppModeService();
    });

    test('AppModeService initial state is simple mode', () {
      expect(modeService.mode, equals(AppDisplayMode.simple));
      expect(modeService.isSimple, isTrue);
      expect(modeService.isEverything, isFalse);
    });

    test('AppModeService notifies listeners on mode transition', () {
      int notifications = 0;
      modeService.addListener(() => notifications++);

      modeService.setMode(AppDisplayMode.everything);
      expect(modeService.mode, equals(AppDisplayMode.everything));
      expect(modeService.isSimple, isFalse);
      expect(modeService.isEverything, isTrue);
      expect(notifications, equals(1));

      // Same mode should not trigger redundant notification
      modeService.setMode(AppDisplayMode.everything);
      expect(notifications, equals(1));

      modeService.toggleMode();
      expect(modeService.mode, equals(AppDisplayMode.simple));
      expect(notifications, equals(2));
    });

    testWidgets('AppModeSlider renders both mode options with clear visual indicators', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppModeSlider(modeService: modeService),
          ),
        ),
      );

      expect(find.byKey(const Key('btn_mode_simple')), findsOneWidget);
      expect(find.byKey(const Key('btn_mode_everything')), findsOneWidget);
      expect(find.textContaining('Simple'), findsOneWidget);
      expect(find.textContaining('Everything'), findsOneWidget);
    });

    testWidgets('Tapping Everything switches AppModeService to everything mode', (tester) async {
      AppDisplayMode? reportedMode;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppModeSlider(
              modeService: modeService,
              onModeChanged: (newMode) => reportedMode = newMode,
            ),
          ),
        ),
      );

      expect(modeService.isSimple, isTrue);

      await tester.tap(find.byKey(const Key('btn_mode_everything')));
      await tester.pumpAndSettle();

      expect(modeService.isEverything, isTrue);
      expect(reportedMode, equals(AppDisplayMode.everything));
    });

    testWidgets('Tapping Simple switches AppModeService back to simple mode', (tester) async {
      modeService.setMode(AppDisplayMode.everything);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppModeSlider(modeService: modeService),
          ),
        ),
      );

      expect(modeService.isEverything, isTrue);

      await tester.tap(find.byKey(const Key('btn_mode_simple')));
      await tester.pumpAndSettle();

      expect(modeService.isSimple, isTrue);
    });
  });
}
