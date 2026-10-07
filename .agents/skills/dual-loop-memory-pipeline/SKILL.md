---
name: dual-loop-memory-pipeline
description: Design, implement, and audit dual-loop memory architectures combining real-time local edge working context (SQLite/IndexedDB) with asynchronous cloud consolidation (Firestore, Gemini 3.8 Flash). Enforces strict 50 KB edge bundle budgeting, contradiction resolution, and topic uncaching.
---

# Dual-Loop Durable Memory Pipeline Specification

This skill governs the design, data schemas, synchronization lifecycles, and automated testing of edge-to-cloud dual-loop memory architectures.

---

## 1. Architectural Philosophy

Memory in distributed AI systems cannot rely solely on either massive cloud contexts (due to latency, cost, and offline vulnerability) or purely local storage (due to memory constraints and lack of cross-session synthesis).

The **Dual-Loop Memory Architecture** solves this by separating real-time execution from asynchronous knowledge consolidation:

```
┌────────────────────────────────────────────────────────────────────────┐
│                        ONLINE REAL-TIME LOOP                           │
│                                                                        │
│   User Prompt ──► Local PII Scrubber ──► Local Working Memory (RAM)    │
│                                                   │                    │
│                                                   ▼                    │
│                                         Local SQLite / Room            │
│                                        (Pruned via LRU to 5)           │
│                                                   │                    │
│                                                   ▼                    │
│                                        Client Ingestion Queue          │
└───────────────────────────────────────────────────┬────────────────────┘
                                                    │ Sanitized Sync
                                                    ▼
┌────────────────────────────────────────────────────────────────────────┐
│                      OFFLINE CONSOLIDATION LOOP                        │
│                                                                        │
│      Cloud Ingestion Store ──► Cloud Run Memory Consolidator           │
│       (/episodes, UNCONSOLIDATED)                 │                    │
│                                                   ▼                    │
│                                         Vertex AI Gemini 3.8 Flash     │
│                                        (Contradiction Resolution &     │
│                                         Entity Graph Synthesis)        │
│                                                   │                    │
│                                                   ▼                    │
│                                         Cloud Firestore Native         │
│                                         (/durable_nodes)               │
│                                                   │                    │
│                                                   ▼                    │
│                                         Edge Memory Bundle Packer      │
│                                         (Strict Limit: < 50,000 bytes) │
└───────────────────────────────────────────────────┬────────────────────┘
                                                    │ Distribute Bundle
                                                    ▼
┌────────────────────────────────────────────────────────────────────────┐
│                        EDGE BOOT SYNCHRONIZATION                       │
│                                                                        │
│   Client retrieves versioned bundle ──► Injects anchors into SQLite    │
│   Zero-latency offline grounding (<5ms) with zero cloud dependencies   │
└────────────────────────────────────────────────────────────────────────┘
```

---

## 2. Ingestion & Storage Contracts

### 1. Episodic Turn (`/episodes/{episodeId}`)
Represents a single conversational or tactical interaction:
- `episodeId`: Unique turn identifier.
- `sessionId`: Session boundary identifier.
- `timestamp`: ISO-8601 UTC timestamp.
- `userPrompt`: Local PII-scrubbed user input.
- `modelResponse`: Output from edge or cloud model.
- `route`: `EDGE_LOCAL`, `CLOUD_ESCALATE`, or `EDGE_FALLBACK`.
- `entities`: Array of extracted concepts (e.g. `["SQLite WASM", "Friday"]`).
- `status`: `UNCONSOLIDATED` | `CONSOLIDATED`.

### 2. Durable Knowledge Node (`/durable_nodes/{nodeId}`)
Represents distilled, authoritative knowledge stored in Cloud Firestore:
- `nodeId`: Unique slug or UUID.
- `entityName`: Normalized concept name.
- `category`: `USER_PREFERENCE`, `SYSTEM_ARCHITECTURE`, `ROADMAP_DECISION`, `SECURITY_POLICY`.
- `summary`: Factual distillation of consolidated knowledge.
- `confidence`: Double between 0.0 and 1.0.
- `relations`: Directed graph edge IDs linking to dependent entities.
- `resolvedContradictions`: Audit trail of superseded facts and resolution rationale.

### 3. Compact Edge Bundle Invariant (`< 50 KB / 51,200 bytes`)
- The packed bundle payload **MUST NOT exceed 50,000 bytes** (51,200 bytes maximum buffer).
- If the knowledge graph generates more anchors than can fit within the budget, the packing algorithm must:
  1. Rank anchors by frequency and recency.
  2. Synthesize/compress lower-priority anchors into higher-level summary nodes.
  3. Evict stale nodes according to LRU and domain importance.

---

## 3. Envoy 4-Tier Memory Boot Protocol

To prevent client application startup lag and avoid memory exhaustion on mobile or embedded devices, memory is loaded across four deterministic stages:

1. **Phase 1: Static Boot State ($< 4$ KB)**:
   - Loads core system identity, baseline configuration, and active session flags.
   - Immediate startup execution without blocking network requests.

2. **Phase 2: JIT Working Context**:
   - Loads the active dialogue/scenario working memory (max 5 turns) into fast RAM.
   - Enforces LRU pruning on older turns to maintain bounded heap allocation.

3. **Phase 3: Pre-Emptive Edge Cache**:
   - Caches the current versioned 50 KB edge bundle into SQLite/IndexedDB.
   - Injects domain anchors directly into the local model prompt context window.

4. **Phase 4: Asynchronous Reconciliation**:
   - Background worker drains the client ingestion queue to Cloud Run.
   - Performs topic uncaching and cache-invalidation for stale local nodes.

---

## 4. Contradiction Resolution Protocol

When a user or agent submits contradictory directives across sessions (e.g., Turn 1: *"Target memory limit is 2 GB"*; Turn 5: *"Downgrade memory limit to 1 GB"*):
1. **Detection**: Gemini 3.8 Flash consolidation prompts compare new episodic turns against existing durable nodes in `/durable_nodes`.
2. **Adjudication**:
   - The newer authoritative instruction supersedes the older instruction.
   - The older directive is recorded under `resolvedContradictions` with timestamp and actor attribution.
3. **Auditability**:
   - The UI provides a one-click rollback affordance in the Memory Lifecycle Studio allowing operators to revert to the previous directive if necessary.

---

## 5. Automated TDD Verification Checklist

Any implementation of the dual-loop memory pipeline must pass these automated assertions:
- [ ] Ingestion test: Asserts `POST /api/memory/ingest` creates an `UNCONSOLIDATED` episode with scrubbed PII.
- [ ] Consolidation test: Verifies that running batch consolidation resolves contradictory directives and marks episodes as `CONSOLIDATED`.
- [ ] Edge bundle budget test: Injects 200+ heavy anchors and asserts the emitted bundle size is strictly $< 51,200$ bytes without truncation errors.
- [ ] Offline partition test: Asserts local SQLite stores turns with `PENDING_SYNC` status when network connectivity is severed.
- [ ] Edge-cloud diff tree test: Asserts the UI diff inspector accurately displays pending ingestion items, topic cache deltas, and synchronization health.
