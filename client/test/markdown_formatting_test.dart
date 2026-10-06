import 'package:flutter_test/flutter_test.dart';
import 'package:client/views/widgets/sepia_markdown_widget.dart';

void main() {
  runMarkdownFormattingTests(
    (name, body) => test(name, body),
    (cond, [String? msg]) => expect(cond, isTrue, reason: msg),
  );
}

void runMarkdownFormattingTests(
  void Function(String name, void Function() body) test,
  void Function(bool condition, [String? message]) expect,
) {
  test('Markdown: Parses headings H1 through H4', () {
    const text = '# Heading 1\n## Heading 2\n### Heading 3\n#### Heading 4';
    final blocks = parseMarkdownBlocks(text);

    expect(blocks.length == 4, 'Should parse 4 blocks');
    expect(blocks[0] is HeadingBlock && (blocks[0] as HeadingBlock).level == 1, 'H1 level matches');
    expect((blocks[0] as HeadingBlock).text == 'Heading 1', 'H1 text matches');
    expect(blocks[1] is HeadingBlock && (blocks[1] as HeadingBlock).level == 2, 'H2 level matches');
    expect(blocks[2] is HeadingBlock && (blocks[2] as HeadingBlock).level == 3, 'H3 level matches');
    expect(blocks[3] is HeadingBlock && (blocks[3] as HeadingBlock).level == 4, 'H4 level matches');
  });

  test('Markdown: Parses fenced code blocks with language and content', () {
    const text = '```go\nfunc main() {\n\tprintln("hello")\n}\n```';
    final blocks = parseMarkdownBlocks(text);

    expect(blocks.length == 1, 'Should parse 1 code block');
    expect(blocks[0] is CodeBlock, 'Block must be CodeBlock');
    final code = blocks[0] as CodeBlock;
    expect(code.language.toLowerCase() == 'go', 'Language must be go');
    expect(code.code.contains('println("hello")'), 'Code body must match');
  });

  test('Markdown: Handles unclosed code block during streaming gracefully', () {
    const text = '```dart\nvoid main() {\n  // streaming partial tokens';
    final blocks = parseMarkdownBlocks(text);

    expect(blocks.length == 1, 'Should parse unclosed code fence');
    expect(blocks[0] is CodeBlock, 'Should be parsed as CodeBlock');
    final code = blocks[0] as CodeBlock;
    expect(code.language.toLowerCase() == 'dart', 'Language must be dart');
    expect(code.code.contains('streaming partial tokens'), 'Should preserve code content');
  });

  test('Markdown: Parses blockquotes with multi-line support', () {
    const text = '> This is a critical blockquote.\n> Second line of blockquote.\n\nRegular text';
    final blocks = parseMarkdownBlocks(text);

    expect(blocks.length == 2, 'Should parse blockquote and regular paragraph');
    expect(blocks[0] is BlockquoteBlock, 'First block must be BlockquoteBlock');
    final quote = blocks[0] as BlockquoteBlock;
    expect(quote.text.contains('This is a critical blockquote.'), 'Quote contains first line');
    expect(quote.text.contains('Second line of blockquote.'), 'Quote contains second line');
    expect(blocks[1] is ParagraphBlock, 'Second block must be ParagraphBlock');
  });

  test('Markdown: Parses ordered and unordered lists with nested items', () {
    const text = '''
1. **Complexity:** Setup DevTools protocol
2. **Environment:** Requires local browser
   * Running Chrome instance
   * Auth configuration
''';
    final blocks = parseMarkdownBlocks(text);

    expect(blocks.isNotEmpty, 'Should parse list items');
    final ordered = blocks.whereType<ListItemBlock>().where((b) => b.isOrdered).toList();
    expect(ordered.length == 2, 'Should have 2 ordered list items');
    expect(ordered[0].number == '1.', 'First number is 1.');
    expect(ordered[1].number == '2.', 'Second number is 2.');

    final unordered = blocks.whereType<ListItemBlock>().where((b) => !b.isOrdered).toList();
    expect(unordered.length == 2, 'Should have 2 nested unordered bullet items');
    expect(unordered[0].indentationLevel > 0, 'Bullet item has indentation');
  });

  test('Markdown: Parses horizontal rules', () {
    const text = 'Text before\n---\nText after';
    final blocks = parseMarkdownBlocks(text);

    expect(blocks.length == 3, 'Should parse 3 blocks');
    expect(blocks[0] is ParagraphBlock, 'First is paragraph');
    expect(blocks[1] is DividerBlock, 'Second is divider');
    expect(blocks[2] is ParagraphBlock, 'Third is paragraph');
  });

  test('Markdown: Parses markdown tables', () {
    const text = '''
| Model | Latency | Egress |
|---|---|---|
| Gemma 4 | 42ms | 0 KB |
| Gemini 3.8 Flash | 280ms | 1.8 KB |
''';
    final blocks = parseMarkdownBlocks(text);

    expect(blocks.length == 1, 'Should parse table as single TableBlock');
    expect(blocks[0] is TableBlock, 'Must be TableBlock');
    final table = blocks[0] as TableBlock;
    expect(table.headers.length == 3, 'Table has 3 headers');
    expect(table.rows.length == 2, 'Table has 2 data rows');
    expect(table.headers[0] == 'Model', 'First header is Model');
    expect(table.rows[0][0] == 'Gemma 4', 'First row first col is Gemma 4');
  });

  test('Markdown: Parses inline spans (bold, italic, code, links)', () {
    const inlineText = 'Use `Page.navigate` to open **Chrome** or *safari*, see [docs](https://antigravity.dev).';
    final spans = parseInlineSpans(inlineText);

    expect(spans.isNotEmpty, 'Spans must be non-empty');
    final boldSpans = spans.where((s) => s.isBold).toList();
    expect(boldSpans.isNotEmpty, 'Should contain bold span');
    expect(boldSpans.any((s) => s.text == 'Chrome'), 'Bold span has "Chrome"');

    final codeSpans = spans.where((s) => s.isCode).toList();
    expect(codeSpans.isNotEmpty, 'Should contain code span');
    expect(codeSpans.any((s) => s.text == 'Page.navigate'), 'Code span has "Page.navigate"');

    final linkSpans = spans.where((s) => s.isLink).toList();
    expect(linkSpans.isNotEmpty, 'Should contain link span');
    expect(linkSpans.any((s) => s.linkUrl == 'https://antigravity.dev'), 'Link has correct URL');
  });

  test('Markdown: Preserves unclosed formatting delimiters without crashing', () {
    const broken = 'This has an unclosed **bold word and `unclosed code block';
    final spans = parseInlineSpans(broken);

    expect(spans.isNotEmpty, 'Must parse without throwing');
    final allText = spans.map((s) => s.text).join();
    expect(allText.contains('bold word'), 'Preserves content');
  });
}
