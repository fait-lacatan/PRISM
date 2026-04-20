import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:math' as math;
import 'dart:async';

/// Foundational Theories — flat vertical layout with 5 interactive theory sections.
class FoundationalTheoriesTemplate extends StatefulWidget {
  final Map<String, dynamic> data;
  final Color accent;
  const FoundationalTheoriesTemplate({super.key, required this.data, required this.accent});

  @override
  State<FoundationalTheoriesTemplate> createState() => _FoundationalTheoriesTemplateState();
}

class _FoundationalTheoriesTemplateState extends State<FoundationalTheoriesTemplate> with TickerProviderStateMixin {
  final Map<String, String> _modes = {};
  int _qbftStep = 0;
  String? _qbftFault; // null = healthy, 'malicious' | 'crash' | 'partition'
  Timer? _qbftTimer;

  @override
  void initState() {
    super.initState();
    _qbftTimer = Timer.periodic(const Duration(milliseconds: 2500), (_) {
      if (mounted) setState(() => _qbftStep++);
    });
  }

  @override
  void dispose() {
    _qbftTimer?.cancel();
    super.dispose();
  }

  static const _orange = Color(0xFFE97316);
  static const _blue = Color(0xFF38BDF8);
  static const _violet = Color(0xFFA78BFA);
  static const _green = Color(0xFF22C55E);
  static const _red = Color(0xFFEF4444);
  static const _yellow = Color(0xFFFBBF24);
  static const _cardBorder = Color(0xFF1a2d42);
  static const _panelBg = Color(0xFF0f1e30);

  Map<String, dynamic> get _d => widget.data;
  List get _theories => (_d['theories'] as List?) ?? [];

  Color _tagColor(String c) {
    switch (c) {
      case 'orange': return _orange;
      case 'blue': return _blue;
      case 'violet': return _violet;
      case 'green': return _green;
      case 'yellow': return _yellow;
      case 'red': return _red;
      default: return _blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ..._theories.asMap().entries.map((entry) {
          final i = entry.key;
          final t = entry.value as Map<String, dynamic>;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (i > 0) const SizedBox(height: 48),
              _buildTheorySection(t),
            ],
          );
        }),
      ],
    ).animate().fadeIn(duration: 400.ms);
  }

  // ═══════════════════════════════════════════════════════════
  // Flat theory section
  // ═══════════════════════════════════════════════════════════
  Widget _buildTheorySection(Map<String, dynamic> theory) {
    final id = theory['id'] as String? ?? '';
    final number = theory['number'] as int? ?? 1;
    final tagColor = _tagColor(theory['tag_color'] as String? ?? 'blue');
    final name = theory['name'] as String? ?? '';
    final subtitle = theory['subtitle'] as String? ?? '';
    final modes = (theory['modes'] as List?) ?? [];
    final activeMode = _modes[id] ?? (modes.isNotEmpty ? (modes[0] as Map<String, dynamic>)['key'] as String : '');

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Section divider with theory tag
      Row(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(
            color: tagColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: tagColor.withValues(alpha: 0.25)),
          ),
          child: Text('THEORY $number', style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w700, color: tagColor, letterSpacing: 0.8)),
        ),
        const SizedBox(width: 10),
        Expanded(child: Container(height: 1, color: tagColor.withValues(alpha: 0.1))),
      ]),
      const SizedBox(height: 12),
      // Theory name as heading
      Text(name, style: GoogleFonts.spaceGrotesk(fontSize: 24, fontWeight: FontWeight.w700, color: Colors.white)),
      const SizedBox(height: 6),
      Text(subtitle, style: GoogleFonts.inter(fontSize: 14, color: Colors.white38, height: 1.5)),
      const SizedBox(height: 14),

      // Mode buttons with UX hint
      _buildMaskedScroll(
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: modes.map<Widget>((m) {
              final mode = m as Map<String, dynamic>;
              final key = mode['key'] as String;
              final label = mode['label'] as String? ?? '';
              final btnColor = _tagColor(mode['color'] as String? ?? 'blue');
              final isActive = activeMode == key;
              return Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => setState(() { _modes[id] = key; }),
                    borderRadius: BorderRadius.circular(24),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: isActive ? btnColor.withValues(alpha: 0.15) : Colors.transparent,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: isActive ? btnColor.withValues(alpha: 0.6) : Colors.white.withValues(alpha: 0.15), width: 1.5),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isActive) ...[
                            Icon(Icons.check_circle_rounded, size: 14, color: btnColor),
                            const SizedBox(width: 6),
                          ],
                          Text(label, style: GoogleFonts.inter(fontSize: 12, fontWeight: isActive ? FontWeight.w700 : FontWeight.w500, color: isActive ? btnColor : Colors.white70)),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
      const SizedBox(height: 16),
      _buildTheoryContent(theory, activeMode),
    ]);
  }

  Widget _buildTheoryContent(Map<String, dynamic> theory, String mode) {
    final id = theory['id'] as String? ?? '';
    switch (id) {
      case 'pad': return _buildPAD(theory, mode);
      case 'triplet_loss': return _buildTripletLoss(theory, mode);
      case 'fuzzy_extractor': return _buildFuzzyExtractor(theory, mode);
      case 'blockchain_qbft': return _buildBlockchainQBFT(theory, mode);
      case 'ssi_did': return _buildSSIDID(theory, mode);
      default: return const SizedBox.shrink();
    }
  }

  // ═══════════════════════════════════════════════════════════
  // T1: PAD
  // ═══════════════════════════════════════════════════════════
  Widget _buildPAD(Map<String, dynamic> theory, String mode) {
    final explanations = (theory['explanations'] as Map<String, dynamic>?) ?? {};
    final modeData = (explanations[mode] as Map<String, dynamic>?) ?? {};
    final title = modeData['title'] as String? ?? '';
    final body = modeData['body'] as String? ?? '';

    if (mode == 'attacks') {
      final attackList = (modeData['attack_list'] as List?) ?? [];
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _sectionLabel(title, _blue),
        const SizedBox(height: 6),
        Text(body, style: _bodyStyle()),
        const SizedBox(height: 14),
        LayoutBuilder(builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 400;
          final cols = isNarrow ? 2 : 4;
          return Wrap(
            spacing: 8,
            runSpacing: 8,
            children: attackList.map<Widget>((a) {
              final attack = a as Map<String, dynamic>;
              final sevColor = _severityColor(attack['severity'] as String? ?? 'low');
              final width = (constraints.maxWidth - (cols - 1) * 8) / cols;
              return SizedBox(
                width: width,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                  decoration: BoxDecoration(
                    color: sevColor.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: sevColor.withValues(alpha: 0.2)),
                  ),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(_attackIcon(attack['icon'] as String? ?? 'photo'), size: 22, color: sevColor),
                    const SizedBox(height: 6),
                    Text(attack['name'] ?? '', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: sevColor), textAlign: TextAlign.center),
                  ]),
                ),
              );
            }).toList(),
          );
        }),
      ]);
    }

    if (mode == 'prism') {
      final pipeline = (modeData['pipeline_position'] as List?)?.cast<String>() ?? [];
      final gateNote = modeData['gate_note'] as String? ?? '';
      return LayoutBuilder(builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 500;
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _sectionLabel(title, _blue),
        const SizedBox(height: 6),
        Text(body, style: _bodyStyle()),
        const SizedBox(height: 14),
        if (isNarrow)
          Column(children: pipeline.asMap().entries.map<Widget>((e) {
            final isFirst = e.key == 0;
            return Column(children: [
              if (e.key > 0) Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Icon(Icons.arrow_downward_rounded, size: 14, color: _orange.withValues(alpha: 0.4))),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                decoration: BoxDecoration(
                  color: isFirst ? _orange.withValues(alpha: 0.1) : _panelBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: isFirst ? _orange.withValues(alpha: 0.4) : _cardBorder),
                  boxShadow: isFirst ? [BoxShadow(color: _orange.withValues(alpha: 0.15), blurRadius: 8)] : null,
                ),
                child: Text(e.value, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: isFirst ? _orange : Colors.white54)),
              ),
            ]);
          }).toList())
        else
          Row(children: pipeline.asMap().entries.map<Widget>((e) {
            final isFirst = e.key == 0;
            return Expanded(child: Row(children: [
              if (e.key > 0) _glowArrow(_orange),
              Expanded(child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                decoration: BoxDecoration(
                  color: isFirst ? _orange.withValues(alpha: 0.1) : _panelBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: isFirst ? _orange.withValues(alpha: 0.4) : _cardBorder),
                  boxShadow: isFirst ? [BoxShadow(color: _orange.withValues(alpha: 0.15), blurRadius: 8)] : null,
                ),
                child: Text(e.value, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: isFirst ? _orange : Colors.white54), textAlign: TextAlign.center),
              )),
            ]));
          }).toList()),
        if (gateNote.isNotEmpty) ...[
          const SizedBox(height: 14),
          _highlightBox(gateNote, _green),
        ],
      ]);
      });
    }

    // "what" mode
    final highlights = (modeData['highlights'] as List?) ?? [];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _sectionLabel(title, _blue),
      const SizedBox(height: 6),
      Text(body, style: _bodyStyle()),
      if (highlights.isNotEmpty) ...[
        const SizedBox(height: 14),
        IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: highlights.asMap().entries.map<Widget>((e) =>
            Expanded(child: Padding(
              padding: EdgeInsets.only(left: e.key > 0 ? 8 : 0),
              child: _padHighlightCard(e.value as Map<String, dynamic>),
            ))
          ).toList()),
        ),
      ],
    ]);
  }

  Widget _padHighlightCard(Map<String, dynamic> h) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: _panelBg, borderRadius: BorderRadius.circular(8)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(h['label'] ?? '', style: GoogleFonts.jetBrainsMono(fontSize: 14, fontWeight: FontWeight.w700, color: _yellow)),
        const SizedBox(height: 4),
        Text(h['text'] ?? '', style: GoogleFonts.inter(fontSize: 12, color: Colors.white54, height: 1.4)),
      ]),
    );
  }

  IconData _attackIcon(String name) {
    switch (name) {
      case 'photo': return Icons.photo_outlined;
      case 'videocam': return Icons.videocam_outlined;
      case 'face_retouching_natural': return Icons.face_retouching_natural;
      case 'memory': return Icons.memory;
      default: return Icons.warning_amber_rounded;
    }
  }

  Color _severityColor(String sev) {
    switch (sev) {
      case 'low': return _green;
      case 'medium': return _yellow;
      case 'high': return _orange;
      case 'critical': return _red;
      default: return Colors.white38;
    }
  }

  // ═══════════════════════════════════════════════════════════
  // T2: Triplet Loss
  // ═══════════════════════════════════════════════════════════
  Widget _buildTripletLoss(Map<String, dynamic> theory, String mode) {
    final properties = (theory['properties'] as List?) ?? [];
    final explanations = (theory['explanations'] as Map<String, dynamic>?) ?? {};
    final text = explanations[mode] as String? ?? '';

    return LayoutBuilder(builder: (context, constraints) {
      final isNarrow = constraints.maxWidth < 500;
      final diagram = _buildTLDiagram(mode);
      final explainer = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _sectionLabel(mode == 'standard' ? 'STANDARD TRIPLET LOSS' : (mode == 'stl' ? 'SECURE TRIPLET LOSS' : 'REISSUANCE'), mode == 'reissue' ? _violet : (mode == 'stl' ? _violet : _violet)),
        const SizedBox(height: 8),
        Text(text, style: _bodyStyle()),
        const SizedBox(height: 14),
        ...properties.map((p) {
          final prop = p as Map<String, dynamic>;
          final color = _tagColor(prop['color'] as String? ?? 'blue');
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: _panelBg, borderRadius: BorderRadius.circular(8), border: Border(left: BorderSide(color: color, width: 3))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(prop['name'] ?? '', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: color)),
              const SizedBox(height: 3),
              Text(prop['text'] ?? '', style: GoogleFonts.inter(fontSize: 10, color: Colors.white.withValues(alpha: 0.55), height: 1.4)),
            ]),
          );
        }),
      ]);

      if (isNarrow) return Column(children: [diagram, const SizedBox(height: 14), explainer]);
      return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: diagram),
        const SizedBox(width: 14),
        Expanded(child: explainer),
      ]);
    });
  }

  Widget _buildTLDiagram(String mode) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF070e1a),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _cardBorder),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('EMBEDDING SPACE ℝⁿ', style: GoogleFonts.jetBrainsMono(fontSize: 8, color: Colors.white12)),
          if (mode == 'stl') _pill('kS active', _violet),
          if (mode == 'reissue') _pill('kS → kS\'', _orange),
        ]),
        const SizedBox(height: 10),
        SizedBox(
          height: 160,
          child: LayoutBuilder(builder: (context, constraints) {
            final w = constraints.maxWidth;
            const h = 160.0;
            final double ax, ay, px, py, nx, ny;
            if (mode == 'standard') {
              ax = w * 0.35; ay = h * 0.55;
              px = w * 0.60; py = h * 0.35;
              nx = w * 0.20; ny = h * 0.20;
            } else {
              ax = w * 0.40; ay = h * 0.50;
              px = w * 0.47; py = h * 0.40;
              nx = w * 0.10; ny = h * 0.12;
            }

            return Stack(children: [
              if (mode != 'standard')
                AnimatedPositioned(
                  duration: 600.ms,
                  left: ax - 40, top: ay - 40,
                  child: Container(
                    width: 80, height: 80,
                    decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: _orange.withValues(alpha: 0.2), width: 1), boxShadow: [BoxShadow(color: _orange.withValues(alpha: 0.06), blurRadius: 20)]),
                  ),
                ),
              CustomPaint(
                size: Size(w, h),
                painter: _TripletLinePainter(ax: ax, ay: ay, px: px, py: py, nx: nx, ny: ny, pullColor: _green.withValues(alpha: mode == 'standard' ? 0.12 : 0.5), pushColor: _red.withValues(alpha: mode == 'standard' ? 0.12 : 0.5), glow: mode != 'standard'),
              ),
              _animatedDot(ax, ay, 'A', 'Anchor', _orange),
              _animatedDot(px, py, 'P', 'Positive', _green),
              _animatedDot(nx, ny, 'N', 'Negative', _red),
              if (mode == 'reissue') _animatedDot(w * 0.78, h * 0.70, "P'", 'Reissued', _violet),
              if (mode != 'standard') ...[
                Positioned(left: (ax + px) / 2 - 12, top: (ay + py) / 2 - 18, child: Text('pull', style: GoogleFonts.inter(fontSize: 8, fontWeight: FontWeight.w700, color: _green.withValues(alpha: 0.8)))),
                Positioned(left: (ax + nx) / 2 - 12, top: (ay + ny) / 2 - 18, child: Text('push', style: GoogleFonts.inter(fontSize: 8, fontWeight: FontWeight.w700, color: _red.withValues(alpha: 0.8)))),
              ],
              if (mode == 'reissue')
                Positioned(left: w * 0.60, top: h * 0.85, child: Text('orthogonal region', style: GoogleFonts.inter(fontSize: 8, color: _violet.withValues(alpha: 0.6)))),
            ]);
          }),
        ),
      ]),
    );
  }

  Widget _animatedDot(double x, double y, String letter, String label, Color color) {
    return AnimatedPositioned(
      duration: 600.ms,
      curve: Curves.easeOutCubic,
      left: x - 9, top: y - 9,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 18, height: 18,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color, boxShadow: [BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 10, spreadRadius: 1)]),
          child: Center(child: Text(letter, style: GoogleFonts.inter(fontSize: 8, fontWeight: FontWeight.w700, color: Colors.black))),
        ),
        Text(label, style: GoogleFonts.inter(fontSize: 7, fontWeight: FontWeight.w600, color: color.withValues(alpha: 0.7))),
      ]),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // T3: Fuzzy Extractor — pipeline always fully scrollable
  // ═══════════════════════════════════════════════════════════
  Widget _buildFuzzyExtractor(Map<String, dynamic> theory, String mode) {
    final nodes = (theory['pipeline_nodes'] as List?) ?? [];
    final explanations = (theory['explanations'] as Map<String, dynamic>?) ?? {};
    final noiseLevels = (theory['noise_levels'] as Map<String, dynamic>?) ?? {};
    final text = explanations[mode] as String? ?? '';
    final noiseData = (noiseLevels[mode] as Map<String, dynamic>?) ?? {};
    final noiseValue = (noiseData['value'] as num?)?.toDouble() ?? 0.3;
    final noiseLabel = noiseData['label'] as String? ?? '';
    final noiseColor = _tagColor(noiseData['color'] as String? ?? 'green');
    final isFail = mode == 'verify-fail';
    final isPass = mode == 'verify-pass';
    final phaseColor = isFail ? _red : (isPass ? _green : _blue);
    final phaseLabel = mode == 'enroll' ? 'Enrollment — Generate' : (isPass ? 'Verification — Close Match ✓' : 'Verification — Too Different ✗');
    final activeTo = isFail ? 2 : nodes.length - 1;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _sectionLabel(phaseLabel, phaseColor),
      const SizedBox(height: 14),

      // Pipeline — vertical in narrow, horizontal scroll in wide
      LayoutBuilder(builder: (context, constraints) {
        final isNarrowPipe = constraints.maxWidth < 500;
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: const Color(0xFF070e1a), borderRadius: BorderRadius.circular(12), border: Border.all(color: _cardBorder)),
          child: isNarrowPipe
              ? Column(children: List.generate(nodes.length, (i) {
                  return Column(mainAxisSize: MainAxisSize.min, children: [
                    if (i > 0) Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Icon(Icons.arrow_downward_rounded, size: 14, color: i <= activeTo ? _blue.withValues(alpha: 0.4) : Colors.white12)),
                    SizedBox(width: double.infinity, child: _feNode(nodes[i] as Map<String, dynamic>, i, activeTo, isFail)),
                  ]);
                }))
              : _buildMaskedScroll(
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(children: List.generate(nodes.length, (i) {
                      return Row(mainAxisSize: MainAxisSize.min, children: [
                        if (i > 0) _glowArrow(i <= activeTo ? _blue : Colors.white12),
                        _feNode(nodes[i] as Map<String, dynamic>, i, activeTo, isFail),
                      ]);
                    })),
                  ),
                ),
        );
      }),
      const SizedBox(height: 12),

      // Noise bar
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: _panelBg, borderRadius: BorderRadius.circular(10)),
        child: Row(children: [
          Text('Noise', style: GoogleFonts.inter(fontSize: 10, color: Colors.white38)),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              height: 6,
              decoration: BoxDecoration(color: const Color(0xFF1a2d42), borderRadius: BorderRadius.circular(3)),
              clipBehavior: Clip.antiAlias,
              child: AnimatedFractionallySizedBox(
                duration: 600.ms, alignment: Alignment.centerLeft, widthFactor: noiseValue,
                child: Container(decoration: BoxDecoration(color: noiseColor, borderRadius: BorderRadius.circular(3), boxShadow: [BoxShadow(color: noiseColor.withValues(alpha: 0.4), blurRadius: 6)])),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(noiseLabel, style: GoogleFonts.jetBrainsMono(fontSize: 9, fontWeight: FontWeight.w700, color: noiseColor)),
        ]),
      ),
      const SizedBox(height: 12),

      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: _panelBg, borderRadius: BorderRadius.circular(12)),
        child: Text(text, style: _bodyStyle()),
      ),
    ]);
  }

  Widget _feNode(Map<String, dynamic> node, int index, int activeTo, bool isFail) {
    final isActive = index <= activeTo;
    final isKey = node['type'] == 'key';
    final isFailed = isFail && index == 2;
    final nodeColor = isFailed ? _red : (isKey ? _yellow : (isActive ? _blue : Colors.white24));
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      decoration: BoxDecoration(
        color: nodeColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: nodeColor.withValues(alpha: 0.3), width: 1.5),
        boxShadow: isActive ? [BoxShadow(color: nodeColor.withValues(alpha: 0.15), blurRadius: 8)] : null,
      ),
      child: Text(node['label'] ?? '', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: nodeColor), textAlign: TextAlign.center),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // T4: Blockchain / QBFT with fault simulation
  // ═══════════════════════════════════════════════════════════
  Widget _buildBlockchainQBFT(Map<String, dynamic> theory, String mode) {
    if (mode == 'chain') return _buildChainView(theory);
    return _buildQBFTView(theory);
  }

  Widget _buildChainView(Map<String, dynamic> theory) {
    final blocks = (theory['chain_blocks'] as List?) ?? [];
    final desc = theory['chain_description'] as String? ?? '';
    final zeroNote = theory['zero_data_note'] as String? ?? '';

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _sectionLabel('BLOCK CHAIN', _yellow),
      const SizedBox(height: 12),
      _buildMaskedScroll(
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: blocks.asMap().entries.map<Widget>((e) {
            final b = e.value as Map<String, dynamic>;
            final isNew = b['is_new'] == true;
            return Row(children: [
              if (e.key > 0) _chainArrow(),
              _blockCard(b['num'] ?? '', b['hash'] ?? '', b['data'] ?? '', isNew),
            ]);
          }).toList()),
        ),
      ),
      const SizedBox(height: 14),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: _panelBg, borderRadius: BorderRadius.circular(12)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(desc, style: _bodyStyle()),
          if (zeroNote.isNotEmpty) ...[
            const SizedBox(height: 10),
            _highlightBox(zeroNote, _green),
          ],
        ]),
      ),
    ]);
  }

  Widget _blockCard(String num, String hash, String data, bool isNew) {
    return Container(
      width: 95,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _panelBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isNew ? _blue : _cardBorder, width: isNew ? 2 : 1),
        boxShadow: isNew ? [BoxShadow(color: _blue.withValues(alpha: 0.25), blurRadius: 14, spreadRadius: 1)] : null,
      ),
      child: Column(children: [
        Text(num, style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w700, color: _blue.withValues(alpha: 0.6), letterSpacing: 0.5)),
        const SizedBox(height: 4),
        Text(hash, style: GoogleFonts.jetBrainsMono(fontSize: 7, color: Colors.white24)),
        const SizedBox(height: 4),
        Text(data, style: GoogleFonts.inter(fontSize: 9, color: Colors.white60)),
      ]),
    );
  }

  Widget _chainArrow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 28, height: 2,
          decoration: BoxDecoration(color: _blue.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(1), boxShadow: [BoxShadow(color: _blue.withValues(alpha: 0.15), blurRadius: 6)]),
        ),
        const SizedBox(height: 2),
        Text('prev_hash', style: GoogleFonts.jetBrainsMono(fontSize: 6, color: _blue.withValues(alpha: 0.3))),
      ]),
    );
  }

  Widget _buildQBFTView(Map<String, dynamic> theory) {
    final healthyRounds = (theory['qbft_healthy_rounds'] as List?) ?? [];
    final faultScenarios = (theory['fault_scenarios'] as Map<String, dynamic>?) ?? {};
    final validators = (theory['validators'] as List?)?.cast<String>() ?? ['V1', 'V2', 'V3', 'V4'];

    // Determine which rounds to use
    List currentRounds;
    if (_qbftFault != null && faultScenarios.containsKey(_qbftFault)) {
      final scenario = faultScenarios[_qbftFault!] as Map<String, dynamic>;
      currentRounds = (scenario['rounds'] as List?) ?? [];
    } else {
      currentRounds = healthyRounds;
    }
    if (currentRounds.isEmpty) return const SizedBox.shrink();

    final step = _qbftStep % currentRounds.length;
    final round = currentRounds[step] as Map<String, dynamic>;
    final roundLabel = round['round'] as String? ?? '';
    final states = (round['states'] as List?)?.cast<String>() ?? [];
    final votes = (round['votes'] as List?)?.cast<String>() ?? [];
    final desc = round['desc'] as String? ?? '';

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Fault scenario buttons
      _buildMaskedScroll(
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _faultBtn(null, 'All healthy', Icons.check_circle_outline_rounded, _green),
              ...faultScenarios.entries.map((e) {
                final key = e.key;
                final scenario = e.value as Map<String, dynamic>;
                final label = scenario['label'] as String? ?? key;
                final iconName = scenario['icon'] as String? ?? 'warning';
                return _faultBtn(key, label, _faultIcon(iconName), _red);
              }),
            ],
          ),
        ),
      ),
      const SizedBox(height: 14),

      _sectionLabel(roundLabel, _qbftFault != null ? _red : _green),
      const SizedBox(height: 14),

      // QBFT square layout
      LayoutBuilder(builder: (context, constraints) {
        final size = math.min(constraints.maxWidth * 0.7, 280.0);
        return Center(
          child: SizedBox(
            width: size,
            height: size,
            child: CustomPaint(
              painter: _QBFTLinkPainter(size: size, activeStates: states),
              child: Stack(children: [
                _qbftNodeAt(0, size, validators, states, votes),
                _qbftNodeAt(1, size, validators, states, votes),
                _qbftNodeAt(2, size, validators, states, votes),
                _qbftNodeAt(3, size, validators, states, votes),
              ]),
            ),
          ),
        );
      }),
      const SizedBox(height: 14),

      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: _panelBg, borderRadius: BorderRadius.circular(12)),
        child: Text(desc, style: _bodyStyle()),
      ),
    ]);
  }

  Widget _faultBtn(String? key, String label, IconData icon, Color color) {
    final isActive = _qbftFault == key;
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => setState(() { _qbftFault = key; _qbftStep = 0; }),
          borderRadius: BorderRadius.circular(24),
          child: AnimatedContainer(
            duration: 200.ms,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isActive ? color.withValues(alpha: 0.15) : Colors.transparent,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: isActive ? color.withValues(alpha: 0.6) : Colors.white.withValues(alpha: 0.15), width: 1.5),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(isActive ? Icons.check_circle_rounded : icon, size: 14, color: isActive ? color : Colors.white70),
              const SizedBox(width: 6),
              Text(label, style: GoogleFonts.inter(fontSize: 12, fontWeight: isActive ? FontWeight.w700 : FontWeight.w500, color: isActive ? color : Colors.white70)),
            ]),
          ),
        ),
      ),
    );
  }

  IconData _faultIcon(String name) {
    switch (name) {
      case 'warning': return Icons.warning_amber_rounded;
      case 'power_off': return Icons.power_off_rounded;
      case 'wifi_off': return Icons.wifi_off_rounded;
      default: return Icons.error_outline_rounded;
    }
  }

  Widget _qbftNodeAt(int index, double containerSize, List<String> labels, List<String> states, List<String> votes) {
    final state = index < states.length ? states[index] : 'idle';
    final vote = index < votes.length ? votes[index] : '';
    final label = index < labels.length ? labels[index] : 'V${index + 1}';

    final isPartA = state == 'partitioned_a';
    final isPartB = state == 'partitioned_b';
    final nodeColor = state == 'proposer'
        ? _blue
        : (state == 'voter' || state == 'finalized')
            ? _green
            : isPartA
                ? _blue
                : isPartB
                    ? _violet
                    : (state == 'faulty' || state == 'malicious' || state == 'crashed' || state == 'partitioned' || state == 'excluded')
                        ? _red
                        : Colors.white54;

    final nodeIcon = (state == 'faulty' || state == 'malicious')
        ? Icons.warning_amber_rounded
        : state == 'crashed'
            ? Icons.power_off_rounded
            : (state == 'partitioned' || isPartA || isPartB)
                ? Icons.wifi_off_rounded
                : state == 'excluded'
                    ? Icons.block_rounded
                    : state == 'finalized'
                        ? Icons.check_circle_rounded
                        : Icons.dns_rounded;

    const nodeSize = 72.0;
    final dx = (index == 0 || index == 2) ? 0.0 : containerSize - nodeSize;
    final dy = (index == 0 || index == 1) ? 0.0 : containerSize - nodeSize;

    return Positioned(
      left: dx, top: dy,
      child: AnimatedContainer(
        duration: 300.ms,
        width: nodeSize,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: nodeColor.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: nodeColor.withValues(alpha: 0.5), width: 1.5),
          boxShadow: [BoxShadow(color: nodeColor.withValues(alpha: 0.15), blurRadius: 10)],
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(nodeIcon, size: 16, color: nodeColor),
          const SizedBox(height: 3),
          Text(label, style: GoogleFonts.inter(fontSize: 8, fontWeight: FontWeight.w700, color: nodeColor), textAlign: TextAlign.center),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(color: nodeColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20)),
            child: Text(vote, style: GoogleFonts.inter(fontSize: 7, fontWeight: FontWeight.w700, color: nodeColor)),
          ),
        ]),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // T5: SSI / DID
  // ═══════════════════════════════════════════════════════════
  Widget _buildSSIDID(Map<String, dynamic> theory, String mode) {
    final entities = (theory['entities'] as List?) ?? [];
    final explanations = (theory['explanations'] as Map<String, dynamic>?) ?? {};
    final text = explanations[mode] as String? ?? '';

    return LayoutBuilder(builder: (context, constraints) {
      final isNarrow = constraints.maxWidth < 500;

      final grid = Column(children: [
        IntrinsicHeight(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Expanded(child: _entityCard(entities.isNotEmpty ? entities[0] as Map<String, dynamic> : {}, mode)),
          const SizedBox(width: 8),
          Expanded(child: _entityCard(entities.length > 1 ? entities[1] as Map<String, dynamic> : {}, mode)),
        ])),
        const SizedBox(height: 8),
        IntrinsicHeight(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Expanded(child: _entityCard(entities.length > 2 ? entities[2] as Map<String, dynamic> : {}, mode)),
          const SizedBox(width: 8),
          Expanded(child: _entityCard(entities.length > 3 ? entities[3] as Map<String, dynamic> : {}, mode)),
        ])),
      ]);

      final explainer = Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: _panelBg, borderRadius: BorderRadius.circular(12)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _sectionLabel(mode == 'enroll' ? 'ENROLLMENT' : (mode == 'present' ? 'VERIFICATION' : (mode == 'revoke' ? 'REVOCATION' : 'REISSUANCE')),
              mode == 'revoke' ? _green : (mode == 'present' ? _green : (mode == 'reissue' ? _green : _green))),
          const SizedBox(height: 8),
          Text(text, style: _bodyStyle()),
        ]),
      );

      if (isNarrow) return Column(children: [grid, const SizedBox(height: 14), explainer]);
      return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: grid),
        const SizedBox(width: 14),
        Expanded(child: explainer),
      ]);
    });
  }

  Widget _entityCard(Map<String, dynamic> entity, String activeMode) {
    if (entity.isEmpty) return const SizedBox.shrink();
    final label = entity['label'] as String? ?? '';
    final sub = entity['sub'] as String? ?? '';
    final activeIn = (entity['active_in'] as List?)?.cast<String>() ?? [];
    final isActive = activeIn.contains(activeMode);
    final iconName = entity['icon'] as String? ?? 'person';
    final icon = _ssiIcon(iconName);

    return AnimatedContainer(
      duration: 300.ms,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isActive ? _green.withValues(alpha: 0.08) : _panelBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isActive ? _green.withValues(alpha: 0.5) : _cardBorder, width: isActive ? 1.5 : 1),
        boxShadow: isActive ? [BoxShadow(color: _green.withValues(alpha: 0.15), blurRadius: 10)] : null,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 22, color: isActive ? _green : Colors.white24),
        const SizedBox(height: 8),
        Text(label, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: isActive ? Colors.white : Colors.white54)),
        const SizedBox(height: 4),
        Text(sub, style: GoogleFonts.inter(fontSize: 9, color: isActive ? Colors.white54 : Colors.white24, height: 1.4)),
        if (isActive)
          Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(color: _green.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)),
            child: Text('ACTIVE', style: GoogleFonts.inter(fontSize: 7, fontWeight: FontWeight.w700, color: _green, letterSpacing: 0.5)),
          ),
      ]),
    );
  }

  IconData _ssiIcon(String name) {
    switch (name) {
      case 'person': return Icons.person_rounded;
      case 'account_balance': return Icons.account_balance_rounded;
      case 'verified_user': return Icons.verified_user_rounded;
      case 'link': return Icons.link_rounded;
      default: return Icons.circle;
    }
  }

  // ═══════════════════════════════════════════════════════════
  // Shared helpers
  // ═══════════════════════════════════════════════════════════
  TextStyle _bodyStyle() => GoogleFonts.inter(fontSize: 14, color: Colors.white.withValues(alpha: 0.65), height: 1.6);

  Widget _sectionLabel(String text, Color color) {
    return Text(text.toUpperCase(), style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: color, letterSpacing: 0.6));
  }

  Widget _pill(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.15), border: Border.all(color: color.withValues(alpha: 0.3)), borderRadius: BorderRadius.circular(20)),
      child: Text(text, style: GoogleFonts.inter(fontSize: 8, fontWeight: FontWeight.w700, color: color)),
    );
  }

  Widget _highlightBox(String text, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(8), border: Border.all(color: color.withValues(alpha: 0.15))),
      child: Text(text, style: GoogleFonts.inter(fontSize: 10, color: color.withValues(alpha: 0.7), height: 1.5)),
    );
  }

  Widget _glowArrow(Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Container(
        decoration: BoxDecoration(boxShadow: [BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 6)]),
        child: Icon(Icons.arrow_forward_rounded, size: 14, color: color),
      ),
    );
  }

  Widget _buildMaskedScroll(Widget child) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 600;
        if (!isNarrow) return child;

        return SizedBox(
          width: double.infinity,
          child: ShaderMask(
            shaderCallback: (Rect bounds) => const LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [Colors.white, Colors.white, Colors.transparent],
              stops: [0.0, 0.92, 1.0],
            ).createShader(bounds),
            blendMode: BlendMode.dstIn,
            child: child,
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════
// Custom painters
// ═══════════════════════════════════════════════════════════

class _TripletLinePainter extends CustomPainter {
  final double ax, ay, px, py, nx, ny;
  final Color pullColor, pushColor;
  final bool glow;
  _TripletLinePainter({required this.ax, required this.ay, required this.px, required this.py, required this.nx, required this.ny, required this.pullColor, required this.pushColor, this.glow = false});

  @override
  void paint(Canvas canvas, Size size) {
    final pullPaint = Paint()..color = pullColor..strokeWidth = glow ? 2.0 : 1.5..style = PaintingStyle.stroke;
    final pushPaint = Paint()..color = pushColor..strokeWidth = glow ? 2.0 : 1.5..style = PaintingStyle.stroke;
    if (glow) {
      final pullGlow = Paint()..color = pullColor.withValues(alpha: 0.2)..strokeWidth = 6..style = PaintingStyle.stroke..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
      final pushGlow = Paint()..color = pushColor.withValues(alpha: 0.2)..strokeWidth = 6..style = PaintingStyle.stroke..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
      canvas.drawLine(Offset(ax, ay), Offset(px, py), pullGlow);
      canvas.drawLine(Offset(ax, ay), Offset(nx, ny), pushGlow);
    }
    canvas.drawLine(Offset(ax, ay), Offset(px, py), pullPaint);
    canvas.drawLine(Offset(ax, ay), Offset(nx, ny), pushPaint);
  }

  @override
  bool shouldRepaint(covariant _TripletLinePainter old) => ax != old.ax || px != old.px || nx != old.nx || glow != old.glow;
}

class _QBFTLinkPainter extends CustomPainter {
  final double size;
  final List<String> activeStates;
  _QBFTLinkPainter({required this.size, required this.activeStates});

  @override
  void paint(Canvas canvas, Size canvasSize) {
    const nodeSize = 72.0;
    final centers = [
      Offset(nodeSize / 2, nodeSize / 2),
      Offset(size - nodeSize / 2, nodeSize / 2),
      Offset(nodeSize / 2, size - nodeSize / 2),
      Offset(size - nodeSize / 2, size - nodeSize / 2),
    ];

    const badStates = ['faulty', 'malicious', 'crashed', 'partitioned', 'excluded'];
    for (int i = 0; i < centers.length; i++) {
      for (int j = i + 1; j < centers.length; j++) {
        final stateI = i < activeStates.length ? activeStates[i] : 'idle';
        final stateJ = j < activeStates.length ? activeStates[j] : 'idle';

        // Partition: same group = connected, cross-group = severed
        final isPartitioned = (stateI.startsWith('partitioned_') || stateJ.startsWith('partitioned_'));
        final samePartition = isPartitioned && stateI == stateJ;
        final crossPartition = isPartitioned && stateI != stateJ;

        final isBad = crossPartition || badStates.contains(stateI) || badStates.contains(stateJ);
        final isHonest = samePartition || (!isBad && stateI != 'idle' && stateJ != 'idle');

        final Color color;
        if (crossPartition) {
          color = const Color(0xFF1a1010);
        } else if (samePartition) {
          color = stateI == 'partitioned_a' ? const Color(0xFFE97316) : const Color(0xFFA78BFA);
        } else if (isBad) {
          color = const Color(0xFF1a1010);
        } else if (isHonest) {
          color = const Color(0xFF38BDF8);
        } else {
          color = const Color(0xFF1e3a55);
        }

        if (isHonest) {
          final glowPaint = Paint()..color = color.withValues(alpha: 0.15)..strokeWidth = 5..style = PaintingStyle.stroke..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
          canvas.drawLine(centers[i], centers[j], glowPaint);
        }

        final paint = Paint()..color = color.withValues(alpha: (isBad && !samePartition) ? 0.1 : 0.5)..strokeWidth = (isBad && !samePartition) ? 0.5 : 1.5..style = PaintingStyle.stroke;
        canvas.drawLine(centers[i], centers[j], paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _QBFTLinkPainter old) => activeStates != old.activeStates;
}
