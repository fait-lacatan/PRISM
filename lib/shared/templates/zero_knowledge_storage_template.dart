import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ZeroKnowledgeStorageTemplate extends StatefulWidget {
  final Map<String, dynamic> data;
  const ZeroKnowledgeStorageTemplate({super.key, required this.data});

  @override
  State<ZeroKnowledgeStorageTemplate> createState() =>
      _ZeroKnowledgeStorageTemplateState();
}

class _ZeroKnowledgeStorageTemplateState
    extends State<ZeroKnowledgeStorageTemplate> {
  static const _panel = Color(0xFF071428);
  static const _accent = Color(0xFFA78BFA);

  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final title = widget.data['title'] as String? ?? '';
    final description = widget.data['description'] as String? ?? '';
    final phases = (widget.data['phases'] as List?)?.cast<Map<String, dynamic>>() ?? [];

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
        LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 650;

            final stepsList = Padding(
              padding: EdgeInsets.symmetric(
                  vertical: isNarrow ? 12 : 24, horizontal: 16),
              child: ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: phases.length,
                itemBuilder: (context, index) {
                  final isActive = index == _currentIndex;
                  return GestureDetector(
                    onTap: () => setState(() => _currentIndex = index),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isActive
                            ? _accent.withValues(alpha: 0.1)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isActive ? _accent : Colors.transparent,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: isActive
                                  ? _accent
                                  : const Color(0xFF1E3A5C),
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              '${index + 1}',
                              style: GoogleFonts.spaceGrotesk(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              phases[index]['title'] as String? ?? '',
                              style: GoogleFonts.spaceGrotesk(
                                fontSize: isNarrow ? 14 : 16,
                                fontWeight: isActive
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: isActive
                                    ? Colors.white
                                    : Colors.white60,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            );

            final detailPanel = Container(
              decoration: BoxDecoration(
                color: const Color(0xFF0B1D34),
                borderRadius: isNarrow
                    ? const BorderRadius.vertical(bottom: Radius.circular(24))
                    : const BorderRadius.horizontal(right: Radius.circular(24)),
              ),
              padding: const EdgeInsets.all(32),
              child: Center(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Column(
                    key: ValueKey(_currentIndex),
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _currentIndex == 0
                            ? Icons.vpn_lock
                            : _currentIndex == 1
                                ? Icons.enhanced_encryption
                                : Icons.anchor,
                        size: isNarrow ? 48 : 64,
                        color: _accent.withValues(alpha: 0.8),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        phases.isNotEmpty
                            ? phases[_currentIndex]['desc'] as String? ?? ''
                            : '',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: isNarrow ? 14 : 15,
                          color: Colors.white.withValues(alpha: 0.9),
                          height: 1.6,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );

            if (isNarrow) {
              return Container(
                decoration: BoxDecoration(
                  color: _panel,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFF1E3A5C)),
                ),
                child: Column(
                  children: [
                    stepsList,
                    detailPanel,
                  ],
                ),
              );
            }

            return Container(
              height: 320,
              decoration: BoxDecoration(
                color: _panel,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFF1E3A5C)),
              ),
              child: Row(
                children: [
                  Expanded(flex: 2, child: stepsList),
                  Expanded(flex: 3, child: detailPanel),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}
