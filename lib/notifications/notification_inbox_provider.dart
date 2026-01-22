import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../bubble_library/providers/providers.dart';
import 'notification_inbox_store.dart';

/// 載入所有收件匣項目（已排序：新到舊）
final inboxItemsProvider = FutureProvider<List<InboxItem>>((ref) async {
  final uid = ref.read(uidProvider);
  await NotificationInboxStore.sweepMissed(uid);
  final items = await NotificationInboxStore.load(uid);
  items.sort((a, b) => b.whenMs.compareTo(a.whenMs));
  return items;
});

/// 未讀數量（status != InboxStatus.opened）
final inboxUnreadCountProvider = FutureProvider<int>((ref) async {
  final items = await ref.watch(inboxItemsProvider.future);
  return items.where((item) => item.status != InboxStatus.opened).length;
});
