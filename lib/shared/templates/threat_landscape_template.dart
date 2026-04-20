import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Linear face-off threat landscape: actors on the left,
/// assets on the right, with animated projectile beams between them.
class ThreatLandscapeTemplate extends StatefulWidget {
  final Map<String, dynamic> data;
  const ThreatLandscapeTemplate({super.key, required this.data});

  @override
  State<ThreatLandscapeTemplate> createState() =>
      _ThreatLandscapeTemplateState();
}

class _ThreatLandscapeTemplateState extends State<ThreatLandscapeTemplate>
    with SingleTickerProviderStateMixin {
  late AnimationController _anim;
  int? _focusedActor;
  int _frame = 0;
  final List<_Particle> _particles = [];
  final List<double> _flash = List.filled(10, 0);
  final Random _rng = Random();

  late List<Map<String, dynamic>> _assets;
  late List<Map<String, dynamic>> _actors;

  @override
  void initState() {
    super.initState();
    _assets =
        (widget.data['assets'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    _actors =
        (widget.data['actors'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..addListener(_tick);
    _anim.repeat();
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  void _tick() {
    _frame++;
    if (_frame % 50 == 0 && _actors.isNotEmpty) {
      final ai = _focusedActor ?? _rng.nextInt(_actors.length);
      final actor = _actors[ai];
      final tgts = (actor['targets'] as List?)?.cast<int>() ?? [];
      if (tgts.isNotEmpty) {
        final ti = tgts[_rng.nextInt(tgts.length)];
        _particles.add(_Particle(
          actorIndex: ai,
          targetIndex: ti,
          t: 0,
          speed: 0.008 + _rng.nextDouble() * 0.005,
          radius: 2.5 + _rng.nextDouble() * 1.5,
        ));
      }
    }
    for (final p in _particles) {
      if (!p.alive) continue;
      if (p.phase == _PPhase.go) {
        p.t += p.speed;
        if (p.t >= 1) {
          p.phase = _PPhase.hit;
          p.t = 1;
          if (p.targetIndex < _flash.length) {
            _flash[p.targetIndex] = 20;
          }
        }
      } else {
        p.hitT = (p.hitT ?? 0) + 0.08;
        if ((p.hitT ?? 0) > 1) p.alive = false;
      }
    }
    _particles.removeWhere((p) => !p.alive);
    for (int i = 0; i < _flash.length; i++) {
      _flash[i] = max(0, _flash[i] - 1);
    }
  }



  Color _parseHex(String hex) {
    hex = hex.replaceFirst('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    return Color(int.parse(hex, radix: 16));
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.data['title'] as String? ?? '';
    final desc = widget.data['description'] as String? ?? '';
    final screenW = MediaQuery.of(context).size.width;
    final isNarrow = screenW < 600;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title.isNotEmpty)
          Text(title,
              style: GoogleFonts.spaceGrotesk(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: Colors.white)),
        const SizedBox(height: 24),

        // Choice chips for actor selection
        Builder(
          builder: (context) {
            final surfaceColor = Theme.of(context).scaffoldBackgroundColor;
            Widget scrollView = SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildCustomChip(
                    label: 'All Actors',
                    isActive: _focusedActor == null,
                    color: Colors.white,
                    onTap: () => setState(() => _focusedActor = null),
                  ),
                  const SizedBox(width: 8),
                  ..._actors.asMap().entries.map((e) {
                    final labelColor = _parseHex(e.value['labelColor'] as String? ?? '#E879F9');
                    final isSelected = _focusedActor == e.key;
                    final label = e.value['short'] as String? ?? e.value['name'] as String? ?? '';
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: _buildCustomChip(
                        label: label,
                        isActive: isSelected,
                        color: labelColor,
                        onTap: () => setState(() => _focusedActor = e.key),
                      ),
                    );
                  }),
                ],
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

        // Graph-view canvas — actors scattered, assets in column
        LayoutBuilder(builder: (ctx, constraints) {
          final w = constraints.maxWidth;
          final assetCount = _assets.length;
          final assetRowH = isNarrow ? 42.0 : 56.0;
          final canvasH = isNarrow
              ? max(assetCount * assetRowH + 50, 380.0)
              : max(assetCount * assetRowH + 50, 500.0);

          return RepaintBoundary(
            child: GestureDetector(
              onTapDown: (d) =>
                  _handleTap(d, w, canvasH, isNarrow),
              child: AnimatedBuilder(
                animation: _anim,
                builder: (context, _) {
                  return CustomPaint(
                    size: Size(w, canvasH),
                    painter: _LinearPainter(
                      assets: _assets,
                      actors: _actors,
                      focusedActor: _focusedActor,
                      particles: _particles,
                      flash: _flash,
                      width: w,
                      height: canvasH,
                      isNarrow: isNarrow,
                      frame: _frame,
                    ),
                  );
                },
              ),
            ),
          );
        }),

        // Attack vectors panel
        Container(
          width: double.infinity,
          margin: const EdgeInsets.only(top: 12),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.transparent,
            border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
            borderRadius: BorderRadius.circular(16),
          ),
          child: _focusedActor == null
              ? Text(
                  desc.isNotEmpty
                      ? desc
                      : 'Select any threat actor to focus their attack vectors.',
                  style: GoogleFonts.inter(
                      fontSize: 14,
                      height: 1.5,
                      color: Colors.white54,
                      fontStyle: FontStyle.italic),
                )
              : _buildActorDetail(_actors[_focusedActor!]),
        ),

        // Legend
        const SizedBox(height: 10),
        _buildLegend(),
      ],
    );
  }

  Widget _buildActorDetail(Map<String, dynamic> actor) {
    final name = (actor['name'] as String? ?? '').replaceAll('\n', ' ');
    final labelColor =
        _parseHex(actor['labelColor'] as String? ?? '#E879F9');
    final vectors = (actor['vectors'] as List?)?.cast<String>() ?? [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(name,
            style: GoogleFonts.spaceGrotesk(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: labelColor)),
        const SizedBox(height: 8),
        Text('Attack vectors against PRISM assets:',
            style: GoogleFonts.inter(fontSize: 14, color: Colors.white.withValues(alpha: 0.6))),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: vectors
              .map((v) => Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                      border:
                          Border.all(color: labelColor.withValues(alpha: 0.4)),
                    ),
                    child: Text(v,
                        style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.white70)),
                  ))
              .toList(),
        ),
      ],
    );
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

  Widget _buildLegend() {
    return Wrap(
      spacing: 14,
      runSpacing: 6,
      children: [
        _legendDot(const Color(0xFFEF4444), 'Critical'),
        _legendDot(const Color(0xFFF97316), 'High'),
        _legendDot(const Color(0xFFFBBF24), 'Medium'),
        _legendDot(const Color(0xFF38BDF8), 'Low / public'),
        Container(width: 1, height: 14, color: const Color(0xFF1A2D42)),
        _legendLine('Attack path'),
      ],
    );
  }

  Widget _legendDot(Color c, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(shape: BoxShape.circle, color: c)),
        const SizedBox(width: 5),
        Text(label,
            style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.white.withValues(alpha: 0.6))),
      ],
    );
  }

  Widget _legendLine(String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
            width: 28,
            height: 2,
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(1),
                color: const Color(0x66EF4444))),
        const SizedBox(width: 5),
        Text(label,
            style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.white.withValues(alpha: 0.6))),
      ],
    );
  }

  // Normalised scatter coords for up to 5 actors (xFrac, yFrac)
  // Spread across left ~40% and full height for Obsidian-style graph look
  static const _actorScatter = [
    (0.20, 0.10), // EXT  — top-center-left
    (0.08, 0.30), // THF  — far left, upper-mid
    (0.28, 0.42), // USR  — right of center, mid
    (0.12, 0.62), // ADM  — left, lower-mid
    (0.24, 0.82), // NST  — center-left, bottom
  ];

  void _handleTap(
      TapDownDetails d, double w, double h, bool isNarrow) {
    final actorNodeR = isNarrow ? 18.0 : 28.0;
    final hitR = actorNodeR + 14;

    int? hit;
    for (int i = 0; i < _actors.length; i++) {
      if (i >= _actorScatter.length) break;
      final s = _actorScatter[i];
      final ax = s.$1 * w;
      final ay = s.$2 * h;
      final dx = d.localPosition.dx - ax;
      final dy = d.localPosition.dy - ay;
      if (dx * dx + dy * dy < hitR * hitR) {
        hit = i;
        break;
      }
    }
    setState(() {
      _focusedActor = (hit != null && hit != _focusedActor) ? hit : null;
    });
  }
}

// --- Graph Painter ---

class _LinearPainter extends CustomPainter {
  final List<Map<String, dynamic>> assets;
  final List<Map<String, dynamic>> actors;
  final int? focusedActor;
  final List<_Particle> particles;
  final List<double> flash;
  final double width;
  final double height;
  final bool isNarrow;
  final int frame;

  static const _cc = {
    'critical': (Color(0xFF3D0A0A), Color(0xFFEF4444), Color(0xFFFCA5A5)),
    'high': (Color(0xFF3D1A05), Color(0xFFF97316), Color(0xFFFED7AA)),
    'medium': (Color(0xFF3D2C05), Color(0xFFFBBF24), Color(0xFFFEF08A)),
    'low': (Color(0xFF051D3D), Color(0xFF38BDF8), Color(0xFFBAE6FD)),
  };

  // Same scatter table as the widget (normalised xFrac, yFrac)
  static const _scatter = [
    (0.20, 0.10), // EXT
    (0.08, 0.30), // THF
    (0.28, 0.42), // USR
    (0.12, 0.62), // ADM
    (0.24, 0.82), // NST
  ];

  _LinearPainter({
    required this.assets,
    required this.actors,
    required this.focusedActor,
    required this.particles,
    required this.flash,
    required this.width,
    required this.height,
    required this.isNarrow,
    required this.frame,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final assetColX = isNarrow ? width * 0.82 : width * 0.85;
    final actorNodeR = isNarrow ? 18.0 : 28.0;
    final assetNodeR = isNarrow ? 14.0 : 18.0;

    // Actor positions — Obsidian-style scatter
    final actorPositions = <Offset>[];
    for (int i = 0; i < actors.length; i++) {
      if (i < _scatter.length) {
        actorPositions.add(Offset(
          _scatter[i].$1 * width,
          _scatter[i].$2 * height,
        ));
      }
    }

    // Asset positions — evenly spaced column on the right
    final assetPositions = <Offset>[];
    final assetSpacing = height / (assets.length + 1);
    for (int i = 0; i < assets.length; i++) {
      assetPositions.add(Offset(assetColX, assetSpacing * (i + 1)));
    }

    // Column headers
    final headerStyle = TextStyle(
      color: const Color(0xFF667788),
      fontSize: isNarrow ? 8.0 : 9.0,
      fontWeight: FontWeight.w700,
      fontFamily: 'JetBrains Mono',
      letterSpacing: 0.5,
    );
    _drawText(canvas, 'THREAT ACTORS', Offset(width * 0.16, 8), headerStyle);
    _drawText(canvas, 'SYSTEM ASSETS', Offset(assetColX, 8), headerStyle);

    // Attack path curves
    for (int ai = 0; ai < actors.length; ai++) {
      if (focusedActor != null && ai != focusedActor) continue;
      final actor = actors[ai];
      final col = _parseHex(actor['color'] as String? ?? '#C026D3');
      final tgts = (actor['targets'] as List?)?.cast<int>() ?? [];
      final isFocused = focusedActor != null;

      for (final ti in tgts) {
        if (ti >= assetPositions.length) continue;
        final from = actorPositions[ai];
        final to = assetPositions[ti];

        final path = Path();
        path.moveTo(from.dx + actorNodeR + 4, from.dy);
        final cpx = width / 2;
        path.cubicTo(
            cpx, from.dy, cpx, to.dy, to.dx - assetNodeR - 4, to.dy);

        final p = Paint()
          ..color = col.withValues(alpha: isFocused ? 0.35 : 0.18)
          ..strokeWidth = isFocused ? 1.5 : 1.0
          ..style = PaintingStyle.stroke;
        _drawDashedPath(canvas, path, p);
      }
    }

    // Actor nodes
    for (int i = 0; i < actors.length; i++) {
      final actor = actors[i];
      final pos = actorPositions[i];
      final col = _parseHex(actor['color'] as String? ?? '#C026D3');
      final lc = _parseHex(actor['labelColor'] as String? ?? '#E879F9');
      final dim = focusedActor != null && i != focusedActor;
      final isSel = focusedActor == i;

      // Outer glow
      canvas.drawCircle(
          pos,
          actorNodeR + 6,
          Paint()
            ..color = col.withValues(alpha: dim ? 0.02 : (isSel ? 0.22 : 0.1))
            ..style = PaintingStyle.fill);

      // Node body
      canvas.drawCircle(
          pos,
          actorNodeR,
          Paint()
            ..color = col.withValues(alpha: dim ? 0.05 : 0.2)
            ..style = PaintingStyle.fill);
      canvas.drawCircle(
          pos,
          actorNodeR,
          Paint()
            ..color = col.withValues(alpha: dim ? 0.12 : (isSel ? 1.0 : 0.6))
            ..style = PaintingStyle.stroke
            ..strokeWidth = isSel ? 2.5 : 1.5);

      // Short label inside
      _drawText(
          canvas,
          actor['short'] as String? ?? '',
          pos,
          TextStyle(
              color: lc.withValues(alpha: dim ? 0.15 : 1.0),
              fontSize: isNarrow ? 8.0 : 12.0,
              fontWeight: FontWeight.w700,
              fontFamily: 'DM Sans'));

      // Name label to the right of bubble
      final nameLines = (actor['name'] as String? ?? '').split('\n');
      for (int j = 0; j < nameLines.length; j++) {
        _drawText(
            canvas,
            nameLines[j],
            Offset(pos.dx + actorNodeR + 10, pos.dy - 5 + j * 11),
            TextStyle(
                color: lc.withValues(alpha: dim ? 0.12 : 0.8),
                fontSize: isNarrow ? 7.0 : 9.0,
                fontWeight: FontWeight.w600,
                fontFamily: 'DM Sans'),
            center: false);
      }
    }

    // Asset nodes
    for (int i = 0; i < assets.length; i++) {
      final a = assets[i];
      final pos = assetPositions[i];
      final cc = _cc[a['confidentiality'] ?? 'low'] ?? _cc['low']!;
      final fl = i < flash.length ? flash[i] / 20 : 0.0;

      // Flash ring
      if (fl > 0) {
        canvas.drawCircle(
            pos,
            assetNodeR + 6 + fl * 10,
            Paint()
              ..color = cc.$2.withValues(alpha: fl * 0.6)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2);
      }

      // Node
      canvas.drawCircle(
          pos,
          assetNodeR,
          Paint()
            ..color = fl > 0.1 ? cc.$2.withValues(alpha: 0.25) : cc.$1
            ..style = PaintingStyle.fill);
      canvas.drawCircle(
          pos,
          assetNodeR,
          Paint()
            ..color = fl > 0.1 ? cc.$2 : cc.$2.withValues(alpha: 0.6)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5);

      // Label inside
      final label =
          (a['short'] as String? ?? a['name'] as String? ?? '').split('\n');
      for (int j = 0; j < label.length; j++) {
        _drawText(
            canvas,
            label[j],
            Offset(pos.dx, pos.dy - (label.length > 1 ? 4 : 0) + j * 9),
            TextStyle(
                color: cc.$3,
                fontSize: isNarrow ? 6.5 : 8.0,
                fontWeight: FontWeight.w700,
                fontFamily: 'DM Sans'));
      }

      // Name label to the left
      _drawText(
          canvas,
          a['name'] as String? ?? '',
          Offset(pos.dx - assetNodeR - 8, pos.dy),
          TextStyle(
              color: cc.$3.withValues(alpha: 0.7),
              fontSize: isNarrow ? 7.0 : 8.5,
              fontWeight: FontWeight.w600,
              fontFamily: 'DM Sans'),
          center: false,
          alignRight: true);
    }

    // "Tap a threat actor" prompt when none selected
    if (focusedActor == null) {
      final pulse = (sin(frame * 0.06) * 0.5 + 0.5).clamp(0.0, 1.0);
      _drawText(
          canvas,
          '\u25C0  TAP A THREAT ACTOR TO FOCUS  \u25B6',
          Offset(width / 2, height - 12),
          TextStyle(
              color: Color.fromRGBO(120, 160, 200, 0.2 + pulse * 0.25),
              fontSize: isNarrow ? 8.0 : 10.0,
              fontWeight: FontWeight.w700,
              fontFamily: 'JetBrains Mono',
              letterSpacing: 1.0));
    }

    // Particles
    for (final p in particles) {
      if (!p.alive || p.phase != _PPhase.go) continue;
      if (p.actorIndex >= actorPositions.length ||
          p.targetIndex >= assetPositions.length) {
        continue;
      }
      final from = actorPositions[p.actorIndex];
      final to = assetPositions[p.targetIndex];
      final cpx = width / 2;
      final pos = _cubicBez(
          from.dx + actorNodeR + 4,
          from.dy,
          cpx,
          from.dy,
          cpx,
          to.dy,
          to.dx - assetNodeR - 4,
          to.dy,
          p.t);

      canvas.drawCircle(
          pos,
          p.radius,
          Paint()
            ..color = const Color(0xFFEF4444)
            ..style = PaintingStyle.fill);
      if (p.t > 0.05) {
        final prev = _cubicBez(
            from.dx + actorNodeR + 4,
            from.dy,
            cpx,
            from.dy,
            cpx,
            to.dy,
            to.dx - assetNodeR - 4,
            to.dy,
            p.t - 0.05);
        canvas.drawCircle(
            prev,
            p.radius * 0.5,
            Paint()
              ..color = const Color(0x88F97316)
              ..style = PaintingStyle.fill);
      }
    }
  }

  Offset _cubicBez(double x0, double y0, double cx1, double cy1,
      double cx2, double cy2, double x3, double y3, double t) {
    final mt = 1 - t;
    final x = mt * mt * mt * x0 +
        3 * mt * mt * t * cx1 +
        3 * mt * t * t * cx2 +
        t * t * t * x3;
    final y = mt * mt * mt * y0 +
        3 * mt * mt * t * cy1 +
        3 * mt * t * t * cy2 +
        t * t * t * y3;
    return Offset(x, y);
  }

  void _drawText(Canvas c, String text, Offset pos, TextStyle style,
      {bool center = true, bool alignRight = false}) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    );
    tp.layout();
    final dx = alignRight
        ? pos.dx - tp.width
        : (center ? pos.dx - tp.width / 2 : pos.dx);
    final dy = center ? pos.dy - tp.height / 2 : pos.dy - tp.height / 2;
    tp.paint(c, Offset(dx, dy));
  }

  void _drawDashedPath(Canvas c, Path path, Paint p) {
    final metrics = path.computeMetrics();
    for (final m in metrics) {
      double dist = 0;
      while (dist < m.length) {
        final end = min(dist + 3, m.length);
        final seg = m.extractPath(dist, end);
        c.drawPath(seg, p);
        dist += 5;
      }
    }
  }

  Color _parseHex(String hex) {
    hex = hex.replaceFirst('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    return Color(int.parse(hex, radix: 16));
  }

  @override
  bool shouldRepaint(covariant _LinearPainter old) => true;
}

enum _PPhase { go, hit }

class _Particle {
  int actorIndex;
  int targetIndex;
  double t;
  double speed;
  double radius;
  _PPhase phase;
  double? hitT;
  bool alive;

  _Particle({
    required this.actorIndex,
    required this.targetIndex,
    required this.t,
    required this.speed,
    required this.radius,
  })  : phase = _PPhase.go,
        alive = true;
}
