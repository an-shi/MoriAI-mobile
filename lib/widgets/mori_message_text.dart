import 'package:flutter/material.dart';
import 'package:mori_ai/ui/mori_theme.dart';

/// Renders the light markdown subset used by chat models: bold, italics,
/// inline code and fenced code blocks. It intentionally stays compact so that
/// streaming updates remain cheap.
class MoriMessageText extends StatelessWidget {
  const MoriMessageText({
    super.key,
    required this.text,
    required this.baseStyle,
    required this.isUser,
  });

  final String text;
  final TextStyle baseStyle;
  final bool isUser;

  static final _fencePattern = RegExp(
    r'```([a-zA-Z0-9_+\-#.]*)[ \t]*\r?\n?([\s\S]*?)```',
  );

  @override
  Widget build(BuildContext context) {
    final matches = _fencePattern.allMatches(text).toList(growable: false);
    if (matches.isEmpty) {
      return Text.rich(
        TextSpan(children: _inlineSpans(context), style: baseStyle),
        softWrap: true,
      );
    }

    final children = <Widget>[];
    var cursor = 0;
    for (final match in matches) {
      final before = text.substring(cursor, match.start).trimRight();
      if (before.trim().isNotEmpty) {
        children.add(
          Text.rich(
            TextSpan(
              children: _inlineSpans(context, text: before),
              style: baseStyle,
            ),
            softWrap: true,
          ),
        );
      }
      final language = match.group(1)?.trim() ?? '';
      final code = (match.group(2) ?? '').trimRight();
      children.add(_CodeBlock(language: language, code: code));
      cursor = match.end;
    }
    final after = text.substring(cursor).trimLeft();
    if (after.trim().isNotEmpty) {
      children.add(
        Text.rich(
          TextSpan(
            children: _inlineSpans(context, text: after),
            style: baseStyle,
          ),
          softWrap: true,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var index = 0; index < children.length; index++) ...[
          if (index > 0) const SizedBox(height: 8),
          children[index],
        ],
      ],
    );
  }

  List<InlineSpan> _inlineSpans(BuildContext context, {String? text}) {
    final source = text ?? this.text;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final spans = <InlineSpan>[];
    final pattern = RegExp(r'(\*\*[^*\n]+\*\*|`[^`\n]+`|~~[^~\n]+~~)');
    var index = 0;
    for (final match in pattern.allMatches(source)) {
      if (match.start > index) {
        spans.add(TextSpan(text: source.substring(index, match.start)));
      }
      final token = match.group(0)!;
      if (token.startsWith('**')) {
        spans.add(
          TextSpan(
            text: token.substring(2, token.length - 2),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        );
      } else if (token.startsWith('~~')) {
        spans.add(
          TextSpan(
            text: token.substring(2, token.length - 2),
            style: const TextStyle(decoration: TextDecoration.lineThrough),
          ),
        );
      } else {
        spans.add(
          TextSpan(
            text: token.substring(1, token.length - 1),
            style: TextStyle(
              fontFamily: 'monospace',
              fontFamilyFallback: const ['Consolas', 'Menlo', 'Courier New'],
              fontSize: (baseStyle.fontSize ?? 15) * 0.9,
              backgroundColor: (isUser ? colors.onPrimary : colors.onSurface)
                  .withValues(alpha: 0.07),
            ),
          ),
        );
      }
      index = match.end;
    }
    if (index < source.length) {
      spans.add(TextSpan(text: source.substring(index)));
    }
    return spans;
  }
}

class _CodeBlock extends StatelessWidget {
  const _CodeBlock({required this.language, required this.code});

  final String language;
  final String code;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final background = isDark
        ? const Color(0xFF0B110E)
        : const Color(0xFF18231E);
    final foreground = const Color(0xFFDCEFE6);
    final muted = const Color(0xFF93A89E);

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minWidth: 180),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(MoriRadius.small),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 7, 12, 6),
            child: Text(
              language.isEmpty ? '代码' : language,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                color: muted,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.3,
              ),
            ),
          ),
          Divider(height: 0.8, thickness: 0.8, color: Colors.white12),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 11),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Text(
                code,
                style: TextStyle(
                  color: foreground,
                  fontFamily: 'monospace',
                  fontFamilyFallback: const [
                    'Consolas',
                    'Menlo',
                    'Courier New',
                  ],
                  fontSize: 12.4,
                  height: 1.55,
                  letterSpacing: 0,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
