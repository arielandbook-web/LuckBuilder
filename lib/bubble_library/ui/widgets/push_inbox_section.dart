import 'package:flutter/material.dart';
import '../../notifications/scheduled_push_cache.dart';
import '../../../notifications/push_inbox_store.dart';
import '../product_library_page.dart';
import 'bubble_card.dart';

class PushInboxSection extends StatefulWidget {
  const PushInboxSection({super.key});

  @override
  State<PushInboxSection> createState() => _PushInboxSectionState();
}

class _PushInboxSectionState extends State<PushInboxSection> {
  final _cache = ScheduledPushCache();
  final _store = PushInboxStore();

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

    // 讀最近 3 天排程（你本來就只排 3 天，這裡一致）
    final upcoming =
        await _cache.loadSortedUpcoming(horizon: const Duration(days: 3));

    final now = DateTime.now();
    final past = upcoming.where((e) => e.when.isBefore(now)).toList();

    // 過濾尚未 opened 的
    final missed = <ScheduledPushEntry>[];
    for (final e in past) {
      final cid = e.payload['contentItemId']?.toString();
      if (cid == null || cid.isEmpty) continue;
      final opened = await _store.isOpened(cid);
      if (!opened) missed.add(e);
    }

    missed.sort((a, b) => b.when.compareTo(a.when)); // 最近錯過的在最上面

    if (!mounted) return;
    setState(() {
      _missed = missed;
      _loading = false;
    });
  }

  Future<void> _openAndMark(ScheduledPushEntry e) async {
    final productId = e.payload['productId']?.toString();
    final contentItemId = e.payload['contentItemId']?.toString();

    if (productId == null || productId.isEmpty) return;
    if (contentItemId != null && contentItemId.isNotEmpty) {
      await _store.markOpened(contentItemId);
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
