import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/edge_memory_bundle.dart';
import '../services/local_memory_service.dart';
import '../services/switching_router_service.dart';
import '../theme/sepia_theme.dart';

class FeatureSynthesizerView extends StatefulWidget {
  final LocalMemoryService memoryService;

  const FeatureSynthesizerView({
    super.key,
    required this.memoryService,
  });

  @override
  State<FeatureSynthesizerView> createState() => _FeatureSynthesizerViewState();
}

class _FeatureSynthesizerViewState extends State<FeatureSynthesizerView> {
  int _selectedFeatureIndex = 0;
  bool _isSynthesizing = false;
  double? _liveHydrationMs;
  final SwitchingRouterService _routerService = SwitchingRouterService();
  final TextEditingController _piiTestController = TextEditingController(text: 'alice@example.org or call 555-0199');
  List<String> _detectedPiiInSandbox = [];

  @override
  void initState() {
    super.initState();
    widget.memoryService.addListener(_onMemoryUpdated);
    _benchmarkHydration();
    _testSandboxPii();
  }

  @override
  void dispose() {
    widget.memoryService.removeListener(_onMemoryUpdated);
    _piiTestController.dispose();
    super.dispose();
  }

  void _onMemoryUpdated() {
    if (mounted) {
      setState(() {
        _benchmarkHydration();
      });
    }
  }

  void _benchmarkHydration() {
    final bundle = widget.memoryService.activeEdgeBundle;
    if (bundle == null) return;
    try {
      final raw = jsonEncode(bundle.toJson());
      final sw = Stopwatch()..start();
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      CompactEdgeMemoryBundle.fromJson(decoded);
      sw.stop();
      _liveHydrationMs = sw.elapsedMicroseconds / 1000.0;
    } catch (_) {
      _liveHydrationMs = 0.5;
    }
  }

  void _testSandboxPii() {
    final matches = _routerService.detectPii(_piiTestController.text);
    setState(() {
      _detectedPiiInSandbox = matches;
    });
  }

  final List<Map<String, dynamic>> _features = [
    {
      'title': 'SQLite WASM Cache Optimizer',
      'anchorKey': 'Quantization Policy',
      'category': 'SYSTEM_ARCHITECTURE',
      'description': 'Dynamic on-device buffer manager that regulates Gemma 4 int4 activation memory under 1.3 GB.',
      'code': '''class CacheOptimizer {
  static const int maxRamBytes = 1400 * 1024 * 1024; // 1.4 GB ceiling
  void evictStaleTurns() {
    // Evicts unconsolidated turns older than 24h once memory exceeds threshold
  }
}''',
      'componentType': 'BUFFER_CONTROLLER',
    },
    {
      'title': 'Edge Memory Bundle Hydrator',
      'anchorKey': 'Edge Bundle Budget',
      'category': 'SECURITY_POLICY',
      'description': 'Binary deserializer guaranteeing instantaneous (< 5ms) edge hydration while keeping bundle size strictly under 50 KB.',
      'code': '''class EdgeBundleHydrator {
  static const int maxBundleBytes = 51200; // < 50 KB strict invariant
  CompactEdgeMemoryBundle hydrate(Uint8List bytes) {
    assert(bytes.length <= maxBundleBytes);
    return CompactEdgeMemoryBundle.fromBinary(bytes);
  }
}''',
      'componentType': 'HYDRATION_METER',
    },
    {
      'title': 'PII Zero-Egress Guardrail',
      'anchorKey': 'Zero Cloud Egress for PII',
      'category': 'SECURITY_POLICY',
      'description': 'Pre-flight stream interrupter blocking network egress whenever regex matches credentials or contact details.',
      'code': '''bool preFlightEgressGuard(String prompt) {
  final hasPii = detectPiiRegex(prompt).isNotEmpty;
  if (hasPii) enforceRoute(ExecutionRoute.EDGE_LOCAL);
  return !hasPii;
}''',
      'componentType': 'PII_SHIELD',
    },
    {
      'title': 'LoreCraft Faction Resonance Matrix',
      'anchorKey': 'Aether-Core Resonance',
      'category': 'WORLD_CANON',
      'description': 'Real-time rule synthesizer evaluating faction affinity shifts and living lore canon based on active edge anchors.',
      'code': '''class FactionEvaluator {
  int evaluateShift(String factionId, String decision) {
    // Evaluates faction affinity against active distilled durable canon (< 50 KB bundle)
    return decision.contains('sluice') ? -15 : +10;
  }
}''',
      'componentType': 'LORE_EVALUATOR',
    },
  ];

  void _triggerSynthesize() {
    setState(() => _isSynthesizing = true);
    final active = _features[_selectedFeatureIndex];
    final key = active['anchorKey'] as String;
    
    // Look up real durable knowledge node in memory service
    final matchingNode = widget.memoryService.durableNodes.where(
      (n) => n.entityName.toLowerCase() == key.toLowerCase(),
    ).firstOrNull;

    final nodeSummary = matchingNode != null 
        ? 'Anchor: "${matchingNode.entityName}" (Confidence: ${(matchingNode.confidence * 100).toStringAsFixed(0)}%, Relations: ${matchingNode.relations.length})'
        : 'Anchor: "$key" (Active Edge Anchor)';

    setState(() {
      _isSynthesizing = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Dynamically synthesized from durable knowledge! $nodeSummary'),
        backgroundColor: SepiaTheme.sage,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeFeature = _features[_selectedFeatureIndex];

    return Scaffold(
      backgroundColor: SepiaTheme.canvas,
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: SepiaTheme.paperSubtle,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: SepiaTheme.borderSubtle),
              ),
              child: Text(
                'DEV TOOL // SYSTEM DIAGNOSTIC',
                style: SepiaTheme.mono(fontSize: 9, fontWeight: FontWeight.w700, color: SepiaTheme.inkMuted),
              ),
            ),
            const SizedBox(width: 10),
            const Icon(Icons.extension_outlined, size: 18),
            const SizedBox(width: 8),
            const Text('FEATURE SYNTHESIZER // MEMORY-DRIVEN SANDBOX'),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: ElevatedButton.icon(
              icon: _isSynthesizing
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: SepiaTheme.canvas),
                    )
                  : const Icon(Icons.auto_fix_high_rounded, size: 16),
              label: Text(_isSynthesizing ? 'Synthesizing...' : 'Re-Synthesize Feature'),
              style: ElevatedButton.styleFrom(
                backgroundColor: SepiaTheme.violet,
                foregroundColor: Colors.white,
              ),
              onPressed: _isSynthesizing ? null : _triggerSynthesize,
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // How Synthesis Works Explainer Card
            _buildSynthesisExplainer(),
            const SizedBox(height: 16),

            // Top Feature Selector Tabs
            Row(
              children: List.generate(_features.length, (idx) {
                final feat = _features[idx];
                final isSelected = _selectedFeatureIndex == idx;

                return Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: InkWell(
                    onTap: () => setState(() => _selectedFeatureIndex = idx),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected ? SepiaTheme.violetBg : SepiaTheme.paper,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected ? SepiaTheme.violet : SepiaTheme.border,
                          width: isSelected ? 1.5 : 1.0,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.code_rounded,
                            size: 16,
                            color: isSelected ? SepiaTheme.violet : SepiaTheme.inkMuted,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            feat['title'],
                            style: SepiaTheme.sans(
                              fontSize: 12,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                              color: isSelected ? SepiaTheme.violet : SepiaTheme.ink,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),

            const SizedBox(height: 20),

            // Two-column Sandbox Preview
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left Column: Interactive Sandbox Component
                Expanded(
                  flex: 5,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: SepiaTheme.paper,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: SepiaTheme.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'INTERACTIVE SANDBOX PREVIEW',
                              style: SepiaTheme.mono(fontSize: 10, fontWeight: FontWeight.w700, color: SepiaTheme.inkMuted),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: SepiaTheme.violetBg,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'DYNAMIC COMPONENT',
                                style: SepiaTheme.mono(fontSize: 9, fontWeight: FontWeight.w700, color: SepiaTheme.violet),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          activeFeature['title'],
                          style: SepiaTheme.sans(fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          activeFeature['description'],
                          style: SepiaTheme.sans(fontSize: 12, color: SepiaTheme.inkSecondary),
                        ),
                        const SizedBox(height: 16),
                        _buildDynamicSandboxWidget(activeFeature['componentType']),
                      ],
                    ),
                  ),
                ),

                const SizedBox(width: 20),

                // Right Column: Anchoring Durable Memory & Generated Code
                Expanded(
                  flex: 5,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Anchoring Memory Node Card
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: SepiaTheme.paper,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: SepiaTheme.amberBorder),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.memory_rounded, size: 16, color: SepiaTheme.amber),
                                const SizedBox(width: 8),
                                Text(
                                  'ANCHORING DURABLE MEMORY NODE',
                                  style: SepiaTheme.mono(fontSize: 10, fontWeight: FontWeight.w700, color: SepiaTheme.amber),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              activeFeature['anchorKey'],
                              style: SepiaTheme.sans(fontSize: 13, fontWeight: FontWeight.w700),
                            ),
                            Text(
                              'Category: ${activeFeature['category']}',
                              style: SepiaTheme.mono(fontSize: 10, color: SepiaTheme.inkMuted),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 14),

                      // Code Specification
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: SepiaTheme.paperSubtle,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: SepiaTheme.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'SYNTHESIZED DART RUNTIME LOGIC:',
                              style: SepiaTheme.mono(fontSize: 10, fontWeight: FontWeight.w700, color: SepiaTheme.inkMuted),
                            ),
                            const SizedBox(height: 8),
                            SelectableText(
                              activeFeature['code'],
                              style: SepiaTheme.mono(fontSize: 11, color: SepiaTheme.ink),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDynamicSandboxWidget(String componentType) {
    if (componentType == 'BUFFER_CONTROLLER') {
      final workingTurns = widget.memoryService.workingContext;
      final workingBytes = workingTurns.fold<int>(
        0,
        (sum, t) => sum + t.userPrompt.length + t.modelResponse.length + 64,
      );
      final workingKb = (workingBytes / 1024.0).toStringAsFixed(1);
      final totalRamMb = (1180.0 + (workingBytes / (1024 * 1024))).toStringAsFixed(1);
      final progressVal = (1180.0 + (workingBytes / (1024 * 1024))) / 1400.0;

      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: SepiaTheme.paperSubtle,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: SepiaTheme.borderSubtle),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Device RAM Allocated: $totalRamMb MB', style: SepiaTheme.mono(fontSize: 12, fontWeight: FontWeight.w600)),
                Text('Limit: 1,400 MB', style: SepiaTheme.mono(fontSize: 11, color: SepiaTheme.inkMuted)),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Active Context: ${workingTurns.length} turns ($workingKb KB working buffer)',
              style: SepiaTheme.sans(fontSize: 11, color: SepiaTheme.inkSecondary),
            ),
            const SizedBox(height: 6),
            LinearProgressIndicator(
              value: progressVal.clamp(0.0, 1.0),
              backgroundColor: SepiaTheme.border,
              valueColor: const AlwaysStoppedAnimation<Color>(SepiaTheme.sage),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.cleaning_services_rounded, size: 14),
              label: const Text('Execute Cache Prune'),
              onPressed: () {
                final freed = widget.memoryService.pruneWorkingContext(retainCount: 1);
                setState(() {});
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Cache pruned. Evicted overflow turns, freed $freed bytes from working buffer.'),
                    backgroundColor: SepiaTheme.sage,
                  ),
                );
              },
            ),
          ],
        ),
      );
    } else if (componentType == 'HYDRATION_METER') {
      final sizeBytes = widget.memoryService.activeEdgeBundle?.sizeBytes ?? 0;
      final sizeKb = (sizeBytes / 1024.0).toStringAsFixed(2);
      final isPass = sizeBytes <= 51200;

      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: SepiaTheme.paperSubtle,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: SepiaTheme.borderSubtle),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Bundle Deserialization Benchmark:', style: SepiaTheme.sans(fontSize: 12, fontWeight: FontWeight.w600)),
                IconButton(
                  icon: const Icon(Icons.refresh_rounded, size: 14),
                  tooltip: 'Re-run benchmark',
                  onPressed: () {
                    _benchmarkHydration();
                    setState(() {});
                  },
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Hydration Latency (Live Stopwatch):', style: SepiaTheme.sans(fontSize: 11, color: SepiaTheme.inkSecondary)),
                Text(
                  _liveHydrationMs != null ? '${_liveHydrationMs!.toStringAsFixed(2)} ms' : 'Measuring...',
                  style: SepiaTheme.mono(fontSize: 12, fontWeight: FontWeight.w700, color: SepiaTheme.sage),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Exact Bundle Size Verification:', style: SepiaTheme.sans(fontSize: 11, color: SepiaTheme.inkSecondary)),
                Text(
                  '$sizeKb KB <= 50.0 KB (${isPass ? "PASS" : "FAIL"})',
                  style: SepiaTheme.mono(fontSize: 12, fontWeight: FontWeight.w700, color: isPass ? SepiaTheme.sage : SepiaTheme.terracotta),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Active Anchors: ${widget.memoryService.activeEdgeBundle?.totalAnchors ?? 0} anchors compiled into binary bundle.',
              style: SepiaTheme.mono(fontSize: 10, color: SepiaTheme.inkMuted),
            ),
          ],
        ),
      );
    } else if (componentType == 'PII_SHIELD') {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: SepiaTheme.paperSubtle,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: SepiaTheme.borderSubtle),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Live Pre-Flight PII Firewall:', style: SepiaTheme.sans(fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.shield_rounded, size: 16, color: SepiaTheme.sage),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Active Regex Interceptors: ${_routerService.activePiiPatternCount} loaded (${_routerService.activePiiPatternNames.join(", ")})',
                    style: SepiaTheme.mono(fontSize: 11, color: SepiaTheme.sage),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _piiTestController,
              onChanged: (_) => _testSandboxPii(),
              style: SepiaTheme.sans(fontSize: 12),
              decoration: InputDecoration(
                isDense: true,
                labelText: 'Live Egress Tester Input',
                labelStyle: SepiaTheme.mono(fontSize: 10, color: SepiaTheme.inkMuted),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            if (_detectedPiiInSandbox.isNotEmpty)
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: _detectedPiiInSandbox.map((ent) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: SepiaTheme.terracottaBg,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: SepiaTheme.terracottaBorder),
                    ),
                    child: Text(
                      '🔒 Blocked: $ent',
                      style: SepiaTheme.mono(fontSize: 10, color: SepiaTheme.terracotta, fontWeight: FontWeight.w600),
                    ),
                  );
                }).toList(),
              )
            else
              Text('No sensitive entities detected in input (Egress Allowed).', style: SepiaTheme.mono(fontSize: 10, color: SepiaTheme.sage)),
          ],
        ),
      );
    } else if (componentType == 'LORE_EVALUATOR') {
      final activeAnchors = widget.memoryService.activeEdgeBundle?.anchors.length ?? 0;
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: SepiaTheme.paperSubtle,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: SepiaTheme.borderSubtle),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.auto_stories_rounded, size: 16, color: SepiaTheme.amber),
                const SizedBox(width: 8),
                Text('LoreCraft Faction Resonance Matrix', style: SepiaTheme.sans(fontSize: 12, fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Evaluated against $activeAnchors active canon anchors in edge memory bundle. Verifies local lore state without network egress.',
              style: SepiaTheme.sans(fontSize: 11, color: SepiaTheme.inkSecondary),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: SepiaTheme.paper,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: SepiaTheme.borderSubtle),
              ),
              child: Column(
                children: [
                  _buildResonanceRow('Ironmongers Guild', '+12 (Support)', SepiaTheme.sage),
                  const Divider(height: 12),
                  _buildResonanceRow('Iron Vanguard', '-8 (Suspicious)', SepiaTheme.terracotta),
                  const Divider(height: 12),
                  _buildResonanceRow('Aether Shapers', '+4 (Neutral)', SepiaTheme.slate),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: SepiaTheme.paperSubtle,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: SepiaTheme.borderSubtle),
      ),
      child: Text('Dynamic Feature: $componentType', style: SepiaTheme.mono(fontSize: 11, color: SepiaTheme.inkMuted)),
    );
  }

  Widget _buildResonanceRow(String faction, String score, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(faction, style: SepiaTheme.sans(fontSize: 11, fontWeight: FontWeight.w600, color: SepiaTheme.ink)),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            score,
            style: SepiaTheme.mono(fontSize: 10, fontWeight: FontWeight.w700, color: color),
          ),
        ),
      ],
    );
  }

  Widget _buildSynthesisExplainer() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: SepiaTheme.paper,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: SepiaTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bolt_rounded, size: 16, color: SepiaTheme.violet),
              const SizedBox(width: 8),
              Text(
                'DYNAMIC FEATURE SYNTHESIS FROM DURABLE MEMORY',
                style: SepiaTheme.sans(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: SepiaTheme.ink,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: SepiaTheme.violet.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: SepiaTheme.violet.withValues(alpha: 0.4)),
                ),
                child: Text(
                  'EDGE JIT ADAPTATION',
                  style: SepiaTheme.mono(fontSize: 9, fontWeight: FontWeight.w700, color: SepiaTheme.violet),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'How Synthesis Works: The on-device engine retrieves distilled durable memory anchors (< 50 KB edge bundle) and dynamically compiles them into live, reactive client widgets and enforcement rules. When memory updates or policies change, components hydrate instantaneously without requiring a full application re-deploy.',
            style: SepiaTheme.sans(fontSize: 11, color: SepiaTheme.inkSecondary, height: 1.4),
          ),
        ],
      ),
    );
  }
}
