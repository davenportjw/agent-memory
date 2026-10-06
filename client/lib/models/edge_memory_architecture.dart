import 'dart:convert';
import 'package:flutter/foundation.dart';

/// Local environmental and hardware state measured directly on edge device.
class LocalEnvironmentalState {
  final double batteryLevel; // 0.0 to 1.0 (e.g. 0.88 = 88%)
  final bool isCharging;
  final String networkStatus; // ONLINE_WIFI, ONLINE_CELLULAR, OFFLINE_PARTITIONED
  final String thermalState; // NOMINAL, FAIR, SERIOUS
  final String currentSector; // khar_drak_gates, subterranean_foundry, sunken_docks, keystone_spire
  final String hardwareEngine; // Apple Silicon M-Series WebGPU (Gemma 4 int4)
  final double sensorAmbientNoiseDb;

  const LocalEnvironmentalState({
    required this.batteryLevel,
    required this.isCharging,
    required this.networkStatus,
    required this.thermalState,
    required this.currentSector,
    required this.hardwareEngine,
    this.sensorAmbientNoiseDb = 42.0,
  });

  LocalEnvironmentalState copyWith({
    double? batteryLevel,
    bool? isCharging,
    String? networkStatus,
    String? thermalState,
    String? currentSector,
    String? hardwareEngine,
    double? sensorAmbientNoiseDb,
  }) {
    return LocalEnvironmentalState(
      batteryLevel: batteryLevel ?? this.batteryLevel,
      isCharging: isCharging ?? this.isCharging,
      networkStatus: networkStatus ?? this.networkStatus,
      thermalState: thermalState ?? this.thermalState,
      currentSector: currentSector ?? this.currentSector,
      hardwareEngine: hardwareEngine ?? this.hardwareEngine,
      sensorAmbientNoiseDb: sensorAmbientNoiseDb ?? this.sensorAmbientNoiseDb,
    );
  }

  Map<String, dynamic> toJson() => {
    'battery_level': batteryLevel,
    'is_charging': isCharging,
    'network_status': networkStatus,
    'thermal_state': thermalState,
    'current_sector': currentSector,
    'hardware_engine': hardwareEngine,
    'sensor_ambient_noise_db': sensorAmbientNoiseDb,
  };

  static String get defaultEngineForPlatform {
    if (kIsWeb) return 'WebGPU Browser Engine (Gemma 4 int4)';
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'Android LiteRT (Gemma 4 int4)';
      case TargetPlatform.macOS:
      case TargetPlatform.iOS:
        return 'Apple Silicon M-Series WebGPU (Gemma 4 int4)';
      default:
        return 'Host Edge Runtime (Gemma 4 int4)';
    }
  }

  factory LocalEnvironmentalState.fromJson(Map<String, dynamic> json) =>
      LocalEnvironmentalState(
        batteryLevel: (json['battery_level'] as num?)?.toDouble() ?? 0.88,
        isCharging: json['is_charging'] as bool? ?? false,
        networkStatus: json['network_status'] as String? ?? 'ONLINE_WIFI',
        thermalState: json['thermal_state'] as String? ?? 'NOMINAL',
        currentSector: json['current_sector'] as String? ?? 'khar_drak_gates',
        hardwareEngine: json['hardware_engine'] as String? ?? defaultEngineForPlatform,
        sensorAmbientNoiseDb:
            (json['sensor_ambient_noise_db'] as num?)?.toDouble() ?? 42.0,
      );

  static LocalEnvironmentalState defaultState({String? hardwareEngine}) => LocalEnvironmentalState(
    batteryLevel: 0.88,
    isCharging: true,
    networkStatus: 'ONLINE_WIFI',
    thermalState: 'NOMINAL',
    currentSector: 'khar_drak_gates',
    hardwareEngine: hardwareEngine ?? defaultEngineForPlatform,
    sensorAmbientNoiseDb: 42.0,
  );
}

/// Adaptive routing and triage policy enforced by the edge agent runtime.
enum EdgeRoutingPolicy {
  fullPerformance,
  lowPower,
  offlineAirgapped,
}

extension EdgeRoutingPolicyExtension on EdgeRoutingPolicy {
  String get displayName {
    switch (this) {
      case EdgeRoutingPolicy.fullPerformance:
        return 'FULL PERFORMANCE';
      case EdgeRoutingPolicy.lowPower:
        return 'LOW POWER (<15%)';
      case EdgeRoutingPolicy.offlineAirgapped:
        return 'AIR-GAPPED OFFLINE';
    }
  }

  String get plainEnglishDescription {
    switch (this) {
      case EdgeRoutingPolicy.fullPerformance:
        return 'Unrestricted edge runtime. Cloud escalations, predictive background prefetching, and overnight 3 AM syncs active.';
      case EdgeRoutingPolicy.lowPower:
        return 'Battery critically constrained. Background prefetching throttled, cloud visual renders deferred, strictly prioritizing on-device Gemma 4 int4.';
      case EdgeRoutingPolicy.offlineAirgapped:
        return 'Zero network interface. Semantic queries strictly resolved via local cached topic files; 3 AM Dream Delta queued for reconnection.';
    }
  }

  String get nextActionGuidance {
    switch (this) {
      case EdgeRoutingPolicy.fullPerformance:
        return 'All systems nominal. Ready to triage incoming events with 0ms local response.';
      case EdgeRoutingPolicy.lowPower:
        return 'Connect AC power or tap Battery simulation to restore full performance mode.';
      case EdgeRoutingPolicy.offlineAirgapped:
        return 'Reconnect Wi-Fi or tap Network simulation to resume cloud consolidation.';
    }
  }
}

/// Static system prompt and directives governing edge agent behavior on this hardware.
class CorePersonaDirectives {
  final String systemPromptId;
  final String hardwareProfile;
  final String personaName;
  final List<String> staticDirectives;
  final int allocatedTokens;

  const CorePersonaDirectives({
    required this.systemPromptId,
    required this.hardwareProfile,
    required this.personaName,
    required this.staticDirectives,
    required this.allocatedTokens,
  });

  Map<String, dynamic> toJson() => {
    'system_prompt_id': systemPromptId,
    'hardware_profile': hardwareProfile,
    'persona_name': personaName,
    'static_directives': staticDirectives,
    'allocated_tokens': allocatedTokens,
  };

  factory CorePersonaDirectives.fromJson(Map<String, dynamic> json) =>
      CorePersonaDirectives(
        systemPromptId: json['system_prompt_id'] as String? ?? 'prompt-edge-v1',
        hardwareProfile: json['hardware_profile'] as String? ?? 'Apple Silicon M-Series',
        personaName: json['persona_name'] as String? ?? 'Khar-Drak Envoy Edge Intelligence',
        staticDirectives: (json['static_directives'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [],
        allocatedTokens: json['allocated_tokens'] as int? ?? 256,
      );

  static CorePersonaDirectives defaultDirectives({String? hardwareProfile}) => CorePersonaDirectives(
    systemPromptId: 'prompt-khar-drak-envoy-v1',
    hardwareProfile: hardwareProfile ?? LocalEnvironmentalState.defaultEngineForPlatform,
    personaName: 'Khar-Drak Grand Council Envoy',
    staticDirectives: const [
      'Maintain sub-60ms TTFT by bounding local generation to 3 concise sentences.',
      'Enforce zero cloud egress for tactical inquiries by checking local Master Index first.',
      'Drop injected task context immediately upon workflow completion to prevent RAM bloat.',
      'Respect faction neutrality unless an explicit diplomatic accord is ratified.',
    ],
    allocatedTokens: 256,
  );
}

/// Entry within the compressed Master Index ("The Map") generated by the cloud's dream phase.
class MasterIndexEntry {
  final String topicId;
  final String title;
  final String category; // TACTICAL_SECURITY, WORLD_CANON, USER_PREFERENCES, ARTIFACT_SCHEMATICS
  final String summaryScope;
  final int byteSize;
  final int tokenEstimate;
  final String versionHash;
  final bool isCachedLocally;
  final DateTime lastUpdated;

  const MasterIndexEntry({
    required this.topicId,
    required this.title,
    required this.category,
    required this.summaryScope,
    required this.byteSize,
    required this.tokenEstimate,
    required this.versionHash,
    required this.isCachedLocally,
    required this.lastUpdated,
  });

  String get topicName => title;
  int get estimatedTokens => tokenEstimate;

  MasterIndexEntry copyWith({
    String? topicId,
    String? title,
    String? category,
    String? summaryScope,
    int? byteSize,
    int? tokenEstimate,
    String? versionHash,
    bool? isCachedLocally,
    DateTime? lastUpdated,
  }) {
    return MasterIndexEntry(
      topicId: topicId ?? this.topicId,
      title: title ?? this.title,
      category: category ?? this.category,
      summaryScope: summaryScope ?? this.summaryScope,
      byteSize: byteSize ?? this.byteSize,
      tokenEstimate: tokenEstimate ?? this.tokenEstimate,
      versionHash: versionHash ?? this.versionHash,
      isCachedLocally: isCachedLocally ?? this.isCachedLocally,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  Map<String, dynamic> toJson() => {
    'topic_id': topicId,
    'title': title,
    'category': category,
    'summary_scope': summaryScope,
    'byte_size': byteSize,
    'token_estimate': tokenEstimate,
    'version_hash': versionHash,
    'is_cached_locally': isCachedLocally,
    'last_updated': lastUpdated.toIso8601String(),
  };

  factory MasterIndexEntry.fromJson(Map<String, dynamic> json) => MasterIndexEntry(
    topicId: json['topic_id'] as String? ?? '',
    title: json['title'] as String? ?? '',
    category: json['category'] as String? ?? 'WORLD_CANON',
    summaryScope: json['summary_scope'] as String? ?? '',
    byteSize: json['byte_size'] as int? ?? 0,
    tokenEstimate: json['token_estimate'] as int? ?? 0,
    versionHash: json['version_hash'] as String? ?? '',
    isCachedLocally: json['is_cached_locally'] as bool? ?? false,
    lastUpdated: json['last_updated'] != null
        ? DateTime.parse(json['last_updated'] as String)
        : DateTime.now(),
  );
}

/// The Master Index ("The Map") — highly compressed directory generated by cloud dream consolidation.
class MasterIndex {
  final int version;
  final String generatedBy;
  final DateTime generatedAt;
  final List<MasterIndexEntry> entries;

  const MasterIndex({
    required this.version,
    required this.generatedBy,
    required this.generatedAt,
    required this.entries,
  });

  int get totalTopicCount => entries.length;

  int get calculatedSizeBytes {
    final rawJson = jsonEncode(toJson());
    return utf8.encode(rawJson).length;
  }

  MasterIndex copyWith({
    int? version,
    String? generatedBy,
    DateTime? generatedAt,
    List<MasterIndexEntry>? entries,
  }) {
    return MasterIndex(
      version: version ?? this.version,
      generatedBy: generatedBy ?? this.generatedBy,
      generatedAt: generatedAt ?? this.generatedAt,
      entries: entries ?? this.entries,
    );
  }

  Map<String, dynamic> toJson() => {
    'version': version,
    'generated_by': generatedBy,
    'generated_at': generatedAt.toIso8601String(),
    'entries': entries.map((e) => e.toJson()).toList(),
  };

  factory MasterIndex.fromJson(Map<String, dynamic> json) {
    final rawEntries = (json['entries'] as List<dynamic>?)
            ?.map((e) => MasterIndexEntry.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];
    return MasterIndex(
      version: json['version'] as int? ?? 1,
      generatedBy: json['generated_by'] as String? ?? 'Cloud Dream Daemon v3.8',
      generatedAt: json['generated_at'] != null
          ? DateTime.parse(json['generated_at'] as String)
          : DateTime.now(),
      entries: rawEntries,
    );
  }

  static MasterIndex defaultIndex() {
    final now = DateTime.now();
    return MasterIndex(
      version: 4,
      generatedBy: 'Cloud Dream Daemon v3.8 (Overnight Consolidation)',
      generatedAt: now.subtract(const Duration(hours: 3)),
      entries: [
        MasterIndexEntry(
          topicId: 'iron_vanguard_ciphers',
          title: 'Iron Vanguard Valve Ciphers',
          category: 'TACTICAL_SECURITY',
          summaryScope:
              'Cryptographic bypass frequencies and acoustic pressure damper settings for Foundry gates.',
          byteSize: 3420,
          tokenEstimate: 380,
          versionHash: 'hash-ivg-99a',
          isCachedLocally: false,
          lastUpdated: now.subtract(const Duration(hours: 3)),
        ),
        MasterIndexEntry(
          topicId: 'undercity_sluice_bypass',
          title: 'Undercity Sluice Drainage Grid',
          category: 'WORLD_CANON',
          summaryScope:
              'Submerged subterranean aqueduct labyrinth connecting the Docks to Municipal Basins.',
          byteSize: 4180,
          tokenEstimate: 460,
          versionHash: 'hash-slc-41b',
          isCachedLocally: false,
          lastUpdated: now.subtract(const Duration(hours: 3)),
        ),
        MasterIndexEntry(
          topicId: 'keystone_spire_harmonics',
          title: 'Keystone Spire Leyline Harmonics',
          category: 'ARTIFACT_SCHEMATICS',
          summaryScope:
              'Resonant crystal tuning frequencies required to dampen subterranean arcane surges.',
          byteSize: 3890,
          tokenEstimate: 420,
          versionHash: 'hash-ksp-18c',
          isCachedLocally: false,
          lastUpdated: now.subtract(const Duration(hours: 3)),
        ),
        MasterIndexEntry(
          topicId: 'envoy_diplomatic_treaties',
          title: 'Grand Council Tripartite Treaties',
          category: 'USER_PREFERENCES',
          summaryScope:
              'Binding clauses between Vanguard, Syndicate, and Enclave governing territorial defense.',
          byteSize: 2950,
          tokenEstimate: 310,
          versionHash: 'hash-trt-04d',
          isCachedLocally: true,
          lastUpdated: now.subtract(const Duration(hours: 3)),
        ),
        MasterIndexEntry(
          topicId: 'volcanic_slag_thresholds',
          title: 'Volcanic Slag Thermal Tolerances',
          category: 'TACTICAL_SECURITY',
          summaryScope:
              'Critical melting temperatures and blast wall survivability against magma reflux.',
          byteSize: 2640,
          tokenEstimate: 290,
          versionHash: 'hash-vsl-77e',
          isCachedLocally: false,
          lastUpdated: now.subtract(const Duration(hours: 3)),
        ),
        MasterIndexEntry(
          topicId: 'smuggler_cipher_routes',
          title: 'Shadow Syndicate Contraband Bypasses',
          category: 'TACTICAL_SECURITY',
          summaryScope:
              'Clandestine canal valve routes used to smuggle civilians and goods around Vanguard checkpoints.',
          byteSize: 3120,
          tokenEstimate: 340,
          versionHash: 'hash-smg-22f',
          isCachedLocally: false,
          lastUpdated: now.subtract(const Duration(hours: 3)),
        ),
        MasterIndexEntry(
          topicId: 'ancient_grove_roots',
          title: 'Ancient Sylvan Grove Living Roots',
          category: 'WORLD_CANON',
          summaryScope:
              'Botanical conduit pathways that ground arcane feedback loops through the mountain base.',
          byteSize: 3500,
          tokenEstimate: 390,
          versionHash: 'hash-grv-33g',
          isCachedLocally: false,
          lastUpdated: now.subtract(const Duration(hours: 3)),
        ),
        MasterIndexEntry(
          topicId: 'envoy_hardware_limits',
          title: 'Envoy Edge Hardware Constraints',
          category: 'USER_PREFERENCES',
          summaryScope:
              'Hardware guardrails: max 5 turns working context, 50 KB edge bundle limit, Apple Silicon thermal caps.',
          byteSize: 2100,
          tokenEstimate: 240,
          versionHash: 'hash-hwd-88h',
          isCachedLocally: true,
          lastUpdated: now.subtract(const Duration(hours: 3)),
        ),
      ],
    );
  }
}

/// Full semantic topic file paged in conditionally or pre-emptively cached.
class MemoryTopicFile {
  final String topicId;
  final String title;
  final String category;
  final String fullContent;
  final String versionHash;
  final DateTime lastConsolidatedAt;
  final int byteSize;
  final List<String> tags;

  const MemoryTopicFile({
    required this.topicId,
    required this.title,
    required this.category,
    required this.fullContent,
    required this.versionHash,
    required this.lastConsolidatedAt,
    required this.byteSize,
    required this.tags,
  });

  int get tokenEstimate => (byteSize / 8.5).round();

  Map<String, dynamic> toJson() => {
    'topic_id': topicId,
    'title': title,
    'category': category,
    'full_content': fullContent,
    'version_hash': versionHash,
    'last_consolidated_at': lastConsolidatedAt.toIso8601String(),
    'byte_size': byteSize,
    'tags': tags,
  };

  factory MemoryTopicFile.fromJson(Map<String, dynamic> json) => MemoryTopicFile(
    topicId: json['topic_id'] as String? ?? '',
    title: json['title'] as String? ?? '',
    category: json['category'] as String? ?? 'WORLD_CANON',
    fullContent: json['full_content'] as String? ?? '',
    versionHash: json['version_hash'] as String? ?? '',
    lastConsolidatedAt: json['last_consolidated_at'] != null
        ? DateTime.parse(json['last_consolidated_at'] as String)
        : DateTime.now(),
    byteSize: json['byte_size'] as int? ?? 0,
    tags: (json['tags'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
  );
}

/// Task-bound context window representing JIT memory injection during an active workflow.
class TaskBoundContext {
  final String taskId;
  final String taskName;
  final List<MemoryTopicFile> injectedTopics;
  final DateTime startTime;
  final DateTime? endTime;
  final int baseContextTokens;
  final int taskContextTokens;
  final bool isEvicted;

  const TaskBoundContext({
    required this.taskId,
    required this.taskName,
    required this.injectedTopics,
    required this.startTime,
    this.endTime,
    required this.baseContextTokens,
    required this.taskContextTokens,
    required this.isEvicted,
  });

  int get totalContextTokens => baseContextTokens + (isEvicted ? 0 : taskContextTokens);

  TaskBoundContext copyWith({
    String? taskId,
    String? taskName,
    List<MemoryTopicFile>? injectedTopics,
    DateTime? startTime,
    DateTime? endTime,
    int? baseContextTokens,
    int? taskContextTokens,
    bool? isEvicted,
  }) {
    return TaskBoundContext(
      taskId: taskId ?? this.taskId,
      taskName: taskName ?? this.taskName,
      injectedTopics: injectedTopics ?? this.injectedTopics,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      baseContextTokens: baseContextTokens ?? this.baseContextTokens,
      taskContextTokens: taskContextTokens ?? this.taskContextTokens,
      isEvicted: isEvicted ?? this.isEvicted,
    );
  }

  Map<String, dynamic> toJson() => {
    'task_id': taskId,
    'task_name': taskName,
    'injected_topics': injectedTopics.map((t) => t.toJson()).toList(),
    'start_time': startTime.toIso8601String(),
    'end_time': endTime?.toIso8601String(),
    'base_context_tokens': baseContextTokens,
    'task_context_tokens': taskContextTokens,
    'is_evicted': isEvicted,
    'total_context_tokens': totalContextTokens,
  };
}

/// Record of a state-based prefetch triggered prior to user interaction.
class PrefetchEvent {
  final String id;
  final String stateTrigger;
  final String? sceneId;
  final List<String> targetTopicIds;
  final List<String> evictedTopicIds;
  final DateTime timestamp;
  final String status; // PREFETCHED, TRANSITIONED, ALREADY_CACHED, FAILED
  final int latencyMs;
  final int bytesCached;
  final int bytesEvicted;

  const PrefetchEvent({
    required this.id,
    required this.stateTrigger,
    this.sceneId,
    required this.targetTopicIds,
    this.evictedTopicIds = const [],
    required this.timestamp,
    required this.status,
    required this.latencyMs,
    required this.bytesCached,
    this.bytesEvicted = 0,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'state_trigger': stateTrigger,
    if (sceneId != null) 'scene_id': sceneId,
    'target_topic_ids': targetTopicIds,
    'evicted_topic_ids': evictedTopicIds,
    'timestamp': timestamp.toIso8601String(),
    'status': status,
    'latency_ms': latencyMs,
    'bytes_cached': bytesCached,
    'bytes_evicted': bytesEvicted,
  };

  factory PrefetchEvent.fromJson(Map<String, dynamic> json) => PrefetchEvent(
    id: json['id'] as String? ?? '',
    stateTrigger: json['state_trigger'] as String? ?? '',
    sceneId: json['scene_id'] as String?,
    targetTopicIds: (json['target_topic_ids'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [],
    evictedTopicIds: (json['evicted_topic_ids'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [],
    timestamp: json['timestamp'] != null
        ? DateTime.parse(json['timestamp'] as String)
        : DateTime.now(),
    status: json['status'] as String? ?? 'PREFETCHED',
    latencyMs: json['latency_ms'] as int? ?? 0,
    bytesCached: json['bytes_cached'] as int? ?? 0,
    bytesEvicted: json['bytes_evicted'] as int? ?? 0,
  );
}

/// Delta update pushed by the cloud dream daemon overnight during low-activity periods.
class DreamDeltaUpdate {
  final String deltaId;
  final DateTime syncTimestamp;
  final String source;
  final int newMasterIndexVersion;
  final List<MasterIndexEntry> updatedEntries;
  final List<String> deprecatedTopicIds;
  final int conflictsResolvedCount;
  final List<String> invalidatedCachedTopicIds;

  const DreamDeltaUpdate({
    required this.deltaId,
    required this.syncTimestamp,
    required this.source,
    required this.newMasterIndexVersion,
    required this.updatedEntries,
    required this.deprecatedTopicIds,
    required this.conflictsResolvedCount,
    required this.invalidatedCachedTopicIds,
  });

  Map<String, dynamic> toJson() => {
    'delta_id': deltaId,
    'sync_timestamp': syncTimestamp.toIso8601String(),
    'source': source,
    'new_master_index_version': newMasterIndexVersion,
    'updated_entries': updatedEntries.map((e) => e.toJson()).toList(),
    'deprecated_topic_ids': deprecatedTopicIds,
    'conflicts_resolved_count': conflictsResolvedCount,
    'invalidated_cached_topic_ids': invalidatedCachedTopicIds,
  };

  factory DreamDeltaUpdate.fromJson(Map<String, dynamic> json) => DreamDeltaUpdate(
    deltaId: json['delta_id'] as String? ?? '',
    syncTimestamp: json['sync_timestamp'] != null
        ? DateTime.parse(json['sync_timestamp'] as String)
        : DateTime.now(),
    source: json['source'] as String? ?? 'Cloud Dream Daemon',
    newMasterIndexVersion: json['new_master_index_version'] as int? ?? 1,
    updatedEntries: (json['updated_entries'] as List<dynamic>?)
            ?.map((e) => MasterIndexEntry.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [],
    deprecatedTopicIds: (json['deprecated_topic_ids'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [],
    conflictsResolvedCount: json['conflicts_resolved_count'] as int? ?? 0,
    invalidatedCachedTopicIds: (json['invalidated_cached_topic_ids'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [],
  );
}

/// The complete, minimal boot state loaded on-demand when the edge agent spins up.
class AgentBootState {
  final bool isBooted;
  final DateTime bootTimestamp;
  final int bootDurationMs;
  final CorePersonaDirectives coreDirectives;
  final MasterIndex masterIndex;
  final LocalEnvironmentalState environmentalState;

  const AgentBootState({
    required this.isBooted,
    required this.bootTimestamp,
    required this.bootDurationMs,
    required this.coreDirectives,
    required this.masterIndex,
    required this.environmentalState,
  });

  /// Total bytes loaded into working memory at boot (< 2 KB index + directives + telemetry).
  int get bootFootprintBytes {
    final indexBytes = masterIndex.calculatedSizeBytes;
    final directivesBytes = utf8.encode(jsonEncode(coreDirectives.toJson())).length;
    final envBytes = utf8.encode(jsonEncode(environmentalState.toJson())).length;
    return indexBytes + directivesBytes + envBytes;
  }

  bool get isWithinBootBudget => bootFootprintBytes <= 4096; // Strictly < 4 KB

  /// Dynamic adaptive routing policy derived from live environmental vitals.
  EdgeRoutingPolicy get routingPolicy {
    if (environmentalState.networkStatus == 'OFFLINE_AIRGAPPED' ||
        environmentalState.networkStatus == 'OFFLINE_PARTITIONED') {
      return EdgeRoutingPolicy.offlineAirgapped;
    }
    if (environmentalState.batteryLevel <= 0.15 && !environmentalState.isCharging) {
      return EdgeRoutingPolicy.lowPower;
    }
    return EdgeRoutingPolicy.fullPerformance;
  }

  AgentBootState copyWith({
    bool? isBooted,
    DateTime? bootTimestamp,
    int? bootDurationMs,
    CorePersonaDirectives? coreDirectives,
    MasterIndex? masterIndex,
    LocalEnvironmentalState? environmentalState,
  }) {
    return AgentBootState(
      isBooted: isBooted ?? this.isBooted,
      bootTimestamp: bootTimestamp ?? this.bootTimestamp,
      bootDurationMs: bootDurationMs ?? this.bootDurationMs,
      coreDirectives: coreDirectives ?? this.coreDirectives,
      masterIndex: masterIndex ?? this.masterIndex,
      environmentalState: environmentalState ?? this.environmentalState,
    );
  }

  Map<String, dynamic> toJson() => {
    'is_booted': isBooted,
    'boot_timestamp': bootTimestamp.toIso8601String(),
    'boot_duration_ms': bootDurationMs,
    'boot_footprint_bytes': bootFootprintBytes,
    'core_directives': coreDirectives.toJson(),
    'master_index': masterIndex.toJson(),
    'environmental_state': environmentalState.toJson(),
  };

  static AgentBootState initial() {
    return AgentBootState(
      isBooted: false,
      bootTimestamp: DateTime.now(),
      bootDurationMs: 0,
      coreDirectives: CorePersonaDirectives.defaultDirectives(),
      masterIndex: MasterIndex.defaultIndex(),
      environmentalState: LocalEnvironmentalState.defaultState(),
    );
  }
}
