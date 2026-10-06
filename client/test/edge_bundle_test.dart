import 'package:flutter_test/flutter_test.dart';
import '../lib/models/edge_memory_bundle.dart';

void main() {
  runEdgeBundleTests(test, (cond, [msg = 'Assertion failed']) => expect(cond, isTrue, reason: msg));
}

void runEdgeBundleTests(void Function(String name, void Function() body) test, void Function(bool condition, [String message]) expect) {
  test('Edge Bundle: Strict size budget enforcement (< 50 KB / 51,200 bytes)', () {
    final anchors = List.generate(14, (i) {
      return MemoryAnchor(
        anchorId: 'anchor-$i',
        key: 'Architecture Rule $i',
        category: 'SYSTEM_ARCHITECTURE',
        distilledContext: 'Distilled policy enforcing constraint $i for mobile memory safety.',
      );
    });

    final bundle = CompactEdgeMemoryBundle(
      bundleVersion: 5,
      createdAt: DateTime.now(),
      totalAnchors: anchors.length,
      sizeBytes: 29082, // 28.4 KB
      anchors: anchors,
    );

    expect(bundle.isWithinBudget == true, 'Bundle exceeds 50 KB size limit');
    expect(bundle.sizeBytes <= 51200, 'Bundle size strictly exceeds 51,200 bytes ceiling');
    expect(bundle.sizeKb < 50.0, 'Bundle size in KB exceeds 50.0 KB');
  });

  test('Edge Bundle: JSON serialization roundtrip preserves anchors', () {
    final bundle = CompactEdgeMemoryBundle(
      bundleVersion: 2,
      createdAt: DateTime.now(),
      totalAnchors: 2,
      sizeBytes: 15420,
      anchors: const [
        MemoryAnchor(
          anchorId: 'a1',
          key: 'Int4 Quantization',
          category: 'SYSTEM_ARCHITECTURE',
          distilledContext: 'Gemma 4 int4 model footprint < 1.3 GB.',
        ),
        MemoryAnchor(
          anchorId: 'a2',
          key: 'Zero PII Egress',
          category: 'SECURITY_POLICY',
          distilledContext: 'Redact emails before sync.',
        ),
      ],
    );

    final json = bundle.toJson();
    final restored = CompactEdgeMemoryBundle.fromJson(json);

    expect(restored.bundleVersion == 2, 'Bundle version mismatch');
    expect(restored.anchors.length == 2, 'Anchors count mismatch');
    expect(restored.anchors.first.key == 'Int4 Quantization', 'Anchor key mismatch');
  });
}
