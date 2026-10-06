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

    testWidgets('Simple mode hides EducationAssessmentCard', (tester) async {
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
    });

    testWidgets('Everything mode displays EducationAssessmentCard', (tester) async {
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

      expect(find.byType(EducationAssessmentCard), findsOneWidget);
    });
  });
}
