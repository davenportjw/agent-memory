import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:client/services/app_mode_service.dart';
import 'package:client/services/local_memory_service.dart';
import 'package:client/services/lorecraft_service.dart';
import 'package:client/services/switching_router_service.dart';
import 'package:client/services/local_execution_manager.dart';
import 'package:client/services/cloud_sse_client.dart';
import 'package:client/views/lorecraft_boot_page_view.dart';
import 'package:client/views/widgets/education_assessment_card.dart';

void main() {
  group('LoreCraftBootPageView Simple vs Everything Mode Tests', () {
    late AppModeService modeService;
    late LocalMemoryService memoryService;
    late LoreCraftService loreService;

    setUp(() {
      modeService = AppModeService();
      memoryService = LocalMemoryService();
      final routerService = SwitchingRouterService();
      final edgeManager = LocalExecutionManager();
      final cloudClient = CloudSseClient();

      loreService = LoreCraftService(
        routerService: routerService,
        edgeManager: edgeManager,
        cloudClient: cloudClient,
        memoryService: memoryService,
      );
    });

    testWidgets('Simple mode hides EducationAssessmentCard and toggle button', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      modeService.setMode(AppDisplayMode.simple);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LoreCraftBootPageView(
              loreService: loreService,
              memoryService: memoryService,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(EducationAssessmentCard), findsNothing);
      expect(find.byKey(const Key('btn_toggle_efficacy_rater')), findsNothing);
    });

    testWidgets('Everything mode hides EducationAssessmentCard by default and reveals on toggle tap', (tester) async {
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
            body: LoreCraftBootPageView(
              loreService: loreService,
              memoryService: memoryService,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Hidden by default in boot prompt
      expect(find.byType(EducationAssessmentCard), findsNothing);
      final toggleFinder = find.byKey(const Key('btn_toggle_efficacy_rater'));
      expect(toggleFinder, findsOneWidget);
      expect(find.text('SHOW EFFICACY RATER'), findsOneWidget);

      // Tap to reveal
      await tester.ensureVisible(toggleFinder);
      await tester.tap(toggleFinder);
      await tester.pumpAndSettle();

      expect(find.byType(EducationAssessmentCard), findsOneWidget);
      expect(find.text('HIDE EFFICACY RATER'), findsOneWidget);

      // Tap to re-hide
      await tester.ensureVisible(toggleFinder);
      await tester.tap(toggleFinder);
      await tester.pumpAndSettle();

      expect(find.byType(EducationAssessmentCard), findsNothing);
      expect(find.text('SHOW EFFICACY RATER'), findsOneWidget);
    });
  });
}
