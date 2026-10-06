import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/local_execution_manager.dart';
import '../../theme/sepia_theme.dart';

/// Interactive on-device Gemma 4 loading pill.
///
/// Follows UI Clarity standards: zero false affordances, compact Intent Pill layout,
/// and directly executes model loading commands across Web (WebGPU fetch streaming)
/// and Android (MediaPipe / LiteRT LlmInference session initialization).
class GemmaLoadPill extends StatefulWidget {
  final LocalExecutionManager edgeManager;
  final VoidCallback? onModelLoaded;
  final VoidCallback? onModelUnloaded;
  final bool isCompact;

  const GemmaLoadPill({
    super.key,
    required this.edgeManager,
    this.onModelLoaded,
    this.onModelUnloaded,
    this.isCompact = false,
  });

  @override
  State<GemmaLoadPill> createState() => _GemmaLoadPillState();
}

class _GemmaLoadPillState extends State<GemmaLoadPill> {
  static const MethodChannel _androidChannel = MethodChannel('com.example.client/gemma_edge');

  bool _isCheckingPlatform = false;
  Map<String, dynamic>? _androidStatus;

  @override
  void initState() {
    super.initState();
    widget.edgeManager.addListener(_onManagerUpdate);
    _checkAndroidModelStatus();
  }

  @override
  void dispose() {
    widget.edgeManager.removeListener(_onManagerUpdate);
    super.dispose();
  }

  void _onManagerUpdate() {
    if (mounted) setState(() {});
  }

  Future<void> _checkAndroidModelStatus() async {
    try {
      final res = await _androidChannel.invokeMapMethod<String, dynamic>('checkModelStatus');
      if (mounted) {
        setState(() {
          _androidStatus = res;
        });
      }
    } catch (_) {
      // Non-Android platform (Web/Desktop) - silently ignore MethodChannel exceptions
    }
  }

  Future<void> _handleLoadTrigger() async {
    final mgr = widget.edgeManager;

    // Check if on Android
    if (_androidStatus != null) {
      final bool exists = _androidStatus!['exists'] as bool? ?? false;
      if (!exists) {
        _showAndroidInstructionDialog();
        return;
      }

      setState(() => _isCheckingPlatform = true);
      try {
        final res = await _androidChannel.invokeMapMethod<String, dynamic>('loadModel');
        if (mounted) {
          mgr.setGemmaLoaded(true);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ ${res?['model'] ?? "Gemma 4"} initialized successfully in LiteRT!'),
              backgroundColor: SepiaTheme.sage,
            ),
          );
          widget.onModelLoaded?.call();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('⚠️ Failed to load Gemma 4 in LiteRT: $e'),
              backgroundColor: SepiaTheme.terracotta,
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _isCheckingPlatform = false);
      }
      return;
    }

    // Web / WebGPU execution flow
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('⚡ Streaming Gemma 4 2B int4 model weights via WebGPU...'),
        duration: Duration(seconds: 2),
      ),
    );

    final success = await mgr.loadGemmaWeights(
      onProgress: (loaded, total, pct) {
        if (mounted) setState(() {});
      },
    );

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Gemma 4 2B WebGPU int4 pipeline active! 0 KB Cloud Egress.'),
            backgroundColor: SepiaTheme.sage,
          ),
        );
        widget.onModelLoaded?.call();
      } else {
        final err = mgr.gemmaError ?? 'WebGPU adapter or weights streaming failed.';
        _showWebGpuInstructionDialog(err);
      }
    }
  }

  Future<void> _handleUnloadTrigger() async {
    final mgr = widget.edgeManager;
    setState(() => _isCheckingPlatform = true);
    try {
      if (_androidStatus != null) {
        await _androidChannel.invokeMapMethod<String, dynamic>('unloadModel');
      }
      await mgr.unloadGemmaWeights();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🗑️ Gemma 4 2B weights unloaded. System RAM freed.'),
            backgroundColor: SepiaTheme.amber,
          ),
        );
        widget.onModelUnloaded?.call();
      }
    } finally {
      if (mounted) setState(() => _isCheckingPlatform = false);
    }
  }

  void _showAndroidInstructionDialog() {
    const cmd = 'adb push gemma-4-2b-it-int4.bin /data/local/tmp/gemma-4-2b-it-int4.bin';

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: SepiaTheme.paper,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: SepiaTheme.border, width: 1.5),
        ),
        title: Row(
          children: [
            const Icon(Icons.android, color: SepiaTheme.sage, size: 22),
            const SizedBox(width: 8),
            Text(
              'Gemma 4 Android Setup',
              style: SepiaTheme.sans(fontSize: 16, fontWeight: FontWeight.w700, color: SepiaTheme.ink),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'To run on-device inference on the Android AVD or physical device without cloud egress, push the int4 model weights into local storage:',
              style: SepiaTheme.sans(fontSize: 12, color: SepiaTheme.inkSecondary, height: 1.4),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: SepiaTheme.paperSubtle,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: SepiaTheme.border),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: SelectableText(
                      cmd,
                      style: SepiaTheme.mono(fontSize: 11, fontWeight: FontWeight.w600, color: SepiaTheme.ink),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy, size: 16),
                    onPressed: () {
                      Clipboard.setData(const ClipboardData(text: cmd));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Command copied to clipboard!')),
                      );
                    },
                    tooltip: 'Copy command',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Hardware profile: Requires >= 6 GB RAM (scripts/create_gemma_avd.sh) and LiteRT MediaPipe GenAI.',
              style: SepiaTheme.sans(fontSize: 11, fontStyle: FontStyle.italic, color: SepiaTheme.inkMuted),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'Close',
              style: SepiaTheme.sans(fontWeight: FontWeight.w600, color: SepiaTheme.ink),
            ),
          ),
        ],
      ),
    );
  }

  void _showWebGpuInstructionDialog(String error) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: SepiaTheme.paper,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: SepiaTheme.border, width: 1.5),
        ),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: SepiaTheme.terracotta, size: 22),
            const SizedBox(width: 8),
            Text(
              'WebGPU Hardware Notice',
              style: SepiaTheme.sans(fontSize: 16, fontWeight: FontWeight.w700, color: SepiaTheme.ink),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Gemma 4 on-device execution requires a compatible WebGPU adapter with float16 or high storage buffer limits.',
              style: SepiaTheme.sans(fontSize: 12, color: SepiaTheme.inkSecondary, height: 1.4),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: SepiaTheme.paperSubtle,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: SepiaTheme.border),
              ),
              child: SelectableText(
                error,
                style: SepiaTheme.mono(fontSize: 11, color: SepiaTheme.terracotta),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Enable flags in Chrome:\n• chrome://flags/#enable-unsafe-webgpu\n• chrome://flags/#enable-webgpu-developer-features',
              style: SepiaTheme.sans(fontSize: 11, color: SepiaTheme.inkMuted),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'Close',
              style: SepiaTheme.sans(fontWeight: FontWeight.w600, color: SepiaTheme.ink),
            ),
          ),
        ],
      ),
    );
  }

  void _showLoadedInspectionModal() {
    final mgr = widget.edgeManager;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: SepiaTheme.paper,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: SepiaTheme.border, width: 1.5),
        ),
        title: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: SepiaTheme.sage, size: 22),
            const SizedBox(width: 8),
            Text(
              'Gemma 4 2B Runtime Active',
              style: SepiaTheme.sans(fontSize: 16, fontWeight: FontWeight.w700, color: SepiaTheme.ink),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: SepiaTheme.sageBg,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: SepiaTheme.sageBorder),
              ),
              child: Row(
                children: [
                  const Icon(Icons.memory_rounded, size: 16, color: SepiaTheme.sage),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Resident Memory: ~${mgr.activeRamMb.toStringAsFixed(1)} MB RAM allocated (0 KB Cloud Egress)',
                      style: SepiaTheme.mono(fontSize: 11, fontWeight: FontWeight.w600, color: SepiaTheme.sage),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'What is active?',
              style: SepiaTheme.sans(fontSize: 12, fontWeight: FontWeight.w700, color: SepiaTheme.ink),
            ),
            const SizedBox(height: 4),
            Text(
              'Gemma 4 2B int4 model weights are loaded on-device via ${_androidStatus != null ? "LiteRT C++ Engine" : "WebGPU compute pipeline"}. Sensitive prompts, PII scrubbing, and local dialogue execute locally.',
              style: SepiaTheme.sans(fontSize: 12, color: SepiaTheme.inkSecondary, height: 1.4),
            ),
            const SizedBox(height: 12),
            Text(
              'Why is it loaded?',
              style: SepiaTheme.sans(fontSize: 12, fontWeight: FontWeight.w700, color: SepiaTheme.ink),
            ),
            const SizedBox(height: 4),
            Text(
              'Provides sub-65ms time-to-first-token, full offline capability, and prevents private data from traversing cloud networks.',
              style: SepiaTheme.sans(fontSize: 12, color: SepiaTheme.inkSecondary, height: 1.4),
            ),
            const SizedBox(height: 12),
            Text(
              'What can you do next?',
              style: SepiaTheme.sans(fontSize: 12, fontWeight: FontWeight.w700, color: SepiaTheme.ink),
            ),
            const SizedBox(height: 4),
            Text(
              'You can keep Gemma 4 active for zero-latency responses, or unload weights now to reclaim system RAM.',
              style: SepiaTheme.sans(fontSize: 12, color: SepiaTheme.inkSecondary, height: 1.4),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'Keep Active',
              style: SepiaTheme.sans(fontWeight: FontWeight.w600, color: SepiaTheme.inkSecondary),
            ),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: SepiaTheme.terracotta,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
            icon: const Icon(Icons.eject_outlined, size: 16),
            label: const Text('Unload Model (Free RAM)'),
            onPressed: () {
              Navigator.of(ctx).pop();
              _handleUnloadTrigger();
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mgr = widget.edgeManager;
    final isLoaded = mgr.isGemmaWeightsLoaded;
    final isDownloading = mgr.isGemmaDownloading || _isCheckingPlatform;

    Color bg;
    Color border;
    Color textColor;
    String label;
    IconData icon;

    if (isLoaded) {
      bg = SepiaTheme.sageBg;
      border = SepiaTheme.sageBorder;
      textColor = SepiaTheme.sage;
      label = widget.isCompact ? 'Gemma 4 Ready' : 'Gemma 4 2B Ready (0 KB Egress)';
      icon = Icons.check_circle_outline;
    } else if (isDownloading) {
      bg = SepiaTheme.amberBg;
      border = SepiaTheme.amberBorder;
      textColor = SepiaTheme.amber;
      final pct = mgr.gemmaDownloadProgress.toStringAsFixed(0);
      label = widget.isCompact ? 'Gemma 4 ($pct%)' : 'Downloading Gemma 4 2B ($pct%)';
      icon = Icons.downloading;
    } else {
      bg = SepiaTheme.paperSubtle;
      border = SepiaTheme.border;
      textColor = SepiaTheme.inkSecondary;
      label = widget.isCompact ? 'Load Gemma 4' : 'Load Gemma 4 2B (~1.46 GB)';
      icon = Icons.bolt_outlined;
    }

    final tooltipMsg = isLoaded
        ? 'Gemma 4 2B active on-device. Tap to inspect runtime or unload weights.'
        : isDownloading
            ? 'Downloading Gemma 4 2B model weights...'
            : 'Tap to load Gemma 4 2B on-device (~1.46 GB).';

    return Tooltip(
      message: tooltipMsg,
      child: InkWell(
        onTap: isDownloading
            ? null
            : () {
                if (isLoaded) {
                  _showLoadedInspectionModal();
                } else {
                  _handleLoadTrigger();
                }
              },
        borderRadius: BorderRadius.circular(6),
        child: Container(
          margin: EdgeInsets.symmetric(horizontal: widget.isCompact ? 2 : 4),
          padding: EdgeInsets.symmetric(
            horizontal: widget.isCompact ? 7 : 10,
            vertical: widget.isCompact ? 4 : 5,
          ),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 13, color: textColor),
              SizedBox(width: widget.isCompact ? 4 : 6),
              Text(
                label,
                style: SepiaTheme.mono(
                  fontSize: widget.isCompact ? 10 : 11,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
              if (isLoaded) ...[
                const SizedBox(width: 4),
                Icon(Icons.expand_more, size: 13, color: textColor),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
