import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Draggable timeline scrubber with dual modes (Lifecycle / Stolen Kiosk),
/// colored phase segments, risk bar, and severity-coded vulnerability cards.
class TemporalAnalysisTemplate extends StatefulWidget {
  final Map<String, dynamic> data;
  const TemporalAnalysisTemplate({super.key, required this.data});

  @override
  State<TemporalAnalysisTemplate> createState() =>
      _TemporalAnalysisTemplateState();
}

class _TemporalAnalysisTemplateState extends State<TemporalAnalysisTemplate> {
  String _mode = 'lc';
  double _cursorPct = 0.08;
  bool _dragging = false;
  int _selectedNarrowIndex = 0;

  Color _parseHex(String hex) {
    hex = hex.replaceFirst('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    return Color(int.parse(hex, radix: 16));
  }

  List<Map<String, dynamic>> _getPhases() {
    final modes =
        (widget.data['modes'] as Map<String, dynamic>?) ?? {};
    final modeData =
        (modes[_mode] as Map<String, dynamic>?) ?? {};
    return (modeData['phases'] as List?)?.cast<Map<String, dynamic>>() ?? [];
  }

  Map<String, dynamic> _getPhaseAt(double pct) {
    final phases = _getPhases();
    double acc = 0;
    for (final p in phases) {
      acc += (p['pct'] as int? ?? 10) / 100;
      if (pct <= acc) return p;
    }
    return phases.isNotEmpty ? phases.last : {};
  }

  static const _riskPct = {
    'critical': 0.95,
    'high': 0.72,
    'medium': 0.45,
    'low': 0.18,
  };
  static const _riskColor = {
    'critical': Color(0xFFEF4444),
    'high': Color(0xFFF97316),
    'medium': Color(0xFFFBBF24),
    'low': Color(0xFF22C55E),
  };
  static const _sevClass = {
    'c': ('Critical', Color(0xFFEF4444)),
    'h': ('High', Color(0xFFF97316)),
    'm': ('Medium', Color(0xFFFBBF24)),
    'l': ('Low', Color(0xFF22C55E)),
    'n': ('Mitigated', Color(0xFF38BDF8)),
  };

  @override
  Widget build(BuildContext context) {
    final title = widget.data['title'] as String? ?? '';
    final modes =
        (widget.data['modes'] as Map<String, dynamic>?) ?? {};
    final phases = _getPhases();
    final current = _getPhaseAt(_cursorPct);
    final risk = current['risk'] as String? ?? 'low';
    final riskW = _riskPct[risk] ?? 0.3;
    final riskCol = _riskColor[risk] ?? const Color(0xFF22C55E);
    final isNarrow = MediaQuery.of(context).size.width < 600;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title.isNotEmpty)
          Text(title,
              style: GoogleFonts.spaceGrotesk(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: Colors.white)),
        const SizedBox(height: 16),

        // Mode toggle (Choice chips with ShaderMask)
        Builder(
          builder: (context) {
            final surfaceColor = Theme.of(context).scaffoldBackgroundColor;
            Widget scrollView = SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: modes.entries.map((e) {
                  final isActive = _mode == e.key;
                  final label = (e.value as Map<String, dynamic>)['label'] as String? ?? e.key;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: _buildCustomChip(
                      label: label,
                      isActive: isActive,
                      color: const Color(0xFF38BDF8),
                      onTap: () => setState(() {
                        _mode = e.key;
                        _cursorPct = 0.08;
                        _selectedNarrowIndex = 0;
                      }),
                    ),
                  );
                }).toList(),
              ),
            );

            if (!isNarrow) return scrollView;

            return SizedBox(
              width: double.infinity,
              child: ShaderMask(
                shaderCallback: (Rect bounds) {
                  return LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [surfaceColor, surfaceColor, surfaceColor.withValues(alpha: 0.0)],
                    stops: const [0.0, 0.85, 1.0],
                  ).createShader(bounds);
                },
                blendMode: BlendMode.dstIn,
                child: scrollView,
              ),
            );
          },
        ),
        const SizedBox(height: 16),

        // Responsive track: horizontal on wide, vertical on narrow
        if (isNarrow)
          _buildVerticalTrack(phases, riskW, riskCol)
        else
          _buildHorizontalTrack(phases, riskW, riskCol),
        const SizedBox(height: 12),

        // Detail panel
        _buildDetailPanel(isNarrow
            ? (phases.isNotEmpty && _selectedNarrowIndex < phases.length
                ? phases[_selectedNarrowIndex]
                : current)
            : current),
      ],
    );
  }

  Widget _buildVerticalTrack(
      List<Map<String, dynamic>> phases, double riskW, Color riskCol) {
    return Column(
      children: [
        // Risk bar at top
        Container(
          height: 6,
          decoration: BoxDecoration(
            color: const Color(0xFF1A2D42),
            borderRadius: BorderRadius.circular(3),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: riskW,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              decoration: BoxDecoration(
                color: riskCol,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Phase list
        ...phases.asMap().entries.map((entry) {
          final index = entry.key;
          final p = entry.value;
          final col = _parseHex(p['color'] as String? ?? '#22C55E');
          final isSelected = _selectedNarrowIndex == index;
          final riskStr = p['risk'] as String? ?? 'low';
          final rCol = _riskColor[riskStr] ?? const Color(0xFF22C55E);

          return GestureDetector(
            onTap: () => setState(() => _selectedNarrowIndex = index),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                margin: const EdgeInsets.only(bottom: 4),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected
                      ? col.withValues(alpha: 0.1)
                      : Colors.transparent,
                  border: Border(
                    left: BorderSide(color: col, width: isSelected ? 4 : 3),
                    top: BorderSide(color: isSelected ? col.withValues(alpha: 0.3) : Colors.white.withValues(alpha: 0.15)),
                    right: BorderSide(color: isSelected ? col.withValues(alpha: 0.3) : Colors.white.withValues(alpha: 0.15)),
                    bottom: BorderSide(color: isSelected ? col.withValues(alpha: 0.3) : Colors.white.withValues(alpha: 0.15)),
                  ),
                ),
              child: Row(
                children: [
                  // Risk dot
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: rCol,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      p['name'] as String? ?? '',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight:
                            isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected ? Colors.white : Colors.white54,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    p['duration'] as String? ?? '',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 11,
                      color: Colors.white54,
                    ),
                  ),
                ],
              ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildHorizontalTrack(
      List<Map<String, dynamic>> phases, double riskW, Color riskCol) {
    return LayoutBuilder(builder: (ctx, constraints) {
      final trackW = constraints.maxWidth;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onHorizontalDragStart: (d) {
              _dragging = true;
              _updateCursor(d.localPosition.dx, trackW);
            },
            onHorizontalDragUpdate: (d) {
              if (_dragging) _updateCursor(d.localPosition.dx, trackW);
            },
            onHorizontalDragEnd: (_) => _dragging = false,
            onTapDown: (d) => _updateCursor(d.localPosition.dx, trackW),
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Row(
                    children: phases.map((p) {
                      final pct = (p['pct'] as int? ?? 10);
                      final col =
                          _parseHex(p['color'] as String? ?? '#22C55E');
                      return Expanded(
                        flex: pct,
                        child: Container(
                          decoration: BoxDecoration(
                            color: col.withValues(alpha: 0.13),
                            border: Border(
                                right: BorderSide(
                                    color: col.withValues(alpha: 0.2))),
                          ),
                          alignment: Alignment.center,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 2),
                              child: Text(
                                p['name'] as String? ?? '',
                                style: GoogleFonts.inter(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: col),
                                maxLines: 1,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  Positioned(
                    left: (_cursorPct * trackW) - 1.5,
                    top: -4,
                    bottom: -4,
                    child: Container(
                      width: 3,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(2),
                      ),
                      child: Center(
                        child: Container(
                          width: 13,
                          height: 13,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                            border: Border.all(
                                color: const Color(0xFF070E1A), width: 3),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                    phases.isNotEmpty
                        ? (phases.first['name'] as String? ?? '')
                            .split(':')
                            .last
                            .trim()
                        : '',
                    style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.white24)),
                Text(
                    phases.isNotEmpty
                        ? (phases.last['name'] as String? ?? '')
                            .split(':')
                            .last
                            .trim()
                        : '',
                    style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.white24)),
              ],
            ),
          ),
          Container(
            height: 6,
            decoration: BoxDecoration(
              color: const Color(0xFF1A2D42),
              borderRadius: BorderRadius.circular(3),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: riskW,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                decoration: BoxDecoration(
                  color: riskCol,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ),
        ],
      );
    });
  }

  Widget _buildCustomChip({
    required String label,
    required bool isActive,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: isActive ? color.withValues(alpha: 0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
                color: isActive
                    ? color.withValues(alpha: 0.6)
                    : Colors.white.withValues(alpha: 0.15),
                width: 1.5),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isActive) ...[
                Icon(Icons.check_circle_rounded, size: 14, color: color),
                const SizedBox(width: 6),
              ],
              Text(label,
                  style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                      color: isActive ? color : Colors.white70)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailPanel(Map<String, dynamic> phase) {
    final name = phase['name'] as String? ?? '';
    final duration = phase['duration'] as String? ?? '';
    final risk = phase['risk'] as String? ?? 'low';
    final riskCol = _riskColor[risk] ?? const Color(0xFF22C55E);
    final vulns = (phase['vulnerabilities'] as List?)
            ?.cast<Map<String, dynamic>>() ??
        [];

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: Container(
        key: ValueKey('$_mode-$name'),
        width: double.infinity,
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.transparent,
          border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(name,
                style: GoogleFonts.spaceGrotesk(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.white)),
            const SizedBox(height: 3),
            RichText(
              text: TextSpan(
                style: GoogleFonts.inter(fontSize: 13, color: Colors.white54),
                children: [
                  TextSpan(text: 'Duration: $duration  ·  Risk: '),
                  TextSpan(
                    text:
                        risk[0].toUpperCase() + risk.substring(1),
                    style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: riskCol),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Vulnerability items
            ...vulns.map((v) {
              final sev = v['severity'] as String? ?? 'l';
              final sevData = _sevClass[sev] ?? ('Low', const Color(0xFF22C55E));
              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 2),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: sevData.$2.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                            color: sevData.$2.withValues(alpha: 0.19)),
                      ),
                      child: Text(sevData.$1,
                          style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: sevData.$2)),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(v['text'] as String? ?? '',
                          style: GoogleFonts.inter(
                              fontSize: 13,
                              color: Colors.white70,
                              height: 1.4)),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  void _updateCursor(double localX, double trackWidth) {
    setState(() {
      _cursorPct = (localX / trackWidth).clamp(0.01, 0.99);
    });
  }
}
