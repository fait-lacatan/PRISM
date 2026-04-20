import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

class ExhibitShell extends StatelessWidget {
  final int exhibitNumber;
  final String exhibitName;
  final Color accentColor;
  final Widget child;

  const ExhibitShell({
    super.key,
    required this.exhibitNumber,
    required this.exhibitName,
    required this.accentColor,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF060608),
      appBar: AppBar(
        backgroundColor: Colors.black,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white70),
          tooltip: 'Back to Dashboard',
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.goNamed('home');
            }
          },
        ),
        title: Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: accentColor.withValues(alpha: 0.35)),
            ),
            child: Text(
              'EXHIBIT $exhibitNumber',
              style: GoogleFonts.inter(
                color: accentColor,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            exhibitName,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ]),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_rounded, color: Colors.white54),
            tooltip: 'Download PDF',
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.code_rounded, color: Colors.white54),
            tooltip: 'GitHub',
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.photo_library_rounded, color: Colors.white54),
            tooltip: 'Documentation Gallery',
            onPressed: () => context.goNamed('gallery_docs'),
          ),
          IconButton(
            icon: const Icon(Icons.bubble_chart_rounded, color: Colors.white54),
            tooltip: 'Obsidian Archive',
            onPressed: () => context.goNamed('archive'),
          ),
          const SizedBox(width: 8),
          if (exhibitNumber > 1)
            TextButton(
              onPressed: () => context.goNamed('exhibit',
                  pathParameters: {'id': '${exhibitNumber - 1}'}),
              child: Row(
                children: [
                  const Icon(Icons.chevron_left_rounded, size: 18,
                      color: Colors.white54),
                  Text('Prev',
                      style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.white54)),
                ],
              ),
            ),
          if (exhibitNumber < 6)
            TextButton(
              onPressed: () => context.goNamed('exhibit',
                  pathParameters: {'id': '${exhibitNumber + 1}'}),
              child: Row(
                children: [
                  Text('Next',
                      style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.white54)),
                  const Icon(Icons.chevron_right_rounded, size: 18,
                      color: Colors.white54),
                ],
              ),
            ),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: const Color(0xFF18181B)),
        ),
      ),
      body: child,
    );
  }
}
