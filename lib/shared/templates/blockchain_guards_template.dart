import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Interactive 22-guard grid with category filters.
/// Wide: grid (left) + detail panel (right) side-by-side.
/// Narrow: grid stacked above detail panel.
class BlockchainGuardsTemplate extends StatefulWidget {
  final Map<String, dynamic> data;
  const BlockchainGuardsTemplate({super.key, required this.data});

  @override
  State<BlockchainGuardsTemplate> createState() =>
      _BlockchainGuardsTemplateState();
}

class _BlockchainGuardsTemplateState extends State<BlockchainGuardsTemplate> {
  String _filterCat = 'all';
  int? _openIndex;

  Map<String, dynamic> _catDef(String key) {
    final cats =
        (widget.data['categories'] as Map<String, dynamic>?) ?? {};
    return (cats[key] as Map<String, dynamic>?) ??
        {'color': '#ffffff', 'label': key};
  }

  Color _parseHex(String hex) {
    hex = hex.replaceFirst('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    return Color(int.parse(hex, radix: 16));
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.data['title'] as String? ?? '';
    final guards =
        (widget.data['guards'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final cats =
        (widget.data['categories'] as Map<String, dynamic>?) ?? {};

    final filtered = _filterCat == 'all'
        ? guards
        : guards.where((g) => g['cat'] == _filterCat).toList();

    final isNarrow = MediaQuery.of(context).size.width < 700;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title.isNotEmpty)
          Text(title,
              style: GoogleFonts.spaceGrotesk(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: Colors.white)),
        const SizedBox(height: 16),

        // Filter chips (Choice chips with ShaderMask)
        Builder(
          builder: (context) {
            final surfaceColor = Theme.of(context).scaffoldBackgroundColor;
            Widget scrollView = SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildCustomChip(
                    label: 'All 22',
                    isActive: _filterCat == 'all',
                    color: Colors.white,
                    onTap: () => setState(() { _filterCat = 'all'; _openIndex = null; }),
                  ),
                  const SizedBox(width: 8),
                  ...cats.entries.map((e) {
                    final labelColor = _parseHex((e.value as Map<String, dynamic>)['color'] as String? ?? '#fff');
                    final isSelected = _filterCat == e.key;
                    final label = (e.value as Map<String, dynamic>)['label'] as String? ?? e.key;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: _buildCustomChip(
                        label: label,
                        isActive: isSelected,
                        color: labelColor,
                        onTap: () => setState(() { _filterCat = e.key; _openIndex = null; }),
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

        // Layout: side-by-side on wide, stacked on narrow
        if (isNarrow) ...[
          // Narrow: grid first, detail below
          _buildGrid(filtered, guards, isNarrow),
          if (_openIndex != null && _openIndex! < guards.length) ...[
            const SizedBox(height: 10),
            _buildDetailPanel(guards[_openIndex!], isNarrow),
          ],
        ] else
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Grid on left — compact
              Expanded(
                flex: 5,
                child: _buildGrid(filtered, guards, isNarrow),
              ),
              const SizedBox(width: 12),
              // Detail on right
              Expanded(
                flex: 7,
                child: _openIndex != null && _openIndex! < guards.length
                    ? _buildDetailPanel(guards[_openIndex!], isNarrow)
                    : Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.transparent,
                          border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Center(
                          child: Text(
                            'Select a guard to view\nattack vector & mitigation',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                                fontSize: 14,
                                height: 1.5,
                                color: Colors.white54,
                                fontStyle: FontStyle.italic),
                          ),
                        ),
                      ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildGrid(List<Map<String, dynamic>> filtered,
      List<Map<String, dynamic>> guards, bool isNarrow) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: isNarrow ? 4 : 4,
        mainAxisSpacing: 4,
        crossAxisSpacing: 4,
        childAspectRatio: isNarrow ? 1.2 : 1.3,
      ),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final g = filtered[index];
        final realIndex = guards.indexOf(g);
        final cat = _catDef(g['cat'] as String? ?? 'rbac');
        final col = _parseHex(cat['color'] as String? ?? '#38BDF8');
        final isOpen = _openIndex == realIndex;

        return InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            setState(() {
              _openIndex = _openIndex == realIndex ? null : realIndex;
            });
          },
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              decoration: BoxDecoration(
                color: isOpen
                    ? col.withValues(alpha: 0.18)
                    : Colors.transparent,
                border: Border(
                  left: BorderSide(
                      color: col,
                      width: isOpen ? 4 : 3),
                  top: BorderSide(
                      color: isOpen
                          ? col.withValues(alpha: 0.35)
                          : Colors.white.withValues(alpha: 0.15)),
                  right: BorderSide(
                      color: isOpen
                          ? col.withValues(alpha: 0.35)
                          : Colors.white.withValues(alpha: 0.15)),
                  bottom: BorderSide(
                      color: isOpen
                          ? col.withValues(alpha: 0.35)
                          : Colors.white.withValues(alpha: 0.15)),
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(g['id'] as String? ?? '',
                      style: GoogleFonts.jetBrainsMono(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isOpen ? Colors.white : col)),
                  const SizedBox(height: 2),
                  Text(g['name'] as String? ?? '',
                      style: GoogleFonts.inter(
                          fontSize: 9,
                          color: Colors.white70,
                          height: 1.3),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ),
        );
      },
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

  Widget _buildDetailPanel(Map<String, dynamic> g, bool isNarrow) {
    final cat = _catDef(g['cat'] as String? ?? 'rbac');
    final col = _parseHex(cat['color'] as String? ?? '#38BDF8');

    return AnimatedSize(
      duration: const Duration(milliseconds: 250),
      child: Container(
        width: double.infinity,
        key: ValueKey('detail-${g['id']}'),
        decoration: BoxDecoration(
          color: Colors.transparent,
          border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Text(g['id'] as String? ?? '',
                    style: GoogleFonts.jetBrainsMono(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: col)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(g['name'] as String? ?? '',
                          style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Colors.white)),
                      const SizedBox(height: 4),
                      Text(g['layer'] as String? ?? '',
                          style: GoogleFonts.inter(
                              fontSize: 12, color: Colors.white54)),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: col.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: col.withValues(alpha: 0.16)),
                  ),
                  child: Text(cat['label'] as String? ?? '',
                      style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: col)),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Attack / Guard split — always stacked here to save space
            _buildAtkBox(g['attack'] as String? ?? ''),
            const SizedBox(height: 8),
            _buildGrdBox(g['guard'] as String? ?? ''),


          ],
        ),
      ),
    );
  }

  Widget _buildAtkBox(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF1A0808),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0x28EF4444)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('ATTACK VECTOR',
              style: GoogleFonts.jetBrainsMono(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFFEF4444),
                  letterSpacing: 0.8)),
          const SizedBox(height: 5),
          Text(text,
              style: GoogleFonts.inter(
                  fontSize: 13,
                  color: const Color(0xFFFCA5A5),
                  height: 1.5)),
        ],
      ),
    );
  }

  Widget _buildGrdBox(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF071A0E),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0x2822C55E)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('GUARD MITIGATION',
              style: GoogleFonts.jetBrainsMono(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF22C55E),
                  letterSpacing: 0.8)),
          const SizedBox(height: 5),
          Text(text,
              style: GoogleFonts.inter(
                  fontSize: 13,
                  color: const Color(0xFF86EFAC),
                  height: 1.5)),
        ],
      ),
    );
  }

}
