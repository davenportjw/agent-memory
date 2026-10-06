import 'package:flutter/material.dart';
import '../models/message.dart';
import '../models/routing_decision.dart';
import '../services/local_execution_manager.dart';
import '../services/switching_router_service.dart';
import '../theme/sepia_theme.dart';
import 'widgets/intent_pill_widget.dart';
import 'widgets/telemetry_card.dart';
import 'widgets/sepia_markdown_widget.dart';
import 'widgets/markdown_prompt_editor.dart';
import 'widgets/gemma_load_pill.dart';

class CenterWorkspace extends StatefulWidget {
  final List<ChatMessage> messages;
  final bool isGenerating;
  final RouterModeOverride currentOverride;
  final ValueChanged<RouterModeOverride> onOverrideChanged;
  final Future<void> Function(String prompt) onSendMessage;
  final IntentPillData? selectedPill;
  final ValueChanged<IntentPillData> onPillSelected;
  final VoidCallback onToggleDrawer;
  final bool isDrawerOpen;
  final VoidCallback onClearChat;
  final String activeEdgeEngineName;
  final LocalExecutionManager? edgeManager;
  final ValueChanged<EdgeEngineSelection>? onEngineChanged;
  final VoidCallback? onCreateLanguageModel;

  const CenterWorkspace({
    super.key,
    required this.messages,
    required this.isGenerating,
    required this.currentOverride,
    required this.onOverrideChanged,
    required this.onSendMessage,
    required this.selectedPill,
    required this.onPillSelected,
    required this.onToggleDrawer,
    required this.isDrawerOpen,
    required this.onClearChat,
    this.activeEdgeEngineName = 'Gemini Nano (Chrome Built-in AI)',
    this.edgeManager,
    this.onEngineChanged,
    this.onCreateLanguageModel,
  });

  @override
  State<CenterWorkspace> createState() => _CenterWorkspaceState();
}

class _CenterWorkspaceState extends State<CenterWorkspace> {
  final TextEditingController _promptController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final SwitchingRouterService _routerInspector = SwitchingRouterService();

  List<String> _detectedPiiInDraft = [];
  int _estimatedTokens = 0;
  int? _liveProbeLatencyMs;
  bool _isNanoBannerDismissed = false;

  @override
  void initState() {
    super.initState();
    _promptController.addListener(_onPromptChanged);
    _runLiveProbe();
  }

  void _runLiveProbe() {
    final sw = Stopwatch()..start();
    _routerInspector.detectPii('Contact alice@example.org or call 555-0199');
    _routerInspector.evaluateRoute(prompt: 'Edge-to-cloud policy probe check', isNetworkOnline: true);
    sw.stop();
    setState(() {
      final elapsed = (sw.elapsedMicroseconds / 1000.0).ceil();
      _liveProbeLatencyMs = elapsed > 0 ? elapsed : 1;
    });
  }

  @override
  void dispose() {
    _promptController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onPromptChanged() {
    final text = _promptController.text;
    final pii = _routerInspector.detectPii(text);
    final tokens = (text.length / 3.8).ceil();

    setState(() {
      _detectedPiiInDraft = pii;
      _estimatedTokens = tokens;
    });
  }

  void _submit() {
    final text = _promptController.text.trim();
    if (text.isEmpty || widget.isGenerating) return;
    _promptController.clear();
    widget.onSendMessage(text);

    // Auto-scroll to bottom after submit
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _insertPrompt(String prompt) {
    _promptController.text = prompt;
    _onPromptChanged();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: SepiaTheme.canvas,
      child: Column(
        children: [
          // Header Bar
          _buildWorkspaceHeader(),

          // Gemini Nano Status / Creation Banner
          if (widget.edgeManager != null && _shouldShowGeminiNanoBanner() && !_isNanoBannerDismissed)
            _buildGeminiNanoStatusBanner(),

          // Message Stream
          Expanded(
            child: widget.messages.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    itemCount: widget.messages.length,
                    itemBuilder: (context, index) {
                      final msg = widget.messages[index];
                      return _buildMessageTurn(msg);
                    },
                  ),
          ),

          // Real-time PII Alert if detected in draft
          if (_detectedPiiInDraft.isNotEmpty) _buildPiiDraftNotice(),

          // Prompt Input Bar
          _buildPromptInputBar(),
        ],
      ),
    );
  }

  Widget _buildProbeChip({required bool isCompact}) {
    return InkWell(
      onTap: () {
        _runLiveProbe();
        if (!widget.isDrawerOpen) {
          widget.onToggleDrawer();
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: Tooltip(
        message: 'Edge probe latency. Click to re-probe and inspect live telemetry.',
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: isCompact ? 6 : 8,
            vertical: 3,
          ),
          decoration: BoxDecoration(
            color: SepiaTheme.paper,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: SepiaTheme.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: _liveProbeLatencyMs != null ? SepiaTheme.sage : SepiaTheme.amber,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 5),
              Text(
                _liveProbeLatencyMs != null
                    ? (isCompact ? '${_liveProbeLatencyMs}ms' : 'Edge Probe: ${_liveProbeLatencyMs}ms')
                    : (isCompact ? 'Probing' : 'Probing...'),
                style: SepiaTheme.mono(fontSize: 10, color: SepiaTheme.inkSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWorkspaceHeader() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final workspaceWidth = constraints.maxWidth;
        final isCompact = workspaceWidth < 820;
        final isUltraCompact = workspaceWidth < 600;
        final isMobile = MediaQuery.of(context).size.width < 900;

        final String titleText;
        if (workspaceWidth >= 900) {
          titleText = 'ASSISTANT SHELL // DUAL EDGE-CLOUD WORKSPACE';
        } else if (workspaceWidth >= 600) {
          titleText = 'ASSISTANT SHELL';
        } else {
          titleText = 'ASSISTANT';
        }

        final actions = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Latency Probe Chip (shown on screens 600px and wider)
            if (workspaceWidth >= 600) ...[
              _buildProbeChip(isCompact: isCompact),
              const SizedBox(width: 6),
            ],
            // Unified Execution & Routing Control Pill
            _buildExecutionRoutingPill(isCompact: isCompact),
            if (widget.edgeManager != null) ...[
              const SizedBox(width: 6),
              GemmaLoadPill(
                edgeManager: widget.edgeManager!,
                isCompact: isCompact,
              ),
            ],
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, size: 18),
              onPressed: widget.onClearChat,
              tooltip: 'Clear Chat History',
              splashRadius: 18,
            ),
            Builder(
              builder: (ctx) => IconButton(
                icon: Icon(
                  widget.isDrawerOpen ? Icons.dock_rounded : Icons.view_sidebar_outlined,
                  size: 18,
                  color: widget.isDrawerOpen ? SepiaTheme.amber : SepiaTheme.ink,
                ),
                onPressed: () {
                  if (isMobile) {
                    Scaffold.of(ctx).openEndDrawer();
                  } else {
                    widget.onToggleDrawer();
                  }
                },
                tooltip: widget.isDrawerOpen ? 'Close Inspector' : 'Open Inspector',
                splashRadius: 18,
              ),
            ),
          ],
        );

        return Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: const BoxDecoration(
            color: SepiaTheme.canvas,
            border: Border(bottom: BorderSide(color: SepiaTheme.border)),
          ),
          child: Row(
            children: [
              // 1. Left Title Block (bounded to at most 45% of workspace width, naturally sized)
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: workspaceWidth * 0.45),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isMobile) ...[
                      Builder(
                        builder: (ctx) => IconButton(
                          icon: const Icon(Icons.menu_rounded, size: 20, color: SepiaTheme.ink),
                          onPressed: () => Scaffold.of(ctx).openDrawer(),
                          tooltip: 'Navigation Menu',
                          splashRadius: 20,
                        ),
                      ),
                      const SizedBox(width: 4),
                    ],
                    if (!isUltraCompact && workspaceWidth >= 740) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color: SepiaTheme.paperSubtle,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: SepiaTheme.borderSubtle),
                        ),
                        child: Text(
                          'DEV TOOL',
                          style: SepiaTheme.mono(fontSize: 9, fontWeight: FontWeight.w700, color: SepiaTheme.inkMuted),
                        ),
                      ),
                    ],
                    const Icon(Icons.hub_outlined, size: 16, color: SepiaTheme.ink),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        titleText,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                        style: SepiaTheme.sans(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // 2. Right Action Pills (takes all remaining width, scrollable if very narrow)
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: actions,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  bool _shouldShowGeminiNanoBanner() {
    final mgr = widget.edgeManager;
    if (mgr == null) return false;
    if (mgr.isCreatingModel) return true;
    if (mgr.selectedEngine == EdgeEngineSelection.geminiNano && !mgr.isGeminiNanoActive) return true;
    if (mgr.isGeminiNanoNeedsDownload && widget.messages.isEmpty) return true;
    return false;
  }

  Widget _buildExecutionRoutingPill({bool isCompact = false}) {
    final mgr = widget.edgeManager;
    final mode = widget.currentOverride;

    IconData modeIcon;
    Color modeColor;
    String modeLabel;

    switch (mode) {
      case RouterModeOverride.auto:
        modeIcon = Icons.bolt_rounded;
        modeColor = SepiaTheme.ink;
        if (isCompact) {
          if (mgr != null && mgr.isGeminiNanoActive) {
            modeLabel = 'Auto (Nano)';
          } else if (mgr != null && mgr.selectedEngine == EdgeEngineSelection.gemma4) {
            modeLabel = 'Auto (Gemma)';
          } else {
            modeLabel = 'Auto';
          }
        } else if (mgr != null) {
          if (mgr.isGeminiNanoActive) {
            modeLabel = 'Auto (Gemini Nano)';
          } else {
            modeLabel = 'Auto: Gemma 4 (Nano Pending)';
          }
        } else {
          modeLabel = 'Auto (${widget.activeEdgeEngineName})';
        }
        break;
      case RouterModeOverride.enforceEdgeLocal:
        modeIcon = Icons.memory_rounded;
        modeColor = SepiaTheme.sage;
        if (isCompact) {
          if (mgr != null && mgr.selectedEngine == EdgeEngineSelection.geminiNano) {
            modeLabel = 'Local (Nano)';
          } else if (mgr != null && mgr.selectedEngine == EdgeEngineSelection.gemma4) {
            modeLabel = 'Local (Gemma)';
          } else {
            modeLabel = 'Local';
          }
        } else if (mgr != null) {
          if (mgr.selectedEngine == EdgeEngineSelection.geminiNano) {
            if (mgr.isGeminiNanoActive) {
              modeLabel = 'Local: Gemini Nano';
            } else if (mgr.isCreatingModel) {
              modeLabel = 'Local: Gemini Nano [Downloading...]';
            } else if (mgr.isGeminiNanoNeedsDownload) {
              modeLabel = 'Local: Gemini Nano [Weights Pending]';
            } else {
              modeLabel = 'Local: Gemini Nano [Flag Needed]';
            }
          } else if (mgr.selectedEngine == EdgeEngineSelection.gemma4) {
            modeLabel = 'Local: Gemma 4 int4';
          } else {
            if (mgr.isGeminiNanoActive) {
              modeLabel = 'Local: Gemini Nano';
            } else {
              modeLabel = 'Local: Gemma 4 (Nano Pending)';
            }
          }
        } else {
          modeLabel = 'Local: ${widget.activeEdgeEngineName}';
        }
        break;
      case RouterModeOverride.enforceCloudFlash:
        modeIcon = Icons.cloud_outlined;
        modeColor = SepiaTheme.amber;
        modeLabel = isCompact ? 'Cloud' : 'Cloud: Gemini 3.8 Flash';
        break;
      case RouterModeOverride.simulateOffline:
        modeIcon = Icons.cloud_off_rounded;
        modeColor = SepiaTheme.terracotta;
        modeLabel = isCompact ? 'Offline' : 'Simulate Offline';
        break;
    }

    final isCreating = mgr?.isCreatingModel ?? false;

    return Theme(
      data: Theme.of(context).copyWith(
        cardColor: SepiaTheme.paper,
        popupMenuTheme: const PopupMenuThemeData(
          color: SepiaTheme.paper,
          surfaceTintColor: Colors.transparent,
        ),
      ),
      child: PopupMenuButton<String>(
        tooltip: 'Select routing policy and on-device engine',
        offset: const Offset(0, 36),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: SepiaTheme.border),
        ),
        onSelected: (value) {
          if (value.startsWith('mode:')) {
            final modeName = value.substring(5);
            switch (modeName) {
              case 'auto':
                widget.onOverrideChanged(RouterModeOverride.auto);
                break;
              case 'edge':
                widget.onOverrideChanged(RouterModeOverride.enforceEdgeLocal);
                break;
              case 'cloud':
                widget.onOverrideChanged(RouterModeOverride.enforceCloudFlash);
                break;
              case 'offline':
                widget.onOverrideChanged(RouterModeOverride.simulateOffline);
                break;
            }
          } else if (value.startsWith('engine:')) {
            final engineName = value.substring(7);
            if (widget.onEngineChanged != null) {
              switch (engineName) {
                case 'auto':
                  widget.onEngineChanged!(EdgeEngineSelection.auto);
                  break;
                case 'gemma4':
                  widget.onEngineChanged!(EdgeEngineSelection.gemma4);
                  break;
                case 'nano':
                  widget.onEngineChanged!(EdgeEngineSelection.geminiNano);
                  break;
              }
            }
          } else if (value == 'action:create_nano') {
            widget.onCreateLanguageModel?.call();
          }
        },
        itemBuilder: (context) {
          final items = <PopupMenuEntry<String>>[];

          // 1. ROUTING POLICY HEADER
          items.add(
            PopupMenuItem<String>(
              enabled: false,
              height: 28,
              child: Text(
                'ROUTING POLICY OVERRIDE',
                style: SepiaTheme.mono(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: SepiaTheme.inkMuted,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          );

          items.add(
            _buildRoutingMenuItem(
              value: 'mode:auto',
              icon: Icons.bolt_rounded,
              title: 'Auto Policy (Dynamic Routing)',
              badge: 'Default',
              isSelected: mode == RouterModeOverride.auto,
              accentColor: SepiaTheme.ink,
            ),
          );
          items.add(
            _buildRoutingMenuItem(
              value: 'mode:edge',
              icon: Icons.memory_rounded,
              title: 'Enforce On-Device Local',
              badge: '0 KB Egress',
              isSelected: mode == RouterModeOverride.enforceEdgeLocal,
              accentColor: SepiaTheme.sage,
            ),
          );
          items.add(
            _buildRoutingMenuItem(
              value: 'mode:cloud',
              icon: Icons.cloud_outlined,
              title: 'Enforce Cloud Flash',
              badge: 'Gemini 3.8',
              isSelected: mode == RouterModeOverride.enforceCloudFlash,
              accentColor: SepiaTheme.amber,
            ),
          );
          items.add(
            _buildRoutingMenuItem(
              value: 'mode:offline',
              icon: Icons.cloud_off_rounded,
              title: 'Simulate Offline Network',
              badge: 'Fallback',
              isSelected: mode == RouterModeOverride.simulateOffline,
              accentColor: SepiaTheme.terracotta,
            ),
          );

          if (mgr != null && widget.onEngineChanged != null) {
            items.add(const PopupMenuDivider(height: 12));

            // 2. ON-DEVICE ENGINE HEADER
            items.add(
              PopupMenuItem<String>(
                enabled: false,
                height: 28,
                child: Text(
                  'ON-DEVICE ENGINE TARGET',
                  style: SepiaTheme.mono(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: SepiaTheme.inkMuted,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            );

            final currentEngine = mgr.selectedEngine;
            items.add(
              _buildRoutingMenuItem(
                value: 'engine:auto',
                icon: Icons.auto_mode_rounded,
                title: 'Auto (Best Engine Probe)',
                badge: 'Probed',
                isSelected: currentEngine == EdgeEngineSelection.auto,
                accentColor: SepiaTheme.ink,
              ),
            );
            items.add(
              _buildRoutingMenuItem(
                value: 'engine:gemma4',
                icon: Icons.memory_rounded,
                title: 'Gemma 4 int4 (LiteRT/WebGPU)',
                badge: '~1.2 GB',
                isSelected: currentEngine == EdgeEngineSelection.gemma4,
                accentColor: SepiaTheme.sage,
              ),
            );
            items.add(
              _buildRoutingMenuItem(
                value: 'engine:nano',
                icon: Icons.bolt_rounded,
                title: 'Gemini Nano (Chrome Built-in AI)',
                badge: mgr.isGeminiNanoActive
                    ? 'Active'
                    : (mgr.isCreatingModel
                        ? 'Downloading'
                        : (mgr.isGeminiNanoNeedsDownload ? 'Weights Pending' : 'Flag Needed')),
                isSelected: currentEngine == EdgeEngineSelection.geminiNano,
                accentColor: mgr.isGeminiNanoActive
                    ? SepiaTheme.sage
                    : (mgr.isCreatingModel
                        ? SepiaTheme.terracotta
                        : (mgr.isGeminiNanoNeedsDownload ? SepiaTheme.amber : SepiaTheme.inkMuted)),
              ),
            );

            if (mgr.isGeminiNanoNeedsDownload && widget.onCreateLanguageModel != null) {
              items.add(const PopupMenuDivider(height: 12));
              items.add(
                PopupMenuItem<String>(
                  value: 'action:create_nano',
                  height: 36,
                  child: Row(
                    children: [
                      const Icon(Icons.download_rounded, size: 14, color: SepiaTheme.terracotta),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Create Model Session in Chrome (~1.8 GB)',
                          style: SepiaTheme.mono(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: SepiaTheme.terracotta,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }
          }

          return items;
        },
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: isCompact ? 7 : 10, vertical: 4),
          decoration: BoxDecoration(
            color: SepiaTheme.paper,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: mode == RouterModeOverride.auto ? SepiaTheme.border : modeColor.withValues(alpha: 0.6),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isCreating) ...[
                const SizedBox(
                  width: 10,
                  height: 10,
                  child: CircularProgressIndicator(strokeWidth: 1.5, color: SepiaTheme.terracotta),
                ),
                const SizedBox(width: 6),
                Text(
                  isCompact ? 'Creating...' : 'Creating Model...',
                  style: SepiaTheme.mono(fontSize: 10, fontWeight: FontWeight.w700, color: SepiaTheme.terracotta),
                ),
              ] else ...[
                Icon(modeIcon, size: 13, color: modeColor),
                SizedBox(width: isCompact ? 4 : 6),
                Text(
                  modeLabel,
                  style: SepiaTheme.mono(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: SepiaTheme.ink,
                  ),
                ),
              ],
              const SizedBox(width: 4),
              const Icon(Icons.arrow_drop_down_rounded, size: 16, color: SepiaTheme.inkSecondary),
            ],
          ),
        ),
      ),
    );
  }

  PopupMenuItem<String> _buildRoutingMenuItem({
    required String value,
    required IconData icon,
    required String title,
    required String badge,
    required bool isSelected,
    required Color accentColor,
  }) {
    return PopupMenuItem<String>(
      value: value,
      height: 36,
      child: Row(
        children: [
          Icon(
            isSelected ? Icons.check_circle_rounded : icon,
            size: 14,
            color: isSelected ? accentColor : SepiaTheme.inkMuted,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: SepiaTheme.sans(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                color: isSelected ? SepiaTheme.ink : SepiaTheme.inkSecondary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
            decoration: BoxDecoration(
              color: isSelected ? accentColor.withValues(alpha: 0.12) : SepiaTheme.paperSubtle,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: isSelected ? accentColor.withValues(alpha: 0.3) : SepiaTheme.borderSubtle,
              ),
            ),
            child: Text(
              badge,
              style: SepiaTheme.mono(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: isSelected ? accentColor : SepiaTheme.inkMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGeminiNanoStatusBanner() {
    final mgr = widget.edgeManager!;

    if (mgr.isCreatingModel) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: SepiaTheme.paper,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: SepiaTheme.terracotta.withValues(alpha: 0.5)),
        ),
        child: Row(
          children: [
            const SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(strokeWidth: 1.5, color: SepiaTheme.terracotta),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Creating Language Model in Chrome... Gemma 4 int4 is on standby for immediate on-device queries.',
                style: SepiaTheme.sans(fontSize: 11, fontWeight: FontWeight.w600, color: SepiaTheme.ink),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (mgr.downloadedBytes > 0) ...[
              const SizedBox(width: 8),
              Text(
                '${(mgr.downloadedBytes / (1024 * 1024)).toStringAsFixed(1)} MB',
                style: SepiaTheme.mono(fontSize: 10, color: SepiaTheme.inkSecondary),
              ),
            ],
            if (mgr.downloadProgress != null) ...[
              const SizedBox(width: 8),
              SizedBox(
                width: 80,
                child: LinearProgressIndicator(
                  value: mgr.downloadProgress,
                  backgroundColor: SepiaTheme.canvas,
                  valueColor: const AlwaysStoppedAnimation<Color>(SepiaTheme.terracotta),
                ),
              ),
            ],
            IconButton(
              icon: const Icon(Icons.close_rounded, size: 14),
              splashRadius: 14,
              padding: const EdgeInsets.only(left: 6),
              constraints: const BoxConstraints(),
              onPressed: () => setState(() => _isNanoBannerDismissed = true),
              tooltip: 'Dismiss notice',
            ),
          ],
        ),
      );
    }

    if (mgr.isGeminiNanoNeedsDownload) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: SepiaTheme.paper,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: SepiaTheme.sage.withValues(alpha: 0.6)),
        ),
        child: Row(
          children: [
            const Icon(Icons.bolt, color: SepiaTheme.sage, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Chrome Built-in AI ready. Click Initialize to download local weights (~1.8 GB). Gemma 4 int4 is ready on standby.',
                style: SepiaTheme.sans(fontSize: 11, fontWeight: FontWeight.w600, color: SepiaTheme.ink),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            if (widget.onCreateLanguageModel != null)
              ElevatedButton.icon(
                onPressed: widget.onCreateLanguageModel,
                icon: const Icon(Icons.bolt, size: 12, color: Colors.white),
                label: const Text(
                  'Initialize Session',
                  style: TextStyle(
                    fontFamily: SepiaTheme.fontMono,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: SepiaTheme.ink,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                ),
              ),
            IconButton(
              icon: const Icon(Icons.close_rounded, size: 14),
              splashRadius: 14,
              padding: const EdgeInsets.only(left: 6),
              constraints: const BoxConstraints(),
              onPressed: () => setState(() => _isNanoBannerDismissed = true),
              tooltip: 'Dismiss notice',
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: SepiaTheme.paper,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: SepiaTheme.amber.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, color: SepiaTheme.amber, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Chrome Prompt API setup: enable chrome://flags/#prompt-api (>= 22 GB free disk space). Gemma 4 int4 is currently active.',
              style: SepiaTheme.sans(fontSize: 11, color: SepiaTheme.inkSecondary),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          if (widget.onCreateLanguageModel != null) ...[
            ElevatedButton(
              onPressed: widget.onCreateLanguageModel,
              style: ElevatedButton.styleFrom(
                backgroundColor: SepiaTheme.terracotta,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              ),
              child: Text(
                'Create Model',
                style: SepiaTheme.mono(fontSize: 9.5, fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: 6),
          ],
          OutlinedButton(
            onPressed: () => widget.onEngineChanged?.call(EdgeEngineSelection.gemma4),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              side: const BorderSide(color: SepiaTheme.sage),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            ),
            child: Text(
              'Use Gemma 4',
              style: SepiaTheme.mono(fontSize: 9.5, fontWeight: FontWeight.w700, color: SepiaTheme.sage),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 14),
            splashRadius: 14,
            padding: const EdgeInsets.only(left: 6),
            constraints: const BoxConstraints(),
            onPressed: () => setState(() => _isNanoBannerDismissed = true),
            tooltip: 'Dismiss notice',
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: SepiaTheme.paper,
                shape: BoxShape.circle,
                border: Border.all(color: SepiaTheme.border),
              ),
              child: const Icon(Icons.auto_awesome_rounded, size: 36, color: SepiaTheme.inkSecondary),
            ),
            const SizedBox(height: 16),
            Text(
              'Dual Edge AI: Gemini Nano & Gemma 4',
              style: SepiaTheme.sans(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Text(
                'Demonstrating true on-device local execution with 0 KB cloud egress. '
                'In Google Chrome, run native Gemini Nano via the Built-in Prompt API. '
                'On mobile and edge devices, run quantized Gemma 4 int4 via LiteRT/WebGPU. '
                'Complex multi-hop reasoning escalates to Gemini 3.8 Flash in Google Cloud.',
                textAlign: TextAlign.center,
                style: SepiaTheme.sans(fontSize: 13, color: SepiaTheme.inkMuted, height: 1.4),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'TRY TEST PROMPTS:',
              style: SepiaTheme.mono(fontSize: 10, fontWeight: FontWeight.w700, color: SepiaTheme.inkMuted),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                _buildTestPromptButton(
                  '🔒 Local Privacy PII (On-Device)',
                  'Extract action items and redact contact details: Contact alice@example.org or call 555-0199 before Friday.',
                ),
                _buildTestPromptButton(
                  '⚡ On-Device Gemini Nano Probe',
                  'Summarize the latency and privacy advantages of executing Gemini Nano locally in Chrome compared to cloud roundtrips.',
                ),
                _buildTestPromptButton(
                  '🌐 Cloud Multi-Hop Reasoning',
                  'Synthesize our durable memory policy and explain why edge bundles must remain under 50 KB.',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTestPromptButton(String label, String prompt) {
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        backgroundColor: SepiaTheme.paper,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      onPressed: () => _insertPrompt(prompt),
      child: Text(label, style: SepiaTheme.sans(fontSize: 12, fontWeight: FontWeight.w500)),
    );
  }

  Widget _buildMessageTurn(ChatMessage msg) {
    final isUser = msg.sender == MessageSender.user;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: msg.intentPill?.route == ExecutionRoute.CLOUD_ESCALATE
                    ? SepiaTheme.amberBg
                    : SepiaTheme.sageBg,
                shape: BoxShape.circle,
                border: Border.all(
                  color: msg.intentPill?.route == ExecutionRoute.CLOUD_ESCALATE
                      ? SepiaTheme.amberBorder
                      : SepiaTheme.sageBorder,
                ),
              ),
              child: Icon(
                msg.intentPill?.route == ExecutionRoute.CLOUD_ESCALATE
                    ? Icons.cloud_outlined
                    : Icons.memory_rounded,
                size: 14,
                color: msg.intentPill?.route == ExecutionRoute.CLOUD_ESCALATE
                    ? SepiaTheme.amber
                    : SepiaTheme.sage,
              ),
            ),
            const SizedBox(width: 10),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                // Sender label & time
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      isUser ? 'USER // LOCAL DEVICE' : 'ASSISTANT // ROUTED COMPLETION',
                      style: SepiaTheme.mono(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: SepiaTheme.inkMuted,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${msg.timestamp.hour.toString().padLeft(2, '0')}:${msg.timestamp.minute.toString().padLeft(2, '0')}',
                      style: SepiaTheme.mono(fontSize: 9, color: SepiaTheme.inkMuted),
                    ),
                  ],
                ),
                const SizedBox(height: 4),

                // Intent Pill badge for assistant messages
                if (!isUser && msg.intentPill != null) ...[
                  IntentPillWidget(
                    pillData: msg.intentPill!,
                    isSelected: widget.selectedPill?.id == msg.intentPill?.id,
                    onTap: () => widget.onPillSelected(msg.intentPill!),
                  ),
                  const SizedBox(height: 6),
                ],

                // Fallback Notice Banner if this message resulted from an on-device or cloud fallback
                if (!isUser && msg.isFallback) ...[
                  _buildFallbackNoticeBanner(
                    reason: msg.fallbackReason ??
                        'Engine fallback active. Automatically routed to maintain continuous execution.',
                    isCloudEscalation: msg.telemetry != null && msg.telemetry!.cloudEgressKb > 0,
                  ),
                  const SizedBox(height: 6),
                ],

                // Content Box or Interactive Action Notice Card
                if (!isUser && (msg.text.contains('Chrome Built-in AI') || msg.text.contains('Local Inference Failure')))
                  _buildLocalInferenceActionCard(msg)
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: isUser ? SepiaTheme.paperSubtle : SepiaTheme.paper,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isUser ? SepiaTheme.border : SepiaTheme.borderSubtle,
                      ),
                    ),
                    child: SepiaMarkdownWidget(
                      markdown: msg.text,
                      isUser: isUser,
                    ),
                  ),

                // Micro Telemetry for assistant turns
                if (!isUser && msg.telemetry != null && !msg.isStreaming) ...[
                  const SizedBox(height: 4),
                  TelemetryCard(
                    telemetry: msg.telemetry!,
                    compact: true,
                  ),
                ],
              ],
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 10),
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: SepiaTheme.paper,
                shape: BoxShape.circle,
                border: Border.all(color: SepiaTheme.border),
              ),
              child: const Icon(Icons.person_outline_rounded, size: 14, color: SepiaTheme.ink),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLocalInferenceActionCard(ChatMessage msg) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: SepiaTheme.paper,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: SepiaTheme.amber.withValues(alpha: 0.6), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: SepiaTheme.ink.withValues(alpha: 0.04),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded, size: 18, color: SepiaTheme.amber),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Chrome Built-in AI (Gemini Nano) Setup Required',
                  style: SepiaTheme.sans(fontSize: 13, fontWeight: FontWeight.w700, color: SepiaTheme.ink),
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
                  'ON-DEVICE EDGE',
                  style: SepiaTheme.mono(fontSize: 9, fontWeight: FontWeight.w700, color: SepiaTheme.amber),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'The browser cannot access Gemini Nano. Modern Chrome requires enabling the Prompt API flag and verifying available local disk space.',
            style: SepiaTheme.sans(fontSize: 12, color: SepiaTheme.ink, height: 1.4),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: SepiaTheme.paperSubtle,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: SepiaTheme.borderSubtle),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '📌 Why Option 2 was missing:',
                  style: SepiaTheme.mono(fontSize: 10, fontWeight: FontWeight.w700, color: SepiaTheme.ink),
                ),
                const SizedBox(height: 2),
                Text(
                  'The legacy flag #optimization-guide-on-device-model has been deprecated and removed in modern Chrome. It is no longer needed or configurable.',
                  style: SepiaTheme.sans(fontSize: 11, color: SepiaTheme.inkSecondary),
                ),
                const SizedBox(height: 6),
                Text(
                  '⚙️ Modern Chrome Setup Steps:',
                  style: SepiaTheme.mono(fontSize: 10, fontWeight: FontWeight.w700, color: SepiaTheme.ink),
                ),
                const SizedBox(height: 2),
                Text(
                  '1. Open chrome://flags/#prompt-api (or #prompt-api-for-gemini-nano) -> set to "Enabled"\n'
                  '2. Ensure >= 22 GB free disk space on startup drive (Chrome evicts models if free space < 10 GB)\n'
                  '3. Relaunch Chrome and monitor status in chrome://on-device-internals (Model Status tab)\n'
                  '4. Optional DevTools trigger: await LanguageModel.create()',
                  style: SepiaTheme.mono(fontSize: 10, color: SepiaTheme.inkSecondary, height: 1.35),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (widget.onCreateLanguageModel != null)
                ElevatedButton.icon(
                  onPressed: widget.onCreateLanguageModel,
                  icon: const Icon(Icons.bolt, size: 14, color: Colors.white),
                  label: const Text(
                    'Create Language Model in Chrome',
                    style: TextStyle(
                      fontFamily: 'JetBrains Mono',
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: SepiaTheme.terracotta,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                ),
              OutlinedButton.icon(
                onPressed: () {
                  widget.onEngineChanged?.call(EdgeEngineSelection.gemma4);
                  final prompt = msg.rawOriginalPrompt;
                  if (prompt != null && prompt.isNotEmpty) {
                    widget.onSendMessage(prompt);
                  }
                },
                icon: const Icon(Icons.memory_rounded, size: 14, color: SepiaTheme.sage),
                label: Text(
                  'Switch to Gemma 4 int4 & Run',
                  style: SepiaTheme.mono(fontSize: 11, fontWeight: FontWeight.w700, color: SepiaTheme.sage),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  side: const BorderSide(color: SepiaTheme.sage),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
              ),
              OutlinedButton.icon(
                onPressed: () {
                  widget.onOverrideChanged(RouterModeOverride.enforceCloudFlash);
                  final prompt = msg.rawOriginalPrompt;
                  if (prompt != null && prompt.isNotEmpty) {
                    widget.onSendMessage(prompt);
                  }
                },
                icon: const Icon(Icons.cloud_outlined, size: 14, color: SepiaTheme.amber),
                label: Text(
                  'Escalate to Cloud Gemini 3.8 Flash',
                  style: SepiaTheme.mono(fontSize: 11, fontWeight: FontWeight.w700, color: SepiaTheme.amber),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  side: const BorderSide(color: SepiaTheme.amber),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFallbackNoticeBanner({
    required String reason,
    bool isCloudEscalation = false,
  }) {
    final title = isCloudEscalation
        ? 'LOCAL FALLBACK ACTIVE // ESCALATED TO GOOGLE CLOUD'
        : 'LOCAL ON-DEVICE FALLBACK // 0.0 KB CLOUD EGRESS';
    final icon = isCloudEscalation ? Icons.cloud_outlined : Icons.memory_rounded;
    final accentColor = isCloudEscalation ? SepiaTheme.amber : SepiaTheme.sage;
    final bgColor = isCloudEscalation ? SepiaTheme.amberBg : SepiaTheme.sageBg;
    final borderColor = isCloudEscalation ? SepiaTheme.amberBorder : SepiaTheme.sageBorder;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: borderColor, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: accentColor),
              const SizedBox(width: 6),
              Text(
                title,
                style: SepiaTheme.mono(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: accentColor,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            reason,
            style: SepiaTheme.sans(
              fontSize: 11,
              color: SepiaTheme.ink,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPiiDraftNotice() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      color: SepiaTheme.sageBg,
      child: Row(
        children: [
          const Icon(Icons.shield_outlined, size: 14, color: SepiaTheme.sage),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'Privacy Guard Active: Detected ${_detectedPiiInDraft.length} sensitive entity (${_detectedPiiInDraft.first}). Will execute 100% on-device with zero cloud egress.',
              style: SepiaTheme.mono(fontSize: 10, fontWeight: FontWeight.w600, color: SepiaTheme.sage),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPromptInputBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: SepiaTheme.canvas,
        border: Border(top: BorderSide(color: SepiaTheme.border)),
      ),
      child: MarkdownPromptEditor(
        controller: _promptController,
        onSubmit: _submit,
        isGenerating: widget.isGenerating,
        estimatedTokens: _estimatedTokens,
        hintText: 'Type prompt... (markdown supported: **bold**, `code`, ```blocks```, lists; regex detects PII & tokens)',
      ),
    );
  }
}
