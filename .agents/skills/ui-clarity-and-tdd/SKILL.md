---
name: ui-clarity-and-tdd
description: Mandatory planning, TDD, affordance enforcement, and clarity standards for Flutter, web, and client UI development. Activates whenever designing, modifying, or auditing user interfaces, components, widgets, cards, or dashboards to prevent dead UI, false affordances, and unexplained engineering jargon.
---

# UI Clarity, Affordance Enforcement & TDD Protocol

This skill governs the design, implementation, and automated testing of user interfaces across Flutter, web, and client applications. It establishes strict engineering rules to eliminate **dead UI**, **false affordances**, **confetti pills**, **confusing toggles**, and **unexplained engineering jargon**, enforcing complete visual parity with underlying data models through rigorous Test-Driven Development (TDD) and live production verification.

---

## 1. Core Philosophy & Principles of UI Truthfulness

> **"If it looks like a button, chip, or card, it must do something; if it does nothing, style it like quiet text."**

False affordances break user trust. When a UI element presents interactive visual signifiers—such as rounded borders, elevated surfaces, badge pill containers, hover states, or action icons—the user instinctively expects a responsive interaction (tap, click, drill-down, expansion, or detailed tooltip). When an interactive element does nothing or acts as dead decoration, users experience frustration.

### The Four Principles of UI Truthfulness:
1. **Interactive Elements Must Respond**: Any component styled as a chip, pill, badge, elevated card, or button MUST provide meaningful interaction (open a modal, trigger navigation, toggle an inline expansion, or display an inspectable contextual sheet).
2. **Static Data Must Look Static (Quiet Typography)**: Purely informational data that cannot be tapped or expanded must be presented using **quiet typography**—subtle fonts, standard inline text, inline colored dots (`●`), zero elevated pill backgrounds, and no misleading hover cursors.
3. **The Cognitive Overload Principle (Simple vs. Everything Mode)**: A clean UI separates product showcase value from developer instrumentation. Exposing internal diagnostic knobs, cheat steppers, and raw rule IDs in the primary user flow creates fatigue. Systems must support dual-mode presentation: **Simple Mode** (spotlighting core product pillars with plain-English telemetry) and **Everything Mode** (revealing developer diagnostics, rule matrices, and cheat knobs).
4. **The High-Value Control Principle (No Frivolous/Confusing Toggles)**: Avoid creating toggles for internal display flags that confuse users (such as toggles that merely hide/show redundant speech). Instead, provide **high-value functional controls** that map to clear mental models (e.g. toggling active edge AI engines between Gemma 4 int4 and Gemini Nano with real model switching, dynamic label updates, and instant visual feedback).

---

## 2. The Four Mandatory Gates

Before writing code or marking any UI task complete, engineers and agents must pass through four mandatory gates. **Work is NEVER complete until the live version is deployed to Cloud Run ('$GCP_PROJECT') and verified via live HTTP probe.**

```
+-----------------------------------------------------------------------------------+
| GATE 1: Affordance, Clarity & Cognitive Layout Specification                      |
| - Zero-False-Affordance Rule (every pill/card has action or quiet styling)        |
| - Plain Language & Three Context Questions (What, Why, What Changed; no enums)   |
| - Complete Visual Parity Rule (relations, history, latencies, and diffs exposed)  |
| - Confetti Pill Anti-Pattern & Quiet Typography Mandate (dot indicators, mono text)|
| - Simple vs. Everything Mode Partitioning (spotlight 3 technical pillars)         |
| - High-Value Control Mandate (meaningful toggles with instant feedback)           |
| - Generative UI (A2UI) Extraction (sanitize raw JSON, separate stage cues)        |
| - Responsive Layout Contention & Overlap Prevention (3-tier LayoutBuilder)       |
+----------------------------------------+------------------------------------------+
                                         |
                                         v
+-----------------------------------------------------------------------------------+
| GATE 2: Test-Driven Development (TDD) Protocol                                    |
| - Explicit physical viewport sizing (`tester.view.physicalSize = Size(1440, 900)`)|
| - Tap gesture dispatch (`tester.tap`) and bottom sheet/dialog verification        |
| - Simple vs. Everything Mode visibility assertions                                |
| - Responsive breakpoint testing (Wide, Compact 640px, Ultra-compact 480px)        |
| - State mutation, live service notifications, and real error handling assertions  |
+----------------------------------------+------------------------------------------+
                                         |
                                         v
+-----------------------------------------------------------------------------------+
| GATE 3: Automated Validation & Pre-Commit Review                                  |
| - `flutter test` & `flutter analyze` pass with zero warnings                      |
| - Dead UI grep audit (no decorative Containers masquerading as buttons)           |
| - Strict Never Mock & real dynamic data wiring verification                        |
+----------------------------------------+------------------------------------------+
                                         |
                                         v
+-----------------------------------------------------------------------------------+
| GATE 4: Deployment & Live Verification Standard (MANDATORY)                       |
| - Build production assets (`flutter build web --release` / Docker)                |
| - Deploy to Cloud Run (`$GCP_PROJECT` in `us-central1`)                             |
| - Verify via live HTTP probe (`curl -s -i <cloud-run-service-url>`)                |
| - Work is NOT done until the live service URL is verified and reported             |
+-----------------------------------------------------------------------------------+
```

---

### Gate 1: Affordance, Clarity & Cognitive Layout Specification

#### Rule 1.1: The Zero-False-Affordance Rule
Every UI component featuring any of the following visual attributes is classified as **Affordance-Bearing**:
- Rounded pill backgrounds (`BorderRadius`, `StadiumBorder`, `Chip`)
- Outlined borders with accent colors
- Card elevation or drop shadows
- Accompanying chevron (`Icons.chevron_right`), info (`Icons.info_outline`), or action icons
- Hover cursor set to `SystemMouseCursors.click`

**Requirement**: Every Affordance-Bearing element **MUST** have an interactive handler:
- An `onTap` / `onPressed` callback that launches a detail modal, bottom sheet, or route transition.
- An inline expansion panel (`ExpansionTile` or accordion) that unfolds deeper details.
- At minimum, an accessible, multi-line `Tooltip` explaining context if no modal is warranted.

If an element does not warrant any interaction or tooltip, you **MUST** strip its pill/card styling and render it as flat, quiet inline text (e.g., `Text('Status: Active', style: theme.textTheme.bodySmall)`).

#### Rule 1.2: The Plain Language & Context Rule
Raw engineering jargon, internal database enums, machine codes, and cryptic state machine identifiers are **strictly prohibited** in user-facing surfaces.

- **Forbidden**: `ERR_CONSENSUS_TIMEOUT_V2`, `STATE_DISPATCH_ORCHESTRATOR_RUNNING`, `AGENT_WORKER_SIG_409`, raw UUIDs (`f0a0612a-76d6-4a18-8330-823099b86f84`), raw internal rule IDs (`RULE_DEV_DEBUG_01`) in default views.
- **Required**: Human-readable, clear English terms translated via dedicated presentation formatters or extension methods.

Furthermore, every status badge, decision pill, or alert card must answer the **Three Context Questions**:
1. **What is it?** A plain-English label of the current status or decision.
2. **Why is it in this state?** An inspectable explanation of the underlying cause, agent reasoning, or validation criteria.
3. **What changed / What is next?** A clear indication of the previous state, timestamp, or actionable next step (retry, inspect diff, view logs).

#### Rule 1.3: The Complete Visual Parity Rule
A UI must never truncate or swallow rich domain model data. If the underlying data entity includes:
- Related entities (parent tasks, assigned subagents, target databases)
- Historical audit logs or trajectory steps
- Contradictions or conflicting agent opinions
- Timestamps, TTFT (Time to First Token), total execution durations, and network egress byte counts (e.g. `0.0 KB (100% private)` vs remote egress)

The UI **MUST** provide a concrete path for the user to view this information—via an inspectable details drawer, modal bottom sheet, or expandable panel. Never drop model fields simply because they do not fit inside a single row.

#### Rule 1.4: The "Confetti Pill" Anti-Pattern & Quiet Typography Mandate
Packaging every piece of metadata (status, category, confidence, tags) into separate rounded container capsules creates severe cognitive fatigue ("Christmas tree" effect) and violates affordance truthfulness.

- **Forbidden Anti-Pattern**: Surrounding non-interactive metadata with capsule borders, shadows, or background fills (e.g. `Container(decoration: BoxDecoration(color: sageBg, borderRadius: BorderRadius.circular(4)), child: Text('Clean'))`).
- **Required Quiet Pattern**: Use quiet typography with minimal visual container weight:
  - **Status indicators**: Use a quiet inline colored dot indicator (`●`) followed by plain text (`● Clean`, `● PII Scrubbed`).
  - **Category tags**: Render as quiet uppercase mono text without container borders (`SYSTEM ARCHITECTURE`, `SECURITY POLICY`).
  - **Metrics / Confidence**: Render as inline key-value pairs (`Confidence: 99%`) in subtle secondary text.
  - **Entity lists**: Render as inline dot-separated text (`SQLite WASM · Friday`) rather than wraps of individual pill badges.
- **Actionable Intent Pills**: Retain pill containers ONLY when the element is an explicit interactive button or chip (such as `IntentPillWidget` in user flows or `Inspect Contradiction ➔` links) that dispatches a navigation, drawer expansion, or inspection dialog.

#### Rule 1.5: Simple vs. Everything Mode Partitioning
To avoid overwhelming users while preserving deep developer observability, implement a tactile mode switcher (`[ ⚡ Simple | 🔬 Everything ]`):
- **Simple Mode**:
  - Highlights strictly the core product pillars (e.g., Edge vs Cloud Execution, Memory Lifecycles, Living World State).
  - Hides developer-internal cheat buttons (e.g. reputation steppers `+10/-10`), debug jump buttons, raw rule IDs, and raw rater rubrics.
  - Telemetry modals display concise, high-value metrics: Execution Route, Model Engine, TTFT, Total Latency, Cloud Egress, Memory Delta, and Plain-English Routing Reason.
- **Everything Mode**:
  - Reveals all diagnostic views, engine toggles (`btn_toggle_edge_model`), internal policy rule IDs (`Firebase AI Policy`), cheat steppers, and LLM-as-a-rater grading rubrics.
  - Telemetry modals display full internal debugging fields.

#### Rule 1.6: High-Value Controls & Immediate Feedback
Do not create decorative or confusing toggles for internal UI flags (e.g., toggles that merely hide speech text without adding value). Instead, implement **high-value functional controls**:
- Example: An interactive edge model switcher (`EDGE: GEMMA 4` $\leftrightarrow$ `EDGE: GEMINI NANO`) that dynamically switches the active inference runtime between on-device Gemma 4 int4 (WebGPU / LiteRT) and Gemini Nano (Chrome Prompt API).
- **Feedback Standard**: Any control that mutates runtime state must provide:
  1. An immediate state change on the button/pill (icon + text).
  2. Clear multi-line tooltip explaining the active state and what tapping will trigger.
  3. A clean, non-stacking toast or SnackBar (`ScaffoldMessenger.of(context).clearSnackBars()`) confirming the transition in plain English.

#### Rule 1.7: Generative UI (A2UI) Extraction & Clean Dialogue
Generative AI outputs presenting interactive choices or actions must never leak raw JSON syntax or markdown code blocks into dialogue:
- **Sanitization**: Strips raw ````json ... ```` fences from visible dialogue bubbles.
- **Stage Cue Extraction**: Extracts stage cues `*[cue]*` into quiet italicized headers above the dialogue text.
- **Surface Promotion**: Promotes choices into dedicated interactive cards (`A2UISurfaceView`) featuring execution tier tags (`[EDGE]`, `[CLOUD]`).
- **Deduplication**: Suppresses redundant speech text when generative UI components are active to prevent visual repetition.

#### Rule 1.8: Responsive Layout Contention & Overlap Prevention
When sidebars or contextual inspector drawers open (e.g. 240px Left Nav Rail + 320px Right Inspector Drawer), the center workspace width shrinks dramatically (from 1200px+ down to 640px or 480px).
- **Three-Tier Breakpoints via `LayoutBuilder`**:
  - **Wide ($\ge 900$px)**: Full title text and full pill labels (`Load Gemma 4 2B (~1.46 GB)`, `Edge Probe: 12ms`).
  - **Compact ($600\text{px} \le \text{width} < 900\text{px}$)**: Streamlined title (`ASSISTANT SHELL`), concise pill labels (`Load Gemma 4`, `Auto`).
  - **Ultra-Compact ($< 600$px)**: Minimalist title (`ASSISTANT`), defer non-essential probes to inspector drawer.
- **Title Block Bounding**: Title block must be bounded to at most 45% of available width with `TextOverflow.ellipsis`.
- **Action Container**: Wrap action buttons/pills in an `Expanded` right-aligned container with a non-reversed horizontal scroll viewer (`SingleChildScrollView(scrollDirection: Axis.horizontal)`). This guarantees pills never wrap unexpectedly, squish, or clip from the left.

---

## 3. Good vs. Bad Code Patterns (Flutter Examples)

### Anti-Pattern 1: The "Dead UI" Confetti Pill (False Affordance)

```dart
// ❌ BAD: Misleading interactive appearance, raw enum jargon, dead to taps.
Widget buildStatusBadge(BuildContext context, String rawStatus) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
      color: Colors.amber.shade100,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.amber.shade700),
      boxShadow: const [
        BoxShadow(color: Colors.black12, blurRadius: 2, offset: Offset(0, 1)),
      ],
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.warning_amber_rounded, size: 16, color: Colors.amber.shade900),
        const SizedBox(width: 6),
        // Jargon: raw internal identifier shown directly to user
        Text(
          rawStatus, // e.g. "ERR_SUBAGENT_CONSENSUS_REJECTED"
          style: TextStyle(color: Colors.amber.shade900, fontWeight: FontWeight.bold),
        ),
      ],
    ),
  );
}
```

*Why it fails*:
- Has rounded pill border, shadow, and icon, looking exactly like an actionable button or filter chip.
- Clicking or tapping does nothing—frustrating the user.
- Displays raw technical jargon (`ERR_SUBAGENT_CONSENSUS_REJECTED`) without explaining what happened or what to do next.

---

### Pattern 1: The Active Affordance Chip with Inspection Modal

```dart
// ✅ GOOD: Accessible, clear affordance, plain English, contextual drill-down modal.
class AgentStatusChip extends StatelessWidget {
  final AgentStatusInfo statusInfo;

  const AgentStatusChip({super.key, required this.statusInfo});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: Tooltip(
        message: 'Tap to view decision details and timeline',
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _showStatusDetailsModal(context),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: statusInfo.backgroundColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: statusInfo.borderColor),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(statusInfo.icon, size: 14, color: statusInfo.textColor),
                const SizedBox(width: 6),
                Text(
                  statusInfo.userFacingTitle, // Plain English: "Consensus Blocked"
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: statusInfo.textColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(Icons.expand_more, size: 14, color: statusInfo.textColor),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showStatusDetailsModal(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => AgentStatusDetailsSheet(statusInfo: statusInfo),
    );
  }
}
```

---

### Pattern 2: Quiet Informational Styling (No False Affordance)

When an element is strictly informational and requires no tap interaction, modal, or expansion, **do not style it like a button or badge**.

```dart
// ✅ GOOD: Clean, quiet informational presentation. No misleading button styling.
class QuietStatusLabel extends StatelessWidget {
  final String label;
  final String value;

  final Color dotColor;

  const QuietStatusLabel({
    super.key,
    required this.label,
    required this.value,
    this.dotColor = const Color(0xFF3F6212),
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(shape: BoxShape.circle, color: dotColor),
        ),
        const SizedBox(width: 6),
        RichText(
          text: TextSpan(
            style: theme.textTheme.bodySmall,
            children: [
              TextSpan(
                text: '$label: ',
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
              ),
              TextSpan(
                text: value,
                style: TextStyle(
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
```

---

### Pattern 3: Responsive Header Toolbar with Overlap Prevention

```dart
// ✅ GOOD: Three-tier adaptive responsiveness preventing RenderFlex overflow
class ResponsiveWorkspaceHeader extends StatelessWidget {
  final String title;
  final Widget leftAction;
  final List<Widget> rightPills;

  const ResponsiveWorkspaceHeader({
    super.key,
    required this.title,
    required this.leftAction,
    required this.rightPills,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final isUltraCompact = width < 600;
        final isCompact = width < 900;

        final displayTitle = isUltraCompact
            ? 'ASSISTANT'
            : (isCompact ? 'ASSISTANT SHELL' : title);

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Color(0xFFE6DFD5))),
          ),
          child: Row(
            children: [
              leftAction,
              const SizedBox(width: 8),
              // Constrain title to prevent pushing out action pills
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: width * 0.42),
                child: Text(
                  displayTitle,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
              const Spacer(),
              // Right-aligned scrollable action pills container
              Flexible(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  reverse: false,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: rightPills,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
```

---

### Pattern 4: High-Value Edge Model Switcher Pill with State Feedback

```dart
// ✅ GOOD: Functional, informative edge engine switcher with instant toast feedback
Widget buildEdgeEngineTogglePill(BuildContext context, LocalExecutionManager edgeManager) {
  final isNano = edgeManager.activeEngine == ActiveEdgeEngine.geminiNano;
  final color = isNano ? const Color(0xFF0284C7) : const Color(0xFF3F6212);
  final engineLabel = isNano ? 'EDGE: GEMINI NANO' : 'EDGE: GEMMA 4';
  final tooltipMsg = isNano
      ? 'Active Edge Engine: Gemini Nano (Chrome Prompt API).\nTap to toggle Gemma 4 int4 (WebGPU / LiteRT).'
      : 'Active Edge Engine: Gemma 4 int4.\nTap to toggle Gemini Nano (Chrome Prompt API).';

  return InkWell(
    key: const Key('btn_toggle_edge_model'),
    onTap: () async {
      await edgeManager.toggleLocalEngine();
      final newIsNano = edgeManager.activeEngine == ActiveEdgeEngine.geminiNano;
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                newIsNano ? Icons.auto_awesome_rounded : Icons.memory_rounded,
                size: 16,
                color: Colors.white,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  newIsNano
                      ? '⚡ Switched edge engine to Gemini Nano (Chrome Built-in AI)'
                      : '⚡ Switched edge engine to Gemma 4 int4 (WebGPU / LiteRT)',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          duration: const Duration(seconds: 2),
          backgroundColor: color,
        ),
      );
    },
    borderRadius: BorderRadius.circular(14),
    child: Tooltip(
      message: tooltipMsg,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(isNano ? Icons.auto_awesome_rounded : Icons.memory_rounded, size: 13, color: color),
            const SizedBox(width: 4),
            Text(
              engineLabel,
              style: TextStyle(fontFamily: 'monospace', fontSize: 10, fontWeight: FontWeight.w700, color: color),
            ),
            const SizedBox(width: 4),
            Icon(Icons.swap_horiz, size: 12, color: color.withOpacity(0.7)),
          ],
        ),
      ),
    ),
  );
}
```

---

## 4. Test-Driven Development: Widget Test Specifications

### Viewport Guardrail for Flutter Widget Tests
In Flutter headless testing environments, default viewports are restricted. When testing responsive layouts or panels, **always explicitly set physicalSize and register tearDown**:

```dart
tester.view.physicalSize = const Size(1440, 900);
tester.view.devicePixelRatio = 1.0;
addTearDown(() {
  tester.view.resetPhysicalSize();
  tester.view.resetDevicePixelRatio();
});
```

### Complete Test Suite Example

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/services/app_mode_service.dart';
import 'package:my_app/views/agent_status_chip.dart';
import 'package:my_app/views/widgets/responsive_workspace_header.dart';

void main() {
  group('UI Clarity, Affordance & TDD Suite', () {
    testWidgets('renders human-readable title and tooltip, not raw code', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: AgentStatusChip(
                statusInfo: AgentStatusInfo(
                  userFacingTitle: 'Consensus Blocked',
                  summary: 'Agents disagreed on deployment safety criteria.',
                  reasoning: 'Security flagged egress rule.',
                  updatedAt: DateTime.now(),
                  traceId: 'tr-99',
                  isRetryable: true,
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Consensus Blocked'), findsOneWidget);
      expect(find.byType(Tooltip), findsOneWidget);

      // Tap chip to open bottom sheet
      await tester.tap(find.byType(InkWell));
      await tester.pumpAndSettle();

      expect(find.text('What Happened:'), findsOneWidget);
      expect(find.text('Why:'), findsOneWidget);
      expect(find.text('Retry Step'), findsOneWidget);
    });

    testWidgets('Simple mode hides developer knobs and cheat steppers', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      AppModeService().setMode(AppDisplayMode.simple);

      await tester.pumpWidget(const MaterialApp(home: MyMainStudioView()));
      await tester.pumpAndSettle();

      // Core product flows visible
      expect(find.byKey(const Key('btn_mission_dossier')), findsOneWidget);

      // Dev tools and cheat knobs hidden
      expect(find.byKey(const Key('btn_faction_sub_vanguard')), findsNothing);
      expect(find.byKey(const Key('btn_open_game_memory_dev_tool')), findsNothing);
    });

    testWidgets('Responsive header adapts titles and avoids overflow at 640px', (tester) async {
      tester.view.physicalSize = const Size(640, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ResponsiveWorkspaceHeader(
              title: 'ASSISTANT SHELL // DUAL EDGE-CLOUD WORKSPACE',
              leftAction: const Icon(Icons.bolt),
              rightPills: const [
                Chip(label: Text('Load Gemma 4')),
                Chip(label: Text('Auto')),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('ASSISTANT SHELL'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
```

---

## 5. Gate 3: Automated Validation & Pre-Commit Checklist

Before submitting code or declaring a UI component complete, run through this automated and manual checklist:

| Verification Item | Requirement | Pass Criteria |
| :--- | :--- | :--- |
| **Affordance Audit** | Every chip, pill, badge, or card has an active `onTap` or uses quiet text. | No dead `Container(decoration: BoxDecoration(...))` without interaction. |
| **No Raw Enums** | All status strings and rule IDs are formatted into plain English. | Grep shows no uppercase enum constants displayed directly in user `Text()`. |
| **Contextual Details** | Tapping opens a sheet/modal with What, Why, and Timestamps. | Modal verified in widget tests. |
| **Simple vs Everything Mode** | Showcase views hide dev cheats, rater rubrics, and internal rule IDs. | Simple mode widget tests pass 100%. |
| **Responsive Layout** | `LayoutBuilder` used on headers with bounded titles ($\le 45\%$) and scrollable pills. | Zero `RenderFlex` overflow errors at 1200px, 640px, and 480px. |
| **A2UI Cleanliness** | Strips raw JSON code blocks and stage cues from dialogue speech bubbles. | Dialogue cards render clean text + promoted `A2UISurfaceView` choices. |
| **High-Value Controls** | Toggles trigger real engine switches with immediate icon/text change & SnackBar. | Active engine toggle tested with live state assertion. |
| **TDD Widget Tests** | Physical viewport set (`1440x900`), taps tested, sheets asserted. | `flutter test` passes 100%. |
| **Static Analysis** | Dart analyzer reports zero issues. | `flutter analyze` reports zero warnings or errors. |
| **Strict Never Mock** | Dynamic wiring to real endpoints, services, and reactive stores. | No hardcoded fake delays, `simulateInference()`, or mock fallback objects. |

---

## 6. Gate 4: Deployment & Live Verification Standard (MANDATORY)

> **"The task is NOT complete when the tests pass locally. The task is ONLY complete when built, deployed to Cloud Run ('$GCP_PROJECT'), and verified via live HTTP probe."**

No agent, engineer, or workflow may declare a UI, service, or feature complete while running solely on localhost or emulator. Every feature touching client UI, service routers, or backend APIs must pass Gate 4:

1. **Production Build**: Compile release artifacts (`flutter build web --release`). Ensure zero build warnings or missing asset bundles.
2. **Cloud Run Deployment**: Deploy to Google Cloud Run in project `$GCP_PROJECT` (region `us-central1`).
   ```bash
   # Deploy Client to Cloud Run
   cd client && ../scripts/flutter build web --release
   gcloud run deploy distributed-ai-frontend \
     --source . \
     --region us-central1 \
     --project "${GCP_PROJECT}" \
     --platform managed \
     --allow-unauthenticated
   ```
3. **Live HTTP Verification Probe**: Probe the deployed URL with `curl -s -i <url>` to verify HTTP 200, valid headers (`cross-origin-opener-policy: same-origin`, `cross-origin-embedder-policy: credentialless`, `Cache-Control: no-cache, no-store, must-revalidate`), and proper HTML/WASM asset loading.
4. **Mandatory Live URL Reporting**: The completion response must provide the live URL (`https://<service-url>`) and the live probe outcome.

---

## 7. Engineer & Agent Runbook: Step-by-Step UI Implementation

When introducing any new card, chip, badge, row, or dashboard widget, follow this step-by-step runbook:

### Step 1: Data Model & Affordance Audit
1. Inspect the underlying data model. List all fields (raw code, human label, explanation, timestamps, durations, network egress, related IDs).
2. Classify visibility:
   - Does this belong in **Simple Mode** (core user journey/pillars) or **Everything Mode** (diagnostic logs, cheat knobs, internal policy IDs)?
3. Determine interaction requirement:
   - **Needs Inspection/Action**: Element represents a state with background context, logs, or actions. Use **Interactive Affordance** (`InkWell`, `Tooltip`, chevron icon, and modal/bottom sheet).
   - **Purely Informational**: Element is a simple scalar (line count, date, status tag). Use **Quiet Typography** (inline dot `●`, flat typography, no container capsule).

### Step 2: Responsive & Layout Contention Planning
1. Use `LayoutBuilder` for headers, action bars, or multi-item rows.
2. Constrain title blocks ($\le 45\%$ width) with `TextOverflow.ellipsis`.
3. Wrap action buttons in `Expanded` right-aligned containers with horizontal scrolling to prevent squishing or clipping when drawers open.

### Step 3: Write Widget Tests First (TDD)
1. Create `<widget_name>_test.dart` in `test/`.
2. Configure physical test viewport: `tester.view.physicalSize = const Size(1440, 900); addTearDown(tester.view.resetPhysicalSize);`.
3. Assert:
   - Plain English rendering (banning raw codes/enums).
   - Tap gesture triggering `showModalBottomSheet` or dialog.
   - Verification of the "What, Why, What Changed" and telemetry inside the dialog.
   - Verification of mode gating (hidden in Simple mode, visible in Everything mode).
   - Verification of responsive layout at 1200px, 640px, and 480px with `tester.takeException() == null`.
4. Run `flutter test test/...` and verify tests fail (Red stage).

### Step 4: Implement Widget with Full Affordances
1. Implement the widget using proper theme tokens and semantic widgets (`Material`, `InkWell`, `Tooltip`).
2. Implement contextual inspection sheet or expansion tile displaying full model context.
3. Wire real reactive state updates (`notifyListeners()`) and instant toast feedback for functional toggles.
4. Re-run `flutter test` and verify tests pass (Green stage).

### Step 5: Run Static Checks & Visual Review
1. Run `flutter analyze` to ensure zero linter or type errors.
2. Verify visual styling conforms to the design system (distraction-free light/sepia palette, readable typography, compact Intent Pills).
3. Ensure no mocked data or synthetic fallback routines are used.

### Step 6: Cloud Run Build, Deployment & Live Verification Probe (MANDATORY)
1. Compile production client (`cd client && ../scripts/flutter build web --release`).
2. Deploy to Cloud Run (`gcloud run deploy distributed-ai-frontend ...`).
3. Execute live HTTP verification probe (`curl -s -i https://<distributed-ai-frontend-url>/`).
4. Report the live service URL and live probe verification in your final response.
