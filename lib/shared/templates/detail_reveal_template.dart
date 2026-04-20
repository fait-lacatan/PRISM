import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Tap a card to reveal a full-screen detail overlay with Hero animation.
class DetailRevealTemplate extends StatelessWidget {
  final Map<String, dynamic> data;
  final Color accent;

  const DetailRevealTemplate({super.key, required this.data, required this.accent});

  static const Map<String, IconData> _iconMap = {
    'fingerprint': Icons.fingerprint_rounded,
    'link': Icons.link_rounded,
    'key': Icons.key_rounded,
    'description': Icons.description_rounded,
    'code': Icons.code_rounded,
    'vpn_key': Icons.vpn_key_rounded,
    'verified_user': Icons.verified_user_rounded,
    'lock': Icons.lock_rounded,
    'security': Icons.security_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final title = data['title'] ?? '';
    final items = (data['items'] as List?) ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(title, style: GoogleFonts.spaceGrotesk(fontSize: 28, fontWeight: FontWeight.w700, color: Colors.white)),
        ],
        const SizedBox(height: 32),
        ...List.generate(items.length, (i) {
          final item = items[i];
          final iconName = item['icon'] as String? ?? 'description';
          final icon = _iconMap[iconName] ?? Icons.info_outline;
          final heroTag = 'detail_reveal_${data.hashCode}_$i';

          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: GestureDetector(
              onTap: () => _showDetail(context, item, icon, heroTag),
              child: Hero(
                tag: heroTag,
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: const Color(0xFF112035),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(icon, size: 24, color: accent),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item['title'] ?? '',
                                style: GoogleFonts.spaceGrotesk(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                item['summary'] ?? item['desc'] ?? '',
                                style: GoogleFonts.inter(fontSize: 13, color: Colors.white.withValues(alpha: 0.5)),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.open_in_new_rounded, size: 18, color: accent.withValues(alpha: 0.5)),
                      ],
                    ),
                  ),
                ),
              ),
            ).animate().fadeIn(delay: (100 + i * 100).ms).slideX(begin: 0.04),
          );
        }),
      ],
    );
  }

  void _showDetail(BuildContext context, Map<String, dynamic> item, IconData icon, String heroTag) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierDismissible: true,
        barrierColor: Colors.black87,
        transitionDuration: const Duration(milliseconds: 350),
        reverseTransitionDuration: const Duration(milliseconds: 250),
        pageBuilder: (context, anim, secondAnim) {
          return _DetailOverlay(
            item: item,
            icon: icon,
            accent: accent,
            heroTag: heroTag,
            animation: anim,
          );
        },
      ),
    );
  }

}

class _DetailOverlay extends StatelessWidget {
  final Map<String, dynamic> item;
  final IconData icon;
  final Color accent;
  final String heroTag;
  final Animation<double> animation;

  const _DetailOverlay({
    required this.item,
    required this.icon,
    required this.accent,
    required this.heroTag,
    required this.animation,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Hero(
        tag: heroTag,
        child: Material(
          color: Colors.transparent,
          child: FadeTransition(
            opacity: animation,
            child: Container(
              width: MediaQuery.of(context).size.width * 0.6,
              constraints: const BoxConstraints(maxWidth: 600, maxHeight: 500),
              padding: const EdgeInsets.all(40),
              decoration: BoxDecoration(
                color: const Color(0xFF0C1829),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: accent.withValues(alpha: 0.2)),
                boxShadow: [
                  BoxShadow(color: accent.withValues(alpha: 0.08), blurRadius: 40, spreadRadius: 4),
                ],
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(icon, size: 28, color: accent),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Text(
                            item['title'] ?? '',
                            style: GoogleFonts.spaceGrotesk(fontSize: 24, fontWeight: FontWeight.w700, color: Colors.white),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close_rounded, color: Colors.white38),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),
                    Text(
                      item['detail'] ?? item['desc'] ?? '',
                      style: GoogleFonts.inter(fontSize: 16, color: Colors.white.withValues(alpha: 0.75), height: 1.7),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
