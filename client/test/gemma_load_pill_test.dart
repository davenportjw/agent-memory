import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:client/services/local_execution_manager.dart';
import 'package:client/views/widgets/gemma_load_pill.dart';

void main() {
  group('GemmaLoadPill Affordance & Load/Unload TDD Suite', () {
    late LocalExecutionManager manager;

    setUp(() async {
      manager = LocalExecutionManager();
      await manager.init();
    });

    testWidgets('renders unloaded state with plain English label and tooltip', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: GemmaLoadPill(edgeManager: manager),
            ),
          ),
        ),
      );

      // Verify human-readable unloaded label
      expect(find.text('Load Gemma 4 2B (~1.46 GB)'), findsOneWidget);
      expect(find.byIcon(Icons.bolt_outlined), findsOneWidget);

      // Verify tooltip presence
      expect(find.byType(Tooltip), findsOneWidget);
      final tooltip = tester.widget<Tooltip>(find.byType(Tooltip));
      expect(tooltip.message, contains('Tap to load Gemma 4 2B on-device'));
    });

    testWidgets('transitions to loaded state with checkmark and chevron affordance', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: GemmaLoadPill(edgeManager: manager),
            ),
          ),
        ),
      );

      // Simulate model loaded
      manager.setGemmaLoaded(true);
      await tester.pumpAndSettle();

      // Verify loaded label
      expect(find.text('Gemma 4 2B Ready (0 KB Egress)'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
      expect(find.byIcon(Icons.expand_more), findsOneWidget);

      final tooltip = tester.widget<Tooltip>(find.byType(Tooltip));
      expect(tooltip.message, contains('Tap to inspect runtime or unload weights'));
    });

    testWidgets('tapping loaded pill opens inspection modal with Three Context Questions', (tester) async {
      manager.setGemmaLoaded(true);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: GemmaLoadPill(edgeManager: manager),
            ),
          ),
        ),
      );

      // Tap loaded pill
      await tester.tap(find.text('Gemma 4 2B Ready (0 KB Egress)'));
      await tester.pumpAndSettle();

      // Verify inspection dialog appeared
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Gemma 4 2B Runtime Active'), findsOneWidget);

      // Verify Three Context Questions
      expect(find.text('What is active?'), findsOneWidget);
      expect(find.text('Why is it loaded?'), findsOneWidget);
      expect(find.text('What can you do next?'), findsOneWidget);
      expect(find.textContaining('Resident Memory: ~1240.5 MB RAM allocated'), findsOneWidget);

      // Verify action buttons
      expect(find.text('Keep Active'), findsOneWidget);
      expect(find.text('Unload Model (Free RAM)'), findsOneWidget);

      // Tap Keep Active to dismiss without unloading
      await tester.tap(find.text('Keep Active'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(manager.isGemmaWeightsLoaded, isTrue);
      expect(find.text('Gemma 4 2B Ready (0 KB Egress)'), findsOneWidget);
    });

    testWidgets('tapping Unload Model in dialog unloads weights and restores unloaded pill', (tester) async {
      manager.setGemmaLoaded(true);
      bool unloadedCallbackFired = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: GemmaLoadPill(
                edgeManager: manager,
                onModelUnloaded: () {
                  unloadedCallbackFired = true;
                },
              ),
            ),
          ),
        ),
      );

      // Tap loaded pill to open dialog
      await tester.tap(find.text('Gemma 4 2B Ready (0 KB Egress)'));
      await tester.pumpAndSettle();

      // Tap Unload Model (Free RAM)
      await tester.tap(find.text('Unload Model (Free RAM)'));
      await tester.pumpAndSettle();

      // Verify dialog dismissed
      expect(find.byType(AlertDialog), findsNothing);

      // Verify manager state updated
      expect(manager.isGemmaWeightsLoaded, isFalse);
      expect(unloadedCallbackFired, isTrue);

      // Verify pill transitions back to unloaded label
      expect(find.text('Load Gemma 4 2B (~1.46 GB)'), findsOneWidget);
      expect(find.byIcon(Icons.bolt_outlined), findsOneWidget);

      // Verify SnackBar notification
      expect(find.textContaining('Gemma 4 2B weights unloaded'), findsOneWidget);
    });

    testWidgets('renders compact labels when isCompact is true', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: GemmaLoadPill(edgeManager: manager, isCompact: true),
            ),
          ),
        ),
      );

      // Unloaded compact label
      expect(find.text('Load Gemma 4'), findsOneWidget);

      // Transition to loaded compact state
      manager.setGemmaLoaded(true);
      await tester.pumpAndSettle();

      expect(find.text('Gemma 4 Ready'), findsOneWidget);
    });
  });
}
