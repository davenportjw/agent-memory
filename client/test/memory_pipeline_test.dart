import 'package:flutter_test/flutter_test.dart';
import '../lib/models/episodic_turn.dart';
import '../lib/models/memory_node.dart';
import '../lib/services/local_memory_service.dart';

void main() {
  runMemoryPipelineTests(test, (cond, [msg = 'Assertion failed']) => expect(cond, isTrue, reason: msg));
}

void runMemoryPipelineTests(void Function(String name, void Function() body) test, void Function(bool condition, [String message]) expect) {
  test('Memory: EpisodicTurn serialization and entity extraction', () {
    final turn = EpisodicTurn(
      id: 'ep-test-01',
      sessionId: 'sess-test',
      timestamp: DateTime.now(),
      userPrompt: 'Migrate to SQLite WASM before Friday.',
      modelResponse: 'Completed task extraction.',
      route: 'EDGE_LOCAL',
      modelName: 'gemma-4-2b',
      latencyMs: 95,
      ttftMs: 58,
      isPiiSanitized: true,
      entitiesExtracted: [
        const ExtractedEntity(entityType: 'DATABASE_ENGINE', entityValue: 'SQLite WASM', confidence: 0.99),
        const ExtractedEntity(entityType: 'DEADLINE', entityValue: 'Friday', confidence: 0.95),
      ],
    );

    final json = turn.toJson();
    final restored = EpisodicTurn.fromJson(json);

    expect(restored.id == 'ep-test-01', 'Id mismatch');
    expect(restored.entitiesExtracted.length == 2, 'Entities count mismatch');
    expect(restored.isPiiSanitized == true, 'Sanitized flag mismatch');
  });

  test('Memory: DurableKnowledgeNode contradiction resolution and relations', () {
    final node = DurableKnowledgeNode(
      id: 'node-arch-test',
      entityName: 'Quantization Target',
      category: 'SYSTEM_ARCHITECTURE',
      summary: 'Enforce int4 quantization on Gemma 4.',
      confidence: 0.99,
      relations: [
        const NodeRelation(predicate: 'CONSTRAINS', targetNodeId: 'node-budget'),
      ],
      sourceEpisodeIds: ['ep-01', 'ep-02'],
      resolvedContradictions: ['Superseded FP16 trial from Q2 roadmap'],
      lastUpdated: DateTime.now(),
    );

    final json = node.toJson();
    final restored = DurableKnowledgeNode.fromJson(json);

    expect(restored.entityName == 'Quantization Target', 'Entity name mismatch');
    expect(restored.resolvedContradictions.isNotEmpty, 'Contradictions list empty');
    expect(restored.relations.first.predicate == 'CONSTRAINS', 'Relation predicate mismatch');
  });

  test('Memory: LocalMemoryService offline consolidation merges and updates graph', () async {
    final memoryService = LocalMemoryService();
    final initialNodeCount = memoryService.durableNodes.length;

    // Commit a new turn to working context
    memoryService.commitTurn(
      EpisodicTurn(
        id: 'ep-dynamic-01',
        sessionId: 'sess-live',
        timestamp: DateTime.now(),
        userPrompt: 'Implement IndexedDB storage driver',
        modelResponse: 'Driver template generated.',
        route: 'CLOUD_ESCALATE',
        modelName: 'gemini-3.8-flash',
        latencyMs: 240,
        ttftMs: 220,
        isPiiSanitized: false,
        entitiesExtracted: [
          const ExtractedEntity(entityType: 'LOCAL_STORAGE', entityValue: 'IndexedDB', confidence: 0.96),
        ],
        status: 'UNCONSOLIDATED',
      ),
    );

    expect(memoryService.ingestionQueue.isNotEmpty, 'Ingestion queue should contain unconsolidated turn');

    // Trigger consolidation
    await memoryService.triggerOfflineConsolidation();

    expect(memoryService.ingestionQueue.isEmpty, 'Ingestion queue should be drained after consolidation');
    expect(memoryService.durableNodes.length >= initialNodeCount, 'Durable graph should have updated');
    expect(memoryService.activeEdgeBundle != null, 'Edge bundle should exist');
  });

  test('Memory: ContradictionRecord serialization and revertContradiction rollback', () {
    final record = ContradictionRecord(
      id: 'cr-test-01',
      priorDirective: 'Planned FP16 trial in Q2 roadmap for high-precision inference',
      activeDirective: 'Enforce int4 quantization on Gemma 4 to fit within 2 GB client RAM limits',
      rationale: 'int4 quantization supersedes earlier FP16 roadmap trial',
      resolvedAt: DateTime.now(),
    );

    final json = record.toJson();
    final restoredRecord = ContradictionRecord.fromJson(json);
    expect(restoredRecord.id == 'cr-test-01', 'Record id mismatch');
    expect(restoredRecord.priorDirective.contains('FP16'), 'Prior directive mismatch');

    final nodeWithRecord = DurableKnowledgeNode(
      id: 'node-roundtrip',
      entityName: 'Quantization Policy',
      category: 'SYSTEM_ARCHITECTURE',
      summary: 'Enforce int4 quantization on Gemma 4.',
      confidence: 0.99,
      contradictionRecords: [restoredRecord],
      resolvedContradictions: ['Superseded FP16 trial from Q2 roadmap'],
      lastUpdated: DateTime.now(),
    );
    final nodeJson = nodeWithRecord.toJson();
    final restoredNode = DurableKnowledgeNode.fromJson(nodeJson);
    expect(restoredNode.contradictionRecords.length == 1, 'Contradiction record count mismatch');
    expect(restoredNode.contradictionRecords.first.id == 'cr-test-01', 'Contradiction record id mismatch');

    // Test revertContradiction rollback in LocalMemoryService
    final memoryService = LocalMemoryService();
    final initialNode = memoryService.durableNodes.firstWhere((n) => n.id == 'node-arch-01');
    expect(initialNode.contradictionRecords.isNotEmpty, 'Initial contradictionRecords should not be empty');
    expect(initialNode.resolvedContradictions.isNotEmpty, 'Initial resolvedContradictions should not be empty');

    memoryService.revertContradiction('node-arch-01', initialNode.resolvedContradictions.first);

    final updatedNode = memoryService.durableNodes.firstWhere((n) => n.id == 'node-arch-01');
    expect(updatedNode.resolvedContradictions.isEmpty, 'Resolved contradictions should be removed after rollback');
    expect(updatedNode.summary.contains('Reverted to prior directive'), 'Summary should reflect reverted state');
  });
}
