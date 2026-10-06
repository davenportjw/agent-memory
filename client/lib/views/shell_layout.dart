import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../models/message.dart';
import '../models/routing_decision.dart';
import '../models/episodic_turn.dart';
import '../services/switching_router_service.dart';
import '../services/gemma_edge_service.dart';
import '../services/local_execution_manager.dart';
import '../services/cloud_sse_client.dart';
import '../services/local_memory_service.dart';
import '../theme/sepia_theme.dart';
import 'center_workspace.dart';
import 'right_drawer_panel.dart';
import 'memory_lifecycle_studio.dart';
import 'device_test_bench.dart';
import 'policy_matrix_view.dart';
import 'feature_synthesizer_view.dart';
import 'lorecraft_studio.dart';
import 'lorecraft_boot_page_view.dart';
import '../services/lorecraft_service.dart';

enum ShellNavDestination {
  loreCraftStudio,
  bootSequence,
  assistant,
  memoryStudio,
  modelTestBench,
  switchingPolicy,
  featureSynthesizer,
}

class ShellLayout extends StatefulWidget {
  const ShellLayout({super.key});

  @override
  State<ShellLayout> createState() => _ShellLayoutState();
}

class _ShellLayoutState extends State<ShellLayout> {
  ShellNavDestination _currentDestination = ShellNavDestination.loreCraftStudio;
  bool _isRightDrawerOpen = true;
  bool _isLeftRailCollapsed = false;

  // Services
  final SwitchingRouterService _routerService = SwitchingRouterService();
  final GemmaEdgeService _gemmaService = GemmaEdgeService();
  late final LocalExecutionManager _edgeManager = LocalExecutionManager(gemmaService: _gemmaService);
  final CloudSseClient _cloudClient = CloudSseClient();
  final LocalMemoryService _memoryService = LocalMemoryService();
  late final LoreCraftService _loreCraftService = LoreCraftService(
    routerService: _routerService,
    edgeManager: _edgeManager,
    cloudClient: _cloudClient,
    memoryService: _memoryService,
  );

  // Chat State
  final List<ChatMessage> _messages = [];
  bool _isGenerating = false;
  IntentPillData? _selectedPill;
  ExecutionTelemetry? _latestTelemetry;
  bool _isCloudReachable = true;

  @override
  void initState() {
    super.initState();
    _checkCloudHealth();
    _edgeManager.addListener(_onEdgeManagerChanged);
    _edgeManager.init();
  }

  void _onEdgeManagerChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _edgeManager.removeListener(_onEdgeManagerChanged);
    super.dispose();
  }

  Future<void> _checkCloudHealth() async {
    try {
      final client = http.Client();
      final res = await client.get(Uri.parse('${_cloudClient.baseUrl}/health')).timeout(const Duration(seconds: 3));
      if (mounted) {
        setState(() {
          _isCloudReachable = res.statusCode == 200;
        });
      }
      client.close();
    } catch (_) {
      if (mounted) {
        setState(() {
          _isCloudReachable = false;
        });
      }
    }
  }

  Future<void> _handleCreateLanguageModel() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('⚡ Initializing Gemini Nano session in Chrome...'),
        duration: Duration(seconds: 3),
      ),
    );
    final success = await _edgeManager.createLanguageModel();
    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Gemini Nano initialized successfully! Active on-device for 0 KB egress inference.'),
            backgroundColor: SepiaTheme.sage,
            duration: Duration(seconds: 4),
          ),
        );
      } else {
        final err = _edgeManager.creationError ?? 'Failed to initialize Gemini Nano in Chrome.';
        final firstLine = err.split('\n').first;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('⚠️ $firstLine'),
            backgroundColor: SepiaTheme.terracotta,
            duration: const Duration(seconds: 8),
            action: SnackBarAction(
              label: 'Details',
              textColor: Colors.white,
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    backgroundColor: SepiaTheme.paper,
                    title: Row(
                      children: [
                        const Icon(Icons.info_outline, color: SepiaTheme.amber, size: 20),
                        const SizedBox(width: 8),
                        Text('Gemini Nano Setup Details', style: SepiaTheme.sans(fontWeight: FontWeight.w700, fontSize: 16)),
                      ],
                    ),
                    content: SelectableText(err, style: SepiaTheme.mono(fontSize: 12, height: 1.4)),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: Text('Close', style: SepiaTheme.sans(fontWeight: FontWeight.w600, color: SepiaTheme.ink)),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      }
    }
  }

  Future<void> _handleSendMessage(String prompt) async {
    final userMsg = ChatMessage(
      id: 'msg-${DateTime.now().millisecondsSinceEpoch}',
      sender: MessageSender.user,
      text: prompt,
      timestamp: DateTime.now(),
    );

    setState(() {
      _messages.add(userMsg);
      _isGenerating = true;
    });

    // 1. Evaluate routing policy
    final eval = _routerService.evaluateRoute(
      prompt: prompt,
      isNetworkOnline: _isCloudReachable,
    );

    // Refresh edge capabilities
    await _edgeManager.init();

    final isEdge = eval.route == ExecutionRoute.EDGE_LOCAL || eval.route == ExecutionRoute.EDGE_FALLBACK;
    final activeModelName = isEdge ? _edgeManager.activeEngineName : 'Gemini 3.8 Flash';

    final pillData = IntentPillData(
      id: 'pill-${DateTime.now().millisecondsSinceEpoch}',
      intentLabel: isEdge ? '${eval.intentLabel} [$activeModelName]' : eval.intentLabel,
      justificationRule: '${eval.ruleId}: ${eval.justification}',
      memoryDelta: eval.memoryDelta,
      route: eval.route,
      ruleId: eval.ruleId,
      detectedPii: eval.detectedPii,
      tokenCount: eval.estimatedTokens,
      timestamp: DateTime.now(),
      metadata: {'model': activeModelName, 'engine': activeModelName},
    );

    final assistantMsg = ChatMessage(
      id: 'resp-${DateTime.now().millisecondsSinceEpoch}',
      sender: MessageSender.assistant,
      text: '',
      timestamp: DateTime.now(),
      isStreaming: true,
      intentPill: pillData,
      rawOriginalPrompt: prompt,
    );

    setState(() {
      _messages.add(assistantMsg);
      _selectedPill = assistantMsg.intentPill;
    });

    // 2. Dispatch execution
    if (isEdge) {
      // Local Edge On-Device execution (Gemini Nano or Gemma 4 via LocalExecutionManager)
      try {
        final stream = _edgeManager.executeOnDevice(
          prompt: prompt,
          onComplete: (telemetry) {
            setState(() {
              assistantMsg.telemetry = telemetry;
              assistantMsg.isStreaming = false;
              assistantMsg.isFallback = telemetry.isFallback;
              assistantMsg.fallbackReason = telemetry.fallbackReason;

              // Dynamically update the intent pill to reflect true executed model and fallback status
              if (assistantMsg.intentPill != null) {
                final executedModel = telemetry.modelName;
                final updatedLabel = telemetry.isFallback
                    ? '${eval.intentLabel} [$executedModel - Fallback]'
                    : '${eval.intentLabel} [$executedModel]';

                final updatedPill = assistantMsg.intentPill!.copyWith(
                  intentLabel: updatedLabel,
                  isFallback: telemetry.isFallback,
                  fallbackReason: telemetry.fallbackReason,
                  metadata: {
                    ...assistantMsg.intentPill!.metadata,
                    'executedModel': executedModel,
                    'isFallback': telemetry.isFallback,
                    if (telemetry.fallbackReason != null) 'fallbackReason': telemetry.fallbackReason,
                  },
                );
                assistantMsg.intentPill = updatedPill;
                _selectedPill = updatedPill;
              }

              _latestTelemetry = telemetry;
              _isGenerating = false;
            });
          },
          onError: (errMsg) {
            setState(() {
              assistantMsg.text = '⚠️ Chrome Built-in AI (Gemini Nano) Notice:\n\n'
                  '$errMsg\n\n'
                  '💡 Quick demo option: You can switch to on-device "Gemma 4 int4" in the top header bar to run locally right now!';
              assistantMsg.isStreaming = false;
              _isGenerating = false;
            });
          },
        );

        await for (final token in stream) {
          setState(() {
            assistantMsg.text += token;
          });
        }
      } catch (e) {
        setState(() {
          if (assistantMsg.text.isEmpty) {
            assistantMsg.text = '⚠️ Local Inference Failure: $e';
          }
          assistantMsg.isStreaming = false;
          _isGenerating = false;
        });
      }
    } else {
      // Cloud Gemini 3.8 Flash execution
      final anchors = _memoryService.activeEdgeBundle?.anchors ?? [];
      final promptToSend = eval.requiresRedaction
          ? _routerService.scrubPii(prompt)
          : prompt;

      final stream = _cloudClient.streamCloudCompletion(
        prompt: promptToSend,
        injectedAnchors: anchors,
        onComplete: (telemetry) {
          _routerService.recordCloudSuccess();
          setState(() {
            assistantMsg.telemetry = telemetry;
            assistantMsg.isStreaming = false;
            assistantMsg.isFallback = telemetry.isFallback;
            assistantMsg.fallbackReason = telemetry.fallbackReason;

            if (assistantMsg.intentPill != null) {
              final executedModel = telemetry.modelName;
              final updatedPill = assistantMsg.intentPill!.copyWith(
                intentLabel: '${eval.intentLabel} [$executedModel]',
                metadata: {
                  ...assistantMsg.intentPill!.metadata,
                  'executedModel': executedModel,
                },
              );
              assistantMsg.intentPill = updatedPill;
              _selectedPill = updatedPill;
            }

            _latestTelemetry = telemetry;
            _isGenerating = false;
          });
        },
        onError: (err) {
          _routerService.recordCloudFailure();
          setState(() {
            assistantMsg.text = '⚠️ Cloud Execution Error: $err';
            assistantMsg.isStreaming = false;
            _isGenerating = false;
          });
        },
      );

      try {
        await for (final token in stream) {
          setState(() {
            assistantMsg.text += token;
          });
        }
      } catch (e) {
        setState(() {
          assistantMsg.isStreaming = false;
          _isGenerating = false;
        });
      }
    }

    // 3. Stage 1 Memory Pipeline: Commit episodic turn to local working context
    final turn = EpisodicTurn(
      id: 'turn-${DateTime.now().millisecondsSinceEpoch}',
      sessionId: 'session-main',
      timestamp: DateTime.now(),
      userPrompt: prompt,
      modelResponse: assistantMsg.text,
      route: eval.route.key,
      modelName: activeModelName,
      latencyMs: assistantMsg.telemetry?.totalLatencyMs ?? 0,
      ttftMs: assistantMsg.telemetry?.ttftMs ?? 0,
      isPiiSanitized: eval.requiresRedaction,
      entitiesExtracted: [],
    );
    _memoryService.commitTurn(turn);
  }

  void _onPillSelected(IntentPillData pill) {
    setState(() {
      _selectedPill = pill;
      _isRightDrawerOpen = true; // Auto-open drawer to inspect
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isCompact = screenWidth < 900;

    if (isCompact) {
      return Scaffold(
        backgroundColor: SepiaTheme.canvas,
        drawer: Drawer(
          backgroundColor: SepiaTheme.canvas,
          child: SafeArea(child: _buildLeftNavRail(isModal: true)),
        ),
        endDrawer: Drawer(
          width: 320,
          backgroundColor: SepiaTheme.paper,
          child: SafeArea(
            child: RightDrawerPanel(
              selectedPill: _selectedPill,
              latestTelemetry: _latestTelemetry,
              recalledAnchors: _memoryService.activeEdgeBundle?.anchors ?? [],
              circuitBreakerState: _routerService.circuitBreakerState,
              consecutiveFailures: _routerService.consecutiveFailures,
              onResetCircuitBreaker: () {
                setState(() => _routerService.resetCircuitBreaker());
              },
              onToggleDrawer: () {
                Navigator.of(context).maybePop();
              },
            ),
          ),
        ),
        body: _buildCenterBody(),
      );
    }

    return Scaffold(
      backgroundColor: SepiaTheme.canvas,
      body: Row(
        children: [
          // 1. Left Navigation Rail (fixed 240px)
          _buildLeftNavRail(),

          // 2. Center Workspace (flex)
          Expanded(
            child: _buildCenterBody(),
          ),

          // 3. Right Expandable Drawer (collapsible 320px)
          if (_isRightDrawerOpen)
            RightDrawerPanel(
              selectedPill: _selectedPill,
              latestTelemetry: _latestTelemetry,
              recalledAnchors: _memoryService.activeEdgeBundle?.anchors ?? [],
              circuitBreakerState: _routerService.circuitBreakerState,
              consecutiveFailures: _routerService.consecutiveFailures,
              onResetCircuitBreaker: () {
                setState(() => _routerService.resetCircuitBreaker());
              },
              onToggleDrawer: () {
                setState(() => _isRightDrawerOpen = false);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildLeftNavRail({bool isModal = false}) {
    final isCollapsed = !isModal && _isLeftRailCollapsed;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      width: isModal ? double.infinity : (isCollapsed ? 68 : 240),
      decoration: BoxDecoration(
        color: SepiaTheme.canvas,
        border: isModal
            ? null
            : const Border(
                right: BorderSide(color: SepiaTheme.border, width: 1),
              ),
      ),
      child: ClipRect(
        child: OverflowBox(
          alignment: Alignment.topLeft,
          minWidth: isCollapsed ? 68 : 240,
          maxWidth: isCollapsed ? 68 : 240,
          child: SizedBox(
            width: isCollapsed ? 68 : 240,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Rail Header
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: isCollapsed ? 8 : 16,
              vertical: isCollapsed ? 12 : 18,
            ),
            decoration: const BoxDecoration(
              color: SepiaTheme.paper,
              border: Border(bottom: BorderSide(color: SepiaTheme.border)),
            ),
            child: isCollapsed
                ? Column(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: SepiaTheme.ink,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Center(
                          child: Text(
                            'AG',
                            style: TextStyle(
                              fontFamily: SepiaTheme.fontMono,
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                              color: SepiaTheme.canvas,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      IconButton(
                        key: const Key('btn_expand_shell_nav_rail'),
                        icon: const Icon(Icons.chevron_right_rounded, size: 20, color: SepiaTheme.ink),
                        tooltip: 'Expand navigation rail',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        splashRadius: 16,
                        onPressed: () => setState(() => _isLeftRailCollapsed = false),
                      ),
                    ],
                  )
                : Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: SepiaTheme.ink,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Center(
                          child: Text(
                            'AG',
                            style: TextStyle(
                              fontFamily: SepiaTheme.fontMono,
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                              color: SepiaTheme.canvas,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'ANTIGRAVITY',
                              style: SepiaTheme.sans(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                              ),
                            ),
                            Text(
                              'DISTRIBUTED AI // CLIENT',
                              style: SepiaTheme.mono(
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                                color: SepiaTheme.inkMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (!isModal)
                        IconButton(
                          key: const Key('btn_collapse_shell_nav_rail'),
                          icon: const Icon(Icons.chevron_left_rounded, size: 20, color: SepiaTheme.inkMuted),
                          tooltip: 'Collapse navigation rail',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          splashRadius: 16,
                          onPressed: () => setState(() => _isLeftRailCollapsed = true),
                        ),
                    ],
                  ),
          ),

          // Nav Items List
          Expanded(
            child: ListView(
              padding: EdgeInsets.symmetric(
                vertical: 12,
                horizontal: isCollapsed ? 6 : 8,
              ),
              children: [
                _buildNavItem(
                  destination: ShellNavDestination.loreCraftStudio,
                  title: 'LoreCraft Studio',
                  subtitle: 'Distributed dynamic world',
                  icon: Icons.auto_stories_rounded,
                  badge: 'PRIMARY',
                  isModal: isModal,
                ),
                const SizedBox(height: 4),
                _buildNavItem(
                  destination: ShellNavDestination.bootSequence,
                  title: 'Edge Agent Boot',
                  subtitle: 'Context hydration & map',
                  icon: Icons.bolt_rounded,
                  badge: 'PHASE 1',
                  isModal: isModal,
                ),
                const SizedBox(height: 4),
                _buildNavItem(
                  destination: ShellNavDestination.assistant,
                  title: 'Assistant Workspace',
                  subtitle: 'Dual execution stream',
                  icon: Icons.chat_bubble_outline_rounded,
                  isModal: isModal,
                ),
                const SizedBox(height: 4),
                _buildNavItem(
                  destination: ShellNavDestination.memoryStudio,
                  title: 'Memory Studio',
                  subtitle: '4-stage online/offline loop',
                  icon: Icons.account_tree_outlined,
                  badge: '${_memoryService.durableNodes.length} nodes',
                  isModal: isModal,
                ),
                const SizedBox(height: 4),
                _buildNavItem(
                  destination: ShellNavDestination.modelTestBench,
                  title: 'Model Test Bench',
                  subtitle: 'Multi-model prompt comparison & ratings',
                  icon: Icons.speed_rounded,
                  isModal: isModal,
                ),
                const SizedBox(height: 4),
                _buildNavItem(
                  destination: ShellNavDestination.switchingPolicy,
                  title: 'Switching Policy',
                  subtitle: 'Declarative rules matrix',
                  icon: Icons.rule_rounded,
                  isModal: isModal,
                ),
                const SizedBox(height: 4),
                _buildNavItem(
                  destination: ShellNavDestination.featureSynthesizer,
                  title: 'Feature Synthesizer',
                  subtitle: 'Memory sandbox builder',
                  icon: Icons.extension_outlined,
                  isModal: isModal,
                ),
              ],
            ),
          ),

          // Bottom Telemetry & Status Footer
          Container(
            padding: EdgeInsets.all(isCollapsed ? 8 : 12),
            decoration: const BoxDecoration(
              color: SepiaTheme.paper,
              border: Border(top: BorderSide(color: SepiaTheme.border)),
            ),
            child: Builder(
              builder: (context) {
                final isCloudOnline = _isCloudReachable && _routerService.circuitBreakerState != CircuitBreakerState.OPEN;

                Color edgeDotColor;
                String edgeLabelText;

                if (_edgeManager.activeEngine == ActiveEdgeEngine.geminiNano) {
                  if (_edgeManager.isGeminiNanoActive) {
                    edgeDotColor = SepiaTheme.sage;
                    edgeLabelText = 'Gemini Nano: Active (0 KB)';
                  } else if (_edgeManager.isCreatingModel) {
                    edgeDotColor = SepiaTheme.terracotta;
                    edgeLabelText = 'Gemini Nano: Initializing...';
                  } else if (_edgeManager.isGeminiNanoNeedsDownload) {
                    edgeDotColor = SepiaTheme.amber;
                    edgeLabelText = 'Gemini Nano: Weights Pending';
                  } else if (_edgeManager.isGeminiNanoAvailable) {
                    edgeDotColor = SepiaTheme.amber;
                    edgeLabelText = 'Gemini Nano: Flag Set (Unready)';
                  } else {
                    edgeDotColor = SepiaTheme.inkMuted;
                    edgeLabelText = 'Gemini Nano: Flag Needed';
                  }
                } else {
                  if (_edgeManager.selectedEngine == EdgeEngineSelection.auto && !_edgeManager.isGeminiNanoActive) {
                    edgeDotColor = SepiaTheme.sage;
                    edgeLabelText = _gemmaService.isWebGPUAvailable
                        ? 'Gemma 4: WebGPU (Auto Fallback)'
                        : 'Gemma 4: LiteRT (Auto Fallback)';
                  } else {
                    edgeDotColor = _gemmaService.isWebGPUAvailable ? SepiaTheme.sage : SepiaTheme.amber;
                    edgeLabelText = _gemmaService.isWebGPUAvailable
                        ? 'Gemma 4: WebGPU Active'
                        : 'Gemma 4: LiteRT CPU';
                  }
                }

                if (isCollapsed) {
                  return Column(
                    children: [
                      Tooltip(
                        message: edgeLabelText,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: edgeDotColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Tooltip(
                        message: isCloudOnline ? 'Gemini 3.8 Flash: Live' : 'Gemini 3.8 Flash: Degraded',
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: isCloudOnline ? SepiaTheme.sage : SepiaTheme.terracotta,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ],
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: edgeDotColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            edgeLabelText,
                            overflow: TextOverflow.ellipsis,
                            style: SepiaTheme.mono(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: edgeDotColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: isCloudOnline ? SepiaTheme.sage : SepiaTheme.terracotta,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            isCloudOnline ? 'Gemini 3.8 Flash: Live' : 'Gemini 3.8 Flash: Degraded',
                            overflow: TextOverflow.ellipsis,
                            style: SepiaTheme.mono(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: isCloudOnline ? SepiaTheme.sage : SepiaTheme.terracotta,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required ShellNavDestination destination,
    required String title,
    required String subtitle,
    required IconData icon,
    String? badge,
    bool isModal = false,
  }) {
    final isSelected = _currentDestination == destination;
    final isCollapsed = !isModal && _isLeftRailCollapsed;

    if (isCollapsed) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Tooltip(
          message: '$title\n$subtitle${badge != null ? " [$badge]" : ""}',
          waitDuration: const Duration(milliseconds: 200),
          child: InkWell(
            onTap: () {
              setState(() => _currentDestination = destination);
              if (isModal) {
                Navigator.of(context).maybePop();
              }
            },
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isSelected ? SepiaTheme.paper : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isSelected ? SepiaTheme.border : Colors.transparent,
                ),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(
                    icon,
                    size: 20,
                    color: isSelected ? SepiaTheme.ink : SepiaTheme.inkMuted,
                  ),
                  if (badge != null)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: SepiaTheme.amber,
                          shape: BoxShape.circle,
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

    return InkWell(
      onTap: () {
        setState(() => _currentDestination = destination);
        if (isModal) {
          Navigator.of(context).maybePop();
        }
      },
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? SepiaTheme.paper : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected ? SepiaTheme.border : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? SepiaTheme.ink : SepiaTheme.inkMuted,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: SepiaTheme.sans(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected ? SepiaTheme.ink : SepiaTheme.inkSecondary,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: SepiaTheme.sans(
                      fontSize: 10,
                      color: SepiaTheme.inkMuted,
                    ),
                  ),
                ],
              ),
            ),
            if (badge != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: SepiaTheme.paperSubtle,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: SepiaTheme.borderSubtle),
                ),
                child: Text(
                  badge,
                  style: SepiaTheme.mono(fontSize: 9, color: SepiaTheme.inkMuted),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCenterBody() {
    switch (_currentDestination) {
      case ShellNavDestination.loreCraftStudio:
        return LoreCraftStudio(loreService: _loreCraftService);
      case ShellNavDestination.bootSequence:
        return LoreCraftBootPageView(
          loreService: _loreCraftService,
          memoryService: _memoryService,
        );
      case ShellNavDestination.assistant:
        return CenterWorkspace(
          messages: _messages,
          isGenerating: _isGenerating,
          currentOverride: _routerService.modeOverride,
          onOverrideChanged: (mode) => setState(() => _routerService.modeOverride = mode),
          onSendMessage: _handleSendMessage,
          selectedPill: _selectedPill,
          onPillSelected: _onPillSelected,
          onToggleDrawer: () => setState(() => _isRightDrawerOpen = !_isRightDrawerOpen),
          isDrawerOpen: _isRightDrawerOpen,
          onClearChat: () => setState(() => _messages.clear()),
          activeEdgeEngineName: _edgeManager.activeEngineName,
          edgeManager: _edgeManager,
          onEngineChanged: (engine) {
            setState(() {
              _edgeManager.selectedEngine = engine;
            });
          },
          onCreateLanguageModel: _handleCreateLanguageModel,
        );
      case ShellNavDestination.memoryStudio:
        return MemoryLifecycleStudio(memoryService: _memoryService);
      case ShellNavDestination.modelTestBench:
        return const DeviceTestBench();
      case ShellNavDestination.switchingPolicy:
        return const PolicyMatrixView();
      case ShellNavDestination.featureSynthesizer:
        return FeatureSynthesizerView(memoryService: _memoryService);
    }
  }
}
