import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:client/views/architecture_notebook_view.dart';
import 'package:client/services/local_execution_manager.dart';
import 'package:client/services/switching_router_service.dart';
import 'package:client/services/local_memory_service.dart';

void main() {
  group('ArchitectureNotebookView Tests', () {
    late LocalExecutionManager edgeManager;
    late SwitchingRouterService routerService;
    late LocalMemoryService memoryService;

    setUp(() {
      edgeManager = LocalExecutionManager();
      routerService = SwitchingRouterService();
      memoryService = LocalMemoryService();
    });

    Widget createWidgetUnderTest() {
      return MaterialApp(
        home: Scaffold(
          body: ArchitectureNotebookView(
            edgeManager: edgeManager,
            routerService: routerService,
            memoryService: memoryService,
          ),
        ),
      );
    }

    testWidgets('renders notebook header and all 4 stage cells', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      // Verify header
      expect(find.text('COMPUTATIONAL NOTEBOOK'), findsOneWidget);
      expect(find.text('Edge Architecture & On-Device Memory Notebook'), findsOneWidget);

      // Verify Cell [1]
      expect(find.text('CELL [1]'), findsOneWidget);
      expect(find.textContaining('Local AI Loading: Gemini Nano'), findsOneWidget);

      // Verify Cell [2]
      expect(find.text('CELL [2]'), findsOneWidget);
      expect(find.textContaining('Switching Logic: Priority-Based Policy Routing'), findsOneWidget);

      // Verify Cell [3]
      expect(find.text('CELL [3]'), findsOneWidget);
      expect(find.textContaining('Dreaming Logic: Asynchronous Offline Memory Consolidation'), findsOneWidget);

      // Verify Cell [4]
      expect(find.text('CELL [4]'), findsOneWidget);
      expect(find.textContaining('Selective On-Device Memory Loading: 4-Stage Architecture'), findsOneWidget);
    });

    testWidgets('allows switching code tabs in Cell 1', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      // Tab 1 is active initially: LocalExecutionManager.dart
      expect(find.text('client/lib/services/local_execution_manager.dart'), findsOneWidget);

      // Tap on chrome_prompt_api.js tab
      final chromeTab = find.text('chrome_prompt_api.js');
      await tester.ensureVisible(chromeTab);
      await tester.tap(chromeTab);
      await tester.pumpAndSettle();

      // Verify chrome_prompt_api.js is now shown
      expect(find.text('client/web/js/chrome_prompt_api.js'), findsOneWidget);
      expect(find.textContaining('Chrome Built-in AI (Gemini Nano) session creation'), findsOneWidget);

      // Tap on gemma_webgpu.js tab
      final gemmaTab = find.text('gemma_webgpu.js');
      await tester.ensureVisible(gemmaTab);
      await tester.tap(gemmaTab);
      await tester.pumpAndSettle();

      // Verify gemma_webgpu.js is now shown
      expect(find.text('client/web/js/gemma_webgpu.js'), findsOneWidget);
      expect(find.textContaining('Gemma 4 WebGPU Hardware Check'), findsOneWidget);
    });

    testWidgets('Cell 1 live demonstrator probes local engine', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      // Scroll to Probe Local Engine button
      final probeBtn = find.text('Probe Local Engine');
      await tester.ensureVisible(probeBtn);
      await tester.pumpAndSettle();

      expect(probeBtn, findsOneWidget);
      await tester.tap(probeBtn);
      await tester.pumpAndSettle();

      // Verify probe output is displayed
      expect(find.textContaining('Active Engine:'), findsOneWidget);
      expect(find.textContaining('Egress Guarantee: STRICT 0 KB'), findsOneWidget);
    });

    testWidgets('Cell 2 live demonstrator evaluates prompt and triggers PII shield', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      // Scroll to Evaluate Route button
      final evalBtn = find.text('Evaluate Route');
      await tester.ensureVisible(evalBtn);
      await tester.pumpAndSettle();

      expect(evalBtn, findsOneWidget);
      await tester.tap(evalBtn);
      await tester.pumpAndSettle();

      // Verify decision is EDGE_LOCAL with PII Firewall triggered
      expect(find.textContaining('ROUTE DECISION: EDGE_LOCAL'), findsOneWidget);
      expect(find.textContaining('PII Firewall Triggered: YES'), findsOneWidget);
    });

    testWidgets('Cell 3 live demonstrator applies dream delta sync', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      final dreamBtn = find.text('Trigger Dream Phase Delta');
      await tester.ensureVisible(dreamBtn);
      await tester.pumpAndSettle();

      expect(dreamBtn, findsOneWidget);
      await tester.tap(dreamBtn);
      await tester.pumpAndSettle();

      // Verify dream delta output
      expect(find.textContaining('Dream Delta Applied:'), findsOneWidget);
      expect(find.textContaining('Master Index Version:'), findsOneWidget);
      expect(find.textContaining('Budget PRESERVED'), findsOneWidget);
    });

    testWidgets('Cell 4 live demonstrator runs task with bound memory and executes immediate eviction', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      final taskBtn = find.text('Run Task with Bound Memory');
      await tester.ensureVisible(taskBtn);
      await tester.pumpAndSettle();

      expect(taskBtn, findsOneWidget);
      await tester.tap(taskBtn);
      await tester.pumpAndSettle();

      // Verify task output and immediate eviction rule
      expect(find.textContaining('Immediate Eviction Executed: YES'), findsOneWidget);
      expect(find.textContaining('Restored to baseline 256 tokens'), findsOneWidget);
      expect(find.textContaining('Zero RAM Leaks: Tab memory pressure preserved'), findsOneWidget);
    });

    testWidgets('Expand All / Collapse All buttons toggle notebook cells', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      // Verify all cells start expanded with educational callouts
      expect(find.text('Cognitive Concept & Hardware Boundary'), findsNWidgets(4));

      // Tap Collapse All
      await tester.tap(find.text('Collapse All'));
      await tester.pumpAndSettle();

      // Educational callouts should now be hidden
      expect(find.text('Cognitive Concept & Hardware Boundary'), findsNothing);

      // Tap Expand All
      await tester.tap(find.text('Expand All'));
      await tester.pumpAndSettle();

      // Educational callouts should be restored
      expect(find.text('Cognitive Concept & Hardware Boundary'), findsNWidgets(4));
    });
  });
}
