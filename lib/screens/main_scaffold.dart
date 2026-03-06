import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class MainScaffold extends StatelessWidget {
  final StatefulNavigationShell navigationShell;
  const MainScaffold({super.key, required this.navigationShell});

  void _onTap(int index) {
    navigationShell.goBranch(
      index,
      // If user taps current tab, go back to that branch root.
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        height: 60,
        indicatorColor: Colors.transparent,
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: _onTap,
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.explore_outlined),
            selectedIcon: Icon(
              Icons.explore,
              color: Theme.of(context).colorScheme.secondary,
            ),
            label: 'Decouvrir',
          ),
          NavigationDestination(
            icon: const Icon(Icons.dynamic_feed_outlined),
            selectedIcon: Icon(
              Icons.dynamic_feed,
              color: Theme.of(context).colorScheme.secondary,
            ),
            label: 'Mon fil',
          ),
          NavigationDestination(
            icon: const Icon(Icons.search),
            selectedIcon: Icon(
              Icons.search,
              color: Theme.of(context).colorScheme.secondary,
            ),
            label: 'Rechercher',
          ),
          NavigationDestination(
            icon: const Icon(Icons.folder_outlined),
            selectedIcon: Icon(
              Icons.folder,
              color: Theme.of(context).colorScheme.secondary,
            ),
            label: 'Mes projets',
          ),
          NavigationDestination(
            icon: const Icon(Icons.settings_outlined),
            selectedIcon: Icon(
              Icons.settings,
              color: Theme.of(context).colorScheme.secondary,
            ),
            label: 'Parametres',
          ),
        ],
      ),
    );
  }
}
