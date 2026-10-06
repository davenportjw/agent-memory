import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/sepia_theme.dart';

// ---------------------------------------------------------------------------
// Block Model Hierarchy
// ---------------------------------------------------------------------------

abstract class MarkdownBlock {}

class HeadingBlock extends MarkdownBlock {
  final int level;
  final String text;
  HeadingBlock(this.level, this.text);
}

class CodeBlock extends MarkdownBlock {
  final String language;
  final String code;
  CodeBlock(this.language, this.code);
}

class BlockquoteBlock extends MarkdownBlock {
  final String text;
  BlockquoteBlock(this.text);
}

class ListItemBlock extends MarkdownBlock {
  final bool isOrdered;
  final String number;
  final int indentationLevel;
  final String text;
  ListItemBlock({
    required this.isOrdered,
    this.number = '',
    this.indentationLevel = 0,
    required this.text,
  });
}

class DividerBlock extends MarkdownBlock {}

class TableBlock extends MarkdownBlock {
  final List<String> headers;
  final List<List<String>> rows;
  TableBlock(this.headers, this.rows);
}

class ParagraphBlock extends MarkdownBlock {
  final String text;
  ParagraphBlock(this.text);
}

// ---------------------------------------------------------------------------
// Inline Span Token Node
// ---------------------------------------------------------------------------

class InlineSpanNode {
  final String text;
  final bool isBold;
  final bool isItalic;
  final bool isCode;
  final bool isStrike;
  final bool isLink;
  final String? linkUrl;

  const InlineSpanNode({
    required this.text,
    this.isBold = false,
    this.isItalic = false,
    this.isCode = false,
    this.isStrike = false,
    this.isLink = false,
    this.linkUrl,
  });
}

// ---------------------------------------------------------------------------
// Markdown Parser
// ---------------------------------------------------------------------------

List<MarkdownBlock> parseMarkdownBlocks(String rawText) {
  final List<MarkdownBlock> blocks = [];
  final lines = rawText.split('\n');
  int i = 0;

  while (i < lines.length) {
    final line = lines[i];
    final trimmed = line.trim();

    // 1. Skip completely empty lines
    if (trimmed.isEmpty) {
      i++;
      continue;
    }

    // 2. Fenced Code Block (```lang)
    if (trimmed.startsWith('```')) {
      final lang = trimmed.substring(3).trim();
      final language = lang.isEmpty ? 'code' : lang;
      final codeLines = <String>[];
      i++;
      while (i < lines.length && !lines[i].trim().startsWith('```')) {
        codeLines.add(lines[i]);
        i++;
      }
      if (i < lines.length && lines[i].trim().startsWith('```')) {
        i++; // Consume closing fence
      }
      blocks.add(CodeBlock(language, codeLines.join('\n')));
      continue;
    }

    // 3. Headings (# H1 - ###### H6)
    if (trimmed.startsWith('#')) {
      int hashCount = 0;
      while (hashCount < trimmed.length && trimmed[hashCount] == '#') {
        hashCount++;
      }
      if (hashCount <= 6 && hashCount < trimmed.length && trimmed[hashCount] == ' ') {
        final headingText = trimmed.substring(hashCount).trim();
        blocks.add(HeadingBlock(hashCount, headingText));
        i++;
        continue;
      }
    }

    // 4. Horizontal Rule (---, ***, ___)
    if (trimmed == '---' || trimmed == '***' || trimmed == '___') {
      blocks.add(DividerBlock());
      i++;
      continue;
    }

    // 5. Blockquote (> quote)
    if (trimmed.startsWith('>')) {
      final quoteLines = <String>[];
      while (i < lines.length && lines[i].trim().startsWith('>')) {
        var qLine = lines[i].trim().substring(1);
        if (qLine.startsWith(' ')) qLine = qLine.substring(1);
        quoteLines.add(qLine);
        i++;
      }
      blocks.add(BlockquoteBlock(quoteLines.join('\n')));
      continue;
    }

    // 6. Markdown Table (| Header | Header |)
    if (trimmed.startsWith('|') && trimmed.endsWith('|') && i + 1 < lines.length) {
      final nextTrimmed = lines[i + 1].trim();
      if (nextTrimmed.startsWith('|') && nextTrimmed.contains('---')) {
        final rawHeaders = trimmed
            .split('|')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList();
        i += 2; // Skip header and separator
        final rows = <List<String>>[];
        while (i < lines.length && lines[i].trim().startsWith('|') && lines[i].trim().endsWith('|')) {
          final rowCells = lines[i]
              .trim()
              .split('|')
              .map((s) => s.trim())
              .where((s) => s.isNotEmpty)
              .toList();
          if (rowCells.isNotEmpty) {
            rows.add(rowCells);
          }
          i++;
        }
        blocks.add(TableBlock(rawHeaders, rows));
        continue;
      }
    }

    // 7. Ordered List (1. , 2. ) or Unordered List (* , - , + )
    final orderedMatch = RegExp(r'^(\s*)(\d+)\.\s+(.*)$').firstMatch(line);
    final unorderedMatch = RegExp(r'^(\s*)([\*\-\+])\s+(.*)$').firstMatch(line);

    if (orderedMatch != null) {
      final indentSpaces = orderedMatch.group(1)?.length ?? 0;
      final indentLevel = (indentSpaces / 2).floor();
      final numStr = '${orderedMatch.group(2)}.';
      final itemText = orderedMatch.group(3) ?? '';
      blocks.add(ListItemBlock(
        isOrdered: true,
        number: numStr,
        indentationLevel: indentLevel,
        text: itemText,
      ));
      i++;
      continue;
    }

    if (unorderedMatch != null) {
      final indentSpaces = unorderedMatch.group(1)?.length ?? 0;
      final indentLevel = (indentSpaces / 2).floor();
      final itemText = unorderedMatch.group(3) ?? '';
      blocks.add(ListItemBlock(
        isOrdered: false,
        indentationLevel: indentLevel,
        text: itemText,
      ));
      i++;
      continue;
    }

    // 8. Default: Regular Paragraph (gather lines until blank line or next block marker)
    final paraLines = <String>[line];
    i++;
    while (i < lines.length) {
      final next = lines[i];
      final nextTrimmed = next.trim();
      if (nextTrimmed.isEmpty ||
          nextTrimmed.startsWith('```') ||
          nextTrimmed.startsWith('#') ||
          nextTrimmed.startsWith('>') ||
          nextTrimmed == '---' ||
          nextTrimmed == '***' ||
          RegExp(r'^(\s*)(\d+)\.\s+').hasMatch(next) ||
          RegExp(r'^(\s*)([\*\-\+])\s+').hasMatch(next) ||
          (nextTrimmed.startsWith('|') && nextTrimmed.endsWith('|'))) {
        break;
      }
      paraLines.add(next);
      i++;
    }
    blocks.add(ParagraphBlock(paraLines.join('\n')));
  }

  return blocks;
}

// ---------------------------------------------------------------------------
// Inline Spans Parser
// ---------------------------------------------------------------------------

List<InlineSpanNode> parseInlineSpans(String text) {
  final List<InlineSpanNode> nodes = [];
  if (text.isEmpty) return nodes;

  // Master inline regex matching links, code, bold-italic, bold, italic, strikethrough
  final pattern = RegExp(
    r'(\[(.*?)\]\((.*?)\))|(`{1,3}([^`]+)`{1,3})|(\*\*\*(.*?)\*\*\*)|(\*\*(.*?)\*\*)|(\*(.*?)\*)|(~~(.*?)~~)',
  );

  int lastIndex = 0;
  for (final match in pattern.allMatches(text)) {
    // Plain text before match
    if (match.start > lastIndex) {
      nodes.add(InlineSpanNode(text: text.substring(lastIndex, match.start)));
    }

    if (match.group(1) != null) {
      // Link: [title](url)
      final label = match.group(2) ?? '';
      final url = match.group(3) ?? '';
      nodes.add(InlineSpanNode(text: label, isLink: true, linkUrl: url));
    } else if (match.group(4) != null) {
      // Inline Code: `code`
      final codeContent = match.group(5) ?? '';
      nodes.add(InlineSpanNode(text: codeContent, isCode: true));
    } else if (match.group(6) != null) {
      // Bold Italic: ***text***
      final content = match.group(7) ?? '';
      nodes.add(InlineSpanNode(text: content, isBold: true, isItalic: true));
    } else if (match.group(8) != null) {
      // Bold: **text**
      final content = match.group(9) ?? '';
      nodes.add(InlineSpanNode(text: content, isBold: true));
    } else if (match.group(10) != null) {
      // Italic: *text*
      final content = match.group(11) ?? '';
      nodes.add(InlineSpanNode(text: content, isItalic: true));
    } else if (match.group(12) != null) {
      // Strikethrough: ~~text~~
      final content = match.group(13) ?? '';
      nodes.add(InlineSpanNode(text: content, isStrike: true));
    }

    lastIndex = match.end;
  }

  // Trailing plain text
  if (lastIndex < text.length) {
    nodes.add(InlineSpanNode(text: text.substring(lastIndex)));
  }

  return nodes;
}

// ---------------------------------------------------------------------------
// Sepia Markdown Widget Component
// ---------------------------------------------------------------------------

class SepiaMarkdownWidget extends StatelessWidget {
  final String markdown;
  final bool isUser;
  final TextStyle? baseStyle;

  const SepiaMarkdownWidget({
    super.key,
    String? markdown,
    String? markdownText,
    this.isUser = false,
    this.baseStyle,
  }) : markdown = markdown ?? markdownText ?? '';

  @override
  Widget build(BuildContext context) {
    if (markdown.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    final blocks = parseMarkdownBlocks(markdown);
    final defaultStyle = baseStyle ??
        SepiaTheme.sans(
          fontSize: 13,
          color: isUser ? SepiaTheme.ink : SepiaTheme.ink,
          height: 1.45,
        );

    return SelectionArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (int i = 0; i < blocks.length; i++) ...[
            _buildBlockWidget(context, blocks[i], defaultStyle),
            if (i < blocks.length - 1 && !_isCompactSpacing(blocks[i], blocks[i + 1]))
              const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }

  bool _isCompactSpacing(MarkdownBlock a, MarkdownBlock b) {
    // Keep list items closer together
    if (a is ListItemBlock && b is ListItemBlock) return true;
    return false;
  }

  Widget _buildBlockWidget(BuildContext context, MarkdownBlock block, TextStyle defaultStyle) {
    if (block is HeadingBlock) {
      return _buildHeading(block);
    } else if (block is CodeBlock) {
      return _CodeBlockWidget(language: block.language, code: block.code);
    } else if (block is BlockquoteBlock) {
      return _buildBlockquote(block, defaultStyle);
    } else if (block is ListItemBlock) {
      return _buildListItem(block, defaultStyle);
    } else if (block is DividerBlock) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 6),
        child: Divider(color: SepiaTheme.border, thickness: 1, height: 16),
      );
    } else if (block is TableBlock) {
      return _buildTable(block, defaultStyle);
    } else if (block is ParagraphBlock) {
      return _buildRichParagraph(block.text, defaultStyle);
    }
    return const SizedBox.shrink();
  }

  Widget _buildHeading(HeadingBlock block) {
    double size = 15;
    FontWeight weight = FontWeight.w700;
    Color color = SepiaTheme.ink;

    switch (block.level) {
      case 1:
        size = 19;
        break;
      case 2:
        size = 17;
        break;
      case 3:
        size = 15;
        break;
      case 4:
      default:
        size = 13.5;
        break;
    }

    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 2),
      child: Text(
        block.text,
        style: SepiaTheme.sans(
          fontSize: size,
          fontWeight: weight,
          color: color,
          height: 1.3,
        ),
      ),
    );
  }

  Widget _buildBlockquote(BlockquoteBlock block, TextStyle defaultStyle) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      decoration: BoxDecoration(
        color: SepiaTheme.amberBg.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(4),
        border: const Border(
          left: BorderSide(color: SepiaTheme.amber, width: 3),
        ),
      ),
      child: _buildRichParagraph(
        block.text,
        defaultStyle.copyWith(
          fontStyle: FontStyle.italic,
          color: SepiaTheme.inkSecondary,
        ),
      ),
    );
  }

  Widget _buildListItem(ListItemBlock block, TextStyle defaultStyle) {
    final indent = block.indentationLevel * 14.0;

    return Padding(
      padding: EdgeInsets.only(left: indent, top: 2, bottom: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (block.isOrdered) ...[
            SizedBox(
              width: 22,
              child: Text(
                block.number,
                style: SepiaTheme.mono(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: SepiaTheme.inkSecondary,
                ),
              ),
            ),
          ] else ...[
            Container(
              width: 5,
              height: 5,
              margin: const EdgeInsets.only(top: 6, right: 8, left: 4),
              decoration: const BoxDecoration(
                color: SepiaTheme.inkSecondary,
                shape: BoxShape.circle,
              ),
            ),
          ],
          Expanded(
            child: _buildRichParagraph(block.text, defaultStyle),
          ),
        ],
      ),
    );
  }

  Widget _buildTable(TableBlock block, TextStyle defaultStyle) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: SepiaTheme.paper,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: SepiaTheme.border),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Table(
          border: TableBorder.all(color: SepiaTheme.borderSubtle, width: 1),
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          children: [
            // Header
            TableRow(
              decoration: const BoxDecoration(color: SepiaTheme.paperSubtle),
              children: [
                for (final h in block.headers)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    child: Text(
                      h,
                      style: SepiaTheme.sans(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: SepiaTheme.ink,
                      ),
                    ),
                  ),
              ],
            ),
            // Data rows
            for (final row in block.rows)
              TableRow(
                children: [
                  for (final cell in row)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      child: _buildRichParagraph(cell, defaultStyle.copyWith(fontSize: 12)),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRichParagraph(String text, TextStyle baseStyle) {
    final spans = parseInlineSpans(text);

    return Text.rich(
      TextSpan(
        children: spans.map((node) {
          if (node.isCode) {
            return WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: SepiaTheme.paperSubtle,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: SepiaTheme.borderSubtle),
                ),
                child: Text(
                  node.text,
                  style: SepiaTheme.mono(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: SepiaTheme.ink,
                  ),
                ),
              ),
            );
          }

          TextStyle style = baseStyle;
          if (node.isBold && node.isItalic) {
            style = style.copyWith(fontWeight: FontWeight.w700, fontStyle: FontStyle.italic);
          } else if (node.isBold) {
            style = style.copyWith(fontWeight: FontWeight.w700);
          } else if (node.isItalic) {
            style = style.copyWith(fontStyle: FontStyle.italic);
          }

          if (node.isStrike) {
            style = style.copyWith(decoration: TextDecoration.lineThrough);
          }

          if (node.isLink) {
            style = style.copyWith(
              color: SepiaTheme.amber,
              decoration: TextDecoration.underline,
              fontWeight: FontWeight.w600,
            );
          }

          return TextSpan(text: node.text, style: style);
        }).toList(),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Fenced Code Block Widget with Copy Button & Feedback
// ---------------------------------------------------------------------------

class _CodeBlockWidget extends StatefulWidget {
  final String language;
  final String code;

  const _CodeBlockWidget({
    required this.language,
    required this.code,
  });

  @override
  State<_CodeBlockWidget> createState() => _CodeBlockWidgetState();
}

class _CodeBlockWidgetState extends State<_CodeBlockWidget> {
  bool _isCopied = false;
  Timer? _copyTimer;

  @override
  void dispose() {
    _copyTimer?.cancel();
    super.dispose();
  }

  void _copyToClipboard() async {
    await Clipboard.setData(ClipboardData(text: widget.code));
    if (mounted) {
      setState(() => _isCopied = true);
      _copyTimer?.cancel();
      _copyTimer = Timer(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() => _isCopied = false);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: SepiaTheme.canvas,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: SepiaTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Bar with Language Badge and Copy Button
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: const BoxDecoration(
              color: SepiaTheme.paperSubtle,
              borderRadius: BorderRadius.vertical(top: Radius.circular(5)),
              border: Border(bottom: BorderSide(color: SepiaTheme.borderSubtle)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.language.toUpperCase(),
                  style: SepiaTheme.mono(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    color: SepiaTheme.inkMuted,
                  ),
                ),
                InkWell(
                  onTap: _copyToClipboard,
                  borderRadius: BorderRadius.circular(4),
                  child: Tooltip(
                    message: 'Copy code to clipboard',
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _isCopied ? Icons.check_rounded : Icons.copy_rounded,
                            size: 13,
                            color: _isCopied ? SepiaTheme.sage : SepiaTheme.inkSecondary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _isCopied ? 'Copied!' : 'Copy',
                            style: SepiaTheme.mono(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: _isCopied ? SepiaTheme.sage : SepiaTheme.inkSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Code Content
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(12),
            child: SelectableText(
              widget.code,
              style: SepiaTheme.mono(
                fontSize: 12,
                color: SepiaTheme.ink,
                height: 1.42,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
