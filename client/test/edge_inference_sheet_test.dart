import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:client/services/local_execution_manager.dart';
import 'package:client/views/widgets/edge_inference_sheet.dart';

void main() {
  testWidgets('EdgeInferenceSheet renders engines and allows switching selection', (tester) async {
    final manager = LocalExecutionManager();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () => EdgeInferenceSheet.show(context, manager),
                child: const Text('Open Sheet'),
              );
            },
          ),
        ),
      ),
    );

    // Tap button to show bottom sheet
    await tester.tap(find.text('Open Sheet'));
    await tester.pumpAndSettle();

    // Verify Title & Engine options
    expect(find.text('On-Device Browser Inference'), findsOneWidget);
    expect(find.text('Auto (Best Engine Probe)'), findsOneWidget);
    expect(find.text('Gemini Nano (Chrome Built-in AI)'), findsOneWidget);
    expect(find.text('Gemma 4 int4 (WebGPU / LiteRT)'), findsOneWidget);

    // Default selection is auto
    expect(manager.selectedEngine, EdgeEngineSelection.auto);

    // Select Gemini Nano
    await tester.tap(find.text('Gemini Nano (Chrome Built-in AI)'));
    await tester.pumpAndSettle();
    expect(manager.selectedEngine, EdgeEngineSelection.geminiNano);

    // Select Gemma 4
    await tester.tap(find.text('Gemma 4 int4 (WebGPU / LiteRT)'));
    await tester.pumpAndSettle();
    expect(manager.selectedEngine, EdgeEngineSelection.gemma4);

    // Select Auto back
    await tester.tap(find.text('Auto (Best Engine Probe)'));
    await tester.pumpAndSettle();
    expect(manager.selectedEngine, EdgeEngineSelection.auto);
  });
}
