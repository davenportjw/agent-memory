import '../models/routing_decision.dart';
import 'firebase_ai_policy_service.dart';

enum RouterModeOverride {
  auto,
  enforceEdgeLocal,
  enforceCloudFlash,
  simulateOffline,
}

class RoutingEvaluationResult {
  final ExecutionRoute route;
  final String ruleId;
  final String intentLabel;
  final String justification;
  final String memoryDelta;
  final List<String> detectedPii;
  final int estimatedTokens;
  final bool requiresRedaction;
  final bool requiresDurableMemories;
  final String policyVersion;
  final String policySource;

  const RoutingEvaluationResult({
    required this.route,
    required this.ruleId,
    required this.intentLabel,
    required this.justification,
    required this.memoryDelta,
    this.detectedPii = const [],
    this.estimatedTokens = 0,
    this.requiresRedaction = false,
    this.requiresDurableMemories = false,
    this.policyVersion = '1.4.0',
    this.policySource = 'Firebase Remote Config',
  });
}

class SwitchingRouterService {
  final FirebaseAiPolicyService policyService;
  RouterModeOverride modeOverride = RouterModeOverride.auto;
  CircuitBreakerState circuitBreakerState = CircuitBreakerState.CLOSED;
  int consecutiveFailures = 0;

  SwitchingRouterService({FirebaseAiPolicyService? policyService})
      : policyService = policyService ?? FirebaseAiPolicyService();

  int get circuitBreakerThreshold => policyService.circuitBreakerLimit;
  int get maxEdgeTokens => policyService.maxEdgeTokens;

  // Compiled regex patterns matching shared/routing_policy.json
  final RegExp _emailRegex = RegExp(r'[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}');
  final RegExp _phoneRegex = RegExp(r'\b(?:\+?1[-.]?)?(?:\(?([0-9]{3})\)?[-. ]?)?([0-9]{3})[-. ]?([0-9]{4})\b');
  final RegExp _ssnRegex = RegExp(r'\b\d{3}-\d{2}-\d{4}\b');
  final RegExp _creditCardRegex = RegExp(r'\b(?:4[0-9]{12}(?:[0-9]{3})?|5[1-5][0-9]{14}|3[47][0-9]{13})\b');
  final RegExp _apiKeyRegex = RegExp(r'\b(?:AIza[0-9A-Za-z-_]{35}|sk-[a-zA-Z0-9]{32,})\b');

  int get activePiiPatternCount => 5;
  List<String> get activePiiPatternNames => const ['Email', 'Phone', 'SSN', 'Credit Card', 'API Keys'];

  /// Detects all PII entities in a text string
  List<String> detectPii(String input) {
    final List<String> found = [];

    for (final match in _emailRegex.allMatches(input)) {
      found.add('Email: ${match.group(0)}');
    }
    for (final match in _phoneRegex.allMatches(input)) {
      found.add('Phone: ${match.group(0)}');
    }
    for (final match in _ssnRegex.allMatches(input)) {
      found.add('SSN: ${match.group(0)}');
    }
    for (final match in _creditCardRegex.allMatches(input)) {
      found.add('Credit Card: ${match.group(0)}');
    }
    for (final match in _apiKeyRegex.allMatches(input)) {
      found.add('API Key: ${match.group(0)}');
    }

    return found;
  }

  /// Scrubs detected PII entities replacing them with sanitized placeholders
  String scrubPii(String input) {
    var sanitized = input;
    sanitized = sanitized.replaceAll(_emailRegex, '[REDACTED_EMAIL]');
    sanitized = sanitized.replaceAll(_phoneRegex, '[REDACTED_PHONE]');
    sanitized = sanitized.replaceAll(_ssnRegex, '[REDACTED_SSN]');
    sanitized = sanitized.replaceAll(_creditCardRegex, '[REDACTED_CREDIT_CARD]');
    sanitized = sanitized.replaceAll(_apiKeyRegex, '[REDACTED_API_KEY]');
    return sanitized;
  }

  /// Evaluates routing policy rules based on input text, token count, and network state
  RoutingEvaluationResult evaluateRoute({
    required String prompt,
    int? estimatedTokens,
    bool isNetworkOnline = true,
  }) {
    final tokens = estimatedTokens ?? _estimateTokenCount(prompt);
    final piiItems = detectPii(prompt);
    final hasPii = piiItems.isNotEmpty;

    // Check manual override first
    if (modeOverride == RouterModeOverride.enforceEdgeLocal) {
      return RoutingEvaluationResult(
        route: ExecutionRoute.EDGE_LOCAL,
        ruleId: 'OVERRIDE_ENFORCE_EDGE',
        intentLabel: 'Local Edge Fast Intent: Zero-Latency Execution',
        justification: 'Manual Mode Override: Enforced on-device execution (Gemini Nano / Gemma 4).',
        memoryDelta: 'Committed to local working context (0 KB egress)',
        detectedPii: piiItems,
        estimatedTokens: tokens,
        requiresRedaction: hasPii,
      );
    } else if (modeOverride == RouterModeOverride.enforceCloudFlash) {
      return RoutingEvaluationResult(
        route: ExecutionRoute.CLOUD_ESCALATE,
        ruleId: 'OVERRIDE_ENFORCE_CLOUD',
        intentLabel: 'Cloud Synthesis Intent: Cross-Session Architecture Alignment',
        justification: 'Manual Mode Override: Enforced Gemini 3.8 Flash cloud reasoning.',
        memoryDelta: 'Sanitized turn dispatched to Cloud Ingestion Queue',
        detectedPii: piiItems,
        estimatedTokens: tokens,
        requiresRedaction: hasPii,
        requiresDurableMemories: true,
      );
    } else if (modeOverride == RouterModeOverride.simulateOffline || !isNetworkOnline || circuitBreakerState == CircuitBreakerState.OPEN) {
      return RoutingEvaluationResult(
        route: ExecutionRoute.EDGE_FALLBACK,
        ruleId: 'RULE_CIRCUIT_BREAKER_OFFLINE',
        intentLabel: 'Offline Fallback Intent: Degraded Tactical Answer',
        justification: circuitBreakerState == CircuitBreakerState.OPEN
            ? 'Cloud circuit breaker tripped (> $circuitBreakerThreshold failures). Dispatched to LiteRT CPU fallback.'
            : 'Client network offline or disconnected. Executing on-device.',
        memoryDelta: 'Turn queued in Local SQLite for batch offline reconciliation',
        detectedPii: piiItems,
        estimatedTokens: tokens,
        requiresRedaction: hasPii,
      );
    }

    // Rule 1: Priority 100 - Strict Privacy & Zero PII Leakage
    if (hasPii || prompt.toLowerCase().contains('confidential') || prompt.toLowerCase().contains('private note')) {
      return RoutingEvaluationResult(
        route: ExecutionRoute.EDGE_LOCAL,
        ruleId: 'RULE_STRICT_PRIVACY',
        intentLabel: 'Local Privacy Intent: PII Sanitization & Task Extraction',
        justification: 'Detected ${piiItems.length} sensitive entities. Strict on-device execution enforced.',
        memoryDelta: 'Locally sanitized & stored in private working context. 0 KB egress.',
        detectedPii: piiItems,
        estimatedTokens: tokens,
        requiresRedaction: true,
      );
    }

    // Rule 2: Priority 80 - Context Capacity Limit Exceeded (> maxEdgeTokens)
    if (tokens > maxEdgeTokens) {
      return RoutingEvaluationResult(
        route: ExecutionRoute.CLOUD_ESCALATE,
        ruleId: 'RULE_CONTEXT_LIMIT_EXCEEDED',
        intentLabel: 'Cloud Long-Context Intent: Extended Token Capacity',
        justification: 'Estimated token volume ($tokens tokens) exceeds Firebase dynamic edge budget ($maxEdgeTokens tokens). Escalate to Gemini 3.8 Flash (1M tokens).',
        memoryDelta: 'Dispatched to Cloud Ingestion Queue with PII scrubbed',
        detectedPii: piiItems,
        estimatedTokens: tokens,
        requiresRedaction: hasPii,
        requiresDurableMemories: true,
        policyVersion: policyService.policyVersion,
        policySource: policyService.providerLabel,
      );
    }

    // Rule 2.2: Priority 90 - Game Visual Synthesis (Requires Vertex AI Nano Banana 2 Lite)
    if (_isVisualSynthesis(prompt)) {
      return RoutingEvaluationResult(
        route: ExecutionRoute.CLOUD_ESCALATE,
        ruleId: 'RULE_GAME_VISUAL_SYNTHESIS',
        intentLabel: 'Cloud Visual Synthesis: Nano Banana 2 Lite (~1.2s)',
        justification: 'Visual asset generation requested. Autoregressive edge models (Nano/Gemma 4) are text-only; routing to Cloud Run with Nano Banana 2 Lite.',
        memoryDelta: 'Visual prompt & context anchors dispatched to Cloud Run /api/image/generate',
        detectedPii: piiItems,
        estimatedTokens: tokens,
        requiresRedaction: hasPii,
        requiresDurableMemories: false,
      );
    }

    // Rule 2.5: Priority 85 - Game Reactive Bark (60 FPS on-device budget)
    if (_isGameReactiveBark(prompt) && !_isGameCampaignSynthesis(prompt)) {
      return RoutingEvaluationResult(
        route: ExecutionRoute.EDGE_LOCAL,
        ruleId: 'RULE_GAME_REACTIVE_BARK',
        intentLabel: 'Local Reactive Bark: 60-FPS Dialogue Budget (<60ms)',
        justification: 'Reactive NPC dialogue/barter within 60-FPS interactive frame budget (<60ms). Executing on-device.',
        memoryDelta: 'Appended to local World State episodic log (0 KB cloud egress)',
        detectedPii: piiItems,
        estimatedTokens: tokens,
        requiresRedaction: false,
      );
    }

    // Rule 3: Priority 75 - Game Campaign & Faction Synthesis
    if (_isGameCampaignSynthesis(prompt)) {
      return RoutingEvaluationResult(
        route: ExecutionRoute.CLOUD_ESCALATE,
        ruleId: 'RULE_GAME_CAMPAIGN_SYNTHESIS',
        intentLabel: 'Grand Campaign Synthesis: Faction & Lore Evolution',
        justification: 'Multi-faction consequence simulation and high-context lore synthesis requires Gemini 3.8 Flash.',
        memoryDelta: 'World state flags & durable faction nodes injected; queued for cloud consolidation',
        detectedPii: piiItems,
        estimatedTokens: tokens,
        requiresRedaction: hasPii,
        requiresDurableMemories: true,
      );
    }

    // Rule 3.5: Priority 70 - Task Complexity & Multi-hop Temporal Synthesis
    if (_isComplexTask(prompt)) {
      return RoutingEvaluationResult(
        route: ExecutionRoute.CLOUD_ESCALATE,
        ruleId: 'RULE_COMPLEXITY_ESCALATION',
        intentLabel: 'Cloud Synthesis Intent: Cross-Session Architecture Alignment',
        justification: 'Multi-hop temporal reasoning and durable knowledge graph alignment required.',
        memoryDelta: 'Recalled durable memory anchors injected; queued for cloud consolidation',
        detectedPii: piiItems,
        estimatedTokens: tokens,
        requiresRedaction: hasPii,
        requiresDurableMemories: true,
      );
    }

    // Rule 4: Priority 10 - Default Edge Fast
    return RoutingEvaluationResult(
      route: ExecutionRoute.EDGE_LOCAL,
      ruleId: 'RULE_EDGE_DEFAULT_FAST',
      intentLabel: 'Local Edge Fast Intent: Zero-Latency Execution',
      justification: 'Bounded single-turn query within edge capacity. Executing on-device (Gemini Nano / Gemma 4) with sub-60ms TTFT.',
      memoryDelta: 'Committed to local SQLite working context cache',
      detectedPii: piiItems,
      estimatedTokens: tokens,
      requiresRedaction: false,
    );
  }

  void recordCloudSuccess() {
    consecutiveFailures = 0;
    if (circuitBreakerState == CircuitBreakerState.HALF_OPEN) {
      circuitBreakerState = CircuitBreakerState.CLOSED;
    }
  }

  void recordCloudFailure() {
    consecutiveFailures++;
    if (consecutiveFailures >= circuitBreakerThreshold) {
      circuitBreakerState = CircuitBreakerState.OPEN;
    }
  }

  void resetCircuitBreaker() {
    consecutiveFailures = 0;
    circuitBreakerState = CircuitBreakerState.CLOSED;
  }

  int _estimateTokenCount(String text) {
    // Standard rule-of-thumb: ~4 characters per token in English
    if (text.isEmpty) return 0;
    return (text.length / 3.8).ceil();
  }

  bool _isComplexTask(String text) {
    final lower = text.toLowerCase();
    return lower.contains('how does our decision') ||
        lower.contains('cross-session') ||
        lower.contains('temporal') ||
        lower.contains('multi-hop') ||
        lower.contains('refactor') ||
        lower.contains('architecture alignment') ||
        lower.contains('reconcile') ||
        lower.contains('contradiction') ||
        lower.contains('synthesize') ||
        lower.contains('historical context');
  }

  bool _isGameReactiveBark(String text) {
    final lower = text.toLowerCase();
    return lower.contains('gideon') ||
        lower.contains('lyra') ||
        lower.contains('elion') ||
        lower.contains('broadsword') ||
        lower.contains('billet') ||
        lower.contains('steel') ||
        lower.contains('grain manifest') ||
        lower.contains('barter') ||
        lower.contains('forge') ||
        lower.contains('docks') ||
        lower.contains('aqueduct') ||
        lower.contains('trade') ||
        lower.contains('supplies') ||
        lower.contains('ingot') ||
        lower.contains('state your business');
  }

  bool _isGameCampaignSynthesis(String text) {
    final lower = text.toLowerCase();
    return lower.contains('synthesize the political consequences') ||
        lower.contains('cross-faction') ||
        lower.contains('lore bible') ||
        lower.contains('region-wide consequence') ||
        lower.contains('cataclysm of the 3rd era') ||
        lower.contains('treaty collapse') ||
        lower.contains('inter-faction war') ||
        lower.contains('political fallout') ||
        (lower.contains('shadow syndicate') && lower.contains('consequences'));
  }

  bool _isVisualSynthesis(String text) {
    final lower = text.toLowerCase();
    return lower.contains('image') ||
        lower.contains('visual') ||
        lower.contains('concept art') ||
        lower.contains('forge commander\'s aegis') ||
        lower.contains('inspect encrypted lockbox') ||
        lower.contains('synthesize star astrolabe') ||
        lower.contains('render') ||
        lower.contains('illustration') ||
        lower.contains('portrait') ||
        lower.contains('blueprint') ||
        lower.contains('draw ') ||
        lower.contains('paint ');
  }
}

