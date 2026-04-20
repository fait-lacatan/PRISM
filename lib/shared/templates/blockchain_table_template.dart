import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// S6: Blockchain consensus table with row hover, inline bars, finality badges.
class BlockchainTableTemplate extends StatelessWidget {
  final Map<String, dynamic> data;
  final Color accent;
  const BlockchainTableTemplate({super.key, required this.data, required this.accent});

  @override
  Widget build(BuildContext context) {
    final title = data['title'] ?? '';
    final subtitle = data['subtitle'] ?? '';
    final protocols = (data['protocols'] as List?) ?? [];

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

        // Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF0d1e30),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 500;
              return Row(
                children: [
                  Expanded(flex: 2, child: _headerText('Consensus')),
                  if (!isNarrow) Expanded(flex: 2, child: _headerText('Platform')),
                  Expanded(flex: 2, child: _headerText('Finality')),
                  Expanded(flex: 2, child: _headerText('Overhead')),
                  if (!isNarrow) Expanded(flex: 2, child: _headerText('Best for')),
                ],
              );
            },
          ),
        ),

        // Rows
        ...List.generate(protocols.length, (i) {
          final p = protocols[i] as Map<String, dynamic>;
          return _BlockchainRow(protocol: p, accent: accent, delay: i * 60);
        }),
      ],
    );
  }

  Widget _headerText(String text) {
    return Text(
      text.toUpperCase(),
      style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: accent, letterSpacing: 0.6),
    );
  }
}

class _BlockchainRow extends StatefulWidget {
  final Map<String, dynamic> protocol;
  final Color accent;
  final int delay;
  const _BlockchainRow({required this.protocol, required this.accent, required this.delay});

  @override
  State<_BlockchainRow> createState() => _BlockchainRowState();
}

class _BlockchainRowState extends State<_BlockchainRow> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final p = widget.protocol;
    final overhead = (p['overhead'] as num?)?.toDouble() ?? 0;
    final isDeterministic = p['finality'] == 'deterministic';
    final barColor = overhead >= 70 ? const Color(0xFFE97316) : (overhead >= 50 ? const Color(0xFFFBBF24) : widget.accent);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        color: _hovering ? const Color(0xFF0f1e30) : Colors.transparent,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 470;
            return Row(
              children: [
                // Name
                Expanded(
                  flex: 2,
                  child: Text(p['name'] ?? '', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
                ),
                // Platform (desktop only)
                if (!isNarrow)
                  Expanded(
                    flex: 2,
                    child: Text(p['platform'] ?? '', style: GoogleFonts.inter(fontSize: 11, color: Colors.white70)),
                  ),
                // Finality badge
                Expanded(
                  flex: 2,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isDeterministic ? widget.accent.withValues(alpha: 0.08) : const Color(0xFFFBBF24).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: isDeterministic ? widget.accent.withValues(alpha: 0.2) : const Color(0xFFFBBF24).withValues(alpha: 0.2)),
                      ),
                      child: Text(
                        isDeterministic ? 'Deterministic' : 'Probabilistic',
                        style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w700, color: isDeterministic ? widget.accent : const Color(0xFFFBBF24)),
                      ),
                    ),
                  ),
                ),
                // Overhead bar
                Expanded(
                  flex: 2,
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 5,
                          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(3)),
                          child: FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: (overhead / 100).clamp(0, 1),
                            child: Container(decoration: BoxDecoration(color: barColor, borderRadius: BorderRadius.circular(3))),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Best for (desktop only)
                if (!isNarrow)
                  Expanded(
                    flex: 2,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 10),
                      child: Text(p['best_for'] ?? '', style: GoogleFonts.inter(fontSize: 10, color: Colors.white54)),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    ).animate().fadeIn(delay: widget.delay.ms, duration: 300.ms);
  }
}
