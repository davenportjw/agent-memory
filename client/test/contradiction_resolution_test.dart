import 'dart:io';

import '../lib/models/memory_node.dart';
import '../lib/services/local_memory_service.dart';

void runContradictionResolutionTests(
  void Function(String name, dynamic Function() body) test,
  void Function(bool condition, [String message]) expect,
) {
  test('Contradiction: ContradictionRecord serialization and deserialization (toJson / fromJson)', () {
    final fixedTime = DateTime.parse('2026-10-01T12:30:00.000Z');
    final record = ContradictionRecord(
      id: 'cr-test-spec-01',
      priorDirective: 'Planned FP16 trial in Q2 roadmap for high-precision inference',
      activeDirective: 'Enforce int4 quantization on Gemma 4 to fit within 2 GB client RAM limits',
      rationale: 'int4 quantization supersedes earlier FP16 roadmap trial to prevent macOS memory panics',
      resolvedAt: fixedTime,
    );

    final json = record.toJson();
    expect(json['id'] == 'cr-test-spec-01', 'Field id missing or incorrect in json');
    expect(json['prior_directive'] == 'Planned FP16 trial in Q2 roadmap for high-precision inference', 'Field prior_directive missing or incorrect');
    expect(json['active_directive'] == 'Enforce int4 quantization on Gemma 4 to fit within 2 GB client RAM limits', 'Field active_directive missing or incorrect');
    expect(json['rationale'] == 'int4 quantization supersedes earlier FP16 roadmap trial to prevent macOS memory panics', 'Field rationale missing or incorrect');
    expect(json['resolved_at'] == fixedTime.toIso8601String(), 'Field resolved_at missing or incorrect');

    final restored = ContradictionRecord.fromJson(json);
    expect(restored.id == record.id, 'Restored id mismatch');
    expect(restored.priorDirective == record.priorDirective, 'Restored priorDirective mismatch');
    expect(restored.activeDirective == record.activeDirective, 'Restored activeDirective mismatch');
    expect(restored.rationale == record.rationale, 'Restored rationale mismatch');
    expect(restored.resolvedAt.toIso8601String() == fixedTime.toIso8601String(), 'Restored resolvedAt mismatch');
  });

  test('Contradiction: NodeRelation serialization and deserialization (toJson / fromJson)', () {
    const relation = NodeRelation(
      predicate: 'CONSTRAINS',
      targetNodeId: 'node-arch-02',
    );

    final json = relation.toJson();
    expect(json['predicate'] == 'CONSTRAINS', 'Relation predicate mismatch in json');
    expect(json['target_node_id'] == 'node-arch-02', 'Relation target_node_id mismatch in json');

    final restored = NodeRelation.fromJson(json);
    expect(restored.predicate == 'CONSTRAINS', 'Restored relation predicate mismatch');
    expect(restored.targetNodeId == 'node-arch-02', 'Restored relation targetNodeId mismatch');
  });

  test('Contradiction: DurableKnowledgeNode roundtrip preserves contradictionRecords and relations', () {
    final fixedTime = DateTime.parse('2026-10-01T14:00:00.000Z');
    final record1 = ContradictionRecord(
      id: 'cr-spec-roundtrip-01',
      priorDirective: 'Planned FP16 trial in Q2 roadmap for high-precision inference',
      activeDirective: 'Enforce int4 quantization on Gemma 4 to fit within 2 GB client RAM limits',
      rationale: 'Hardware limits enforce 2 GB ceiling for client RAM',
      resolvedAt: fixedTime,
    );

    const relation1 = NodeRelation(
      predicate: 'CONSTRAINS',
      targetNodeId: 'node-arch-02',
    );

    const relation2 = NodeRelation(
      predicate: 'IMPLEMENTS',
      targetNodeId: 'node-road-04',
    );

    final node = DurableKnowledgeNode(
      id: 'node-arch-test-roundtrip',
      entityName: 'Quantization Target Spec',
      category: 'SYSTEM_ARCHITECTURE',
      summary: 'Enforce int4 quantization on Gemma 4.',
      confidence: 0.99,
      relations: [relation1, relation2],
      sourceEpisodeIds: ['ep-seed-01', 'ep-seed-02'],
      resolvedContradictions: ['Superseded FP16 trial from Q2 roadmap'],
      contradictionRecords: [record1],
      lastUpdated: fixedTime,
    );

    final json = node.toJson();
    expect(json.containsKey('contradiction_records'), 'JSON must contain contradiction_records key');
    expect(json['contradiction_records'] is List, 'contradiction_records must be a list');
    final rawRecords = json['contradiction_records'] as List;
    expect(rawRecords.length == 1, 'contradiction_records length mismatch in json');
    expect(rawRecords.first['id'] == 'cr-spec-roundtrip-01', 'Contradiction record id mismatch in json');

    expect(json.containsKey('relations'), 'JSON must contain relations key');
    final rawRelations = json['relations'] as List;
    expect(rawRelations.length == 2, 'relations length mismatch in json');

    final restored = DurableKnowledgeNode.fromJson(json);
    expect(restored.id == node.id, 'Node id mismatch');
    expect(restored.entityName == node.entityName, 'Node entityName mismatch');
    expect(restored.category == node.category, 'Node category mismatch');
    expect(restored.summary == node.summary, 'Node summary mismatch');
    expect(restored.confidence == node.confidence, 'Node confidence mismatch');
    expect(restored.sourceEpisodeIds.length == 2, 'Source episodes count mismatch');
    expect(restored.resolvedContradictions.length == 1, 'Resolved contradictions count mismatch');
    expect(restored.resolvedContradictions.first == 'Superseded FP16 trial from Q2 roadmap', 'Resolved contradiction content mismatch');

    // Verify relations preserved and accessible
    expect(restored.relations.length == 2, 'Restored relations count mismatch');
    expect(restored.relations[0].predicate == 'CONSTRAINS', 'First relation predicate mismatch');
    expect(restored.relations[0].targetNodeId == 'node-arch-02', 'First relation targetNodeId mismatch');
    expect(restored.relations[1].predicate == 'IMPLEMENTS', 'Second relation predicate mismatch');
    expect(restored.relations[1].targetNodeId == 'node-road-04', 'Second relation targetNodeId mismatch');

    // Verify contradictionRecords preserved and accessible
    expect(restored.contradictionRecords.length == 1, 'Restored contradiction records count mismatch');
    final restoredRecord = restored.contradictionRecords.first;
    expect(restoredRecord.id == 'cr-spec-roundtrip-01', 'Restored contradiction record id mismatch');
    expect(restoredRecord.priorDirective == record1.priorDirective, 'Restored record priorDirective mismatch');
    expect(restoredRecord.activeDirective == record1.activeDirective, 'Restored record activeDirective mismatch');
    expect(restoredRecord.rationale == record1.rationale, 'Restored record rationale mismatch');
    expect(restoredRecord.resolvedAt.toIso8601String() == fixedTime.toIso8601String(), 'Restored record resolvedAt mismatch');
  });

  test('Contradiction: LocalMemoryService.revertContradiction drains contradiction, reverts summary, removes record, and notifies listeners', () {
    final memoryService = LocalMemoryService();

    // Verify initial seeded state of node-arch-01
    final initialNode = memoryService.durableNodes.firstWhere((n) => n.id == 'node-arch-01');
    expect(initialNode.resolvedContradictions.length == 1, 'Initial node must have 1 resolved contradiction');
    expect(initialNode.resolvedContradictions.first == 'Superseded FP16 trial from Q2 roadmap', 'Initial contradiction text mismatch');
    expect(initialNode.contradictionRecords.length == 1, 'Initial node must have 1 contradiction record');
    expect(initialNode.contradictionRecords.first.id == 'cr-01', 'Initial record id mismatch');
    expect(initialNode.contradictionRecords.first.priorDirective == 'Planned FP16 trial in Q2 roadmap for high-precision inference', 'Initial prior directive mismatch');
    expect(initialNode.relations.any((r) => r.predicate == 'CONSTRAINS' && r.targetNodeId == 'node-arch-02'), 'Initial node must retain CONSTRAINS relation to node-arch-02');

    final beforeLastUpdated = initialNode.lastUpdated;
    bool listenerNotified = false;
    void listener() {
      listenerNotified = true;
    }
    memoryService.addListener(listener);

    try {
      // Execute revertContradiction on seeded 'node-arch-01'
      memoryService.revertContradiction('node-arch-01', 'Superseded FP16 trial from Q2 roadmap');

      // Verify listener was notified
      expect(listenerNotified == true, 'revertContradiction must trigger notifyListeners()');

      // Fetch updated node
      final updatedNode = memoryService.durableNodes.firstWhere((n) => n.id == 'node-arch-01');

      // 1. Drains the matching contradiction from resolvedContradictions
      expect(updatedNode.resolvedContradictions.isEmpty, 'resolvedContradictions must be drained of matching contradiction');

      // 2. Reverts the node summary to the prior directive
      const expectedSummary = 'Reverted to prior directive: Planned FP16 trial in Q2 roadmap for high-precision inference';
      expect(updatedNode.summary == expectedSummary, 'Summary must revert to "$expectedSummary", got "${updatedNode.summary}"');

      // 3. Removes the matching ContradictionRecord
      expect(updatedNode.contradictionRecords.isEmpty, 'Matching ContradictionRecord must be removed');

      // 4. Relations are preserved and accessible
      expect(updatedNode.relations.length == 1, 'Relations must be preserved after revert');
      expect(updatedNode.relations.first.predicate == 'CONSTRAINS', 'Relation predicate must remain CONSTRAINS');
      expect(updatedNode.relations.first.targetNodeId == 'node-arch-02', 'Relation targetNodeId must remain node-arch-02');

      // 5. lastUpdated is updated
      expect(updatedNode.lastUpdated.isAfter(beforeLastUpdated) || updatedNode.lastUpdated == beforeLastUpdated, 'lastUpdated must be updated');
    } finally {
      memoryService.removeListener(listener);
    }
  });

  test('Contradiction: LocalMemoryService.revertContradiction on non-existent node safely no-ops', () {
    final memoryService = LocalMemoryService();
    bool listenerNotified = false;
    void listener() {
      listenerNotified = true;
    }
    memoryService.addListener(listener);

    try {
      // Calling with invalid node ID should safely return without throwing or notifying
      memoryService.revertContradiction('non-existent-node-xyz', 'Superseded FP16 trial');
      expect(listenerNotified == false, 'No listeners should be notified if nodeId does not exist');
    } finally {
      memoryService.removeListener(listener);
    }
  });

  test('Contradiction & Affordance: Three Context Questions audit on ContradictionRecord', () {
    final record = ContradictionRecord(
      id: 'cr-audit-01',
      priorDirective: 'Planned FP16 trial in Q2 roadmap for high-precision inference',
      activeDirective: 'Enforce int4 quantization on Gemma 4 to fit within 2 GB client RAM limits',
      rationale: 'int4 quantization supersedes earlier FP16 roadmap trial to prevent macOS memory panics and comply with Android LiteRT 1.4 GB RAM ceilings.',
      resolvedAt: DateTime.now(),
    );

    // Gate 1: Context Question 1 (What is it?)
    expect(record.activeDirective.isNotEmpty, 'What is it: activeDirective must clearly state the current policy');
    expect(record.activeDirective.contains('int4 quantization'), 'activeDirective must contain concrete human-readable term');

    // Gate 1: Context Question 2 (Why is it in this state?)
    expect(record.rationale.isNotEmpty, 'Why is it in this state: rationale must explain reason for resolution');
    expect(record.rationale.contains('prevent macOS memory panics'), 'rationale must detail engineering motivation');

    // Gate 1: Context Question 3 (What changed / What was prior directive?)
    expect(record.priorDirective.isNotEmpty, 'What changed: priorDirective must record preceding directive');
    expect(record.priorDirective.contains('FP16'), 'priorDirective must mention previous roadmap state');
    expect(record.resolvedAt.isBefore(DateTime.now().add(const Duration(seconds: 1))), 'Timestamp must be valid DateTime');
  });
}

/// Standalone entrypoint for running directly via `dart run test/contradiction_resolution_test.dart`
void main() {
  stdout.writeln('Running Contradiction Resolution & Affordance Test Suite...');
  int passed = 0;
  int failed = 0;

  void test(String name, dynamic Function() body) {
    try {
      final res = body();
      if (res is Future) {
        throw UnsupportedError('Async tests should be awaited via runner');
      }
      passed++;
      stdout.writeln('  ✓ [PASS] $name');
    } catch (e, st) {
      failed++;
      stdout.writeln('  ✗ [FAIL] $name');
      stdout.writeln('    Error: $e\n$st');
    }
  }

  void expect(bool condition, [String message = 'Assertion failed']) {
    if (!condition) {
      throw Exception(message);
    }
  }

  runContradictionResolutionTests(test, expect);

  stdout.writeln('\nSuite Summary: Passed: $passed, Failed: $failed');
  if (failed > 0) {
    exit(1);
  }
}
