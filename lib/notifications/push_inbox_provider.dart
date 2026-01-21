import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../bubble_library/providers/providers.dart';
import 'notification_inbox_store.dart';

/// 顯示「已到時間 but 未開啟 & 未略過」= 錯過推播收件匣
final missedInboxProvider = FutureProvider<List<InboxItem>>((ref) async {
  String uid;
  try {
    uid = ref.read(uidProvider);
  } catch (_) {
    return [];
  }

  final all = await NotificationInboxStore.load(uid);
  final nowMs = DateTime.now().millisecondsSinceEpoch;

  final missed = all.where((it) {
    if (it.whenMs > nowMs) return false; // 還沒到時間：不算錯過
    if (it.isOpened) return false;
    if (it.isDismissed) return false;
    return true;
  }).toList();

  missed.sort((a, b) => b.whenMs.compareTo(a.whenMs));
  return missed;
});
