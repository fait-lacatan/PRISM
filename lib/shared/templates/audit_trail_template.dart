import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AuditTrailTemplate extends StatefulWidget {
  final Map<String, dynamic> data;
  const AuditTrailTemplate({super.key, required this.data});

  @override
  State<AuditTrailTemplate> createState() => _AuditTrailTemplateState();
}

class _AuditTrailTemplateState extends State<AuditTrailTemplate> {
  static const _panel = Color(0xFF071428);
  int _selectedContractIndex = 0;

  Color _fromHex(String hex) {
    hex = hex.replaceAll('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    return Color(int.parse(hex, radix: 16));
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.data['title'] as String? ?? '';
    final description = widget.data['description'] as String? ?? '';
    final contracts =
        (widget.data['contracts'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    if (contracts.isEmpty) return const SizedBox.shrink();

    // Ensure index bounds are safe during hot reload changes
    if (_selectedContractIndex >= contracts.length) {
      _selectedContractIndex = 0;
    }

    final selectedContract = contracts[_selectedContractIndex];
    final color = _fromHex(selectedContract['color'] as String? ?? '#38BDF8');
    final events =
        (selectedContract['events'] as List?)?.cast<Map<String, dynamic>>() ??
            [];

    final screenWidth = MediaQuery.of(context).size.width;
    // 1 column for phones, 2 for tablets, 3 for wide desktop
    final crossAxisCount = screenWidth < 600
        ? 1
        : screenWidth < 1000
            ? 2
            : 3;

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

        // Custom Tab Bar
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: List.generate(contracts.length, (index) {
              final contract = contracts[index];
              final name = contract['name'] as String? ?? 'Contract';
              final cColor = _fromHex(contract['color'] as String? ?? '#FFF');
              final isSelected = index == _selectedContractIndex;

              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => setState(() => _selectedContractIndex = index),
                    borderRadius: BorderRadius.circular(24),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? cColor.withValues(alpha: 0.15)
                            : _panel,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: isSelected
                              ? cColor.withValues(alpha: 0.5)
                              : const Color(0xFF1E3A5C),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.description_outlined,
                            size: 18,
                            color: isSelected ? cColor : Colors.white54,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            name,
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 14,
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: isSelected ? cColor : Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),

        const SizedBox(height: 24),

        // Events Grid
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: GridView.builder(
            key: ValueKey(_selectedContractIndex),
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              mainAxisExtent: 150, // Fixed height per event card
            ),
            itemCount: events.length,
            itemBuilder: (context, index) {
              final ev = events[index];
              final evName = ev['name'] as String? ?? 'Event';
              final evParams = ev['params'] as String? ?? '';
              final evTrigger = ev['trigger'] as String? ?? '';

              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _panel,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: color.withValues(alpha: 0.2)),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.03),
                      blurRadius: 10,
                      spreadRadius: 1,
                    )
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            evName,
                            style: GoogleFonts.spaceGrotesk(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Colors.white),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black26,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        evParams.isEmpty ? 'No parameters' : evParams,
                        style: GoogleFonts.jetBrainsMono(
                            fontSize: 11, color: color.withValues(alpha: 0.8)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      evTrigger,
                      style: GoogleFonts.inter(
                          fontSize: 13,
                          color: Colors.white70,
                          height: 1.4),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
