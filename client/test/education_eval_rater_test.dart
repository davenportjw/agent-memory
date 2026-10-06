import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:client/models/education_eval_rater.dart';
import 'package:client/services/local_memory_service.dart';
import 'package:client/views/widgets/education_assessment_card.dart';

void main() {
  group('EducationEvalRater Model & Pedagogical Rubric Tests', () {
    const rater = EducationEvalRater();

    test('Evaluates boot state within budget as Exceptional (A+ tier)', () {
      final memoryService = LocalMemoryService();
      final bootState = memoryService.bootState;

      final report = rater.evaluate(
        bootState: bootState,
        isToolFetchTested: true,
        isTaskEvictionTested: true,
        isPrefetchTested: true,
        isDreamSyncTested: true,
      );

      expect(report.overallScore, greaterThanOrEqualTo(95.0));
      expect(report.letterGrade, 'A+');
      expect(report.tier, EducationGradeTier.exceptional);
      expect(report.executiveSummary, contains('exceptional educational walkthrough'));

      // Check all 4 component results are present
      expect(report.componentResults.length, 4);
      expect(report.componentResults[0].id, 'boot_state_minimum_context');
      expect(report.componentResults[0].statusLabel, 'MASTERED');
      expect(report.componentResults[1].id, 'jit_context_paging');
      expect(report.componentResults[2].id, 'predictive_prefetching');
      expect(report.componentResults[3].id, 'cloud_dream_sync');

      // Check digestible takeaways
      expect(report.playerGraspedTakeaways.length, 4);
      expect(report.playerGraspedTakeaways[0], contains('The Map is Not the Territory'));
      expect(report.playerGraspedTakeaways[1], contains('Task-Bound Context Windows'));
      expect(report.playerGraspedTakeaways[2], contains('Predictive Edge Caching'));
      expect(report.playerGraspedTakeaways[3], contains('Overnight Cloud Consolidation'));
    });

    test('Serializes to JSON accurately for automated reporting', () {
      final memoryService = LocalMemoryService();
      final bootState = memoryService.bootState;
      final report = rater.evaluate(bootState: bootState);

      final json = report.toJson();
      expect(json['letter_grade'], report.letterGrade);
      expect(json['overall_score'], report.overallScore);
      expect(json['tier'], report.tier.name);
      expect(json['component_results'], isA<List>());
      expect((json['component_results'] as List).length, 4);
      expect(json['player_grasped_takeaways'], isA<List>());
    });
  });

  group('EducationAssessmentCard Widget Tests', () {
    testWidgets('Renders easy-to-digest scorecard, grade badge, meters, and takeaways', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final memoryService = LocalMemoryService();
      memoryService.bootEdgeAgent();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: EducationAssessmentCard(memoryService: memoryService),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Header & Grade
      expect(find.text('EDUCATIONAL EFFICACY RATER'), findsOneWidget);
      expect(find.textContaining('GRADE: B'), findsOneWidget);

      // Dimension meters
      expect(find.text('Concept Retention'), findsOneWidget);
      expect(find.text('Tactile Interactivity'), findsOneWidget);
      expect(find.text('Cognitive Simplicity'), findsOneWidget);
      expect(find.text('Gameplay Cohesion'), findsOneWidget);

      // Takeaways
      expect(find.text('CORE CONCEPT TAKEAWAYS FOR PLAYERS'), findsOneWidget);
      expect(find.textContaining('The Map is Not the Territory'), findsOneWidget);

      // Toggle 4-Phase breakdown
      expect(find.byKey(const Key('btn_toggle_education_breakdown')), findsOneWidget);
      expect(find.text('▼ VIEW 4-PHASE PEDAGOGICAL BREAKDOWN'), findsOneWidget);
      expect(find.text('1. On-Load Boot State (<4 KB)'), findsNothing);

      // Tap toggle to expand
      await tester.tap(find.byKey(const Key('btn_toggle_education_breakdown')));
      await tester.pumpAndSettle();

      expect(find.text('▲ HIDE 4-PHASE PEDAGOGICAL BREAKDOWN'), findsOneWidget);
      expect(find.text('1. On-Load Boot State (<4 KB)'), findsOneWidget);
      expect(find.text('2. JIT Context & Task Eviction'), findsOneWidget);
      expect(find.text('3. Predictive Pre-Emptive Caching'), findsOneWidget);
      expect(find.text('4. Overnight Cloud Consolidation'), findsOneWidget);

      // Trigger prefetch and dream sync to achieve mastery
      await memoryService.triggerStatePrefetch(
        stateTrigger: 'Player entered aqueduct',
        topicIds: ['undercity_sluice_bypass'],
      );
      await memoryService.applyDreamDeltaSync();

      // Tap refresh button to re-evaluate
      await tester.tap(find.byKey(const Key('btn_refresh_education_rater')));
      await tester.pumpAndSettle();
      expect(find.textContaining('GRADE: A+'), findsOneWidget);
    });
  });
}
