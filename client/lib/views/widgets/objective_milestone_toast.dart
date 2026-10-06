import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/objective_milestone.dart';
import '../../theme/sepia_theme.dart';

/// Floating toast banner celebrating strategic objective completion
/// triggered by player dialogue actions and edge memory retrieval.
class ObjectiveMilestoneToast extends StatefulWidget {
  final ObjectiveMilestoneEvent event;
  final VoidCallback onDismiss;
  final Duration autoDismissDuration;

  const ObjectiveMilestoneToast({
    super.key,
    required this.event,
    required this.onDismiss,
    this.autoDismissDuration = const Duration(seconds: 4),
  });

  @override
  State<ObjectiveMilestoneToast> createState() => _ObjectiveMilestoneToastState();
}

class _ObjectiveMilestoneToastState extends State<ObjectiveMilestoneToast>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _offsetAnimation;
  late Animation<double> _fadeAnimation;
  Timer? _autoDismissTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );

    _offsetAnimation = Tween<Offset>(
      begin: const Offset(0.0, -0.4),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeIn,
    ));

    _controller.forward();

    // Auto-dismiss timer
    _autoDismissTimer = Timer(widget.autoDismissDuration, () {
      if (mounted) {
        _dismiss();
      }
    });
  }

  void _dismiss() {
    _autoDismissTimer?.cancel();
    widget.onDismiss();
  }

  @override
  void dispose() {
    _autoDismissTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _offsetAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Material(
          color: Colors.transparent,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 520),
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: SepiaTheme.paper,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: SepiaTheme.sage, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top header row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: SepiaTheme.sageBg,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: SepiaTheme.sageBorder),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.check_circle, size: 14, color: SepiaTheme.sage),
                                const SizedBox(width: 4),
                                Text(
                                  'OBJECTIVE MILESTONE REACHED',
                                  style: SepiaTheme.mono(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: SepiaTheme.sage,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: SepiaTheme.amberBg,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: SepiaTheme.amberBorder),
                            ),
                            child: Text(
                              '${widget.event.faction.toUpperCase()} (${widget.event.repDelta})',
                              style: SepiaTheme.mono(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: SepiaTheme.amber,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      key: const Key('btn_dismiss_milestone_toast'),
                      icon: const Icon(Icons.close, size: 16, color: SepiaTheme.inkMuted),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                      onPressed: _dismiss,
                      tooltip: 'Dismiss notification',
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Milestone Title
                Text(
                  widget.event.title,
                  style: SepiaTheme.sans(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: SepiaTheme.ink,
                  ),
                ),
                const SizedBox(height: 4),

                // Narrative Context
                Text(
                  widget.event.description,
                  style: SepiaTheme.sans(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: SepiaTheme.inkSecondary,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 8),

                // Memory Pipeline Citation
                Row(
                  children: [
                    const Icon(Icons.memory, size: 12, color: SepiaTheme.inkMuted),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        'Resolved via ${widget.event.memorySource} (${widget.event.latencyMs}ms latency)',
                        style: SepiaTheme.mono(
                          fontSize: 10,
                          color: SepiaTheme.inkMuted,
                          fontStyle: FontStyle.italic,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
