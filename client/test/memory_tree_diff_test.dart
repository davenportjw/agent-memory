import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:client/views/widgets/memory_tree_view.dart';
import 'package:client/services/local_memory_service.dart';
import 'package:client/models/memory_node.dart';

void main() {
  group('MemoryTreeView Edge-Cloud Diff Suite (TDD)', () {
    testWidgets('Diff view is default hero star, renders delta summary, and switches tabs', (tester) async {
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

      // Diff view is now the DEFAULT STAR VIEW on load
      expect(find.text('⚡ Edge-to-Cloud Difference Tree'), findsOneWidget);
      expect(find.text('⚡ Edge-to-Cloud Delta & Synchronization Status'), findsOneWidget);
      expect(find.text('Memory Movement Tasks (Edge ⮂ Cloud)'), findsOneWidget);
      expect(find.byKey(const Key('diff-action-consolidate')), findsOneWidget);
      expect(find.byKey(const Key('diff-action-repack')), findsOneWidget);
      expect(find.byKey(const Key('diff-action-prune')), findsOneWidget);

      // Tap tab 0 (📱 Local Edge Tree)
      await tester.tap(find.text('📱 Local Edge Tree'));
      await tester.pumpAndSettle();

      // Now Local Edge Tree is shown
      expect(find.text('📱 Local Edge Memory Tree'), findsOneWidget);
      expect(find.text('⚡ Edge-to-Cloud Difference Tree'), findsNothing);
    });

    testWidgets('Tapping memory movement tasks dispatches callbacks accurately', (tester) async {
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

      bool consolidated = false;
      bool repacked = false;
      bool pruned = false;
      String? prefetchedTopic;
      String? evictedTopic;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: MemoryTreeView(
                localTree: localTree,
                cloudTree: cloudTree,
                diffTree: diffTree,
                onConsolidateQueue: () => consolidated = true,
                onRepackBundle: () => repacked = true,
                onPruneContext: () => pruned = true,
                onPrefetchTopic: (id) => prefetchedTopic = id,
                onEvictTopic: (id) => evictedTopic = id,
                onInspectContradiction: (_, __) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap consolidate queue
      await tester.tap(find.byKey(const Key('diff-action-consolidate')));
      await tester.pumpAndSettle();
      expect(consolidated, isTrue);

      // Tap repack bundle
      await tester.tap(find.byKey(const Key('diff-action-repack')));
      await tester.pumpAndSettle();
      expect(repacked, isTrue);

      // Tap prune context
      await tester.tap(find.byKey(const Key('diff-action-prune')));
      await tester.pumpAndSettle();
      expect(pruned, isTrue);
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

      // Find the contradiction inspection affordance in default diff view
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

    testWidgets('Desktop view supports selecting Edge-Cloud Diff view and Split view', (tester) async {
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
      expect(find.text('⚡ Edge-to-Cloud Difference Tree'), findsOneWidget);
      expect(find.text('Local Ingestion Queue (1 turns awaiting cloud)'), findsOneWidget);

      // Switch to Split View
      expect(find.text('🔀 Split View'), findsOneWidget);
      await tester.tap(find.text('🔀 Split View'));
      await tester.pumpAndSettle();

      expect(find.text('📱 Local Edge Memory Tree'), findsOneWidget);
      expect(find.text('☁️ Cloud Durable Knowledge Tree'), findsOneWidget);
    });
  });
}
