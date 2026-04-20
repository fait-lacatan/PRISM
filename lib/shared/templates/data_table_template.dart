import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// A flexible template that renders interleaved prose paragraphs,
/// M3-styled data tables, and equation blocks from a JSON "blocks" array.
///
/// Supported block types:
///   {"type":"prose","text":"..."}
///   {"type":"table","caption":"...","headers":[...],"rows":[[...],...]}
///   {"type":"equation","label":"...","formula":"...","note":"..."}
class DataTableTemplate extends StatelessWidget {
  final Map<String, dynamic> data;
  final Color accent;

  const DataTableTemplate({
    super.key,
    required this.data,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final List<dynamic> blocks = data['blocks'] ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < blocks.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 32),
            child: _buildBlock(blocks[i] as Map<String, dynamic>, i),
          ),
      ],
    );
  }

  Widget _buildBlock(Map<String, dynamic> block, int index) {
    final type = block['type'] ?? 'prose';
    switch (type) {
      case 'table':
        return _TableBlock(block: block, accent: accent, index: index);
      case 'equation':
        return _EquationBlock(block: block, accent: accent, index: index);
      case 'image':
        return _ImageBlock(block: block, index: index);
      case 'prose':
      default:
        return _ProseBlock(block: block, index: index);
    }
  }
}

// ─── Image Block ─────────────────────────────────────────────────────────────

class _ImageBlock extends StatelessWidget {
  final Map<String, dynamic> block;
  final int index;

  const _ImageBlock({required this.block, required this.index});

  @override
  Widget build(BuildContext context) {
    final multiImages = block['images'] as List?;
    final ratioStr = block['aspect_ratio'] as String?;
    double? aspect;
    if (ratioStr != null) {
      final parts = ratioStr.split(':');
      if (parts.length == 2) {
        final w = double.tryParse(parts[0]);
        final h = double.tryParse(parts[1]);
        if (w != null && h != null) aspect = w / h;
      }
    }

    final screenW = MediaQuery.of(context).size.width;
    final isNarrow = screenW < 600;

    if (multiImages != null && multiImages.isNotEmpty) {
      if (isNarrow) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: multiImages.map((img) {
            final i = img as Map<String, dynamic>;
            final src = i['src'] ?? '';
            final caption = i['caption'] ?? '';
            return Padding(
              padding: EdgeInsets.only(bottom: img == multiImages.last ? 0 : 20),
              child: _buildSingleImage(src, caption, aspect),
            );
          }).toList(),
        );
      } else {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: multiImages.map((img) {
            final i = img as Map<String, dynamic>;
            final src = i['src'] ?? '';
            final caption = i['caption'] ?? '';
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: img == multiImages.last ? 0 : 12),
                child: _buildSingleImage(src, caption, aspect),
              ),
            );
          }).toList(),
        );
      }
    }

    final src = block['src'] ?? '';
    final caption = block['caption'] ?? '';
    return _buildSingleImage(src, caption, aspect);
  }

  Widget _buildSingleImage(String src, String caption, double? aspect) {
    Widget imageContainer = ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Image.asset(src, fit: aspect != null ? BoxFit.cover : null),
    );

    if (aspect != null) {
      imageContainer = AspectRatio(
        aspectRatio: aspect,
        child: imageContainer,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        imageContainer,
        if (caption.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              caption,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: Colors.white54,
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
            ),
          )
      ],
    );
  }
}

// ─── Prose Block ─────────────────────────────────────────────────────────────

class _ProseBlock extends StatelessWidget {
  final Map<String, dynamic> block;
  final int index;

  const _ProseBlock({required this.block, required this.index});

  @override
  Widget build(BuildContext context) {
    final text = block['text'] ?? '';

    return Text(
      text,
      style: GoogleFonts.inter(
        fontSize: 15,
        color: Colors.white70,
        height: 1.75,
      ),
    );
  }
}

// ─── Equation Block ──────────────────────────────────────────────────────────

class _EquationBlock extends StatelessWidget {
  final Map<String, dynamic> block;
  final Color accent;
  final int index;

  const _EquationBlock({
    required this.block,
    required this.accent,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    final label = block['label'] ?? '';
    final formula = block['formula'] ?? '';
    final note = block['note'] ?? '';
    final screenW = MediaQuery.of(context).size.width;
    final isPhone = screenW < 500;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              label,
              style: GoogleFonts.spaceGrotesk(
                fontSize: isPhone ? 14 : 16,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(
            horizontal: isPhone ? 16 : 24,
            vertical: isPhone ? 14 : 18,
          ),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: accent.withValues(alpha: 0.15)),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Text(
              formula,
              style: GoogleFonts.firaCode(
                fontSize: isPhone ? 12 : 14,
                color: Colors.white.withValues(alpha: 0.9),
                height: 1.6,
              ),
            ),
          ),
        ),
        if (note.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              note,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontStyle: FontStyle.italic,
                color: Colors.white54,
                height: 1.5,
              ),
            ),
          ),
      ],
    );
  }
}

// ─── Table Block ─────────────────────────────────────────────────────────────

class _TableBlock extends StatelessWidget {
  final Map<String, dynamic> block;
  final Color accent;
  final int index;

  const _TableBlock({
    required this.block,
    required this.accent,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    final caption = block['caption'] ?? '';
    final headers = (block['headers'] as List?)?.cast<String>() ?? [];
    final colFlex = (block['column_flex'] as List?)?.map((e) => (e as num).toInt()).toList() ?? [];
    final rows = (block['rows'] as List?)
            ?.map((r) => (r as List).map((c) => c.toString()).toList())
            .toList() ??
        [];

    final screenW = MediaQuery.of(context).size.width;
    final isPhone = screenW < 500;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Table caption
        if (caption.isNotEmpty) ...[
          Text(
            caption,
            style: GoogleFonts.spaceGrotesk(
              fontSize: isPhone ? 16 : 18,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
        ],
        // Decide layout: card list on phones with many columns, table otherwise
        if (isPhone && headers.length > 2)
          _buildCardLayout(headers, rows, isPhone)
        else
          _buildScrollableTable(headers, rows, colFlex, isPhone),
      ],
    );
  }

  /// Phone-friendly card layout: each row becomes a vertical card
  /// with header: value pairs stacked.
  Widget _buildCardLayout(List<String> headers, List<List<String>> rows, bool isPhone) {
    return Column(
      children: [
        for (int r = 0; r < rows.length; r++) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF0d1e30).withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // First cell as card title
                if (rows[r].isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text(
                      rows[r][0],
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                // Remaining cells as key-value pairs
                for (int c = 1; c < rows[r].length && c < headers.length; c++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 100,
                          child: Text(
                            headers[c],
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Colors.white54,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _CellText(
                            text: rows[r][c],
                            fontSize: 13,
                            fontWeight: FontWeight.w400,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          if (r < rows.length - 1) const SizedBox(height: 10),
        ],
      ],
    );
  }

  /// Displays the standard table layout taking full available width.
  Widget _buildScrollableTable(
      List<String> headers, List<List<String>> rows, List<int> colFlex, bool isPhone) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
      ),
      child: _buildTable(headers, rows, colFlex, isPhone),
    );
  }

  int _getFlex(int colIndex, int totalCols, List<int> providedFlex) {
    if (providedFlex.length > colIndex) return providedFlex[colIndex];
    if (totalCols >= 5) {
      if (colIndex == 0) return 1;
      if (colIndex == 1) return 2;
      if (colIndex == 2) return 3;
      return 4;
    } else if (totalCols >= 3) {
      if (colIndex == 0) return 2;
      if (colIndex == 1) return 3;
      return 4;
    }
    return colIndex == 0 ? 2 : 3;
  }

  Widget _buildTable(List<String> headers, List<List<String>> rows, List<int> colFlex, bool isPhone) {
    final hPad = isPhone ? 14.0 : 20.0;
    final vPad = isPhone ? 10.0 : 14.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header row
        Container(
          padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
          decoration: BoxDecoration(
            color: const Color(0xFF0d1e30),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
          ),
          child: Row(
            children: [
              for (int h = 0; h < headers.length; h++)
                Expanded(
                  flex: _getFlex(h, headers.length, colFlex),
                  child: Text(
                    headers[h].toUpperCase(),
                    style: GoogleFonts.inter(
                      fontSize: isPhone ? 9 : 10,
                      fontWeight: FontWeight.w700,
                      color: Colors.white54,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
            ],
          ),
        ),
        // Data rows
        for (int r = 0; r < rows.length; r++)
          _DataRow(
            cells: rows[r],
            isEven: r.isEven,
            headers: headers,
            colFlex: colFlex,
            isPhone: isPhone,
          ),
      ],
    );
  }
}

class _DataRow extends StatefulWidget {
  final List<String> cells;
  final bool isEven;
  final List<String> headers;
  final List<int> colFlex;
  final bool isPhone;

  const _DataRow({
    required this.cells,
    required this.isEven,
    required this.headers,
    required this.colFlex,
    this.isPhone = false,
  });

  @override
  State<_DataRow> createState() => _DataRowState();
}

class _DataRowState extends State<_DataRow> {
  bool _hovering = false;

  int _getFlex(int colIndex, int totalCols, List<int> providedFlex) {
    if (providedFlex.length > colIndex) return providedFlex[colIndex];
    if (totalCols >= 5) {
      if (colIndex == 0) return 1;
      if (colIndex == 1) return 2;
      if (colIndex == 2) return 3;
      return 4;
    } else if (totalCols >= 3) {
      if (colIndex == 0) return 2;
      if (colIndex == 1) return 3;
      return 4;
    }
    return colIndex == 0 ? 2 : 3;
  }

  @override
  Widget build(BuildContext context) {
    final hPad = widget.isPhone ? 14.0 : 16.0;
    final vPad = widget.isPhone ? 10.0 : 14.0;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
        decoration: BoxDecoration(
          color: _hovering ? const Color(0xFF0f1e30) : Colors.transparent,
          border: Border(
            bottom: BorderSide(color: Colors.white.withValues(alpha: 0.04)),
          ),
        ),
        child: Row(
          children: [
            for (int c = 0; c < widget.cells.length; c++)
              Expanded(
                flex: _getFlex(c, widget.headers.length, widget.colFlex),
                child: _CellText(
                  text: widget.cells[c],
                  fontSize: widget.isPhone ? 12 : 13,
                  fontWeight: c == 0 ? FontWeight.w700 : FontWeight.w400,
                  color: c == 0 ? Colors.white : Colors.white70,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CellText extends StatelessWidget {
  final String text;
  final double fontSize;
  final FontWeight fontWeight;
  final Color color;

  const _CellText({
    required this.text,
    required this.fontSize,
    required this.fontWeight,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    if (text.startsWith('✅') || text.startsWith('❌') || text.startsWith('🔄')) {
      final isCheck = text.startsWith('✅');
      final isCross = text.startsWith('❌');
      
      String textPart = text;
      if (isCheck) {
        textPart = text.substring('✅'.length);
      } else if (isCross) {
        textPart = text.substring('❌'.length);
      } else {
        textPart = text.substring('🔄'.length);
      }
      textPart = textPart.trim();
      
      Color iconColor;
      IconData iconData;
      
      if (isCheck) {
        iconColor = const Color(0xFF22C55E);
        iconData = Icons.check_circle_rounded;
      } else if (isCross) {
        iconColor = const Color(0xFFEF4444);
        iconData = Icons.cancel_rounded;
      } else {
        iconColor = const Color(0xFF38BDF8); // Blue
        iconData = Icons.sync_rounded;
      }
      
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2.0),
            child: Icon(iconData, color: iconColor, size: 14),
          ),
          if (textPart.isNotEmpty) const SizedBox(width: 6),
          if (textPart.isNotEmpty)
            Expanded(
              child: Text(
                textPart,
                style: GoogleFonts.inter(
                  fontSize: fontSize,
                  fontWeight: fontWeight,
                  color: color,
                  height: 1.4,
                ),
              ),
            ),
        ],
      );
    }

    return Text(
      text,
      style: GoogleFonts.inter(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        height: 1.4,
      ),
    );
  }
}
