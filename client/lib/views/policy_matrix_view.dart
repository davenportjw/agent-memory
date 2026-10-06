import 'package:flutter/material.dart';
import '../models/routing_decision.dart';
import '../services/switching_router_service.dart';
import '../theme/sepia_theme.dart';

class PolicyMatrixView extends StatefulWidget {
  const PolicyMatrixView({super.key});

  @override
  State<PolicyMatrixView> createState() => _PolicyMatrixViewState();
}

class _PolicyMatrixViewState extends State<PolicyMatrixView> {
  final SwitchingRouterService _router = SwitchingRouterService();
  final TextEditingController _testPromptController = TextEditingController(
    text: 'Contact alice@example.org or call 555-0199 regarding SQLite caching before Friday.',
  );

  bool _simulateOffline = false;
  double _tokenSliderValue = 120;
  late RoutingEvaluationResult _evalResult;

  final List<Map<String, dynamic>> _policyRules = [
    {
      'id': 'RULE_STRICT_PRIVACY',
      'priority': 100,
      'route': 'EDGE_LOCAL',
      'condition': 'has_pii(prompt) == true || contains_confidential(prompt)',
      'intent': 'Local Privacy Intent: PII Sanitization & Task Extraction',
      'memory_action': 'Locally sanitized & stored in private working context. 0 KB egress.',
    },
    {
      'id': 'RULE_GAME_REACTIVE_BARK',
      'priority': 95,
      'route': 'EDGE_LOCAL',
      'condition': 'task_intent == NPC_REACTIVE_BARK && prompt_tokens < 512',
      'intent': 'LoreCraft Tactical Turn: Sub-60ms NPC Reactive Bark',
      'memory_action': 'Locally executed with distilled edge anchors; 0 KB egress.',
    },
    {
      'id': 'RULE_CIRCUIT_BREAKER_OFFLINE',
      'priority': 90,
      'route': 'EDGE_FALLBACK',
      'condition': 'network_status == OFFLINE || circuit_breaker == OPEN',
      'intent': 'Offline Fallback Intent: Degraded Tactical Answer',
      'memory_action': 'Turn queued in Local SQLite for batch offline reconciliation',
    },
    {
      'id': 'RULE_GAME_CAMPAIGN_SYNTHESIS',
      'priority': 85,
      'route': 'CLOUD_ESCALATE',
      'condition': 'task_intent == NARRATIVE_CONSEQUENCE || conflict_detected == true',
      'intent': 'LoreCraft Campaign Synthesis: Cross-Faction Canon Arbitration',
      'memory_action': 'Dispatched to Cloud Run Gemini 3.8 Flash for multi-hop memory reconciliation.',
    },
    {
      'id': 'RULE_CONTEXT_LIMIT_EXCEEDED',
      'priority': 80,
      'route': 'CLOUD_ESCALATE',
      'condition': 'prompt_token_count > 4096',
      'intent': 'Cloud Long-Context Intent: Extended Token Capacity',
      'memory_action': 'Dispatched to Cloud Ingestion Queue with PII scrubbed',
    },
    {
      'id': 'RULE_COMPLEXITY_ESCALATION',
      'priority': 70,
      'route': 'CLOUD_ESCALATE',
      'condition': 'task_intent in [MULTI_HOP, TEMPORAL_SYNTHESIS, CODE_REFACTOR, CONTRADICTION]',
      'intent': 'Cloud Synthesis Intent: Cross-Session Architecture Alignment',
      'memory_action': 'Recalled durable memory anchors injected; queued for cloud consolidation',
    },
    {
      'id': 'RULE_EDGE_DEFAULT_FAST',
      'priority': 10,
      'route': 'EDGE_LOCAL',
      'condition': 'bounded single-turn within edge capacity',
      'intent': 'Local Edge Fast Intent: Zero-Latency Execution',
      'memory_action': 'Committed to local SQLite working context cache',
    },
  ];

  @override
  void initState() {
    super.initState();
    _recalculate();
  }

  void _recalculate() {
    _evalResult = _router.evaluateRoute(
      prompt: _testPromptController.text,
      estimatedTokens: _tokenSliderValue.toInt(),
      isNetworkOnline: !_simulateOffline,
    );
  }

  @override
  Widget build(BuildContext context) {
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
            const Icon(Icons.rule_rounded, size: 18),
            const SizedBox(width: 8),
            const Text('DECLARATIVE SWITCHING POLICY MATRIX'),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // How Redaction & Routing Work
            _buildRoutingAndRedactionExplainer(),
            const SizedBox(height: 16),

            // Interactive Policy Sandbox
            _buildInteractiveSandboxCard(),

            const SizedBox(height: 20),

            // Declarative Rules Table
            Text(
              'DECLARATIVE ROUTING RULES (PRIORITY ORDER):',
              style: SepiaTheme.mono(fontSize: 11, fontWeight: FontWeight.w700, color: SepiaTheme.inkMuted),
            ),
            const SizedBox(height: 10),
            ..._policyRules.map((r) => _buildRuleCard(r)),

            const SizedBox(height: 20),

            // PII Patterns Viewer
            Text(
              'ON-DEVICE PII REGEX DETECTORS:',
              style: SepiaTheme.mono(fontSize: 11, fontWeight: FontWeight.w700, color: SepiaTheme.inkMuted),
            ),
            const SizedBox(height: 10),
            _buildPiiRegexCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildRoutingAndRedactionExplainer() {
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
              const Icon(Icons.security_rounded, size: 16, color: SepiaTheme.terracotta),
              const SizedBox(width: 8),
              Text(
                'PII REDACTION & SWITCHING ROUTER MECHANICS',
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
                  color: SepiaTheme.sage.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: SepiaTheme.sage.withValues(alpha: 0.4)),
                ),
                child: Text(
                  '0 KB EGRESS ENFORCED',
                  style: SepiaTheme.mono(fontSize: 9, fontWeight: FontWeight.w700, color: SepiaTheme.sage),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 800;
              final steps = [
                _buildExplainerStep(
                  step: '1. Pattern Detection',
                  summary: 'Local regex engine tests incoming text for emails, phone numbers, and auth tokens with 0ms overhead.',
                  accentColor: SepiaTheme.slate,
                ),
                _buildExplainerStep(
                  step: '2. On-Device Masking',
                  summary: 'Matches are masked locally ([REDACTED_EMAIL], [REDACTED_PHONE]) before context retention.',
                  accentColor: SepiaTheme.amber,
                ),
                _buildExplainerStep(
                  step: '3. Route Lock Invariant',
                  summary: 'RULE_STRICT_PRIVACY (Priority 100) locks execution to EDGE_LOCAL. Network requests are physically aborted.',
                  accentColor: SepiaTheme.terracotta,
                ),
                _buildExplainerStep(
                  step: '4. Cloud Synthesis Escalation',
                  summary: 'Only sanitized turns and complex reasoning tasks (multi-hop, contradiction resolution) escalate to Gemini 3.8 Flash.',
                  accentColor: SepiaTheme.sage,
                ),
              ];

              if (isWide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: steps.map((s) => Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: s))).toList(),
                );
              }
              return Column(
                children: steps.map((s) => Padding(padding: const EdgeInsets.only(bottom: 6), child: s)).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildExplainerStep({
    required String step,
    required String summary,
    required Color accentColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: SepiaTheme.paperSubtle,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: SepiaTheme.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 6, height: 6, decoration: BoxDecoration(color: accentColor, shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  step,
                  style: SepiaTheme.sans(fontSize: 10, fontWeight: FontWeight.w700, color: SepiaTheme.ink),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            summary,
            style: SepiaTheme.sans(fontSize: 10, color: SepiaTheme.inkSecondary, height: 1.3),
          ),
        ],
      ),
    );
  }

  Widget _buildInteractiveSandboxCard() {
    return Container(
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
            children: [
              const Icon(Icons.science_outlined, size: 16, color: SepiaTheme.ink),
              const SizedBox(width: 8),
              Text(
                'LIVE POLICY SANDBOX TESTER',
                style: SepiaTheme.mono(fontSize: 11, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _testPromptController,
            maxLines: 2,
            style: SepiaTheme.sans(fontSize: 13),
            decoration: const InputDecoration(
              labelText: 'Test Input Prompt (type emails, phones, API keys, or synthesis queries)',
            ),
            onChanged: (_) => setState(() => _recalculate()),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Text(
                      'Context Volume: ${_tokenSliderValue.toInt()} tokens',
                      style: SepiaTheme.mono(fontSize: 11, color: SepiaTheme.inkSecondary),
                    ),
                    Expanded(
                      child: Slider(
                        value: _tokenSliderValue,
                        min: 50,
                        max: 6000,
                        divisions: 50,
                        activeColor: SepiaTheme.ink,
                        onChanged: (val) {
                          setState(() {
                            _tokenSliderValue = val;
                            _recalculate();
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Row(
                children: [
                  Checkbox(
                    value: _simulateOffline,
                    activeColor: SepiaTheme.terracotta,
                    onChanged: (val) {
                      setState(() {
                        _simulateOffline = val ?? false;
                        _recalculate();
                      });
                    },
                  ),
                  Text('Simulate Offline Network', style: SepiaTheme.sans(fontSize: 12)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Evaluation Output Banner
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _evalResult.route.key == 'EDGE_LOCAL'
                  ? SepiaTheme.sageBg
                  : _evalResult.route.key == 'CLOUD_ESCALATE'
                      ? SepiaTheme.amberBg
                      : SepiaTheme.terracottaBg,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: _evalResult.route.key == 'EDGE_LOCAL'
                    ? SepiaTheme.sageBorder
                    : _evalResult.route.key == 'CLOUD_ESCALATE'
                        ? SepiaTheme.amberBorder
                        : SepiaTheme.terracottaBorder,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _evalResult.route.key == 'EDGE_LOCAL'
                      ? Icons.check_circle_outline
                      : Icons.arrow_forward_rounded,
                  color: _evalResult.route.key == 'EDGE_LOCAL' ? SepiaTheme.sage : SepiaTheme.amber,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'EVALUATION VERDICT: ${_evalResult.route.key} via ${_evalResult.ruleId}',
                        style: SepiaTheme.mono(fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Intent: ${_evalResult.intentLabel}',
                        style: SepiaTheme.sans(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                      Text(
                        'Justification: ${_evalResult.justification}',
                        style: SepiaTheme.sans(fontSize: 11, color: SepiaTheme.inkSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRuleCard(Map<String, dynamic> rule) {
    final isMatching = _evalResult.ruleId == rule['id'];

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isMatching ? SepiaTheme.paperSubtle : SepiaTheme.paper,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isMatching ? SepiaTheme.ink : SepiaTheme.border,
          width: isMatching ? 2.0 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: SepiaTheme.paperSubtle,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: SepiaTheme.border),
                    ),
                    child: Text(
                      'Priority ${rule['priority']}',
                      style: SepiaTheme.mono(fontSize: 10, fontWeight: FontWeight.w700, color: SepiaTheme.ink),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    rule['id'],
                    style: SepiaTheme.mono(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                  if (isMatching) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: SepiaTheme.sageBg,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'ACTIVE MATCH',
                        style: SepiaTheme.mono(fontSize: 9, fontWeight: FontWeight.w700, color: SepiaTheme.sage),
                      ),
                    ),
                  ],
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: rule['route'] == 'EDGE_LOCAL'
                      ? SepiaTheme.sageBg
                      : rule['route'] == 'CLOUD_ESCALATE'
                          ? SepiaTheme.amberBg
                          : SepiaTheme.terracottaBg,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  rule['route'],
                  style: SepiaTheme.mono(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: rule['route'] == 'EDGE_LOCAL'
                        ? SepiaTheme.sage
                        : rule['route'] == 'CLOUD_ESCALATE'
                            ? SepiaTheme.amber
                            : SepiaTheme.terracotta,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Condition: ${rule['condition']}',
            style: SepiaTheme.mono(fontSize: 11, color: SepiaTheme.inkSecondary),
          ),
          const SizedBox(height: 4),
          Text(
            'Memory Delta: ${rule['memory_action']}',
            style: SepiaTheme.sans(fontSize: 11, color: SepiaTheme.inkMuted),
          ),
        ],
      ),
    );
  }

  Widget _buildPiiRegexCard() {
    final patterns = [
      {'name': 'Email Address', 'pattern': r'[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}', 'example': 'alice@example.org'},
      {'name': 'US Phone Number', 'pattern': r'\b(?:\+?1[-.]?)?\(?([0-9]{3})\)?[-. ]?([0-9]{3})[-. ]?([0-9]{4})\b', 'example': '555-0199'},
      {'name': 'Social Security Number', 'pattern': r'\b\d{3}-\d{2}-\d{4}\b', 'example': '000-12-3456'},
      {'name': 'Credit Card', 'pattern': r'\b(?:4[0-9]{12}(?:[0-9]{3})?|5[1-5][0-9]{14}|3[47][0-9]{13})\b', 'example': '4111222233334444'},
      {'name': 'API Key / Secret', 'pattern': r'\b(?:AIza[0-9A-Za-z-_]{35}|sk-[a-zA-Z0-9]{32,})\b', 'example': 'AIzaSyD...'},
    ];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: SepiaTheme.paper,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: SepiaTheme.border),
      ),
      child: Column(
        children: patterns.map((p) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                SizedBox(
                  width: 160,
                  child: Text(p['name']!, style: SepiaTheme.sans(fontSize: 12, fontWeight: FontWeight.w600)),
                ),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: SepiaTheme.paperSubtle,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: SepiaTheme.borderSubtle),
                    ),
                    child: Text(p['pattern']!, style: SepiaTheme.mono(fontSize: 10, color: SepiaTheme.inkSecondary)),
                  ),
                ),
                const SizedBox(width: 8),
                Text('e.g. ${p['example']}', style: SepiaTheme.mono(fontSize: 10, color: SepiaTheme.inkMuted)),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}
