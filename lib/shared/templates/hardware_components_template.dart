import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class HardwareComponentsTemplate extends StatelessWidget {
  final Map<String, dynamic> data;
  const HardwareComponentsTemplate({super.key, required this.data});

  static const _panel = Color(0xFF071428);
  static const _accent = Color(0xFF38BDF8);

  @override
  Widget build(BuildContext context) {
    final title = data['title'] as String? ?? '';
    final subtitle = data['subtitle'] as String? ?? '';
    final components =
        (data['components'] as List?)?.cast<Map<String, dynamic>>() ?? [];

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
        Builder(
          builder: (context) {
            final isNarrow = MediaQuery.of(context).size.width < 700;
            if (isNarrow) {
              return Column(
                children: [
                  for (int i = 0; i < components.length; i++) ...[
                    _buildComponentCard(components[i]),
                    if (i < components.length - 1) const SizedBox(height: 16),
                  ],
                ],
              );
            }
            return IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: components.asMap().entries.map((e) {
                  return Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                          right:
                              e.key < components.length - 1 ? 16.0 : 0),
                      child: _buildComponentCard(e.value),
                    ),
                  );
                }).toList(),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildComponentCard(Map<String, dynamic> comp) {
    return Container(
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _accent.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 8))
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Image / Icon area
          Container(
            height: 180,
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                  bottom:
                      BorderSide(color: _accent.withValues(alpha: 0.2))),
            ),
            child: comp['image'] != null
                ? Builder(
                    builder: (context) {
                      // Apply specific scaling factors to compensate for built-in 
                      // image whitespace without editing the PNGs manually.
                      double scale = 1.0;
                      if (comp['id'] == 'scanner') scale = 1;
                      if (comp['id'] == 'display') scale = 1;
                      if (comp['id'] == 'camera') scale = 1;

                      return Transform.scale(
                        scale: scale,
                        child: Image.asset(comp['image'], fit: BoxFit.contain),
                      );
                    },
                  )
                : Stack(
                    alignment: Alignment.center,
                    children: [
                      Icon(Icons.memory,
                          size: 64, color: _accent.withValues(alpha: 0.2)),
                      Positioned(
                        bottom: 12,
                        child: Text('Placeholder: ${comp['id']}',
                            style: GoogleFonts.jetBrainsMono(
                                color: _accent.withValues(alpha: 0.5),
                                fontSize: 10)),
                      )
                    ],
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  comp['name'] as String? ?? 'Component',
                  style: GoogleFonts.spaceGrotesk(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      height: 1.2),
                ),
                const SizedBox(height: 12),
                Text(
                  comp['role'] as String? ?? '',
                  style: GoogleFonts.inter(
                      fontSize: 13, color: Colors.white70, height: 1.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
