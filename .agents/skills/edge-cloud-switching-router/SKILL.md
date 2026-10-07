---
name: edge-cloud-switching-router
description: Design, implement, and audit dynamic switching routers between on-device edge models (Gemma 4 int4, Gemini Nano) and cloud reasoning (Gemini 3.8 Flash, Nano Banana 2 Lite). Enforces strict PII redaction, token budgeting, circuit breaker failover, and pre-flight foresight affordances.
---

# Edge-to-Cloud Dynamic Switching Router Specification

This skill governs the architecture, policy evaluation, and testing of intelligent switching routers that dynamically dispatch prompts between local edge execution and cloud AI services.

---

## 1. Core Invariants

1. **Zero-Cloud Egress for PII (`RULE_STRICT_PRIVACY`)**:
   - Any prompt containing Personally Identifiable Information (emails, phone numbers, Social Security Numbers, credit cards, auth tokens, or API keys) **MUST** be routed to local on-device models (`EDGE_LOCAL`).
   - If local models are unavailable or uninitialized, PII **MUST** be scrubbed client-side before any cloud transmission.

2. **Strict Never Mock Directive**:
   - Never mock network latency, dummy tokens, or synthetic router decisions.
   - If edge weights are missing, the router must either surface an explicit error or execute a truthful fallback route (`EDGE_FALLBACK`) with inspectable telemetry (`isDynamicallyEscalated: true`).

3. **Pre-Flight Foresight Affordance**:
   - User-facing text inputs must provide real-time foresight (e.g. `LoreCraftForesightPill`) previewing the target route, model, estimated latency, and triggered policy rule before the user submits the turn.

---

## 2. Policy Rule Hierarchy

Policies are evaluated in descending priority order. The first matching rule dictates the execution route:

| Priority | Rule Name | Condition | Target Route | Target Model Engine | Egress Bytes |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **100** | `RULE_STRICT_PRIVACY` | Regex matches PII (email, phone, SSN, API key) | `EDGE_LOCAL` | Gemma 4 int4 / Gemini Nano | **0.0 KB** |
| **90** | `RULE_GAME_VISUAL_SYNTHESIS` | Intent requires image generation, blueprints, maps | `CLOUD_ESCALATE` | Nano Banana 2 Lite (`gemini-3.1-flash-lite-image`) | Structured Request |
| **85** | `RULE_GAME_REACTIVE_BARK` | Short NPC dialogue, stage cues, barter, inventory | `EDGE_LOCAL` | Gemma 4 int4 / Gemini Nano | **0.0 KB** |
| **80** | `RULE_CONTEXT_LIMIT_EXCEEDED` | Estimated prompt tokens $> 4,096$ | `CLOUD_ESCALATE` | Gemini 3.8 Flash (Vertex AI) | Sanitized Request |
| **75** | `RULE_GAME_CAMPAIGN_SYNTHESIS` | Cross-faction consequence, treaty negotiation, climax | `CLOUD_ESCALATE` | Gemini 3.8 Flash (Vertex AI) | Sanitized Request |
| **70** | `RULE_COMPLEXITY_ESCALATION` | Multi-hop reasoning, code architecture synthesis | `CLOUD_ESCALATE` | Gemini 3.8 Flash (Vertex AI) | Sanitized Request |
| **10** | `RULE_EDGE_DEFAULT_FAST` | Standard single-turn prompt within edge token limits | `EDGE_LOCAL` | Gemma 4 int4 / Gemini Nano | **0.0 KB** |

---

## 3. Circuit Breaker Specification

To guarantee resilience against network outages or backend service degradation, the switching router implements a client-side circuit breaker:

```
        [ Normal Requests Pass ]
                 │
                 ▼
        ┌──────────────────┐
        │  CLOSED STATE    │ ◄─────────────────────────┐
        └────────┬─────────┘                           │
                 │ 3 Consecutive Failures / Timeouts   │
                 ▼                                     │ Success Probe
        ┌──────────────────┐                           │
        │   OPEN STATE     │                           │
        │ (Force Fallback) │                           │
        └────────┬─────────┘                           │
                 │ Cooldown Period Expired (30s)       │
                 ▼                                     │
        ┌──────────────────┐                           │
        │ HALF-OPEN STATE  │ ──────────────────────────┘
        │  (Canary Probe)  │
        └──────────────────┘
```

### Circuit Breaker Behavior:
- **CLOSED**: Requests evaluate normal policy rules.
- **OPEN**: All requests normally destined for `CLOUD_ESCALATE` are immediately downgraded to `EDGE_FALLBACK` (local Gemma 4 / Gemini Nano tactical response) with an offline episodic sync queue (`PENDING_SYNC`). Egress is 0.0 KB.
- **HALF-OPEN**: Dispatches a single lightweight health probe. If successful, state flips to `CLOSED`; if it fails, the breaker resets to `OPEN` for another cooldown cycle.

---

## 4. Pre-Flight Foresight Pill Protocol

Every input console utilizing the switching router must integrate an interactive pre-flight pill:
1. **Debounce (50–100ms)**: Evaluates input text as the user types without locking the UI thread.
2. **Visual States**:
   - `Sage Olive`: Local privacy guard or sub-60ms edge reactive bark (`0 KB Egress`).
   - `Warm Amber`: Cloud multi-hop synthesis or campaign consequence simulation.
   - `Azure Indigo`: Cloud multimodal visual synthesis (~1.2s).
   - `Terracotta`: Circuit breaker open or offline fallback mode.
3. **Inspectable Dossier**: Tapping the pill opens a bottom modal sheet detailing:
   - Target Route (`EDGE_LOCAL`, `CLOUD_ESCALATE`, `EDGE_FALLBACK`)
   - Triggered Rule Identifier (e.g. `RULE_STRICT_PRIVACY`)
   - Assigned Model Identifier (e.g. `gemini-3.8-flash` or `Gemma 4 int4`)
   - Destination Memory Queue (Local SQLite vs Cloud Ingestion)
   - Plain-English Rationale answering: What is it? Why was it routed? What changed?

---

## 5. Automated TDD Verification Checklist

Any implementation or modification of the switching router must pass the following test assertions:
- [ ] PII detection test: Asserts `RULE_STRICT_PRIVACY` triggers on emails and phone numbers, routing to `EDGE_LOCAL` with `egressBytes == 0`.
- [ ] Token overflow test: Asserts input $> 4096$ tokens triggers `RULE_CONTEXT_LIMIT_EXCEEDED` and routes to `CLOUD_ESCALATE`.
- [ ] Visual intent test: Asserts visual generation keywords trigger `RULE_GAME_VISUAL_SYNTHESIS` to Nano Banana 2 Lite.
- [ ] Circuit breaker test: Simulates 3 consecutive network timeouts, asserts circuit breaker flips to `OPEN`, and confirms fallback to on-device models.
- [ ] Manual override test: Asserts `RouterModeOverride.enforceEdgeLocal` and `RouterModeOverride.enforceCloudFlash` strictly bypass heuristics.
