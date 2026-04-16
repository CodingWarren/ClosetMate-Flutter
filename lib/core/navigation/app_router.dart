import 'package:closetmate/features/closet/screens/add_clothing_screen.dart';
import 'package:closetmate/features/closet/screens/clothing_detail_screen.dart';
import 'package:closetmate/features/closet/screens/closet_screen.dart';
import 'package:closetmate/features/lock/screens/lock_screen.dart';
import 'package:closetmate/features/outfit/screens/outfit_screen.dart';
import 'package:closetmate/features/settings/screens/settings_screen.dart';
import 'package:closetmate/features/stats/screens/stats_screen.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  routes: <RouteBase>[
    ShellRoute(
      builder: (BuildContext context, GoRouterState state, Widget child) {
        return AppScaffold(child: child);
      },
      routes: <RouteBase>[
        GoRoute(
          path: '/',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: ClosetScreen(),
          ),
        ),
        GoRoute(
          path: '/clothing/add',
          builder: (context, state) => const AddClothingScreen(),
        ),
        GoRoute(
          path: '/clothing/:id',
          builder: (context, state) => ClothingDetailScreen(
            clothingId: state.pathParameters['id']!,
          ),
        ),
        GoRoute(
          path: '/clothing/:id/edit',
          builder: (context, state) => AddClothingScreen(
            editClothingId: state.pathParameters['id'],
          ),
        ),
        GoRoute(
          path: '/outfits',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: OutfitScreen(),
          ),
        ),
        GoRoute(
          path: '/stats',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: StatsScreen(),
          ),
        ),
        GoRoute(
          path: '/settings',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: SettingsScreen(),
          ),
        ),
      ],
    ),
    GoRoute(
      path: '/lock',
      builder: (context, state) => const LockScreen(),
    ),
  ],
);

class AppScaffold extends StatelessWidget {
  const AppScaffold({super.key, required this.child});

  final Widget child;

  int _locationToIndex(String location) {
    if (location.startsWith('/outfits')) return 1;
    if (location.startsWith('/stats')) return 2;
    if (location.startsWith('/settings')) return 3;
    return 0;
  }

  void _onDestinationSelected(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.go('/');
        break;
      case 1:
        context.go('/outfits');
        break;
      case 2:
        context.go('/stats');
        break;
      case 3:
        context.go('/settings');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final String location = GoRouterState.of(context).uri.toString();
    final int currentIndex = _locationToIndex(location);

    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: (index) => _onDestinationSelected(context, index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.checkroom_outlined),
            selectedIcon: Icon(Icons.checkroom),
            label: '衣橱',
          ),
          NavigationDestination(
            icon: Icon(Icons.style_outlined),
            selectedIcon: Icon(Icons.style),
            label: '搭配',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart),
            label: '统计',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: '设置',
          ),
        ],
      ),
    );
  }
}
