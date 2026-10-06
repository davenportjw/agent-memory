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
- Memory Studio: Horizontal Request/Response flow diagram, continuous notebook stream, side-by-side Dual-Tree view (Local Edge Tree on left, Cloud Knowledge Graph on right) with docked simulator.

### Mobile / On-Device Mode ($< 700$px)
- Nav transforms into a drawer or bottom navigation bar.
- Request/Response diagram transforms into a **Vertical Stepper Indicator**.
- Dual-Tree transforms into a **Segmented Control** (`[ 📱 Local Tree ]`, `[ ☁️ Cloud Graph ]`, `[ ⚡ Diff ]`) with thumb-friendly collapsible tree nodes.
- Contradiction audits open in an accessible **Modal Bottom Sheet**.
- The Pattern Testing Sandbox pins cleanly as a **Docked Bottom Action Bar**.

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

## 7. Related Documentation
- [LoreCraft Dynamic Gameplay](lorecraft_dynamic_gameplay.md): Narrative systems and A2UI interaction surfaces.
- [Routing Guide](routing_guide.md): Intent Pill visual contracts and switching rationale modals.
- [Memory Pipeline Specification](memory_pipeline.md): Quiet typography in memory inspectors and boot sequence telemetry.
- [Model Matrix & Hardware Boundaries](model_matrix.md): A2UI static catalog and two-step orchestration.



