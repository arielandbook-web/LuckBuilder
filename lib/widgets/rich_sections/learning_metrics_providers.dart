import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'user_learning_store.dart';

/// 全域：過去 7 天（含今天）完成天數
final globalWeeklyCountProvider = FutureProvider<int>((ref) async {
  return UserLearningStore().globalWeeklyCount();
});

/// 全域：連續天數 streak
final globalStreakProvider = FutureProvider<int>((ref) async {
  return UserLearningStore().globalStreak();
});
