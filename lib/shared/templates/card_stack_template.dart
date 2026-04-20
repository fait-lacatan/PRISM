import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Vertically stacked card template — cards are stacked on top of each other.
/// Uses explicit navigation controls (arrows + dots) that work reliably
/// inside scrollable parents.
class CardStackTemplate extends StatefulWidget {
  final Map<String, dynamic> data;
  final Color accent;

  const CardStackTemplate({super.key, required this.data, required this.accent});

  @override
  State<CardStackTemplate> createState() => _CardStackTemplateState();
}

class _CardStackTemplateState extends State<CardStackTemplate> {
  int _currentIndex = 0;

  Color get _accent => widget.accent;
  Map<String, dynamic> get _d => widget.data;
  List get _cards => (_d['cards'] as List?) ?? [];

  static const Map<String, IconData> _iconMap = {
    'schedule': Icons.schedule_rounded,
    'menu_book': Icons.menu_book_rounded,
    'trending_down': Icons.trending_down_rounded,
    'desktop_windows': Icons.desktop_windows_outlined,
    'fingerprint': Icons.fingerprint_rounded,
    'badge': Icons.badge_rounded,
    'qr_code': Icons.qr_code_rounded,
    'wifi': Icons.wifi_rounded,
    'security': Icons.security_rounded,
    'memory': Icons.memory_rounded,
    'cloud': Icons.cloud_rounded,
    'lock': Icons.lock_rounded,
  };

  void _goTo(int index) {
    setState(() => _currentIndex = index.clamp(0, _cards.length - 1));
  }

  void _openFullscreenGallery(BuildContext context, int initialIndex) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black.withValues(alpha: 0.9),
        transitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (context, animation, secondaryAnimation) {
          return _FullscreenGallery(
            cards: _cards,
            initialIndex: initialIndex,
            accent: _accent,
          );
        },
        transitionsBuilder: (context, animation, _, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = _d['title'] ?? '';
    final sources = (_d['sources'] as List?) ?? [];
    final sourceStr = _d['source'] as String?;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title.isNotEmpty) ...[
          Text(
            title,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 32),
        ],
        // Card display area — only shows the active card with animated transition
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 350),
          transitionBuilder: (child, animation) {
            return FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.04),
                  end: Offset.zero,
                ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
                child: child,
              ),
            );
          },
          child: _buildCard(
            _cards.isNotEmpty ? _cards[_currentIndex] : {},
            key: ValueKey(_currentIndex),
          ),
        ),
        const SizedBox(height: 20),
        // Navigation controls
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Prev button
            Material(
              color: _currentIndex > 0 ? const Color(0xFFE97316).withValues(alpha: 0.12) : Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                onTap: _currentIndex > 0 ? () => _goTo(_currentIndex - 1) : null,
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 40, height: 40,
                  child: Icon(Icons.chevron_left_rounded, size: 22, color: _currentIndex > 0 ? const Color(0xFFE97316) : Colors.white12),
                ),
              ),
            ),
            const SizedBox(width: 16),
            // Dot indicators
            ...List.generate(_cards.length, (i) {
              final isActive = i == _currentIndex;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _goTo(i),
                    borderRadius: BorderRadius.circular(6),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: isActive ? 28 : 10,
                      height: 6,
                      decoration: BoxDecoration(
                        color: isActive ? const Color(0xFFE97316) : Colors.white12,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ),
              );
            }),
            const SizedBox(width: 16),
            // Next button
            Material(
              color: _currentIndex < _cards.length - 1 ? const Color(0xFFE97316).withValues(alpha: 0.12) : Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                onTap: _currentIndex < _cards.length - 1 ? () => _goTo(_currentIndex + 1) : null,
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 40, height: 40,
                  child: Icon(Icons.chevron_right_rounded, size: 22, color: _currentIndex < _cards.length - 1 ? const Color(0xFFE97316) : Colors.white12),
                ),
              ),
            ),
          ],
        ),
        // Sources
        if (sources.isNotEmpty || (sourceStr != null && sourceStr.isNotEmpty)) ...[
          const SizedBox(height: 32),
          _buildSources(sources, sourceStr),
        ],
      ],
    );
  }

  Widget _buildCard(Map<String, dynamic> card, {Key? key}) {
    final iconName = card['icon'] as String?;
    final imageSrc = card['image'] as String?;
    final icon = iconName != null ? (_iconMap[iconName] ?? Icons.info_outline) : null;
    final cardTitle = card['title'] as String? ?? '';
    final desc = card['desc'] as String? ?? '';

    return Container(
      key: key,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFFB388FF).withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      padding: EdgeInsets.all(imageSrc != null ? 0 : 32),
      clipBehavior: Clip.antiAlias,
      child: imageSrc != null
          ? Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AspectRatio(
                  aspectRatio: 16 / 10,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.asset(imageSrc, fit: BoxFit.cover),
                      Positioned.fill(
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => _openFullscreenGallery(context, _currentIndex),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 12,
                        right: 12,
                        child: IgnorePointer(
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.fullscreen_rounded, color: Colors.white, size: 20),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (cardTitle.isNotEmpty || desc.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (cardTitle.isNotEmpty)
                          Text(cardTitle, style: GoogleFonts.spaceGrotesk(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white)),
                        if (desc.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(desc, style: GoogleFonts.inter(fontSize: 14, color: Colors.white70, height: 1.5)),
                        ],
                      ],
                    ),
                  ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null)
                  Container(
                    width: 52, height: 52,
                    decoration: BoxDecoration(
                      color: _accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(icon, size: 26, color: _accent),
                  ),
                const SizedBox(height: 20),
                Text(
                  cardTitle,
                  style: GoogleFonts.spaceGrotesk(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white),
                ),
                const SizedBox(height: 12),
                Text(
                  desc,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    color: Colors.white60,
                    height: 1.65,
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildSources(List sources, String? sourceStr) {
    if (sources.isNotEmpty) {
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: sources.map<Widget>((s) {
          final label = s['label'] ?? s.toString();
          return Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                // TODO: Navigate to references page at specific citation
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF112035),
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
    if (sourceStr != null && sourceStr.isNotEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF112035),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.info_outline_rounded, size: 14, color: Colors.white.withValues(alpha: 0.27)),
            const SizedBox(width: 8),
            Flexible(child: Text(sourceStr, style: GoogleFonts.inter(fontSize: 12, color: Colors.white.withValues(alpha: 0.27)))),
          ],
        ),
      );
    }
    return const SizedBox.shrink();
  }
}

class _FullscreenGallery extends StatefulWidget {
  final List cards;
  final int initialIndex;
  final Color accent;

  const _FullscreenGallery({
    required this.cards,
    required this.initialIndex,
    required this.accent,
  });

  @override
  State<_FullscreenGallery> createState() => _FullscreenGalleryState();
}

class _FullscreenGalleryState extends State<_FullscreenGallery> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goTo(int index) {
    final target = index.clamp(0, widget.cards.length - 1);
    _pageController.animateToPage(
      target,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentCard = widget.cards[_currentIndex] as Map<String, dynamic>? ?? {};
    final title = currentCard['title'] as String? ?? '';
    final desc = currentCard['desc'] as String? ?? '';

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Dismiss on tap empty space
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(color: Colors.transparent),
          ),
          
          // Page View
          PageView.builder(
            controller: _pageController,
            onPageChanged: (idx) => setState(() => _currentIndex = idx),
            itemCount: widget.cards.length,
            itemBuilder: (context, index) {
              final card = widget.cards[index] as Map<String, dynamic>? ?? {};
              final src = card['image'] as String?;
              if (src == null) return const SizedBox.shrink();
              return InteractiveViewer(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Image.asset(src, fit: BoxFit.contain),
                  ),
                ),
              );
            },
          ),
          
          // Close button
          Positioned(
            top: 32,
            right: 32,
            child: Material(
              color: Colors.black.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(20),
              child: IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ),

          // Left Arrow
          if (_currentIndex > 0)
            Positioned(
              left: 24,
              top: 0,
              bottom: 0,
              child: Center(
                child: Material(
                  color: Colors.black.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(24),
                  child: IconButton(
                    iconSize: 32,
                    icon: const Icon(Icons.chevron_left_rounded, color: Colors.white),
                    onPressed: () => _goTo(_currentIndex - 1),
                  ),
                ),
              ),
            ),

          // Right Arrow
          if (_currentIndex < widget.cards.length - 1)
            Positioned(
              right: 24,
              top: 0,
              bottom: 0,
              child: Center(
                child: Material(
                  color: Colors.black.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(24),
                  child: IconButton(
                    iconSize: 32,
                    icon: const Icon(Icons.chevron_right_rounded, color: Colors.white),
                    onPressed: () => _goTo(_currentIndex + 1),
                  ),
                ),
              ),
            ),

          // Caption overlay
          if (title.isNotEmpty || desc.isNotEmpty)
            Positioned(
              bottom: 40,
              left: 64,
              right: 64,
              child: IgnorePointer(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.75),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (title.isNotEmpty)
                        Text(
                          title,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.spaceGrotesk(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white),
                        ),
                      if (desc.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          desc,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(fontSize: 14, color: Colors.white70, height: 1.4),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
