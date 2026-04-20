import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// S5: Privacy-preservation animated explainer with flow diagrams.
class PrivacyExplainerTemplate extends StatefulWidget {
  final Map<String, dynamic> data;
  final Color accent;
  const PrivacyExplainerTemplate({super.key, required this.data, required this.accent});

  @override
  State<PrivacyExplainerTemplate> createState() => _PrivacyExplainerTemplateState();
}

class _PrivacyExplainerTemplateState extends State<PrivacyExplainerTemplate>
    with TickerProviderStateMixin {
  int _selectedIndex = -1;
  late final AnimationController _pulseCtrl;
  late final AnimationController _scanCtrl;
  late final AnimationController _dotCtrl;

  static const _violet = Color(0xFFA78BFA);
  static const _orange = Color(0xFFE97316);
  static const _blue = Color(0xFF38BDF8);
  static const _green = Color(0xFF86EFAC);

  Map<String, dynamic> get _d => widget.data;
  List get _techniques => (_d['techniques'] as List?) ?? [];

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..repeat(reverse: true);
    _scanCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))..repeat();
    _dotCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 2000))..repeat();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _scanCtrl.dispose();
    _dotCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = _d['title'] ?? '';
    final subtitle = _d['subtitle'] ?? '';

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        // Wide: 5-across single row; medium: 3; narrow: horizontal scroll strip
        final useScrollStrip = w < 450;

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

            // Technique cards
            if (useScrollStrip)
              // Narrow: horizontal scroll strip — all cards same compact size
              SizedBox(
                height: 90,
                child: _buildMaskedScroll(
                  ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _techniques.length,
                    separatorBuilder: (context, idx) => const SizedBox(width: 8),
                    itemBuilder: (context, i) {
                      final tech = _techniques[i] as Map<String, dynamic>;
                      final isSelected = i == _selectedIndex;
                      return _buildCard(tech, isSelected, i, 150);
                    },
                  ),
                ),
              )
            else
              // Wide/medium: wrap grid
              Builder(
                builder: (context) {
                  final cols = w >= 700 ? 5 : 3;
                  final spacing = 8.0;
                  final cardW = (w - spacing * (cols - 1)) / cols;
                  return Wrap(
                    spacing: spacing,
                    runSpacing: spacing,
                    children: List.generate(_techniques.length, (i) {
                      final tech = _techniques[i] as Map<String, dynamic>;
                      final isSelected = i == _selectedIndex;
                      return _buildCard(tech, isSelected, i, cardW);
                    }),
                  );
                },
              ),

            // Animated explainer panel
            AnimatedSize(
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: _selectedIndex >= 0 ? _buildExplainer() : const SizedBox.shrink(),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCard(Map<String, dynamic> tech, bool isSelected, int i, double width) {
    return SizedBox(
      width: width,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => setState(() => _selectedIndex = _selectedIndex == i ? -1 : i),
          borderRadius: BorderRadius.circular(14),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFF120f25) : const Color(0xFF0f1e30),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected ? _violet : Colors.white.withValues(alpha: 0.06),
                width: 1.5,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  tech['title'] ?? '',
                  style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  tech['subtitle'] ?? '',
                  style: GoogleFonts.inter(fontSize: 9, color: Colors.white54, height: 1.4),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    ).animate().fadeIn(delay: (i * 60).ms, duration: 300.ms);
  }

  Widget _buildExplainer() {
    final tech = _techniques[_selectedIndex] as Map<String, dynamic>;
    final flowType = tech['flow_type'] ?? '';
    final desc = tech['description'] ?? '';
    final techTitle = tech['title'] ?? '';

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF0d1525),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _violet.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(techTitle, style: GoogleFonts.spaceGrotesk(fontSize: 14, fontWeight: FontWeight.w700, color: _violet)),
          const SizedBox(height: 14),
          _buildFlowDiagram(flowType),
          const SizedBox(height: 14),
          Text(desc, style: GoogleFonts.inter(fontSize: 12, color: Colors.white.withValues(alpha: 0.65), height: 1.55)),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.03);
  }

  Widget _buildFlowDiagram(String type) {
    // Use LayoutBuilder to make flow diagrams responsive
    return LayoutBuilder(
      builder: (context, constraints) {
        final boxW = (constraints.maxWidth < 400) ? 70.0 : 80.0;
        final boxH = 48.0;

        switch (type) {
          case 'cancel':
            return _cancelableFlow(boxW, boxH);
          case 'gan':
            return _ganFlow(boxW, boxH);
          case 'zkp':
            return _zkpFlow(boxW, boxH);
          case 'homo':
            return _homoFlow(boxW, boxH);
          case 'crypto':
            return _cryptoFlow(boxW, boxH);
          default:
            return const SizedBox.shrink();
        }
      },
    );
  }

  Widget _cancelableFlow(double boxW, double boxH) {
    return _buildMaskedScroll(
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
        children: [
          _animBox('Raw\nTemplate', const Color(0xFF152a40), _blue, boxW, boxH, scanAnim: true),
          _animArrow(_violet),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Key K', style: GoogleFonts.inter(fontSize: 9, color: Colors.white38)),
              const SizedBox(height: 2),
              Text('⊕', style: TextStyle(fontSize: 18, color: _violet)),
              Text('Irreversible\ntransform', textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 8, fontWeight: FontWeight.w700, color: _violet)),
            ],
          ),
          _animArrow(_violet),
          _animBox('Protected\nTemplate', const Color(0xFF120f25), _violet, boxW, boxH),
        ],
      ),
    ));
  }

  Widget _ganFlow(double boxW, double boxH) {
    return AnimatedBuilder(
      animation: _pulseCtrl,
      builder: (context, _) {
        final opacity = 0.5 + 0.5 * _pulseCtrl.value;
        return _buildMaskedScroll(
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
            children: [
              _animBox('Real\nTemplate', const Color(0xFF152a40), Colors.white70, boxW, boxH),
              _animArrow(_violet),
              Opacity(opacity: opacity, child: _animBox('Generator\nG', const Color(0xFF1a1535), _violet, boxW, boxH)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Text('↔', style: TextStyle(fontSize: 14, color: _violet.withValues(alpha: 0.5))),
              ),
              Opacity(opacity: opacity, child: _animBox('Discrim.\nD', const Color(0xFF0f1a10), _green, boxW, boxH)),
              _animArrow(_orange),
              _animBox('Synthetic\nTemplate', const Color(0xFF1a100d), _orange, boxW, boxH),
            ],
          ),
        ));
      },
    );
  }

  Widget _zkpFlow(double boxW, double boxH) {
    return AnimatedBuilder(
      animation: _dotCtrl,
      builder: (context, _) {
        return _buildMaskedScroll(
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
            children: [
              _animBox('Prover\n(has secret)', const Color(0xFF152a40), Colors.white70, boxW, boxH),
              _dotLine(_violet, _dotCtrl.value),
              _animBox('ZK Proof\n(zkSNARK)', const Color(0xFF1a1535), _violet, boxW, boxH),
              _dotLine(_violet, (_dotCtrl.value + 0.4) % 1.0),
              _animBox('Verifier\n(no secret)', const Color(0xFF0f1a10), _green, boxW, boxH),
            ],
          ),
        ));
      },
    );
  }

  Widget _homoFlow(double boxW, double boxH) {
    return _buildMaskedScroll(
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
        children: [
          _animBox('Plain\nTemplate', const Color(0xFF152a40), Colors.white70, boxW, boxH),
          _animArrow(_violet),
          _animBox('Encrypt\n(HE)', const Color(0xFF1a1535), _violet, boxW, boxH),
          _animArrow(_violet),
          _animBox('Encrypted\nMatch ✓', const Color(0xFF120f25), _violet, boxW, boxH),
        ],
      ),
    ));
  }

  Widget _cryptoFlow(double boxW, double boxH) {
    return _buildMaskedScroll(
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
        children: [
          _animBox('Bio\nFeature', const Color(0xFF152a40), Colors.white70, boxW, boxH),
          _animArrow(_blue),
          _animBox('Fuzzy\nExtractor', const Color(0xFF152a40), _blue, boxW, boxH),
          _animArrow(_blue),
          _animBox('Crypto\nKey K', const Color(0xFF152a40), _blue, boxW, boxH),
        ],
      ),
    ));
  }

  Widget _animBox(String label, Color bg, Color textColor, double w, double h, {bool scanAnim = false}) {
    return Container(
      width: w, height: h,
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: textColor.withValues(alpha: 0.3)),
      ),
      child: Stack(
        children: [
          if (scanAnim)
            AnimatedBuilder(
              animation: _scanCtrl,
              builder: (context, _) {
                return Positioned(
                  left: 0, right: 0,
                  top: _scanCtrl.value * h,
                  child: Container(height: 2, color: _blue),
                );
              },
            ),
          Center(
            child: Text(label, textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w700, color: textColor, height: 1.3)),
          ),
        ],
      ),
    );
  }

  Widget _animArrow(Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5),
      child: Text('→', style: TextStyle(fontSize: 16, color: color.withValues(alpha: 0.5))),
    );
  }

  Widget _dotLine(Color color, double progress) {
    return SizedBox(
      width: 36, height: 16,
      child: Stack(
        children: [
          Positioned(left: 0, right: 0, top: 7, child: Container(height: 2, color: color.withValues(alpha: 0.15))),
          Positioned(
            left: progress * 28,
            top: 4,
            child: Container(
              width: 8, height: 8,
              decoration: BoxDecoration(shape: BoxShape.circle, color: color),
            ),
          ),
        ],
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
