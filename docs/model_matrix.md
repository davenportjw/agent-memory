# Factual Model Matrix & Hardware Execution Capabilities

This reference document outlines the empirical specifications, runtime behaviors, and hardware constraints of models deployed across the edge-to-cloud architecture.

## 1. Matrix Overview

| Environment | Model Engine | Model Name | Quantization / Format | Context Window | Time-to-First-Token (TTFT) / Latency | Throughput / Modality | Egress / Privacy |
|---|---|---|---|---|---|---|---|
| **Browser (WASM/WebGPU)** | MediaPipe LLM WebGPU | **Gemma 4 2B / A4B** | int4 (.task / .litertlm) | 2,048–4,096 tokens | 60–140 ms | 25–40 tps (Text) | 0 KB Cloud Egress (Fully Local) |
| **Browser (Built-in)** | Chrome Prompt API (`window.LanguageModel` / `window.ai`) | **Gemini Nano** | 4-bit (~1.8B params) | 4,096–9,216 tokens | 30–55 ms | ~40 tps (Text) | 0 KB Cloud Egress (Fully Local) |
| **Android Emulator** | LiteRT-LM CPU-fallback | **Gemma 4 2B** | int4 (.litertlm) | 2,048–4,096 tokens | 220–550 ms | 10–20 tps (Text) | 0 KB Cloud Egress (Fully Local) |
| **Google Cloud (Cloud Run)** | Vertex AI Go SDK | **Gemini 3.8 Flash** | Full Precision (Cloud Hosted) | 1,048,576 tokens | 250–450 ms | 80+ tps (Text / JSON) | HTTPS with ADC Auth |
| **Google Cloud (Cloud Run)** | Vertex AI REST (`generateContent`) | **Nano Banana 2 Lite** (`gemini-3.1-flash-lite-image`) | Multimodal Generator | Variable | 1,100–1,400 ms | Base64 JPEG Image + Text Caption | HTTPS with ADC Auth |

## 2. A2UI Agent-Driven Interface Protocol (a2ui.org)
- **Static Catalog (`client/assets/catalogs/lorecraft_catalog.json`)**: Declares standard components (`Card`, `Text`, `Badge`, `Button`, `ChoiceGroup`, `Slider`, `ImageCanvas`, `Divider`, `Row`, `Column`).
- **Dynamic Surface Synthesis**: Edge models (Gemma 4 / Gemini Nano) generate proactive dilemma dialogue and declarative surface JSON trees (`A2UISurface`).
- **Escalation Routing**: Tapping cloud-flagged choices (`intent: visual_synthesis`) dynamically triggers the Vertex AI Cloud Run endpoint (`/api/image/generate`) running **Nano Banana 2 Lite** with zero local compute strain.

### 2.1 Two-Step Hybrid Orchestration (Cloud Visual Synthesis -> Edge Follow-Up Turn)
To avoid dead UI state after cloud image rendering, the system employs a two-step turn orchestration:
1. **Step 1 (Cloud Visual Synthesis)**: The player's visual prompt or A2UI action is dispatched to Cloud Run (`/api/image/generate`) using `gemini-3.1-flash-lite-image` (Nano Banana 2 Lite). The synthesized base64 image and descriptive caption materialize inside an `A2UISurface` visual canvas card attributed to the cloud backend.
2. **Step 2 (Local Edge Follow-Up Turn)**: Upon reception of the cloud asset, execution immediately advances to the local edge model (Gemma 4 int4 / Gemini Nano). The active NPC evaluates the newly materialized artifact in-character, delivers physical stage cues and spoken dialogue (<60ms TTFT, 0.0 KB egress), and generates the next proactive A2UI choice surface to progress the scene dynamically.


## 3. Hardware Execution Guardrails

### Chrome Built-in AI (Gemini Nano) Specifications
- Standard: W3C Prompt API interface exposed via `window.LanguageModel` (with backward compatibility fallback to `window.ai.languageModel`).
- Initialization Semantics: When `LanguageModel.availability()` returns `'downloadable'`, creating the session requires an explicit **user gesture** (e.g. clicking the "Create Language Model" button in the UI).
- Progress Monitoring: Tracked through `create({ monitor(m) { m.addEventListener('downloadprogress', ...) } })`.
- Storage Requirement: Chrome requires >= 22 GB free disk space on the system drive and an unmetered connection.
- Deprecated Flags: Legacy `#optimization-guide-on-device-model` has been removed from modern Chrome; users only need `#prompt-api` (or `#prompt-api-for-gemini-nano`).

### Client Guardrails (Apple Silicon Host)
- To prevent kernel memory watchdog panics on macOS, heavy model training, fine-tuning, large weight loading, or unrolled autoregressive loops locally are strictly prohibited.
- Local execution is strictly restricted to fast unit tests (`flutter test`, `uv run pytest`) and int4 Gemma 4 / Gemini Nano browser inference. Heavy visual synthesis tasks are routed to Cloud Run (`gemini-3.1-flash-lite-image`).

### Android Emulator & Native Device Behavior
- Android AICore (system Gemini Nano) is disabled on Android Virtual Devices (AVDs) because emulators lack physical NPU virtualization.
- The reference implementation executes **LiteRT-LM with Gemma 4 2B** using CPU fallback on the emulator or GPU delegate on native hardware via Flutter `MethodChannel("com.example.client/gemma_edge")`.
- Model weights are loaded from `/data/local/tmp/gemma-4-2b-it-int4.bin` or app internal storage via `adb push`.

## 4. Gemma 4 Runtime Loading Protocol & GemmaLoadPill
To avoid silent mocks and heavy unrequested downloads, Gemma 4 weight loading is explicitly user-commanded via the **Gemma Load Pill** in the workspace header:
- **Web (WebGPU)**: Allocates `navigator.gpu.requestAdapter()`, streams weight bytes with real-time transfer counters and percentage calculation, and transitions from `Load Gemma 4 2B (~1.46 GB)` to `Gemma 4 2B Ready (0 KB Egress)`.
- **Android Native (LiteRT / MediaPipe GenAI)**: Binds to Kotlin `MethodChannel("com.example.client/gemma_edge")`. If `/data/local/tmp/gemma-4-2b-it-int4.bin` is not resident, presents a copyable ADB push command dialog (`adb push gemma-4-2b-it-int4.bin /data/local/tmp/gemma-4-2b-it-int4.bin`). Once pushed, `loadModel` executes `LlmInference.createFromOptions`.
- **Zero-Mock Enforcement**: Attempting edge execution without resident weights immediately raises a `StateError` or transparently executes an edge fallback turn to Cloud Run (`Gemini 3.8 Flash`) with truthful telemetry attribution (`isDynamicallyEscalated: true`, `route: EDGE_FALLBACK`).

### Cloud Guardrails (Google Cloud Vertex AI)
- All cloud inference uses Google Cloud Application Default Credentials (ADC) without API key dependencies.
- Vertex AI endpoints use `global` (or `us-central1`), with Cloud Run services hosted in `us-central1`.
- Reasoning Model ID: `gemini-3.8-flash`.
- Visual Synthesis Model ID: `gemini-3.1-flash-lite-image` (Nano Banana 2 Lite) with `generationConfig.responseModalities: ["TEXT", "IMAGE"]`.
- Policy Gateway Endpoint: `/api/policy/firebase` serving live Firebase Remote Config dynamic routing parameters.
