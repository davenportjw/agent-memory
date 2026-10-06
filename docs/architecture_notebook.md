# Architecture & Runtime Code Notebook Guide

This technical guide documents the **Architecture Notebook** view (`client/lib/views/architecture_notebook_view.dart`) in the Antigravity Edge-to-Cloud system. It walks through the four computational notebook cells, their exact production code blocks, architectural ASCII diagrams, switching heuristics, and memory lifecycle mechanics.

---

## 1. Cell 1: Local AI Loading (Gemini Nano & Gemma 4)

### Cognitive Concept & Hardware Boundaries
Local on-device AI execution delivers three foundational guarantees:
1. **Strict 0 KB Cloud Egress**: Inputs, personal data, and intermediate activations never leave the client device.
2. **Sub-80ms First-Token Latency (TTFT)**: Zero roundtrip network delays for low-latency dialogue and reactive game barks.
3. **Hardware-Adaptive Binding**: The runtime probes browser capabilities dynamically:
   - If `window.LanguageModel` (or `window.ai.languageModel`) is supported, it binds to **Chrome Built-in Gemini Nano**.
   - If WebGPU is supported (`navigator.gpu`), it binds to **Gemma 4 int4** tensor buffers.
   - If WebGPU is unavailable, it falls back gracefully to CPU LiteRT.

### On-Device Dispatch State Machine

```
┌────────────────────────────────────────────────────────────────────────┐
│                   CLIENT ON-DEVICE ENGINE DISPATCH                     │
│                                                                        │
│                  LocalExecutionManager.init()                          │
│                                │                                       │
│        ┌───────────────────────┴───────────────────────┐               │
│        ▼                                               ▼               │
│ ┌───────────────────────────┐           ┌────────────────────────────┐ │
│ │    ChromePromptAPIService │           │      GemmaEdgeService      │ │
│ │   window.LanguageModel    │           │ navigator.gpu (WebGPU)     │ │
│ └──────────────┬────────────┘           └──────────────┬─────────────┘ │
│                │                                       │               │
│  [availability == 'readily']            [adapter.requestDevice()]      │
│                │                                       │               │
│  createSession({ monitor })             loadWeights(ReadableStream)    │
│                │                                       │               │
│                ▼                                       ▼               │
│ ┌───────────────────────────┐           ┌────────────────────────────┐ │
│ │  Gemini Nano Local Engine │           │   Gemma 4 int4 Pipeline    │ │
│ │  (Resident RAM: ~850 MB)  │           │  (Resident RAM: ~1,460 MB) │ │
│ └──────────────┬────────────┘           └──────────────┬─────────────┘ │
│                │                                       │               │
│                └───────────────────┬───────────────────┘               │
│                                    ▼                                   │
│                     executeOnDevice(prompt, onChunk)                   │
│                       Sub-80ms TTFT • 0 KB Egress                      │
└────────────────────────────────────────────────────────────────────────┘
```

### Production Code Snippets

#### Dart Client Manager (`client/lib/services/local_execution_manager.dart`)
```dart
Future<LocalExecutionResult> executeOnDevice({
  required String prompt,
  void Function(String delta)? onStreamChunk,
}) async {
  final engine = _resolveActiveEngine();

  // Engine 1: Chrome Built-in AI (Gemini Nano)
  if (engine == ActiveEdgeEngine.geminiNano && _chromeService.isActive) {
    final response = await _chromeService.promptStreaming(
      prompt,
      onDelta: onStreamChunk,
    );
    return LocalExecutionResult(
      modelName: _chromeService.modelName,
      text: response,
      engine: 'Chrome Built-in AI (Gemini Nano)',
      latencyMs: stopwatch.elapsedMilliseconds,
      egressBytes: 0,
    );
  }

  // Engine 2: On-Device WebGPU Compute (Gemma 4 int4)
  if (engine == ActiveEdgeEngine.gemma4 && _gemmaService.isModelLoaded) {
    final response = await _gemmaService.generateStreaming(
      prompt,
      onDelta: onStreamChunk,
    );
    return LocalExecutionResult(
      modelName: 'Gemma 4 2B (WebGPU int4)',
      text: response,
      engine: 'WebGPU Pipeline (Gemma 4)',
      latencyMs: stopwatch.elapsedMilliseconds,
      egressBytes: 0,
    );
  }

  throw StateError('No local on-device engine available. Initialize hardware first.');
}
```

#### Chrome Prompt API (`client/web/js/chrome_prompt_api.js`)
```javascript
async function createSession(options = {}) {
  const lm = _resolveLanguageModelAPI();
  if (!lm) throw new Error('Chrome Prompt API not available in this browser');

  const capabilities = await lm.availability();
  if (capabilities === 'no') throw new Error('Hardware unsupported for Gemini Nano');

  window._activeNanoSession = await lm.create({
    temperature: options.temperature || 0.7,
    topK: options.topK || 3,
    monitor(m) {
      m.addEventListener('downloadprogress', (e) => {
        const pct = Math.round((e.loaded / e.total) * 100);
        console.log(`[Gemini Nano] Model weights downloading: ${pct}%`);
      });
    }
  });
  return true;
}
```

---

## 2. Cell 2: Switching Logic (Zero-Egress Triage & Routing Matrix)

### Priority Hierarchy
Before dispatching any user prompt, the `SwitchingRouterService` processes an ordered decision ladder:

| Priority | Rule ID | Condition | Target Route | Rationale |
|---|---|---|---|---|
| **100** | `RULE_PRIVACY_PII_LOCAL` | Prompt matches Email, SSN, API key, Secret | `EDGE_LOCAL` | Strict Privacy Guarantee: Zero cloud egress for personal/credential data. |
| **85** | `RULE_GAME_REACTIVE_BARK` | Frame budget deadline $\le 60\text{ms}$ (Dialogue bark) | `EDGE_LOCAL` | Reactive frame rate parity without network jitter. |
| **80** | `RULE_LONG_CONTEXT_CLOUD` | Token volume $> 2,048$ tokens | `CLOUD_ESCALATE` | Edge WebGPU memory budget bounding prevents OOMs. |
| **75** | `RULE_COMPLEX_SYNTHESIS` | Multi-hop reasoning or cross-session synthesis | `CLOUD_ESCALATE` | Escalates to Gemini 3.8 Flash on Cloud Run for deep inference. |
| **0** | `RULE_CIRCUIT_BREAKER_OPEN` | Cloud error rate $\ge 3$ consecutive failures | `EDGE_FALLBACK` | Degraded tactical execution on local LiteRT CPU. |

---

## 3. Cell 3: Dreaming Logic to Create Memories (Offline Consolidation)

### The Offline "Dream Phase"
Conversational turns are written to local SQLite WASM immediately with zero cloud overhead. During idle periods or the overnight 03:00 AM cycle, the **Dream Consolidator** activates:
1. Batches pending turns from `Cloud Ingestion Queue`.
2. Invokes **Gemini 3.8 Flash** on Cloud Run to synthesize durable knowledge nodes.
3. Detects contradictions, audits conflicting assertions, and links entities with SHA-256 deterministic node IDs.
4. Recompiles the compact edge bundle ($< 50\text{ KB}$ strict ceiling) and publishes an atomic Dream Delta Update to the client.

#### Server Consolidator (`server/pkg/memory/consolidator.go`)
```go
func (c *Consolidator) Consolidate(ctx context.Context, sessionID string, forceAll bool) (*models.ConsolidateResponse, error) {
    turns, err := c.store.GetUnconsolidatedTurns(ctx, sessionID)
    if err != nil || len(turns) == 0 {
        return &models.ConsolidateResponse{Status: "success", ConsolidatedTurns: 0}, nil
    }

    existingNodes, _ := c.store.GetAllKnowledgeNodes(ctx)
    nodes, err := c.extractWithGemini(ctx, turns, existingNodes)
    if err != nil {
        nodes = c.dynamicRuleConsolidation(turns, existingNodes)
    }

    for _, node := range nodes {
        if node.ID == "" {
            node.ID = generateNodeID(node.Category, node.EntityName)
        }
        c.store.SaveKnowledgeNode(ctx, &node)
    }
    c.store.MarkTurnsConsolidated(ctx, extractTurnIDs(turns))
    return &models.ConsolidateResponse{Status: "success", ConsolidatedTurns: len(turns), NodesUpdated: len(nodes)}, nil
}
```

---

## 4. Cell 4: Selective Memory Loading Architecture (4 Patterns)

Edge agents must operate within tight tab memory budgets ($< 2\text{ GB}$). Megabytes of global memories cannot reside in active LLM context. The solution consists of 4 distinct operational patterns:

### Pattern 1: The Boot State (On-Load Minimization)
- **Footprint**: Strictly $< 4\text{ KB}$.
- **Contents**: Core Persona Directives (256 tokens) + Master Index Map + Environmental State (Battery, Network, Thermal).
- **Latency**: $0\text{ms}$ cold boot, zero context bloat.

### Pattern 2: Task-Bound Context (Just-In-Time Injection with Immediate Eviction)
- Paginates specific topic files into the LLM context **only** for the duration of a task.
- **Immediate Eviction Rule**: The loaded topic is evicted in a `finally` block immediately when the task concludes, preventing context leakage:
```dart
Future<T> executeTaskWithBoundContext<T>({
  required String taskId,
  required String taskName,
  required List<String> topicIds,
  required Future<T> Function() action,
}) async {
  final loadedTopics = [for (final id in topicIds) await fetchMemoryTopic(id)];
  _activeTaskContext = TaskBoundContext(...);
  notifyListeners();

  try {
    return await action();
  } finally {
    // Drop injected context immediately upon task conclusion
    _activeTaskContext = _activeTaskContext?.copyWith(isEvicted: true);
    notifyListeners();
  }
}
```

### Pattern 3: Pre-Emptive Predictive Caching (State Shifts)
- When environmental or world states shift (e.g., player enters Volcanic Caldera or thermal throttling engages), the runtime asynchronously prefetches relevant topic files into the local SQLite WASM RAM cache, ensuring $0\text{ms}$ cache hits when prompted.

### Pattern 4: Asynchronous Dream Syncs (The "Morning After")
- The overnight daemon replaces the Master Index version, invalidates stale local topic files, and prunes superseded directives, maintaining strict $< 50\text{ KB}$ active edge bundle limits.
