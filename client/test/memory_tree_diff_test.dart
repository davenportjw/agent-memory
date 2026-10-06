import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:client/views/widgets/memory_tree_view.dart';
import 'package:client/services/local_memory_service.dart';
import 'package:client/models/memory_node.dart';

void main() {
  group('MemoryTreeView Edge-Cloud Diff Suite (TDD)', () {
    testWidgets('Renders segmented control with 3 tabs and switches to Edge-Cloud Diff tree', (tester) async {
      tester.view.physicalSize = const Size(800, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final service = LocalMemoryService();
      final localTree = service.getLocalMemoryTree();
      final cloudTree = service.getCloudKnowledgeTree();
      final diffTree = service.getEdgeCloudDiffTree();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: MemoryTreeView(
                localTree: localTree,
                cloudTree: cloudTree,
                diffTree: diffTree,
                onInspectContradiction: (_, __) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Initially on tab 0 (Local Edge Tree)
      expect(find.text('📱 Local Edge Memory Tree'), findsOneWidget);
      expect(find.text('⚡ Edge-to-Cloud Difference Tree'), findsNothing);

      // Tap tab 2 (⚡ Edge-Cloud Diff)
      await tester.tap(find.text('⚡ Edge-Cloud Diff'));
      await tester.pumpAndSettle();

      // Now Edge-to-Cloud Difference Tree is shown
      expect(find.text('⚡ Edge-to-Cloud Difference Tree'), findsOneWidget);
      expect(find.text('⚡ Edge-to-Cloud Delta & Synchronization Status'), findsOneWidget);
      expect(find.text('Local Ingestion Queue (1 turns awaiting cloud)'), findsOneWidget);
      expect(find.textContaining('Durable Knowledge vs. Edge Anchors'), findsOneWidget);
      expect(find.textContaining('Topic Cache Delta'), findsOneWidget);
      expect(find.text('Synchronization Health & Partition State'), findsOneWidget);
    });

    testWidgets('Tapping contradiction in Diff Tree dispatches onInspectContradiction callback', (tester) async {
      tester.view.physicalSize = const Size(1000, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final service = LocalMemoryService();
      final localTree = service.getLocalMemoryTree();
      final cloudTree = service.getCloudKnowledgeTree();
      final diffTree = service.getEdgeCloudDiffTree();

      ContradictionRecord? inspectedRecord;
      DurableKnowledgeNode? inspectedNode;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: MemoryTreeView(
                localTree: localTree,
                cloudTree: cloudTree,
                diffTree: diffTree,
                onInspectContradiction: (record, node) {
                  inspectedRecord = record;
                  inspectedNode = node;
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Switch to Diff tab
      await tester.tap(find.text('⚡ Edge-Cloud Diff'));
      await tester.pumpAndSettle();

      // Find the contradiction inspection affordance
      final contradictionAffordance = find.text('Click to inspect full contradiction audit trail ➔');
      expect(contradictionAffordance, findsOneWidget);

      // Tap it
      await tester.tap(contradictionAffordance);
      await tester.pumpAndSettle();

      // Verify callback was dispatched
      expect(inspectedRecord, isNotNull);
      expect(inspectedNode, isNotNull);
      expect(inspectedNode!.entityName, 'Quantization Policy');
    });

    testWidgets('Desktop view supports selecting Edge-Cloud Diff view', (tester) async {
      // Large desktop width
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final service = LocalMemoryService();
      final localTree = service.getLocalMemoryTree();
      final cloudTree = service.getCloudKnowledgeTree();
      final diffTree = service.getEdgeCloudDiffTree();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: MemoryTreeView(
                localTree: localTree,
                cloudTree: cloudTree,
                diffTree: diffTree,
                onInspectContradiction: (_, __) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Segmented control is available on desktop with Diff option
      expect(find.text('⚡ Edge-Cloud Diff'), findsOneWidget);
      await tester.tap(find.text('⚡ Edge-Cloud Diff'));
      await tester.pumpAndSettle();

      expect(find.text('⚡ Edge-to-Cloud Difference Tree'), findsOneWidget);
      expect(find.text('Local Ingestion Queue (1 turns awaiting cloud)'), findsOneWidget);
    });
  });
}
