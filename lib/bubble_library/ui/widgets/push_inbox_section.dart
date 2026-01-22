import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../notifications/scheduled_push_cache.dart';
import '../../../notifications/notification_inbox_store.dart';
import '../product_library_page.dart';
import 'bubble_card.dart';
import '../../providers/providers.dart';

class PushInboxSection extends ConsumerStatefulWidget {
  const PushInboxSection({super.key});

  @override
  ConsumerState<PushInboxSection> createState() => _PushInboxSectionState();
}

class _PushInboxSectionState extends ConsumerState<PushInboxSection> {
  final _cache = ScheduledPushCache();

  bool _loading = true;
  List<ScheduledPushEntry> _missed = const [];

  @override
  void initState() {
    super.initState();
    _loadMissed();
  }

  String _fmt(DateTime dt) {
    final y = dt.year;
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$y-$m-$d $hh:$mm';
  }

  Future<void> _loadMissed() async {
    setState(() => _loading = true);

    try {
      final uid = ref.read(uidProvider);
      
      // 讀最近 3 天排程（你本來就只排 3 天，這裡一致）
      final upcoming =
          await _cache.loadSortedUpcoming(horizon: const Duration(days: 3));

      final now = DateTime.now();
      final past = upcoming.where((e) => e.when.isBefore(now)).toList();

      // 過濾尚未 opened 的（使用 NotificationInboxStore）
      final missed = <ScheduledPushEntry>[];
      final inboxItems = await NotificationInboxStore.load(uid);
      final openedContentIds = inboxItems
          .where((item) => item.status == InboxStatus.opened)
          .map((item) => item.contentItemId)
          .toSet();
      
      for (final e in past) {
        final cid = e.payload['contentItemId']?.toString();
        if (cid == null || cid.isEmpty) continue;
        if (!openedContentIds.contains(cid)) {
          missed.add(e);
        }
      }

      missed.sort((a, b) => b.when.compareTo(a.when)); // 最近錯過的在最上面

      if (!mounted) return;
      setState(() {
        _missed = missed;
        _loading = false;
      });
    } catch (e) {
      // 如果未登入或其他錯誤，顯示空列表
      if (!mounted) return;
      setState(() {
        _missed = [];
        _loading = false;
      });
    }
  }

  Future<void> _openAndMark(ScheduledPushEntry e) async {
    final productId = e.payload['productId']?.toString() ?? '';
    final contentItemId = e.payload['contentItemId']?.toString() ?? '';

    if (productId.isEmpty) return;
    
    try {
      final uid = ref.read(uidProvider);
      if (productId.isNotEmpty && contentItemId.isNotEmpty) {
        await NotificationInboxStore.markOpened(
          uid,
          productId: productId,
          contentItemId: contentItemId,
        );
      }
    } catch (e) {
      // 如果未登入，繼續執行但不標記為已開啟
    }

    if (!mounted) return;
    // 補看 → 直接進該 Topic library
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) =>
          ProductLibraryPage(productId: productId, isWishlistPreview: false),
    ));

    // 回來後刷新
    await _loadMissed();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('推播收件匣',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
        const SizedBox(height: 10),
        BubbleCard(
          child: _missed.isEmpty
              ? Text('沒有錯過的推播 🎉',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.8)))
              : Column(
                  children: _missed.map((e) {
                    final productId = e.payload['productId']?.toString() ?? '';
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.inbox),
                      title: Text(e.title,
                          style: const TextStyle(fontWeight: FontWeight.w900)),
                      subtitle: Text('${_fmt(e.when)} · $productId',
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.75),
                              fontSize: 12)),
                      trailing: TextButton(
                        onPressed: () => _openAndMark(e),
                        child: const Text('補看'),
                      ),
                      onTap: () => _openAndMark(e),
                    );
                  }).toList(),
                ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            OutlinedButton.icon(
              onPressed: _loadMissed,
              icon: const Icon(Icons.refresh),
              label: const Text('更新收件匣'),
            ),
          ],
        ),
      ],
    );
  }
}
