import 'package:flutter/material.dart';
import 'package:gpt_markdown/custom_widgets/code_field.dart';
import 'package:gpt_markdown/gpt_markdown.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';

/// Renders an assistant reply: GFM tables, code blocks with highlighting and a
/// copy button, and LaTeX math in `$…$` / `$$…$$` as remark-math does on the web.
class MarkdownView extends StatelessWidget {
  const MarkdownView(this.data, {super.key});

  final String data;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return GptMarkdown(
      data,
      style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: palette.text, height: 1.5),
      useDollarSignsForLatex: true,
      // Replies arrive whole (the backend sends one `final` event), so there
      // is nothing to reveal character by character.
      isStreaming: false,
      followLinkColor: true,
      codeBuilder: (context, language, code, closed) => _DarkCodeBlock(language: language, code: code),
    );
  }
}

/// Code blocks are always dark, in both themes, so the highlighter's dark
/// colors are used everywhere.
class _DarkCodeBlock extends StatelessWidget {
  const _DarkCodeBlock({required this.language, required this.code});

  final String language;
  final String code;

  static final _dark = buildTheme(Brightness.dark);

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Theme(
        data: _dark,
        child: CodeField(
          name: language,
          codes: code,
          scalesItsOwnText: true,
          style: CodeBlockStyle(
            backgroundColor: palette.codeBackground,
            textColor: palette.codeText,
            borderColor: palette.codeBackground,
          ).resolve(_dark.colorScheme),
        ),
      ),
    );
  }
}
