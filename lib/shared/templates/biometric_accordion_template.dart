import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// S3: Biometric modalities with arc progress rings + accordion expand.
class BiometricAccordionTemplate extends StatefulWidget {
  final Map<String, dynamic> data;
  final Color accent;
  const BiometricAccordionTemplate({super.key, required this.data, required this.accent});

  @override
  State<BiometricAccordionTemplate> createState() => _BiometricAccordionTemplateState();
}

class _BiometricAccordionTemplateState extends State<BiometricAccordionTemplate> {
  int _expandedIndex = -1;

  static const Map<String, IconData> _iconMap = {
    'face': Icons.face_rounded,
    'fingerprint': Icons.fingerprint_rounded,
    'visibility': Icons.visibility_rounded,
    'mic': Icons.mic_rounded,
    'hearing': Icons.hearing_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    final title = d['title'] ?? '';
    final subtitle = d['subtitle'] ?? '';
    final modalities = (d['modalities'] as List?) ?? [];

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

        LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth;
            final cols = w >= 700 ? 5 : (w >= 500 ? 3 : 2);
            final spacing = 10.0;
            final cardW = (w - spacing * (cols - 1)) / cols;

            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: List.generate(modalities.length, (i) {
                final mod = modalities[i] as Map<String, dynamic>;
                final isExpanded = i == _expandedIndex;
                final accuracy = (mod['accuracy'] as num?)?.toDouble() ?? 0;
                final name = mod['name'] ?? '';
                final range = mod['range'] ?? '';
                final models = mod['models'] ?? '';
                final strength = mod['strength'] ?? '';
                final iconName = mod['icon'] as String? ?? 'face';
                final icon = _iconMap[iconName] ?? Icons.face_rounded;

                return SizedBox(
                  width: cardW,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => setState(() => _expandedIndex = isExpanded ? -1 : i),
                      borderRadius: BorderRadius.circular(16),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0f1e30),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isExpanded ? widget.accent : Colors.white.withValues(alpha: 0.06),
                            width: 1.5,
                          ),
                        ),
                        child: Column(
                          children: [
                            // Arc progress
                            SizedBox(
                              width: 64, height: 64,
                              child: CustomPaint(
                                painter: _ArcPainter(accuracy / 100, widget.accent),
                                child: Center(
                                  child: Icon(icon, size: 22, color: widget.accent),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(name, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
                            const SizedBox(height: 2),
                            Text(range, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: widget.accent)),
                            // Accordion detail
                            AnimatedCrossFade(
                              duration: const Duration(milliseconds: 250),
                              crossFadeState: isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                              firstChild: const SizedBox.shrink(),
                              secondChild: Padding(
                                padding: const EdgeInsets.only(top: 10),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(height: 1, color: Colors.white.withValues(alpha: 0.06)),
                                    const SizedBox(height: 8),
                                    Text('Models', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white70)),
                                    Text(models, style: GoogleFonts.inter(fontSize: 10, color: Colors.white54, height: 1.5)),
                                    const SizedBox(height: 6),
                                    Text('Strength', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white70)),
                                    Text(strength, style: GoogleFonts.inter(fontSize: 10, color: Colors.white54, height: 1.5)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ).animate().fadeIn(delay: (i * 70).ms, duration: 350.ms).slideY(begin: 0.06);
              }),
            );
          },
        ),
      ],
    );
  }
}

class _ArcPainter extends CustomPainter {
  final double progress; // 0.0 – 1.0
  final Color color;
  _ArcPainter(this.progress, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 4;

    // Background ring
    canvas.drawCircle(center, radius, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..color = Colors.white.withValues(alpha: 0.06));

    // Progress arc
    final rect = Rect.fromCircle(center: center, radius: radius);
    canvas.drawArc(rect, -math.pi / 2, 2 * math.pi * progress, false, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..color = color);
  }

  @override
  bool shouldRepaint(_ArcPainter old) => old.progress != progress || old.color != color;
}
