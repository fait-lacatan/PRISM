import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class SpecGridTemplate extends StatelessWidget {
  final Map<String, dynamic> data;
  final Color accent;

  const SpecGridTemplate({
    super.key,
    required this.data,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final title = data['title'] ?? 'Specifications';
    final description = data['description'] ?? '';
    final List<dynamic> cards = data['cards'] ?? [];

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
        LayoutBuilder(
          builder: (context, constraints) {
            // Determine column count based on width.
            int crossAxisCount = 1;
            if (constraints.maxWidth > 800) {
              crossAxisCount = 3;
            } else if (constraints.maxWidth > 500) {
              crossAxisCount = 2;
            }

            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                mainAxisExtent: 300, // Fixed height or could use StaggeredGridView
              ),
              itemCount: cards.length,
              itemBuilder: (context, index) {
                final card = cards[index] as Map<String, dynamic>;
                return _SpecCard(card: card, accent: accent);
              },
            );
          },
        ),
      ],
    );
  }
}

class _SpecCard extends StatelessWidget {
  final Map<String, dynamic> card;
  final Color accent;

  const _SpecCard({required this.card, required this.accent});

  @override
  Widget build(BuildContext context) {
    final category = card['category'] ?? 'Category';
    final specs = card['specs'] as Map<String, dynamic>? ?? {};

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E24), // M3 Surface Variant
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.category, color: accent, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  category,
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: Colors.white10),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.separated(
              itemCount: specs.length,
              separatorBuilder: (context, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final key = specs.keys.elementAt(index);
                final val = specs[key].toString();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      key,
                      style: GoogleFonts.firaCode(
                        fontSize: 12,
                        color: accent,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      val,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
