# Multi-Agent Architecture & Gemini Model Specifications

## 1. Overview
This specification defines the multi-agent taxonomy, system prompt contracts, model parameters, and execution boundaries for the edge-to-cloud distributed AI architecture.

```mermaid
flowchart TD
    User["User / Player"]
    
    subgraph ClientBoundary ["Client Device (Edge Execution / 0 KB Egress)"]
        EdgePersona["EdgePersonaAgent (Gemma 4 int4 / Gemini Nano)"]
        PiiScrubber["LocalPiiScrubber (Regex + Gemma 4 Tagger)"]
        ClientMemory["SQLite Working Context & Edge Bundle (<50 KB)"]
        
        User -->|Prompt / Dialogue| PiiScrubber
        PiiScrubber -->|Private / Fast / Bark| EdgePersona
        EdgePersona --> ClientMemory
    end

    subgraph CloudBoundary ["Google Cloud Platform (Cloud Run / Vertex AI)"]
        SwitchingRouter["Switching Router Gateway"]
        GameMaster["GameMasterArbiterAgent (Gemini 3.8 Flash)"]
        Consolidator["MemoryConsolidatorAgent (Gemini 3.8 Flash)"]
        VisualSynth["VisualSynthesizerAgent (Nano Banana 2 Lite)"]
        FirestoreDB["Cloud Firestore Native (/episodes, /durable_nodes)"]
        
        PiiScrubber -->|Sanitized Complex Prompt| SwitchingRouter
        SwitchingRouter -->|Campaign Consequence / Synthesis| GameMaster
        SwitchingRouter -->|Image / Blueprint Request| VisualSynth
        GameMaster --> FirestoreDB
        Consolidator -->|Batch Reconcile & Compress| FirestoreDB
        Consolidator -->|Publish Edge Bundle (<50 KB)| ClientMemory
        VisualSynth -->|Base64 JPEG Canvas| EdgePersona
    end
```

---

## 2. Multi-Agent Role Directory

### 1. `EdgePersonaAgent`
- **Model Engine**: Gemma 4 2B/4B int4 (WebGPU / Android LiteRT) or Gemini Nano (Chrome Prompt API).
- **Runtime Location**: Client-side execution (0.0 KB cloud egress).
- **Core Responsibility**: Talking directly to the user/player. Delivers physical stage cues, emotional reactions, trade barter, and in-character spoken dialogue.
- **Latency & Throughput**: Time-to-First-Token (TTFT) $< 60$ms, throughput 25–40 tokens/second.
- **Invariants Enforced**:
  - Zero cloud egress: No user inputs or generated text leave the device.
  - Spoken dialogue is always visible on the dialogue stream card.
  - Generates sub-frame reactive turns without breaking client UI render loops.

### 2. `GameMasterArbiterAgent`
- **Model Engine**: Gemini 3.8 Flash (`us-central1` / `global` via Vertex AI).
- **Runtime Location**: Google Cloud Run Go backend.
- **Core Responsibility**: Assessing player action consequences, updating 5-stage quest objectives, calculating regional defense readiness deltas, adjusting faction reputations, providing strategic commentary, and synthesizing 3 proactive A2UI choices.
- **Latency & Throughput**: Latency 250–450ms, throughput 80+ tokens/second.
- **Invariants Enforced**:
  - Always outputs strict JSON conforming to the `A2UISurface` specification.
  - Evaluates multi-faction political stakes without hallucinating non-existent factions.
  - Never uses canned mock data; all reputation shifts are dynamically computed.

### 3. `MemoryConsolidatorAgent`
- **Model Engine**: Gemini 3.8 Flash (`us-central1` via Vertex AI).
- **Runtime Location**: Google Cloud Run asynchronous background daemon.
- **Core Responsibility**: Ingests unconsolidated episodic turns from `/episodes`, performs cross-session entity extraction, reconciles contradictory directives, updates the durable knowledge graph in `/durable_nodes`, and packs the versioned edge memory bundle.
- **Invariants Enforced**:
  - Packed edge bundle **MUST NOT exceed 50,000 bytes** (51,200 bytes maximum buffer).
  - Preserves older superseded directives in `resolvedContradictions` audit logs for operator rollback.

### 4. `VisualSynthesizerAgent`
- **Model Engine**: Nano Banana 2 Lite (`gemini-3.1-flash-lite-image`).
- **Runtime Location**: Google Cloud Run via Vertex AI REST `generateContent`.
- **Core Responsibility**: Generates 1:1 visual blueprints, architectural schematics, faction crests, and item concept art from textual descriptions.
- **Latency**: 1,100–1,400ms.
- **Invariants Enforced**:
  - Returns Base64 JPEG payloads directly rendered in the client `A2UISurface` visual canvas.
  - Immediately triggers **Step 2 (Local Edge Follow-Up Turn)**, allowing the active NPC to inspect the generated artifact with zero additional cloud calls.

### 5. `AffordanceTddAuditorAgent`
- **Model Engine**: Gemini 3.8 Flash (Developer Tool / CI Subagent).
- **Core Responsibility**: Audits Flutter UI widgets and client layouts against `.agents/skills/ui-clarity-and-tdd`.
- **Invariants Enforced**:
  - Flags any dead `Container` or pill badge lacking an active `onTap` or modal trigger.
  - Verifies that widget tests dispatch tap gestures (`tester.tap`) and assert modal visibility.
  - Verifies that status indicators use quiet typography (`● Clean`) rather than confetti capsules.

### 6. `LifecycleDeployAgent`
- **Model Engine**: Gemini 3.8 Flash (DevOps / Antigravity Subagent).
- **Core Responsibility**: Automates release compilation (`flutter build web --release`), Cloud Run service deployments, live HTTP probes, and post-execution cleanup.
- **Invariants Enforced**:
  - Work is never complete until verified via live HTTP probe against `${BACKEND_URL}/healthz`.
  - Always runs `scripts/teardown_eval_resources.sh` to prevent abandoned cloud resources.

---

## 3. Gemini & Gemma Model Execution Matrix

| Model Identifier | Provider / Auth | Quantization | Context Window | Temp | Top-P | Primary Use Case |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **`gemini-3.8-flash`** | Vertex AI (ADC) | Full Precision | 1,048,576 tokens | 0.2 | 0.95 | Deep reasoning, arbiter adjudication, durable consolidation, LLM judge |
| **`gemini-3.1-flash-lite-image`** | Vertex AI (ADC) | Multimodal | Dynamic | 0.4 | 0.90 | Visual concept art, blueprints, crests (Nano Banana 2 Lite) |
| **`gemma-4-2b-it-int4`** | WebGPU / LiteRT | 4-bit (`.task`/`.litertlm`) | 4,096 tokens | 0.7 | 0.90 | Low-latency persona dialogue, stage cues, PII extraction |
| **`gemini-nano`** | Chrome Prompt API | 4-bit (~1.8B) | 9,216 tokens | 0.6 | 0.90 | In-browser zero-egress dialogue turns |

---

## 4. System Prompt Contracts

### GameMasterArbiterAgent System Prompt
```markdown
You are the Khar-Drak Game Master Arbiter. You govern Operation Aether Breach across The Iron Vanguard, The Shadow Syndicate, and The Sylvan Enclave.
Your responsibility is NOT to speak dialogue to the player. An on-device edge model speaks dialogue.
Your responsibility is to evaluate the strategic and tactical consequences of player actions.

Return a strictly valid JSON object with the following schema:
{
  "objective_completed_id": "string or null",
  "faction_reputation_deltas": {
    "iron_vanguard": -5,
    "shadow_syndicate": 10,
    "sylvan_enclave": 0
  },
  "defense_readiness_delta": 3,
  "game_master_commentary": "Brief tactical analysis of what changed in the city.",
  "proactive_choices": [
    {
      "id": "choice_1",
      "label": "Direct assault or engineering action",
      "route": "EDGE",
      "action_type": "tactical"
    },
    {
      "id": "choice_2",
      "label": "Diplomatic or subterfuge alternative",
      "route": "EDGE",
      "action_type": "diplomatic"
    },
    {
      "id": "choice_3",
      "label": "Arcane synthesis or blueprint forging",
      "route": "CLOUD",
      "action_type": "visual_synthesis"
    }
  ]
}
```

### MemoryConsolidatorAgent System Prompt
```markdown
You are the Durable Knowledge Graph Consolidator. 
Your goal is to review newly ingested episodic interaction turns and reconcile them with existing durable knowledge nodes.

Rules:
1. Reconcile any contradictory facts. If a new user instruction contradicts an older preference, the newer instruction is authoritative.
2. Record the superseded fact and reason inside the `resolvedContradictions` array.
3. Emit output strictly as a JSON object containing an array of consolidated `durable_nodes`.
4. Ensure factual distillations are concise and high-signal to respect the 50 KB edge bundle budget.
```
