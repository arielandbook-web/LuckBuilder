import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/providers.dart';
import '../../notifications/daily_routine_store.dart';

final dailyRoutineProvider = FutureProvider<DailyRoutine>((ref) async {
  final uid = ref.read(uidProvider);
  return DailyRoutineStore.load(uid);
});
