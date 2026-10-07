import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:client/views/device_test_bench.dart';
import 'package:client/views/widgets/radar_chart_widget.dart';

void main() {
  testWidgets('Model Test Bench: Renders single prompt input, presets, and 4 model cards without radar charts', (WidgetTester tester) async {
    // Set a large enough surface size so all cards fit without clipping
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: DeviceTestBench(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 1. Verify Title & Header
    expect(find.text('MULTI-MODEL COMPARATIVE TEST BENCH'), findsOneWidget);

    // 2. Verify Single Prompt Input and Action Button
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Run Across All Models'), findsOneWidget);

    // 3. Verify Preset Prompt Chips
    expect(find.text('PII Redaction Test'), findsOneWidget);
    expect(find.text('Strict JSON Schema'), findsOneWidget);

    // 4. Verify all 4 Model Combinations exist
    expect(find.textContaining('Gemma 4 2B'), findsWidgets);
    expect(find.textContaining('Gemma 4 A4B'), findsWidgets);
    expect(find.textContaining('Gemini Nano'), findsWidgets);
    expect(find.textContaining('Gemini 3.8 Flash'), findsWidgets);

    // 5. STRICT USER DIRECTIVE: Verify radar chart is completely removed
    expect(find.byType(RadarChartWidget), findsNothing);
  });

  testWidgets('Model Test Bench: Selecting preset prompt populates input field', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: DeviceTestBench(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Tap preset chip 'Strict JSON Schema'
    await tester.tap(find.text('Strict JSON Schema'));
    await tester.pumpAndSettle();

    // Verify text field contains JSON prompt
    expect(find.textContaining('schema'), findsWidgets);
  });

  testWidgets('Model Test Bench: Model execution yields rated responses and inspectable rubric modal', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: DeviceTestBench(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Enter a prompt into the single prompt input
    await tester.enterText(
      find.byType(TextField),
      'Extract action items and redact contact details: Contact alice@example.org or call 555-0199.',
    );
    await tester.pumpAndSettle();

    // Tap 'Run Across All Models'
    await tester.tap(find.text('Run Across All Models'));
    
    // Pump through the inference streams
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    // Verify rating displays: scores out of 5.0
    expect(find.textContaining('/ 5.0'), findsWidgets);

    // Verify the 4 rubric dimensions are presented
    expect(find.textContaining('Semantic Fidelity'), findsWidgets);
    expect(find.textContaining('Instruction Compliance'), findsWidgets);
    expect(find.textContaining('Safety & PII Redaction'), findsWidgets);
    expect(find.textContaining('Efficiency Factor'), findsWidgets);

    // Verify inspectable affordance exists and can be tapped
    final inspectButtons = find.text('Inspect Rubrics & Trace');
    expect(inspectButtons, findsWidgets);

    await tester.tap(inspectButtons.first);
    await tester.pumpAndSettle();

    // Verify modal detail sheet opens with What, Why, and Telemetry per ui-clarity-and-tdd
    expect(find.text('Model Evaluation Trace'), findsOneWidget);
    expect(find.textContaining('Composite Rating Breakdown'), findsOneWidget);
  });

  testWidgets('Model Test Bench: Action bar embeds GemmaLoadPill and cards afford weight loading and cloud retry', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: DeviceTestBench(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 1. Verify GemmaLoadPill is present in the action bar
    expect(find.textContaining('Gemma 4'), findsWidgets);

    // 2. Verify on-device Gemma weight readiness banner appears
    expect(find.text('Weights not resident (~1.46 GB)'), findsWidgets);
    expect(find.text('Load Weights'), findsWidgets);

    // 3. Tap 'Run Across All Models'
    await tester.tap(find.text('Run Across All Models'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    // 4. Verify actionable recovery buttons appear on failed/unloaded models (Zero False Affordances)
    expect(find.text('Load Gemma 4 Weights'), findsWidgets);
    expect(find.text('Run on Cloud Run'), findsWidgets);
    expect(find.text('Retry Connection'), findsOneWidget);
    expect(find.textContaining('Target: http'), findsOneWidget);
  });
}

