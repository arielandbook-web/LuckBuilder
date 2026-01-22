import 'dart:math';
import 'package:flutter/material.dart';
import '../models/content_item.dart';
import '../models/global_push_settings.dart';
import '../models/push_config.dart';
import '../models/user_library.dart';

class PushTask {
  final String productId;
  final DateTime when;
  final ContentItem item;
  PushTask({required this.productId, required this.when, required this.item});
}

class PushScheduler {
  static const Map<String, TimeOfDay> presetSlotTimes = {
    'morning': TimeOfDay(hour: 9, minute: 10),
    'noon': TimeOfDay(hour: 12, minute: 30),
    'evening': TimeOfDay(hour: 18, minute: 40),
    'night': TimeOfDay(hour: 21, minute: 40),
  };

  static int _todToMin(TimeOfDay t) => t.hour * 60 + t.minute;

  static bool _inQuiet(TimeRange q, TimeOfDay t) {
    final start = _todToMin(q.start);
    final end = _todToMin(q.end);
    final cur = _todToMin(t);

    if (start < end) return cur >= start && cur < end; // same-day
    return cur >= start || cur < end; // crosses midnight
  }

  static DateTime _at(DateTime date, TimeOfDay tod) =>
      DateTime(date.year, date.month, date.day, tod.hour, tod.minute);

  static List<TimeOfDay> _resolveTimes(PushConfig cfg) {
    if (cfg.timeMode == PushTimeMode.custom && cfg.customTimes.isNotEmpty) {
      final list = List<TimeOfDay>.from(cfg.customTimes)
        ..sort((a, b) => _todToMin(a).compareTo(_todToMin(b)));
      return list.take(5).toList();
    }
    final slots = cfg.presetSlots.isEmpty ? ['night'] : cfg.presetSlots;
    final list = slots
        .map((s) => presetSlotTimes[s] ?? presetSlotTimes['night']!)
        .toList()
      ..sort((a, b) => _todToMin(a).compareTo(_todToMin(b)));
    return list.take(5).toList();
  }

  static List<TimeOfDay> _applyFreq(List<TimeOfDay> times, int freq) {
    freq = freq.clamp(1, 5);
    if (times.isEmpty) return [presetSlotTimes['night']!];

    if (freq <= times.length) return times.take(freq).toList();

    final base = List<TimeOfDay>.from(times);
    const order = ['morning', 'noon', 'evening', 'night'];
    while (base.length < freq) {
      for (final k in order) {
        final t = presetSlotTimes[k]!;
        final exists = base.any((x) => _todToMin(x) == _todToMin(t));
        if (!exists) {
          base.add(t);
          break;
        }
      }
      if (base.length >= freq) break;
      final last = base.last;
      final mins = _todToMin(last) + 120;
      base.add(TimeOfDay(hour: (mins ~/ 60) % 24, minute: mins % 60));
    }
    base.sort((a, b) => _todToMin(a).compareTo(_todToMin(b)));
    return base.take(5).toList();
  }

  static bool _allowedDay(GlobalPushSettings g, PushConfig p, DateTime d) {
    final w = d.weekday; // 1..7
    return g.daysOfWeek.contains(w) && p.daysOfWeek.contains(w);
  }

  static List<DateTime> _enforceMinInterval(
      List<DateTime> dt, int minIntervalMinutes) {
    if (dt.length <= 1) return dt;
    final out = <DateTime>[];
    DateTime? last;
    for (final t in dt) {
      if (last == null) {
        out.add(t);
        last = t;
      } else {
        final diff = t.difference(last).inMinutes;
        if (diff >= minIntervalMinutes) {
          out.add(t);
          last = t;
        } else {
          final pushed = last.add(Duration(minutes: minIntervalMinutes));
          out.add(pushed);
          last = pushed;
        }
      }
    }
    return out;
  }

  static ContentItem? _pickItem({
    required List<ContentItem> itemsSorted,
    required ProgressState progress,
    required Map<String, SavedContent> savedMap,
    required PushContentMode mode,
  }) {
    if (itemsSorted.isEmpty) return null;

    ContentItem? bySeq(int seq) {
      final idx = itemsSorted.indexWhere((e) => e.seq == seq);
      return idx >= 0 ? itemsSorted[idx] : null;
    }

    if (mode == PushContentMode.seq) {
      return bySeq(progress.nextSeq) ?? itemsSorted.first;
    }

    if (mode == PushContentMode.preferSaved) {
      return itemsSorted.firstWhere(
        (e) =>
            (savedMap[e.id]?.favorite ?? false) ||
            (savedMap[e.id]?.reviewLater ?? false),
        orElse: () => bySeq(progress.nextSeq) ?? itemsSorted.first,
      );
    }

    if (mode == PushContentMode.preferUnlearned) {
      return itemsSorted.firstWhere(
        (e) => !(savedMap[e.id]?.learned ?? false),
        orElse: () => bySeq(progress.nextSeq) ?? itemsSorted.first,
      );
    }

    // mixNewReview
    final r = Random();
    if (r.nextDouble() < 0.3) {
      return itemsSorted.firstWhere(
        (e) =>
            (savedMap[e.id]?.reviewLater ?? false) ||
            (savedMap[e.id]?.favorite ?? false),
        orElse: () => bySeq(progress.nextSeq) ?? itemsSorted.first,
      );
    }
    return bySeq(progress.nextSeq) ?? itemsSorted.first;
  }

  static List<PushTask> buildSchedule({
    required DateTime now,
    required int days,
    required GlobalPushSettings global,
    required Map<String, UserLibraryProduct> libraryByProductId,
    required Map<String, List<ContentItem>> contentByProduct,
    required Map<String, SavedContent> savedMap,
    required int iosSafeMaxScheduled, // <= 60

    // ✅ 新增：真排序用的「日常順序」(本機)
    List<String>? productOrder,
  }) {
    if (!global.enabled) return [];

    // ✅ 建立 order index map
    final orderIdx = <String, int>{};
    if (productOrder != null && productOrder.isNotEmpty) {
      for (int i = 0; i < productOrder.length; i++) {
        orderIdx[productOrder[i]] = i;
      }
    }
    int idxOf(String pid) => orderIdx[pid] ?? 1 << 20; // 沒在日常裡的放後面

    final tasks = <PushTask>[];
    final startDate = DateTime(now.year, now.month, now.day);

    for (int di = 0; di < days; di++) {
      final date = startDate.add(Duration(days: di));
      final dayCandidates = <PushTask>[];

      for (final entry in libraryByProductId.entries) {
        final lp = entry.value;
        if (lp.isHidden) continue;
        if (!lp.pushEnabled) continue;
        if (!_allowedDay(global, lp.pushConfig, date)) continue;

        final baseTimes = _resolveTimes(lp.pushConfig);
        final times = _applyFreq(baseTimes, lp.pushConfig.freqPerDay);

        // 避開 quiet hours（global + per-product）
        final filtered = times.where((t) {
          final inGlobal = _inQuiet(global.quietHours, t);
          final inProd = _inQuiet(lp.pushConfig.quietHours, t);
          return !(inGlobal || inProd);
        }).toList();
        if (filtered.isEmpty) continue;

        final dts = filtered.map((t) => _at(date, t)).toList()..sort();
        final enforced =
            _enforceMinInterval(dts, lp.pushConfig.minIntervalMinutes)
                .take(5)
                .toList();

        final items =
            List<ContentItem>.from(contentByProduct[lp.productId] ?? const [])
              ..sort((a, b) => a.seq.compareTo(b.seq));

        final picked = _pickItem(
          itemsSorted: items,
          progress: lp.progress,
          savedMap: savedMap,
          mode: lp.pushConfig.contentMode,
        );
        if (picked == null) continue;

        for (final when in enforced) {
          if (di == 0 && when.isBefore(now.add(const Duration(minutes: 1)))) {
            continue;
          }
          dayCandidates
              .add(PushTask(productId: lp.productId, when: when, item: picked));
        }
      }

      // 全域每日上限
      final dailyCap = global.dailyTotalCap.clamp(1, 50);
      dayCandidates.sort((a, b) => a.when.compareTo(b.when));

      if (dayCandidates.length > dailyCap) {
        // 優先：商品最愛 + 最近開啟 + 日常順序
        int prio(PushTask t) {
          final lp = libraryByProductId[t.productId]!;
          int score = 0;

          // ✅ 日常順序越前分數越高（真排序核心）
          final oi = idxOf(t.productId);
          score += (1000000 - oi).clamp(0, 1000000);

          // 你原本的權重保留
          if (lp.isFavorite) score += 2000;
          if (lp.lastOpenedAt != null) score += 300;
          score += lp.purchasedAt.millisecondsSinceEpoch ~/ 100000000;

          return score;
        }

        dayCandidates.sort((a, b) {
          final pa = prio(a);
          final pb = prio(b);
          if (pa != pb) return pb.compareTo(pa);
          return a.when.compareTo(b.when);
        });

        final kept = dayCandidates.take(dailyCap).toList()
          ..sort((a, b) => a.when.compareTo(b.when));
        tasks.addAll(kept);
      } else {
        tasks.addAll(dayCandidates);
      }
    }

    tasks.sort((a, b) {
      final t = a.when.compareTo(b.when);
      if (t != 0) return t;

      // ✅ 同一時間：日常順序小的排前
      final ao = idxOf(a.productId);
      final bo = idxOf(b.productId);
      if (ao != bo) return ao.compareTo(bo);

      // ✅ 再穩定：productId
      return a.productId.compareTo(b.productId);
    });
    return tasks.take(iosSafeMaxScheduled).toList();
  }
}
