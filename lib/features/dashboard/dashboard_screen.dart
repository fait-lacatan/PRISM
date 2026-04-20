import 'dart:io';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/data/narrative_repository.dart';
import '../../core/routing/router.dart';
import '../gallery/gallery_data.dart';
import 'dart:math' as math;

// ─── Color Palette ────────────────────────────────────────────────────────────

const _kViolet = Color(0xFF7C3AED);
const _kGreen = Color(0xFF22C55E);
const _kAmber = Color(0xFFF59E0B);
const _kRed = Color(0xFFEF4444);
const _kSurface = Color(0xFF060608);
const _kCard = Color(0xFF111114);
const _kCardBorder = Color(0xFF1E1E24);
const _kMuted = Color(0xFF71717A);

// ═══════════════════════════════════════════════════════════════════════════════
// DASHBOARD SCREEN — Pure bento grid, no sidebar
// ═══════════════════════════════════════════════════════════════════════════════

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final narrativeIdx = ref.watch(currentNarrativeIndexProvider);
    final isResuming = narrativeIdx > 0;
    final screenW = MediaQuery.of(context).size.width;
    final hPad = screenW > 900 ? 56.0 : (screenW > 500 ? 32.0 : 20.0);

    return Scaffold(
      backgroundColor: _kSurface,
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(top: 64.0), // Generous whitespace from top border
                child: _buildNetflixHero(context, hPad),
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(hPad, 48, hPad, 80),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // ── Bento Grid ──
                  LayoutBuilder(builder: (context, constraints) {
                    final w = constraints.maxWidth;
                    const gap = 14.0;

                    if (w < 500) {
                      return _buildGrid(context, ref, isResuming, narrativeIdx, gap, 1);
                    } else if (w < 900) {
                      return _buildGrid(context, ref, isResuming, narrativeIdx, gap, 2);
                    } else {
                      return _buildGrid(context, ref, isResuming, narrativeIdx, gap, 3);
                    }
                  }),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNetflixHero(BuildContext context, double hPad) {
    final screenW = MediaQuery.of(context).size.width;
    final screenH = MediaQuery.of(context).size.height;
    final isMobile = screenW < 450;
    
    // Scale hero height dynamically based on screen size so it stays responsive
    final heroHeight = isMobile 
        ? (screenH * 0.5).clamp(360.0, 460.0) // Kept shorter on mobile so portrait photo fits well
        : 640.0;

    final titleBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'PRISM',
          style: GoogleFonts.spaceGrotesk(
            fontSize: isMobile ? 56 : 86,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            letterSpacing: -3,
            height: 1.0,
          ),
        ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.08),
        const SizedBox(height: 16),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Text(
            'A Privacy Preserving and Revocable Identity System for Mitigating On-Chain Credential Irrevocability in Blockchain-Based Faculty Attendance Tracking Using Multimodal Biometrics, Smart Contracts, Decentralized Identity, and Quorum Byzantine Fault Tolerance',
            style: GoogleFonts.inter(
              fontSize: isMobile ? 14 : 16,
              fontWeight: FontWeight.w500,
              color: Colors.white54,
              height: 1.6,
            ),
          ),
        ).animate().fadeIn(delay: 200.ms, duration: 500.ms),
      ],
    );

    final buttons = Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        FilledButton.icon(
          onPressed: () async {
            final Uri url = Uri.parse('https://github.com/fait-lacatan/PRISM');
            if (!await launchUrl(url)) debugPrint('Could not launch $url');
          },
          icon: const Icon(Icons.code, size: 18),
          label: const Text('View Source'),
          style: FilledButton.styleFrom(
            backgroundColor: _kViolet, // Matching PRISM accent
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600),
          ),
        ),
        OutlinedButton.icon(
          onPressed: () async {
            final Uri url = Uri.parse('https://drive.google.com/file/d/1totQOAYRTH-1-jOY72Ybk-mRpKMAkrGz/view?usp=sharing');
            if (!await launchUrl(url)) debugPrint('Could not launch $url');
          },
          icon: const Icon(Icons.picture_as_pdf, size: 18),
          label: const Text('Read Paper'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            foregroundColor: Colors.white,
            side: BorderSide(color: Colors.white.withValues(alpha: 0.4), width: 1.5),
            textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ).animate().fadeIn(delay: 300.ms, duration: 500.ms);

    return SizedBox(
      height: heroHeight,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Graphic Backdrop
          Image.asset(
            'assets/images/Kiosk.14.png',
            fit: isMobile ? BoxFit.fitWidth : BoxFit.cover,
            alignment: isMobile ? Alignment.topCenter : const Alignment(0, -0.2), 
          ),
          
          // Gradient Fade to Dark
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0.3, 0.7, 1.0],
                colors: [
                  _kSurface.withValues(alpha: 0.0),
                  _kSurface.withValues(alpha: 0.7),
                  _kSurface,
                ],
              ),
            ),
          ),
          
          // Text & Actions
          Positioned(
            left: hPad,
            right: hPad,
            bottom: 24, // Slight offset from the content below
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                titleBlock,
                const SizedBox(height: 24),
                buttons,
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Hero stat card data ────────────────────────────────────────────────────

  static const _heroStats = [
    (
      label: 'Impostor Match Rate (FMR)',
      value: '0.00%',
      ci: '[0.00%, 0.15%]',
      subtext: 'Zero impostors passed the fingerprint + face gate across 50/50 live spoofing attempts',
      sentiment: 'positive',
      style: _CardStyle.dark,
    ),
    (
      label: 'Operational FNMR',
      value: '31.5%',
      ci: '[25.13%, 38.43%]',
      subtext: 'Intentional trade-off — same gate enforces credential revocation checks',
      sentiment: 'warning',
      style: _CardStyle.white,
    ),
    (
      label: 'FNMR Under Lighting',
      value: '0.00%',
      ci: null,
      subtext: 'Both controlled and uncontrolled conditions — no genuine rejections',
      sentiment: 'positive',
      style: _CardStyle.dark,
    ),
  ];

  // ── Unified grid builder ───────────────────────────────────────────────────

  Widget _buildGrid(
    BuildContext context,
    WidgetRef ref,
    bool isResuming,
    int narrativeIdx,
    double gap,
    int cols, // 1 = mobile, 2 = tablet, 3 = desktop
  ) {
    final children = <Widget>[];
    int delay = 0;
    const delayStep = 80;

    Widget animated(Widget child) {
      final d = delay;
      delay += delayStep;
      return child
          .animate()
          .fadeIn(delay: Duration(milliseconds: d), duration: 400.ms)
          .slideY(begin: 0.03);
    }

    // ── Row 1: Discovery (always full width) ──
    children.add(animated(
      _DiscoveryCard(isResuming: isResuming, narrativeIdx: narrativeIdx),
    ));
    children.add(SizedBox(height: gap));

    // ── Row 2: Factorial hero + Gallery split ──
    children.addAll(_pairedRow(
      const _FactorialHeroCard(),
      _PhotoGalleryCard(cols: cols),
      cols, gap, delay,
    ));
    delay += delayStep;

    // ── Row 3: Three hero stats ──
    if (cols == 1) {
      // Single column — stack all three
      for (final s in _heroStats) {
        children.add(animated(_HeroStatCard(
          label: s.label, value: s.value, ci: s.ci,
          subtext: s.subtext, sentiment: s.sentiment,
          style: s.style,
          onTap: () => context.goNamed('narrative', extra: const NarrativeFlowParams(chapterIds: ['chap_16', 'chap_18', 'chap_23'])),
        )));
        children.add(SizedBox(height: gap));
      }
    } else if (cols == 2) {
      // Tablet: first two side-by-side, third full width
      children.add(animated(IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: _HeroStatCard(
              label: _heroStats[0].label, value: _heroStats[0].value,
              ci: _heroStats[0].ci, subtext: _heroStats[0].subtext,
              sentiment: _heroStats[0].sentiment, style: _heroStats[0].style,
              onTap: () => context.goNamed('narrative', extra: const NarrativeFlowParams(chapterIds: ['chap_16', 'chap_18', 'chap_23'])),
            )),
            SizedBox(width: gap),
            Expanded(child: _HeroStatCard(
              label: _heroStats[1].label, value: _heroStats[1].value,
              ci: _heroStats[1].ci, subtext: _heroStats[1].subtext,
              sentiment: _heroStats[1].sentiment, style: _heroStats[1].style,
              onTap: () => context.goNamed('narrative', extra: const NarrativeFlowParams(chapterIds: ['chap_16', 'chap_18', 'chap_23'])),
            )),
          ],
        ),
      )));
      children.add(SizedBox(height: gap));
      children.add(animated(_HeroStatCard(
        label: _heroStats[2].label, value: _heroStats[2].value,
        ci: _heroStats[2].ci, subtext: _heroStats[2].subtext,
        sentiment: _heroStats[2].sentiment, style: _heroStats[2].style,
        onTap: () => context.goNamed('narrative', extra: const NarrativeFlowParams(chapterIds: ['chap_16', 'chap_18', 'chap_23'])),
      )));
      children.add(SizedBox(height: gap));
    } else {
      // Desktop: all three side-by-side
      children.add(animated(IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (int i = 0; i < 3; i++) ...[
              if (i > 0) SizedBox(width: gap),
              Expanded(child: _HeroStatCard(
                label: _heroStats[i].label, value: _heroStats[i].value,
                ci: _heroStats[i].ci, subtext: _heroStats[i].subtext,
                sentiment: _heroStats[i].sentiment, style: _heroStats[i].style,
                onTap: () => context.goNamed('narrative', extra: const NarrativeFlowParams(chapterIds: ['chap_16', 'chap_18', 'chap_23'])),
              )),
            ],
          ],
        ),
      )));
      children.add(SizedBox(height: gap));
    }

    // ── Row 4: Biometrics + Security ──
    children.addAll(_pairedRow(
      const _BiometricsSummaryCard(),
      const _SecuritySummaryCard(),
      cols, gap, delay,
    ));
    delay += delayStep;

    // ── Row 5: Blockchain + Latency ──
    children.addAll(_pairedRow(
      const _BlockchainSummaryCard(),
      const _LatencySummaryCard(),
      cols, gap, delay,
    ));

    return Column(children: children);
  }

  /// Builds a pair of cards: side-by-side when cols >= 2, stacked when cols == 1.
  /// Always uses IntrinsicHeight to ensure matched heights.
  List<Widget> _pairedRow(
    Widget a, Widget b, int cols, double gap, int delayMs,
  ) {
    if (cols == 1) {
      return [
        a.animate().fadeIn(delay: Duration(milliseconds: delayMs), duration: 400.ms).slideY(begin: 0.03),
        SizedBox(height: gap),
        b.animate().fadeIn(delay: Duration(milliseconds: delayMs + 80), duration: 400.ms).slideY(begin: 0.03),
        SizedBox(height: gap),
      ];
    }
    return [
      IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: a),
            SizedBox(width: gap),
            Expanded(child: b),
          ],
        ),
      ).animate().fadeIn(delay: Duration(milliseconds: delayMs), duration: 400.ms).slideY(begin: 0.03),
      SizedBox(height: gap),
    ];
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// CARD WIDGETS
// ═══════════════════════════════════════════════════════════════════════════════

// ─── Discovery Card (entry point) ────────────────────────────────────────────

class _DiscoveryCard extends ConsumerWidget {
  final bool isResuming;
  final int narrativeIdx;

  const _DiscoveryCard({
    required this.isResuming,
    required this.narrativeIdx,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chaptersAsync = ref.watch(narrativeFlowProvider);
    final String currentChapterTitle = chaptersAsync.when(
      data: (chapters) {
        if (chapters.isEmpty) return 'Hierarchical Narrative';
        if (narrativeIdx >= chapters.length) return 'Start Discovery'; 
        return chapters[narrativeIdx].title;
      },
      loading: () => 'Loading...',
      error: (err, stack) => 'Hierarchical Narrative',
    );

    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: () => context.goNamed('narrative', extra: narrativeIdx),
        style: FilledButton.styleFrom(
          backgroundColor: _kViolet,
          foregroundColor: Colors.white,
          elevation: 8,
          shadowColor: _kViolet.withValues(alpha: 0.5),
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(100),
          ),
        ),
        child: Row(
          children: [
            Icon(
              isResuming
                  ? Icons.bookmark_rounded
                  : Icons.auto_stories_rounded,
              size: 28,
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isResuming ? 'Resume Discovery' : 'Start Discovery',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isResuming
                        ? '${narrativeIdx + 1} · $currentChapterTitle'
                        : 'PRISM in knowledge chunks',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.white38,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_rounded, size: 28),
          ],
        ),
      ),
    );
  }
}

// ─── Factorial Hero Card ─────────────────────────────────────────────────────

class _FactorialHeroCard extends StatelessWidget {
  const _FactorialHeroCard();

  @override
  Widget build(BuildContext context) {
    return _CardShell(
      accentColor: _kViolet,
      style: _CardStyle.white,
      onTap: () => context.goNamed('narrative', extra: const NarrativeFlowParams(chapterIds: ['chap_22', 'chap_27'])),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionLabel('Hypothesis · Core Result', style: _CardStyle.white),
          const SizedBox(height: 12),
          Text(
            'Architecture × Credential State',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: _CardStyle.white.textPrimary,
            ),
          ),
          const SizedBox(height: 20),
          // 2×2 matrix
          _buildMatrix(context),
          const SizedBox(height: 20),
          // Verdict row
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _VerdictBadge(label: 'H₀ REJECTED', color: _kGreen),
              Text(
                'β = −6.767 · OR = 0.001 · p = 6.02 × 10⁻³',
                style: GoogleFonts.firaCode(
                    fontSize: 11, color: Colors.white38),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Sensitivity
          Text('Sensitivity Analysis',
              style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.white54)),
          const SizedBox(height: 8),
          _buildSensitivityRows(),
          const SizedBox(height: 12),
          Text(
            'Parallel system is structurally blind to revocation. SSI drops revoked acceptance from 100% → 0%.',
            style: GoogleFonts.inter(
                fontSize: 12, color: Colors.white38, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildMatrix(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _CardStyle.white.border),
      ),
      child: Column(
        children: [
          // Header row
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.04),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(15)),
            ),
            child: Row(
              children: [
                const Expanded(flex: 2, child: SizedBox()),
                Expanded(
                    flex: 3,
                    child: Text('Parallel Fusion',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.firaCode(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: _CardStyle.white.textSecondary))),
                Expanded(
                    flex: 3,
                    child: Text('Proposed (SSI)',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.firaCode(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: _CardStyle.white.textSecondary))),
              ],
            ),
          ),
          // Active row
          _matrixRow('Active', '100%', '200/200', null, '68.5%', '137/200', null),
          // Revoked row
          _matrixRow(
              'Revoked', '100%', '200/200', _kRed, '0%', '0/200', _kGreen),
        ],
      ),
    );
  }

  Widget _matrixRow(String label, String v1, String n1, Color? h1, String v2,
      String n2, Color? h2) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: _CardStyle.white.border)),
      ),
      child: Row(
        children: [
          Expanded(
              flex: 2,
              child: Text(label,
                  style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _CardStyle.white.textSecondary))),
          Expanded(flex: 3, child: _matrixCell(v1, n1, h1)),
          Expanded(flex: 3, child: _matrixCell(v2, n2, h2)),
        ],
      ),
    );
  }

  Widget _matrixCell(String value, String n, Color? highlight) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.spaceGrotesk(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: highlight ?? _CardStyle.white.textPrimary,
          ),
        ),
        Text(n,
            style: GoogleFonts.firaCode(fontSize: 10, color: _CardStyle.white.textMuted)),
      ],
    );
  }

  Widget _buildSensitivityRows() {
    const items = [
      ('Worst-case clustering', '0.0298', 'Significant'),
      ('Moderate clustering', '0.0133', 'Significant'),
      ('Best-case clustering', '0.0013', 'Strongest'),
    ];
    return Column(
      children: items
          .map((e) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                          color: _kGreen, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text(e.$1,
                            style: GoogleFonts.inter(
                                fontSize: 11, color: _CardStyle.white.textSecondary))),
                    Text('p = ${e.$2}',
                        style: GoogleFonts.firaCode(
                            fontSize: 10, color: _CardStyle.white.textMuted)),
                    const SizedBox(width: 8),
                    _SmallBadge(label: e.$3, color: _kGreen),
                  ],
                ),
              ))
          .toList(),
    );
  }
}

// ─── Photo Gallery Card ──────────────────────────────────────────────────────

class _PhotoGalleryCard extends StatelessWidget {
  final int cols;
  const _PhotoGalleryCard({required this.cols});

  @override
  Widget build(BuildContext context) {
    final images = GalleryData.allImages;
    final String heroImagePath = images.isNotEmpty 
        ? images[math.Random().nextInt(images.length)]
        : 'assets/images/hardware/kiosk_1.jpg';

    Widget content = Container(
      decoration: BoxDecoration(
        image: DecorationImage(
          image: AssetImage(heroImagePath),
          fit: BoxFit.cover,
        ),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: const [0.4, 1.0],
            colors: [
              Colors.black.withValues(alpha: 0.1),
              Colors.black.withValues(alpha: 0.8),
            ],
          ),
        ),
        child: Align(
          alignment: Alignment.bottomLeft,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Icon(Icons.photo_library_rounded, color: Colors.white, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'PROJECT GALLERY',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.0,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Tap to view',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (cols == 1) {
      content = AspectRatio(aspectRatio: 16 / 10, child: content);
    }

    return _CardShell(
      accentColor: Colors.white,
      padding: EdgeInsets.zero,
      onTap: () => context.pushNamed('gallery'),
      child: content,
    );
  }
}

// ─── Hero Stat Card ──────────────────────────────────────────────────────────

class _HeroStatCard extends StatelessWidget {
  final String label;
  final String value;
  final String? ci;
  final String subtext;
  final String sentiment;
  final _CardStyle style;
  final VoidCallback? onTap;

  const _HeroStatCard({
    required this.label,
    required this.value,
    this.ci,
    required this.subtext,
    required this.sentiment,
    this.style = _CardStyle.dark,
    this.onTap,
  });

  Color get _sentimentColor {
    switch (sentiment) {
      case 'positive':
        return _kGreen;
      case 'warning':
        return _kAmber;
      default:
        return _kMuted;
    }
  }

  @override
  Widget build(BuildContext context) {
    return _CardShell(
      accentColor: _sentimentColor,
      style: style,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.0,
              color: style.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 36,
              fontWeight: FontWeight.w900,
              color: style.textPrimary,
              height: 1.0,
            ),
          ),
          if (ci != null) ...[
            const SizedBox(height: 6),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: _sentimentColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'CI: $ci',
                style: GoogleFonts.firaCode(
                    fontSize: 10, color: _sentimentColor),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Text(
            subtext,
            style: GoogleFonts.inter(
                fontSize: 12, color: style.textMuted, height: 1.5),
          ),
        ],
      ),
    );
  }
}

// ─── Biometrics Summary Card ─────────────────────────────────────────────────

class _BiometricsSummaryCard extends StatelessWidget {
  const _BiometricsSummaryCard();

  @override
  Widget build(BuildContext context) {
    return _CardShell(
      accentColor: _kViolet,
      style: _CardStyle.white,
      onTap: () => context.goNamed('narrative', extra: const NarrativeFlowParams(chapterIds: ['chap_18', 'chap_23'])),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionLabel('SO1 · Biometrics', style: _CardStyle.white),
          const SizedBox(height: 8),
          Text('Biometric Accuracy',
              style: GoogleFonts.spaceGrotesk(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: _CardStyle.white.textPrimary)),
          const SizedBox(height: 16),
          const _MetricRow(
            label: 'EER reduction (face)',
            value: '−16.99 pp',
            detail: '26.32% → 9.33% · InceptionResNet → EfficientNet-B0',
            sentiment: 'positive',
            style: _CardStyle.white,
          ),
          const _MetricRow(
            label: 'Best fingerprint EER',
            value: '1.66%',
            detail: 'L=2048, k=16, high-quality config',
            sentiment: 'positive',
            style: _CardStyle.white,
          ),
          const _MetricRow(
            label: 'Quality tier EER gap',
            value: '3.72×',
            detail: 'Low quality 8.69% vs. high quality 2.34%',
            sentiment: 'positive',
            style: _CardStyle.white,
          ),
          const SizedBox(height: 16),
          // Unlinkability table
          Text('Template Unlinkability (ISO 30136)',
              style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: _CardStyle.white.textSecondary)),
          const SizedBox(height: 4),
          Text('Threshold: D_sys < 0.1',
              style: GoogleFonts.firaCode(
                  fontSize: 10, color: _CardStyle.white.textMuted)),
          const SizedBox(height: 8),
          const _UnlinkRow('C3 · EfficientNet / Local', '0.0725', true, style: _CardStyle.white),
          const _UnlinkRow('C4 · InceptionResNet / Local', '0.0042', true, style: _CardStyle.white),
          const _UnlinkRow('C1 · EfficientNet / YTFDB', '0.1960', false, style: _CardStyle.white),
          const _UnlinkRow('C2 · InceptionResNet / YTFDB', '0.1694', false, style: _CardStyle.white),
          const SizedBox(height: 8),
          Text(
            'Production (local) models satisfy threshold. YTFDB conditions are non-production.',
            style: GoogleFonts.inter(
                fontSize: 11, color: _CardStyle.white.textMuted, height: 1.4),
          ),
        ],
      ),
    );
  }
}

// ─── Security Summary Card ───────────────────────────────────────────────────

class _SecuritySummaryCard extends StatelessWidget {
  const _SecuritySummaryCard();

  @override
  Widget build(BuildContext context) {
    return _CardShell(
      accentColor: _kGreen,
      onTap: () => context.goNamed('narrative', extra: const NarrativeFlowParams(chapterIds: ['chap_20', 'chap_25'])),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionLabel('SO3 · Credential Security'),
          const SizedBox(height: 8),
          Text('Adversarial & Replay Tests',
              style: GoogleFonts.spaceGrotesk(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.white)),
          const SizedBox(height: 16),
          // Hero stat
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('22 / 22',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 36,
                    fontWeight: FontWeight.w900,
                    color: _kGreen,
                    height: 1.0,
                  )),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text('guards defeated',
                      style: GoogleFonts.inter(
                          fontSize: 13, color: Colors.white54)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'All attack classes → EVM revert. Zero unauthorized state changes.',
            style: GoogleFonts.inter(
                fontSize: 12, color: Colors.white38, height: 1.4),
          ),
          const SizedBox(height: 16),
          // Checklist
          _CheckRow('Consumed voucher reuse', 'BLOCKED'),
          _CheckRow('Reissue on suspended DID', 'BLOCKED'),
          _CheckRow('Two-phase revocation grace', 'ENFORCED'),
          _CheckRow('Reissue during pending revocation', 'BLOCKED'),
          _CheckRow('Rapid double-submit (nonce)', 'BLOCKED'),
        ],
      ),
    );
  }
}

// ─── Blockchain Summary Card ─────────────────────────────────────────────────

class _BlockchainSummaryCard extends StatelessWidget {
  const _BlockchainSummaryCard();

  @override
  Widget build(BuildContext context) {
    return _CardShell(
      accentColor: const Color(0xFF3B82F6),
      onTap: () => context.goNamed('narrative', extra: const NarrativeFlowParams(chapterIds: ['chap_19', 'chap_24'])),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionLabel('SO2 · Blockchain'),
          const SizedBox(height: 8),
          Text('Blockchain Performance',
              style: GoogleFonts.spaceGrotesk(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.white)),
          const SizedBox(height: 16),
          _MetricRow(
            label: 'Peak ingestion throughput',
            value: '1,192.9 TPS',
            detail:
                'Wired · pre-saturation knee at 1,500 TPS. Wired vs. wireless gap negligible (d = 0.05, p = 0.965).',
            sentiment: 'positive',
          ),
          _MetricRow(
            label: 'Sustained CPU per node',
            value: '6.7–7.2%',
            detail: 'P95 ≤ 23.2% · GC max pause 23 ms vs. 2,000 ms block period',
            sentiment: 'positive',
          ),
          _MetricRow(
            label: 'Consensus ceiling',
            value: '~30 TPS',
            detail:
                'Intentional QBFT serialization (~54,000 tx/hr). Ingestion vs. consensus gap 8.4×.',
            sentiment: 'neutral',
          ),
          const SizedBox(height: 16),
          // Gas CV mini table
          Text('Gas Coefficient of Variation',
              style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.white54)),
          const SizedBox(height: 4),
          Text('All ops within ≤10% CV threshold',
              style: GoogleFonts.firaCode(
                  fontSize: 10, color: Colors.white24)),
          Builder(
            builder: (context) {
              final screenW = MediaQuery.of(context).size.width;
              if (screenW > 400) {
                return Row(
                  children: [
                    _GasBadge('Enroll', '0.05%'),
                    const SizedBox(width: 8),
                    _GasBadge('Record', '0.00%'),
                    const SizedBox(width: 8),
                    _GasBadge('Reissue', '5.68%'),
                    const SizedBox(width: 8),
                    _GasBadge('Revoke', '0.00%'),
                  ],
                );
              }
              return Column(
                children: [
                  Row(children: [
                    _GasBadge('Enroll', '0.05%'),
                    const SizedBox(width: 8),
                    _GasBadge('Record', '0.00%'),
                  ]),
                  const SizedBox(height: 8),
                  Row(children: [
                    _GasBadge('Reissue', '5.68%'),
                    const SizedBox(width: 8),
                    _GasBadge('Revoke', '0.00%'),
                  ]),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

// ─── Latency Summary Card ────────────────────────────────────────────────────

class _LatencySummaryCard extends StatelessWidget {
  const _LatencySummaryCard();

  @override
  Widget build(BuildContext context) {
    return _CardShell(
      accentColor: _kAmber,
      style: _CardStyle.white,
      onTap: () => context.goNamed('narrative', extra: const NarrativeFlowParams(chapterIds: ['chap_21', 'chap_26'])),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionLabel('SO4 · Performance', style: _CardStyle.white),
          const SizedBox(height: 8),
          Text('End-to-End Latency',
              style: GoogleFonts.spaceGrotesk(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: _CardStyle.white.textPrimary)),
          const SizedBox(height: 16),
          // Enrollment breakdown
          Text('ENROLLMENT P95',
              style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                  color: _kAmber.withValues(alpha: 0.7))),
          const SizedBox(height: 6),
          Text('47.1 s',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: _CardStyle.white.textPrimary,
                height: 1.0,
              )),
          const SizedBox(height: 12),
          _LatencyComponent(
              'Fingerprint sensor', '29.8 s', 63.3, _kAmber),
          _LatencyComponent(
              'Face capture', '8.8 s', 18.7, _kAmber),
          _LatencyComponent(
              'AI inference', '10.9 s', 23.1, _kViolet),
          _LatencyComponent(
              'Chain anchoring', '3.5 s', 7.4, const Color(0xFF3B82F6)),
          const SizedBox(height: 6),
          Text('Hardware capture dominates',
              style: GoogleFonts.inter(
                  fontSize: 11, color: _CardStyle.white.textMuted)),
          const SizedBox(height: 20),
          // Verification
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _CardStyle.white.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('VERIFICATION MEAN',
                    style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        color: _CardStyle.white.textMuted)),
                const SizedBox(height: 4),
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    Text('2,867 ms',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: _CardStyle.white.textPrimary,
                        )),
                    Text(
                      '~4–5 verifications/min',
                      style: GoogleFonts.firaCode(
                          fontSize: 10, color: _CardStyle.white.textMuted),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Ledger lookup < 100 ms at P95',
                  style: GoogleFonts.firaCode(
                      fontSize: 10, color: _CardStyle.white.textMuted),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'IPFS penalty −76.5% (367 → 86 TPS); CPU unchanged at ~7%. Negligible in consensus mode.',
            style: GoogleFonts.inter(
                fontSize: 11, color: _CardStyle.white.textSecondary, height: 1.4),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// SHARED MICRO-WIDGETS
// ═══════════════════════════════════════════════════════════════════════════════

// ─── Card Style ──────────────────────────────────────────────────────────────

class _CardStyle {
  final Color background;
  final Color border;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;

  const _CardStyle({
    required this.background,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
  });

  static const dark = _CardStyle(
    background: _kCard,
    border: _kCardBorder,
    textPrimary: Colors.white,
    textSecondary: Colors.white70,
    textMuted: Colors.white38,
  );

  static const black = _CardStyle(
    background: Colors.black,
    border: Color(0xFF27272A),
    textPrimary: Colors.white,
    textSecondary: Colors.white70,
    textMuted: Colors.white38,
  );

  static const white = _CardStyle(
    background: Colors.white,
    border: Color(0xFFE4E4E7),
    textPrimary: Color(0xFF09090B),
    textSecondary: Color(0xFF52525B),
    textMuted: Color(0xFFA1A1AA),
  );
}

// ─── Card Shell ──────────────────────────────────────────────────────────────

class _CardShell extends StatelessWidget {
  final Widget child;
  final Color accentColor;
  final _CardStyle style;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;

  const _CardShell({
    required this.child,
    required this.accentColor,
    this.style = _CardStyle.dark,
    this.onTap,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.of(context).size.width;
    final pad = padding ?? EdgeInsets.all(screenW < 400 ? 16.0 : 24.0);
    
    Widget content = Container(
      width: double.infinity,
      padding: pad,
      decoration: BoxDecoration(
        color: style.background,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: style == _CardStyle.white 
              ? style.border 
              : accentColor.withValues(alpha: 0.2),
          width: style == _CardStyle.black ? 1.5 : 1.0,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );

    if (onTap != null) {
      content = Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: content,
        ),
      );
    }

    return content;
  }
}

// ─── Section Label ───────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  final _CardStyle style;
  const _SectionLabel(this.text, {this.style = _CardStyle.dark});

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: GoogleFonts.inter(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
        color: style.textMuted,
      ),
    );
  }
}

// ─── Verdict Badge ───────────────────────────────────────────────────────────

class _VerdictBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _VerdictBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: GoogleFonts.spaceGrotesk(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: color,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

// ─── Small Badge ─────────────────────────────────────────────────────────────

class _SmallBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _SmallBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

// ─── Metric Row ──────────────────────────────────────────────────────────────

class _MetricRow extends StatelessWidget {
  final String label;
  final String value;
  final String detail;
  final String sentiment;
  final _CardStyle style;

  const _MetricRow({
    required this.label,
    required this.value,
    required this.detail,
    required this.sentiment,
    this.style = _CardStyle.dark,
  });

  Color get _color {
    switch (sentiment) {
      case 'positive':
        return _kGreen;
      case 'warning':
        return _kAmber;
      default:
        return _kMuted;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 5),
            width: 6,
            height: 6,
            decoration:
                BoxDecoration(color: _color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(label,
                          style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: style.textPrimary)),
                    ),
                    Text(value,
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: style.textPrimary,
                        )),
                  ],
                ),
                const SizedBox(height: 2),
                Text(detail,
                    style: GoogleFonts.inter(
                        fontSize: 11,
                        color: style.textMuted,
                        height: 1.3)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Unlinkability Row ───────────────────────────────────────────────────────

class _UnlinkRow extends StatelessWidget {
  final String condition;
  final String dSys;
  final bool pass;
  final _CardStyle style;

  const _UnlinkRow(this.condition, this.dSys, this.pass, {this.style = _CardStyle.dark});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
              child: Text(condition,
                  style: GoogleFonts.firaCode(
                      fontSize: 10, color: style.textSecondary))),
          const SizedBox(width: 8),
          Text(dSys,
              style: GoogleFonts.firaCode(
                  fontSize: 10, color: style.textMuted)),
          const SizedBox(width: 8),
          _SmallBadge(
            label: pass ? 'PASS' : 'FAIL',
            color: pass ? _kGreen : _kRed,
          ),
        ],
      ),
    );
  }
}

// ─── Check Row ───────────────────────────────────────────────────────────────

class _CheckRow extends StatelessWidget {
  final String test;
  final String result;

  const _CheckRow(this.test, this.result);

  @override
  Widget build(BuildContext context) {
    final color = result == 'ENFORCED' ? _kAmber : _kGreen;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            result == 'ENFORCED'
                ? Icons.check_circle_outline
                : Icons.block_rounded,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 8),
          Expanded(
              child: Text(test,
                  style: GoogleFonts.inter(
                      fontSize: 12, color: Colors.white54))),
          _SmallBadge(label: result, color: color),
        ],
      ),
    );
  }
}

// ─── Gas Badge ───────────────────────────────────────────────────────────────

class _GasBadge extends StatelessWidget {
  final String op;
  final String cv;

  const _GasBadge(this.op, this.cv);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _kCardBorder),
        ),
        child: Column(
          children: [
            Text(op,
                style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Colors.white38)),
            const SizedBox(height: 2),
            Text(cv,
                style: GoogleFonts.firaCode(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _kGreen)),
          ],
        ),
      ),
    );
  }
}

// ─── Latency Component Bar ───────────────────────────────────────────────────

class _LatencyComponent extends StatelessWidget {
  final String name;
  final String valueStr;
  final double pct;
  final Color color;

  const _LatencyComponent(this.name, this.valueStr, this.pct, this.color);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(name,
                style: GoogleFonts.inter(
                    fontSize: 11, color: _CardStyle.white.textSecondary)),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 4,
            child: Container(
              height: 8,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(4),
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: pct / 100,
                child: Container(
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 44,
            child: Text(valueStr,
                textAlign: TextAlign.right,
                style: GoogleFonts.firaCode(
                    fontSize: 10, color: _CardStyle.white.textSecondary)),
          ),
        ],
      ),
    );
  }
}
