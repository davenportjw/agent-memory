import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../models/a2ui_models.dart';
import '../../theme/sepia_theme.dart';

/// A2UISurfaceView dynamically renders declarative A2UI components
/// conforming to the static lorecraft_catalog.json specification.
class A2UISurfaceView extends StatefulWidget {
  final A2UISurface surface;
  final void Function(A2UIAction action)? onAction;
  final bool isCloudGenerating;
  final String? cloudGeneratingStatus;

  const A2UISurfaceView({
    super.key,
    required this.surface,
    this.onAction,
    this.isCloudGenerating = false,
    this.cloudGeneratingStatus,
  });

  @override
  State<A2UISurfaceView> createState() => _A2UISurfaceViewState();
}

class _A2UISurfaceViewState extends State<A2UISurfaceView> {
  final Map<String, double> _sliderValues = {};
  String? _selectedChoiceId;

  @override
  Widget build(BuildContext context) {
    if (widget.surface.components.isEmpty) {
      return const SizedBox.shrink();
    }

    final root = widget.surface.rootComponent;
    if (root != null) {
      return _renderComponent(root);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: widget.surface.components.map(_renderComponent).toList(),
    );
  }

  Widget _renderComponent(A2UIComponent comp) {
    switch (comp.type) {
      case 'Card':
        return _renderCard(comp);
      case 'Text':
        return _renderText(comp);
      case 'Badge':
        return _renderBadge(comp);
      case 'Button':
        return _renderButton(comp);
      case 'ChoiceGroup':
        return _renderChoiceGroup(comp);
      case 'Slider':
        return _renderSlider(comp);
      case 'ImageCanvas':
        return _renderImageCanvas(comp);
      case 'Divider':
        return _renderDivider(comp);
      case 'Row':
        return _renderRow(comp);
      case 'Column':
        return _renderColumn(comp);
      default:
        return _renderFallback(comp);
    }
  }

  Widget _renderCard(A2UIComponent comp) {
    final variant = comp.properties['variant'] as String? ?? 'default';
    final paddingVal = (comp.properties['padding'] as num?)?.toDouble() ?? 12.0;

    Color bgColor = SepiaTheme.paper;
    Border? border = Border.all(color: SepiaTheme.border);
    List<BoxShadow>? shadows;

    if (variant == 'edge_accent') {
      bgColor = SepiaTheme.sageBg.withValues(alpha: 0.25);
      border = Border.all(color: SepiaTheme.sageBorder, width: 1.5);
    } else if (variant == 'cloud_accent') {
      bgColor = SepiaTheme.azureBg.withValues(alpha: 0.35);
      border = Border.all(color: SepiaTheme.azureBorder, width: 1.5);
      shadows = [
        BoxShadow(
          color: SepiaTheme.azure.withValues(alpha: 0.08),
          blurRadius: 10,
          offset: const Offset(0, 3),
        ),
      ];
    } else if (variant == 'elevated') {
      shadows = [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.05),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ];
    }

    final children = comp.childrenIds
        .map((id) => widget.surface.findComponent(id))
        .whereType<A2UIComponent>()
        .map(_renderComponent)
        .toList();

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: EdgeInsets.all(paddingVal),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: border,
        boxShadow: shadows,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children.isEmpty
            ? [const SizedBox.shrink()]
            : _joinWithSpacing(children, 8),
      ),
    );
  }

  Widget _renderText(A2UIComponent comp) {
    final text = comp.properties['text'] as String? ?? '';
    final variant = comp.properties['variant'] as String? ?? 'body';
    final colorStr = comp.properties['color'] as String? ?? 'default';

    Color textColor = SepiaTheme.ink;
    if (colorStr == 'muted') textColor = SepiaTheme.inkMuted;
    if (colorStr == 'edge') textColor = SepiaTheme.sage;
    if (colorStr == 'cloud') textColor = SepiaTheme.azure;

    if (variant == 'stage_cue') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: SepiaTheme.canvas,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: SepiaTheme.borderSubtle),
        ),
        child: Row(
          children: [
            const Icon(Icons.theater_comedy, size: 14, color: SepiaTheme.inkMuted),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                text,
                style: SepiaTheme.sans(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  color: SepiaTheme.inkMuted,
                  height: 1.3,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (variant == 'heading') {
      return Text(
        text,
        style: SepiaTheme.sans(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: textColor,
        ),
      );
    }

    if (variant == 'subheading') {
      return Text(
        text,
        style: SepiaTheme.sans(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      );
    }

    if (variant == 'caption') {
      return Text(
        text,
        style: SepiaTheme.mono(
          fontSize: 11,
          color: textColor,
        ),
      );
    }

    return Text(
      text,
      style: SepiaTheme.sans(
        fontSize: 13.5,
        height: 1.45,
        color: textColor,
      ),
    );
  }

  Widget _renderBadge(A2UIComponent comp) {
    final label = comp.properties['label'] as String? ?? '';
    final tone = comp.properties['tone'] as String? ?? 'neutral';

    Color bg = SepiaTheme.paperSubtle;
    Color border = SepiaTheme.border;
    Color text = SepiaTheme.inkSecondary;
    IconData icon = Icons.info_outline;

    if (tone == 'edge') {
      bg = SepiaTheme.sageBg;
      border = SepiaTheme.sageBorder;
      text = SepiaTheme.sage;
      icon = Icons.bolt;
    } else if (tone == 'cloud') {
      bg = SepiaTheme.azureBg;
      border = SepiaTheme.azureBorder;
      text = SepiaTheme.azure;
      icon = Icons.cloud_done;
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: text),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
                style: SepiaTheme.mono(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: text,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _renderButton(A2UIComponent comp) {
    final label = comp.properties['label'] as String? ?? '';
    final actionId = comp.properties['actionId'] as String? ?? '';
    final intent = comp.properties['intent'] as String? ?? 'local_dialogue';
    final payload = comp.properties['payload'] != null
        ? Map<String, dynamic>.from(comp.properties['payload'] as Map)
        : <String, dynamic>{};

    final isCloud = intent == 'visual_synthesis';
    final isDossier = actionId == 'open_dossier' || intent == 'inspect_dossier';

    return OutlinedButton.icon(
      icon: Icon(
        isCloud
            ? Icons.auto_awesome
            : (isDossier ? Icons.assignment_outlined : Icons.chat_bubble_outline),
        size: 14,
        color: isCloud ? SepiaTheme.azure : SepiaTheme.sage,
      ),
      label: Text(
        label,
        style: SepiaTheme.sans(
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          color: isCloud ? SepiaTheme.azure : SepiaTheme.sage,
        ),
      ),
      style: OutlinedButton.styleFrom(
        backgroundColor: isCloud
            ? SepiaTheme.azureBg.withValues(alpha: 0.6)
            : SepiaTheme.sageBg.withValues(alpha: 0.6),
        side: BorderSide(
          color: isCloud ? SepiaTheme.azureBorder : SepiaTheme.sageBorder,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      onPressed: () {
        widget.onAction?.call(A2UIAction(
          surfaceId: widget.surface.surfaceId,
          componentId: comp.id,
          actionId: actionId,
          intent: intent,
          parameters: payload,
        ));
      },
    );
  }

  Widget _renderChoiceGroup(A2UIComponent comp) {
    final rawList = comp.properties['items'] ?? comp.properties['choices'] ?? comp.properties['options'];
    final rawItems = (rawList as List<dynamic>?) ?? [];
    final choices = rawItems
        .whereType<Map>()
        .map((e) => A2UIChoiceItem.fromJson(Map<String, dynamic>.from(e)))
        .toList();

    final hasDetailedInfo = choices.any((c) => c.description != null || c.consequence != null);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.fork_right, size: 14, color: SepiaTheme.inkMuted),
            const SizedBox(width: 5),
            Text(
              'PROACTIVE NARRATIVE BRANCHES',
              style: SepiaTheme.mono(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: SepiaTheme.inkMuted,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (hasDetailedInfo)
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: choices.map((choice) {
              final isSelected = _selectedChoiceId == choice.id;
              final isVisual = choice.intent == 'visual_synthesis' || choice.requiresCloud;

              final accentColor = isVisual ? SepiaTheme.azure : SepiaTheme.sage;
              final bgColor = isSelected
                  ? (isVisual ? SepiaTheme.azureBg : SepiaTheme.sageBg)
                  : SepiaTheme.paper;
              final borderColor = isSelected
                  ? accentColor
                  : (isVisual ? SepiaTheme.azureBorder : SepiaTheme.sageBorder);

              return Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () {
                      setState(() => _selectedChoiceId = choice.id);
                      widget.onAction?.call(A2UIAction(
                        surfaceId: widget.surface.surfaceId,
                        componentId: comp.id,
                        actionId: 'select_choice',
                        intent: choice.intent,
                        parameters: {
                          'choiceId': choice.id,
                          'label': choice.label,
                          'intent': choice.intent,
                          'prompt': choice.prompt,
                          'requiresCloud': isVisual,
                        },
                      ));
                    },
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: bgColor,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: borderColor, width: isSelected ? 1.5 : 1.0),
                        boxShadow: [
                          if (isVisual)
                            BoxShadow(
                              color: SepiaTheme.azure.withValues(alpha: 0.06),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                isVisual ? Icons.cloud_outlined : Icons.flash_on,
                                size: 14,
                                color: accentColor,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  choice.label,
                                  style: SepiaTheme.sans(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    color: accentColor,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isVisual
                                      ? SepiaTheme.azure.withValues(alpha: 0.12)
                                      : SepiaTheme.sage.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  isVisual ? 'CLOUD' : 'EDGE',
                                  style: SepiaTheme.mono(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    color: accentColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (choice.description != null && choice.description!.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              choice.description!,
                              style: SepiaTheme.sans(
                                fontSize: 11.5,
                                color: SepiaTheme.ink,
                                height: 1.35,
                              ),
                            ),
                          ],
                          if (choice.consequence != null && choice.consequence!.isNotEmpty) ...[
                            const SizedBox(height: 5),
                            Row(
                              children: [
                                Icon(
                                  Icons.subdirectory_arrow_right,
                                  size: 12,
                                  color: accentColor.withValues(alpha: 0.8),
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    choice.consequence!,
                                    style: SepiaTheme.mono(
                                      fontSize: 10,
                                      color: accentColor,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: choices.map((choice) {
              final isSelected = _selectedChoiceId == choice.id;
              final isVisual = choice.intent == 'visual_synthesis' || choice.requiresCloud;

              final accentColor = isVisual ? SepiaTheme.azure : SepiaTheme.sage;
              final bgColor = isSelected
                  ? (isVisual ? SepiaTheme.azureBg : SepiaTheme.sageBg)
                  : SepiaTheme.paper;
              final borderColor = isSelected
                  ? accentColor
                  : (isVisual ? SepiaTheme.azureBorder : SepiaTheme.sageBorder);

              return InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () {
                  setState(() => _selectedChoiceId = choice.id);
                  widget.onAction?.call(A2UIAction(
                    surfaceId: widget.surface.surfaceId,
                    componentId: comp.id,
                    actionId: 'select_choice',
                    intent: choice.intent,
                    parameters: {
                      'choiceId': choice.id,
                      'label': choice.label,
                      'intent': choice.intent,
                      'prompt': choice.prompt,
                      'requiresCloud': isVisual,
                    },
                  ));
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: borderColor, width: 1.2),
                    boxShadow: [
                      if (isVisual)
                        BoxShadow(
                          color: SepiaTheme.azure.withValues(alpha: 0.08),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isVisual ? Icons.cloud_outlined : Icons.flash_on,
                        size: 13,
                        color: accentColor,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          choice.label,
                          style: SepiaTheme.sans(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: accentColor,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: isVisual
                              ? SepiaTheme.azure.withValues(alpha: 0.12)
                              : SepiaTheme.sage.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          isVisual ? 'CLOUD' : 'EDGE',
                          style: SepiaTheme.mono(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: accentColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
      ],
    );
  }

  Widget _renderSlider(A2UIComponent comp) {
    final label = comp.properties['label'] as String? ?? 'Setting';
    final min = (comp.properties['min'] as num?)?.toDouble() ?? 0.0;
    final max = (comp.properties['max'] as num?)?.toDouble() ?? 100.0;
    final initialVal = (comp.properties['value'] as num?)?.toDouble() ?? 50.0;
    final unit = comp.properties['unit'] as String? ?? '';
    final actionId = comp.properties['actionId'] as String? ?? 'update_slider';

    final currentVal = _sliderValues[comp.id] ?? initialVal;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: SepiaTheme.canvas,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: SepiaTheme.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: SepiaTheme.sans(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: SepiaTheme.inkSecondary,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: SepiaTheme.paper,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: SepiaTheme.border),
                ),
                child: Text(
                  '${currentVal.toInt()}$unit',
                  style: SepiaTheme.mono(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: SepiaTheme.sage,
                  ),
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: SepiaTheme.sage,
              inactiveTrackColor: SepiaTheme.border,
              thumbColor: SepiaTheme.sage,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
              trackHeight: 3,
            ),
            child: Slider(
              value: currentVal.clamp(min, max),
              min: min,
              max: max,
              onChanged: (val) {
                setState(() => _sliderValues[comp.id] = val);
                widget.onAction?.call(A2UIAction(
                  surfaceId: widget.surface.surfaceId,
                  componentId: comp.id,
                  actionId: actionId,
                  parameters: {'value': val, 'label': label},
                ));
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _renderImageCanvas(A2UIComponent comp) {
    final imageBase64 = comp.properties['imageBase64'] as String? ?? '';
    final caption = comp.properties['caption'] as String? ?? '';
    final prompt = comp.properties['prompt'] as String? ?? '';
    final latencyMs = (comp.properties['latencyMs'] as num?)?.toInt() ?? 0;
    final egressBytes = (comp.properties['egressBytes'] as num?)?.toInt() ?? 0;
    final modelAttribution = comp.properties['modelAttribution'] as String? ??
        'Nano Banana 2 Lite (gemini-3.1-flash-lite-image)';

    if (widget.isCloudGenerating && imageBase64.isEmpty) {
      return Container(
        height: 220,
        decoration: BoxDecoration(
          color: SepiaTheme.azureBg.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: SepiaTheme.azureBorder, style: BorderStyle.solid),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(SepiaTheme.azure),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                widget.cloudGeneratingStatus ?? 'Escalating to Cloud Run...',
                style: SepiaTheme.sans(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: SepiaTheme.azure,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Nano Banana 2 Lite • responseModalities: ["TEXT", "IMAGE"]',
                style: SepiaTheme.mono(fontSize: 11, color: SepiaTheme.inkMuted),
              ),
            ],
          ),
        ),
      );
    }

    if (imageBase64.isEmpty) {
      return const SizedBox.shrink();
    }

    Uint8List? imageBytes;
    try {
      imageBytes = base64Decode(imageBase64);
    } catch (_) {
      imageBytes = null;
    }

    return Container(
      decoration: BoxDecoration(
        color: SepiaTheme.paper,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: SepiaTheme.azureBorder),
        boxShadow: [
          BoxShadow(
            color: SepiaTheme.azure.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Image header with Cloud Attribution
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: SepiaTheme.azureBg.withValues(alpha: 0.5),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(7)),
            ),
            child: Row(
              children: [
                const Icon(Icons.cloud_done, size: 14, color: SepiaTheme.azure),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    modelAttribution,
                    style: SepiaTheme.mono(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: SepiaTheme.azure,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '${latencyMs}ms • ${(egressBytes / 1024).toStringAsFixed(1)} KB',
                  style: SepiaTheme.mono(
                    fontSize: 10,
                    color: SepiaTheme.inkMuted,
                  ),
                ),
              ],
            ),
          ),

          // Decoded Image Display
          if (imageBytes != null)
            ClipRRect(
              child: AspectRatio(
                aspectRatio: 1.0,
                child: Image.memory(
                  imageBytes,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Center(
                    child: Text('Failed to render synthesized image', style: SepiaTheme.sans(color: SepiaTheme.terracotta)),
                  ),
                ),
              ),
            )
          else
            Container(
              height: 180,
              color: SepiaTheme.canvas,
              child: const Center(child: Text('Invalid image payload')),
            ),

          // Caption & Prompt Inspector
          if (caption.isNotEmpty || prompt.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (caption.isNotEmpty)
                    Text(
                      caption,
                      style: SepiaTheme.sans(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        color: SepiaTheme.inkSecondary,
                      ),
                    ),
                  if (prompt.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Prompt: "$prompt"',
                      style: SepiaTheme.mono(
                        fontSize: 10.5,
                        color: SepiaTheme.inkMuted,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _renderDivider(A2UIComponent comp) {
    final spacing = (comp.properties['spacing'] as num?)?.toDouble() ?? 8.0;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: spacing),
      child: const Divider(height: 1, color: SepiaTheme.borderSubtle),
    );
  }

  Widget _renderRow(A2UIComponent comp) {
    final children = comp.childrenIds
        .map((id) => widget.surface.findComponent(id))
        .whereType<A2UIComponent>()
        .map(_renderComponent)
        .toList();

    return Row(
      children: children.map((c) => Expanded(child: c)).toList(),
    );
  }

  Widget _renderColumn(A2UIComponent comp) {
    final children = comp.childrenIds
        .map((id) => widget.surface.findComponent(id))
        .whereType<A2UIComponent>()
        .map(_renderComponent)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: _joinWithSpacing(children, 8),
    );
  }

  Widget _renderFallback(A2UIComponent comp) {
    return Container(
      padding: const EdgeInsets.all(8),
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: SepiaTheme.canvas,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: SepiaTheme.border),
      ),
      child: Text(
        'A2UI[${comp.type}]: ${comp.id}',
        style: SepiaTheme.mono(fontSize: 11, color: SepiaTheme.inkMuted),
      ),
    );
  }

  List<Widget> _joinWithSpacing(List<Widget> items, double spacing) {
    if (items.isEmpty) return [];
    final result = <Widget>[];
    for (int i = 0; i < items.length; i++) {
      result.add(items[i]);
      if (i < items.length - 1) {
        result.add(SizedBox(height: spacing));
      }
    }
    return result;
  }
}
