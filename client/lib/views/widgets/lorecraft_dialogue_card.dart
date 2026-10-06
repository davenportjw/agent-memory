import 'package:flutter/material.dart';
import '../../models/lorecraft_state.dart';
import '../../models/routing_decision.dart';
import '../../models/a2ui_models.dart';
import '../../theme/sepia_theme.dart';
import '../../utils/a2ui_extractor.dart';
import '../../services/app_mode_service.dart';
import 'a2ui_surface_view.dart';

class LoreCraftDialogueCard extends StatelessWidget {
  final LoreDialogueTurn turn;
  final VoidCallback? onInspectTelemetry;
  final void Function(A2UIAction action)? onA2UIAction;
  final bool isCloudGenerating;
  final String? cloudGeneratingStatus;

  final bool hideTextIfGenerativeUi;

  const LoreCraftDialogueCard({
    super.key,
    required this.turn,
    this.onInspectTelemetry,
    this.onA2UIAction,
    this.isCloudGenerating = false,
    this.cloudGeneratingStatus,
    this.hideTextIfGenerativeUi = true,
  });

  @override
  Widget build(BuildContext context) {
    final isNpc = turn.isNpc;
    final isCloud = turn.route == ExecutionRoute.CLOUD_ESCALATE ||
        turn.modelName.contains('Nano Banana') ||
        turn.modelName.contains('Gemini');

    // Extract any embedded A2UI payload (dynamic choices or surface JSON) and clean speech text
    final extracted = A2UIExtractor.extract(
      rawText: turn.speechText,
      existingStageCue: turn.stageCue.isNotEmpty ? turn.stageCue : null,
      surfaceIdPrefix: 'a2ui-${turn.id}',
    );

    final effectiveSurface = turn.a2uiSurface ?? extracted.surface;
    final effectiveStageCue = turn.stageCue.isNotEmpty
        ? turn.stageCue
        : (extracted.extractedStageCue ?? '');
    final effectiveSpeech = extracted.cleanSpeechText;

    final surfaceHasSpokenText = effectiveSurface?.components
            .any((c) => c.id == 'spoken_text' && (c.properties['text']?.toString().isNotEmpty ?? false)) ??
        false;

    final surfaceHasStageCue = effectiveSurface?.components
            .any((c) => (c.id == 'stage_cue' || c.id == 'cue_text') && (c.properties['text']?.toString().isNotEmpty ?? false)) ??
        false;

    final shouldShowStageCue = effectiveStageCue.isNotEmpty && !surfaceHasStageCue;

    final shouldShowSpeechText = effectiveSpeech.isNotEmpty &&
        (!hideTextIfGenerativeUi || effectiveSurface == null || !surfaceHasSpokenText);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: isNpc ? MainAxisAlignment.start : MainAxisAlignment.end,
        children: [
          if (isNpc) ...[
            _buildAvatar(context, isCloud),
            const SizedBox(width: 12),
          ],
          Flexible(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 720),
              decoration: BoxDecoration(
                color: isNpc
                    ? (isCloud ? SepiaTheme.paper : SepiaTheme.paper)
                    : SepiaTheme.paperSubtle,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isNpc
                      ? (isCloud
                          ? SepiaTheme.azureBorder
                          : SepiaTheme.border)
                      : SepiaTheme.amber.withValues(alpha: 0.4),
                  width: isCloud ? 1.5 : 1.0,
                ),
                boxShadow: isNpc
                    ? [
                        BoxShadow(
                          color: isCloud
                              ? SepiaTheme.azure.withValues(alpha: 0.06)
                              : Colors.black.withValues(alpha: 0.03),
                          offset: const Offset(0, 2),
                          blurRadius: isCloud ? 6 : 4,
                        ),
                      ]
                    : null,
              ),
              padding: const EdgeInsets.all(14.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Speaker Header + Execution Model Badge
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          turn.speakerName,
                          style: SepiaTheme.sans(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: isNpc
                                ? (isCloud ? SepiaTheme.azure : SepiaTheme.ink)
                                : SepiaTheme.amber,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (turn.isNpc) _buildTelemetryAffordance(context),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // Stage Cue (Gestures / Actions) - Always visible for immersive roleplay
                  if (shouldShowStageCue)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6.0),
                      child: Text(
                        effectiveStageCue,
                        style: SepiaTheme.sans(
                          fontSize: 12.5,
                          fontStyle: FontStyle.italic,
                          color: SepiaTheme.inkMuted,
                          height: 1.3,
                        ),
                      ),
                    ),

                  // Speech Text - Displays clean narrative speech text (excluding raw JSON code blocks)
                  if (shouldShowSpeechText)
                    SelectableText(
                      effectiveSpeech,
                      style: SepiaTheme.sans(
                        fontSize: 14,
                        color: SepiaTheme.ink,
                        height: 1.45,
                      ),
                    )
                  else if (turn.isStreaming)
                    Row(
                      children: [
                        SizedBox(
                          width: 13,
                          height: 13,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: isCloud ? SepiaTheme.azure : SepiaTheme.sage,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isCloud
                              ? 'Cloud synthesis streaming...'
                              : 'Local edge generation...',
                          style: SepiaTheme.sans(
                            fontSize: 13,
                            fontStyle: FontStyle.italic,
                            color: SepiaTheme.inkMuted,
                          ),
                        ),
                      ],
                    ),

                  // A2UI Declarative Dynamic Surface
                  if (effectiveSurface != null) ...[
                    const SizedBox(height: 10),
                    A2UISurfaceView(
                      surface: effectiveSurface,
                      onAction: onA2UIAction,
                      isCloudGenerating: isCloudGenerating,
                      cloudGeneratingStatus: cloudGeneratingStatus,
                    ),
                  ],

                  // Fallback warning if triggered
                  if (turn.isFallback && turn.fallbackReason != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        '⚠️ Fallback: ${turn.fallbackReason}',
                        style: SepiaTheme.sans(fontSize: 11, color: SepiaTheme.terracotta),
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (!isNpc) ...[
            const SizedBox(width: 12),
            _buildPlayerAvatar(),
          ],
        ],
      ),
    );
  }

  Widget _buildAvatar(BuildContext context, bool isCloud) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: isCloud ? SepiaTheme.azureBg : SepiaTheme.paperSubtle,
        shape: BoxShape.circle,
        border: Border.all(
          color: isCloud ? SepiaTheme.azureBorder : SepiaTheme.border,
          width: 1.5,
        ),
      ),
      child: Icon(
        isCloud ? Icons.cloud_done : Icons.person,
        color: isCloud ? SepiaTheme.azure : SepiaTheme.ink,
        size: 20,
      ),
    );
  }

  Widget _buildPlayerAvatar() {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: SepiaTheme.amber.withValues(alpha: 0.15),
        shape: BoxShape.circle,
        border: Border.all(color: SepiaTheme.amber, width: 1.5),
      ),
      child: const Icon(Icons.navigation_outlined, color: SepiaTheme.amber, size: 20),
    );
  }

  Widget _buildTelemetryAffordance(BuildContext context) {
    final isEdge = turn.route == ExecutionRoute.EDGE_LOCAL || turn.route == ExecutionRoute.EDGE_FALLBACK;
    final isVisual = turn.modelName.contains('Nano Banana');

    final badgeColor = isVisual
        ? SepiaTheme.azure
        : (isEdge ? SepiaTheme.sage : SepiaTheme.amber);
    final badgeBg = isVisual
        ? SepiaTheme.azureBg
        : (isEdge ? SepiaTheme.sageBg : SepiaTheme.amberBg);
    final badgeBorder = isVisual
        ? SepiaTheme.azureBorder
        : (isEdge ? SepiaTheme.sageBorder : SepiaTheme.amberBorder);

    final badgeText = turn.isDynamicallyEscalated
        ? '☁️ DYNAMIC ESCALATION • ${turn.modelName} • ${turn.latencyMs}ms'
        : (isVisual
            ? '☁️ CLOUD ESCALATED • Nano Banana 2 Lite • ${turn.latencyMs}ms'
            : (isEdge
                ? '⚡ LOCAL EDGE • 0.0 KB Egress • ${turn.ttftMs > 0 ? '${turn.ttftMs}ms' : '< 60ms'}'
                : '☁️ CLOUD ESCALATED • Gemini 3.8 Flash • ${turn.latencyMs}ms'));

    final isSimple = AppModeService().isSimple;
    return InkWell(
      onTap: onInspectTelemetry ??
          () {
            showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                backgroundColor: SepiaTheme.paper,
                title: Row(
                  children: [
                    Icon(
                      isVisual
                          ? Icons.auto_awesome
                          : (isEdge ? Icons.bolt : Icons.cloud_outlined),
                      color: badgeColor,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Dialogue Frame Telemetry',
                      style: SepiaTheme.sans(fontWeight: FontWeight.w700, fontSize: 16),
                    ),
                  ],
                ),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: isSimple
                        ? [
                            _metricRow('Execution Route', isEdge ? '⚡ Local Edge (On-Device)' : '☁️ Cloud Escalated (Remote)'),
                            _metricRow('Model Engine', turn.modelName),
                            _metricRow('Time to First Token (TTFT)', '${turn.ttftMs} ms'),
                            _metricRow('Total Latency', '${turn.latencyMs} ms'),
                            _metricRow('Cloud Egress', isEdge ? '0.0 KB (Zero egress, 100% private)' : '${turn.egressBytes} bytes'),
                            _metricRow(
                              'Frame Budget Status',
                              isVisual
                                  ? 'Cloud Visual Task (~1.2s)'
                                  : (turn.fpsCompliant ? 'Compliant (< 100ms)' : 'Exceeded (> 100ms)'),
                            ),
                            if (turn.memoryDelta != null)
                              _metricRow('Memory Delta', turn.memoryDelta!),
                            if (turn.routeJustification != null)
                              _metricRow('Routing Reason', turn.routeJustification!),
                          ]
                        : [
                            _metricRow('Execution Route', turn.route.name),
                            if (turn.personaModelName != null)
                              _metricRow('Persona Model (Talking)', turn.personaModelName!),
                            if (turn.arbiterModelName != null)
                              _metricRow('Game Master Arbiter', turn.arbiterModelName!),
                            if (turn.gameMasterCommentary != null)
                              _metricRow('Arbiter Commentary', turn.gameMasterCommentary!),
                            if (turn.ruleId != null)
                              _metricRow('Firebase AI Policy', turn.ruleId!),
                            if (turn.routeJustification != null)
                              _metricRow('Escalation Reason', turn.routeJustification!),
                            if (turn.memoryDelta != null)
                              _metricRow('Memory Delta', turn.memoryDelta!),
                            _metricRow('Model Engine', turn.modelName),
                            _metricRow('Time to First Token (TTFT)', '${turn.ttftMs} ms'),
                            _metricRow('Total Latency', '${turn.latencyMs} ms'),
                            _metricRow('Cloud Egress', '${turn.egressBytes} bytes'),
                            _metricRow(
                              'Frame Budget Status',
                              isVisual
                                  ? 'Cloud Visual Task (~1.2s)'
                                  : (turn.fpsCompliant ? 'Compliant (< 100ms)' : 'Exceeded (> 100ms)'),
                            ),
                          ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: Text(
                      'Close',
                      style: SepiaTheme.sans(color: SepiaTheme.ink, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            );
          },
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: badgeBg,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: badgeBorder),
        ),
        child: Text(
          badgeText,
          style: SepiaTheme.mono(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: badgeColor,
          ),
        ),
      ),
    );
  }

  static Widget _metricRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(label, style: SepiaTheme.sans(fontSize: 12, color: SepiaTheme.inkMuted)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: SepiaTheme.mono(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: SepiaTheme.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
