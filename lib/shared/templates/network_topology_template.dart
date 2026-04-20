import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math' as math;

class NetworkTopologyTemplate extends StatefulWidget {
  final Map<String, dynamic> data;
  const NetworkTopologyTemplate({super.key, required this.data});

  @override
  State<NetworkTopologyTemplate> createState() =>
      _NetworkTopologyTemplateState();
}

class _NetworkTopologyTemplateState extends State<NetworkTopologyTemplate>
    with SingleTickerProviderStateMixin {
  static const _panel = Color(0xFF071428);
  static const _accent = Color(0xFF38BDF8);
  static const _validator = Color(0xFF818CF8);

  late final AnimationController _animCtrl;

  @override
  void initState() {
    super.initState();
    _animCtrl =
        AnimationController(vsync: this, duration: const Duration(seconds: 4))
          ..repeat();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.data['title'] as String? ?? '';
    final subtitle = widget.data['subtitle'] as String? ?? '';
    final description = widget.data['description'] as String? ?? '';
    final numNodes = widget.data['nodes'] as int? ?? 4;
    final centerLabel = widget.data['center_label'] as String? ?? 'Switch';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title.isNotEmpty)
          Text(title,
              style: GoogleFonts.spaceGrotesk(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: Colors.white)),
        if (subtitle.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(subtitle,
              style: GoogleFonts.inter(fontSize: 16, color: _accent)),
        ],
        const SizedBox(height: 24),

        // Animated Topology View — no flutter_animate wrapper
        Container(
          height: 480,
          width: double.infinity,
          decoration: BoxDecoration(
            color: _panel,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFF1E3A5C)),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3), blurRadius: 20)
            ],
          ),
          child: AnimatedBuilder(
            animation: _animCtrl,
            builder: (context, child) {
              return CustomPaint(
                painter: _StarTopologyPainter(
                  nodes: numNodes,
                  centerLabel: centerLabel,
                  progress: _animCtrl.value,
                  accent: _accent,
                  validator: _validator,
                ),
              );
            },
          ),
        ),

        const SizedBox(height: 24),
        if (description.isNotEmpty)
          Text(description,
              style: GoogleFonts.inter(
                  fontSize: 15, color: Colors.white70, height: 1.6)),
      ],
    );
  }
}

class _StarTopologyPainter extends CustomPainter {
  final int nodes;
  final String centerLabel;
  final double progress;
  final Color accent;
  final Color validator;

  _StarTopologyPainter({
    required this.nodes,
    required this.centerLabel,
    required this.progress,
    required this.accent,
    required this.validator,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final center = Offset(cx, cy);
    
    // Responsive scaling for narrow mobile views
    final isNarrow = size.width < 450;
    final switchRadius = isNarrow ? 35.0 : 45.0;
    final nodeRadius = isNarrow ? 55.0 : 65.0;
    
    // Guarantee minimum distance so nodes NEVER overlap the center switch
    final minDistance = switchRadius + nodeRadius + 15.0;
    final radius = math.max(math.min(cx, cy) * 0.65, minDistance);

    final linePaint = Paint()
      ..color = const Color(0xFF1E3A5C)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final particlePaint1 = Paint()
      ..color = accent
      ..style = PaintingStyle.fill;
    final particlePaint2 = Paint()
      ..color = validator
      ..style = PaintingStyle.fill;

    // Draw links and particles
    for (int i = 0; i < nodes; i++) {
      final angle = (2 * math.pi * i / nodes) - math.pi / 2;
      final nodePos =
          Offset(cx + radius * math.cos(angle), cy + radius * math.sin(angle));

      canvas.drawLine(center, nodePos, linePaint);

      final tOut = (progress + (i * 0.25)) % 1.0;
      final pOutX = center.dx + (nodePos.dx - center.dx) * tOut;
      final pOutY = center.dy + (nodePos.dy - center.dy) * tOut;
      canvas.drawCircle(Offset(pOutX, pOutY), 4, particlePaint1);

      final tIn = (1.0 - ((progress + (i * 0.6)) % 1.0));
      final pInX = center.dx + (nodePos.dx - center.dx) * tIn;
      final pInY = center.dy + (nodePos.dy - center.dy) * tIn;
      canvas.drawCircle(Offset(pInX, pInY), 4, particlePaint2);
    }

    // Draw center Switch node
    final centerPaint = Paint()
      ..color = const Color(0xFF0B1D34)
      ..style = PaintingStyle.fill;
    final centerBorder = Paint()
      ..color = accent
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(center, switchRadius, centerPaint);
    canvas.drawCircle(center, switchRadius, centerBorder);

    final switchText = TextPainter(
      text: TextSpan(
          text: centerLabel,
          style: GoogleFonts.spaceGrotesk(
              fontSize: isNarrow ? 13 : 16,
              fontWeight: FontWeight.w700,
              color: Colors.white)),
      textDirection: TextDirection.ltr,
    )..layout();
    switchText.paint(
        canvas, Offset(cx - switchText.width / 2, cy - switchText.height / 2));

    // Draw Encapsulated Edge nodes
    for (int i = 0; i < nodes; i++) {
      final angle = (2 * math.pi * i / nodes) - math.pi / 2;
      final nodePos =
          Offset(cx + radius * math.cos(angle), cy + radius * math.sin(angle));

      canvas.drawCircle(nodePos, nodeRadius, centerPaint);
      canvas.drawCircle(
          nodePos,
          nodeRadius,
          Paint()
            ..color = validator.withValues(alpha: 0.6)
            ..strokeWidth = 2.0
            ..style = PaintingStyle.stroke);

      // Node Title
      final title = TextPainter(
        text: TextSpan(
            text: 'Node ${i + 1}',
            style: GoogleFonts.spaceGrotesk(
                fontSize: isNarrow ? 11 : 13,
                fontWeight: FontWeight.w700,
                color: Colors.white)),
        textDirection: TextDirection.ltr,
      )..layout();
      title.paint(canvas, Offset(nodePos.dx - title.width / 2, nodePos.dy - (isNarrow ? 32 : 40)));

      // Separator Line
      final lineW = isNarrow ? 35.0 : 45.0;
      final lineY = nodePos.dy - (isNarrow ? 18 : 22);
      canvas.drawLine(
        Offset(nodePos.dx - lineW, lineY),
        Offset(nodePos.dx + lineW, lineY),
        Paint()..color = validator.withValues(alpha: 0.3)..strokeWidth = 1,
      );

      // Inner Elements List
      final elements = ['• Biometrics', '• Validator', '• IPFS Sidecar'];
      double currentY = nodePos.dy - (isNarrow ? 10 : 12);

      for (var element in elements) {
        final elText = TextPainter(
          text: TextSpan(
              text: element,
              style: GoogleFonts.inter(
                  fontSize: isNarrow ? 8.5 : 10,
                  color: Colors.white.withValues(alpha: 0.8))),
          textDirection: TextDirection.ltr,
        )..layout();
        elText.paint(canvas, Offset(nodePos.dx - (isNarrow ? 28 : 35), currentY));
        currentY += (isNarrow ? 12 : 14);
      }
    }
  }

  @override
  bool shouldRepaint(_StarTopologyPainter oldDelegate) =>
      progress != oldDelegate.progress;
}
