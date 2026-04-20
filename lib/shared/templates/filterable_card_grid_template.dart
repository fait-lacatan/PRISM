import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Filterable card grid with 5 interaction features:
/// ① Segmented control filter
/// ② Staggered entrance animation
/// ③ Hover elevation (desktop)
/// ④ 3D card flip (rotateY)
/// ⑤ Progressive disclosure drawer
class FilterableCardGridTemplate extends StatefulWidget {
  final Map<String, dynamic> data;
  final Color accent;

  const FilterableCardGridTemplate({super.key, required this.data, required this.accent});

  @override
  State<FilterableCardGridTemplate> createState() => _FilterableCardGridTemplateState();
}

class _FilterableCardGridTemplateState extends State<FilterableCardGridTemplate> {
  int _selectedFilter = 0;
  int _flippedIndex = -1; // index in _filteredCards
  int _animKey = 0; // incremented to re-trigger stagger

  Color get _accent => widget.accent;
  Map<String, dynamic> get _d => widget.data;
  List get _allCards => (_d['cards'] as List?) ?? [];
  List<String> get _filters => (_d['filters'] as List?)?.cast<String>() ?? ['All'];

  static const Map<String, IconData> _iconMap = {
    'badge': Icons.badge_rounded,
    'fingerprint': Icons.fingerprint_rounded,
    'qr_code': Icons.qr_code_rounded,
    'description': Icons.description_rounded,
    'videocam': Icons.videocam_rounded,
    'photo_camera': Icons.photo_camera_rounded,
    'monitor': Icons.monitor_rounded,
    'schedule': Icons.schedule_rounded,
    'lock': Icons.lock_rounded,
    'wifi': Icons.wifi_rounded,
    'security': Icons.security_rounded,
    'memory': Icons.memory_rounded,
  };

  List<Map<String, dynamic>> get _filteredCards {
    if (_selectedFilter == 0) {
      return _allCards.cast<Map<String, dynamic>>();
    }
    final filterLabel = _filters[_selectedFilter];
    return _allCards
        .cast<Map<String, dynamic>>()
        .where((c) => c['filter'] == filterLabel)
        .toList();
  }

  void _setFilter(int i) {
    setState(() {
      _selectedFilter = i;
      _flippedIndex = -1;
      _animKey++;
    });
  }

  void _toggleFlip(int i) {
    setState(() {
      _flippedIndex = _flippedIndex == i ? -1 : i;
    });
  }

  @override
  Widget build(BuildContext context) {
    final title = _d['title'] ?? '';
    final subtitle = _d['subtitle'] ?? '';
    final sources = (_d['sources'] as List?) ?? [];
    final filtered = _filteredCards;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title
        if (title.isNotEmpty) ...[
          Text(title, style: GoogleFonts.spaceGrotesk(fontSize: 28, fontWeight: FontWeight.w700, color: Colors.white)),
          if (subtitle.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(subtitle, style: GoogleFonts.inter(fontSize: 14, color: Colors.white38)),
          ],
          const SizedBox(height: 24),
        ],

        // ① Segmented control
        LayoutBuilder(builder: (context, constraints) {
          return _buildSegmentedControl(constraints.maxWidth);
        }),
        const SizedBox(height: 28),

        // ② ③ ④ Card grid with stagger, hover, and flip
        LayoutBuilder(
          builder: (context, constraints) {
            final availW = constraints.maxWidth;
            final cols = availW >= 700 ? 3 : (availW >= 500 ? 2 : 1);
            final spacing = 14.0;
            final cardW = (availW - spacing * (cols - 1)) / cols;

            return Wrap(
              key: ValueKey(_animKey),
              spacing: spacing,
              runSpacing: spacing,
              children: List.generate(filtered.length, (i) {
                return SizedBox(
                  width: cardW,
                  height: 200,
                  child: _FlipCard(
                    card: filtered[i],
                    accent: _accent,
                    isFlipped: _flippedIndex == i,
                    onTap: () => _toggleFlip(i),
                    delay: i * 70,
                  ),
                );
              }),
            );
          },
        ),

        // ⑤ Progressive disclosure drawer (opt-in via "show_drawer": true)
        if (_d['show_drawer'] == true)
          AnimatedSize(
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: _flippedIndex >= 0 && _flippedIndex < filtered.length
                ? _buildDrawer(filtered[_flippedIndex])
                : const SizedBox.shrink(),
          ),

        // Sources
        if (sources.isNotEmpty) ...[
          const SizedBox(height: 32),
          _buildSources(sources),
        ],
      ],
    );
  }

  // ① Segmented control (M3 Choice Chips style with scroll fade mask)
  Widget _buildSegmentedControl(double maxWidth) {
    final theme = Theme.of(context);
    final surfaceColor = theme.scaffoldBackgroundColor;
    
    Widget scrollView = SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (int i = 0; i < _filters.length; i++) ...[
              _CustomChoiceChip(
                label: _filters[i],
                isSelected: i == _selectedFilter,
                onSelected: (selected) => selected ? _setFilter(i) : null,
                selectedColor: _accent,
              ),
              if (i < _filters.length - 1) const SizedBox(width: 8),
            ],
          ],
        ),
      ),
    );

    if (maxWidth >= 600) return scrollView;

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
  }


  // ⑤ Progressive disclosure drawer
  Widget _buildDrawer(Map<String, dynamic> card) {
    final iconName = card['icon'] as String? ?? 'info';
    final icon = _iconMap[iconName] ?? Icons.info_outline;
    final title = card['title'] as String? ?? '';
    final backDesc = card['back_desc'] as String? ?? '';
    final filter = card['filter'] as String? ?? '';
    final isOnsite = filter == 'On-site';

    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _accent.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _accent.withValues(alpha: 0.15)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              color: _accent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, size: 24, color: _accent),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GoogleFonts.spaceGrotesk(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: isOnsite ? const Color(0xFFE97316).withValues(alpha: 0.12) : _accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: isOnsite ? const Color(0xFFE97316).withValues(alpha: 0.3) : _accent.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    filter,
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: isOnsite ? const Color(0xFFE97316) : _accent,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  backDesc,
                  style: GoogleFonts.inter(fontSize: 13, color: Colors.white60, height: 1.55),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => setState(() => _flippedIndex = -1),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(Icons.close_rounded, size: 18, color: Colors.white.withValues(alpha: 0.3)),
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.03);
  }

  Widget _buildSources(List sources) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: sources.map<Widget>((s) {
        final label = s['label'] ?? s.toString();
        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {},
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: _accent.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.menu_book_rounded, size: 12, color: _accent.withValues(alpha: 0.5)),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: _accent.withValues(alpha: 0.7),
                      decoration: TextDecoration.underline,
                      decorationColor: _accent.withValues(alpha: 0.3),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

/// Individual flip card with ③ hover elevation and ④ 3D flip.
class _FlipCard extends StatefulWidget {
  final Map<String, dynamic> card;
  final Color accent;
  final bool isFlipped;
  final VoidCallback onTap;
  final int delay;

  const _FlipCard({
    required this.card,
    required this.accent,
    required this.isFlipped,
    required this.onTap,
    required this.delay,
  });

  @override
  State<_FlipCard> createState() => _FlipCardState();
}

class _FlipCardState extends State<_FlipCard> with SingleTickerProviderStateMixin {
  bool _hovering = false;
  late AnimationController _flipController;
  late Animation<double> _flipAnimation;

  static const Map<String, IconData> _iconMap = {
    'badge': Icons.badge_rounded,
    'fingerprint': Icons.fingerprint_rounded,
    'qr_code': Icons.qr_code_rounded,
    'description': Icons.description_rounded,
    'videocam': Icons.videocam_rounded,
    'photo_camera': Icons.photo_camera_rounded,
    'monitor': Icons.monitor_rounded,
  };

  @override
  void initState() {
    super.initState();
    _flipController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _flipAnimation = Tween<double>(begin: 0, end: math.pi).animate(
      CurvedAnimation(parent: _flipController, curve: Curves.easeInOutCubic),
    );
  }

  @override
  void didUpdateWidget(covariant _FlipCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isFlipped && !oldWidget.isFlipped) {
      _flipController.forward();
    } else if (!widget.isFlipped && oldWidget.isFlipped) {
      _flipController.reverse();
    }
  }

  @override
  void dispose() {
    _flipController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final card = widget.card;
    final iconName = card['icon'] as String? ?? 'info';
    final icon = _iconMap[iconName] ?? Icons.info_outline;
    final title = card['title'] as String? ?? '';
    final frontDesc = card['front_desc'] as String? ?? '';
    final backDesc = card['back_desc'] as String? ?? '';
    final filter = card['filter'] as String? ?? '';
    final isOnsite = filter == 'On-site';
    final badgeColor = isOnsite ? const Color(0xFFE97316) : widget.accent;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          transform: Matrix4.translationValues(0, _hovering && !widget.isFlipped ? -5 : 0, 0),
          child: AnimatedBuilder(
            animation: _flipAnimation,
            builder: (context, child) {
              final angle = _flipAnimation.value;
              final showBack = angle > math.pi / 2;

              return Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.001) // perspective
                  ..rotateY(angle),
                child: showBack
                    ? Transform(
                        alignment: Alignment.center,
                        transform: Matrix4.rotationY(math.pi),
                        child: _buildBackFace(title, backDesc),
                      )
                    : _buildFrontFace(icon, title, frontDesc, filter, badgeColor),
              );
            },
          ),
        ),
      ),
    ).animate().fadeIn(delay: widget.delay.ms, duration: 350.ms).slideY(begin: 0.08);
  }

  Widget _buildFrontFace(IconData icon, String title, String desc, String filter, Color badgeColor) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: widget.accent.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _hovering ? widget.accent.withValues(alpha: 0.25) : Colors.white.withValues(alpha: 0.04),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: widget.accent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 22, color: widget.accent),
          ),
          const SizedBox(height: 12),
          Text(title, style: GoogleFonts.spaceGrotesk(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
          const SizedBox(height: 6),
          Expanded(
            child: Text(
              desc,
              style: GoogleFonts.inter(fontSize: 12, color: Colors.white.withValues(alpha: 0.4), height: 1.45),
              overflow: TextOverflow.ellipsis,
              maxLines: 3,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: badgeColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: badgeColor.withValues(alpha: 0.25)),
            ),
            child: Text(
              filter,
              style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: badgeColor, letterSpacing: 0.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackFace(String title, String desc) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: widget.accent.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: widget.accent.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: GoogleFonts.spaceGrotesk(fontSize: 14, fontWeight: FontWeight.w700, color: widget.accent)),
          const SizedBox(height: 8),
          Expanded(
            child: Text(
              desc,
              style: GoogleFonts.inter(fontSize: 12, color: Colors.white.withValues(alpha: 0.65), height: 1.55),
              overflow: TextOverflow.ellipsis,
              maxLines: 6,
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              'Tap to close ↩',
              style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: widget.accent.withValues(alpha: 0.5)),
            ),
          ),
        ],
      ),
    );
  }
}

class _CustomChoiceChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final ValueChanged<bool> onSelected;
  final Color selectedColor;

  const _CustomChoiceChip({
    required this.label,
    required this.isSelected,
    required this.onSelected,
    required this.selectedColor,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onSelected(!isSelected),
        borderRadius: BorderRadius.circular(24),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? selectedColor.withValues(alpha: 0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isSelected ? selectedColor.withValues(alpha: 0.6) : Colors.white.withValues(alpha: 0.15),
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isSelected) ...[
                Icon(Icons.check_circle_rounded, size: 14, color: selectedColor),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? selectedColor : Colors.white70,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
