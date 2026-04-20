import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AttackVectorsTemplate extends StatelessWidget {
  final Map<String, dynamic> data;
  const AttackVectorsTemplate({super.key, required this.data});

  Color _getImpactColor(String impact) {
    switch (impact.toLowerCase()) {
      case 'critical':
        return Colors.redAccent;
      case 'high':
        return Colors.orangeAccent;
      case 'medium':
        return Colors.amber;
      case 'low':
        return Colors.lightGreen;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = data['title'] as String? ?? 'Systemic Attack Vectors';
    final desc = data['description'] as String? ?? '';
    final categories = (data['categories'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title.isNotEmpty)
          Text(title,
              style: GoogleFonts.spaceGrotesk(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: Colors.white)),
        const SizedBox(height: 12),
        if (desc.isNotEmpty)
          Text(desc,
              style: GoogleFonts.inter(
                  fontSize: 16, color: Colors.white70, height: 1.6)),
        const SizedBox(height: 32),
        
        // We avoid ExpansionPanels to prevent Slivers layout bound panics during mouse tracking.
        // Instead, we just present them in grouped clean M3 cards.
        ...categories.map((cat) {
          final catName = cat['name'] as String? ?? 'Category';
          final vectors = (cat['vectors'] as List?)?.cast<Map<String, dynamic>>() ?? [];
          
          return Padding(
            padding: const EdgeInsets.only(bottom: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.shield_outlined, color: Colors.blueAccent),
                    const SizedBox(width: 8),
                    Text(catName,
                        style: GoogleFonts.spaceGrotesk(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: Colors.white)),
                  ],
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: vectors.map((v) => _buildVectorCard(v, context)).toList(),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildVectorCard(Map<String, dynamic> v, BuildContext context) {
    final isNarrow = MediaQuery.of(context).size.width < 800;
    final width = isNarrow ? double.infinity : 340.0;
    
    final impactColor = _getImpactColor(v['impact'] ?? 'Low');

    return Container(
      width: width,
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1E293B)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
               color: impactColor.withValues(alpha: 0.1),
               borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
               border: Border(bottom: BorderSide(color: impactColor.withValues(alpha: 0.3))),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black45,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                     v['id'] ?? '',
                     style: GoogleFonts.jetBrainsMono(
                       fontWeight: FontWeight.bold,
                       color: impactColor,
                       fontSize: 12,
                     )
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    v['attack'] ?? '',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          
          // Body
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Likelihood:', 
                       style: GoogleFonts.inter(fontSize: 12, color: Colors.white54)),
                    Text(v['likelihood'] ?? '', 
                       style: GoogleFonts.inter(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w500)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Impact:', 
                       style: GoogleFonts.inter(fontSize: 12, color: Colors.white54)),
                    Text(v['impact'] ?? '', 
                       style: GoogleFonts.inter(fontSize: 12, color: impactColor, fontWeight: FontWeight.bold)),
                  ],
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Divider(color: Color(0xFF1E293B), height: 1),
                ),
                Text('Mitigation', 
                   style: GoogleFonts.inter(fontSize: 11, color: Colors.blueAccent, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(v['mitigation'] ?? '', 
                   style: GoogleFonts.inter(fontSize: 13, color: Colors.white70)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
