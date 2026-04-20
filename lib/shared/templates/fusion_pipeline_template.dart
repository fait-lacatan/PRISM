import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// S4: Dual-stream fusion pipeline with animated merge point.
/// Wide mode: horizontal dual-stream (top/bottom).
/// Narrow mode: vertical dual-stream (left column = Face, right column = Fingerprint, flowing downward).
class FusionPipelineTemplate extends StatefulWidget {
  final Map<String, dynamic> data;
  final Color accent;
  const FusionPipelineTemplate({super.key, required this.data, required this.accent});

  @override
  State<FusionPipelineTemplate> createState() => _FusionPipelineTemplateState();
}

class _FusionPipelineTemplateState extends State<FusionPipelineTemplate> {
  int _selectedLevel = 1; // default to Feature-level
  static const _orange = Color(0xFFE97316);
  static const _violet = Color(0xFFA78BFA);
  static const _blue = Color(0xFF38BDF8);

  Map<String, dynamic> get _d => widget.data;
  List get _levels => (_d['levels'] as List?) ?? [];
  List get _combos => (_d['combos'] as List?) ?? [];

  static const _stages = ['Image\nAcquisition', 'Feature\nExtraction', 'Score', 'Decision'];

  @override
  Widget build(BuildContext context) {
    final title = _d['title'] ?? '';
    final subtitle = _d['subtitle'] ?? '';
    final currentLevel = _selectedLevel < _levels.length ? _levels[_selectedLevel] as Map<String, dynamic> : <String, dynamic>{};
    final mergeAt = (currentLevel['merge_at'] as num?)?.toInt() ?? 1;
    final desc = currentLevel['description'] ?? '';
    final levelName = currentLevel['name'] ?? '';

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

        // Segmented control — M3 Choice Chips style
        LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 600;
            Widget scrollView = SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (int i = 0; i < _levels.length; i++) ...[
                    Builder(builder: (context) {
                      final level = _levels[i] as Map<String, dynamic>;
                      final isActive = i == _selectedLevel;
                      return Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => setState(() => _selectedLevel = i),
                          borderRadius: BorderRadius.circular(24),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(
                              color: isActive ? widget.accent.withValues(alpha: 0.15) : Colors.transparent,
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: isActive ? widget.accent.withValues(alpha: 0.6) : Colors.white.withValues(alpha: 0.15),
                                width: 1.5,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (isActive) ...[
                                  Icon(Icons.check_circle_rounded, size: 14, color: widget.accent),
                                  const SizedBox(width: 6),
                                ],
                                Text(
                                  level['name'] ?? '',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                                    color: isActive ? widget.accent : Colors.white70,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                    if (i < _levels.length - 1) const SizedBox(width: 8),
                  ],
                ],
              ),
            );

            if (!isNarrow) return scrollView;

            return SizedBox(
              width: double.infinity,
              child: ShaderMask(
                shaderCallback: (Rect bounds) {
                  return const LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [Colors.white, Colors.white, Colors.transparent],
                    stops: [0.0, 0.92, 1.0],
                  ).createShader(bounds);
                },
                blendMode: BlendMode.dstIn,
                child: scrollView,
              ),
            );
          },
        ),
        const SizedBox(height: 24),

        // Pipeline — switches layout based on width
        LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 500;
            return isNarrow
                ? _buildVerticalPipeline(mergeAt, levelName)
                : _buildHorizontalPipeline(mergeAt, levelName);
          },
        ),
        const SizedBox(height: 16),

        // Description
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: Container(
            key: ValueKey(_selectedLevel),
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF0f1e30),
              borderRadius: const BorderRadius.only(topRight: Radius.circular(12), bottomRight: Radius.circular(12)),
              border: const Border(left: BorderSide(color: _violet, width: 3)),
            ),
            child: Text(desc, style: GoogleFonts.inter(fontSize: 12, color: Colors.white.withValues(alpha: 0.65), height: 1.55)),
          ),
        ),
        const SizedBox(height: 20),

        // Combo grid
        Text('COMMON MODALITY COMBINATIONS', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.white38, letterSpacing: 0.6)),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, constraints) {
            final cols = constraints.maxWidth >= 500 ? 2 : 1;
            final spacing = 10.0;
            final cardW = (constraints.maxWidth - spacing * (cols - 1)) / cols;
            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: _combos.map<Widget>((c) {
                final combo = c as Map<String, dynamic>;
                return SizedBox(
                  width: cardW,
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _violet.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _violet.withValues(alpha: 0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(combo['name'] ?? '', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.bolt_rounded, size: 14, color: _orange),
                            const SizedBox(width: 4),
                            Text(combo['accuracy'] ?? '', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: _orange)),
                          ],
                        ),
                        const SizedBox(height: 5),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(color: _violet.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
                          child: Text(combo['meta'] ?? '', style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w600, color: _violet)),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    ).animate().fadeIn(duration: 400.ms);
  }

  // ─────────────────────────────────────────────
  // WIDE MODE — horizontal dual-stream (top/bottom)
  // ─────────────────────────────────────────────
  Widget _buildHorizontalPipeline(int mergeAt, String levelName) {
    return Column(
      children: [
        _buildHStream('Face', Icons.face_rounded, _blue, mergeAt),
        const SizedBox(height: 4),
        _buildHMergeBand(mergeAt, levelName),
        const SizedBox(height: 4),
        _buildHStream('Fingerprint', Icons.fingerprint_rounded, _violet, mergeAt),
      ],
    );
  }

  Widget _buildHStream(String label, IconData icon, Color color, int mergeAt) {
    return Row(
      children: [
        SizedBox(
          width: 64,
          child: Column(
            children: [
              Icon(icon, size: 28, color: color),
              const SizedBox(height: 2),
              Text(label, style: GoogleFonts.inter(fontSize: 8, fontWeight: FontWeight.w700, color: color.withValues(alpha: 0.5))),
            ],
          ),
        ),
        Expanded(
          child: Row(
            children: List.generate(_stages.length * 2 - 1, (i) {
              if (i.isOdd) {
                final nodeIdx = i ~/ 2;
                final isBeforeMerge = nodeIdx < mergeAt;
                return SizedBox(width: 18, child: Center(child: Text('›', style: TextStyle(fontSize: 14, color: isBeforeMerge ? color.withValues(alpha: 0.5) : Colors.white.withValues(alpha: 0.08)))));
              }
              final nodeIdx = i ~/ 2;
              final isMerge = nodeIdx == mergeAt;
              final isActive = nodeIdx <= mergeAt;
              return Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                  decoration: BoxDecoration(
                    color: isMerge ? const Color(0xFF120f2a) : const Color(0xFF0f1e30),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: isMerge ? _violet : (isActive ? color.withValues(alpha: 0.25) : Colors.white.withValues(alpha: 0.05)), width: 1.5),
                  ),
                  child: Text(
                    _stages[nodeIdx],
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: isMerge ? _violet : (isActive ? Colors.white70 : Colors.white24), height: 1.3),
                  ),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }

  Widget _buildHMergeBand(int mergeAt, String levelName) {
    const labelWidth = 64.0;
    return SizedBox(
      height: 40,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final pipeWidth = constraints.maxWidth - labelWidth;
          final stageWidth = pipeWidth / _stages.length;
          final mergeCenter = labelWidth + stageWidth * mergeAt + stageWidth / 2;

          return Stack(
            clipBehavior: Clip.none,
            children: [
              AnimatedPositioned(
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOutCubic,
                left: mergeCenter - 1,
                top: 0, bottom: 0, width: 3,
                child: Container(decoration: BoxDecoration(color: _violet, borderRadius: BorderRadius.circular(2))),
              ),
              AnimatedPositioned(
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOutCubic,
                left: mergeCenter, top: 8,
                child: FractionalTranslation(
                  translation: const Offset(-0.5, 0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0d1020),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _violet, width: 1.5),
                    ),
                    child: Text('$levelName Fusion', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: _violet)),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ─────────────────────────────────────────────
  // NARROW MODE — vertical dual-stream (side-by-side columns, flowing down)
  // Left column = Face, Right column = Fingerprint
  // Stages flow top → bottom, merge connector is a horizontal bar
  // ─────────────────────────────────────────────
  Widget _buildVerticalPipeline(int mergeAt, String levelName) {
    return Column(
      children: [
        // Stream labels row
        Row(
          children: [
            Expanded(child: _vStreamLabel('Face', Icons.face_rounded, _blue)),
            const SizedBox(width: 40), // gap for merge connector
            Expanded(child: _vStreamLabel('Fingerprint', Icons.fingerprint_rounded, _violet)),
          ],
        ),
        const SizedBox(height: 10),

        // Stage rows — each row has: [left node] [merge connector or gap] [right node]
        ...List.generate(_stages.length, (stageIdx) {
          final isMerge = stageIdx == mergeAt;
          final isActive = stageIdx <= mergeAt;

          return Column(
            children: [
              if (stageIdx > 0) ...[
                // Vertical arrows between stages
                Row(
                  children: [
                    Expanded(
                      child: Center(
                        child: Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: 18,
                          color: stageIdx <= mergeAt ? _blue.withValues(alpha: 0.4) : Colors.white.withValues(alpha: 0.08),
                        ),
                      ),
                    ),
                    const SizedBox(width: 40),
                    Expanded(
                      child: Center(
                        child: Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: 18,
                          color: stageIdx <= mergeAt ? _violet.withValues(alpha: 0.4) : Colors.white.withValues(alpha: 0.08),
                        ),
                      ),
                    ),
                  ],
                ),
              ],

              // Stage nodes with merge connector
              SizedBox(
                height: 52,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Left node (Face)
                    Expanded(
                      child: _vStageNode(_stages[stageIdx], _blue, isMerge, isActive),
                    ),

                    // Merge connector or empty gap
                    SizedBox(
                      width: 40,
                      child: isMerge
                          ? Stack(
                              alignment: Alignment.center,
                              children: [
                                // Horizontal connector line
                                Container(
                                  height: 3,
                                  decoration: BoxDecoration(color: _violet, borderRadius: BorderRadius.circular(2)),
                                ),
                              ],
                            )
                          : const SizedBox.shrink(),
                    ),

                    // Right node (Fingerprint)
                    Expanded(
                      child: _vStageNode(_stages[stageIdx], _violet, isMerge, isActive),
                    ),
                  ],
                ),
              ),
            ],
          );
        }),

        // Merge badge below the pipeline
        const SizedBox(height: 10),
        Center(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Container(
              key: ValueKey(levelName),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF0d1020),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _violet, width: 1.5),
              ),
              child: Text('$levelName Fusion', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: _violet)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _vStreamLabel(String label, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, size: 24, color: color),
        const SizedBox(height: 2),
        Text(label, style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w700, color: color.withValues(alpha: 0.6))),
      ],
    );
  }

  Widget _vStageNode(String label, Color streamColor, bool isMerge, bool isActive) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      decoration: BoxDecoration(
        color: isMerge ? const Color(0xFF120f2a) : const Color(0xFF0f1e30),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isMerge ? _violet : (isActive ? streamColor.withValues(alpha: 0.25) : Colors.white.withValues(alpha: 0.05)),
          width: 1.5,
        ),
      ),
      child: Center(
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: isMerge ? _violet : (isActive ? Colors.white70 : Colors.white24),
            height: 1.3,
          ),
        ),
      ),
    );
  }
}
