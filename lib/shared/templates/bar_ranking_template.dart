import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Animated horizontal bar chart with scroll-triggered fill + side stat cards.
class BarRankingTemplate extends StatelessWidget {
  final Map<String, dynamic> data;
  final Color accent;

  const BarRankingTemplate({super.key, required this.data, required this.accent});

  @override
  Widget build(BuildContext context) {
    final title = data['title'] ?? '';
    final items = (data['items'] as List?) ?? [];
    final sideStats = (data['side_stats'] as List?) ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(title, style: GoogleFonts.spaceGrotesk(fontSize: 28, fontWeight: FontWeight.w700, color: Colors.white)),
        ],
        const SizedBox(height: 32),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: Column(
                children: List.generate(items.length, (i) {
                  final item = items[i];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF112035),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Text(item['flag'] ?? '', style: const TextStyle(fontSize: 24)),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              item['name'] ?? '',
                              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.white.withValues(alpha: 0.8)),
                            ),
                          ),
                          SizedBox(
                            width: 120,
                            height: 6,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(3),
                              child: TweenAnimationBuilder<double>(
                                tween: Tween(begin: 0, end: (item['percent'] as num?)?.toDouble() ?? 0),
                                duration: const Duration(milliseconds: 1200),
                                curve: Curves.easeOutCubic,
                                builder: (_, v, child) => LinearProgressIndicator(
                                  value: v,
                                  backgroundColor: Colors.white.withValues(alpha: 0.05),
                                  valueColor: AlwaysStoppedAnimation(accent),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ).animate().fadeIn(delay: (200 + i * 100).ms).slideX(begin: -0.04),
                  );
                }),
              ),
            ),
            if (sideStats.isNotEmpty) ...[
              const SizedBox(width: 48),
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: sideStats.map<Widget>((s) {
                    final isLarge = s['value'].toString().contains('%');
                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: const Color(0xFF112035),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s['value'] ?? '',
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: isLarge ? 36 : 24,
                              fontWeight: FontWeight.w700,
                              color: isLarge ? accent : Colors.white.withValues(alpha: 0.8),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            s['label'] ?? '',
                            style: GoogleFonts.inter(fontSize: 14, color: Colors.white.withValues(alpha: 0.4), height: 1.5),
                          ),
                        ],
                      ),
                    ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.08);
                  }).toList(),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

}
