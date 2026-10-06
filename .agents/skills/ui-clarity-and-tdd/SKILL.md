---
name: ui-clarity-and-tdd
description: Mandatory planning, TDD, affordance enforcement, and clarity standards for Flutter, web, and client UI development. Activates whenever designing, modifying, or auditing user interfaces, components, widgets, cards, or dashboards to prevent dead UI, false affordances, and unexplained engineering jargon.
---

# UI Clarity, Affordance Enforcement & TDD Protocol

This skill governs the design, implementation, and automated testing of user interfaces across Flutter, web, and client applications. It establishes strict rules to eliminate **dead UI**, **false affordances**, and **unexplained engineering jargon**, enforcing complete visual parity with underlying data models through rigorous Test-Driven Development (TDD).

---

## 1. Core Philosophy

> **"If it looks like a button, chip, or card, it must do something; if it does nothing, style it like quiet text."**

False affordances break user trust. When a UI element presents interactive visual signifiers—such as rounded borders, elevated surfaces, badge pill containers, hover states, or action icons—the user instinctively expects a responsive interaction (tap, click, drill-down, expansion, or detailed tooltip). 

Conversely, when an interactive element is styled with dead, unclickable widgets, users become confused and frustrated.

### The Two Principles of UI Truthfulness:
1. **Interactive Elements Must Respond**: Any component styled as a chip, pill, badge, elevated card, or button MUST provide meaningful interaction (open a modal, trigger navigation, toggle an inline expansion, or display an inspectable contextual sheet).
2. **Static Data Must Look Static**: Purely informational data that cannot be tapped or expanded must be presented using **quiet text styling**—subtle typography, standard inline layout, zero elevated pill backgrounds, and no misleading hover cursors.

---

## 2. The Four Mandatory Gates

Before writing code or marking any UI task complete, engineers and agents must pass through four mandatory gates. **Work is NEVER complete until the live version is deployed to Cloud Run ('$GCP_PROJECT') and verified via live HTTP probe.**

```
+-----------------------------------------------------------------------------------+
| GATE 1: Affordance & Clarity Specification                                        |
| - Zero-False-Affordance Rule (every pill/card has action or quiet styling)       |
| - Plain Language & Context Rule (What, Why, What Changed; ban raw enums)          |
| - Complete Visual Parity Rule (relations, history, and diffs are inspectable)    |
+----------------------------------------+------------------------------------------+
                                         |
                                         v
+-----------------------------------------------------------------------------------+
| GATE 2: Test-Driven Development (TDD) Protocol                                    |
| - Write widget tests before widget implementation                                |
| - Tap gesture dispatch (`tester.tap`)                                             |
| - Dialog/bottom sheet/modal content verification                                  |
| - State mutation, error handling & rollback verification                          |
+----------------------------------------+------------------------------------------+
                                         |
                                         v
+-----------------------------------------------------------------------------------+
| GATE 3: Automated Validation & Pre-Commit Review                                  |
| - `flutter test` & `flutter analyze` pass with zero warnings                     |
| - Dead UI grep audit (no decorative Containers masquerading as buttons)          |
| - Strict Never Mock & real dynamic data wiring verification                       |
+----------------------------------------+------------------------------------------+
                                         |
                                         v
+-----------------------------------------------------------------------------------+
| GATE 4: Deployment & Live Verification Standard (MANDATORY)                       |
| - Build production assets (`flutter build web --release` / Docker)                |
| - Deploy to Cloud Run (`$GCP_PROJECT` in `us-central1`)                            |
| - Verify via live HTTP probe (`curl -s -i <cloud-run-service-url>`)               |
| - Work is NOT done until the live service URL is verified and reported            |
+-----------------------------------------------------------------------------------+
```

---

### Gate 1: UI Planning & Affordance Specification

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

- **Forbidden**: `ERR_CONSENSUS_TIMEOUT_V2`, `STATE_DISPATCH_ORCHESTRATOR_RUNNING`, `AGENT_WORKER_SIG_409`, raw UUIDs (`f0a0612a-76d6-4a18-8330-823099b86f84`).
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
- Timestamps and execution durations

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

---

### Gate 2: Test-Driven Development (TDD) Protocol

UI widgets must be designed and validated through tests **before** marking tasks complete. In Flutter/Dart, this requires widget tests targeting user interactions, component lifecycles, and affordance responses.

#### Mandatory Test Cases

1. **Render & Semantic Test**:
   - Verify the widget renders with human-readable text (not raw enum strings).
   - Verify proper semantic labels and tooltips exist.

2. **Tap Gesture & Modal Dispatch (`tester.tap`)**:
   - Verify that tapping the card or chip fires the interaction.
   - Verify that the expected modal bottom sheet, dialog, or drawer appears on screen (`find.byType(BottomSheet)` or `find.byType(AlertDialog)`).

3. **Detail Content & Context Verification**:
   - Verify that inside the opened modal, the full context is present: the "What", the "Why", timestamps, and relational data.

4. **State Mutation & Action Verification**:
   - If the modal or card contains an action (e.g., "Retry", "Approve", "Rollback"), test tapping the button and asserting the corresponding state update or service call.
   - Test failure states: if an action fails, assert that a real error message is surfaced to the user (no silent failures or fake mock fallbacks).

---

### Gate 3: Automated Validation & Pre-Commit Checklist

Before submitting code or declaring a UI component complete, run through this automated and manual checklist:

| Verification Item | Requirement | Pass Criteria |
| :--- | :--- | :--- |
| **Affordance Audit** | Every chip, pill, badge, or card has an active `onTap` or uses quiet text. | No dead `Container(decoration: BoxDecoration(...))` without interaction. |
| **No Raw Enums** | All status strings are formatted into plain English. | Grep shows no uppercase enum constants displayed directly in `Text()`. |
| **Contextual Details** | Tapping opens a sheet/modal with What, Why, and Timestamps. | Modal verified in widget tests. |
| **TDD Widget Tests** | Automated tests execute tap gestures and assert modal visibility. | `flutter test` passes 100%. |
| **Static Analysis** | Dart analyzer reports zero issues. | `flutter analyze` reports zero warnings or errors. |
| **Design System** | Follows academic light / sepia guidelines with clear typography. | Clean 2-3 panel layouts, compact Intent Pills, no bulky static banners. |
| **Strict Never Mock** | Dynamic wiring to real endpoints/models. | No hardcoded fake delays, `simulateInference()`, or mock fallback objects. |

---

### Gate 4: Deployment & Live Verification Standard (MANDATORY)

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
3. **Live HTTP Verification Probe**: Probe the deployed URL with `curl -s -i <url>` to verify HTTP 200, valid headers (`cross-origin-opener-policy: same-origin`, `cross-origin-embedder-policy: credentialless`), and proper HTML/WASM asset loading.
4. **Mandatory Live URL Reporting**: The completion response must provide the live URL (`https://<service-url>`) and the live probe outcome.

---

## 3. Good vs. Bad Code Patterns (Flutter Examples)

### Anti-Pattern 1: The "Dead UI" Pill Chip (False Affordance)

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
    final colorScheme = theme.colorScheme;

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

class AgentStatusDetailsSheet extends StatelessWidget {
  final AgentStatusInfo statusInfo;

  const AgentStatusDetailsSheet({super.key, required this.statusInfo});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                statusInfo.userFacingTitle,
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const Divider(),
          const SizedBox(height: 8),
          Text(
            'What Happened:',
            style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          Text(statusInfo.summary, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 12),
          Text(
            'Why:',
            style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          Text(statusInfo.reasoning, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 12),
          Text(
            'Timestamp & Trace:',
            style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          Text(
            '${statusInfo.updatedAt.toLocal()} (${statusInfo.traceId})',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
              if (statusInfo.isRetryable) ...[
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    statusInfo.onRetry?.call();
                  },
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Retry Step'),
                ),
              ],
            ],
          ),
        ],
      ),
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

  const QuietStatusLabel({super.key, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return RichText(
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
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
```

---

## 4. Test-Driven Development: Widget Test Specification

Here is the standard Flutter widget test demonstrating the mandatory verification pattern:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/ui/agent_status_chip.dart';
import 'package:my_app/models/agent_status_info.dart';

void main() {
  group('AgentStatusChip Affordance & TDD Suite', () {
    final testStatusInfo = AgentStatusInfo(
      rawCode: 'ERR_CONSENSUS_FAIL',
      userFacingTitle: 'Consensus Blocked',
      summary: 'Agents disagreed on the deployment safety criteria.',
      reasoning: 'Security agent flagged unauthorized egress rule in terraform script.',
      traceId: 'trace-88912',
      updatedAt: DateTime(2026, 10, 2, 10, 30),
      isRetryable: true,
      backgroundColor: Colors.amber.shade50,
      borderColor: Colors.amber.shade300,
      textColor: Colors.amber.shade900,
      icon: Icons.warning_amber_rounded,
    );

    testWidgets('renders human-readable title and tooltip, not raw code', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(child: AgentStatusChip(statusInfo: testStatusInfo)),
          ),
        ),
      );

      // Verify plain English label is rendered
      expect(find.text('Consensus Blocked'), findsOneWidget);
      expect(find.text('ERR_CONSENSUS_FAIL'), findsNothing);

      // Verify tooltip presence
      expect(find.byType(Tooltip), findsOneWidget);
    });

    testWidgets('tapping chip opens modal bottom sheet with complete details', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(child: AgentStatusChip(statusInfo: testStatusInfo)),
          ),
        ),
      );

      // Tap the chip
      await tester.tap(find.byType(InkWell));
      await tester.pumpAndSettle();

      // Verify modal bottom sheet opened
      expect(find.byType(AgentStatusDetailsSheet), findsOneWidget);

      // Verify What and Why context are displayed
      expect(find.text('What Happened:'), findsOneWidget);
      expect(find.text('Agents disagreed on the deployment safety criteria.'), findsOneWidget);
      expect(find.text('Why:'), findsOneWidget);
      expect(
        find.text('Security agent flagged unauthorized egress rule in terraform script.'),
        findsOneWidget,
      );

      // Verify Retry button exists
      expect(find.text('Retry Step'), findsOneWidget);

      // Verify dismissing modal
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      expect(find.byType(AgentStatusDetailsSheet), findsNothing);
    });
  });
}
```

---

## 5. Engineer & Agent Runbook: Adding New UI Elements

When introducing any new card, chip, badge, row, or dashboard widget, follow this step-by-step runbook:

### Step 1: Data Model & Affordance Audit
1. Inspect the underlying data model. List all fields (e.g., raw code, human label, explanation, timestamps, related entity IDs, retryable state).
2. Determine interaction requirement:
   - **Needs Inspection/Action**: Element represents a state with background context, logs, or actions. Use **Interactive Affordance** (`InkWell`, `Tooltip`, chevron icon, and modal/bottom sheet).
   - **Purely Informational**: Element is a simple scalar (e.g. line count, simple date). Use **Quiet Text** (flat typography, no badge container, no false clickability).

### Step 2: Write Widget Tests First (TDD)
1. Create `<widget_name>_test.dart` in `test/`.
2. Write tests asserting:
   - Plain English rendering (banning raw codes).
   - Tap gesture triggering `showModalBottomSheet` or dialog.
   - Verification of the "What, Why, What Changed" inside the dialog.
   - Verification of action dispatch and error handling.
3. Run `flutter test test/...` and verify tests fail (Red stage).

### Step 3: Implement Widget with Full Affordances
1. Implement the widget using proper theme tokens and semantic widgets (`Material`, `InkWell`, `Tooltip`).
2. Implement the contextual inspection sheet or expansion tile displaying full model context.
3. Re-run `flutter test` and verify tests pass (Green stage).

### Step 4: Run Static Checks & Visual Review
1. Run `flutter analyze` to ensure zero linter or type errors.
2. Verify visual styling conforms to the design system (distraction-free light/sepia palette, readable typography, compact Intent Pills).
3. Ensure no mocked data or synthetic fallback routines are used—all data must flow dynamically from genuine providers/repositories.

### Step 5: Cloud Run Build, Deployment & Live Verification Probe (MANDATORY)
1. **Never declare work complete until deployed**: Code running locally or passing tests in CI is necessary but NOT sufficient. Work is ONLY complete when the live service is updated and verified in production.
2. **Compile production client**:
   ```bash
   cd client && ../scripts/flutter build web --release
   ```
3. **Deploy to Cloud Run ('$GCP_PROJECT')**:
   ```bash
   cd client && gcloud run deploy distributed-ai-frontend \
     --source . \
     --region us-central1 \
     --project "${GCP_PROJECT}" \
     --platform managed \
     --allow-unauthenticated
   ```
4. **Execute live HTTP verification probe**:
   ```bash
   curl -s -i https://<distributed-ai-frontend-url>/
   ```
5. **Report live service URL**: The final agent response must state that deployment succeeded, cite the live probe HTTP status, and provide the live service URL.

