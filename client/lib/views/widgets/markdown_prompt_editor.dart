import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/sepia_theme.dart';
import 'sepia_markdown_widget.dart';

class MarkdownPromptEditor extends StatefulWidget {
  final TextEditingController controller;
  final VoidCallback onSubmit;
  final bool isGenerating;
  final int estimatedTokens;
  final String hintText;
  final FocusNode? focusNode;

  const MarkdownPromptEditor({
    super.key,
    required this.controller,
    required this.onSubmit,
    this.isGenerating = false,
    this.estimatedTokens = 0,
    this.hintText = 'Type prompt... (markdown supported: **bold**, `code`, ```blocks```, lists)',
    this.focusNode,
  });

  @override
  State<MarkdownPromptEditor> createState() => _MarkdownPromptEditorState();
}

class _MarkdownPromptEditorState extends State<MarkdownPromptEditor> {
  bool _isPreviewMode = false;
  late final FocusNode _internalFocusNode;

  @override
  void initState() {
    super.initState();
    _internalFocusNode = widget.focusNode ?? FocusNode();
  }

  @override
  void dispose() {
    if (widget.focusNode == null) {
      _internalFocusNode.dispose();
    }
    super.dispose();
  }

  void _wrapSelection(String prefix, [String? suffix]) {
    final s = suffix ?? prefix;
    final text = widget.controller.text;
    final selection = widget.controller.selection;

    if (!selection.isValid || selection.isCollapsed) {
      final insertPos = selection.isValid ? selection.baseOffset : text.length;
      final newText = text.substring(0, insertPos) + prefix + s + text.substring(insertPos);
      widget.controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: insertPos + prefix.length),
      );
    } else {
      final selectedText = text.substring(selection.start, selection.end);
      final newText = text.substring(0, selection.start) + prefix + selectedText + s + text.substring(selection.end);
      widget.controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection(
          baseOffset: selection.start + prefix.length,
          extentOffset: selection.end + prefix.length,
        ),
      );
    }
    _internalFocusNode.requestFocus();
  }

  void _insertLinePrefix(String prefix) {
    final text = widget.controller.text;
    final selection = widget.controller.selection;
    final pos = selection.isValid ? selection.baseOffset : text.length;

    // Find the beginning of the current line
    final lineStart = text.lastIndexOf('\n', pos > 0 ? pos - 1 : 0);
    final insertPos = lineStart == -1 ? 0 : lineStart + 1;

    final newText = text.substring(0, insertPos) + prefix + text.substring(insertPos);
    widget.controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: pos + prefix.length),
    );
    _internalFocusNode.requestFocus();
  }

  void _insertBlock(String block) {
    final text = widget.controller.text;
    final selection = widget.controller.selection;
    final pos = selection.isValid ? selection.baseOffset : text.length;

    final prefix = (pos > 0 && !text.endsWith('\n')) ? '\n' : '';
    final newText = text.substring(0, pos) + prefix + block + text.substring(pos);
    widget.controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: pos + prefix.length + block.length),
    );
    _internalFocusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyB, meta: true): () => _wrapSelection('**'),
        const SingleActivator(LogicalKeyboardKey.keyB, control: true): () => _wrapSelection('**'),
        const SingleActivator(LogicalKeyboardKey.keyI, meta: true): () => _wrapSelection('*'),
        const SingleActivator(LogicalKeyboardKey.keyI, control: true): () => _wrapSelection('*'),
        const SingleActivator(LogicalKeyboardKey.keyK, meta: true): () => _wrapSelection('`'),
        const SingleActivator(LogicalKeyboardKey.keyK, control: true): () => _wrapSelection('`'),
      },
      child: Container(
        decoration: BoxDecoration(
          color: SepiaTheme.paper,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: SepiaTheme.border),
          boxShadow: [
            BoxShadow(
              color: SepiaTheme.ink.withValues(alpha: 0.03),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Toolbar Header with Write/Preview Switch and Formatting Buttons
            _buildToolbar(),

            // Editor / Preview Body
            if (_isPreviewMode)
              _buildPreviewArea()
            else
              _buildInputArea(),

            // Footer with Token counter & Send Button
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildToolbar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: const BoxDecoration(
        color: SepiaTheme.paperSubtle,
        borderRadius: BorderRadius.vertical(top: Radius.circular(7)),
        border: Border(bottom: BorderSide(color: SepiaTheme.borderSubtle)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            // Write Tab
            InkWell(
              onTap: () => setState(() => _isPreviewMode = false),
              borderRadius: BorderRadius.circular(4),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: !_isPreviewMode ? SepiaTheme.canvas : Colors.transparent,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: !_isPreviewMode ? SepiaTheme.border : Colors.transparent,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.edit_note_rounded,
                      size: 14,
                      color: !_isPreviewMode ? SepiaTheme.ink : SepiaTheme.inkMuted,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Write',
                      style: SepiaTheme.mono(
                        fontSize: 10,
                        fontWeight: !_isPreviewMode ? FontWeight.w700 : FontWeight.w500,
                        color: !_isPreviewMode ? SepiaTheme.ink : SepiaTheme.inkMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 4),

            // Preview Tab
            InkWell(
              onTap: () => setState(() => _isPreviewMode = true),
              borderRadius: BorderRadius.circular(4),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _isPreviewMode ? SepiaTheme.canvas : Colors.transparent,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: _isPreviewMode ? SepiaTheme.border : Colors.transparent,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.visibility_outlined,
                      size: 13,
                      color: _isPreviewMode ? SepiaTheme.amber : SepiaTheme.inkMuted,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Preview',
                      style: SepiaTheme.mono(
                        fontSize: 10,
                        fontWeight: _isPreviewMode ? FontWeight.w700 : FontWeight.w500,
                        color: _isPreviewMode ? SepiaTheme.amber : SepiaTheme.inkMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(width: 8),
            Container(height: 14, width: 1, color: SepiaTheme.border),
            const SizedBox(width: 8),

            // Formatting Actions
            _buildFormatButton(
              icon: Icons.format_bold_rounded,
              tooltip: 'Bold (**text**)',
              onTap: () => _wrapSelection('**'),
            ),
            _buildFormatButton(
              icon: Icons.format_italic_rounded,
              tooltip: 'Italic (*text*)',
              onTap: () => _wrapSelection('*'),
            ),
            _buildFormatButton(
              icon: Icons.title_rounded,
              tooltip: 'Heading (### text)',
              onTap: () => _insertLinePrefix('### '),
            ),
            _buildFormatButton(
              icon: Icons.code_rounded,
              tooltip: 'Inline Code (`text`)',
              onTap: () => _wrapSelection('`'),
            ),
            _buildFormatButton(
              icon: Icons.integration_instructions_outlined,
              tooltip: 'Code Block (```text```)',
              onTap: () => _wrapSelection('```\n', '\n```'),
            ),
            _buildFormatButton(
              icon: Icons.format_list_bulleted_rounded,
              tooltip: 'Bulleted List (- item)',
              onTap: () => _insertLinePrefix('- '),
            ),
            _buildFormatButton(
              icon: Icons.format_list_numbered_rounded,
              tooltip: 'Numbered List (1. item)',
              onTap: () => _insertLinePrefix('1. '),
            ),
            _buildFormatButton(
              icon: Icons.format_quote_rounded,
              tooltip: 'Blockquote (> text)',
              onTap: () => _insertLinePrefix('> '),
            ),
            _buildFormatButton(
              icon: Icons.link_rounded,
              tooltip: 'Hyperlink ([title](url))',
              onTap: () => _wrapSelection('[', '](url)'),
            ),
            _buildFormatButton(
              icon: Icons.horizontal_rule_rounded,
              tooltip: 'Horizontal Rule (---)',
              onTap: () => _insertBlock('\n---\n'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormatButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: _isPreviewMode ? null : onTap,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
          child: Icon(
            icon,
            size: 15,
            color: _isPreviewMode ? SepiaTheme.inkMuted.withValues(alpha: 0.4) : SepiaTheme.inkSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildInputArea() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: TextField(
        controller: widget.controller,
        focusNode: _internalFocusNode,
        maxLines: 5,
        minLines: 2,
        style: SepiaTheme.sans(fontSize: 13.5, color: SepiaTheme.ink),
        decoration: InputDecoration(
          isDense: true,
          contentPadding: EdgeInsets.zero,
          hintText: widget.hintText,
          hintStyle: SepiaTheme.sans(fontSize: 13, color: SepiaTheme.inkMuted),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
        ),
      ),
    );
  }

  Widget _buildPreviewArea() {
    final text = widget.controller.text.trim();
    return Container(
      constraints: const BoxConstraints(minHeight: 60, maxHeight: 220),
      padding: const EdgeInsets.all(12),
      child: SingleChildScrollView(
        child: text.isEmpty
            ? Text(
                'Markdown preview will appear here as you type...',
                style: SepiaTheme.sans(
                  fontSize: 12,
                  color: SepiaTheme.inkMuted,
                ).copyWith(fontStyle: FontStyle.italic),
              )
            : SepiaMarkdownWidget(markdown: text),
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 4, 8, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Tokens indicator
          if (widget.estimatedTokens > 0)
            Text(
              '~${widget.estimatedTokens} toks',
              style: SepiaTheme.mono(fontSize: 10, color: SepiaTheme.inkMuted),
            )
          else
            Text(
              'Markdown enabled',
              style: SepiaTheme.mono(fontSize: 9.5, color: SepiaTheme.inkMuted),
            ),

          // Send Button
          ElevatedButton.icon(
            onPressed: widget.isGenerating ? null : widget.onSubmit,
            icon: widget.isGenerating
                ? const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(strokeWidth: 2, color: SepiaTheme.canvas),
                  )
                : const Icon(Icons.send_rounded, size: 14),
            label: Text(
              'Send',
              style: SepiaTheme.mono(fontSize: 11, fontWeight: FontWeight.w700),
            ),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              minimumSize: const Size(0, 32),
            ),
          ),
        ],
      ),
    );
  }
}
