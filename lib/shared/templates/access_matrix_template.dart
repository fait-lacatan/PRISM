import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math' as math;

class AccessMatrixTemplate extends StatelessWidget {
  final Map<String, dynamic> data;
  const AccessMatrixTemplate({super.key, required this.data});

  static const _panel = Color(0xFF071428);

  Color _getStatusColor(String val) {
    final v = val.toLowerCase();
    if (v.contains('denied') || v.contains('ban')) return Colors.redAccent;
    if (v.contains('authorized') && !v.contains('[')) return Colors.greenAccent;
    if (v.contains('authorized') && v.contains('[')) return Colors.orangeAccent;
    if (v.contains('grant')) return Colors.blueAccent;
    return Colors.white70;
  }

  @override
  Widget build(BuildContext context) {
    final title = data['title'] as String? ?? '';
    final description = data['description'] as String? ?? '';
    final columns = (data['columns'] as List?)?.cast<String>() ?? [];
    final roles = (data['roles'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final footnotes = (data['footnotes'] as List?)?.cast<String>() ?? [];

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
        Builder(
          builder: (context) {
            final screenWidth = MediaQuery.of(context).size.width;
            final isNarrow = screenWidth < 800;
            // Renderer padding is max 128. Clamping minimum horizontal width to prevent layout bounds crash inside SingleChildScrollView.
            final containerWidth = screenWidth - (isNarrow ? 48 : 128);
            final minTableWidth = columns.length * 120.0 + 160.0;
            final safeWidth = math.max(minTableWidth, containerWidth - 24);

            return Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: _panel,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF1E3A5C)),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 16)
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minWidth: safeWidth),
                  child: DataTable(
                    headingRowColor: WidgetStateProperty.all(
                        const Color(0xFF1E3A5C).withValues(alpha: 0.5)),
                    dataRowMinHeight: 60,
                    dataRowMaxHeight: 76,
                    columns: [
                      DataColumn(
                          label: Text('Role / Capability',
                              style: GoogleFonts.spaceGrotesk(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  fontSize: 13))),
                      ...columns.map((col) => DataColumn(
                              label: Expanded(
                            child: Text(col,
                                textAlign: TextAlign.center,
                                style: GoogleFonts.spaceGrotesk(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white70,
                                    fontSize: 12)),
                          ))),
                    ],
                    rows: roles.map((roleData) {
                      final name = roleData['name'] as String? ?? '';
                      final flags = roleData['flags'] as String?;
                      final values =
                          (roleData['values'] as List?)?.cast<String>() ?? [];
                      return DataRow(
                        cells: [
                          DataCell(Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(name,
                                  style: GoogleFonts.inter(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                      fontSize: 14)),
                              if (flags != null)
                                Text(flags,
                                    style: GoogleFonts.jetBrainsMono(
                                        fontSize: 11, color: Colors.blueAccent)),
                            ],
                          )),
                          ...values.map((v) {
                            final c = _getStatusColor(v);
                            return DataCell(Center(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: c.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                      color: c.withValues(alpha: 0.3)),
                                ),
                                child: Text(v,
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.inter(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: c)),
                              ),
                            ));
                          }),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
            );
          },
        ),
        if (footnotes.isNotEmpty) ...[
          const SizedBox(height: 16),
          ...footnotes.map((fn) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(fn,
                    style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.white54,
                        fontStyle: FontStyle.italic)),
              ))
        ]
      ],
    );
  }
}
