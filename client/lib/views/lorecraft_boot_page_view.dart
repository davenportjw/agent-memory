import 'package:flutter/material.dart';
import '../services/lorecraft_service.dart';
import '../services/local_memory_service.dart';
import '../services/audio_feedback_service.dart';
import '../models/edge_memory_architecture.dart';
import '../theme/sepia_theme.dart';
import '../services/app_mode_service.dart';
import 'widgets/education_assessment_card.dart';

/// LoreCraftBootPageView:
/// First-run entry page highlighting the 4-phase edge memory architecture:
/// 1. On-Load (The Boot State)
/// 2. Conditionally (Just-In-Time Context)
/// 3. Pre-Emptive Caching (The Predictive Load)
/// 4. Asynchronous Syncs (The "Morning After")
class LoreCraftBootPageView extends StatefulWidget {
  final LoreCraftService loreService;
  final LocalMemoryService memoryService;

  const LoreCraftBootPageView({
    super.key,
    required this.loreService,
    required this.memoryService,
  });

  @override
  State<LoreCraftBootPageView> createState() => _LoreCraftBootPageViewState();
}

class _LoreCraftBootPageViewState extends State<LoreCraftBootPageView> {
  bool _isPerformingAction = false;
  String? _statusBannerMessage;
  String? _selectedTopicId;
  String? _selectedTopicContent;
  String? _selectedTopicTitle;

  @override
  void initState() {
    super.initState();
    widget.memoryService.addListener(_onServiceUpdate);
    widget.loreService.addListener(_onServiceUpdate);

    // If not booted yet, trigger initial boot
    if (!widget.memoryService.bootState.isBooted) {
      widget.memoryService.bootEdgeAgent();
    } else {
      widget.memoryService.syncPlatformTelemetry();
    }
  }

  @override
  void dispose() {
    widget.memoryService.removeListener(_onServiceUpdate);
    widget.loreService.removeListener(_onServiceUpdate);
    super.dispose();
  }

  void _onServiceUpdate() {
    if (mounted) setState(() {});
  }

  Future<void> _handleToolFetch(String topicId) async {
    AudioFeedbackService.instance.playClick();
    setState(() {
      _isPerformingAction = true;
      _statusBannerMessage = 'Executing tool call: fetch_memory_topic(topic_id="$topicId")...';
    });
    try {
      final topic = await widget.memoryService.fetchMemoryTopic(topicId);
      setState(() {
        _selectedTopicId = topic.topicId;
        _selectedTopicTitle = topic.title;
        _selectedTopicContent = topic.fullContent;
        _statusBannerMessage = 'Loaded "${topic.title}" (${topic.byteSize} B, ~${topic.tokenEstimate} tokens) into local cache.';
      });
    } catch (e) {
      setState(() {
        _statusBannerMessage = 'Fetch failed: $e';
      });
    } finally {
      if (mounted) {
        setState(() => _isPerformingAction = false);
      }
    }
  }

  void _handleToolEvict(String topicId) {
    AudioFeedbackService.instance.playEvictPulse();
    final topic = widget.memoryService.localTopicCache[topicId];
    final title = topic?.title ?? topicId;
    final evicted = widget.memoryService.evictMemoryTopic(topicId);
    if (evicted) {
      setState(() {
        if (_selectedTopicId == topicId) {
          _selectedTopicId = null;
          _selectedTopicTitle = null;
          _selectedTopicContent = null;
        }
        _statusBannerMessage = 'Evicted "$title" from local edge cache.';
      });
    }
  }

  void _handleEvictAllTopics() {
    AudioFeedbackService.instance.playEvictPulse();
    final count = widget.memoryService.evictAllLocalTopics();
    setState(() {
      _selectedTopicId = null;
      _selectedTopicTitle = null;
      _selectedTopicContent = null;
      _statusBannerMessage = 'Evicted $count cached topic(s) from local edge memory.';
    });
  }

  Future<void> _handleExecuteBoundTask() async {
    AudioFeedbackService.instance.playClick();
    setState(() {
      _isPerformingAction = true;
      _statusBannerMessage = 'Workflow initiated: Injecting "undercity_sluice_bypass" into task context...';
    });

    try {
      await widget.memoryService.executeTaskWithBoundContext<String>(
        taskId: 'task-sluice-breach-triage',
        taskName: 'Undercity Sluice Breach Triage',
        topicIds: ['undercity_sluice_bypass'],
        action: () async {
          await Future.delayed(const Duration(milliseconds: 300));
          return 'Bypass valves calibrated successfully.';
        },
      );
      AudioFeedbackService.instance.playEvictPulse();
      setState(() {
        _statusBannerMessage = 'Task completed! Injected context was evicted immediately. Edge context restored to base Directives.';
      });
    } catch (e) {
      setState(() {
        _statusBannerMessage = 'Task execution failed: $e';
      });
    } finally {
      if (mounted) {
        setState(() => _isPerformingAction = false);
      }
    }
  }

  Future<void> _handleStatePrefetch(String regionId, String triggerText, List<String> topicIds) async {
    AudioFeedbackService.instance.playClick();
    setState(() {
      _isPerformingAction = true;
      _statusBannerMessage = 'Detecting state shift: "$triggerText"... Updating predictive edge cache...';
    });

    try {
      final event = await widget.memoryService.triggerStatePrefetch(
        sceneId: regionId,
        stateTrigger: triggerText,
        topicIds: topicIds,
      );
      final evictText = event.evictedTopicIds.isNotEmpty
          ? ' Evicted ${event.evictedTopicIds.length} previous scene file(s) (${event.bytesEvicted} B).'
          : '';
      setState(() {
        _statusBannerMessage = 'PREFETCH COMPLETE: Cached ${event.bytesCached} B in ${event.latencyMs}ms.$evictText Zero-latency 0ms local query readiness confirmed.';
      });
    } catch (e) {
      setState(() {
        _statusBannerMessage = 'Prefetch error: $e';
      });
    } finally {
      if (mounted) {
        setState(() => _isPerformingAction = false);
      }
    }
  }

  Future<void> _handleDreamDeltaSync() async {
    AudioFeedbackService.instance.playChime();
    setState(() {
      _isPerformingAction = true;
      _statusBannerMessage = 'Connecting to Cloud Dream Daemon overnight delta endpoint (03:00 AM Sync)...';
    });

    try {
      final delta = await widget.memoryService.applyDreamDeltaSync();
      setState(() {
        _statusBannerMessage = 'DREAM SYNC APPLIED: Master Index updated to v${delta.newMasterIndexVersion}. Purged ${delta.invalidatedCachedTopicIds.length} stale cache file(s).';
      });
    } catch (e) {
      setState(() {
        _statusBannerMessage = 'Dream sync error: $e';
      });
    } finally {
      if (mounted) {
        setState(() => _isPerformingAction = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppModeService(),
      builder: (context, _) {
        final bootState = widget.memoryService.bootState;
        final env = widget.memoryService.environmentalState;
        final directives = widget.memoryService.coreDirectives;
        final masterIndex = widget.memoryService.masterIndex;
        final taskContext = widget.memoryService.activeTaskContext;

        return Container(
          color: SepiaTheme.canvas,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. TOP HEADER & TELEMETRY STRIP
                _buildTopHeader(),
                const SizedBox(height: 14),
                _buildHardwareTelemetryBar(bootState, env),
                if (_statusBannerMessage != null) ...[
                  const SizedBox(height: 12),
                  _buildLiveStatusBanner(),
                ],
                const SizedBox(height: 18),

                // 2. THE 4 ARCHITECTURE PATTERNS
                _buildPattern1Card(bootState, directives, masterIndex),
                const SizedBox(height: 16),
                _buildPattern2Card(masterIndex, taskContext),
                const SizedBox(height: 16),
                _buildPattern3Card(),
                const SizedBox(height: 16),
                _buildPattern4Card(masterIndex),
                const SizedBox(height: 20),

                // 3. EASY-TO-DIGEST EDUCATIONAL EFFICACY RATER (Everything Mode Only)
                if (!AppModeService().isSimple) ...[
                  EducationAssessmentCard(memoryService: widget.memoryService),
                  const SizedBox(height: 24),
                ],

                // 4. PRIMARY CALL TO ACTION
                _buildBottomActionCta(),
                const SizedBox(height: 32),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTopHeader() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: SepiaTheme.paper,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: SepiaTheme.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: SepiaTheme.amberBg,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: SepiaTheme.amberBorder),
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 300),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.bolt, size: 14, color: SepiaTheme.amber),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          'PHASE 1 // ON-LOAD BOOT ARCHITECTURE',
                          style: SepiaTheme.mono(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: SepiaTheme.amber,
                            letterSpacing: 0.5,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: SepiaTheme.paperSubtle,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: SepiaTheme.borderSubtle),
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 280),
                  child: Text(
                    'EDGE LLM CONTEXT HYDRATION',
                    style: SepiaTheme.mono(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: SepiaTheme.inkMuted,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'ENVOY EDGE BOOT ARCHITECTURE',
            style: SepiaTheme.sans(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: SepiaTheme.ink,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Minimum Context Hydration & Lifecycle Governance for Gemma 4 int4 on ${widget.memoryService.environmentalState.hardwareEngine.contains("Android") ? "Android LiteRT" : "Apple Silicon"}. '
            'Rather than loading monolithic memory blobs, the Envoy edge agent loads only the minimal operational triad: '
            'Core Directives, the Cloud Dream Master Index TOC, and Local Hardware Environment. All semantic knowledge is paged conditionally, '
            'cached predictively on state shifts, and reconciled asynchronously via 3 AM Cloud Dream Deltas.',
            style: SepiaTheme.sans(
              fontSize: 13,
              height: 1.45,
              color: SepiaTheme.inkSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHardwareTelemetryBar(AgentBootState bootState, LocalEnvironmentalState env) {
    final isWithinBudget = bootState.isWithinBootBudget;
    final policy = bootState.routingPolicy;

    final isLowBattery = env.batteryLevel <= 0.15;
    final isOffline = env.networkStatus == 'OFFLINE_AIRGAPPED' || env.networkStatus == 'OFFLINE_PARTITIONED';
    final isAudioMuted = AudioFeedbackService.instance.isMuted;

    final policyColor = policy == EdgeRoutingPolicy.fullPerformance
        ? SepiaTheme.sage
        : SepiaTheme.terracotta;
    final policyBg = policy == EdgeRoutingPolicy.fullPerformance
        ? SepiaTheme.sageBg
        : SepiaTheme.terracottaBg;
    final policyBorder = policy == EdgeRoutingPolicy.fullPerformance
        ? SepiaTheme.sageBorder
        : SepiaTheme.terracottaBorder;

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
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // Battery interactive toggle / live sync
              _buildInteractiveTelemetryPill(
                key: const Key('btn_toggle_battery_sim'),
                icon: isLowBattery ? Icons.battery_alert : (env.isCharging ? Icons.battery_charging_full : Icons.battery_std),
                label: isLowBattery
                    ? 'BATTERY: ${(env.batteryLevel * 100).toInt()}% [LOW POWER]'
                    : 'BATTERY: ${(env.batteryLevel * 100).toInt()}% (${env.isCharging ? "AC" : "BATT"})',
                color: isLowBattery ? SepiaTheme.terracotta : SepiaTheme.sage,
                tooltip: widget.memoryService.isUsingPlatformTelemetry
                    ? 'Live Android OS Battery (${(env.batteryLevel * 100).toInt()}%). Tap to refresh.'
                    : 'Tap to toggle low-battery (<15%) simulation',
                onTap: () {
                  AudioFeedbackService.instance.playClick();
                  if (widget.memoryService.isUsingPlatformTelemetry) {
                    widget.memoryService.syncPlatformTelemetry().then((_) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('⚡ Live Android Telemetry: Battery ${(widget.memoryService.environmentalState.batteryLevel * 100).toInt()}% (${widget.memoryService.environmentalState.isCharging ? "AC" : "Battery"})'),
                            backgroundColor: SepiaTheme.sage,
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      }
                    });
                  } else {
                    widget.memoryService.toggleBatterySimulation();
                  }
                },
              ),

              // Network interactive toggle / live sync
              _buildInteractiveTelemetryPill(
                key: const Key('btn_toggle_network_sim'),
                icon: isOffline ? Icons.wifi_off : Icons.wifi,
                label: isOffline
                    ? 'NET: OFFLINE (AIR-GAPPED)'
                    : 'NET: ${env.networkStatus.replaceAll("ONLINE_", "ONLINE (").replaceAll("_", "-") + (env.networkStatus.startsWith("ONLINE_") ? ")" : "")}',
                color: isOffline ? SepiaTheme.terracotta : SepiaTheme.amber,
                tooltip: widget.memoryService.isUsingPlatformTelemetry
                    ? 'Live Android OS Network (${env.networkStatus}). Tap to refresh.'
                    : 'Tap to toggle offline air-gapped simulation',
                onTap: () {
                  AudioFeedbackService.instance.playClick();
                  if (widget.memoryService.isUsingPlatformTelemetry) {
                    widget.memoryService.syncPlatformTelemetry().then((_) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('📡 Live Android Telemetry: Network ${widget.memoryService.environmentalState.networkStatus}'),
                            backgroundColor: SepiaTheme.sage,
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      }
                    });
                  } else {
                    widget.memoryService.toggleNetworkSimulation();
                  }
                },
              ),

              // Audio haptic feedback toggle
              _buildInteractiveTelemetryPill(
                key: const Key('btn_toggle_sound'),
                icon: isAudioMuted ? Icons.volume_off : Icons.volume_up,
                label: isAudioMuted ? 'AUDIO: MUTED' : 'AUDIO: ON',
                color: isAudioMuted ? SepiaTheme.inkMuted : SepiaTheme.sage,
                tooltip: 'Tap to toggle tactile acoustic cues & haptics',
                onTap: () {
                  AudioFeedbackService.instance.toggleMute();
                  setState(() {});
                },
              ),

              // Engine
              _buildTelemetryPill(
                icon: Icons.memory,
                label: env.hardwareEngine,
                color: SepiaTheme.terracotta,
              ),

              // Footprint
              _buildTelemetryPill(
                icon: Icons.straighten,
                label: 'BOOT: ${bootState.bootFootprintBytes} B / 4,096 B',
                color: isWithinBudget ? SepiaTheme.sage : Colors.red,
              ),

              // Budget Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isWithinBudget ? SepiaTheme.sageBg : Colors.red.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: isWithinBudget ? SepiaTheme.sageBorder : Colors.red),
                ),
                child: Text(
                  isWithinBudget ? 'PASSED (< 4 KB)' : 'BUDGET EXCEEDED',
                  style: SepiaTheme.mono(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isWithinBudget ? SepiaTheme.sage : Colors.red,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),
          const Divider(height: 1, color: SepiaTheme.borderSubtle),
          const SizedBox(height: 10),

          // ADAPTIVE EDGE ROUTING POLICY BANNER
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: policyBg,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: policyBorder),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  policy == EdgeRoutingPolicy.fullPerformance
                      ? Icons.offline_bolt_outlined
                      : Icons.warning_amber_rounded,
                  size: 16,
                  color: policyColor,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            'ADAPTIVE ROUTING: ${policy.displayName}',
                            style: SepiaTheme.mono(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: policyColor,
                              letterSpacing: 0.5,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'TRIAGE MODE',
                            style: SepiaTheme.mono(
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              color: SepiaTheme.inkMuted,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        policy.plainEnglishDescription,
                        style: SepiaTheme.sans(
                          fontSize: 12,
                          color: SepiaTheme.ink,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        policy.nextActionGuidance,
                        style: SepiaTheme.sans(
                          fontSize: 11,
                          color: SepiaTheme.inkSecondary,
                          fontStyle: FontStyle.italic,
                        ),
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

  Widget _buildInteractiveTelemetryPill({
    required Key key,
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    required String tooltip,
  }) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 400),
      child: Tooltip(
        message: tooltip,
        child: InkWell(
          key: key,
          onTap: onTap,
          borderRadius: BorderRadius.circular(4),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: color.withValues(alpha: 0.4)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 14, color: color),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    label,
                    style: SepiaTheme.mono(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: SepiaTheme.ink,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTelemetryPill({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 400),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              style: SepiaTheme.mono(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: SepiaTheme.ink,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveStatusBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: SepiaTheme.paperSubtle,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: SepiaTheme.amberBorder),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, size: 16, color: SepiaTheme.amber),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _statusBannerMessage!,
              style: SepiaTheme.mono(
                fontSize: 12,
                color: SepiaTheme.ink,
              ),
            ),
          ),
          if (_isPerformingAction)
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
        ],
      ),
    );
  }

  // PATTERN 1: ON-LOAD (THE BOOT STATE)
  Widget _buildPattern1Card(
    AgentBootState bootState,
    CorePersonaDirectives directives,
    MasterIndex masterIndex,
  ) {
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
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              Text(
                '1. On-Load (The Boot State)',
                style: SepiaTheme.sans(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: SepiaTheme.ink,
                ),
              ),
              ElevatedButton.icon(
                key: const Key('btn_reboot_sequence'),
                onPressed: _isPerformingAction
                    ? null
                    : () {
                        AudioFeedbackService.instance.playChime();
                        widget.memoryService.bootEdgeAgent();
                      },
                icon: const Icon(Icons.refresh, size: 14),
                label: const Text('RE-BOOT EDGE AGENT', style: TextStyle(fontSize: 11)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: SepiaTheme.paperSubtle,
                  foregroundColor: SepiaTheme.ink,
                  elevation: 0,
                  side: const BorderSide(color: SepiaTheme.border),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'When the edge agent spins up, it loads only the absolute minimum context required to triage events and route tasks. '
            'Full historical episodes and heavy semantic documents remain in cloud cold storage.',
            style: SepiaTheme.sans(fontSize: 12, color: SepiaTheme.inkSecondary, height: 1.4),
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 800;
              final items = [
                _buildTriadItem(
                  title: 'Core Directives & Persona',
                  subtitle: '${directives.allocatedTokens} Tokens Allocated',
                  details: 'Prompt ID: "${directives.systemPromptId}". Static behavioral invariants compiled into model runtime.',
                  icon: Icons.psychology,
                  badge: 'STATIC',
                ),
                _buildTriadItem(
                  title: 'Master Index (The "Map")',
                  subtitle: '${masterIndex.calculatedSizeBytes} Bytes • ${masterIndex.totalTopicCount} Topics',
                  details: 'TOC directory from Cloud Dream Daemon v${masterIndex.version}. Knows what it knows without loading full files.',
                  icon: Icons.map,
                  badge: 'COMPRESSED TOC',
                ),
                _buildTriadItem(
                  title: 'Local Environmental State',
                  subtitle: '${widget.memoryService.environmentalState.networkStatus}',
                  details: 'Immediate hardware telemetry: battery, network status, thermal state, and LiteRT WebGPU profile.',
                  icon: Icons.sensors,
                  badge: 'LIVE HARDWARE',
                ),
              ];

              if (isWide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: items.map((w) => Expanded(child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: w,
                  ))).toList(),
                );
              } else {
                return Column(
                  children: items.map((w) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: w,
                  )).toList(),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTriadItem({
    required String title,
    required String subtitle,
    required String details,
    required IconData icon,
    required String badge,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: SepiaTheme.canvas,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: SepiaTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: SepiaTheme.amber),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: SepiaTheme.sans(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: SepiaTheme.ink,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: SepiaTheme.paper,
                  borderRadius: BorderRadius.circular(3),
                  border: Border.all(color: SepiaTheme.borderSubtle),
                ),
                child: Text(
                  badge,
                  style: SepiaTheme.mono(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: SepiaTheme.inkMuted,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: SepiaTheme.mono(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: SepiaTheme.amber,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            details,
            style: SepiaTheme.sans(fontSize: 11, color: SepiaTheme.inkSecondary, height: 1.3),
          ),
        ],
      ),
    );
  }

  // PATTERN 2: CONDITIONALLY (JUST-IN-TIME CONTEXT)
  Widget _buildPattern2Card(MasterIndex masterIndex, TaskBoundContext? taskContext) {
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
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              Text(
                '2. Conditionally (Just-In-Time Context)',
                style: SepiaTheme.sans(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: SepiaTheme.ink,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: SepiaTheme.sageBg,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'TOOL-PAGED CONTEXT',
                  style: SepiaTheme.mono(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: SepiaTheme.sage,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'The vast majority of semantic memory is paged in conditionally. The agent inspects its Master Index and calls '
            'fetch_memory_topic(topic_id) only when a task demands historical context. Context windows are strictly task-bound: '
            'injected memory is evicted immediately upon workflow completion to keep latency and RAM minimal.',
            style: SepiaTheme.sans(fontSize: 12, color: SepiaTheme.inkSecondary, height: 1.4),
          ),
          const SizedBox(height: 14),

          // Action 2A: Tool Fetch
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: SepiaTheme.canvas,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: SepiaTheme.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.build_circle, size: 16, color: SepiaTheme.amber),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Tool-Triggered Fetching (fetch_memory_topic)',
                        style: SepiaTheme.sans(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: SepiaTheme.ink,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (masterIndex.entries.any((e) => widget.memoryService.localTopicCache.containsKey(e.topicId))) ...[
                      InkWell(
                        key: const Key('btn_evict_all_topics'),
                        onTap: _isPerformingAction ? null : _handleEvictAllTopics,
                        borderRadius: BorderRadius.circular(4),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: SepiaTheme.paper,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: SepiaTheme.borderSubtle),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.cleaning_services, size: 12, color: SepiaTheme.inkMuted),
                              const SizedBox(width: 4),
                              Text(
                                'CLEAR ALL CACHED',
                                style: SepiaTheme.mono(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: SepiaTheme.inkMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Page full semantic files from the cloud into edge local memory on-demand:',
                  style: SepiaTheme.sans(fontSize: 11, color: SepiaTheme.inkSecondary),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: masterIndex.entries.take(4).map((entry) {
                    final isCached = widget.memoryService.localTopicCache.containsKey(entry.topicId);
                    return InputChip(
                      key: Key('btn_fetch_topic_${entry.topicId}'),
                      avatar: Icon(
                        isCached ? Icons.check_circle : Icons.download,
                        size: 14,
                        color: isCached ? SepiaTheme.sage : SepiaTheme.amber,
                      ),
                      label: Text(
                        isCached
                            ? '${entry.title} (CACHED LOCALLY)'
                            : '${entry.title} (${entry.tokenEstimate} tok)',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: isCached ? FontWeight.bold : FontWeight.normal,
                          color: SepiaTheme.ink,
                        ),
                      ),
                      backgroundColor: isCached ? SepiaTheme.sageBg : SepiaTheme.paper,
                      side: BorderSide(
                        color: isCached ? SepiaTheme.sageBorder : SepiaTheme.border,
                      ),
                      onPressed: _isPerformingAction
                          ? null
                          : () {
                              if (isCached) {
                                _handleToolEvict(entry.topicId);
                              } else {
                                _handleToolFetch(entry.topicId);
                              }
                            },
                      onDeleted: isCached && !_isPerformingAction
                          ? () => _handleToolEvict(entry.topicId)
                          : null,
                      deleteIcon: isCached
                          ? const Icon(Icons.close, size: 14, color: SepiaTheme.sage)
                          : null,
                      deleteButtonTooltipMessage: 'Uncache / evict from local memory',
                      tooltip: isCached
                          ? 'Cached locally in 0ms RAM. Click to uncache / evict.'
                          : 'Click to fetch and page into local cache.',
                    );
                  }).toList(),
                ),
                if (_selectedTopicContent != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: SepiaTheme.paper,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: SepiaTheme.borderSubtle),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'PAGED CONTEXT: $_selectedTopicTitle',
                              style: SepiaTheme.mono(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: SepiaTheme.amber,
                              ),
                            ),
                            if (_selectedTopicId != null &&
                                widget.memoryService.localTopicCache.containsKey(_selectedTopicId)) ...[
                              InkWell(
                                key: Key('btn_evict_selected_topic_$_selectedTopicId'),
                                onTap: _isPerformingAction
                                    ? null
                                    : () => _handleToolEvict(_selectedTopicId!),
                                borderRadius: BorderRadius.circular(4),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.delete_outline, size: 13, color: SepiaTheme.terracotta),
                                      const SizedBox(width: 4),
                                      Text(
                                        'EVICT FROM CACHE',
                                        style: SepiaTheme.mono(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: SepiaTheme.terracotta,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _selectedTopicContent!,
                          style: SepiaTheme.mono(
                            fontSize: 11,
                            color: SepiaTheme.ink,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Action 2B: Task-Bound Context Window Eviction
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: SepiaTheme.canvas,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: SepiaTheme.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 320),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.timelapse, size: 16, color: SepiaTheme.amber),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              'Task-Bound Context Windows (Immediate Eviction)',
                              style: SepiaTheme.sans(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: SepiaTheme.ink,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton.icon(
                      key: const Key('btn_exec_task_context'),
                      onPressed: _isPerformingAction ? null : _handleExecuteBoundTask,
                      icon: const Icon(Icons.play_arrow, size: 14),
                      label: const Text('EXECUTE BOUND TASK', style: TextStyle(fontSize: 11)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: SepiaTheme.amber,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Demonstrates injecting ~480 tokens for "Undercity Sluice Breach Triage" and immediately dropping them once the action finishes:',
                  style: SepiaTheme.sans(fontSize: 11, color: SepiaTheme.inkSecondary),
                ),
                const SizedBox(height: 8),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final box1 = Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: SepiaTheme.paper,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: SepiaTheme.borderSubtle),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'BASE CONTEXT (BOOT DIRECTIVES)',
                            style: SepiaTheme.mono(fontSize: 9, color: SepiaTheme.inkMuted),
                          ),
                          Text(
                            '${widget.memoryService.coreDirectives.allocatedTokens} Tokens',
                            style: SepiaTheme.mono(fontSize: 13, fontWeight: FontWeight.bold, color: SepiaTheme.ink),
                          ),
                        ],
                      ),
                    );

                    final box2 = Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: SepiaTheme.paper,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: SepiaTheme.borderSubtle),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'TASK INJECTION PEAK',
                            style: SepiaTheme.mono(fontSize: 9, color: SepiaTheme.inkMuted),
                          ),
                          Text(
                            '+480 Tokens (760 Total)',
                            style: SepiaTheme.mono(fontSize: 13, fontWeight: FontWeight.bold, color: SepiaTheme.amber),
                          ),
                        ],
                      ),
                    );

                    final box3 = Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: taskContext?.isEvicted == true ? SepiaTheme.sageBg : SepiaTheme.paper,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: taskContext?.isEvicted == true ? SepiaTheme.sageBorder : SepiaTheme.borderSubtle,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'POST-TASK EVICTION',
                            style: SepiaTheme.mono(fontSize: 9, color: SepiaTheme.inkMuted),
                          ),
                          Text(
                            taskContext?.isEvicted == true
                                ? 'EVICTED ➔ ${taskContext?.baseContextTokens} Tokens'
                                : 'READY FOR WORKFLOW',
                            style: SepiaTheme.mono(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: taskContext?.isEvicted == true ? SepiaTheme.sage : SepiaTheme.inkMuted,
                            ),
                          ),
                        ],
                      ),
                    );

                    if (constraints.maxWidth > 550) {
                      return Row(
                        children: [
                          Expanded(child: box1),
                          const SizedBox(width: 8),
                          const Icon(Icons.arrow_forward, size: 14, color: SepiaTheme.inkMuted),
                          const SizedBox(width: 8),
                          Expanded(child: box2),
                          const SizedBox(width: 8),
                          const Icon(Icons.arrow_forward, size: 14, color: SepiaTheme.inkMuted),
                          const SizedBox(width: 8),
                          Expanded(child: box3),
                        ],
                      );
                    } else {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          box1,
                          const SizedBox(height: 4),
                          const Center(child: Icon(Icons.arrow_downward, size: 14, color: SepiaTheme.inkMuted)),
                          const SizedBox(height: 4),
                          box2,
                          const SizedBox(height: 4),
                          const Center(child: Icon(Icons.arrow_downward, size: 14, color: SepiaTheme.inkMuted)),
                          const SizedBox(height: 4),
                          box3,
                        ],
                      );
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // PATTERN 3: PRE-EMPTIVE CACHING (THE PREDICTIVE LOAD)
  Widget _buildPattern3Card() {
    final prefetchList = widget.memoryService.prefetchHistory;

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
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              Text(
                '3. Pre-Emptive Caching (The Predictive Load)',
                style: SepiaTheme.sans(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: SepiaTheme.ink,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: SepiaTheme.terracottaBg,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'STATE-BASED PREFETCH',
                  style: SepiaTheme.mono(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: SepiaTheme.terracotta,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'For edge devices where real-time voice or game dialogue latency is critical, waiting for a conditional cloud fetch '
            'during a turn is too slow. The agent detects shifts in environmental state (e.g. entering a new sector) and '
            'pre-emptively fetches relevant context files into local memory before the user even speaks.',
            style: SepiaTheme.sans(fontSize: 12, color: SepiaTheme.inkSecondary, height: 1.4),
          ),
          const SizedBox(height: 14),

          // Simulation buttons for state shifts
          // Simulation buttons for state shifts
          Text(
            'Simulate Player Sector State Shifts:',
            style: SepiaTheme.sans(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: SepiaTheme.ink,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildScenePrefetchButton(
                keyStr: 'btn_prefetch_foundry',
                sceneId: 'foundry',
                label: 'APPROACH FOUNDRY',
                icon: Icons.fireplace,
                trigger: 'Approaching Ironforge Foundry',
                topics: const ['volcanic_slag_thresholds', 'iron_vanguard_ciphers'],
              ),
              _buildScenePrefetchButton(
                keyStr: 'btn_prefetch_docks',
                sceneId: 'docks',
                label: 'DESCEND TO DOCKS',
                icon: Icons.sailing,
                trigger: 'Descending into Oakhaven Docks',
                topics: const ['undercity_sluice_bypass', 'smuggler_cipher_routes'],
              ),
              _buildScenePrefetchButton(
                keyStr: 'btn_prefetch_spire',
                sceneId: 'spire',
                label: 'ASCEND SPIRE',
                icon: Icons.account_balance,
                trigger: 'Ascending Archivist Spire',
                topics: const ['keystone_spire_harmonics', 'ancient_grove_roots'],
              ),
            ],
          ),
          if (prefetchList.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: SepiaTheme.canvas,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: SepiaTheme.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.bolt, size: 14, color: SepiaTheme.sage),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'PREFETCH EVENT LOG: ${prefetchList.first.stateTrigger}',
                          style: SepiaTheme.mono(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: SepiaTheme.sage,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${prefetchList.first.status} (${prefetchList.first.latencyMs}ms)',
                        style: SepiaTheme.mono(
                          fontSize: 10,
                          color: SepiaTheme.inkMuted,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.add_circle_outline, size: 12, color: SepiaTheme.sage),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Cached into local RAM: ${prefetchList.first.targetTopicIds.join(", ")} '
                          '(${prefetchList.first.bytesCached} B). Zero-latency 0ms local query readiness confirmed.',
                          style: SepiaTheme.mono(fontSize: 11, color: SepiaTheme.ink),
                        ),
                      ),
                    ],
                  ),
                  if (prefetchList.first.evictedTopicIds.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.remove_circle_outline, size: 12, color: SepiaTheme.amber),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Evicted previous scene: ${prefetchList.first.evictedTopicIds.join(", ")} '
                            '(${prefetchList.first.bytesEvicted} B returned to Cloud Dream). Local edge memory bounded.',
                            style: SepiaTheme.mono(fontSize: 11, color: SepiaTheme.amber),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: SepiaTheme.paperSubtle,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: SepiaTheme.borderSubtle),
            ),
            child: Row(
              children: [
                const Icon(Icons.memory, size: 14, color: SepiaTheme.inkSecondary),
                const SizedBox(width: 6),
                Text(
                  'Active Scene Cache: ',
                  style: SepiaTheme.sans(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: SepiaTheme.inkSecondary,
                  ),
                ),
                Expanded(
                  child: widget.memoryService.activeSceneTopicIds.isEmpty
                      ? Text(
                          'No sector context loaded. Baseline directives only.',
                          style: SepiaTheme.mono(fontSize: 10, color: SepiaTheme.inkMuted),
                        )
                      : Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: widget.memoryService.activeSceneTopicIds.map((tid) {
                            final topic = widget.memoryService.localTopicCache[tid];
                            final sizeStr = topic != null ? '${topic.byteSize} B' : '';
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: SepiaTheme.sageBg,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: SepiaTheme.sageBorder),
                              ),
                              child: Text(
                                '$tid ($sizeStr • 0ms)',
                                style: SepiaTheme.mono(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: SepiaTheme.sage,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScenePrefetchButton({
    required String keyStr,
    required String sceneId,
    required String label,
    required IconData icon,
    required String trigger,
    required List<String> topics,
  }) {
    final isActive = widget.memoryService.activePrefetchedSceneId == sceneId;

    return ElevatedButton.icon(
      key: Key(keyStr),
      onPressed: _isPerformingAction
          ? null
          : () => _handleStatePrefetch(sceneId, trigger, topics),
      icon: Icon(
        isActive ? Icons.check_circle : icon,
        size: 14,
        color: isActive ? SepiaTheme.terracotta : SepiaTheme.ink,
      ),
      label: Text(
        isActive ? '$label (ACTIVE)' : label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: isActive ? SepiaTheme.terracottaBg : SepiaTheme.paperSubtle,
        foregroundColor: isActive ? SepiaTheme.terracotta : SepiaTheme.ink,
        elevation: 0,
        side: BorderSide(
          color: isActive ? SepiaTheme.terracotta : SepiaTheme.border,
          width: isActive ? 1.5 : 1.0,
        ),
      ),
    );
  }

  // PATTERN 4: ASYNCHRONOUS SYNCS (THE "MORNING AFTER")
  Widget _buildPattern4Card(MasterIndex masterIndex) {
    final syncList = widget.memoryService.dreamSyncHistory;

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
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              Text(
                '4. Asynchronous Syncs (The "Morning After")',
                style: SepiaTheme.sans(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: SepiaTheme.ink,
                ),
              ),
              ElevatedButton.icon(
                key: const Key('btn_apply_dream_delta'),
                onPressed: _isPerformingAction ? null : _handleDreamDeltaSync,
                icon: const Icon(Icons.cloud_sync, size: 14),
                label: const Text('APPLY 03:00 AM DREAM DELTA', style: TextStyle(fontSize: 11)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: SepiaTheme.paperSubtle,
                  foregroundColor: SepiaTheme.ink,
                  elevation: 0,
                  side: const BorderSide(color: SepiaTheme.border),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Context loading isn\'t just active queries—it receives the results of cloud overnight consolidation. '
            'During 3 AM low-activity periods (plugged in on Wi-Fi), the Cloud Dream Daemon pushes a delta update: '
            'the edge agent overwrites its local Master Index and invalidates cached topic files modified or deprecated by cloud reconciliation.',
            style: SepiaTheme.sans(fontSize: 12, color: SepiaTheme.inkSecondary, height: 1.4),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: SepiaTheme.canvas,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: SepiaTheme.border),
                ),
                child: Text(
                  'MASTER INDEX v${masterIndex.version}',
                  style: SepiaTheme.mono(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: SepiaTheme.amber,
                  ),
                ),
              ),
              Text(
                'Generated by: ${masterIndex.generatedBy}',
                style: SepiaTheme.mono(
                  fontSize: 11,
                  color: SepiaTheme.inkMuted,
                ),
              ),
            ],
          ),
          if (syncList.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: SepiaTheme.canvas,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: SepiaTheme.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.inventory_2, size: 14, color: SepiaTheme.amber),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'CACHE INVALIDATION AUDIT (DELTA ID: ${syncList.first.deltaId})',
                          style: SepiaTheme.mono(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: SepiaTheme.amber,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Invalidated/Purged Topics: ${syncList.first.invalidatedCachedTopicIds.join(", ")} • '
                    'Deprecated Pruned: ${syncList.first.deprecatedTopicIds.join(", ")} • '
                    'Contradictions Resolved: ${syncList.first.conflictsResolvedCount}',
                    style: SepiaTheme.mono(fontSize: 11, color: SepiaTheme.ink),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // 3. PRIMARY CALL TO ACTION
  Widget _buildBottomActionCta() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: SepiaTheme.paper,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: SepiaTheme.border),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 16,
        runSpacing: 12,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Edge Memory Architecture Hydrated',
                  style: SepiaTheme.sans(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: SepiaTheme.ink,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Minimum context verified. Proceed to tactical mission briefing and sector contacts.',
                  style: SepiaTheme.sans(fontSize: 12, color: SepiaTheme.inkSecondary),
                ),
              ],
            ),
          ),
          ElevatedButton.icon(
            key: const Key('btn_enter_world'),
            onPressed: () {
              widget.loreService.completeBootState();
            },
            icon: const Icon(Icons.explore, size: 16),
            label: const Text(
              'INITIALIZE ENVOY & ENTER THE WORLD ➔',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.5),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: SepiaTheme.amber,
              foregroundColor: Colors.white,
              elevation: 2,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
          ),
        ],
      ),
    );
  }
}
