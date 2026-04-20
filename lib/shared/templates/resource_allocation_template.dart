import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ResourceAllocationTemplate extends StatelessWidget {
  final Map<String, dynamic> data;
  const ResourceAllocationTemplate({super.key, required this.data});

  static const _panel = Color(0xFF071428);
  static const _line = Color(0xFF1E3A5C);

  Color _parseColor(String? hex) {
    if (hex == null || hex.isEmpty) return const Color(0xFF38BDF8);
    final hexCode = hex.replaceAll('#', '');
    return Color(int.parse('FF$hexCode', radix: 16));
  }

  @override
  Widget build(BuildContext context) {
    final title = data['title'] as String? ?? '';
    final subtitle = data['subtitle'] as String? ?? '';
    final specs =
        (data['specs'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final cores =
        (data['cores'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: GoogleFonts.spaceGrotesk(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: Colors.white)),
          if (subtitle.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(subtitle,
                style: GoogleFonts.inter(fontSize: 14, color: Colors.white70)),
          ],
          const SizedBox(height: 24),

          // Specs Line
          Wrap(
            spacing: 16,
            runSpacing: 12,
            children: specs.map((s) {
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(12),
                    border:
                        Border.all(color: _line.withValues(alpha: 0.5))),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('${s['label']}: ',
                        style: GoogleFonts.inter(
                            fontSize: 12,
                            color: Colors.white54,
                            fontWeight: FontWeight.w500)),
                    Text('${s['value']}',
                        style: GoogleFonts.inter(
                            fontSize: 12,
                            color: Colors.white,
                            fontWeight: FontWeight.w700)),
                  ],
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 32),

          // Core Allocation blocks
          Builder(builder: (context) {
            final isNarrow = MediaQuery.of(context).size.width < 600;
            final blocks = _buildCoreBlocks(cores, !isNarrow);
            return isNarrow
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: blocks,
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: blocks,
                  );
          }),
        ],
      ),
    );
  }

  List<Widget> _buildCoreBlocks(List<Map<String, dynamic>> cores, bool isRow) {
    final widgets = <Widget>[];
    for (int i = 0; i < cores.length; i++) {
      final item = cores[i];
      final count = item['count'] as int? ?? 1;
      final label = item['label'] as String? ?? 'Core';
      final color = _parseColor(item['color'] as String?);

      final card = Container(
        margin: EdgeInsets.only(
          right: (isRow && i < cores.length - 1) ? 16 : 0,
          bottom: (!isRow && i < cores.length - 1) ? 12 : 16,
        ),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.4), width: 1.5),
          boxShadow: [
            BoxShadow(
                color: color.withValues(alpha: 0.15),
                blurRadius: 16,
                offset: const Offset(0, 4))
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$count',
                style: GoogleFonts.spaceGrotesk(
                    fontSize: 48,
                    fontWeight: FontWeight.w800,
                    color: color,
                    height: 1.0)),
            Text(count == 1 ? 'core' : 'cores',
                style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: color.withValues(alpha: 0.8),
                    letterSpacing: 1.0)),
            const SizedBox(height: 16),
            Text(label,
                style: GoogleFonts.spaceGrotesk(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    height: 1.2)),
          ],
        ),
      );

      widgets.add(isRow ? Expanded(flex: count, child: card) : card);
    }
    return widgets;
  }
}
