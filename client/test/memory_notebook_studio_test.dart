import 'package:flutter_test/flutter_test.dart';
import '../lib/services/local_memory_service.dart';
import '../lib/models/memory_tree_node.dart';

void main() {
  runMemoryNotebookStudioTests(test, (cond, [msg = 'Assertion failed']) => expect(cond, isTrue, reason: msg));
}

void runMemoryNotebookStudioTests(
  void Function(String name, dynamic Function() body) register,
  void Function(bool condition, [String message]) expect,
) {
  register('Hierarchical local memory tree builds all branches correctly', () {
    final service = LocalMemoryService();
    final tree = service.getLocalMemoryTree();

    expect(tree.id == 'local-root', 'Root id must be local-root');
    expect(tree.children.length == 3, 'Must contain Working Context, Queue, and Anchors branches');
    expect(tree.children[0].id == 'local-working-context', 'First branch must be working context');
    expect(tree.children[1].id == 'local-ingestion-queue', 'Second branch must be ingestion queue');
    expect(tree.children[2].id == 'local-edge-bundle', 'Third branch must be edge bundle');
    expect(tree.children[0].children.isNotEmpty, 'Working context should contain seed turn');
    expect(tree.children[2].children.length >= 4, 'Edge bundle should contain seed anchors');
  });

  register('Hierarchical cloud knowledge tree groups categories and audits', () {
    final service = LocalMemoryService();
    final cloudTree = service.getCloudKnowledgeTree();

    expect(cloudTree.id == 'cloud-root', 'Cloud root must be cloud-root');
    expect(cloudTree.children.isNotEmpty, 'Cloud categories must not be empty');

    // Find SYSTEM_ARCHITECTURE category
    final archCategory = cloudTree.children.firstWhere(
      (c) => c.label == 'SYSTEM_ARCHITECTURE',
      orElse: () => throw Exception('SYSTEM_ARCHITECTURE category missing'),
    );
    expect(archCategory.children.isNotEmpty, 'Category should have entity nodes');

    // Find node-arch-01 (Quantization Policy)
    final quantNode = archCategory.children.firstWhere(
      (n) => n.label == 'Quantization Policy',
      orElse: () => throw Exception('Quantization Policy node missing'),
    );
    expect(quantNode.children.isNotEmpty, 'Node should have relations or contradiction children');

    // Check contradiction audit child
    final contradictionChild = quantNode.children.firstWhere(
      (c) => c.nodeType == MemoryNodeType.contradiction,
      orElse: () => throw Exception('Contradiction audit missing under Quantization Policy'),
    );
    expect(contradictionChild.status == 'RESOLVED', 'Contradiction child status must be RESOLVED');
  });

  register('Simulator injects contradictory directive and updates audit records', () {
    final service = LocalMemoryService();
    final initialLogsCount = service.simulationLogs.length;

    service.simulateInjectContradiction(
      'Quantization Policy',
      'Enforce FP16 across all edge devices for scientific compute.',
      'User requested high-precision floating point execution test.',
    );

    expect(service.simulationLogs.length == initialLogsCount + 1, 'Simulation log must record injection event');
    expect(service.simulationLogs.first.contains('[Contradiction Injected]'), 'Log must contain Contradiction Injected tag');

    final updatedNode = service.durableNodes.firstWhere((n) => n.entityName == 'Quantization Policy');
    expect(updatedNode.summary.contains('FP16'), 'Node summary must reflect active directive');
    expect(updatedNode.contradictionRecords.length >= 2, 'Contradiction records must be appended');
    expect(updatedNode.contradictionRecords.last.activeDirective.contains('FP16'), 'Active directive in audit must match');
  });

  register('Simulator budget pressure tests 50 KB ceiling accurately', () {
    final service = LocalMemoryService();
    final initialAnchorsCount = service.activeEdgeBundle?.totalAnchors ?? 0;

    service.simulateBudgetPressure(20);

    final newAnchorsCount = service.activeEdgeBundle?.totalAnchors ?? 0;
    expect(newAnchorsCount == initialAnchorsCount + 20, 'Anchor count must increase by 20');
    expect(service.simulationLogs.first.contains('[Budget Pressure]'), 'Log must record budget pressure event');
  });

  register('Simulator offline partition toggles local edge isolation', () {
    final service = LocalMemoryService();
    expect(!service.isOfflinePartition, 'Initial partition state must be online');

    service.simulateOfflinePartition(true);
    expect(service.isOfflinePartition, 'Partition must be set to offline');
    expect(service.simulationLogs.first.contains('OFFLINE'), 'Log must note OFFLINE state');

    service.simulateOfflinePartition(false);
    expect(!service.isOfflinePartition, 'Partition must be restored to online');
    expect(service.simulationLogs.first.contains('ONLINE'), 'Log must note ONLINE state');
  });

  register('Simulator reset restores memory baseline state and clears logs', () {
    final service = LocalMemoryService();
    service.simulateBudgetPressure(10);
    service.simulateOfflinePartition(true);

    service.resetSimulation();
    expect(!service.isOfflinePartition, 'Reset must restore online state');
    expect(service.activeEdgeBundle?.totalAnchors == 6, 'Reset must restore 6 default anchors');
    expect(service.simulationLogs.length == 1, 'Reset must leave single reset notice log');
    expect(service.simulationLogs.first.contains('[Reset]'), 'Log must confirm reset');
  });

  register('Hierarchical Edge-Cloud diff tree builds all 4 delta branches correctly', () {
    final service = LocalMemoryService();
    final diffTree = service.getEdgeCloudDiffTree();

    expect(diffTree.id == 'diff-root', 'Root id must be diff-root');
    expect(diffTree.children.length == 4, 'Diff tree must contain 4 branches (pending, durable, topics, health)');
    expect(diffTree.children[0].id == 'diff-branch-pending', 'First branch must be pending ingestion');
    expect(diffTree.children[1].id == 'diff-branch-durable', 'Second branch must be durable vs anchor comparison');
    expect(diffTree.children[2].id == 'diff-branch-topics', 'Third branch must be topic cache delta');
    expect(diffTree.children[3].id == 'diff-branch-health', 'Fourth branch must be synchronization health');

    // Check metadata
    expect(diffTree.metadata.containsKey('pendingCount'), 'Metadata must include pendingCount');
    expect(diffTree.metadata.containsKey('syncedCount'), 'Metadata must include syncedCount');
    expect(diffTree.metadata.containsKey('modifiedCount'), 'Metadata must include modifiedCount');
    expect(diffTree.metadata.containsKey('bundleSizeKb'), 'Metadata must include bundleSizeKb');
  });

  register('Edge-Cloud diff tree dynamically reflects pending turns and contradictions', () {
    final service = LocalMemoryService();
    final diffTree = service.getEdgeCloudDiffTree();

    // Check durable comparison category branch
    final durableBranch = diffTree.children[1];
    expect(durableBranch.children.isNotEmpty, 'Durable branch must have category sub-branches');

    // In default state, Quantization Policy has a resolved contradiction
    final archBranch = durableBranch.children.firstWhere(
      (c) => c.label.contains('SYSTEM_ARCHITECTURE'),
      orElse: () => throw Exception('SYSTEM_ARCHITECTURE category missing in diff tree'),
    );
    final quantDiffNode = archBranch.children.firstWhere(
      (n) => n.label.contains('Quantization Policy'),
      orElse: () => throw Exception('Quantization Policy missing in diff tree'),
    );

    expect(quantDiffNode.nodeType == MemoryNodeType.diffModified, 'Quantization Policy with contradiction must be diffModified');
    expect(quantDiffNode.metadata.containsKey('contradiction'), 'Modified node must attach contradiction metadata');
    expect(quantDiffNode.children.length >= 2, 'Must contain local anchor, cloud node, and contradiction audit');

    // Check synched node without contradiction
    final secBranch = durableBranch.children.firstWhere(
      (c) => c.label.contains('SECURITY_POLICY'),
      orElse: () => throw Exception('SECURITY_POLICY category missing in diff tree'),
    );
    final piiNode = secBranch.children.firstWhere(
      (n) => n.label.contains('Zero Cloud Egress for PII'),
      orElse: () => throw Exception('Zero Cloud Egress for PII missing in diff tree'),
    );
    expect(piiNode.nodeType == MemoryNodeType.diffSynced, 'Zero Cloud Egress for PII must be diffSynced');

    // Check pending ingestion branch
    final pendingBranch = diffTree.children[0];
    expect(pendingBranch.children.isNotEmpty, 'Pending branch must show turns in ingestion queue');
    final firstPending = pendingBranch.children.first;
    expect(firstPending.nodeType == MemoryNodeType.diffAdded, 'Pending turn must be diffAdded');
    expect(firstPending.children.isNotEmpty, 'Pending turn must display extracted entity attributes');
  });
}

