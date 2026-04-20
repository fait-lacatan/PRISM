import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Displays a real world map (SVG) with the East Asia & Pacific region
/// highlighted and the Philippines distinctly brighter.
/// No country name overlays — just clean region highlighting.
class RegionMapTemplate extends StatelessWidget {
  final Map<String, dynamic> data;
  final Color accent;

  const RegionMapTemplate({super.key, required this.data, required this.accent});

  @override
  Widget build(BuildContext context) {
    final title = data['title'] ?? '';
    final highlights = (data['highlights'] as List?) ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title.isNotEmpty) ...[
          Text(title, style: GoogleFonts.spaceGrotesk(fontSize: 28, fontWeight: FontWeight.w700, color: Colors.white)),
          const SizedBox(height: 24),
        ],
        // Map container
        LayoutBuilder(
          builder: (context, constraints) {
            final mapW = constraints.maxWidth;
            final mapH = (mapW * 0.52).clamp(260.0, 460.0);

            return Container(
              width: mapW,
              height: mapH,
              decoration: BoxDecoration(
                color: const Color(0xFF06080E),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Stack(
                  children: [
                    // Real SVG world map — alignment shifts right on narrow
                    // screens to keep Philippines centered in the visible area
                    Positioned.fill(
                      child: SvgPicture.asset(
                        'assets/images/world_map.svg',
                        fit: BoxFit.cover,
                        alignment: Alignment(
                          // Narrow (<400): 0.85 → Wide (>900): 0.45
                          (1.0 - ((mapW - 350) / 600).clamp(0.0, 1.0)) * 0.45 + 0.45,
                          0.0,
                        ),
                      ),
                    ),
                    // Depth gradient overlay
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              const Color(0xFF06080E).withValues(alpha: 0.25),
                              Colors.transparent,
                              const Color(0xFF06080E).withValues(alpha: 0.35),
                            ],
                            stops: const [0.0, 0.5, 1.0],
                          ),
                        ),
                      ),
                    ),
                    // Legend
                    Positioned(
                      bottom: 12,
                      left: 14,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.65),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(width: 10, height: 10, decoration: BoxDecoration(color: accent.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(3))),
                            const SizedBox(width: 6),
                            Text('East Asia & Pacific', style: GoogleFonts.inter(fontSize: 10, color: Colors.white54)),
                            const SizedBox(width: 12),
                            Container(width: 10, height: 10, decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(3))),
                            const SizedBox(width: 6),
                            Text('Philippines', style: GoogleFonts.inter(fontSize: 10, color: Colors.white54)),
                          ],
                        ),
                      ).animate().fadeIn(delay: 900.ms),
                    ),
                  ],
                ),
              ),
            ).animate().fadeIn(duration: 500.ms);
          },
        ),
        // Highlight stat cards — fully responsive
        if (highlights.isNotEmpty) ...[
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, constraints) {
              final availW = constraints.maxWidth;
              final cols = (availW / 220).floor().clamp(1, highlights.length);
              if (cols == 1) {
                return Column(
                  children: List.generate(highlights.length, (i) {
                    return Padding(
                      padding: EdgeInsets.only(top: i > 0 ? 12 : 0),
                      child: SizedBox(
                        width: availW,
                        child: _buildHighlightCard(highlights[i], i),
                      ),
                    );
                  }),
                );
              }
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: List.generate(highlights.length, (i) {
                  final cardW = (availW - 12 * (cols - 1)) / cols;
                  return SizedBox(
                    width: cardW,
                    child: _buildHighlightCard(highlights[i], i),
                  );
                }),
              );
            },
          ),
        ],
      ],
    );
  }

  Widget _buildHighlightCard(Map<String, dynamic> h, int i) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFB388FF).withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            h['value'] ?? '',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: (h['value'] ?? '').toString().contains('%') ? accent : Colors.white.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            h['label'] ?? '',
            style: GoogleFonts.inter(fontSize: 12, color: Colors.white.withValues(alpha: 0.4), height: 1.4),
          ),
        ],
      ),
    ).animate().fadeIn(delay: (700 + i * 130).ms).slideY(begin: 0.05);
  }
}
