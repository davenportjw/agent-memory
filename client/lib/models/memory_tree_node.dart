enum MemoryNodeType {
  storeRoot,
  category,
  entityNode,
  relation,
  contradiction,
  turn,
  anchor,
  attribute,
  diffAdded,
  diffRemoved,
  diffModified,
  diffSynced,
}

/// Hierarchical Memory Tree Node representation for Local and Cloud tree views
class MemoryTreeNode {
  final String id;
  final String label;
  final String? subtitle;
  final MemoryNodeType nodeType;
  final String? status;
  final String? metric;
  final List<MemoryTreeNode> children;
  final Map<String, dynamic> metadata;
  bool isExpanded;

  MemoryTreeNode({
    required this.id,
    required this.label,
    this.subtitle,
    required this.nodeType,
    this.status,
    this.metric,
    List<MemoryTreeNode>? children,
    Map<String, dynamic>? metadata,
    this.isExpanded = true,
  })  : children = children ?? [],
        metadata = metadata ?? {};

  bool get hasChildren => children.isNotEmpty;

  MemoryTreeNode copyWith({
    String? id,
    String? label,
    String? subtitle,
    MemoryNodeType? nodeType,
    String? status,
    String? metric,
    List<MemoryTreeNode>? children,
    Map<String, dynamic>? metadata,
    bool? isExpanded,
  }) {
    return MemoryTreeNode(
      id: id ?? this.id,
      label: label ?? this.label,
      subtitle: subtitle ?? this.subtitle,
      nodeType: nodeType ?? this.nodeType,
      status: status ?? this.status,
      metric: metric ?? this.metric,
      children: children ?? this.children,
      metadata: metadata ?? this.metadata,
      isExpanded: isExpanded ?? this.isExpanded,
    );
  }
}
