import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// S2: Solution mapping matrix — row-based layout with hover highlighting.
class SolutionMatrixTemplate extends StatelessWidget {
  final Map<String, dynamic> data;
  final Color accent;
  const SolutionMatrixTemplate({super.key, required this.data, required this.accent});

  @override
  Widget build(BuildContext context) {
    final title = data['title'] ?? '';
    final subtitle = data['subtitle'] ?? '';
    final attacks = (data['attacks'] as List?) ?? [];
    final solutions = (data['solutions'] as List?) ?? [];
    final matrix = (data['matrix'] as List?) ?? [];

    const bioColor = Color(0xFF7C3AED);
    const chainColor = Color(0xFFA78BFA);

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

        // Header row
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF0d1e30),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
          ),
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: Text('CHEATING METHOD', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white54, letterSpacing: 0.8)),
              ),
              ...List.generate(solutions.length, (i) {
                final sol = solutions[i] as Map<String, dynamic>;
                final isBio = sol['color'] == 'bio';
                return Expanded(
                  flex: 2,
                  child: Text(
                    (sol['label'] ?? '').toString().toUpperCase(),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: isBio ? bioColor : chainColor, letterSpacing: 0.6),
                  ),
                );
              }),
            ],
          ),
        ),

        // Data rows with hover
        ...List.generate(attacks.length, (rowIdx) {
          final row = rowIdx < matrix.length ? (matrix[rowIdx] as List) : [];
          return _HoverRow(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.04))),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Text(attacks[rowIdx].toString(), style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
                  ),
                  ...List.generate(solutions.length, (colIdx) {
                    final isChecked = colIdx < row.length && row[colIdx] == true;
                    final sol = solutions[colIdx] as Map<String, dynamic>;
                    final isBio = sol['color'] == 'bio';
                    return Expanded(
                      flex: 2,
                      child: Center(
                        child: isChecked
                            ? Container(
                                width: 26, height: 26,
                                decoration: BoxDecoration(shape: BoxShape.circle, color: isBio ? bioColor : chainColor),
                                child: const Icon(Icons.check_rounded, size: 14, color: Color(0xFF0a1422)),
                              )
                            : Container(
                                width: 26, height: 26,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white.withValues(alpha: 0.03),
                                  border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                                ),
                              ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ).animate().fadeIn(delay: (rowIdx * 60).ms, duration: 300.ms);
        }),
      ],
    );
  }
}

/// Row with hover highlight effect.
class _HoverRow extends StatefulWidget {
  final Widget child;
  const _HoverRow({required this.child});

  @override
  State<_HoverRow> createState() => _HoverRowState();
}

class _HoverRowState extends State<_HoverRow> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        color: _hovering ? const Color(0xFF0f1e30) : Colors.transparent,
        child: widget.child,
      ),
    );
  }
}
