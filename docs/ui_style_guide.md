# Antigravity UI/UX Design System & Affordance Standard

## 1. Overview & Core Philosophy
The Antigravity UI follows an **academic-light / sepia palette** designed for distraction-free reading, cognitive transparency, and high information density without visual clutter.

> **"If it looks like a button, chip, or card, it must do something; if it does nothing, style it like quiet text."**

---

## 2. Palette & Design Tokens (`SepiaTheme`)

### Core Parchment Surfaces
- **Canvas**: `#FAF7F2` (warm parchment background)
- **Paper**: `#FFFFFF` (elevated workspace sheets and primary panels)
- **Paper Subtle**: `#F7F4EE` (tinted card surfaces and code callouts)
- **Ink**: `#1C1917` (warm black typography)
- **Ink Secondary**: `#44403C` (secondary body copy)
- **Ink Muted**: `#78716C` (metadata labels and quiet captions)
- **Border**: `#E6DFD5` (subtle panel dividing lines)

### Semantic Domain Accents
- **Sage Olive (`#3F6212` / bg: `#ECFCCB` / border: `#D9F99D`)**: Edge execution, local privacy, zero-cloud egress, PII scrubbing.
- **Warm Amber (`#B45309` / bg: `#FEF3C7` / border: `#FDE68A`)**: Cloud execution, Gemini 3.8 Flash, durable consolidation, knowledge graph synthesis.
- **Terracotta (`#C2410C` / bg: `#FFEDD5` / border: `#FED7AA`)**: Circuit breakers, offline fallbacks, budget warnings, contradiction alerts.
- **Slate Stone (`#57534E` / bg: `#F4EFE6` / border: `#E7E5E4`)**: Local single-turn responses, neutral runtime logs.

---

## 3. Quiet Typography vs. Actionable Affordances

### The "Confetti Pill" Anti-Pattern
Surrounding every piece of static metadata in a capsule container creates visual noise and deceives users with false interactive affordances.

```
❌ BAD (Confetti Pills):
[Clean]  [SYSTEM_ARCHITECTURE]  [Confidence: 99%]  [SQLite WASM]

✅ GOOD (Quiet Typography):
● Clean    SYSTEM ARCHITECTURE    Confidence: 99%    SQLite WASM · Friday
```

### Formatting Rules
1. **Status Indicators**:
   - Use `SepiaTheme.statusDot(color, label)`. Renders a small circular dot followed by plain readable text (e.g., `● Clean` or `● PII Scrubbed`).
2. **Category Labels**:
   - Use `SepiaTheme.quietLabel(text, color: ...)`. Renders uppercase monospace typography (`fontSize: 10, fontWeight: 700`) with zero background fill and zero border.
3. **Metrics & Scores**:
   - Use `SepiaTheme.metricText(label, value)`. Renders as inline text: `Confidence: 99%`.
4. **Actionable Intent Pills**:
   - Permitted ONLY when an element is explicitly clickable (e.g., `IntentPillWidget` in the chat drawer or `Inspect ➔` audit rows) that opens an inspector drawer, bottom sheet, or modal.

---

## 4. Responsive Layouts: Desktop vs. On-Device Mobile

### Desktop Mode ($\ge 1100$px)
- Strict 2-3 panel layout:
  - Left Nav Rail (collapsible between expanded 240px with full labels/status footer and compact 68px icon rail with tooltips, badge dots, and compact status indicators).
  - Studio Sub-Panels (e.g., LoreCraft Studio left navigation panel, collapsible via dedicated chevron and center header toggle button, with individual collapsible accordion sections for Region, NPCs, Factions, Router, and Edge Budget).
  - Center Main Workspace (Stream, Notebook, or Studio).
  - Right Expandable Drawer (Contextual docs, inspectable telemetry, audit logs).
- Memory Studio: Horizontal Request/Response flow diagram, continuous notebook stream, interactive Tree View supporting Segmented Switcher (`[ 📱 Local Edge Tree ]`, `[ ☁️ Cloud Graph Tree ]`, `[ ⚡ Edge-Cloud Diff ]`, and `[ 🔀 Split View ]`) with docked simulator.

### Mobile / On-Device Mode ($< 700$px)
- Nav transforms into a drawer or bottom navigation bar.
- Request/Response diagram transforms into a **Vertical Stepper Indicator**.
- Memory Tree transforms into a **Segmented Control** (`[ 📱 Local Edge Tree ]`, `[ ☁️ Cloud Graph Tree ]`, `[ ⚡ Edge-Cloud Diff ]`) with thumb-friendly collapsible tree nodes.
- Edge-Cloud Diff tree displays a live 4-branch hierarchical delta (Pending Ingestion Queue, Durable Knowledge vs. Edge Anchors, Topic Cache Delta, and Synchronization Health) with zero mock summaries.
- Contradiction audits open in an accessible **Modal Bottom Sheet** directly from tree diff node affordances.
- The Pattern Testing Sandbox pins cleanly as a **Docked Bottom Action Bar**.

### Assistant Workspace Header & Action Pill Responsiveness
The center workspace header toolbar dynamically adapts to the center column's available width using `LayoutBuilder` (accounting for the 240px Left Nav Rail and 320px Right Inspector Drawer):
- **Wide Workspace ($\ge 900$px)**:
  - Full title text: `ASSISTANT SHELL // DUAL EDGE-CLOUD WORKSPACE` with `DEV TOOL` badge.
  - Interactive Latency Probe Chip: `Edge Probe: {latency}ms`.
  - Execution Routing Pill: Full label (e.g. `Auto (Gemini Nano)` or `Local: Gemini Nano`).
  - Gemma 4 Load Pill: Full plain-English capacity label (`Load Gemma 4 2B (~1.46 GB)` / `Gemma 4 2B Ready (0 KB Egress)`).
- **Compact Workspace ($600\text{px} \le \text{width} < 900\text{px}$, e.g. Drawer Open)**:
  - Adaptive title text: `ASSISTANT SHELL`.
  - Interactive Latency Probe Chip: Concise latency `12ms`.
  - Execution Routing Pill: Streamlined mode label (e.g. `Auto`, `Local`, `Cloud`, `Offline`).
  - Gemma 4 Load Pill: Concise action label (`Load Gemma 4` / `Gemma 4 Ready`).
- **Ultra-Compact Workspace ($< 600$px)**:
  - Minimalist title text: `ASSISTANT`.
  - Latency probe chip gracefully defers to the Inspector panel to prioritize routing and load action controls.
- **Layout Contention & Overlap Prevention**:
  - The left title block is bounded to at most 45% of available width with `TextOverflow.ellipsis`.
  - Action pills reside in an `Expanded` right-aligned container with a non-reversed horizontal scroll viewer fallback, ensuring pills are never squished, overlapped, or clipped from the left.

---

## 5. Rich Markdown Typography & Input Editing Standard

### Message Response Formatting (`SepiaMarkdownWidget`)
Model responses and execution outputs are formatted via `SepiaMarkdownWidget` rather than raw text:
- **Headings (H1–H4)**: Scaled with `SepiaTheme.sans` proportional weights (H1: 19px, H2: 17px, H3: 15px, H4: 13.5px).
- **Inline Styling**: Full support for bold (`**text**`), italic (`*text*`), bold-italic (`***text***`), strikethrough (`~~text~~`), inline code chips (monospaced with `paperSubtle` background and `borderSubtle`), and hyperlinks.
- **Fenced Code Blocks**: Displays an uppercase language chip (`GO`, `DART`, `JSON`, `BASH`), syntax-friendly monospace typography with horizontal scroll, and a copy-to-clipboard button with visual confirmation (`"Copied!"`).
- **Ordered & Unordered Lists**: Supports nested indentations, custom bullet dots (`SepiaTheme.inkSecondary`), and aligned numeric prefixes (e.g., `1. **Complexity:**`).
- **Blockquotes & Dividers**: Blockquotes render with a 3px amber accent bar and italicized text; horizontal rules (`---`) render as clean theme dividers.
- **Tables**: Renders markdown grid tables with styled header bars and cell padding.

### Message Sending & Prompt Editor (`MarkdownPromptEditor`)
The message prompt area features full markdown authoring capabilities:
- **Write / Preview Tabs**: Users can toggle between the drafting `TextField` and an interactive live preview rendered by `SepiaMarkdownWidget`.
- **Formatting Toolbar**: Dedicated buttons with tooltips for **Bold**, **Italic**, **Heading**, **Inline Code**, **Code Block**, **Bullet List**, **Numbered List**, **Blockquote**, **Link**, and **Horizontal Rule**.
- **Selection Wrapping**: Buttons wrap highlighted text in syntax delimiters or insert templates at the cursor position.
- **Keyboard Shortcuts**: Native support for `Cmd+B` / `Ctrl+B` (Bold), `Cmd+I` / `Ctrl+I` (Italic), and `Cmd+K` / `Ctrl+K` (Inline Code).
- **Zero Dead UI**: Every button has an explicit hover state, tooltip, and interactive affordance.

---

## 6. Generative UI (A2UI) & Dynamic Choice Architecture

### The Zero-Raw-JSON Rule
Generative AI responses intended to present interactive affordances (choices, actions, sliders, visual canvases) must **never** leak raw JSON syntax or markdown code blocks into readable dialogue or chat cards:
```
❌ BAD (Unparsed Raw JSON in Bubble):
*[lowers voice]*
```json
[
  { "id": "choice_edge_dialogue", "label": "Inquire about dampeners", ... }
]
```

✅ GOOD (Extracted Interactive A2UI Surface):
*[lowers voice]* (quiet italic cue above card)
┌─────────────────────────────────────────────────────────────┐
│ ⚡ PROACTIVE NARRATIVE BRANCHES                             │
│ ┌─────────────────────────────────────────────────────────┐ │
│ │ ⚡ Inquire about the dampeners' purpose           [EDGE] │ │
│ │   Extract tactical intent without drawing attention.     │ │
│ └─────────────────────────────────────────────────────────┘ │
│ ┌─────────────────────────────────────────────────────────┐ │
│ │ ☁️ Synthesize Undercity Sluice Blueprint         [CLOUD] │ │
│ │   Trigger Nano Banana 2 Lite visual synthesis.          │ │
│ └─────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

### Dynamic Extraction Pipeline (`A2UIExtractor`)
1. **Pre-flight Regex Parsing**: Scans for stage cues `*[cue]*`, markdown fences ````json [...] ````, or raw JSON arrays `[...]`.
2. **Sanitization**: Strips raw JSON blocks from `speechText` before rendering to `SelectableText`.
3. **Surface Promotion**: If the model output contains choices or declarative components, immediately instantiates an `A2UISurface` so choices render via `A2UISurfaceView`.
4. **Deduplication**: When `hideTextIfGenerativeUi` is active, duplicate outer speech text and stage cues are suppressed so the user's attention is focused on the A2UI surface without visual repetition.
5. **Session Isolation**: In on-device runtimes (Chrome Prompt API / Gemini Nano), separate task contexts (`gamemaster` vs `persona`) ensure prior JSON schemas do not contaminate conversational dialogue tokens across model turns.

---

## 8. Unified Contextual & LoreCraft Studio Inspector (`RightDrawerPanel`)

The desktop right drawer provides a context-aware inspection surface that adapts between game narrative lore and AI runtime engine internals without visual duplication:

```
┌────────────────────────────────────────────────────────┐
│ 🏰 LORECRAFT STUDIO INSPECTOR                      [×] │
├──────────────────────────┬─────────────────────────────┤
│ [ 🏰 Game World ] (Active)│ [ ⚙️ AI Engine ]            │
├──────────────────────────┴─────────────────────────────┤
│ ▌ ACTIVE NPC & STRATEGIC CONTEXT                       │
│   Gideon Stonehand • Ironforge Foundry     STAGE 1 / 5 │
│   Voice: Gravelly, deliberate • Mood: Suspicious       │
│                                                        │
│ ▌ ACTIVE WORLD STATE ANCHORS (< 50 KB)                 │
│   #vanguard_iron_rations               [FACTION_STATE] │
│   #syndicate_dock_manifests            [FACTION_STATE] │
│   #enclave_aqueduct_subsidence         [WORLD_EVENT]   │
│   #Aether-Core Resonance               [WORLD_CANON]   │
│                                                        │
│ ▌ GAMEPLAY PERFORMANCE & MEMORY BUDGET                 │
│   EDGE LORE BUNDLE METER           31.4 KB / 50.0 KB   │
│   [████████████████████░░░░░░░░░░]                     │
│   Dialogue TTFT: 58 ms  • Cloud Egress: 0.0 KB         │
│   Active Engine: Gemma 4 int4                          │
│                                                        │
│ ▌ CANON & VOICE ARBITER SCORECARD                      │
│   Alignment: 94% • Tone Consistency: 96%               │
│   Cloud Run Link: CLOSED (Healthy)                     │
└────────────────────────────────────────────────────────┘
```

### Key Inspector Features & Affordances:
1. **Destination-Aware Auto-Switching**:
   - In **LoreCraft Studio** (`ShellNavDestination.loreCraftStudio`), the inspector automatically initializes in **Game World** mode (`InspectorMode.gameWorld`).
   - In **Assistant Workspace** (`ShellNavDestination.assistant`), it initializes in **AI Engine** mode (`InspectorMode.aiEngine`).
2. **Interactive Segmented Mode Switcher**:
   - Allows users to switch views on demand with a single tap (`[ 🏰 Game World ]` vs `[ ⚙️ AI Engine ]`).
3. **World Lore vs Engine Guardrail Separation**:
   - Game World mode surfaces narrative anchors (`WORLD_CANON`, `FACTION_STATE`, `TACTICAL_SECURITY`, `WORLD_EVENT`) and suppresses low-level engine invariants (`Quantization Policy`, `Edge Bundle Budget`).
   - AI Engine mode surfaces runtime system guardrails, PII scrub deltas, and token throughput telemetry.
4. **Edge Working Memory Meter**:
   - Real-time gauge tracking the compact edge bundle against the strict `< 50.0 KB` mobile NPU limit.
5. **Canon Arbiter & Circuit Breaker Link**:
   - Integrates the live canon rater scorecard with a quiet circuit breaker health indicator and a one-click manual reset affordance.
6. **Zero Duplicate Drawers**:
   - Studio's internal right panel is coordinated with `ShellLayout`'s unified 320px drawer, ensuring a single consistent inspection panel across the entire application.

---

## 10. Navigation Architecture & Developer Tool Partitioning

To maintain a clean distinction between the user-facing game experience and underlying edge-cloud infrastructure, the global left navigation rail is explicitly partitioned into two distinct categories:

### A. Navigation Categories
1. **GAME WORLD (LORECRAFT)**:
   - **LoreCraft Studio**: Full interactive RPG experience featuring reactive NPC dialogue, 5-stage quest tracks, living faction simulation, and generative A2UI moment cards.
   - **Edge Agent Boot**: Edge device initialization console demonstrating the 4 cold-start memory patterns (Directives, JIT Fetch, Task-Bound Context, and 3 AM Cloud Dream Delta Sync).
2. **DEVELOPER TOOLS (SYSTEM DIAGNOSTICS)**:
   - **Memory Studio**: Deep inspection notebook for episodic turns, PII scrubbing logs, on-device SQLite WASM cache, and cloud knowledge graph harmonization.
   - **Model Test Bench**: Multi-model simultaneous comparison bench running identical prompts across 4 edge-cloud tiers with standardized 4-rubric scoring.
   - **Switching Policy**: Declarative routing rule matrix evaluating latency, token budget, context complexity, and 0 KB PII egress guarantees.
   - **Feature Synthesizer**: Edge-to-cloud UI compiler synthesizing interactive sandboxes from durable knowledge anchors (<50 KB budget).
   - **Assistant Workspace**: Dual edge-cloud AI chat shell with dynamic Intent Pills and real-time execution telemetry.

### B. Navigation Bridges & Page Intent Badges
- **Contextual Bridges**: LoreCraft Studio includes direct action buttons (`DEV MEMORY ➔` in the top bar, `INSPECT IN MEMORY STUDIO ➔` in the Living Lore drawer) so developers can seamlessly jump to inspect live turn ingestion.
- **Diagnostic Badges**: All dev tools display a quiet uppercase indicator (`DEVELOPER TOOL // SYSTEM DIAGNOSTIC`) with contextual subtitle explanations to clarify their role as engineering instruments.
- **Succinct Explainer Cards**:
  - **Memory Studio**: Collapsible 4-step mechanisms guide explaining Turn Capture, On-Device Regex Scrubbing, Zero-Latency Context Injection, and Cloud Harmonization. Includes origin filter (`ALL SOURCES`, `⚔ LORECRAFT GAME WORLD`, `💬 ASSISTANT SHELL`).
  - **Model Test Bench**: Standardized rubric explainer highlighting the composite formula: `Score = 0.35*Semantic + 0.25*Compliance + 0.25*Safety + 0.15*Efficiency`.
  - **Switching Policy**: Route lock explainer detailing 100% on-device masking with guaranteed 0 KB egress for privacy compliance.
  - **Feature Synthesizer**: Sandbox compiler explainer detailing how durable knowledge nodes dynamically generate live UI components.

---

## 11. Simple Mode vs. Everything Mode (Showcase Slider)

To present a razor-sharp product demonstration while maintaining deep developer observability, the application includes a tactile mode toggle slider (`[ ⚡ Simple | 🔬 Everything ]`) at the top of the global navigation rail.

### A. The 3 Technical Pillars
In **Simple Mode**, all UI language, telemetry, and cards strictly spotlight the 3 core architectural pillars:
1. **Edge vs Cloud AI Execution**:
   - Gemma 4 int4 on-device (< 60 ms TTFT, 0.0 KB cloud egress, 100% private) vs. Gemini 3.8 Flash Cloud Run escalation (strategic cross-session reasoning, complex world simulation).
2. **Memory Architecture & Lifecycles**:
   - 4 cold-start boot phases (Directives, JIT Fetch, Task-Bound Context, 3 AM Dreaming Sync), episodic turn ingestion, durable knowledge anchors, and strict < 50 KB edge memory bundle budgets.
3. **Living State & Multi-Agent World Simulation**:
   - Active quest track / mission dossier, 3 faction standings, dynamic sector contacts, choice consequences, and edge-cloud state synchronization.

### B. What Goes Behind the Slider (Everything Mode Only)
The following developer-internal controls, cheat mechanisms, and diagnostic artifacts are hidden in Simple Mode and unlocked in Everything Mode:
- **Navigation Rail**: Simple Mode restricts the rail to ONLY the 2 core showcase views (`LoreCraft Studio` and `Edge Agent Boot`). Everything Mode unlocks all 8 destinations.
- **Developer Cheat Knobs**: Faction reputation `+10 / -10` stepper buttons (`btn_faction_sub_*`, `btn_faction_add_*`) are hidden in Simple Mode.
- **Direct Nav Jump Shortcuts**: The top bar `DEV MEMORY` button and left drawer `INSPECT IN MEMORY STUDIO ➔` shortcut are hidden in Simple Mode.
- **Arbiter & Scoring Rubrics**: The Canon Arbiter Scorecard card in the Living Lore drawer, the LLM-as-a-rater grading rubric card (`EducationAssessmentCard`) on the boot page, and raw frame budget compliance badges are hidden in Simple Mode.
- **Dialogue Telemetry**: Tapping a dialogue badge in Simple Mode displays a focused 3-pillar breakdown (Execution Route, Model Engine, TTFT/Latency, Cloud Egress, Memory Delta, Routing Reason). In Everything Mode, it displays full internal rule IDs (`Firebase AI Policy`), arbiter models, and commentary.

---

## 12. Related Documentation
- [LoreCraft Dynamic Gameplay](lorecraft_dynamic_gameplay.md): Narrative systems and A2UI interaction surfaces.
- [Routing Guide](routing_guide.md): Intent Pill visual contracts and switching rationale modals.
- [Memory Pipeline Specification](memory_pipeline.md): Quiet typography in memory inspectors and boot sequence telemetry.
- [Model Matrix & Hardware Boundaries](model_matrix.md): A2UI static catalog and two-step orchestration.



