import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class KioskShowcaseTemplate extends StatefulWidget {
  final Map<String, dynamic> data;
  final Color accent;

  const KioskShowcaseTemplate({
    super.key,
    required this.data,
    required this.accent,
  });

  @override
  State<KioskShowcaseTemplate> createState() => _KioskShowcaseTemplateState();
}

class _KioskShowcaseTemplateState extends State<KioskShowcaseTemplate> {
  Map<String, dynamic>? selectedComponent;

  @override
  Widget build(BuildContext context) {
    final title = widget.data['title'] ?? 'Kiosk Showcase';
    final description = widget.data['description'] ?? '';
    final components = widget.data['components'] as List<dynamic>? ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title.isNotEmpty) ...[
          Text(
            title,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (description.isNotEmpty) ...[
          Text(
            description,
            style: GoogleFonts.inter(
              fontSize: 16,
              color: Colors.white70,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 32),
        ],
        // M3 Content Area
        Container(
          height: 600,
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E24), // background
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white10),
          ),
          child: Row(
            children: [
              // Left side: Image with hotspots
              Expanded(
                flex: 2,
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(28),
                    bottomLeft: Radius.circular(28),
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Placeholder block for image
                      Container(
                        color: Colors.black45,
                        child: Center(
                          child: Icon(Icons.important_devices, size: 100, color: Colors.white24),
                        ),
                      ),
                      // Hotspots mapping
                      ...components.map((comp) {
                        final c = comp as Map<String, dynamic>;
                        final dx = (c['x'] as num).toDouble();
                        final dy = (c['y'] as num).toDouble();
                        final isSelected = selectedComponent == c;

                        return Positioned(
                          left: 0,
                          top: 0,
                          right: 0,
                          bottom: 0,
                          child: Align(
                            alignment: FractionalOffset(dx, dy),
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  selectedComponent = c;
                                });
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                width: isSelected ? 48 : 32,
                                height: isSelected ? 48 : 32,
                                decoration: BoxDecoration(
                                  color: isSelected ? widget.accent : widget.accent.withValues(alpha: 0.5),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: isSelected ? 3 : 1,
                                  ),
                                  boxShadow: [
                                    if (isSelected)
                                      BoxShadow(
                                        color: widget.accent.withValues(alpha: 0.6),
                                        blurRadius: 12,
                                        spreadRadius: 4,
                                      ),
                                  ],
                                ),
                                child: Icon(
                                  Icons.info_outline,
                                  color: Colors.white,
                                  size: isSelected ? 24 : 16,
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
              // Right side: Component details (M3 Card layout)
              Expanded(
                flex: 1,
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: selectedComponent == null
                      ? Center(
                          child: Text(
                            'Tap a hotspot to view details',
                            style: GoogleFonts.inter(fontSize: 16, color: Colors.white60),
                            textAlign: TextAlign.center,
                          ),
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              selectedComponent!['name'] ?? '',
                              style: GoogleFonts.spaceGrotesk(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: widget.accent,
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Divider(color: Colors.white24),
                            const SizedBox(height: 16),
                            Text(
                              'Specification',
                              style: GoogleFonts.firaCode(
                                fontSize: 13,
                                color: Colors.white54,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              selectedComponent!['spec'] ?? '',
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                color: Colors.white,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
