import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/dashboard/dashboard_screen.dart';
import '../../features/narrative/narrative_screen.dart';
import '../../features/gallery/gallery_screen.dart';

/// Parameters for an isolated mini-flow from the dashboard.
/// Only the chapters whose IDs are in [chapterIds] will be shown.
class NarrativeFlowParams {
  final List<String> chapterIds;
  const NarrativeFlowParams({required this.chapterIds});
}

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        name: 'home',
        builder: (ctx, state) => const DashboardScreen(),
      ),
      GoRoute(
        path: '/gallery',
        name: 'gallery',
        builder: (ctx, state) => const GalleryScreen(),
      ),
      GoRoute(
        path: '/narrative',
        name: 'narrative',
        builder: (ctx, state) {
          final extra = state.extra;
          // Legacy: extra is int → full narrative at that index
          if (extra is int) {
            return NarrativeScreen(initialIndex: extra);
          }
          // New: extra is NarrativeFlowParams → isolated mini-flow
          if (extra is NarrativeFlowParams) {
            return NarrativeScreen(flowParams: extra);
          }
          return const NarrativeScreen();
        },
      ),
    ],
  );
});

extension AppNavigation on BuildContext {
  void goToHome() => goNamed('home');
}
