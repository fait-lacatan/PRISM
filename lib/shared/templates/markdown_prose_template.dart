import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

/// Renders long-form markdown content with pull-quotes and styled typography.
/// For chapters like Results, Theories, Design that need prose.
class MarkdownProseTemplate extends StatelessWidget {
  final Map<String, dynamic> data;
  final Color accent;

  const MarkdownProseTemplate({super.key, required this.data, required this.accent});

  @override
  Widget build(BuildContext context) {
    final title = data['title'] ?? '';
    final content = data['content'] ?? '';
    final pullQuote = data['pull_quote'] as String?;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(title, style: GoogleFonts.spaceGrotesk(fontSize: 28, fontWeight: FontWeight.w700, color: Colors.white)),
        ],
        if (pullQuote != null) ...[
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.06),
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
              border: Border(left: BorderSide(color: accent, width: 4)),
            ),
            child: Text(
              pullQuote,
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                fontStyle: FontStyle.italic,
                color: Colors.white70,
                height: 1.6,
              ),
            ),
          ),
        ],
        const SizedBox(height: 32),
        MarkdownBody(
          data: content,
          selectable: true,
          styleSheet: MarkdownStyleSheet(
            p: GoogleFonts.inter(fontSize: 16, color: Colors.white70, height: 1.7),
            h1: GoogleFonts.spaceGrotesk(fontSize: 28, color: Colors.white, fontWeight: FontWeight.w700),
            h1Padding: const EdgeInsets.only(top: 48, bottom: 16),
            h2: GoogleFonts.spaceGrotesk(fontSize: 22, color: Colors.white, fontWeight: FontWeight.w700),
            h2Padding: const EdgeInsets.only(top: 40, bottom: 12),
            h3: GoogleFonts.spaceGrotesk(fontSize: 18, color: Colors.white, fontWeight: FontWeight.w600),
            h3Padding: const EdgeInsets.only(top: 32, bottom: 8),
            pPadding: const EdgeInsets.only(bottom: 16),
            listBullet: TextStyle(color: accent),
            blockquote: GoogleFonts.inter(fontSize: 16, fontStyle: FontStyle.italic, color: Colors.white54),
            blockquoteDecoration: BoxDecoration(
              border: Border(left: BorderSide(color: accent, width: 4)),
            ),
            blockquotePadding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
            code: GoogleFonts.firaCode(fontSize: 14, color: accent, backgroundColor: const Color(0xFF18181B)),
            codeblockDecoration: BoxDecoration(
              color: const Color(0xFF18181B),
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ],
    );
  }

}
