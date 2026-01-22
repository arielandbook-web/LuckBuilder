import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/global_push_settings.dart';
import '../../providers/providers.dart';
import '../../../notifications/push_timeline_provider.dart';

class PushSmartSuggestionsCard extends ConsumerWidget {
  const PushSmartSuggestionsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final globalAsync = ref.watch(globalPushSettingsProvider);
    final libAsync = ref.watch(libraryProductsProvider);
    final timelineAsync = ref.watch(upcomingTimelineProvider);

    return globalAsync.when(
      data: (g) => libAsync.when(
        data: (lib) => timelineAsync.when(
          data: (tasks) {
            final tips = _buildTips(
              now: DateTime.now(),
              global: g,
              lib: lib,
              tasks: tasks,
            );

            if (tips.isEmpty) return const SizedBox.shrink();

            return Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.auto_awesome, size: 18),
                        SizedBox(width: 8),
                        Text(
                          '智慧建議',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ...tips.map((t) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _TipTile(tip: t),
                        )),
                  ],
                ),
              ),
            );
          },
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
        ),
        loading: () => const SizedBox.shrink(),
        error: (_, __) => const SizedBox.shrink(),
      ),
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  List<_SmartTip> _buildTips({
    required DateTime now,
    required GlobalPushSettings global,
    required List<dynamic> lib,
    required List<dynamic> tasks,
  }) {
    // lib 的實際型別在你的專案是 UserLibraryProduct，這裡不強制 import，
    // 只用 dynamic 取欄位（避免你檔案間 circular import）
    final pushing = lib
        .where((e) => (e as dynamic).isHidden == false && (e as dynamic).pushEnabled == true)
        .toList();

    final tips = <_SmartTip>[];

    // ===== 規則 A：推播總量 vs 每日上限 cap =====
    // 推播中商品多，但 cap 太低 → 會被每日上限切掉，體感變差
    if (pushing.length >= 4 && global.dailyTotalCap <= 8) {
      tips.add(_SmartTip(
        title: '推播中 Topic 太多，容易被每日上限切掉',
        body:
            '你目前推播中 ${pushing.length} 個 Topic，但每日總上限只有 ${global.dailyTotalCap}。\n'
            '建議把上限調到 12（或改互動模式），不然很多內容排不進去。',
        actionText: '建議：每日上限 → 12',
        severity: _TipSeverity.warn,
      ));
    }

    // 推播中很少，但 cap 超高 → 通知可能稀疏、不聚焦
    if (pushing.length <= 2 && global.dailyTotalCap >= 20) {
      tips.add(_SmartTip(
        title: '每日上限可能太高，通知密度不聚焦',
        body:
            '你目前推播中 ${pushing.length} 個 Topic，但每日總上限是 ${global.dailyTotalCap}。\n'
            '建議先調到 8～12，讓節奏更穩定、也更好控制勿擾時段。',
        actionText: '建議：每日上限 → 12',
        severity: _TipSeverity.info,
      ));
    }

    // ===== 規則 B：接下來 24 小時沒有任何推播 =====
    final next24 = tasks.where((t) {
      final when = (t as dynamic).when as DateTime;
      return when.isAfter(now) && when.isBefore(now.add(const Duration(hours: 24)));
    }).toList();

    if (global.enabled && pushing.isNotEmpty && next24.isEmpty) {
      tips.add(_SmartTip(
        title: '接下來 24 小時沒有推播',
        body:
            '可能是「勿擾時段」或「週期/頻率」設定太嚴格，導致全部被排除。\n'
            '建議檢查：勿擾時段、全域週期、以及各商品的頻率與時段。',
        actionText: '建議：檢查勿擾/週期/頻率',
        severity: _TipSeverity.warn,
      ));
    }

    // ===== 規則 C：下一則推播距離太久 =====
    if (tasks.isNotEmpty) {
      final next = tasks.first;
      final nextWhen = (next as dynamic).when as DateTime;
      final diffH = nextWhen.difference(now).inHours;

      if (diffH >= 10) {
        tips.add(_SmartTip(
          title: '下一則推播要等很久',
          body:
              '下一則推播在 ${_fmt(nextWhen)}（約 ${diffH} 小時後）。\n'
              '建議加上「早上/中午」時段或提高頻率，提升觸達與回訪。',
          actionText: '建議：增加時段（早上/中午）',
          severity: _TipSeverity.info,
        ));
      }
    }

    // ===== 規則 D：推播中商品數 = 0（但全域開著） =====
    if (global.enabled && pushing.isEmpty) {
      tips.add(_SmartTip(
        title: '全域推播已開，但沒有推播中的商品',
        body: '你已啟用全域推播，但目前沒有任何商品設定為「推播中」。\n到「推播中」列表點進去，開啟推播即可開始收到內容。',
        actionText: '建議：先開啟 1 個商品推播',
        severity: _TipSeverity.info,
      ));
    }

    // 最多顯示 3 張，避免太吵
    tips.sort((a, b) => b.severity.index.compareTo(a.severity.index));
    return tips.take(3).toList();
  }

  static String _fmt(DateTime dt) {
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '${dt.month}/${dt.day} $hh:$mm';
  }
}

class _TipTile extends StatelessWidget {
  final _SmartTip tip;
  const _TipTile({required this.tip});

  @override
  Widget build(BuildContext context) {
    final color = switch (tip.severity) {
      _TipSeverity.warn => Colors.orange,
      _TipSeverity.info => Colors.blueGrey,
    };

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.25)),
        color: color.withOpacity(0.06),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tip.title,
            style: TextStyle(
              fontWeight: FontWeight.w900,
              color: color.withOpacity(0.95),
            ),
          ),
          const SizedBox(height: 6),
          Text(tip.body),
          if (tip.actionText != null) ...[
            const SizedBox(height: 8),
            Text(
              tip.actionText!,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: color.withOpacity(0.9),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

enum _TipSeverity { info, warn }

class _SmartTip {
  final String title;
  final String body;
  final String? actionText;
  final _TipSeverity severity;

  const _SmartTip({
    required this.title,
    required this.body,
    this.actionText,
    required this.severity,
  });
}
