# Dynamic Switching Policy & Intent Pill Specification

## 1. Routing Decision Matrix
The routing engine implements declarative evaluation based on five input dimensions:
1. **Visual Synthesis Intent**: Requests to generate, render, or illustrate visual concept art, blueprints, shields, or portraits.
2. **Privacy & Sensitivity**: Strict regex detection of emails, phone numbers, SSNs, credit cards, and API keys.
3. **Token Capacity**: Edge context window limit (strictly capped at 4,096 tokens).
4. **Task Complexity**: Single-turn Q&A / extraction vs multi-hop temporal synthesis.
5. **Hardware & Network State**: Browser `navigator.onLine` and Cloud Run ping latency.

### Prioritized Policy Rules
- **Priority 100 (`RULE_STRICT_PRIVACY`)**: Direct to `EDGE_LOCAL` whenever PII is detected (0.0 KB egress).
- **Priority 90 (`RULE_GAME_VISUAL_SYNTHESIS`)**: Direct to `CLOUD_ESCALATE` via Vertex AI **Nano Banana 2 Lite** (`gemini-3.1-flash-lite-image`) for visual generation (~1.2s latency).
- **Priority 85 (`RULE_GAME_REACTIVE_BARK`)**: Direct to `EDGE_LOCAL` for fast NPC dialogue barks, barters, and inventory checks (< 60ms TTFT).
- **Priority 80 (`RULE_CONTEXT_LIMIT_EXCEEDED`)**: Escalate to `CLOUD_ESCALATE` when prompt exceeds 4,096 tokens.
- **Priority 75 (`RULE_GAME_CAMPAIGN_SYNTHESIS`)**: Escalate to `CLOUD_ESCALATE` for cross-faction consequences, treaty impacts, and world event simulation.
- **Priority 70 (`RULE_COMPLEXITY_ESCALATION`)**: Escalate to `CLOUD_ESCALATE` for multi-hop architectural reasoning.
- **Priority 10 (`RULE_EDGE_DEFAULT_FAST`)**: Default to `EDGE_LOCAL` for standard conversational turns.

## 2. Intent Pill Semantic Contract
An Intent Pill in the UI is not an ambient label; it is a **functional contract badge** indicating:
- **User Intent**: The classified operational objective of the prompt.
- **Routing Justification**: The policy rule that triggered the route.
- **Memory Delta**: The local or cloud storage action taken.

### Visual Intent Pill Mapping

| Intent Type | Visual Style | Badge Text | Expansion Behavior |
|---|---|---|---|
| **Visual Synthesis** | Azure Electric Indigo (`#eff6ff` / `#1565c0`) | `[☁️ Visual Synthesis: Nano Banana 2 Lite (~1.2s)]` | Expands decoded base64 visual asset canvas, prompt inspection, and cloud telemetry. |
| **Local Privacy** | Sage Olive (`#ecfccb` / `#3f6212`) | `[🔒 Local Privacy Intent: PII Sanitization & Task Extraction]` | Expands local sanitized entities table; confirms 0.0 KB cloud egress. |
| **Game Bark** | Sage Olive (`#ecfccb` / `#3f6212`) | `[⚔️ Game Reactive Bark: Sub-60ms On-Device Dialogue]` | Displays on-device TTFT latency (<60ms) and 0.0 KB egress. |
| **Campaign Synthesis** | Warm Amber (`#fef3c7` / `#b45309`) | `[🏰 Campaign Synthesis: Cross-Faction Consequence Simulation]` | Expands multi-faction treaty impact, durable lore anchors, and Canon Arbiter score. |
| **Cloud Synthesis** | Warm Amber (`#fef3c7` / `#b45309`) | `[🌐 Cloud Synthesis Intent: Cross-Session Architecture Alignment]` | Expands recalled durable memory anchors (`#arch-anchor-48`, `#team-pref-02`). |
| **Offline Fallback** | Terracotta (`#ffedd5` / `#c2410c`) | `[⚡ Offline Fallback Intent: Degraded Tactical Answer (Pending Sync)]` | Shows offline queue indicator and network circuit breaker state. |
| **Edge Fast** | Slate Stone (`#f4efe6` / `#57534e`) | `[⚡ Local Edge Fast Intent: Zero-Latency Execution]` | Displays 32ms TTFT telemetry. |

## 3. A2UI Declarative Dynamic UI Protocol (a2ui.org)
The client hosts an immutable static component catalog at `client/assets/catalogs/lorecraft_catalog.json` defining standard UI primitives (`Card`, `Text`, `Badge`, `Button`, `ChoiceGroup`, `Slider`, `ImageCanvas`, `Divider`, `Row`, `Column`).

Edge models (Gemma 4 int4 / Gemini Nano) generate proactive narrative turns with embedded `A2UISurface` structures. Choices in a `ChoiceGroup` explicitly label edge vs cloud actions:
- **Edge Dilemmas**: Tagged with emerald/sage `EDGE` pills; executed locally via on-device dialogue (<60ms).
- **Visual Artifact Dilemmas**: Tagged with azure `CLOUD` pills; dispatched to Cloud Run `/api/image/generate` powered by **Nano Banana 2 Lite** with base64 visual rendering in `ImageCanvas`.

### Two-Step Cloud Visual Synthesis & Local Edge Turn Pipeline
When a player initiates or selects a visual synthesis action (`intent: visual_synthesis`, `requiresCloud: true`):
1. **Step 1 (Cloud Visual Synthesis)**:
   - Heavy generative multimodal rendering is escalated to Cloud Run / Vertex AI (`gemini-3.1-flash-lite-image` / Nano Banana 2 Lite).
   - Renders the visual concept card in `ImageCanvas` with full telemetry (`☁️ CLOUD ESCALATED • Nano Banana 2 Lite`, ~1.2s latency, base64 visual payload).
2. **Step 2 (Local Edge NPC Turn Transition)**:
   - Immediately upon asset materialization, execution seamlessly transitions to the on-device local model (`EDGE_LOCAL`, Gemma 4 int4 / Chrome Gemini Nano, sub-60ms TTFT, 0.0 KB cloud egress).
   - The active NPC reacts in-character with physical stage cues to the newly forged visual artifact (e.g. inspecting temper lines or cryptographic wax seals).
   - The on-device engine presents the next-stage proactive `A2UISurface` choices and dilemma sliders, allowing quest progression and dialogue flow to continue uninterrupted without requiring repeated cloud round-trips.
   - Commits the visual interaction and extracted entities to the private local episodic store.

## 4. Chrome Built-in AI & Fallback Contract

### Detection & Interop
- In Chrome browser sessions, the client dynamically detects `window.ai.languageModel` (or `window.LanguageModel`) via `client/web/js/chrome_prompt_api.js` and `dart:js_interop`.
- If Gemini Nano is downloaded and ready, execution is processed 100% on-device inside Chrome with zero cloud egress.

### Fallback Behavior & UI Indicators
- When Chrome Built-in AI is not enabled or unavailable, the system safely falls back to Cloud Escalation:
  1. **PII Sanitization**: Any sensitive identifiers are scrubbed locally before cloud transit.
  2. **Intent Pill Badge**: The intent pill displays an explicit `[FALLBACK]` indicator with the exact reason (e.g. `Chrome Prompt API unavailable`).
  3. **Amber Notice Banner**: An amber warning banner is displayed above the response in the center workspace:
     > *"⚠️ Execution Fallback: On-device Gemini Nano is not available in this browser session. Request was escalated to Gemini 3.8 Flash on Google Cloud Run."*
  4. **Right Drawer Inspector**: Shows step-by-step instructions for enabling Chrome Built-in AI:
     - Navigate to `chrome://flags/#prompt-api` (or `#prompt-api-for-gemini-nano`) and set to **Enabled**.
     - Ensure startup drive has >= 22 GB free disk space.
     - Restart Chrome and verify model status in `chrome://on-device-internals`.

## 5. LoreCraft Studio Interactive Switching UI Controls

The LoreCraft Studio game interface provides transparent, real-time exposure to the Firebase AI routing engine with zero false affordances:

### 1. Pre-Flight Foresight Pill (`LoreCraftForesightPill`)
- Positioned immediately above the player prompt console.
- **Dynamic Live Evaluation**: Debounces player typing and previews target execution path:
  - `⚡ On-Device Gemma 4 (<60ms) • Local Dialogue`
  - `☁️ Escalating to Gemini 3.8 Flash • Campaign Synthesis`
  - `🎨 Offloading to Nano Banana 2 Lite (~1.2s) • Visual Blueprint`
  - `🔒 Local Privacy Guard • 0 KB Egress`
- **Firebase AI Routing Dossier (Sheet Modal)**: Tapping the pill opens an interactive bottom sheet breaking down:
  - Target Execution Route (`EDGE_LOCAL`, `CLOUD_ESCALATE`, `EDGE_FALLBACK`)
  - Triggered Policy Rule (`RULE_GAME_REACTIVE_BARK`, `RULE_GAME_CAMPAIGN_SYNTHESIS`, `RULE_GAME_VISUAL_SYNTHESIS`, `RULE_STRICT_PRIVACY`)
  - Target Model Engine (Gemma 4 int4, Gemini 3.8 Flash, Nano Banana 2 Lite)
  - Memory Destination (Local Episodic Log vs Cloud Ingestion Queue)
  - Policy Rationale (Plain-English explanation answering What, Why, and What Changed)

### 2. Router Stance Switcher (`LoreCraftRouterDial`)
- Embedded in the Left Control Panel under World Overview.
- **Three Concrete Stances**:
  - `Smart Auto` (`RouterModeOverride.auto`): Standard dynamic evaluation across token budgets, intent rules, and network health.
  - `Force Edge` (`RouterModeOverride.enforceEdgeLocal`): Constrains all requests strictly to on-device Gemma 4 / Gemini Nano (0 KB cloud egress).
  - `Force Cloud` (`RouterModeOverride.enforceCloudFlash`): Bypasses on-device inference and escalates all reasoning directly to Gemini 3.8 Flash.
- **Mode Rationale Dialog**: Tapping the info icon (`Icons.info_outline`) renders an accessible dialog explaining when and why each mode is utilized.

### 3. Dialogue Card Dynamic Escalation Badge & Telemetry Inspector
- When an interaction is escalated to cloud reasoning or visual synthesis, dialogue cards display an amber/azure badge: `☁️ DYNAMIC ESCALATION • <Model> • <Latency>ms`.
- Tapping the badge opens the **Dialogue Frame Telemetry Inspector** showing:
  - Exact TTFT & Latency
  - Egress bytes
  - Active Firebase AI Policy rule
  - Plain-English Escalation Rationale
  - Working Memory Delta

## 6. Firebase AI Policy Synchronization & Zero-Mock Invariants

### Firebase AI Policy Gateway (`/api/policy/firebase`)
- **Remote Policy Arbitrator**: The client's [`FirebaseAiPolicyService`](../client/lib/services/firebase_ai_policy_service.dart) synchronizes dynamic routing rules, token thresholds (default 4,096 tokens), and circuit breaker limits from Cloud Run.
- **Dynamic Rule Refresh**: Rules fetched from the Cloud Run policy gateway override default local rules dynamically without requiring client recompilation.
- **Circuit Breaker**: When edge models fail or uninitialized weights are detected, the policy gateway trips the circuit breaker to transparently fallback to Cloud Run (`Gemini 3.8 Flash`) while recording accurate telemetry (`isFallback: true`, actual round-trip latency, and egress bytes).

### Zero-Mock Gemma 4 Weight Lifecycle & GemmaLoadPill
- **Zero Mock Policy**: The system strictly forbids fake inference generators, synthetic streaming loops, or hardcoded NPC dialogue responses.
- **User-Commanded Loading**: The [`GemmaLoadPill`](../client/lib/views/widgets/gemma_load_pill.dart) in the center workspace header provides real runtime commands:
  - **Web**: Allocates WebGPU device, streams weight bytes with progress percentages, and transitions from `Load Gemma 4 2B (~1.46 GB)` to `Gemma 4 2B Ready (0 KB Egress)`.
  - **Android**: Binds to Kotlin `MethodChannel("com.example.client/gemma_edge")`, checks `/data/local/tmp/gemma-4-2b-it-int4.bin`, and provides ADB copy instructions when uninitialized (`adb push gemma-4-2b-it-int4.bin /data/local/tmp/gemma-4-2b-it-int4.bin`).
- **Uninitialized State Handling**: Calling on-device inference without loaded weights raises a `StateError` or gracefully triggers the dynamic cloud fallback route with full transparency.

---

## 7. Related Documentation
- [System Architecture](architecture.md): Distributed edge-to-cloud architecture specification.
- [Model Matrix & Hardware Boundaries](model_matrix.md): Latency and hardware execution specifications.
- [Memory Pipeline Specification](memory_pipeline.md): Online/offline memory ingestion loops.
- [LLM-as-a-Rater Guide](eval_rater_guide.md): Automated evaluation benchmarks.
- [LoreCraft Dynamic Gameplay](lorecraft_dynamic_gameplay.md): LoreCraft studio switching UI and dynamic 3-card synthesis.


