import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../bubble_library/providers/providers.dart';
import 'notification_inbox_store.dart';

final inboxItemsProvider = FutureProvider<List<InboxItem>>((ref) async {
  final uid = ref.read(uidProvider);
  await NotificationInboxStore.sweepMissed(uid);
  final items = await NotificationInboxStore.load(uid);
  items.sort((a, b) => b.whenMs.compareTo(a.whenMs));
  return items;
});
