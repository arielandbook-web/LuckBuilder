import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';

import 'app_scaffold.dart';
import 'bubble_library/notifications/timezone_init.dart';
import 'bubble_library/bootstrapper.dart';
import 'theme/theme_controller.dart';
import 'theme/app_themes.dart';
import 'navigation/app_nav.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await TimezoneInit.ensureInitialized(); // ✅ 必加

  // 自動匿名登入（如果尚未登入）
  final auth = FirebaseAuth.instance;
  if (auth.currentUser == null) {
    try {
      final userCredential = await auth.signInAnonymously();
      debugPrint('匿名登入成功: uid=${userCredential.user?.uid}');
    } catch (e) {
      // 如果匿名登入失敗，記錄錯誤但不阻止應用程式啟動
      debugPrint('匿名登入失敗: $e');
    }
  } else {
    debugPrint('用戶已登入: uid=${auth.currentUser?.uid}');
  }

  // 初始化主題控制器
  final themeController = ThemeController();
  await themeController.init();

  runApp(ProviderScope(child: MyApp(themeController: themeController)));
}

class MyApp extends StatelessWidget {
  final ThemeController themeController;
  const MyApp({super.key, required this.themeController});

  @override
  Widget build(BuildContext context) {
    return BubbleBootstrapper(
      child: AnimatedBuilder(
        animation: themeController,
        builder: (_, __) {
          return MaterialApp(
            navigatorKey: rootNavKey,
            title: 'Learning Bubble',
            debugShowCheckedModeBanner: false,
            theme: AppThemes.byId(themeController.id),
            home: MainScaffold4Tabs(themeController: themeController),
          );
        },
      ),
    );
  }
}
