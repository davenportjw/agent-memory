import 'package:flutter/material.dart';
import '../../models/routing_decision.dart';
import '../../services/lorecraft_service.dart';
import '../../services/switching_router_service.dart';
import '../../theme/sepia_theme.dart';

/// LoreCraftForesightPill provides pre-flight routing foresight above the prompt input.
/// Complies with UI Clarity & TDD: dynamically responds to user typing and opens the
/// Firebase AI Routing Dossier bottom sheet on tap (zero false affordances).
class LoreCraftForesightPill extends StatefulWidget {
  final TextEditingController promptController;
  final LoreCraftService loreService;

  const LoreCraftForesightPill({
    super.key,
    required this.promptController,
    required this.loreService,
  });

  @override
  State<LoreCraftForesightPill> createState() => _LoreCraftForesightPillState();
}

class _LoreCraftForesightPillState extends State<LoreCraftForesightPill> {
  late RoutingEvaluationResult _currentEval;

  @override
  void initState() {
    super.initState();
    _currentEval = widget.loreService.previewRoute(widget.promptController.text);
    widget.promptController.addListener(_onTextChanged);
    widget.loreService.addListener(_onServiceChanged);
  }

  @override
  void dispose() {
    widget.promptController.removeListener(_onTextChanged);
    widget.loreService.removeListener(_onServiceChanged);
    super.dispose();
  }

  String get _modelTarget {
    if (_currentEval.ruleId == 'RULE_GAME_VISUAL_SYNTHESIS') {
      return 'Nano Banana 2 Lite (Cloud Run)';
    }
    if (_currentEval.route == ExecutionRoute.CLOUD_ESCALATE) {
      return 'Gemini 3.8 Flash (Vertex AI)';
    }
    return 'Gemma 4 int4 (On-Device WebGPU/Metal)';
  }

  void _onTextChanged() {
    final updated = widget.loreService.previewRoute(widget.promptController.text);
    if (updated.route != _currentEval.route ||
        updated.ruleId != _currentEval.ruleId ||
        updated.intentLabel != _currentEval.intentLabel) {
      setState(() {
        _currentEval = updated;
      });
    }
  }

  void _onServiceChanged() {
    final updated = widget.loreService.previewRoute(widget.promptController.text);
    setState(() {
      _currentEval = updated;
    });
  }

  void _showRoutingDossier(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: SepiaTheme.paper,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        side: BorderSide(color: SepiaTheme.border, width: 1.5),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 16,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: SepiaTheme.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        const Icon(Icons.security, size: 20, color: SepiaTheme.amber),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'Firebase AI Routing Dossier',
                            style: SepiaTheme.sans(fontSize: 16, fontWeight: FontWeight.w700, color: SepiaTheme.ink),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _getBadgeBgColor(),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: _getBadgeBorderColor()),
                    ),
                    child: Text(
                      _currentEval.route.name,
                      style: SepiaTheme.mono(fontSize: 10, fontWeight: FontWeight.w700, color: _getBadgeTextColor()),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildDossierRow('Target Execution Route', _currentEval.route.name, Icons.alt_route),
              _buildDossierRow('Policy Engine', '${_currentEval.policySource} (${_currentEval.policyVersion})', Icons.cloud_sync),
              _buildDossierRow('Triggered Policy Rule', _currentEval.ruleId, Icons.rule),
              _buildDossierRow('Target Model Engine', _modelTarget, Icons.memory),
              _buildDossierRow('Memory Destination', _currentEval.memoryDelta, Icons.storage),
              _buildDossierRow('Policy Rationale', _currentEval.justification, Icons.info_outline),
              const SizedBox(height: 12),
              const Divider(color: SepiaTheme.border, height: 1),
              const SizedBox(height: 12),
              Text(
                'QUICK ROUTE BENCHMARK PROBES',
                style: SepiaTheme.sans(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: SepiaTheme.inkMuted,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildBenchmarkProbeChip(
                    ctx,
                    label: "Bark: Steel Billets",
                    prompt: "Inspect available high-carbon steel billets",
                    tag: "Gemma 4 Edge (50ms)",
                    tagColor: SepiaTheme.sage,
                    tagBg: SepiaTheme.sageBg,
                  ),
                  _buildBenchmarkProbeChip(
                    ctx,
                    label: "Visual: Forge Aegis",
                    prompt: "Generate concept art of the Forge Commander's Aegis",
                    tag: "Nano Banana 2 Lite (~1.2s)",
                    tagColor: SepiaTheme.azure,
                    tagBg: SepiaTheme.azureBg,
                  ),
                  _buildBenchmarkProbeChip(
                    ctx,
                    label: "Escalate: Syndicate Seizure",
                    prompt: "Synthesize the political consequences if the Syndicate seizes the docks",
                    tag: "Cloud Flash (Multi-hop)",
                    tagColor: SepiaTheme.amber,
                    tagBg: SepiaTheme.amberBg,
                  ),
                ],
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: SepiaTheme.inkSecondary,
                    side: const BorderSide(color: SepiaTheme.border),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBenchmarkProbeChip(
    BuildContext modalContext, {
    required String label,
    required String prompt,
    required String tag,
    required Color tagColor,
    required Color tagBg,
  }) {
    return InkWell(
      onTap: () {
        widget.promptController.text = prompt;
        Navigator.of(modalContext).pop();
      },
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: SepiaTheme.paperSubtle,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: SepiaTheme.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: SepiaTheme.sans(fontSize: 11, fontWeight: FontWeight.w600, color: SepiaTheme.ink)),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: tagBg,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                tag,
                style: SepiaTheme.sans(fontSize: 9, fontWeight: FontWeight.w700, color: tagColor),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDossierRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: SepiaTheme.inkMuted),
          const SizedBox(width: 8),
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: SepiaTheme.sans(fontSize: 12, fontWeight: FontWeight.w600, color: SepiaTheme.inkSecondary),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: SepiaTheme.mono(fontSize: 11, color: SepiaTheme.ink),
            ),
          ),
        ],
      ),
    );
  }

  Color _getBadgeBgColor() {
    if (_currentEval.ruleId == 'RULE_STRICT_PRIVACY') return SepiaTheme.sageBg;
    if (_currentEval.ruleId == 'RULE_GAME_VISUAL_SYNTHESIS') return SepiaTheme.azureBg;
    if (_currentEval.route == ExecutionRoute.CLOUD_ESCALATE) return SepiaTheme.amberBg;
    return SepiaTheme.slateBg;
  }

  Color _getBadgeBorderColor() {
    if (_currentEval.ruleId == 'RULE_STRICT_PRIVACY') return SepiaTheme.sageBorder;
    if (_currentEval.ruleId == 'RULE_GAME_VISUAL_SYNTHESIS') return SepiaTheme.azureBorder;
    if (_currentEval.route == ExecutionRoute.CLOUD_ESCALATE) return SepiaTheme.amberBorder;
    return SepiaTheme.slateBorder;
  }

  Color _getBadgeTextColor() {
    if (_currentEval.ruleId == 'RULE_STRICT_PRIVACY') return SepiaTheme.sage;
    if (_currentEval.ruleId == 'RULE_GAME_VISUAL_SYNTHESIS') return SepiaTheme.azure;
    if (_currentEval.route == ExecutionRoute.CLOUD_ESCALATE) return SepiaTheme.amber;
    return SepiaTheme.slate;
  }

  String _getPillText() {
    if (_currentEval.ruleId == 'RULE_STRICT_PRIVACY') {
      return '🔒 Local Privacy Guard • 0 KB Egress';
    }
    if (_currentEval.ruleId == 'RULE_GAME_VISUAL_SYNTHESIS') {
      return '🎨 Offloading to Nano Banana 2 Lite (~1.2s) • Visual Blueprint';
    }
    if (_currentEval.route == ExecutionRoute.CLOUD_ESCALATE) {
      return '☁️ Escalating to Gemini 3.8 Flash • Campaign Synthesis';
    }
    return '⚡ On-Device Gemma 4 (<60ms) • Local Dialogue';
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _showRoutingDossier(context),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: _getBadgeBgColor(),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: _getBadgeBorderColor()),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _getPillText(),
              style: SepiaTheme.sans(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: _getBadgeTextColor(),
              ),
            ),
            const SizedBox(width: 6),
            Icon(Icons.touch_app_outlined, size: 12, color: _getBadgeTextColor().withValues(alpha: 0.8)),
          ],
        ),
      ),
    );
  }
}
