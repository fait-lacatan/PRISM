import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// A hero stat section with a pulsing animated circle, insight card,
/// and mini-stat tiles. Responsive: stacks vertically on narrow screens.
class HeroStatTemplate extends StatefulWidget {
  final Map<String, dynamic> data;
  final Color accent;
  final bool isNarrow;

  const HeroStatTemplate({
    super.key,
    required this.data,
    required this.accent,
    this.isNarrow = false,
  });

  @override
  State<HeroStatTemplate> createState() => _HeroStatTemplateState();
}

class _HeroStatTemplateState extends State<HeroStatTemplate>
    with SingleTickerProviderStateMixin {
  int _counter = 0;
  Timer? _counterTimer;
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseAnim;

  Color get _accent => widget.accent;
  Map<String, dynamic> get _d => widget.data;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat();
    _pulseAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
    final target = (_d['stat_value'] as num?)?.toInt() ?? 0;
    _startCounter(target);
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _counterTimer?.cancel();
    super.dispose();
  }

  void _startCounter(int target) {
    int step = 0;
    const steps = 55;
    _counterTimer = Timer.periodic(const Duration(milliseconds: 25), (t) {
      step++;
      final ease = 1 - (1 - step / steps) * (1 - step / steps) * (1 - step / steps);
      setState(() => _counter = (ease * target).round());
      if (step >= steps) {
        t.cancel();
        setState(() => _counter = target);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final suffix = _d['stat_suffix'] ?? '';
    final topLabel = _d['stat_label_top'] ?? '';
    final bottomLabel = _d['stat_label_bottom'] ?? '';

    final miniStats = (_d['mini_stats'] as List?) ?? [];
    final insightText = _d['insight_text'] as String? ?? '';
    final isNarrow = widget.isNarrow;

    final heroCircle = _buildPulsingCircle(topLabel, suffix, bottomLabel, isNarrow);
    final detailColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (insightText.isNotEmpty)
          Container(
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFFB388FF).withValues(alpha: 0.4),
                width: 1.5,
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Text(
              insightText,
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.white.withValues(alpha: 0.8),
                height: 1.6,
              ),
            ),
          ),
        const SizedBox(height: 24),
        if (miniStats.isNotEmpty)
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              for (final ms in miniStats)
                SizedBox(
                  width: isNarrow ? double.infinity : null,
                  child: Container(
                    constraints: isNarrow ? null : const BoxConstraints(minWidth: 160),
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFFB388FF).withValues(alpha: 0.3),
                        width: 1.5,
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ms['value'] ?? '',
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            color: _accent,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          ms['label'] ?? '',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.34),
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
      ],
    );

    final hasDetails = insightText.isNotEmpty || miniStats.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isNarrow || !hasDetails) ...[
          Center(child: heroCircle),
          if (hasDetails) ...[
            const SizedBox(height: 32),
            detailColumn,
          ],
        ] else
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              heroCircle,
              const SizedBox(width: 56),
              Expanded(child: detailColumn),
            ],
          ),
      ],
    );
  }



  Widget _buildPulsingCircle(String topLabel, String suffix, String bottomLabel, bool isNarrow) {
    final circleSize = isNarrow ? 240.0 : 320.0;
    final innerSize = circleSize - 20;
    final fontSize = isNarrow ? 64.0 : 88.0;

    return AnimatedBuilder(
      animation: _pulseAnim,
      builder: (context, child) {
        final pulse = _pulseAnim.value;
        final glow = pulse < 0.5 ? pulse * 2 : (1 - pulse) * 2;
        return SizedBox(
          width: circleSize,
          height: circleSize,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Outer ring 1
              Container(
                width: circleSize + 24 * pulse,
                height: circleSize + 24 * pulse,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: _accent.withValues(alpha: 0.04 + 0.06 * (1 - pulse))),
                ),
              ),
              // Outer ring 2
              Container(
                width: circleSize + 10 * pulse,
                height: circleSize + 10 * pulse,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: _accent.withValues(alpha: 0.08 + 0.12 * glow), width: 1.5),
                ),
              ),
              // Main circle
              Container(
                width: innerSize,
                height: innerSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color.lerp(Colors.black, _accent, 0.14),
                  boxShadow: [
                    BoxShadow(color: _accent.withValues(alpha: 0.1 + 0.22 * glow), blurRadius: 32, spreadRadius: glow * 10),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(topLabel, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFFE97316).withValues(alpha: 0.8))),
                    Text(
                      '$_counter$suffix',
                      style: GoogleFonts.spaceGrotesk(fontSize: fontSize, fontWeight: FontWeight.w700, color: _accent, letterSpacing: -2, height: 1),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 8),
                      child: Text(bottomLabel, textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 12, color: Colors.white.withValues(alpha: 0.4), height: 1.45)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
