import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/app_tokens.dart';
import '../../widgets/app_card.dart';

import '../../bubble_library/notifications/scheduled_push_cache.dart';
import '../../bubble_library/providers/providers.dart';
import '../../notifications/push_timeline_provider.dart';

import '../../widgets/rich_sections/user_learning_store.dart';
import '../../bubble_library/ui/product_library_page.dart';
import '../../notifications/notification_inbox_store.dart';

/// 今日推播統計（總數、已完成數、下一則）
class TodayPushStats {
  final int totalScheduled; // 今日排程總數（從推播設定計算）
  final int completed; // 今日已完成數（= 總數 - 剩餘數）
  final int remaining; // 今日剩餘數（從 scheduledCacheProvider）
  final ScheduledPushEntry? nextEntry; // 下一則推播

  const TodayPushStats({
    required this.totalScheduled,
    required this.completed,
    required this.remaining,
    this.nextEntry,
  });
}

/// 今日推播統計 provider
/// ✅ 使用 upcomingTimelineProvider（推播中心的未來三天時間表）
final _todayPushStatsProvider = FutureProvider<TodayPushStats>((ref) async {
  // 監聽 upcomingTimelineProvider（推播中心的數據源）
  final tasks = await ref.watch(upcomingTimelineProvider.future);
  
  final now = DateTime.now();
  final todayWeekday = now.weekday; // 1=Mon, 7=Sun
  final today0 = DateTime(now.year, now.month, now.day);
  final tomorrow0 = today0.add(const Duration(days: 1));
  
  int totalFreqToday = 0;
  
  try {
    // 1. 從推播設定計算今日應推播數（分母）
    final lib = await ref.read(libraryProductsProvider.future);
    final global = await ref.read(globalPushSettingsProvider.future);
    
    if (global.enabled) {
      for (final lp in lib) {
        if (!lp.pushEnabled || lp.isHidden) continue;
        
        // 檢查今天是否在該產品的推播日
        final cfg = lp.pushConfig;
        if (cfg.daysOfWeek.contains(todayWeekday)) {
          totalFreqToday += cfg.freqPerDay;
        }
      }
      
      // 套用全域每日上限
      totalFreqToday = totalFreqToday.clamp(0, global.dailyTotalCap);
    }
  } catch (_) {
    // 忽略錯誤，使用預設值
  }

  // 2. 從 upcomingTimelineProvider 計算今日剩餘數和下一則
  final todayRemaining = tasks.where((t) =>
      t.when.isAfter(now) && t.when.isBefore(tomorrow0)).toList()
    ..sort((a, b) => a.when.compareTo(b.when));
  
  final remaining = todayRemaining.length;
  
  // 3. 轉換下一則 PushTask 為 ScheduledPushEntry
  ScheduledPushEntry? nextEntry;
  if (todayRemaining.isNotEmpty) {
    try {
      final task = todayRemaining.first;
      final productsMap = await ref.read(productsMapProvider.future);
      final product = productsMap[task.productId];
      final productTitle = product?.title ?? task.productId;
      
      final title = task.item.anchorGroup.isNotEmpty
          ? task.item.anchorGroup
          : productTitle;
      final subtitle =
          'L1｜${task.item.intent}｜◆${task.item.difficulty}｜${task.item.pushOrder}/365';
      final body = '$subtitle\n${task.item.content}';
      
      final payload = {
        'type': 'bubble',
        'productId': task.productId,
        'contentItemId': task.item.id,
        'topicId': product?.topicId ?? '',
        'contentId': task.item.id,
        'pushOrder': task.item.pushOrder,
      };
      
      nextEntry = ScheduledPushEntry(
        when: task.when,
        title: title,
        body: body,
        payload: payload,
      );
    } catch (_) {
      // 轉換失敗時 nextEntry 保持為 null
    }
  }
  
  // 4. 已完成數 = 總數 - 剩餘數（用扣的）
  final completed = (totalFreqToday - remaining).clamp(0, totalFreqToday);

  return TodayPushStats(
    totalScheduled: totalFreqToday,
    completed: completed,
    remaining: remaining,
    nextEntry: nextEntry,
  );
});

class HomeTodayTaskSection extends ConsumerStatefulWidget {
  final int dailyLimit; // 保留向後相容

  const HomeTodayTaskSection({
    super.key,
    this.dailyLimit = 20,
  });

  @override
  ConsumerState<HomeTodayTaskSection> createState() =>
      _HomeTodayTaskSectionState();
}

class _HomeTodayTaskSectionState extends ConsumerState<HomeTodayTaskSection> {
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    // 每 30 秒刷新一次倒數時間（避免過於頻繁）
    _countdownTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    // 未登入：提示（避免 uidProvider throw）
    try {
      ref.read(uidProvider);
    } catch (_) {
      return AppCard(
        child: Text(
          '登入後可顯示今日任務：下一則推播倒數、今日完成狀態',
          style: TextStyle(color: tokens.textSecondary),
        ),
      );
    }

    final globalAsync = ref.watch(globalPushSettingsProvider);
    final todayStatsAsync = ref.watch(_todayPushStatsProvider);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('今日任務',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: tokens.textPrimary)),
          const SizedBox(height: 10),
          globalAsync.when(
            data: (g) {
              return todayStatsAsync.when(
                data: (stats) {
                  // ✅ 直接使用 _todayPushStatsProvider 的統計數據
                  final actualScheduled = stats.totalScheduled;
                  final actualPushed = stats.completed;
                  final nextEntry = stats.nextEntry;
                  // 分子等於分母才標示「今日已完成」，否則不標註
                  final isCompleted = actualScheduled > 0 &&
                      actualPushed == actualScheduled;

                  final progress = (actualScheduled <= 0)
                      ? 0.0
                      : (actualPushed / actualScheduled).clamp(0.0, 1.0);

                  final nextText =
                      nextEntry == null ? '今天沒有更多推播' : _nextLine(nextEntry);

                  final countdownText =
                      nextEntry == null ? '' : _countdown(nextEntry.when);

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 進度條
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '今日推播：$actualPushed / $actualScheduled',
                              style: TextStyle(
                                  color: tokens.textSecondary,
                                  fontWeight: FontWeight.w700),
                            ),
                          ),
                          if (isCompleted)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(999),
                                color: Colors.green.withValues(alpha: 0.25),
                                border: Border.all(
                                    color:
                                        Colors.white.withValues(alpha: 0.12)),
                              ),
                              child: Text(
                                '今日已完成 ✅',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.9),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                        ],
                      ),
                              const SizedBox(height: 8),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(999),
                                child: LinearProgressIndicator(
                                  value: progress,
                                  minHeight: 10,
                                  backgroundColor:
                                      Colors.white.withValues(alpha: 0.08),
                                ),
                              ),
                              const SizedBox(height: 12),

                              // 下一則 + 倒數
                              Text(
                                nextText,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: tokens.textSecondary),
                              ),
                              if (countdownText.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text(
                                  countdownText,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.85),
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],

                              const SizedBox(height: 12),

                              // 立即學 1 則按鈕靠右對齊
                              Align(
                                alignment: Alignment.centerRight,
                                child: ElevatedButton(
                                  onPressed: nextEntry == null
                                      ? null
                                      : () async {
                                          // 立即學 1 則：直接進該 Topic
                                          final pid = nextEntry
                                                  .payload['productId']
                                                  ?.toString() ??
                                              '';
                                          final cid = nextEntry
                                                  .payload['contentItemId']
                                                  ?.toString() ??
                                              '';
                                          if (pid.isEmpty) return;

                                          // 記錄今日完成（全域）
                                          await UserLearningStore()
                                              .markGlobalLearnedToday();

                                          // 標記推播為已開啟
                                          if (pid.isNotEmpty && cid.isNotEmpty) {
                                            final uid = ref.read(uidProvider);
                                            await NotificationInboxStore
                                                .markOpened(
                                              uid,
                                              productId: pid,
                                              contentItemId: cid,
                                            );
                                          }

                                          // ✅ 刷新今日推播統計
                                          ref.invalidate(_todayPushStatsProvider);

                                          // 進頁
                                          // ignore: use_build_context_synchronously
                                          Navigator.of(context)
                                              .push(MaterialPageRoute(
                                            builder: (_) => ProductLibraryPage(
                                              productId: pid,
                                              isWishlistPreview: false,
                                              initialContentItemId:
                                                  cid.isNotEmpty ? cid : null,
                                            ),
                                          ));
                                        },
                                  child: const Text('立即學 1 則'),
                                ),
                              ),
                    ],
                  );
                },
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('stats error: $e',
                  style: TextStyle(color: tokens.textSecondary)),
            );
          },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('global error: $e',
                style: TextStyle(color: tokens.textSecondary)),
          ),
        ],
      ),
    );
  }

  static String _fmtTime(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  static String _nextLine(ScheduledPushEntry e) {
    final pid = e.payload['productId']?.toString() ?? '';
    final title = e.title.isNotEmpty ? e.title : pid;
    return '下一則：${_fmtTime(e.when)} · $title';
  }

  static String _countdown(DateTime when) {
    final diff = when.difference(DateTime.now());
    if (diff.isNegative) return '';
    final h = diff.inHours;
    final m = diff.inMinutes.remainder(60);
    final s = diff.inSeconds.remainder(60);
    if (h > 0) return '倒數：${h}h ${m}m';
    if (m > 0) return '倒數：${m}m';
    return '倒數：${s}s';
  }

}
