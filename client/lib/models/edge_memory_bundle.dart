import 'dart:convert';

class MemoryAnchor {
  final String anchorId;
  final String key;
  final String category;
  final String distilledContext;

  const MemoryAnchor({
    required this.anchorId,
    required this.key,
    required this.category,
    required this.distilledContext,
  });

  Map<String, dynamic> toJson() => {
    'anchor_id': anchorId,
    'key': key,
    'category': category,
    'distilled_context': distilledContext,
  };

  factory MemoryAnchor.fromJson(Map<String, dynamic> json) => MemoryAnchor(
    anchorId: json['anchor_id'] ?? '',
    key: json['key'] ?? '',
    category: json['category'] ?? 'SYSTEM_ARCHITECTURE',
    distilledContext: json['distilled_context'] ?? '',
  );
}

class CompactEdgeMemoryBundle {
  final int bundleVersion;
  final DateTime createdAt;
  final int totalAnchors;
  final int sizeBytes;
  final List<MemoryAnchor> anchors;

  static const int maxBundleSizeBytes = 51200; // Strictly < 50 KB

  const CompactEdgeMemoryBundle({
    required this.bundleVersion,
    required this.createdAt,
    required this.totalAnchors,
    required this.sizeBytes,
    required this.anchors,
  });

  bool get isWithinBudget => sizeBytes <= maxBundleSizeBytes;

  double get sizeKb => sizeBytes / 1024.0;

  Map<String, dynamic> toJson() => {
    'bundle_version': bundleVersion,
    'created_at': createdAt.toIso8601String(),
    'total_anchors': totalAnchors,
    'size_bytes': sizeBytes,
    'anchors': anchors.map((a) => a.toJson()).toList(),
  };

  factory CompactEdgeMemoryBundle.fromJson(Map<String, dynamic> json) {
    final rawAnchors = (json['anchors'] as List<dynamic>?)
            ?.map((e) => MemoryAnchor.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];
    final calculatedBytes = utf8.encode(jsonEncode(json)).length;

    return CompactEdgeMemoryBundle(
      bundleVersion: json['bundle_version'] ?? 1,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : DateTime.now(),
      totalAnchors: json['total_anchors'] ?? rawAnchors.length,
      sizeBytes: json['size_bytes'] ?? calculatedBytes,
      anchors: rawAnchors,
    );
  }
}
