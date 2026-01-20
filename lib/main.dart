import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';

import 'app_scaffold.dart';
import 'bubble_library/notifications/timezone_init.dart';
import 'bubble_library/bootstrapper.dart';

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
  
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return BubbleBootstrapper(
      child: MaterialApp(
        title: 'Learning Bubble',
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.dark(
            primary: Colors.white,
            onPrimary: Colors.black,
            surface: const Color(0xFF1A1A2E),
            onSurface: Colors.white,
            background: const Color(0xFF0F0F1E),
          ),
          scaffoldBackgroundColor: const Color(0xFF0F0F1E),
          appBarTheme: const AppBarTheme(
            backgroundColor: Colors.transparent,
            elevation: 0,
            iconTheme: IconThemeData(color: Colors.white),
            titleTextStyle: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          navigationBarTheme: NavigationBarThemeData(
            backgroundColor: Colors.white.withOpacity(0.1),
            indicatorColor: Colors.white.withOpacity(0.2),
            labelTextStyle: MaterialStateProperty.all(
              const TextStyle(color: Colors.white),
            ),
            iconTheme: MaterialStateProperty.all(
              const IconThemeData(color: Colors.white),
            ),
          ),
        ),
        home: const MainScaffold4Tabs(),
      ),
    );
  }
}