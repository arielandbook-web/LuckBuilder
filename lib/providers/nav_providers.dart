import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 0:首頁 1:泡泡庫 2:分類 3:搜尋 4:我的
final bottomTabIndexProvider = StateProvider<int>((ref) => 0);
