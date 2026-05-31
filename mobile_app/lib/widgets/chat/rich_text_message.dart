import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:url_launcher/url_launcher.dart';

/// Enhanced message widget that supports rich text formatting including:
/// - **Bold text**
/// - *Italic text*
/// - `Code snippets`
/// - Bullet points
/// - Numbered lists
/// - Links
/// - Code blocks
class RichTextMessage extends StatelessWidget {
  final String content;
  final bool isUser;
  final TextStyle? baseStyle;

  const RichTextMessage({
    super.key,
    required this.content,
    required this.isUser,
    this.baseStyle,
  });

  @override
  Widget build(BuildContext context) {
    // For user messages, use simple text (they don't need markdown)
    if (isUser) {
      return Text(
        content,
        style: baseStyle ??
            const TextStyle(
              color: Colors.white,
              fontSize: 16,
              height: 1.4,
            ),
      );
    }

    // For AI messages, use markdown rendering
    return MarkdownBody(
      data: content,
      selectable: true,
      styleSheet: _buildMarkdownStyleSheet(context),
      onTapLink: _handleLinkTap,
      extensionSet: md.ExtensionSet(
        md.ExtensionSet.gitHubFlavored.blockSyntaxes,
        [
          md.EmojiSyntax(),
          ...md.ExtensionSet.gitHubFlavored.inlineSyntaxes,
        ],
      ),
    );
  }

  MarkdownStyleSheet _buildMarkdownStyleSheet(BuildContext context) {
    final baseColor = isUser ? Colors.white : Theme.of(context).colorScheme.onSurfaceVariant;
    final secondaryColor = isUser
        ? Colors.white.withValues(alpha: 0.8)
        : Theme.of(context).colorScheme.onSurfaceVariant;

    return MarkdownStyleSheet(
      // Paragraph text
      p: TextStyle(
        color: baseColor,
        fontSize: 16,
        height: 1.4,
        fontWeight: FontWeight.normal,
      ),

      // Headers
      h1: TextStyle(
        color: baseColor,
        fontSize: 24,
        fontWeight: FontWeight.bold,
        height: 1.3,
      ),
      h2: TextStyle(
        color: baseColor,
        fontSize: 22,
        fontWeight: FontWeight.bold,
        height: 1.3,
      ),
      h3: TextStyle(
        color: baseColor,
        fontSize: 20,
        fontWeight: FontWeight.bold,
        height: 1.3,
      ),
      h4: TextStyle(
        color: baseColor,
        fontSize: 18,
        fontWeight: FontWeight.bold,
        height: 1.3,
      ),
      h5: TextStyle(
        color: baseColor,
        fontSize: 16,
        fontWeight: FontWeight.bold,
        height: 1.3,
      ),
      h6: TextStyle(
        color: baseColor,
        fontSize: 14,
        fontWeight: FontWeight.bold,
        height: 1.3,
      ),

      // Emphasis
      strong: TextStyle(
        color: baseColor,
        fontWeight: FontWeight.bold,
      ),
      em: TextStyle(
        color: baseColor,
        fontStyle: FontStyle.italic,
      ),

      // Code
      code: TextStyle(
        color: isUser ? Colors.white : Theme.of(context).colorScheme.primary,
        backgroundColor: isUser
            ? Colors.white.withValues(alpha: 0.2)
            : Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
        fontFamily: 'monospace',
        fontSize: 14,
      ),
      codeblockDecoration: BoxDecoration(
        color: isUser
            ? Colors.white.withValues(alpha: 0.1)
            : Theme.of(context).colorScheme.surface.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isUser
              ? Colors.white.withValues(alpha: 0.3)
              : Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
        ),
      ),
      codeblockPadding: const EdgeInsets.all(12),

      // Lists
      listBullet: TextStyle(
        color: baseColor,
        fontSize: 16,
      ),
      listIndent: 24,

      // Links
      a: TextStyle(
        color: isUser ? Colors.white : Theme.of(context).colorScheme.primary,
        decoration: TextDecoration.underline,
        decorationColor: isUser ? Colors.white : Theme.of(context).colorScheme.primary,
      ),

      // Blockquotes
      blockquote: TextStyle(
        color: secondaryColor,
        fontStyle: FontStyle.italic,
      ),
      blockquoteDecoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: isUser
                ? Colors.white.withValues(alpha: 0.5)
                : Theme.of(context).colorScheme.primary,
            width: 4,
          ),
        ),
      ),
      blockquotePadding: const EdgeInsets.only(left: 16, top: 8, bottom: 8),

      // Tables
      tableHead: TextStyle(
        color: baseColor,
        fontWeight: FontWeight.bold,
      ),
      tableBody: TextStyle(
        color: baseColor,
      ),
      tableBorder: TableBorder.all(
        color: isUser
            ? Colors.white.withValues(alpha: 0.3)
            : Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
      ),
      tableCellsPadding: const EdgeInsets.all(8),

      // Horizontal rule
      horizontalRuleDecoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: isUser
                ? Colors.white.withValues(alpha: 0.3)
                : Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
      ),
    );
  }

  void _handleLinkTap(String text, String? href, String title) async {
    if (href != null) {
      final uri = Uri.tryParse(href);
      if (uri != null && await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }
  }
}
