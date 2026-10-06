import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:client/views/widgets/sepia_markdown_widget.dart';
import 'package:client/views/widgets/markdown_prompt_editor.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SepiaMarkdownWidget UI & Affordance Suite', () {
    testWidgets('renders headings, bold, inline code, and lists', (tester) async {
      const sampleMarkdown = '''
### Conceptual Example

To query APIs, use **Chrome DevTools Protocol (CDT-API)** with `Page.navigate`.

1. **Complexity:** Requires DevTools connection
2. **Environment:** Requires Chrome
   * Running browser
   * Specific flags

---
> Remember to sanitize sensitive tokens.
''';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: SepiaMarkdownWidget(markdown: sampleMarkdown),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Heading
      expect(find.text('Conceptual Example'), findsOneWidget);
      // Inline bold text
      expect(find.textContaining('Chrome DevTools Protocol (CDT-API)'), findsOneWidget);
      // Inline code
      expect(find.textContaining('Page.navigate'), findsOneWidget);
      // Numbered list items
      expect(find.text('1.'), findsOneWidget);
      expect(find.text('2.'), findsOneWidget);
      // Bullet list items
      expect(find.textContaining('Running browser'), findsOneWidget);
      // Blockquote
      expect(find.textContaining('Remember to sanitize sensitive tokens.'), findsOneWidget);
      // Divider
      expect(find.byType(Divider), findsOneWidget);
    });

    testWidgets('fenced code block displays language badge and copy button with feedback', (tester) async {
      const codeSnippet = '```go\nfunc hello() {\n  println("Hello AGY")\n}\n```';

      // Mock clipboard system channel
      final log = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (MethodCall methodCall) async {
          log.add(methodCall);
          return null;
        },
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SepiaMarkdownWidget(markdown: codeSnippet),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify language badge
      expect(find.text('GO'), findsOneWidget);
      expect(find.textContaining('println("Hello AGY")'), findsOneWidget);

      // Verify copy button with tooltip
      final copyBtn = find.byTooltip('Copy code to clipboard');
      expect(copyBtn, findsOneWidget);

      // Tap copy button
      await tester.tap(copyBtn);
      await tester.pump();

      // Verify visual confirmation "Copied!"
      expect(find.text('Copied!'), findsOneWidget);

      // Verify clipboard channel call
      expect(log.any((call) => call.method == 'Clipboard.setData'), isTrue);
    });
  });

  group('MarkdownPromptEditor UI & Affordance Suite', () {
    testWidgets('renders formatting toolbar with active tooltips and buttons', (tester) async {
      final controller = TextEditingController(text: 'Hello world');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MarkdownPromptEditor(
              controller: controller,
              onSubmit: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify toolbar buttons and tooltips
      expect(find.byTooltip('Bold (**text**)'), findsOneWidget);
      expect(find.byTooltip('Italic (*text*)'), findsOneWidget);
      expect(find.byTooltip('Heading (### text)'), findsOneWidget);
      expect(find.byTooltip('Inline Code (`text`)'), findsOneWidget);
      expect(find.byTooltip('Code Block (```text```)'), findsOneWidget);
      expect(find.byTooltip('Bulleted List (- item)'), findsOneWidget);
      expect(find.byTooltip('Numbered List (1. item)'), findsOneWidget);
      expect(find.byTooltip('Blockquote (> text)'), findsOneWidget);
    });

    testWidgets('tapping bold button wraps selection or inserts markdown bold tags', (tester) async {
      final controller = TextEditingController(text: 'antigravity engine');
      controller.selection = const TextSelection(baseOffset: 0, extentOffset: 11); // "antigravity"

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MarkdownPromptEditor(
              controller: controller,
              onSubmit: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap bold button
      await tester.tap(find.byTooltip('Bold (**text**)'));
      await tester.pump();

      expect(controller.text, equals('**antigravity** engine'));
    });

    testWidgets('toggling between Write and Preview tabs displays live markdown preview', (tester) async {
      final controller = TextEditingController(text: '### Dynamic Preview\n**Bold feature** is ready.');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MarkdownPromptEditor(
              controller: controller,
              onSubmit: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Initially in Write mode: TextField visible
      expect(find.byType(TextField), findsOneWidget);

      // Tap Preview tab
      await tester.tap(find.text('Preview'));
      await tester.pumpAndSettle();

      // In Preview mode: TextField hidden or replaced by SepiaMarkdownWidget
      expect(find.byType(SepiaMarkdownWidget), findsOneWidget);
      expect(find.text('Dynamic Preview'), findsOneWidget);
      expect(find.textContaining('Bold feature'), findsOneWidget);

      // Tap Write tab to switch back
      await tester.tap(find.text('Write'));
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsOneWidget);
    });
  });
}
