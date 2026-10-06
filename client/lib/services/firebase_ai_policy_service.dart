import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Policy rule definition synchronized from Firebase Remote Config.
class FirebasePolicyRule {
  final String id;
  final int priority;
  final String description;
  final String route;

  const FirebasePolicyRule({
    required this.id,
    required this.priority,
    required this.description,
    required this.route,
  });

  factory FirebasePolicyRule.fromJson(Map<String, dynamic> json) {
    return FirebasePolicyRule(
      id: json['id'] as String? ?? 'RULE_UNKNOWN',
      priority: (json['priority'] as num?)?.toInt() ?? 10,
      description: json['description'] as String? ?? '',
      route: json['route'] as String? ?? 'EDGE_LOCAL',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'priority': priority,
        'description': description,
        'route': route,
      };
}

/// Dynamic Firebase Remote Config configuration state.
class FirebaseAiPolicyConfig {
  final String version;
  final String provider;
  final DateTime lastSyncedAt;
  final int maxEdgeTokens;
  final int circuitBreakerLimit;
  final bool piiScrubbingEnabled;
  final String visualSynthesisModel;
  final String cloudReasoningModel;
  final List<String> edgeModelsSupported;
  final List<FirebasePolicyRule> rules;

  const FirebaseAiPolicyConfig({
    required this.version,
    required this.provider,
    required this.lastSyncedAt,
    required this.maxEdgeTokens,
    required this.circuitBreakerLimit,
    required this.piiScrubbingEnabled,
    required this.visualSynthesisModel,
    required this.cloudReasoningModel,
    required this.edgeModelsSupported,
    required this.rules,
  });

  factory FirebaseAiPolicyConfig.defaultConfig() {
    return FirebaseAiPolicyConfig(
      version: '1.4.0',
      provider: 'Firebase Remote Config / Bundled Policy',
      lastSyncedAt: DateTime.now(),
      maxEdgeTokens: 4096,
      circuitBreakerLimit: 3,
      piiScrubbingEnabled: true,
      visualSynthesisModel: 'gemini-3.1-flash-lite-image',
      cloudReasoningModel: 'gemini-3.8-flash',
      edgeModelsSupported: const ['gemma-4-2b-it-int4', 'gemma-4-a4b-it-int4', 'chrome-gemini-nano'],
      rules: const [
        FirebasePolicyRule(
          id: 'RULE_STRICT_PRIVACY',
          priority: 100,
          description: 'If user prompt contains detected PII, credentials, or confidential tags, enforce local on-device execution.',
          route: 'EDGE_LOCAL',
        ),
        FirebasePolicyRule(
          id: 'RULE_GAME_VISUAL_SYNTHESIS',
          priority: 90,
          description: 'Escalate to Vertex AI Nano Banana 2 Lite for concept art, blueprints, and visual rendering.',
          route: 'CLOUD_ESCALATE',
        ),
        FirebasePolicyRule(
          id: 'RULE_GAME_REACTIVE_BARK',
          priority: 85,
          description: 'Fast dialogue barks, barters, and inventory checks execute on-device (<60ms TTFT, 0 KB egress).',
          route: 'EDGE_LOCAL',
        ),
        FirebasePolicyRule(
          id: 'RULE_CONTEXT_LIMIT_EXCEEDED',
          priority: 80,
          description: 'Escalate to Cloud Run when prompt exceeds 4,096 tokens.',
          route: 'CLOUD_ESCALATE',
        ),
        FirebasePolicyRule(
          id: 'RULE_GAME_CAMPAIGN_SYNTHESIS',
          priority: 75,
          description: 'Multi-faction consequence simulation, treaties, and world event updates execute on Gemini 3.8 Flash.',
          route: 'CLOUD_ESCALATE',
        ),
        FirebasePolicyRule(
          id: 'RULE_COMPLEXITY_ESCALATION',
          priority: 70,
          description: 'Escalate multi-hop architectural reasoning to cloud.',
          route: 'CLOUD_ESCALATE',
        ),
        FirebasePolicyRule(
          id: 'RULE_EDGE_DEFAULT_FAST',
          priority: 10,
          description: 'Default to on-device edge execution for standard fast conversational turns.',
          route: 'EDGE_LOCAL',
        ),
      ],
    );
  }

  factory FirebaseAiPolicyConfig.fromJson(Map<String, dynamic> json) {
    final rulesList = (json['rules'] as List<dynamic>?)
            ?.map((e) => FirebasePolicyRule.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];

    final edgeModels = (json['edge_models_supported'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        ['gemma-4-2b-it-int4', 'chrome-gemini-nano'];

    DateTime parsedDate;
    try {
      parsedDate = DateTime.parse(json['last_synced_at'] as String? ?? '');
    } catch (_) {
      parsedDate = DateTime.now();
    }

    return FirebaseAiPolicyConfig(
      version: json['version'] as String? ?? '1.4.0',
      provider: json['provider'] as String? ?? 'Firebase Remote Config',
      lastSyncedAt: parsedDate,
      maxEdgeTokens: (json['max_edge_tokens'] as num?)?.toInt() ?? 4096,
      circuitBreakerLimit: (json['circuit_breaker_limit'] as num?)?.toInt() ?? 3,
      piiScrubbingEnabled: json['pii_scrubbing_enabled'] as bool? ?? true,
      visualSynthesisModel: json['visual_synthesis_model'] as String? ?? 'gemini-3.1-flash-lite-image',
      cloudReasoningModel: json['cloud_reasoning_model'] as String? ?? 'gemini-3.8-flash',
      edgeModelsSupported: edgeModels,
      rules: rulesList,
    );
  }
}

/// Client-side service synchronizing dynamic AI routing policies from Firebase Remote Config.
class FirebaseAiPolicyService extends ChangeNotifier {
  final http.Client _httpClient;
  String _endpointUrl;

  FirebaseAiPolicyConfig _activeConfig;
  bool _isSyncing = false;
  String? _syncError;
  int _syncCount = 0;

  FirebaseAiPolicyService({
    http.Client? httpClient,
    String? initialEndpoint,
  })  : _httpClient = httpClient ?? http.Client(),
        _endpointUrl = initialEndpoint ?? '/api/policy/firebase',
        _activeConfig = FirebaseAiPolicyConfig.defaultConfig();

  FirebaseAiPolicyConfig get activeConfig => _activeConfig;
  bool get isSyncing => _isSyncing;
  String? get syncError => _syncError;
  int get syncCount => _syncCount;
  String get policyVersion => _activeConfig.version;
  String get providerLabel => _activeConfig.provider;
  int get maxEdgeTokens => _activeConfig.maxEdgeTokens;
  int get circuitBreakerLimit => _activeConfig.circuitBreakerLimit;
  List<FirebasePolicyRule> get rules => _activeConfig.rules;

  /// Updates target endpoint for Firebase policy synchronization.
  void setEndpoint(String url) {
    if (_endpointUrl != url) {
      _endpointUrl = url;
    }
  }

  /// Synchronizes live routing policy from Firebase Remote Config endpoint.
  Future<bool> syncPolicy({String? customEndpoint}) async {
    _isSyncing = true;
    _syncError = null;
    notifyListeners();

    final targetUrl = customEndpoint ?? _endpointUrl;

    try {
      final uri = Uri.parse(targetUrl);
      final response = await _httpClient.get(
        uri,
        headers: {
          'Accept': 'application/json',
          'X-Client-Platform': 'Flutter-Edge-Router',
        },
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final decoded = json.decode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        _activeConfig = FirebaseAiPolicyConfig.fromJson(decoded);
        _syncCount++;
        _isSyncing = false;
        notifyListeners();
        return true;
      } else {
        _syncError = 'Firebase Remote Config HTTP ${response.statusCode}';
      }
    } catch (e) {
      _syncError = 'Firebase Policy sync offline: $e';
    }

    _isSyncing = false;
    notifyListeners();
    return false;
  }
}
