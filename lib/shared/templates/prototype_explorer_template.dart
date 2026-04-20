import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class PrototypeExplorerTemplate extends StatefulWidget {
  final Map<String, dynamic> data;
  const PrototypeExplorerTemplate({super.key, required this.data});

  @override
  State<PrototypeExplorerTemplate> createState() =>
      _PrototypeExplorerTemplateState();
}

class _PrototypeExplorerTemplateState extends State<PrototypeExplorerTemplate> {
  static const _accent = Color(0xFF38BDF8);

  // Dynamic grid from manifest
  int? _rows;
  int? _cols;
  bool _isLoading = true;

  // View state
  double _colAccumulator = 3.0; // Offset for an oblique starting angle
  int _colIndex = 3;
  double _rowAccumulator = 3.0; // Starts roughly at center row
  int _rowIndex = 3;

  // Interaction
  bool _isInteracting = false;

  @override
  void initState() {
    super.initState();
    _loadManifest();
  }

  Future<void> _loadManifest() async {
    try {
      final jsonStr = await rootBundle.loadString('assets/images/hardware/spinner_sphere/manifest.json');
      final manifest = jsonDecode(jsonStr);
      
      if (mounted) {
        setState(() {
          _rows = manifest['rows'];
          _cols = manifest['cols'];
          _rowAccumulator = (_rows! / 2).floorToDouble();
          _rowIndex = _rowAccumulator.round();
          
          // Set starting column to ~45 degree oblique angle based on total columns
          _colAccumulator = (_cols! / 8).roundToDouble();
          _colIndex = _colAccumulator.round() % _cols!;
          _isLoading = false;
        });

        // Pre-cache
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          for (int r = 0; r < _rows!; r++) {
            for (int c = 0; c < _cols!; c++) {
              precacheImage(ResizeImage(AssetImage(_getFramePath(r, c)), width: 600), context);
            }
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _rows = 7;
          _cols = 24;
          _colAccumulator = 3.0;
          _colIndex = 3;
          _isLoading = false;
        });
      }
    }
  }

  void _updateIndices() {
    if (_cols == null || _rows == null) return;
    
    // Wrap columns
    if (_colAccumulator < 0) _colAccumulator += _cols!;
    if (_colAccumulator >= _cols!) _colAccumulator -= _cols!;
    _colIndex = _colAccumulator.floor() % _cols!;

    // Clamp rows
    _rowAccumulator = _rowAccumulator.clamp(0.0, _rows! - 1.0);
    _rowIndex = _rowAccumulator.round();
  }

  String _getFramePath(int row, int col) {
    // frame_r00_c00.png formatting
    final rStr = row.toString().padLeft(2, '0');
    final cStr = col.toString().padLeft(2, '0');
    return 'assets/images/hardware/spinner_sphere/frame_r${rStr}_c$cStr.png';
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.data['title'] as String? ?? 'Kiosk Prototype';
    final subtitle = widget.data['subtitle'] as String? ?? '';
    final description = widget.data['description'] as String? ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
        const SizedBox(height: 16),

        // Interactive Sphere Viewer (No Background)
        GestureDetector(
          onPanDown: (_) {
            setState(() {
              _isInteracting = true;
            });
          },
          onPanUpdate: (details) {
            setState(() {
              // X drag translates to column wrapping
              _colAccumulator -= details.delta.dx * 0.05;
              // Y drag translates to row clamping (inverted so drag down = look up/top)
              _rowAccumulator += details.delta.dy * 0.05;
              _updateIndices();
            });
          },
          onPanEnd: (_) {
            setState(() {
              _isInteracting = false;
            });
          },
          onPanCancel: () {
            setState(() {
              _isInteracting = false;
            });
          },
          child: SizedBox(
             // Removed the Container & BoxDecoration from the previous iteration 
             // to keep the 3D model clean on the black background per user request.
            height: 420,
            width: double.infinity,
            child: _isLoading 
                ? const Center(child: CircularProgressIndicator(color: _accent))
                : Stack(
              alignment: Alignment.center,
              children: [
                // Gapless playback to prevent flickering
                Image.asset(
                  _getFramePath(_rowIndex, _colIndex),
                  fit: BoxFit.contain,
                  gaplessPlayback: true,
                  cacheWidth: 600,
                ),
                
                // Hint pill at bottom
                Positioned(
                  bottom: 8,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 300),
                    opacity: _isInteracting ? 0.0 : 1.0,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.swipe,
                            color: Colors.white.withValues(alpha: 0.35),
                            size: 14),
                        const SizedBox(width: 6),
                        Text('Drag fully to view 360°',
                            style: GoogleFonts.inter(
                                fontSize: 11,
                                color: Colors.white.withValues(alpha: 0.35))),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),
        Text(description,
            style: GoogleFonts.inter(
                fontSize: 15, color: Colors.white70, height: 1.6)),
      ],
    );
  }
}
