import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// A 2×2 animated grid where tapping a card reveals a detail overlay.
class ComparisonGridTemplate extends StatefulWidget {
  final Map<String, dynamic> data;
  final Color accent;

  const ComparisonGridTemplate({super.key, required this.data, required this.accent});

  @override
  State<ComparisonGridTemplate> createState() => _ComparisonGridTemplateState();
}

class _ComparisonGridTemplateState extends State<ComparisonGridTemplate> {
  int? _expandedIndex;

  Color get _accent => widget.accent;
  Map<String, dynamic> get _d => widget.data;
  List get _items => (_d['items'] as List?) ?? [];

  static const Map<String, IconData> _iconMap = {
    'target': Icons.gps_fixed_rounded,
    'shield': Icons.shield_rounded,
    'science': Icons.science_rounded,
    'architecture': Icons.architecture_rounded,
    'lightbulb': Icons.lightbulb_rounded,
    'people': Icons.people_rounded,
    'school': Icons.school_rounded,
    'analytics': Icons.analytics_rounded,
    'lock': Icons.lock_rounded,
    'bug_report': Icons.bug_report_rounded,
    'storage': Icons.storage_rounded,
    'fingerprint': Icons.fingerprint_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final title = _d['title'] ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(title, style: GoogleFonts.spaceGrotesk(fontSize: 28, fontWeight: FontWeight.w700, color: Colors.white)),
        ],
        const SizedBox(height: 32),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 20,
            mainAxisSpacing: 20,
            childAspectRatio: 1.6,
          ),
          itemCount: _items.length,
          itemBuilder: (context, i) {
            final item = _items[i];
            final iconName = item['icon'] as String? ?? 'lightbulb';
            final icon = _iconMap[iconName] ?? Icons.info_outline;
            final isExpanded = _expandedIndex == i;

            return GestureDetector(
              onTap: () => setState(() => _expandedIndex = isExpanded ? null : i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutQuart,
                decoration: BoxDecoration(
                  color: isExpanded
                      ? _accent.withValues(alpha: 0.08)
                      : const Color(0xFF112035),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isExpanded
                        ? _accent.withValues(alpha: 0.3)
                        : Colors.white.withValues(alpha: 0.06),
                    width: isExpanded ? 1.5 : 1,
                  ),
                ),
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: _accent.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(icon, size: 22, color: _accent),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            item['title'] ?? '',
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        AnimatedRotation(
                          turns: isExpanded ? 0.5 : 0,
                          duration: const Duration(milliseconds: 250),
                          child: Icon(Icons.expand_more_rounded, size: 20, color: Colors.white38),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: AnimatedCrossFade(
                        duration: const Duration(milliseconds: 250),
                        crossFadeState: isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                        firstChild: Text(
                          item['desc'] ?? '',
                          style: GoogleFonts.inter(fontSize: 13, color: Colors.white.withValues(alpha: 0.5), height: 1.5),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        secondChild: Text(
                          item['detail'] ?? item['desc'] ?? '',
                          style: GoogleFonts.inter(fontSize: 14, color: Colors.white70, height: 1.6),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ).animate().fadeIn(delay: (100 + i * 100).ms).slideY(begin: 0.08);
          },
        ),
      ],
    );
  }

}
