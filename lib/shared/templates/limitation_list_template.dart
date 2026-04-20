import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// S7: Staggered numbered limitation list.
class LimitationListTemplate extends StatelessWidget {
  final Map<String, dynamic> data;
  final Color accent;
  const LimitationListTemplate({super.key, required this.data, required this.accent});

  static const _orange = Color(0xFFE97316);

  @override
  Widget build(BuildContext context) {
    final title = data['title'] ?? '';
    final subtitle = data['subtitle'] ?? '';
    final items = (data['items'] as List?) ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title.isNotEmpty) ...[
          Text(title, style: GoogleFonts.spaceGrotesk(fontSize: 28, fontWeight: FontWeight.w700, color: Colors.white)),
          if (subtitle.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(subtitle, style: GoogleFonts.inter(fontSize: 14, color: Colors.white38)),
          ],
          const SizedBox(height: 24),
        ],

        ...List.generate(items.length, (i) {
          final item = items[i] as Map<String, dynamic>;
          return Padding(
            padding: EdgeInsets.only(bottom: i < items.length - 1 ? 10 : 0),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _orange.withValues(alpha: 0.4),
                  width: 1.5,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 28, height: 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _orange.withValues(alpha: 0.08),
                      border: Border.all(color: _orange.withValues(alpha: 0.2), width: 1.5),
                    ),
                    child: Center(
                      child: Text(
                        '${i + 1}',
                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: _orange),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item['title'] ?? '',
                          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item['description'] ?? '',
                          style: GoogleFonts.inter(fontSize: 12, color: Colors.white54, height: 1.5),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(delay: (80 + i * 110).ms, duration: 400.ms).slideY(begin: 0.06),
          );
        }),
      ],
    );
  }
}
