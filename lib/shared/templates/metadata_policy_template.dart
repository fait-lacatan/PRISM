import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class MetadataPolicyTemplate extends StatelessWidget {
  final Map<String, dynamic> data;
  const MetadataPolicyTemplate({super.key, required this.data});

  static const _panel = Color(0xFF071428);

  @override
  Widget build(BuildContext context) {
    final title = data['title'] as String? ?? '';
    final description = data['description'] as String? ?? '';
    final items = (data['items'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final warning = data['warning'] as String? ?? '';

    final screenWidth = MediaQuery.of(context).size.width;
    final isNarrow = screenWidth < 700;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title.isNotEmpty)
          Text(title,
              style: GoogleFonts.spaceGrotesk(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: Colors.white)),
        const SizedBox(height: 12),
        if (description.isNotEmpty)
          Text(description,
              style: GoogleFonts.inter(
                  fontSize: 15, color: Colors.white70, height: 1.6)),
        const SizedBox(height: 24),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: isNarrow ? 1 : 2,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            mainAxisExtent: 140,
          ),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            final name = item['name'] as String? ?? '';
            final source = item['source'] as String? ?? '';
            final desc = item['desc'] as String? ?? '';

            return Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _panel,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF1E3A5C)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        name,
                        style: GoogleFonts.jetBrainsMono(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF38BDF8)),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E3A5C).withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.source_outlined,
                                size: 12, color: Colors.white70),
                            const SizedBox(width: 6),
                            Text(
                              source,
                              style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: Text(
                      desc,
                      style: GoogleFonts.inter(
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.8),
                          height: 1.4),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        if (warning.isNotEmpty) ...[
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF450A0A).withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFF87171)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.privacy_tip_outlined,
                    color: Color(0xFFF87171)),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    warning,
                    style: GoogleFonts.inter(
                        fontSize: 14,
                        color: const Color(0xFFFECACA),
                        fontWeight: FontWeight.w500,
                        height: 1.5),
                  ),
                ),
              ],
            ),
          )
        ]
      ],
    );
  }
}
