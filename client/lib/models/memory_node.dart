class NodeRelation {
  final String predicate;
  final String targetNodeId;

  const NodeRelation({
    required this.predicate,
    required this.targetNodeId,
  });

  Map<String, dynamic> toJson() => {
    'predicate': predicate,
    'target_node_id': targetNodeId,
  };

  factory NodeRelation.fromJson(Map<String, dynamic> json) => NodeRelation(
    predicate: json['predicate'] ?? '',
    targetNodeId: json['target_node_id'] ?? '',
  );
}

class ContradictionRecord {
  final String id;
  final String priorDirective;
  final String activeDirective;
  final String rationale;
  final DateTime resolvedAt;

  const ContradictionRecord({
    required this.id,
    required this.priorDirective,
    required this.activeDirective,
    required this.rationale,
    required this.resolvedAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'prior_directive': priorDirective,
    'active_directive': activeDirective,
    'rationale': rationale,
    'resolved_at': resolvedAt.toIso8601String(),
  };

  factory ContradictionRecord.fromJson(Map<String, dynamic> json) => ContradictionRecord(
    id: json['id'] as String? ?? '',
    priorDirective: json['prior_directive'] as String? ?? '',
    activeDirective: json['active_directive'] as String? ?? '',
    rationale: json['rationale'] as String? ?? '',
    resolvedAt: DateTime.tryParse(json['resolved_at'] as String? ?? '') ?? DateTime.now(),
  );
}

class DurableKnowledgeNode {
  final String id;
  final String entityName;
  final String category; // USER_PREFERENCE, SYSTEM_ARCHITECTURE, ROADMAP_DECISION, SECURITY_POLICY
  final String summary;
  final double confidence;
  final List<NodeRelation> relations;
  final List<String> sourceEpisodeIds;
  final List<String> resolvedContradictions;
  final List<ContradictionRecord> contradictionRecords;
  final DateTime lastUpdated;

  const DurableKnowledgeNode({
    required this.id,
    required this.entityName,
    required this.category,
    required this.summary,
    required this.confidence,
    this.relations = const [],
    this.sourceEpisodeIds = const [],
    this.resolvedContradictions = const [],
    this.contradictionRecords = const [],
    required this.lastUpdated,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'entity_name': entityName,
    'category': category,
    'summary': summary,
    'confidence': confidence,
    'relations': relations.map((r) => r.toJson()).toList(),
    'source_episode_ids': sourceEpisodeIds,
    'resolved_contradictions': resolvedContradictions,
    'contradiction_records': contradictionRecords.map((r) => r.toJson()).toList(),
    'last_updated': lastUpdated.toIso8601String(),
  };

  factory DurableKnowledgeNode.fromJson(Map<String, dynamic> json) => DurableKnowledgeNode(
    id: json['id'] ?? '',
    entityName: json['entity_name'] ?? '',
    category: json['category'] ?? 'SYSTEM_ARCHITECTURE',
    summary: json['summary'] ?? '',
    confidence: (json['confidence'] as num?)?.toDouble() ?? 1.0,
    relations: (json['relations'] as List<dynamic>?)
            ?.map((r) => NodeRelation.fromJson(r as Map<String, dynamic>))
            .toList() ??
        [],
    sourceEpisodeIds: (json['source_episode_ids'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
    resolvedContradictions:
        (json['resolved_contradictions'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
    contradictionRecords: (json['contradiction_records'] as List<dynamic>?)
            ?.map((r) => ContradictionRecord.fromJson(r as Map<String, dynamic>))
            .toList() ??
        [],
    lastUpdated: json['last_updated'] != null ? DateTime.parse(json['last_updated']) : DateTime.now(),
  );
}
