import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../notifications/scheduled_push_cache.dart';
import '../push_product_config_page.dart';
import '../../providers/providers.dart';
import '../../notifications/push_orchestrator.dart';
import '../../models/push_config.dart';
import 'bubble_card.dart';

class PushTimelineSection extends ConsumerStatefulWidget {
  final Future<void> Function(ScheduledPushEntry entry)? onSkip;

  const PushTimelineSection({super.key, this.onSkip});

  @override
  ConsumerState<PushTimelineSection> createState() => PushTimelineSectionState();
}

class PushTimelineSectionState extends ConsumerState<PushTimelineSection> {
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
    final cache = ScheduledPushCache();

    final upcoming =
        await cache.loadSortedUpcoming(horizon: const Duration(days: 3));

    if (!mounted) return;
    setState(() {
      _upcoming = upcoming;
      _loading = false;
    });
  }

  /// ✅ 從 Firestore 讀取勿擾時段
  TimeOfDay _getQuietHoursStart() {
    final globalAsync = ref.watch(globalPushSettingsProvider);
    return globalAsync.maybeWhen(
      data: (g) => g.quietHours.start,
      orElse: () => const TimeOfDay(hour: 22, minute: 0),
    );
  }

  TimeOfDay _getQuietHoursEnd() {
    final globalAsync = ref.watch(globalPushSettingsProvider);
    return globalAsync.maybeWhen(
      data: (g) => g.quietHours.end,
      orElse: () => const TimeOfDay(hour: 8, minute: 0),
    );
  }

  int _toMinutes(TimeOfDay tod) => tod.hour * 60 + tod.minute;

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
    final current = isStart ? _getQuietHoursStart() : _getQuietHoursEnd();
    final picked = await showTimePicker(
      context: context,
      initialTime: current,
    );
    if (picked == null) return;

    // ✅ 更新 Firestore 全域設定
    final uid = ref.read(uidProvider);
    final repo = ref.read(pushSettingsRepoProvider);
    final globalAsync = ref.read(globalPushSettingsProvider);
    
    globalAsync.whenData((g) async {
      final newQuietHours = isStart
          ? TimeRange(picked, g.quietHours.end)
          : TimeRange(g.quietHours.start, picked);
      final newSettings = g.copyWith(quietHours: newQuietHours);
      await repo.setGlobal(uid, newSettings);
      // 觸發重排（使用新設定）
      await PushOrchestrator.rescheduleNextDays(
        ref: ref,
        days: 3,
        overrideGlobal: newSettings,
      );
    });
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
        // ✅ 從 Firestore 讀取勿擾時段
        ref.watch(globalPushSettingsProvider).when(
          data: (g) {
            final startMin = _toMinutes(g.quietHours.start);
            final endMin = _toMinutes(g.quietHours.end);
            return BubbleCard(
              child: Row(
                children: [
                  const Icon(Icons.bedtime),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text('${_fmtMin(startMin)} - ${_fmtMin(endMin)}',
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
            );
          },
          loading: () => const BubbleCard(
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (_, __) => BubbleCard(
            child: Text('載入錯誤',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.8))),
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
