import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/data/narrative_repository.dart';
import '../../core/routing/router.dart';
import 'chapters/chapter_renderer.dart';

class NarrativeScreen extends ConsumerStatefulWidget {
  final int initialIndex;
  final NarrativeFlowParams? flowParams;

  const NarrativeScreen({
    super.key,
    this.initialIndex = 0,
    this.flowParams,
  });

  @override
  ConsumerState<NarrativeScreen> createState() => _NarrativeScreenState();
}

class _NarrativeScreenState extends ConsumerState<NarrativeScreen> {
  late PageController _pageController;
  int _currentIndex = 0;

  /// Whether we're in an isolated mini-flow (came from a dashboard card)
  bool get _isMiniFlow => widget.flowParams != null;

  @override
  void initState() {
    super.initState();
    _currentIndex = _isMiniFlow ? 0 : widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() => _currentIndex = index);
    // Only persist position for the full narrative flow
    if (!_isMiniFlow) {
      ref.read(currentNarrativeIndexProvider.notifier).setIndex(index);
    }
  }

  void _nextPage(int total) {
    if (_currentIndex < total - 1) {
      _pageController.nextPage(
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOutCubic);
    }
  }

  void _prevPage() {
    if (_currentIndex > 0) {
      _pageController.previousPage(
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOutCubic);
    }
  }

  @override
  Widget build(BuildContext context) {
    final flowAsync = ref.watch(narrativeFlowProvider);

    return flowAsync.when(
      loading: () => const Scaffold(
        backgroundColor: Color(0xFF060608),
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (err, stack) => Scaffold(
        backgroundColor: const Color(0xFF060608),
        body: Center(child: Text('Error: $err')),
      ),
      data: (allChapters) {
        if (allChapters.isEmpty) return const Scaffold(backgroundColor: Color(0xFF060608), body: Center(child: Text('No content')));

        // Filter chapters for mini-flows
        final chapters = _isMiniFlow
            ? allChapters
                .where((c) => widget.flowParams!.chapterIds.contains(c.id))
                .toList()
            : allChapters;

        if (chapters.isEmpty) {
          return Scaffold(
            backgroundColor: const Color(0xFF060608),
            body: Center(
              child: Text('No matching chapters found',
                  style: GoogleFonts.inter(color: Colors.white38)),
            )
          );
        }

        final isNarrow = MediaQuery.of(context).size.width <= 900;

        return Scaffold(
          backgroundColor: const Color(0xFF060608),
          appBar: AppBar(
            backgroundColor: Colors.black,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white70),
              onPressed: () => context.goNamed('home'),
            ),
            actions: [
              if (!_isMiniFlow && isNarrow)
                IconButton(
                  icon: const Icon(Icons.menu_rounded, color: Colors.white70),
                  tooltip: 'Chapters',
                  onPressed: () {
                    showModalBottomSheet(
                      context: context,
                      backgroundColor: const Color(0xFF111114),
                      isScrollControlled: true,
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                      ),
                      builder: (context) {
                        return SizedBox(
                          height: MediaQuery.of(context).size.height * 0.7,
                          child: Column(
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(top: 12, bottom: 8),
                                child: Container(
                                  width: 40,
                                  height: 4,
                                  decoration: BoxDecoration(
                                    color: Colors.white24,
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: _ChapterList(
                                  chapters: chapters,
                                  currentIndex: _currentIndex,
                                  onChapterSelected: (i) {
                                    Navigator.pop(context);
                                    _pageController.animateToPage(i,
                                        duration: const Duration(milliseconds: 500),
                                        curve: Curves.easeInOutCubic);
                                  },
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              const SizedBox(width: 8),
            ],
            title: const SizedBox.shrink(),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Container(height: 1, color: const Color(0xFF18181B)),
            ),
          ),
          body: Row(
            children: [
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  physics: const BouncingScrollPhysics(),
                  onPageChanged: _onPageChanged,
                  itemCount: chapters.length,
                  itemBuilder: (ctx, i) {
                    final chapter = chapters[i];

                    // JSON chapters → ChapterRenderer (template-driven)
                    if (chapter.contentType == 'json') {
                      return _ChapterPage(
                        index: i,
                        total: chapters.length,
                        isMiniFlow: _isMiniFlow,
                        onNext: () => _nextPage(chapters.length),
                        onPrev: _prevPage,
                        onFinish: () {
                          if (!_isMiniFlow) ref.read(currentNarrativeIndexProvider.notifier).setIndex(0);
                          context.goNamed('home');
                        },
                        child: ChapterRenderer(jsonFile: chapter.file, chapterIndex: i),
                      );
                    }

                    // MD chapters → old markdown-based layout
                    return _MarkdownPage(
                      chapter: chapter,
                      index: i,
                      total: chapters.length,
                      isMiniFlow: _isMiniFlow,
                      onNext: () => _nextPage(chapters.length),
                      onPrev: _prevPage,
                      onFinish: () {
                        if (!_isMiniFlow) ref.read(currentNarrativeIndexProvider.notifier).setIndex(0);
                        context.goNamed('home');
                      },
                    );
                  },
                ),
              ),
              
              // Progress sidebar (desktop) — only show for full narrative
              if (!_isMiniFlow && !isNarrow)
                Container(
                  width: 320,
                  decoration: const BoxDecoration(
                    color: Colors.black,
                    border: Border(left: BorderSide(color: Color(0xFF18181B))),
                  ),
                  child: _ChapterList(
                    chapters: chapters,
                    currentIndex: _currentIndex,
                    onChapterSelected: (i) {
                      _pageController.animateToPage(i,
                          duration: const Duration(milliseconds: 500),
                          curve: Curves.easeInOutCubic);
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Wraps the ChapterRenderer (JSON-driven) with bottom nav buttons.
class _ChapterPage extends StatelessWidget {
  final int index;
  final int total;
  final bool isMiniFlow;
  final VoidCallback onNext;
  final VoidCallback onPrev;
  final VoidCallback onFinish;
  final Widget child;

  const _ChapterPage({
    required this.index,
    required this.total,
    required this.onNext,
    required this.onPrev,
    required this.onFinish,
    required this.child,
    this.isMiniFlow = false,
  });

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.of(context).size.width;
    final hPad = screenW > 700 ? 64.0 : 20.0;

    return Column(
      children: [
        Expanded(child: child),
        // Bottom navigation
        Container(
          padding: EdgeInsets.fromLTRB(hPad, 16, hPad, 24),
          decoration: const BoxDecoration(
            color: Color(0xFF060608),
            border: Border(top: BorderSide(color: Color(0xFF18181B))),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (index > 0)
                Flexible(
                  child: OutlinedButton.icon(
                    onPressed: onPrev,
                    icon: const Icon(Icons.arrow_back_rounded, size: 16),
                    label: const Text('Previous'),
                  ),
                )
              else
                const SizedBox(),
              const SizedBox(width: 12),
              if (index < total - 1)
                Flexible(
                  child: FilledButton(
                    onPressed: onNext,
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Next'),
                        SizedBox(width: 8),
                        Icon(Icons.arrow_forward_rounded, size: 16),
                      ],
                    ),
                  ),
                )
              else
                Flexible(
                  child: FilledButton.icon(
                    onPressed: onFinish,
                    icon: Icon(
                      isMiniFlow ? Icons.dashboard_rounded : Icons.flag_rounded,
                      size: 16,
                    ),
                    label: Text(isMiniFlow ? 'Dashboard' : 'Finish'),
                    style: FilledButton.styleFrom(
                      backgroundColor: isMiniFlow
                          ? const Color(0xFF3B82F6)
                          : const Color(0xFF059669),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Markdown-based page for chapters that use .md content files.
class _MarkdownPage extends ConsumerWidget {
  final dynamic chapter;
  final int index;
  final int total;
  final bool isMiniFlow;
  final VoidCallback onNext;
  final VoidCallback onPrev;
  final VoidCallback onFinish;

  const _MarkdownPage({
    required this.chapter,
    required this.index,
    required this.total,
    required this.onNext,
    required this.onPrev,
    required this.onFinish,
    this.isMiniFlow = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contentAsync = ref.watch(narrativeChapterContentProvider(chapter.file));

    return Scaffold(
      backgroundColor: const Color(0xFF060608),
      body: contentAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error loading markdown: $err')),
        data: (markdownText) {
          final screenW = MediaQuery.of(context).size.width;
          final mdPad = screenW < 500 ? 20.0 : 64.0;
          return CustomScrollView(
            slivers: [
              SliverPadding(
                padding: EdgeInsets.fromLTRB(mdPad, mdPad, mdPad, 80),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    Text(
                      'SECTION ${index + 1}',
                      style: GoogleFonts.firaCode(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF3B82F6),
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      chapter.title,
                      style: Theme.of(context).textTheme.displayMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      chapter.subtitle,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            color: Colors.white38,
                          ),
                    ),
                    const SizedBox(height: 48),

                    // Markdown Content
                    MarkdownBody(
                      data: markdownText,
                      selectable: true,
                      styleSheet: MarkdownStyleSheet(
                        p: GoogleFonts.inter(
                            fontSize: 16, color: Colors.white70, height: 1.7),
                        h1: GoogleFonts.spaceGrotesk(
                            fontSize: 28, color: Colors.white, fontWeight: FontWeight.w700),
                        h2: GoogleFonts.spaceGrotesk(
                            fontSize: 22, color: Colors.white, fontWeight: FontWeight.w700),
                        listBullet: const TextStyle(color: Color(0xFF3B82F6)),
                        blockquote: GoogleFonts.inter(
                          fontSize: 16,
                          fontStyle: FontStyle.italic,
                          color: Colors.white54,
                        ),
                        blockquoteDecoration: const BoxDecoration(
                          border: Border(left: BorderSide(color: Color(0xFF3B82F6), width: 4)),
                        ),
                        blockquotePadding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
                      ),
                    ),

                    const SizedBox(height: 80),

                    // Navigation Actions
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        if (index > 0)
                          OutlinedButton.icon(
                            onPressed: onPrev,
                            icon: const Icon(Icons.arrow_back_rounded, size: 16),
                            label: const Text('Previous'),
                          )
                        else
                          const SizedBox(),
                        
                        if (index < total - 1)
                          FilledButton(
                            onPressed: onNext,
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('Next'),
                                SizedBox(width: 8),
                                Icon(Icons.arrow_forward_rounded, size: 16),
                              ],
                            ),
                          )
                        else
                          FilledButton.icon(
                            onPressed: onFinish,
                            icon: Icon(
                              isMiniFlow ? Icons.dashboard_rounded : Icons.flag_rounded,
                              size: 16,
                            ),
                            label: Text(isMiniFlow ? 'Dashboard' : 'Finish Discovery'),
                            style: FilledButton.styleFrom(
                              backgroundColor: isMiniFlow
                                  ? const Color(0xFF3B82F6)
                                  : const Color(0xFF059669),
                            ),
                          ),
                      ],
                    ),
                  ]),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ─── Shared Components ───────────────────────────────────────────────────────

class _ChapterList extends StatelessWidget {
  final List<dynamic> chapters;
  final int currentIndex;
  final Function(int) onChapterSelected;

  const _ChapterList({
    required this.chapters,
    required this.currentIndex,
    required this.onChapterSelected,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(32),
      itemCount: chapters.length,
      itemBuilder: (ctx, i) {
        final isActive = i == currentIndex;
        final isPast = i < currentIndex;

        return InkWell(
          onTap: () => onChapterSelected(i),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: isActive
                        ? const Color(0xFF3B82F6)
                        : isPast ? const Color(0xFF2563EB).withValues(alpha: 0.2) : const Color(0xFF18181B),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isActive
                          ? const Color(0xFF3B82F6)
                          : const Color(0xFF27272A),
                    ),
                  ),
                  child: Center(
                    child: Text(
                      '${i + 1}',
                      style: GoogleFonts.firaCode(
                        fontSize: 10,
                        color: isActive ? Colors.white : isPast ? Colors.white70 : Colors.white24,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    chapters[i].title,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                      color: isActive ? Colors.white : Colors.white38,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
