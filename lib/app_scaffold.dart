import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'pages/home_page.dart';
import 'pages/category_page.dart';
import 'pages/search_page.dart';
import 'pages/me_page.dart';
import 'bubble_library/ui/bubble_library_page.dart';

final bottomTabIndexProvider = StateProvider<int>((ref) => 0);

class MainScaffold4Tabs extends ConsumerWidget {
  const MainScaffold4Tabs({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index = ref.watch(bottomTabIndexProvider);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0F0F1E), // 深藍黑色
              Color(0xFF1A1A2E), // 稍淺的深藍
              Color(0xFF16213E), // 深藍灰
            ],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: IndexedStack(
          index: index,
          children: const [
            HomePage(),
            BubbleLibraryPage(), // ✅ 新增
            CategoryPage(),
            SearchPage(),
            MePage(),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) => ref.read(bottomTabIndexProvider.notifier).state = i,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: '首頁'),
          NavigationDestination(icon: Icon(Icons.library_books_outlined), selectedIcon: Icon(Icons.library_books), label: '泡泡庫'),
          NavigationDestination(icon: Icon(Icons.grid_view_outlined), selectedIcon: Icon(Icons.grid_view), label: '分類'),
          NavigationDestination(icon: Icon(Icons.search_outlined), selectedIcon: Icon(Icons.search), label: '搜尋'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: '我的'),
        ],
      ),
    );
  }
}
