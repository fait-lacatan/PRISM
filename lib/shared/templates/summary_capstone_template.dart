import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Capstone template for Summary, Conclusions & Recommendations.
///
/// Renders three visually distinct sections in a single scroll:
///   1. Findings — bento card grid with SO badges + metric chips
///   2. Conclusions — M3 verdict table
///   3. Recommendations — card grid with priority badges + direction lists
class SummaryCapstoneTemplate extends StatelessWidget {
  final Map<String, dynamic> data;
  final Color accent;

  const SummaryCapstoneTemplate({
    super.key,
    required this.data,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final findings = (data['findings'] as List?) ?? [];
    final conclusions = (data['conclusions'] as List?) ?? [];
    final recommendations = (data['recommendations'] as List?) ?? [];

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 900;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Section 1: Summary of Findings ──
            _SectionHeader(
              title: 'Summary of Findings',
              icon: Icons.auto_awesome_rounded,
              accent: accent,
            ),
            const SizedBox(height: 24),
            _FindingsGrid(
              findings: findings,
              accent: accent,
              isNarrow: isNarrow,
            ),

            const SizedBox(height: 64),

            // ── Section 2: Conclusions ──
            _SectionHeader(
              title: 'Conclusions',
              icon: Icons.gavel_rounded,
              accent: accent,
            ),
            const SizedBox(height: 24),
            _ConclusionsTable(
              conclusions: conclusions,
              accent: accent,
            ),

            const SizedBox(height: 64),

            // ── Section 3: Recommendations ──
            _SectionHeader(
              title: 'Recommendations',
              icon: Icons.rocket_launch_rounded,
              accent: accent,
            ),
            const SizedBox(height: 24),
            _RecommendationsGrid(
              recommendations: recommendations,
              accent: accent,
              isNarrow: isNarrow,
            ),
          ],
        );
      },
    );
  }
}

// ─── Section Header ──────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color accent;

  const _SectionHeader({
    required this.title,
    required this.icon,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, size: 22, color: accent),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ],
    ).animate().fadeIn(duration: 400.ms);
  }
}

// ─── Findings Bento Grid ─────────────────────────────────────────────────────

class _FindingsGrid extends StatelessWidget {
  final List findings;
  final Color accent;
  final bool isNarrow;

  const _FindingsGrid({
    required this.findings,
    required this.accent,
    required this.isNarrow,
  });

  static const Map<String, Color> _soBadgeColors = {
    'SO1': Color(0xFF7C3AED),
    'SO2': Color(0xFF3B82F6),
    'SO3': Color(0xFF06B6D4),
    'SO4': Color(0xFF10B981),
    'H₀': Color(0xFFE97316),
  };

  @override
  Widget build(BuildContext context) {
    if (isNarrow) {
      return Column(
        children: [
          for (int i = 0; i < findings.length; i++) ...[
            _FindingCard(
              finding: findings[i] as Map<String, dynamic>,
              accent: accent,
              badgeColors: _soBadgeColors,
              index: i,
            ),
            if (i < findings.length - 1) const SizedBox(height: 12),
          ],
        ],
      );
    }

    // 2-column grid for wide screens
    final rows = <Widget>[];
    for (int i = 0; i < findings.length; i += 2) {
      rows.add(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _FindingCard(
                  finding: findings[i] as Map<String, dynamic>,
                  accent: accent,
                  badgeColors: _soBadgeColors,
                  index: i,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: i + 1 < findings.length
                    ? _FindingCard(
                        finding: findings[i + 1] as Map<String, dynamic>,
                        accent: accent,
                        badgeColors: _soBadgeColors,
                        index: i + 1,
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      );
      if (i + 2 < findings.length) {
        rows.add(const SizedBox(height: 12));
      }
    }

    return Column(children: rows);
  }
}

class _FindingCard extends StatefulWidget {
  final Map<String, dynamic> finding;
  final Color accent;
  final Map<String, Color> badgeColors;
  final int index;

  const _FindingCard({
    required this.finding,
    required this.accent,
    required this.badgeColors,
    required this.index,
  });

  @override
  State<_FindingCard> createState() => _FindingCardState();
}

class _FindingCardState extends State<_FindingCard> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final so = widget.finding['so'] as String? ?? '';
    final text = widget.finding['text'] as String? ?? '';
    final metric = widget.finding['metric'] as String? ?? '';
    final badgeColor = widget.badgeColors[so] ?? widget.accent;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: _hovering
              ? const Color(0xFF1A1A2E)
              : const Color(0xFF141418),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _hovering
                ? badgeColor.withValues(alpha: 0.25)
                : Colors.white.withValues(alpha: 0.06),
          ),
          boxShadow: _hovering
              ? [BoxShadow(color: badgeColor.withValues(alpha: 0.08), blurRadius: 24, offset: const Offset(0, 8))]
              : [],
        ),
        transform: _hovering
            ? Matrix4.translationValues(0.0, -2.0, 0.0)
            : Matrix4.identity(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // SO badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: badgeColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                so,
                style: GoogleFonts.firaCode(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: badgeColor,
                ),
              ),
            ),
            const SizedBox(height: 14),
            // Finding text
            Text(
              text,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: Colors.white.withValues(alpha: 0.8),
                height: 1.6,
              ),
            ),
            if (metric.isNotEmpty) ...[
              const SizedBox(height: 14),
              // Metric chip
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: badgeColor.withValues(alpha: 0.12)),
                ),
                child: Text(
                  metric,
                  style: GoogleFonts.firaCode(
                    fontSize: 12,
                    color: badgeColor.withValues(alpha: 0.9),
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    ).animate().fadeIn(delay: (widget.index * 60).ms, duration: 350.ms);
  }
}

// ─── Conclusions Table ───────────────────────────────────────────────────────

class _ConclusionsTable extends StatelessWidget {
  final List conclusions;
  final Color accent;

  const _ConclusionsTable({
    required this.conclusions,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF141418),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.08),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 80,
                  child: Text(
                    'OBJECTIVE',
                    style: GoogleFonts.firaCode(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: accent,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    'CONCLUSION',
                    style: GoogleFonts.firaCode(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: accent,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Rows
          for (int i = 0; i < conclusions.length; i++)
            _ConclusionRow(
              conclusion: conclusions[i] as Map<String, dynamic>,
              isEven: i.isEven,
              accent: accent,
            ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms);
  }
}

class _ConclusionRow extends StatefulWidget {
  final Map<String, dynamic> conclusion;
  final bool isEven;
  final Color accent;

  const _ConclusionRow({
    required this.conclusion,
    required this.isEven,
    required this.accent,
  });

  @override
  State<_ConclusionRow> createState() => _ConclusionRowState();
}

class _ConclusionRowState extends State<_ConclusionRow> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final objective = widget.conclusion['objective'] as String? ?? '';
    final text = widget.conclusion['conclusion'] as String? ?? '';

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: _hovering
              ? Colors.white.withValues(alpha: 0.04)
              : widget.isEven
                  ? Colors.transparent
                  : Colors.white.withValues(alpha: 0.015),
          border: Border(
            bottom: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 80,
              child: Text(
                objective,
                style: GoogleFonts.firaCode(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: widget.accent,
                ),
              ),
            ),
            Expanded(
              child: _CellText(
                text: text,
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: Colors.white70,
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Recommendations Grid ────────────────────────────────────────────────────

class _RecommendationsGrid extends StatelessWidget {
  final List recommendations;
  final Color accent;
  final bool isNarrow;

  const _RecommendationsGrid({
    required this.recommendations,
    required this.accent,
    required this.isNarrow,
  });

  @override
  Widget build(BuildContext context) {
    if (isNarrow) {
      return Column(
        children: [
          for (int i = 0; i < recommendations.length; i++) ...[
            _RecommendationCard(
              rec: recommendations[i] as Map<String, dynamic>,
              accent: accent,
              index: i,
            ),
            if (i < recommendations.length - 1) const SizedBox(height: 12),
          ],
        ],
      );
    }

    final rows = <Widget>[];
    for (int i = 0; i < recommendations.length; i += 2) {
      rows.add(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _RecommendationCard(
                  rec: recommendations[i] as Map<String, dynamic>,
                  accent: accent,
                  index: i,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: i + 1 < recommendations.length
                    ? _RecommendationCard(
                        rec: recommendations[i + 1] as Map<String, dynamic>,
                        accent: accent,
                        index: i + 1,
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      );
      if (i + 2 < recommendations.length) {
        rows.add(const SizedBox(height: 12));
      }
    }

    return Column(children: rows);
  }
}

class _RecommendationCard extends StatelessWidget {
  final Map<String, dynamic> rec;
  final Color accent;
  final int index;

  const _RecommendationCard({
    required this.rec,
    required this.accent,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    final id = rec['id'] as String? ?? '';
    final title = rec['title'] as String? ?? '';
    final priority = rec['priority'] as String? ?? '';
    final contextText = rec['context'] as String? ?? '';
    final directions = (rec['directions'] as List?)?.cast<String>() ?? [];
    final applicabilityTable =
        (rec['applicability_table'] as List?) ?? [];

    final isHighPriority = priority.toLowerCase().contains('highest');

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF141418),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isHighPriority
              ? const Color(0xFFE97316).withValues(alpha: 0.3)
              : Colors.white.withValues(alpha: 0.06),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row: ID + priority badge
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  id,
                  style: GoogleFonts.firaCode(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: accent,
                  ),
                ),
              ),
              if (priority.isNotEmpty) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isHighPriority
                        ? const Color(0xFFE97316).withValues(alpha: 0.15)
                        : Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    priority,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isHighPriority
                          ? const Color(0xFFE97316)
                          : Colors.white54,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),
          // Title
          Text(
            title,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          if (contextText.isNotEmpty) ...[
            const SizedBox(height: 10),
            // Context quote
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.02),
                borderRadius: BorderRadius.circular(10),
                border: Border(
                  left: BorderSide(
                    color: isHighPriority
                        ? const Color(0xFFE97316).withValues(alpha: 0.6)
                        : accent.withValues(alpha: 0.3),
                    width: 3,
                  ),
                ),
              ),
              child: Text(
                contextText,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                  color: Colors.white54,
                  height: 1.5,
                ),
              ),
            ),
          ],
          if (directions.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'Future Directions',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 8),
            ...directions.map((d) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Container(
                          width: 5,
                          height: 5,
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.5),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          d,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: Colors.white60,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                )),
          ],
          // Inline applicability table (for R6)
          if (applicabilityTable.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.02),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  for (int i = 0; i < applicabilityTable.length; i++)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        border: i < applicabilityTable.length - 1
                            ? Border(
                                bottom: BorderSide(
                                    color:
                                        Colors.white.withValues(alpha: 0.04)))
                            : null,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              (applicabilityTable[i]
                                      as Map<String, dynamic>)['domain'] ??
                                  '',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: Colors.white70,
                              ),
                            ),
                          ),
                          Flexible(
                            child: _CellText(
                              text: (applicabilityTable[i] as Map<String, dynamic>)['status'] ?? '',
                              fontSize: 13,
                              fontWeight: FontWeight.w400,
                              color: Colors.white54,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    ).animate().fadeIn(delay: (index * 80).ms, duration: 350.ms);
  }
}

class _CellText extends StatelessWidget {
  final String text;
  final double fontSize;
  final FontWeight fontWeight;
  final Color color;
  final double? height;

  const _CellText({
    required this.text,
    required this.fontSize,
    required this.fontWeight,
    required this.color,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    if (text.startsWith('✅') || text.startsWith('❌') || text.startsWith('🔄')) {
      final isCheck = text.startsWith('✅');
      final isCross = text.startsWith('❌');
      
      String textPart = text;
      if (isCheck) {
        textPart = text.substring('✅'.length);
      } else if (isCross) {
        textPart = text.substring('❌'.length);
      } else {
        textPart = text.substring('🔄'.length);
      }
      textPart = textPart.trim();
      
      Color iconColor;
      IconData iconData;
      
      if (isCheck) {
        iconColor = const Color(0xFF22C55E);
        iconData = Icons.check_circle_rounded;
      } else if (isCross) {
        iconColor = const Color(0xFFEF4444);
        iconData = Icons.cancel_rounded;
      } else {
        iconColor = const Color(0xFF38BDF8); // Blue
        iconData = Icons.sync_rounded;
      }
      
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: EdgeInsets.only(top: height == null ? 0.0 : 2.0),
            child: Icon(iconData, color: iconColor, size: fontSize + 1.0),
          ),
          if (textPart.isNotEmpty) const SizedBox(width: 6),
          if (textPart.isNotEmpty)
            Flexible(
              child: Text(
                textPart,
                style: GoogleFonts.inter(
                  fontSize: fontSize,
                  fontWeight: fontWeight,
                  color: color,
                  height: height ?? 1.4,
                ),
              ),
            ),
        ],
      );
    }

    return Text(
      text,
      style: GoogleFonts.inter(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        height: height ?? 1.4,
      ),
    );
  }
}
