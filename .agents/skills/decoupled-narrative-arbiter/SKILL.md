---
name: decoupled-narrative-arbiter
description: Design, implement, and audit decoupled multi-model architectures for dynamic narratives, interactive gaming, and agentic task orchestration. Separates responsive edge persona dialogue from cloud game master consequence adjudication and A2UI proactive choice synthesis.
---

# Decoupled Narrative & Arbiter Multi-Model Architecture

This skill governs the division of labor between fast, on-device persona models and authoritative cloud game master arbiter models in interactive worlds and agentic simulations.

---

## 1. Architectural Philosophy

Single-model architectures in conversational gaming or interactive assistants face a fundamental dilemma:
- If a cloud model is called for every turn, player interactions suffer high latency (1–3s), high egress cost, and total dependency on constant network connectivity.
- If only a small edge model is used, the game lacks deep multi-hop narrative memory, cannot calculate complex systemic consequences across multiple factions, and suffers context drift.

The **Decoupled Architecture** solves this by assigning distinct cognitive roles to specialized models:

```
                  [ Player Action / Choice Selection ]
                                   │
                                   ▼
             ┌───────────────────────────────────────────┐
             │       Decoupled Multi-Model Engine        │
             └─────────────────────┬─────────────────────┘
                                   │
                 ┌─────────────────┴─────────────────┐
                 ▼                                   ▼
      [Model 1: Persona Model]            [Model 2: Game Master Arbiter]
      Role: Talking to User               Role: Consequence Adjudication
      Location: Edge (Gemma 4 int4)       Location: Cloud Run (Gemini 3.8 Flash)
      TTFT: < 60ms (Sub-frame)            Execution: Multi-hop reasoning
      Output:                             Output:
      • In-character spoken voice         • Quest objective completion check
      • Physical stage cues / emoting     • Faction reputation shift (+/- pts)
      • Direct reaction to player         • Strategic narrative commentary
                                          • 3 Proactive A2UI Next-Turn Choices
                 │                                   │
                 └─────────────────┬─────────────────┘
                                   ▼
                  [Unified Dialogue Card & Action Surface]
                  • Persona speech & stage cues rendered immediately
                  • Game Master commentary pill with dual model badges
                  • 3 Proactive contextual action cards (A2UI ChoiceGroup)
```

---

## 2. Pre-Dialogue Strategic Mission Briefing

Interactive games and agentic workflows must **never drop the user into dialogue without high-level grounding**. Before opening persona dialogue:

1. **Strategic Directive Display**:
   - Overarching crisis title (e.g. `OPERATION AETHER BREACH`).
   - Threat level assessment (`CRITICAL • LEVEL 4 ARCANE SURGE`).
   - Strategic context and regional crisis summary.
2. **Explicit Primary Objectives**:
   - List of clear, trackable goals (e.g. `Seal Lower Foundry Gates`, `Safeguard Municipal Aqueducts`).
3. **Faction Stakes Matrix**:
   - Table detailing each faction's stance, critical vulnerability, and strategic opportunity.
4. **Sector Contact Selection**:
   - Player explicitly selects their initial diplomatic liaison (e.g. Gideon Ironhand vs Lyra Vance vs Archivist Elion), establishing an intentional entry point into the crisis.
5. **Persistent Mission Dossier**:
   - The mission briefing remains accessible at all times during active dialogue via a persistent header affordance (`MISSION DOSSIER`).

---

## 3. Dynamic A2UI Proactive Choice Synthesis

Following every player action and dialogue turn:
1. The Game Master Arbiter evaluates the conversation history, current quest stage (Stages 0–4), and active objectives.
2. Synthesizes **three distinct tactical choices** formatted as an `A2UISurface` choice card:
   - **Tactical / Direct Assault Option**: High risk, immediate martial gain.
   - **Diplomatic / Subterfuge Option**: Leverages covert alliances, faction reputation, or bribes.
   - **Arcane / Technical Option**: Uses environmental engineering, harmonic dampening, or knowledge anchors.
3. **Execution Tagging**:
   - Choices that can be resolved on-device are tagged with green `EDGE` badges (<60ms).
   - Choices requiring heavy visual art, blueprints, or deep campaign synthesis are tagged with azure `CLOUD` badges.

---

## 4. Two-Step Hybrid Orchestration (Cloud Visual -> Local Follow-Up)

When a player selects an action requiring visual synthesis (e.g. forging an artifact, examining a cryptographic seal):

```
[ Player Action: Forge Runic Blade ]
                │
                ▼
  STEP 1: Cloud Multimodal Escalation
  • Cloud Run calls Vertex AI Nano Banana 2 Lite (gemini-3.1-flash-lite-image)
  • Synthesizes Base64 JPEG blueprint (~1.2s latency)
  • Materializes visual asset inside A2UISurface ImageCanvas
                │
                ▼
  STEP 2: Local Edge NPC Reaction Turn
  • Execution immediately transitions to on-device Gemma 4 int4 / Gemini Nano
  • Active NPC delivers immediate stage cue and dialogue:
    "Gideon grips the pommel, testing the runic temper with a sharp nod..."
  • Synthesizes next-turn dilemma choices locally without extra cloud delays
  • Egress: 0.0 KB | TTFT: < 60ms
```

---

## 5. Automated TDD Verification Checklist

Any implementation of the decoupled narrative engine must pass these automated assertions:
- [ ] Initial state test: Verifies 3 factions, 3 NPCs, and 3 regions with grounded lore are initialized at startup.
- [ ] World state bundle test: Asserts the packed world state bundle is strictly $< 51,200$ bytes.
- [ ] Router dispatch test: Verifies reactive NPC dialogue barks route to `EDGE_LOCAL` (<60ms TTFT, 0 KB egress), while cross-faction campaign synthesis routes to `CLOUD_ESCALATE`.
- [ ] Mission briefing test: Asserts the mission briefing card renders crisis directive, threat level, objectives, and faction matrix prior to dialogue.
- [ ] Dynamic choice synthesis test: Asserts that every NPC dialogue turn is accompanied by 3 contextual choices with proper edge/cloud route tagging.
- [ ] Two-step visual pipeline test: Asserts image synthesis generates the visual canvas followed by immediate local edge stage cues.
