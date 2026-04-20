import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Hypothesis Framework — flat vertically scrollable layout.
/// S0: Architecture comparison  S1: Hypothesis H₀/H₁  S2: Factorial design
class HypothesisFrameworkTemplate extends StatefulWidget {
  final Map<String, dynamic> data;
  final Color accent;
  const HypothesisFrameworkTemplate({super.key, required this.data, required this.accent});

  @override
  State<HypothesisFrameworkTemplate> createState() => _HypothesisFrameworkTemplateState();
}

class _HypothesisFrameworkTemplateState extends State<HypothesisFrameworkTemplate> {
  String _credState = 'none';

  static const _orange = Color(0xFFE97316);
  static const _blue = Color(0xFF38BDF8);
  static const _violet = Color(0xFFA78BFA);
  static const _green = Color(0xFF22C55E);
  static const _red = Color(0xFFEF4444);
  static const _yellow = Color(0xFFFBBF24);

  Map<String, dynamic> get _d => widget.data;
  Map<String, dynamic> get _arch => (_d['architecture'] as Map<String, dynamic>?) ?? {};
  Map<String, dynamic> get _hyp => (_d['hypothesis'] as Map<String, dynamic>?) ?? {};
  Map<String, dynamic> get _fact => (_d['factorial'] as Map<String, dynamic>?) ?? {};

  @override
  Widget build(BuildContext context) {
    final title = _d['title'] ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title.isNotEmpty) ...[
          Text(title, style: GoogleFonts.spaceGrotesk(fontSize: 28, fontWeight: FontWeight.w700, color: Colors.white)),
          const SizedBox(height: 24),
        ],

        // S0: Architecture comparison
        _buildSectionDivider(label: 'Architecture flow'),
        const SizedBox(height: 16),
        _buildArchSection(),
        const SizedBox(height: 48),

        // S1: Hypothesis
        _buildSectionDivider(label: 'Hypothesis'),
        const SizedBox(height: 16),
        _buildHypothesisSection(),
        const SizedBox(height: 48),

        // S2: Factorial design
        _buildSectionDivider(label: 'Factorial design'),
        const SizedBox(height: 16),
        _buildFactorialSection(),
      ],
    ).animate().fadeIn(duration: 400.ms);
  }

  Widget _buildSectionDivider({required String label}) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: _orange.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: _orange.withValues(alpha: 0.2)),
          ),
          child: Text(label.toUpperCase(), style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: _orange, letterSpacing: 0.8)),
        ),
        const SizedBox(width: 10),
        Expanded(child: Container(height: 1, color: _orange.withValues(alpha: 0.1))),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════
  // S0: Architecture comparison
  // ═══════════════════════════════════════════════════════
  Widget _buildArchSection() {
    final archTitle = _arch['title'] ?? '';
    final archSub = _arch['subtitle'] ?? '';
    final trad = (_arch['traditional'] as Map<String, dynamic>?) ?? {};
    final prism = (_arch['prism'] as Map<String, dynamic>?) ?? {};
    final diffs = (_arch['differences'] as List?) ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(archTitle, style: GoogleFonts.spaceGrotesk(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white)),
        const SizedBox(height: 4),
        Text(archSub, style: GoogleFonts.inter(fontSize: 14, color: Colors.white24)),
        const SizedBox(height: 16),
        _buildCredToggle(),
        const SizedBox(height: 16),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: _buildArchColumn(trad, _orange, isTraditional: true)),
          const SizedBox(width: 10),
          Expanded(child: _buildArchColumn(prism, _blue, isTraditional: false)),
        ]),
        const SizedBox(height: 16),
        _buildDiffBox(diffs),
      ],
    );
  }

  Widget _buildCredToggle() {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(color: const Color(0xFF0a1422), borderRadius: BorderRadius.circular(8)),
      child: Row(children: [
        Expanded(child: _credBtn('Credential Active', 'active', _green)),
        Expanded(child: _credBtn('Credential Revoked', 'revoked', _red)),
      ]),
    );
  }

  Widget _credBtn(String label, String state, Color color) {
    final isActive = _credState == state;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => setState(() => _credState = state),
        borderRadius: BorderRadius.circular(6),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 7),
          decoration: BoxDecoration(
            color: isActive ? color.withValues(alpha: 0.13) : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Center(child: Text(label, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: isActive ? color : Colors.white24))),
        ),
      ),
    );
  }

  Widget _buildArchColumn(Map<String, dynamic> arch, Color titleColor, {required bool isTraditional}) {
    final label = arch['label'] ?? '';
    final steps = (arch['steps'] as List?)?.cast<String>() ?? [];
    final failAt = (arch['revoked_fail_at'] as num?)?.toInt() ?? 3;
    final activeOutcome = arch['active_outcome'] ?? '';
    final revokedOutcome = arch['revoked_outcome'] ?? '';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: const Color(0xFF0f1e30), borderRadius: BorderRadius.circular(12)),
      child: Column(children: [
        Text(label.toUpperCase(), style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: titleColor, letterSpacing: 0.6)),
        const SizedBox(height: 6),
        if (_credState != 'none')
          Text(_credState == 'active' ? 'Credential Active' : 'Credential Revoked',
              style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: _credState == 'active' ? _green : _red, letterSpacing: 0.6)),
        const SizedBox(height: 10),
        ...List.generate(steps.length, (i) {
          final isGated = !isTraditional && i <= 1;
          final nc = _nodeColor(i, failAt, isGated, isTraditional);
          final ac = _arrowColor(i, failAt);
          return Column(children: [
            if (i > 0) Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: AnimatedDefaultTextStyle(duration: const Duration(milliseconds: 300), style: TextStyle(fontSize: 13, color: ac), child: const Text('↓'))),
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
              decoration: BoxDecoration(color: nc['bg']!, borderRadius: BorderRadius.circular(9), border: Border.all(color: nc['border']!, width: 1.5)),
              child: Center(child: Text(steps[i], style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: nc['text']!), textAlign: TextAlign.center)),
            ),
          ]);
        }),
        if (_credState != 'none') ...[
          const SizedBox(height: 10),
          AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF120f25),
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: _violet, width: 2),
            ),
            child: Center(child: Text(_credState == 'active' ? activeOutcome : revokedOutcome, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: _violet), textAlign: TextAlign.center)),
          ).animate().fadeIn(delay: 300.ms, duration: 300.ms),
        ],
      ]),
    );
  }

  Map<String, Color> _nodeColor(int i, int failAt, bool isGated, bool isTraditional) {
    if (_credState == 'none') {
      if (isGated) return {'bg': const Color(0xFF0d1f30), 'border': _blue, 'text': _blue};
      if (i == 3 && isTraditional) return {'bg': const Color(0xFF1a0e04), 'border': _orange.withValues(alpha: 0.25), 'text': _orange};
      return {'bg': const Color(0xFF0a1828), 'border': const Color(0xFF1e3a55), 'text': Colors.white70};
    }
    if (_credState == 'active') return {'bg': const Color(0xFF071a0e), 'border': _green, 'text': _green};
    if (i < failAt) return {'bg': const Color(0xFF071a0e), 'border': _green, 'text': _green};
    if (i == failAt) return {'bg': const Color(0xFF1a0808), 'border': _red, 'text': _red};
    return {'bg': const Color(0xFF070e1a), 'border': const Color(0xFF111e2a), 'text': Colors.white12};
  }

  Color _arrowColor(int i, int failAt) {
    if (_credState == 'none') return const Color(0xFF1e3a55);
    if (_credState == 'active') return _green;
    if (i < failAt) return _green;
    if (i == failAt) return _red;
    return const Color(0xFF111e2a);
  }

  Widget _buildDiffBox(List diffs) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: const Color(0xFF0d1525), borderRadius: BorderRadius.circular(12), border: Border.all(color: _blue.withValues(alpha: 0.2))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('KEY ARCHITECTURAL DIFFERENCE', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: _blue, letterSpacing: 0.6)),
        const SizedBox(height: 10),
        ...diffs.map((d) {
          final diff = d as Map<String, dynamic>;
          final color = diff['color'] == 'orange' ? _orange : _blue;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(width: 6, height: 6, margin: const EdgeInsets.only(top: 5, right: 10), decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
              Expanded(child: Text(diff['text'] ?? '', style: GoogleFonts.inter(fontSize: 14, color: Colors.white.withValues(alpha: 0.65), height: 1.5))),
            ]),
          );
        }),
      ]),
    );
  }

  // ═══════════════════════════════════════════════════════
  // S1: Hypothesis
  // ═══════════════════════════════════════════════════════
  Widget _buildHypothesisSection() {
    final hypTitle = _hyp['title'] ?? '';
    final hypSub = _hyp['subtitle'] ?? '';
    final h0 = (_hyp['null'] as Map<String, dynamic>?) ?? {};
    final h1 = (_hyp['alternative'] as Map<String, dynamic>?) ?? {};
    final measurements = (_hyp['measurements'] as List?) ?? [];
    final whyPrism = _hyp['why_prism'] ?? '';

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(hypTitle, style: GoogleFonts.spaceGrotesk(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white)),
      const SizedBox(height: 4),
      Text(hypSub, style: GoogleFonts.inter(fontSize: 14, color: Colors.white24)),
      const SizedBox(height: 16),
      LayoutBuilder(builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 500;
        if (isNarrow) {
          return Column(children: [
            _buildHypCard(h0, isNull: true),
            const SizedBox(height: 10),
            _buildHypCard(h1, isNull: false),
          ]);
        }
        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: _buildHypCard(h0, isNull: true)),
          const SizedBox(width: 10),
          Expanded(child: _buildHypCard(h1, isNull: false)),
        ]);
      }),
      const SizedBox(height: 16),
      _buildMeasurementBox(measurements, whyPrism),
    ]);
  }

  Widget _buildHypCard(Map<String, dynamic> hyp, {required bool isNull}) {
    final color = isNull ? _orange : _green;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isNull ? const Color(0xFF1a0e04) : const Color(0xFF071a0e),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color, width: 2),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text((hyp['label'] ?? '').toUpperCase(), style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: color, letterSpacing: 1.0)),
        const SizedBox(height: 10),
        Text(hyp['text'] ?? '', style: GoogleFonts.inter(fontSize: 14, color: Colors.white.withValues(alpha: 0.8), height: 1.65)),
      ]),
    );
  }

  Widget _buildMeasurementBox(List measurements, String whyPrism) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: const Color(0xFF0f1e30), borderRadius: BorderRadius.circular(12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('PROPERTY BEING MEASURED', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: _violet, letterSpacing: 0.6)),
        const SizedBox(height: 10),
        ...measurements.map((m) {
          final mm = m as Map<String, dynamic>;
          final dotColor = mm['color'] == 'green' ? _green : _red;
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(width: 6, height: 6, margin: const EdgeInsets.only(top: 5, right: 8), decoration: BoxDecoration(shape: BoxShape.circle, color: dotColor)),
              Expanded(child: Text(mm['text'] ?? '', style: GoogleFonts.inter(fontSize: 14, color: Colors.white.withValues(alpha: 0.65), height: 1.5))),
            ]),
          );
        }),
        if (whyPrism.isNotEmpty) ...[
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.only(top: 10),
            decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFF1a2d42)))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('WHY PRISM SHOULD WIN', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: _blue, letterSpacing: 0.5)),
              const SizedBox(height: 6),
              Text(whyPrism, style: GoogleFonts.inter(fontSize: 14, color: Colors.white.withValues(alpha: 0.65), height: 1.6)),
            ]),
          ),
        ],
      ]),
    );
  }

  // ═══════════════════════════════════════════════════════
  // S2: Factorial design
  // ═══════════════════════════════════════════════════════
  Widget _buildFactorialSection() {
    final factTitle = _fact['title'] ?? '';
    final factSub = _fact['subtitle'] ?? '';
    final columns = (_fact['columns'] as List?)?.cast<String>() ?? [];
    final rows = (_fact['rows'] as List?) ?? [];
    final refNote = _fact['reference_note'] ?? '';
    final statMethod = _fact['stat_method'] ?? '';
    final statReason = _fact['stat_reason'] ?? '';
    final statCards = (_fact['stat_cards'] as List?) ?? [];

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(factTitle, style: GoogleFonts.spaceGrotesk(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white)),
      const SizedBox(height: 4),
      Text(factSub, style: GoogleFonts.inter(fontSize: 14, color: Colors.white24)),
      const SizedBox(height: 16),

      // Visual legend — what cell colors mean
      _buildMatrixLegend(),
      const SizedBox(height: 12),

      // Factorial table
      _buildFactorialMatrix(columns, rows),
      const SizedBox(height: 16),

      // Reference group explainer
      _buildReferenceExplainer(refNote),
      const SizedBox(height: 24),

      // Firth's method — emphasized hero card
      LayoutBuilder(builder: (context, constraints) {
        return _buildFirthCard(statMethod, statReason, isNarrow: constraints.maxWidth < 500);
      }),
      const SizedBox(height: 16),

      // Stat concept cards
      LayoutBuilder(builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 500;
        if (isNarrow) {
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: statCards.map<Widget>((sc) => Padding(padding: const EdgeInsets.only(bottom: 8), child: _buildStatCard(sc as Map<String, dynamic>, isNarrow: false))).toList(),
              ),
            ),
          );
        }
        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: statCards.asMap().entries.map<Widget>((entry) => Expanded(child: Padding(padding: EdgeInsets.only(left: entry.key > 0 ? 8 : 0), child: _buildStatCard(entry.value as Map<String, dynamic>)))).toList());
      }),
    ]);
  }

  /// Factorial matrix with axis labels.
  Widget _buildFactorialMatrix(List<String> columns, List rows) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Y-axis label
        Padding(
          padding: const EdgeInsets.only(bottom: 6, left: 4),
          child: Row(children: [
            Icon(Icons.swap_vert_rounded, size: 12, color: _orange.withValues(alpha: 0.5)),
            const SizedBox(width: 4),
            Text('Architecture', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: _orange.withValues(alpha: 0.5), letterSpacing: 0.5)),
          ]),
        ),
        Container(
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF1a2d42))),
          clipBehavior: Clip.antiAlias,
          child: Column(children: [
            // Header row
            Container(
              decoration: const BoxDecoration(color: Color(0xFF1D3A5C)),
              child: IntrinsicHeight(
                child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Expanded(flex: 3, child: Container(color: const Color(0xFF0f1e30), padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 8))),
                  ...columns.map((col) => Expanded(
                    flex: 3,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 8),
                      child: Center(child: Text(col, textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: _blue, letterSpacing: 0.5))),
                    ),
                  )),
                ]),
              ),
            ),
            // Data rows
            ...rows.map((row) {
              final r = row as Map<String, dynamic>;
              final cells = (r['cells'] as List?) ?? [];
              return Container(
                decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFF1a2d42)))),
                child: IntrinsicHeight(
                  child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Expanded(
                      flex: 3,
                      child: Container(
                        color: const Color(0xFF0f1e30),
                        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                        child: Align(alignment: Alignment.centerLeft, child: Text(r['label'] ?? '', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white))),
                      ),
                    ),
                    ...cells.map((cell) {
                      final c = cell as Map<String, dynamic>;
                      final cc = _cellColor(c['style'] as String? ?? 'normal');
                      final note = c['note'] as String? ?? '';
                      final isRef = c['style'] == 'reference';
                      return Expanded(
                        flex: 3,
                        child: Container(
                          color: cc['bg'],
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                            Text(c['value'] ?? '', textAlign: TextAlign.center, style: GoogleFonts.jetBrainsMono(fontSize: 14, fontWeight: FontWeight.w700, color: _yellow)),
                            if (note.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(note, textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 10, color: cc['text']!.withValues(alpha: 0.55))),
                            ],
                            if (isRef) ...[
                              const SizedBox(height: 4),
                              Icon(Icons.flag_rounded, size: 12, color: _green.withValues(alpha: 0.6)),
                            ],
                          ]),
                        ),
                      );
                    }),
                  ]),
                ),
              );
            }),
          ]),
        ),
        // X-axis label
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Align(
            alignment: Alignment.centerRight,
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text('Credential State', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: _blue.withValues(alpha: 0.5), letterSpacing: 0.5)),
              const SizedBox(width: 4),
              Icon(Icons.swap_horiz_rounded, size: 12, color: _blue.withValues(alpha: 0.5)),
            ]),
          ),
        ),
      ],
    );
  }

  Map<String, Color> _cellColor(String style) {
    switch (style) {
      case 'reference': return {'bg': const Color(0xFF071a0e), 'text': _green};
      case 'key': return {'bg': const Color(0xFF0d1525), 'text': _blue};
      case 'critical': return {'bg': const Color(0xFF1a0808), 'text': _red};
      default: return {'bg': const Color(0xFF0a1422), 'text': Colors.white};
    }
  }

  /// Color-coded legend for the matrix cells.
  Widget _buildMatrixLegend() {
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: [
        _legendChip('Reference group', _green),
        _legendChip('Key comparison', _blue),
        _legendChip('Expected ≈ 0', _red),
        _legendChip('Normal', Colors.white38),
      ],
    );
  }

  Widget _legendChip(String label, Color color) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 8, height: 8, decoration: BoxDecoration(borderRadius: BorderRadius.circular(2), color: color.withValues(alpha: 0.3), border: Border.all(color: color.withValues(alpha: 0.6), width: 1))),
      const SizedBox(width: 4),
      Text(label, style: GoogleFonts.inter(fontSize: 10, color: color.withValues(alpha: 0.7), fontWeight: FontWeight.w600)),
    ]);
  }

  /// Explains why Parallel + Active is the reference group.
  Widget _buildReferenceExplainer(String refNote) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF071a0e),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _green.withValues(alpha: 0.3)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.flag_rounded, size: 14, color: _green),
          const SizedBox(width: 6),
          Text('REFERENCE GROUP', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: _green, letterSpacing: 0.6)),
        ]),
        const SizedBox(height: 10),
        Text(refNote, style: GoogleFonts.inter(fontSize: 14, color: Colors.white70, height: 1.55)),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.only(top: 10),
          decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFF1a3d2a)))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Why this baseline?', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: _green.withValues(alpha: 0.8))),
            const SizedBox(height: 6),
            _refReasonRow(Icons.check_circle_outline_rounded, 'Both biometrics and credential are functional; this is the "everything works" scenario.'),
            _refReasonRow(Icons.compare_arrows_rounded, 'All other cells are compared against this outcome to measure what breaks and how much.'),
            _refReasonRow(Icons.science_outlined, 'Logistic regression treats this cell as the intercept; its success rate defines the expected baseline probability.'),
          ]),
        ),
      ]),
    );
  }

  Widget _refReasonRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 12, color: _green.withValues(alpha: 0.5)),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: GoogleFonts.inter(fontSize: 12, color: Colors.white.withValues(alpha: 0.55), height: 1.45))),
      ]),
    );
  }

  /// Firth's method — prominent hero card with violet accent
  Widget _buildFirthCard(String method, String reason, {required bool isNarrow}) {
    return Container(
      padding: EdgeInsets.all(isNarrow ? 14 : 18),
      decoration: BoxDecoration(
        color: const Color(0xFF0d1020),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _violet, width: 1.5),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: _violet.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
            child: Text('STATISTICAL METHOD', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: _violet, letterSpacing: 0.8)),
          ),
        ]),
        const SizedBox(height: 12),
        Text(method, style: GoogleFonts.spaceGrotesk(fontSize: isNarrow ? 18 : 22, fontWeight: FontWeight.w700, color: Colors.white)),
        const SizedBox(height: 10),
        Text(reason, style: GoogleFonts.inter(fontSize: isNarrow ? 13 : 14, color: Colors.white70, height: 1.6)),
        const SizedBox(height: 12),
        // Visual callout: why Firth's
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _violet.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _violet.withValues(alpha: 0.15)),
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'PRISM + Revoked cell is expected to yield zero successful verifications (complete separation). Standard logistic regression fails under complete separation, whereas Firth\'s bias-reduction penalty keeps estimates finite.',
                style: GoogleFonts.inter(fontSize: 12, color: Colors.white60, height: 1.5),
              ),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _buildStatCard(Map<String, dynamic> card, {bool isNarrow = false}) {
    final rows = (card['rows'] as List?)?.cast<String>() ?? [];
    return Container(
      padding: EdgeInsets.all(isNarrow ? 8 : 12),
      decoration: BoxDecoration(color: const Color(0xFF0f1e30), borderRadius: BorderRadius.circular(10)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(card['symbol'] ?? '', style: GoogleFonts.jetBrainsMono(fontSize: isNarrow ? 14 : 18, fontWeight: FontWeight.w700, color: _yellow)),
        const SizedBox(height: 3),
        Text(card['name'] ?? '', style: GoogleFonts.inter(fontSize: isNarrow ? 8 : 10, fontWeight: FontWeight.w700, color: Colors.white54)),
        const SizedBox(height: 6),
        ...rows.map((r) => Padding(padding: const EdgeInsets.only(bottom: 2), child: Text(r, style: GoogleFonts.inter(fontSize: isNarrow ? 8 : 10, color: Colors.white.withValues(alpha: 0.65), height: 1.4)))),
      ]),
    );
  }
}
