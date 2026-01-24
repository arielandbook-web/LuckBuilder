import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/app_tokens.dart';
import '../../widgets/app_card.dart';

import '../../bubble_library/notifications/scheduled_push_cache.dart';
import '../../bubble_library/providers/providers.dart';
import '../../bubble_library/notifications/notification_service.dart';
import '../../notifications/push_timeline_provider.dart';

import '../../widgets/rich_sections/user_learning_store.dart';
import '../../bubble_library/ui/product_library_page.dart';
import '../../notifications/notification_inbox_store.dart';

class HomeTodayTaskSection extends ConsumerWidget {
  final int dailyLimit; // 保留向後相容

  const HomeTodayTaskSection({
    super.key,
    this.dailyLimit = 20,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
    final upcomingAsync = ref.watch(scheduledCacheProvider);
    final learnedTodayAsync = ref.watch(_globalLearnedTodayProvider);

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
              final cap = g.dailyTotalCap;

              return upcomingAsync.when(
                data: (list) {
                  // 今日推播（依 when 是今天）
                  final now = DateTime.now();
                  final today0 = DateTime(now.year, now.month, now.day);
                  final tomorrow0 = today0.add(const Duration(days: 1));

                  final todayList = list
                      .where((e) =>
                          e.when.isAfter(today0) && e.when.isBefore(tomorrow0))
                      .toList()
                    ..sort((a, b) => a.when.compareTo(b.when));

                  final nextEntry = todayList
                      .where((e) => e.when.isAfter(now))
                      .cast<ScheduledPushEntry?>()
                      .firstWhere((_) => true, orElse: () => null);

                  return learnedTodayAsync.when(
                    data: (done) {
                      // 已收到：用「今天已學」作為最小可用版（更穩）
                      final received = done ? 1 : 0;

                      final progress =
                          (cap <= 0) ? 0.0 : (received / cap).clamp(0.0, 1.0);

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
                                  '今日推播：$received / $cap',
                                  style: TextStyle(
                                      color: tokens.textSecondary,
                                      fontWeight: FontWeight.w700),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(999),
                                  color: done
                                      ? Colors.green.withValues(alpha: 0.25)
                                      : Colors.white.withValues(alpha: 0.08),
                                  border: Border.all(
                                      color:
                                          Colors.white.withValues(alpha: 0.12)),
                                ),
                                child: Text(
                                  done ? '今日已完成 ✅' : '尚未完成',
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

                          Row(
                            children: [
                              Expanded(
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
                                          ref.invalidate(
                                              _globalLearnedTodayProvider);

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
                              const SizedBox(width: 10),
                              OutlinedButton(
                                onPressed: nextEntry == null
                                    ? null
                                    : () async {
                                        await _scheduleRemindLater(nextEntry);
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            const SnackBar(
                                                content:
                                                    Text('已設定 15 分鐘後提醒（本機）')),
                                          );
                                        }
                                      },
                                child: const Text('稍後提醒'),
                              ),
                            ],
                          ),
                        ],
                      );
                    },
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Text('learned error: $e',
                        style: TextStyle(color: tokens.textSecondary)),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text('schedule error: $e',
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

  static Future<void> _scheduleRemindLater(ScheduledPushEntry e) async {
    final ns = NotificationService();
    final when = DateTime.now().add(const Duration(minutes: 15));

    // payload：沿用 bubble payload
    final payload = Map<String, dynamic>.from(e.payload);
    payload['type'] = 'remind_later';

    const title = '提醒你學一下';
    final body = e.title.isNotEmpty ? e.title : '回來學 1 則';

    final id = DateTime.now().millisecondsSinceEpoch.remainder(1000000);

    await ns.schedule(
      id: id,
      when: when,
      title: title,
      body: body,
      payload: payload,
    );
  }
}

final _globalLearnedTodayProvider = FutureProvider<bool>((ref) async {
  return UserLearningStore().globalLearnedToday();
});
