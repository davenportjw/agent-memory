import 'package:flutter/material.dart';
import '../../services/app_mode_service.dart';
import '../../services/audio_feedback_service.dart';
import '../../theme/sepia_theme.dart';

class AppModeSlider extends StatelessWidget {
  final AppModeService? modeService;
  final ValueChanged<AppDisplayMode>? onModeChanged;
  final bool compact;

  const AppModeSlider({
    super.key,
    this.modeService,
    this.onModeChanged,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final service = modeService ?? AppModeService();

    return AnimatedBuilder(
      animation: service,
      builder: (context, _) {
        final isSimple = service.isSimple;

        return Semantics(
          label: 'Display Mode Switcher',
          value: isSimple ? 'Simple Mode Active' : 'Everything Mode Active',
          child: Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: SepiaTheme.paperSubtle,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: SepiaTheme.border, width: 1),
            ),
            child: Row(
              children: [
                // 1. Simple Mode Segment
                Expanded(
                  child: _buildSegment(
                    key: const Key('btn_mode_simple'),
                    isActive: isSimple,
                    icon: Icons.bolt_rounded,
                    label: compact ? 'Simple' : '⚡ Simple',
                    activeColor: SepiaTheme.sage,
                    tooltip: 'Simple Mode: Focus on Edge/Cloud AI, Memories & State',
                    onTap: () {
                      if (!isSimple) {
                        AudioFeedbackService.instance.playClick();
                        service.setMode(AppDisplayMode.simple);
                        onModeChanged?.call(AppDisplayMode.simple);
                      }
                    },
                  ),
                ),

                const SizedBox(width: 2),

                // 2. Everything Mode Segment
                Expanded(
                  child: _buildSegment(
                    key: const Key('btn_mode_everything'),
                    isActive: !isSimple,
                    icon: Icons.science_outlined,
                    label: compact ? 'Everything' : '🔬 Everything',
                    activeColor: SepiaTheme.amber,
                    tooltip: 'Everything Mode: Reveal Developer Tools, Rater Rubrics & Deep Telemetry',
                    onTap: () {
                      if (isSimple) {
                        AudioFeedbackService.instance.playClick();
                        service.setMode(AppDisplayMode.everything);
                        onModeChanged?.call(AppDisplayMode.everything);
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSegment({
    required Key key,
    required bool isActive,
    required IconData icon,
    required String label,
    required Color activeColor,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 300),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: key,
          onTap: onTap,
          borderRadius: BorderRadius.circular(4),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 4 : 6,
              vertical: compact ? 4 : 6,
            ),
            decoration: BoxDecoration(
              color: isActive ? SepiaTheme.paper : Colors.transparent,
              borderRadius: BorderRadius.circular(4),
              border: isActive
                  ? Border.all(color: activeColor.withValues(alpha: 0.6), width: 1)
                  : Border.all(color: Colors.transparent, width: 1),
              boxShadow: isActive
                  ? [
                      BoxShadow(
                        color: SepiaTheme.ink.withValues(alpha: 0.05),
                        blurRadius: 2,
                        offset: const Offset(0, 1),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: compact ? 13 : 14,
                  color: isActive ? activeColor : SepiaTheme.inkMuted,
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: SepiaTheme.sans(
                      fontSize: compact ? 11 : 12,
                      fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                      color: isActive ? SepiaTheme.ink : SepiaTheme.inkMuted,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
