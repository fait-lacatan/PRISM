import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class KeyHierarchyTemplate extends StatelessWidget {
  final Map<String, dynamic> data;
  const KeyHierarchyTemplate({super.key, required this.data});

  static const _panel = Color(0xFF071428);

  @override
  Widget build(BuildContext context) {
    final title = data['title'] as String? ?? '';
    final description = data['description'] as String? ?? '';
    final root = data['root'] as Map<String, dynamic>?;

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
        if (root != null)
          Builder(
            builder: (context) {
              final screenWidth = MediaQuery.of(context).size.width;
              final isNarrow = screenWidth < 700;

              return Container(
                width: double.infinity,
                padding: EdgeInsets.all(isNarrow ? 16 : 24),
                decoration: BoxDecoration(
                  color: _panel,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFF1E3A5C)),
                ),
                child: _TreeNodeWidget(
                    node: root, isRoot: true, isNarrow: isNarrow),
              );
            },
          ),
      ],
    );
  }
}

class _TreeNodeWidget extends StatelessWidget {
  final Map<String, dynamic> node;
  final bool isRoot;
  final bool isNarrow;
  const _TreeNodeWidget(
      {required this.node, this.isRoot = false, this.isNarrow = false});

  @override
  Widget build(BuildContext context) {
    final label = node['label'] as String? ?? '';
    final contextStr = node['context'] as String?;
    final action = node['action'] as String?;
    final desc = node['desc'] as String?;
    final children = (node['children'] as List?)?.cast<Map<String, dynamic>>();

    final titleFS = isNarrow ? 13.0 : 15.0;
    final subFS = isNarrow ? 11.0 : 12.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Node Card
        Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(
              horizontal: 16, vertical: isNarrow ? 10 : 12),
          decoration: BoxDecoration(
            color: isRoot ? const Color(0xFF1E3A5C) : const Color(0xFF0B1D34),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isRoot ? Colors.indigoAccent : Colors.white10,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                      isRoot
                          ? Icons.key
                          : (children?.isNotEmpty == true
                              ? Icons.account_tree
                              : Icons.vpn_key_outlined),
                      color: isRoot ? Colors.indigoAccent : Colors.cyanAccent,
                      size: isNarrow ? 16 : 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      label,
                      style: GoogleFonts.jetBrainsMono(
                          fontSize: titleFS,
                          fontWeight: FontWeight.bold,
                          color: Colors.white),
                    ),
                  ),
                ],
              ),
              if (action != null) ...[
                const SizedBox(height: 8),
                Text(
                  action,
                  style: GoogleFonts.jetBrainsMono(
                      fontSize: subFS, color: Colors.purpleAccent.shade100),
                ),
              ],
              if (desc != null || contextStr != null) ...[
                const SizedBox(height: 8),
                Text(
                  desc ?? contextStr ?? '',
                  style: GoogleFonts.inter(
                      fontSize: isNarrow ? 12 : 13, color: Colors.white70),
                ),
              ],
            ],
          ),
        ),
        // Children
        if (children != null && children.isNotEmpty)
          Padding(
            padding: EdgeInsets.only(
                left: isNarrow ? 12.0 : 20.0,
                top: isNarrow ? 12.0 : 16.0),
            child: Container(
              decoration: const BoxDecoration(
                border: Border(
                  left: BorderSide(color: Colors.white24, width: 2),
                ),
              ),
              padding: EdgeInsets.only(left: isNarrow ? 16.0 : 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: children.map((child) {
                  return Padding(
                    padding:
                        EdgeInsets.only(bottom: isNarrow ? 12.0 : 16.0),
                    child: _TreeNodeWidget(
                        node: child, isRoot: false, isNarrow: isNarrow),
                  );
                }).toList(),
              ),
            ),
          ),
      ],
    );
  }
}
