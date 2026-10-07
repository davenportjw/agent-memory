# LoreCraft Dynamic Story Engine & Mission Progression Architecture

## 1. Executive Summary

LoreCraft delivers an immersive, distributed AI game narrative experience powered by a **Dual-Model Decoupled Architecture**:
1. **Model 1: Conversational Persona Model ("Talking to User")**:
   - **Local Edge (Default)**: Gemma 4 int4 / Chrome Prompt API Gemini Nano. Sub-60ms TTFT, 0.0 KB cloud egress.
   - Speaks directly in-character with physical stage cues, emotive tone, and immediate reactions. Spoken dialogue is always visible on the dialogue stream card.
   - Attribution badge: `Gemma 4 int4 (Edge Local)` or `Gemini 3.8 Flash`.
2. **Model 2: Game Master Arbiter Model ("Assessing Next Actions")**:
   - **Cloud Run (Primary)**: Cloud Run calling Vertex AI **Gemini 3.8 Flash** (`us-central1`).
   - Evaluates the tactical impact of player actions against 5-stage quest objectives, calculates regional defense readiness deltas, assesses faction standing shifts, adjudicates objective completion, and synthesizes 3 proactive choices.
   - **Local Edge Fallback**: Gemma 4 int4 on-device structured generation ensures offline continuity without mocks.
   - Attribution badge: `Gemini 3.8 Flash (Cloud Run)` or `Gemma 4 int4 (Edge Arbiter)` accompanied by Game Master Commentary.
3. **Pre-Dialogue Mission Briefing**: The user is presented with a complete strategic mission directive—including an overarching crisis narrative, threat level, primary objectives, and multi-faction political stakes—**before speaking to any NPC persona**.
4. **Initial Contact & Sector Entry Point Selection**: The user selects which faction contact persona (Gideon Ironhand in the Foundry, Lyra Vance in the Smuggler's Docks, or Archivist Elion in the Keystone Spire) to consult first, establishing an intentional diplomatic entry point into the crisis.
5. **5-Stage Quest Tracks**: Non-linear branching narrative spanning Emergency Mobilization, Sector Operations, Tactical Delivery, Climax: Operation Aether Breach Containment, and Regional Accord Victory.
6. **Persistent Mission Dossier Access**: The strategic directive remains accessible at any point during active dialogue via the `MISSION DOSSIER` header pill, allowing players to review objectives and faction stakes without losing conversation context.

---

## 2. Dual-Model Architecture & Division of Labor

```
                      [In-Card A2UI Proactive Choice]     OR     [Foresight-Guided Freeform Input]
                                      │                                         │
                                      ▼                                         ▼
                      ┌─────────────────────────────────────────────────────────┐
                      │                 Dual-Model Architecture                 │
                      └────────────────────────┬────────────────────────────────┘
                                               │
                      ┌────────────────────────┴────────────────────────┐
                      ▼                                                 ▼
           [Model 1: Persona Model]                          [Model 2: Game Master Arbiter]
           Role: Talking to User                             Role: Assessing Consequences & Next Actions
           Location: Local Edge (Gemma 4 int4)               Location: Cloud Run (Gemini 3.8 Flash)
           TTFT: < 60ms                                      Egress: Structured Prompt
           Output:                                           Output:
           • In-character speech                             • Objective completion check
           • Stage cues / emotional tone                     • Faction reputation shift
           • Direct response to player inquiry               • Defense readiness delta (+/- %)
                                                             • Game Master strategic commentary
                                                             • 3 Proactive contextual choices
                      │                                                 │
                      └────────────────────────┬────────────────────────┘
                                               ▼
                              [LoreCraft Dialogue Card Stream]
                              • Persona Speech & Stage Cues (Always Visible)
                              • Game Master Strategic Commentary Pill
                              • Dual-Model Attribution Badges
                              • Dynamic A2UI Action Surface (3 Contextual Choices)
                                               │
                                               ▼
                              [Streamlined Chat Input Surface]
                              • LoreCraftForesightPill: Real-time route foresight (<60ms)
                              • Firebase AI Routing Dossier Modal with Benchmark Probes
                              • Freeform dialogue text field for unscripted player inquiry
```

---

## 3. Pre-Dialogue Strategic Mission Briefing

### 2.1 The Crisis Narrative: Operation Aether Breach
Before entering Khar-Drak, the player reviews the high-level situation:
- **Title**: `OPERATION AETHER BREACH: The Khar-Drak Subterranean Cataclysm`
- **Threat Level**: `CRITICAL • LEVEL 4 ARCANE SURGE`
- **Harmonic Resonator Status**: `Online • 3 Harmonic Cells Charged`
- **Tactical Intelligence**: A catastrophic seismic fracture beneath the Subterranean Foundry has breached the deep subterranean magma conduits, threatening to flood the lower residential aqueducts with molten slag and destabilize the Keystone Spire's arcane canopy.
- **Primary Objectives**:
  1. `obj-containment`: Seal Lower Foundry Magna Gates (High Priority)
  2. `obj-aqueduct`: Safeguard Municipal Aqueducts & Civilian Canals (Critical Priority)
  3. `obj-resonance`: Stabilize Keystone Spire Harmonic Array (Strategic Priority)

### 3.2 Faction Stakes Matrix
The briefing articulates the conflicting incentives of the city's three governing powers:
| Faction | Stance | Critical Risk | Strategic Opportunity |
| :--- | :--- | :--- | :--- |
| **The Iron Vanguard** | Lockdown and Magma Diversion | Subterranean forge collapse and loss of smithing infrastructure | Complete territorial hegemony over lower industrial districts |
| **The Shadow Syndicate** | Evacuation and Contraband Extraction | Sluice gates flooded with toxic volcanic slag | Extorting desperate merchant guilds for passage rights |
| **The Sylvan Enclave** | Leyline Harmonic Resonance Dampening | Tectonic shockwave shattering living crystal canopy | Harmonizing volatile arcane flux into permanent crystalline wards |

### 3.3 Sector Contact Selection
The player chooses an initial liaison to receive their starting deployment:
- **Gideon Ironhand** (Ironmongers Guildmaster, Subterranean Foundry): Direct assault and engineering lockdown.
- **Lyra Vance** (Smuggler's Guild Navigator, The Sunken Docks): Clandestine canal bypasses and contraband valve ciphers.
- **Archivist Elion** (Keepers of the Grove Scholar, Keystone Spire): Arcane calibration and crystalline dampening.

---

## 4. 5-Stage Dynamic Quest Tracks & Game Master Assessment

Each sector contact features a rich 5-stage progression with real consequences evaluated by the Game Master Arbiter:

```
Stage 0: Emergency Mobilization
   │   (Palisade fortifications, Slipway #4 sabotage, Lower Aqueduct leaks)
   ▼
Stage 1: Sector Operations
   │   (Forging runic broadswords, Contraband sluice rerouting, Leyline conduit survey)
   ▼
Stage 2: Tactical Delivery
   │   (Western Watch Garrison delivery, Secret Guild Vault access, Ancient Inscription recovery)
   ▼
Stage 3: Climax: Operation Aether Breach Containment
   │   (Slamming thermal blast dampers, Detonating subterranean acoustic charges, Weaving living roots)
   ▼
Stage 4: Mission Victory & Regional Accord Resolution
       (Foundry core stabilized, city canals safeguarded, celestial crystal harmony achieved)
```

### 4.1 Game Master Assessment Contract
When evaluating player actions, the Game Master Arbiter outputs structured JSON:
```json
{
  "consequence_summary": "The thermal blast dampers lock in place with a shuddering groan...",
  "readiness_delta": 25.0,
  "faction_deltas": {
    "vanguard": 20,
    "syndicate": -5,
    "enclave": 10
  },
  "is_objective_completed": true,
  "game_master_commentary": "Critical breach contained. Proceed to seal the regional accord.",
  "choices": [
    {
      "id": "choice_climax_1",
      "label": "Seal Regional Accord",
      "description": "Ratify the tripartite defense treaty between the Guilds.",
      "intent": "local_dialogue",
      "prompt": "The breach is sealed. We must sign the treaty before tensions reignite.",
      "requiresCloud": false
    }
  ]
}
```

---

## 5. Dynamic Next-Turn Option Synthesis

### 5.1 On-Device Generation Loop
Unlike static decision trees, next-turn action cards are synthesized dynamically using the on-device model:
```
[User Action / Dialogue Turn]
             │
             ▼
[Local Working Context Cache] ──► [Latest Transcript + Active Quest Objective]
                                                │
                                                ▼
                                    [On-Device Gemma 4 int4]
                                 (Structured JSON Output Prompt)
                                                │
                                                ▼
                                     [3 Dynamic Action Cards]
                                    • Card 1: Local Dialogue / Inquiry
                                    • Card 2: Local Tactical Maneuver
                                    • Card 3: Cloud Visual Synthesis (A2UI)
```

### 5.2 Prompt Contract & JSON Schema
The on-device model is prompted with the active NPC persona, faction, current quest goal, and the latest conversation excerpt:
```json
[
  {
    "id": "choice_dyn_1",
    "label": "Inquire About Vanguard Valve Ciphers",
    "description": "Press Lyra for the cryptographic bypass frequencies to unlock the lower sluice valves.",
    "intent": "local_dialogue",
    "prompt": "What cipher key do the Vanguard engineers use to seal the lower aqueduct gates?",
    "requiresCloud": false
  },
  {
    "id": "choice_dyn_2",
    "label": "Deploy Counter-Surveillance Shunt",
    "description": "Jam Vanguard acoustic listening needles to mask our movement through the water tunnels.",
    "intent": "local_dialogue",
    "prompt": "Drop the sonic dampeners into the drainage channel to mask our approach.",
    "requiresCloud": false
  },
  {
    "id": "choice_dyn_3",
    "label": "Synthesize Undercity Sluice Blueprint",
    "description": "Materialize concept art of the submerged aqueduct labyrinth via Vertex AI Nano Banana 2 Lite.",
    "intent": "visual_synthesis",
    "prompt": "Submerged aqueduct labyrinth beneath Khar-Drak with glowing rune lanterns",
    "requiresCloud": true
  }
]
```

### 5.3 Visual Synthesis Handoff
When the user selects a `visual_synthesis` card or prompts for visual concept art:
1. **Cloud Escalation**: The client calls Cloud Run (`https://distributed-ai-backend-834476222725.us-central1.run.app/api/image/generate`) via `CloudImageClient` to materialize the masterwork concept art using Vertex AI `gemini-3.1-flash-lite-image` (Cloud Nano Banana 2 Lite).
2. **Generative UI Rendering**: An inline `A2UiSurfaceCard` renders the materialized image with inspection affordances, metadata chips, and prompt provenance. If cloud connectivity is temporarily interrupted, the dialogue card provides an actionable `Retry Visual Synthesis (Cloud Run)` affordance with zero dead UI.
3. **Local Follow-Up Bark**: The on-device Gemma 4 model observes the completion of the visual synthesis and automatically generates an immediate in-character reactive bark from the active NPC (e.g., Lyra inspecting the contraband seals under dim lantern light).

### 5.4 Mission Dossier Progression & A2UI Game Moments
To bridge high-level strategic objectives with dialogue-level action:
1. **Dynamic Mission Dossier Synchronization**:
   - `LoreCraftService` maintains an immutable `GameMission` state with primary objectives:
     - `obj-containment`: Seal Lower Foundry Magma Gates (Gideon)
     - `obj-aqueduct`: Safeguard Municipal Aqueducts & Civilian Canals (Lyra)
     - `obj-resonance`: Stabilize Keystone Spire Harmonic Array (Elion)
   - Objectives automatically mark `isCompleted: true` when:
     - Specific tactical milestones are reached (e.g., cracking Undercity sluice ciphers).
     - Game Master Arbiter completes an objective via prompt assessment.
     - Quest stages advance to climax or victory stages.
2. **Declarative A2UI Game Moments in Chat Stream**:
   - Rather than confining game progression updates to passive modals or toasts, significant moments (tactical milestones, objective completions, mission victory) are directly declared in the A2UI component tree of the dialogue turn.
   - `A2UISurface.createProactiveTurn` injects a dedicated `milestone_card` containing:
     - `milestone_badge`: `🏆 STRATEGIC OBJECTIVE COMPLETED • MISSION DOSSIER UPDATED` chip.
     - `milestone_title`: Clear objective headline in subheading typography.
     - `milestone_desc`: Concrete narrative impact explaining what was achieved and why.
     - `milestone_meta`: Faction alignment delta and memory provenance citation.
     - `milestone_btn`: `Inspect Mission Dossier ➔` interactive button affordance (`actionId: 'open_dossier'`, `intent: 'inspect_dossier'`).
3. **Zero False Affordances**:
   - Tapping `Inspect Mission Dossier ➔` directly opens the strategic `LoreCraftMissionBriefingCard` dialog.
   - Objectives completed in dialogue immediately show green checkmarks (`Icons.check_circle` in `SepiaTheme.sage`) within the dossier modal.

---

## 6. UI Architecture & Responsive Affordances

### 6.1 Sepia Design System Standards
- **Academic Light Theme**: High-contrast, distraction-free parchment canvas (`#FAF7F2`) with dark warm ink (`#1C1917`) and subtle borders (`#E6DFD5`).
- **Zero False Affordances**:
  - Interactive elements have explicit hover/focus states, key listeners, and accessible labels.
  - Informational badges (e.g. `CRITICAL • LEVEL 4 ARCANE SURGE`) use distinct quiet pill styling that cannot be confused with clickable buttons.
  - **Streamlined Player Input**: Removed vestigial static prompt rows above the chat input to eliminate false affordances and NPC/stage disconnects. Input flows exclusively through in-card dynamic A2UI proactive choices and foresight-guided freeform input. Static model switching probes are preserved within the Firebase AI Routing Dossier modal.
- **Responsive Flex Safety**: All horizontal headers, tags, and radio labels utilize `Wrap` or `Expanded` with `TextOverflow.ellipsis` to guarantee zero layout overflow across desktop split-screens, tablets, and mobile viewports down to 320px.

### 6.2 State Transition Diagram
```mermaid
stateDiagram-v2
    [*] --> PreDeploymentBriefing : App Launch / hasAcceptedMission == false
    
    state PreDeploymentBriefing {
        [*] --> ViewDossier
        ViewDossier --> SelectContact : Select Radio (Gideon / Lyra / Elion)
        SelectContact --> AcceptMission : Tap "ACCEPT MISSION & DEPLOY"
    }

    AcceptMission --> ActiveDialogueSession : hasAcceptedMission == true
    
    state ActiveDialogueSession {
        [*] --> SeedOpeningTurn
        SeedOpeningTurn --> SynthesizeDynamicCards : On-Device Gemma 4
        SynthesizeDynamicCards --> PlayerSelectsCard
        PlayerSelectsCard --> DispatchAction : Local Turn or Cloud Image
        DispatchAction --> CheckObjectiveProgress : Objective Completed?
        CheckObjectiveProgress --> GameMomentA2UI : Milestone Reached / Objective Completed
        GameMomentA2UI --> SynthesizeDynamicCards : Next Turn (With Milestone Card & Inspect Dossier Affordance)
        ActiveDialogueSession --> ViewDossierModal : Tap "MISSION DOSSIER" or In-Card "Inspect Mission Dossier ➔"
        ViewDossierModal --> ActiveDialogueSession : Dismiss Dialog (Updated Checkmarks Visible)
    }
```

---

## 7. Automated Verification & Test Suite Parity

Continuous verification is maintained across both unit and widget integration tests:

| Test File | Coverage Areas | Verification Status |
| :--- | :--- | :--- |
| `client/test/mission_dossier_a2ui_game_moments_test.dart` | Milestone-to-dossier auto-completion, quest stage advancement objective synchronization, declarative A2UI Game Moment Card generation, `A2UISurfaceView` rendering with `Inspect Mission Dossier ➔`, and in-studio modal launch showing verified green checkmark | **5/5 PASSING** |
| `client/test/mission_and_dynamic_cards_test.dart` | `GameMission` model integrity, immutable `copyWith`, `LoreCraftService` pre-dialogue guard, contact seeding, dynamic 3-card generation, Lyra water context handling, `LoreCraftMissionBriefingCard` widget rendering, radio selection, streamlined studio input layout, and studio deployment transitions | **11/11 PASSING** |
| `client/test/cloud_sse_client_test.dart` | SSE protocol line parsing, handling `event: error` and JSON error payloads without leaking raw tokens, data chunk assembly, comment stripping | **2/2 PASSING** |
| `client/test/lorecraft_switching_feature_test.dart` | `LoreCraftRouterDial` 3-mode stance toggle, `LoreCraftForesightPill` dynamic route preview, `Firebase AI Routing Dossier` bottom sheet with quick route benchmark probes, Dialogue Card dynamic escalation badging, terracotta escalation failure state with retry button, and telemetry inspection modal | **5/5 PASSING** |
| `client/test/lorecraft_studio_test.dart` | 3 factions, 3 NPCs, 3 regions, habitat shifts, reputation updates, memory bundle budget, rubric standards, and dialogue frame inspector | **12/12 PASSING** |
| `client/test/quest_progression_test.dart` | Multi-stage dynamic quest tracks across all 3 NPCs, `hideTextIfGenerativeUi` flag toggling, and objective stage advancement | **6/6 PASSING** |
| `client/test/switching_router_test.dart` | PII regex detection & scrubbing, context limit escalation, multi-hop reasoning, circuit breaker fallback, mode overrides | **7/7 PASSING** |
| `client/test/a2ui_rendering_test.dart` | Proactive choice tags, visual canvas with Nano Banana 2 Lite telemetry, two-step visual-to-local pipeline, embedded markdown JSON choices extraction, raw JSON code fence stripping, full declarative A2UI JSON parsing, and `hideTextIfGenerativeUi` focus mode | **9/9 PASSING** |
| `client/test/lorecraft_simple_mode_clarity_test.dart` | Simple vs. Everything mode visual partitioning, dev tool knob filtering, and Edge Model Toggle (`btn_toggle_edge_model`) switching between Gemma 4 int4 and Gemini Nano | **3/3 PASSING** |
| `client/test/model_test_bench_test.dart` | Single prompt input, preset chips, 4-rubric composite scoring, GemmaLoadPill integration, on-device weight readiness banner, and zero false affordance recovery controls (`Load Gemma 4 Weights`, `Retry Connection`) | **4/4 PASSING** |
| `client/test/live_cloud_switching_test.dart` | Live Cloud Run probe `/api/chat` Gemini 3.8 Flash escalation, memory bundle budget, live eval benchmark LLM judge, and Nano Banana 2 Lite visual generation | **7/7 PASSING** |
| `client/test/eval_rater_test.dart` | Model comparison matrix, automated eval rater scoring, and rubric standards | **4/4 PASSING** |
| `server/tests/` | Cloud Run backend, Gemini 3.8 Flash escalation routes, `/api/weights/` weight streaming, SSE transport, exponential backoff retries | **8/8 PASSING** |

---

## 8. Related Documentation
- [System Architecture](architecture.md): High-level edge-to-cloud topology.
- [Routing Guide](routing_guide.md): Dynamic switching policies, Foresight Pill, and Router Dial controls.
- [Memory Pipeline Specification](memory_pipeline.md): Envoy 4-phase memory boot flow and SQLite local storage.
- [Model Matrix & Hardware Boundaries](model_matrix.md): Execution performance and two-step orchestration protocol.
- [UI/UX Style & Affordances](ui_style_guide.md): Sepia design system standards and A2UI surface rendering.

