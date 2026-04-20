import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class VisibilityMatrixTemplate extends StatelessWidget {
  final Map<String, dynamic> data;
  const VisibilityMatrixTemplate({super.key, required this.data});

  Color _fromHex(String hex) {
    hex = hex.replaceAll('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    return Color(int.parse(hex, radix: 16));
  }

  @override
  Widget build(BuildContext context) {
    final title = data['title'] as String? ?? '';
    final description = data['description'] as String? ?? '';
    final tiers = (data['tiers'] as List?)?.cast<Map<String, dynamic>>() ?? [];

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
        const SizedBox(height: 32),
        ...tiers.map((tier) {
          final actor = tier['actor'] as String? ?? '';
          final scope = tier['scope'] as String? ?? '';
          final decryption = tier['decryption'] as String? ?? '';
          final level = tier['level'] as int? ?? 1;
          final color = _fromHex(tier['color'] as String? ?? '#38BDF8');

          return Container(
            margin: const EdgeInsets.only(bottom: 24),
            decoration: BoxDecoration(
              color: const Color(0xFF071428),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: color.withValues(alpha: 0.3)),
              boxShadow: [
                BoxShadow(
                    color: color.withValues(alpha: 0.05),
                    blurRadius: 16,
                    spreadRadius: 2)
              ],
            ),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Level Indicator Strip
                  Container(
                    width: 8,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(23),
                      bottomLeft: Radius.circular(23),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                level == 1
                                    ? Icons.public
                                    : level == 2
                                        ? Icons.person_outline
                                        : Icons.shield,
                                color: color,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Text(
                                actor,
                                style: GoogleFonts.spaceGrotesk(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Builder(builder: (context) {
                          if (isNarrow) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _InfoBlock(
                                    title: 'Visibility Scope',
                                    content: scope,
                                    icon: Icons.visibility,
                                    color: const Color(0xFF94A3B8)),
                                const SizedBox(height: 16),
                                _InfoBlock(
                                    title: 'Decryption Capability',
                                    content: decryption,
                                    icon: Icons.lock_open,
                                    color: color),
                              ],
                            );
                          }
                          return IntrinsicHeight(
                            child: Row(
                              children: [
                                Expanded(
                                  child: _InfoBlock(
                                      title: 'Visibility Scope',
                                      content: scope,
                                      icon: Icons.visibility,
                                      color: const Color(0xFF94A3B8)),
                                ),
                                const SizedBox(width: 24),
                                Expanded(
                                  child: _InfoBlock(
                                      title: 'Decryption Capability',
                                      content: decryption,
                                      icon: Icons.lock_open,
                                      color: color),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      })
    ],
  );
}
}

class _InfoBlock extends StatelessWidget {
  final String title;
  final String content;
  final IconData icon;
  final Color color;

  const _InfoBlock(
      {required this.title,
      required this.content,
      required this.icon,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1D34),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1E3A5C)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 8),
              Text(
                title,
                style: GoogleFonts.inter(
                    fontSize: 12, fontWeight: FontWeight.w600, color: color),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Text(
              content,
              style: GoogleFonts.inter(
                  fontSize: 14, color: Colors.white.withValues(alpha: 0.9), height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
