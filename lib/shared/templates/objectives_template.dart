import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Objectives template — hero general-objective card with keyword popovers,
/// gradient connector, and numbered accordion cards for specific objectives.
class ObjectivesTemplate extends StatefulWidget {
  final Map<String, dynamic> data;
  final Color accent;
  const ObjectivesTemplate({super.key, required this.data, required this.accent});

  @override
  State<ObjectivesTemplate> createState() => _ObjectivesTemplateState();
}

class _ObjectivesTemplateState extends State<ObjectivesTemplate> {
  int _openObjIdx = -1;

  static const _orange = Color(0xFFE97316);
  static const _blue = Color(0xFF38BDF8);

  Map<String, dynamic> get _d => widget.data;
  Map<String, dynamic> get _general => (_d['general'] as Map<String, dynamic>?) ?? {};
  List get _specific => (_d['specific'] as List?) ?? [];

  @override
  Widget build(BuildContext context) {
    final title = _d['title'] ?? '';
    final connLabel = _d['connector_label'] ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title.isNotEmpty) ...[
          Text(title, style: GoogleFonts.spaceGrotesk(fontSize: 28, fontWeight: FontWeight.w700, color: Colors.white)),
          const SizedBox(height: 28),
        ],

        // ① General objective hero card
        _buildGeneralCard().animate().fadeIn(duration: 400.ms).slideY(begin: 0.05),
        const SizedBox(height: 18),

        // ② Connector line
        _buildConnector(connLabel).animate().fadeIn(delay: 200.ms, duration: 400.ms),
        const SizedBox(height: 14),

        // Label
        Text('SPECIFIC OBJECTIVES',
            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: _orange, letterSpacing: 1.0))
            .animate().fadeIn(delay: 300.ms, duration: 400.ms),
        const SizedBox(height: 12),

        // ③ Numbered accordion cards
        ...List.generate(_specific.length, (i) {
          final obj = _specific[i] as Map<String, dynamic>;
          return Padding(
            padding: const EdgeInsets.only(bottom: 9),
            child: _buildObjCard(obj, i),
          );
        }),
      ],
    );
  }

  // ─── General objective card ──────────────────────────
  Widget _buildGeneralCard() {
    final rawText = _general['text'] as String? ?? '';
    // Strip out the custom `{key|display}` markup to extract just the display text
    final cleanText = rawText.replaceAllMapped(
      RegExp(r'\{(\w+)\|([^}]+)\}'),
      (match) => match.group(2)!,
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF0f2030),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _blue.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('GENERAL OBJECTIVE',
              style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: _blue, letterSpacing: 1.0)),
          const SizedBox(height: 12),
          Text(
            cleanText,
            style: GoogleFonts.inter(
              fontSize: 15,
              color: Colors.white.withValues(alpha: 0.85),
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Connector ───────────────────────────────────────
  Widget _buildConnector(String label) {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [Colors.transparent, _blue.withValues(alpha: 0.25), Colors.transparent]),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text(label, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: _blue.withValues(alpha: 0.35), letterSpacing: 0.8)),
        ),
        Expanded(
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [Colors.transparent, _blue.withValues(alpha: 0.25), Colors.transparent]),
            ),
          ),
        ),
      ],
    );
  }

  // ─── Specific objective accordion card ───────────────
  Widget _buildObjCard(Map<String, dynamic> obj, int index) {
    final isOpen = _openObjIdx == index;
    final tags = (obj['tags'] as List?)?.cast<String>() ?? [];
    final iconName = obj['icon'] as String? ?? 'flag';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => setState(() => _openObjIdx = isOpen ? -1 : index),
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: isOpen ? const Color(0xFF140e04) : const Color(0xFF0f1e30),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isOpen ? _orange : Colors.white.withValues(alpha: 0.06),
              width: 1.5,
            ),
          ),
          child: Column(
            children: [
              // Top row: number badge + icon + title + chevron
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    // Number badge
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 28, height: 28,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isOpen ? _orange : _orange.withValues(alpha: 0.1),
                        border: Border.all(color: isOpen ? _orange : _orange.withValues(alpha: 0.25)),
                      ),
                      child: Center(
                        child: Text(
                          '${index + 1}',
                          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: isOpen ? const Color(0xFF070e1a) : _orange),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Icon
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 32, height: 32,
                      decoration: BoxDecoration(
                        color: isOpen ? const Color(0xFF1a1008) : const Color(0xFF152a40),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Icon(_resolveIcon(iconName), size: 16, color: _blue),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Title
                    Expanded(
                      child: Text(
                        obj['short'] ?? '',
                        style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white, height: 1.3),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Chevron
                    AnimatedRotation(
                      duration: const Duration(milliseconds: 300),
                      turns: isOpen ? 0.5 : 0,
                      child: Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: isOpen ? _orange : Colors.white24),
                    ),
                  ],
                ),
              ),

              // Detail panel
              AnimatedSize(
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeOutCubic,
                alignment: Alignment.topCenter,
                child: isOpen
                    ? Container(
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(54, 0, 14, 14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.only(top: 11),
                              decoration: BoxDecoration(border: Border(top: BorderSide(color: _orange.withValues(alpha: 0.12)))),
                              child: Text(
                                obj['detail'] ?? '',
                                style: GoogleFonts.inter(fontSize: 14, color: Colors.white.withValues(alpha: 0.65), height: 1.6),
                              ),
                            ),
                            if (tags.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 5,
                                runSpacing: 5,
                                children: tags.map((tag) {
                                  return Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF0f1e30),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                                    ),
                                    child: Text(tag, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white.withValues(alpha: 0.3))),
                                  );
                                }).toList(),
                              ),
                            ],
                          ],
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(delay: (400 + index * 120).ms, duration: 400.ms).slideX(begin: -0.04);
  }

  IconData _resolveIcon(String name) {
    switch (name) {
      case 'fingerprint': return Icons.fingerprint_rounded;
      case 'lock_outline': return Icons.lock_outline_rounded;
      case 'schedule': return Icons.schedule_rounded;
      case 'monitor_heart': return Icons.monitor_heart_outlined;
      case 'flag': return Icons.flag_rounded;
      default: return Icons.circle_outlined;
    }
  }
}
