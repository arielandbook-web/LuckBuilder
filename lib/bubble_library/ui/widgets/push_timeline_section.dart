import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../notifications/scheduled_push_cache.dart';
import '../push_product_config_page.dart';
import 'bubble_card.dart';

class PushTimelineSection extends StatefulWidget {
  final Future<void> Function(ScheduledPushEntry entry)? onSkip;

  const PushTimelineSection({super.key, this.onSkip});

  @override
  State<PushTimelineSection> createState() => PushTimelineSectionState();
}

class PushTimelineSectionState extends State<PushTimelineSection> {
  // 勿擾：先本機
  static const _kDndStartMin = 'dnd_start_min_v1';
  static const _kDndEndMin = 'dnd_end_min_v1';

  int _startMin = 22 * 60 + 30;
  int _endMin = 8 * 60;
  bool _loading = true;

  List<ScheduledPushEntry> _upcoming = const [];

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  /// 外部可呼叫此方法重新載入
  Future<void> reload() => _loadAll();

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    final sp = await SharedPreferences.getInstance();
    final cache = ScheduledPushCache();

    final upcoming =
        await cache.loadSortedUpcoming(horizon: const Duration(days: 3));

    if (!mounted) return;
    setState(() {
      _startMin = sp.getInt(_kDndStartMin) ?? _startMin;
      _endMin = sp.getInt(_kDndEndMin) ?? _endMin;
      _upcoming = upcoming;
      _loading = false;
    });
  }

  Future<void> _saveDnd() async {
    final sp = await SharedPreferences.getInstance();
    await sp.setInt(_kDndStartMin, _startMin);
    await sp.setInt(_kDndEndMin, _endMin);
  }

  String _dateHeader(DateTime dt) {
    final y = dt.year.toString();
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  String _time(DateTime dt) {
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  String _fmtMin(int minutes) {
    final h = (minutes ~/ 60).toString().padLeft(2, '0');
    final m = (minutes % 60).toString().padLeft(2, '0');
    return '$h:$m';
  }

  Future<void> _pickTime({required bool isStart}) async {
    final currentMin = isStart ? _startMin : _endMin;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: currentMin ~/ 60, minute: currentMin % 60),
    );
    if (picked == null) return;

    setState(() {
      final v = picked.hour * 60 + picked.minute;
      if (isStart) {
        _startMin = v;
      } else {
        _endMin = v;
      }
    });
    await _saveDnd();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 10),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    // group by date
    final Map<String, List<ScheduledPushEntry>> grouped = {};
    for (final e in _upcoming) {
      final key = _dateHeader(e.when);
      grouped.putIfAbsent(key, () => []).add(e);
    }
    final keys = grouped.keys.toList()..sort();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('未來 3 天推播時間表',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
        const SizedBox(height: 10),
        BubbleCard(
          child: _upcoming.isEmpty
              ? Text('尚未排程（請按右上角刷新重排）',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.8)))
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final day in keys) ...[
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6, top: 4),
                        child: Text(
                          day,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      ...grouped[day]!.map((e) {
                        final productId =
                            e.payload['productId']?.toString() ?? '';
                        final contentItemId =
                            e.payload['contentItemId']?.toString() ?? '';

                        // title 通常是 anchorGroup 或 productTitle
                        final title = e.title.isNotEmpty ? e.title : productId;

                        // body 第一行通常有 Day xx/365
                        final firstLine = e.body.split('\n').first;
                        final dayMatch =
                            RegExp(r'Day\s+(\d+)/365').firstMatch(firstLine);
                        final dayText = dayMatch == null
                            ? ''
                            : ' · Day ${dayMatch.group(1)}';

                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Text(
                            _time(e.when),
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                          title: Text(
                            title,
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                          subtitle: Text(
                            '$productId$dayText',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.75),
                              fontSize: 12,
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (widget.onSkip != null &&
                                  contentItemId.isNotEmpty)
                                TextButton(
                                  onPressed: () async {
                                    await widget.onSkip!(e);
                                    await _loadAll(); // 跳過後重載 timeline
                                  },
                                  child: const Text('跳過'),
                                ),
                              const Icon(Icons.chevron_right),
                            ],
                          ),
                          onTap: productId.isEmpty
                              ? null
                              : () {
                                  // 點 timeline → 直接去該商品推播設定頁
                                  Navigator.of(context).push(MaterialPageRoute(
                                    builder: (_) => PushProductConfigPage(
                                        productId: productId),
                                  ));
                                },
                        );
                      }),
                      const Divider(height: 18),
                    ],
                  ],
                ),
        ),
        const SizedBox(height: 12),
        const Text('勿擾時段',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
        const SizedBox(height: 10),
        BubbleCard(
          child: Row(
            children: [
              const Icon(Icons.bedtime),
              const SizedBox(width: 10),
              Expanded(
                child: Text('${_fmtMin(_startMin)} - ${_fmtMin(_endMin)}',
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w800)),
              ),
              OutlinedButton(
                  onPressed: () => _pickTime(isStart: true),
                  child: const Text('開始')),
              const SizedBox(width: 8),
              OutlinedButton(
                  onPressed: () => _pickTime(isStart: false),
                  child: const Text('結束')),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            OutlinedButton.icon(
              onPressed: _loadAll,
              icon: const Icon(Icons.refresh),
              label: const Text('更新時間表'),
            ),
            const SizedBox(width: 10),
            Text(
              '（資料來源：本機排程快取）',
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6), fontSize: 12),
            ),
          ],
        ),
      ],
    );
  }
}
