import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'pages/home_page.dart';
import 'pages/category_page.dart';
import 'pages/search_page.dart';
import 'pages/me_page.dart';
import 'bubble_library/ui/bubble_library_page.dart';
import 'widgets/app_background.dart';
import 'theme/theme_controller.dart';
import 'theme/app_tokens.dart';

final bottomTabIndexProvider = StateProvider<int>((ref) => 0);
final themeControllerProvider = Provider<ThemeController>((ref) {
  throw UnimplementedError('themeControllerProvider must be overridden');
});

class MainScaffold4Tabs extends ConsumerWidget {
  final ThemeController themeController;
  const MainScaffold4Tabs({super.key, required this.themeController});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index = ref.watch(bottomTabIndexProvider);
    final tokens = context.tokens;

    return ProviderScope(
      overrides: [
        themeControllerProvider.overrideWithValue(themeController),
      ],
      child: AppBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: IndexedStack(
            index: index,
            children: const [
              HomePage(),
              BubbleLibraryPage(),
              CategoryPage(),
              SearchPage(),
              MePage(),
            ],
          ),
          bottomNavigationBar: Container(
            decoration: BoxDecoration(
              color: tokens.navBg,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: NavigationBar(
              selectedIndex: index,
              onDestinationSelected: (i) => ref.read(bottomTabIndexProvider.notifier).state = i,
              backgroundColor: Colors.transparent,
              elevation: 0,
              labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
              destinations: const [
                NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: '首頁'),
                NavigationDestination(icon: Icon(Icons.library_books_outlined), selectedIcon: Icon(Icons.library_books), label: '泡泡庫'),
                NavigationDestination(icon: Icon(Icons.grid_view_outlined), selectedIcon: Icon(Icons.grid_view), label: '分類'),
                NavigationDestination(icon: Icon(Icons.search_outlined), selectedIcon: Icon(Icons.search), label: '搜尋'),
                NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: '我的'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
