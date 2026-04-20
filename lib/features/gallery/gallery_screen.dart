import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'gallery_data.dart';
const _kSurface = Color(0xFF060608);
const _kCardBorder = Color(0xFF1E1E24);
const _kViolet = Color(0xFF7C3AED);

class GalleryScreen extends StatelessWidget {
  const GalleryScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: _kSurface,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(32, 32, 32, 16),
                child: Row(
                  children: [
                    Material(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(16),
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                        onPressed: () => context.pop(),
                      ),
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('PRISM IN THE WORKS', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1.5, color: _kViolet.withValues(alpha: 0.8))),
                          const SizedBox(height: 4),
                          Text('Gallery', style: GoogleFonts.spaceGrotesk(fontSize: 32, fontWeight: FontWeight.w800, color: Colors.white, height: 1.0)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              TabBar(
                isScrollable: true,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                tabAlignment: TabAlignment.start,
                indicatorColor: _kViolet,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white54,
                labelStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
                tabs: const [
                  Tab(text: 'Software'),
                  Tab(text: 'Hardware'),
                  Tab(text: 'Process'),
                  Tab(text: 'People'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    _AlbumGrid(images: GalleryData.softwareImages),
                    _AlbumGrid(images: GalleryData.hardwareImages),
                    _AlbumGrid(images: GalleryData.processImages),
                    _AlbumGrid(images: GalleryData.peopleImages),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AlbumGrid extends StatelessWidget {
  final List<String> images;
  const _AlbumGrid({required this.images});

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.all(32),
          sliver: SliverToBoxAdapter(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final int cols = constraints.maxWidth < 600 ? 2 : 4;
                return _buildStaggeredGrid(cols, images);
              },
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 80)),
      ],
    );
  }

  Widget _buildStaggeredGrid(int cols, List<String> images) {
    // Pinterest style distribution algorithm
    if (images.isEmpty) return const SizedBox.shrink();

    final columnWidgets = List.generate(cols, (_) => <Widget>[]);
    for (int i = 0; i < images.length; i++) {
      columnWidgets[i % cols].add(Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: _GalleryItem(index: i, imageList: images),
      ));
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < cols; i++) ...[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: columnWidgets[i],
            ),
          ),
          if (i < cols - 1) const SizedBox(width: 16),
        ],
      ],
    );
  }
}

class _GalleryItem extends StatelessWidget {
  final int index;
  final List<String> imageList;
  const _GalleryItem({required this.index, required this.imageList});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          PageRouteBuilder(
            opaque: false,
            barrierColor: Colors.black.withValues(alpha: 0.9),
            transitionDuration: const Duration(milliseconds: 300),
            pageBuilder: (context, animation, secondaryAnimation) => _InteractiveGalleryViewer(
              images: imageList,
              initialIndex: index,
            ),
            transitionsBuilder: (context, animation, _, child) => FadeTransition(opacity: animation, child: child),
          ),
        );
      },
      child: Hero(
        tag: imageList[index],
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _kCardBorder),
          ),
          clipBehavior: Clip.antiAlias,
          child: Image.asset(imageList[index], fit: BoxFit.cover, cacheWidth: 800),
        ),
      ),
    );
  }
}

class _InteractiveGalleryViewer extends StatefulWidget {
  final List<String> images;
  final int initialIndex;
  const _InteractiveGalleryViewer({required this.images, required this.initialIndex});

  @override
  State<_InteractiveGalleryViewer> createState() => _InteractiveGalleryViewerState();
}

class _InteractiveGalleryViewerState extends State<_InteractiveGalleryViewer> {
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
    _pageController.animateToPage(
      index.clamp(0, widget.images.length - 1),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        fit: StackFit.expand,
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(color: Colors.transparent),
          ),
          PageView.builder(
            controller: _pageController,
            onPageChanged: (idx) => setState(() => _currentIndex = idx),
            itemCount: widget.images.length,
            itemBuilder: (context, index) {
              final imagePath = widget.images[index];
              return InteractiveViewer(
                child: Hero(
                  tag: imagePath,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Image.asset(imagePath, fit: BoxFit.contain),
                    ),
                  ),
                ),
              );
            },
          ),
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
          if (_currentIndex < widget.images.length - 1)
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
        ],
      ),
    );
  }
}
