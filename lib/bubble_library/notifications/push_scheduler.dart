import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../models/content_item.dart';
import '../models/global_push_settings.dart';
import '../models/push_config.dart';
import '../models/user_library.dart';

class PushTask {
  final String productId;
  final DateTime when;
  final ContentItem item;
  /// 是否為該產品的最後一則內容（完成此則即完成產品）
  final bool isLastInProduct;

  PushTask({
    required this.productId,
    required this.when,
    required this.item,
    this.isLastInProduct = false,
  });
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

    // ✅ 修復：start == end 時視為「無勿擾時段」（例如 0:0 - 0:0）
    if (start == end) {
      if (kDebugMode) {
        debugPrint('  ℹ️ _inQuiet: 無勿擾時段（start == end），時間 ${t.hour}:${t.minute} 不在勿擾時段');
      }
      return false;
    }

    bool result;
    if (start < end) {
      result = cur >= start && cur < end; // same-day
    } else {
      result = cur >= start || cur < end; // crosses midnight
    }
    
    if (kDebugMode && result) {
      debugPrint('  ⚠️ _inQuiet: 時間 ${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')} 在勿擾時段內（${q.start.hour}:${q.start.minute} - ${q.end.hour}:${q.end.minute}）');
    }
    
    return result;
  }

  static DateTime _at(DateTime date, TimeOfDay tod) =>
      DateTime(date.year, date.month, date.day, tod.hour, tod.minute);

  static List<TimeOfDay> _resolveTimes(PushConfig cfg) {
    if (cfg.timeMode == PushTimeMode.custom && cfg.customTimes.isNotEmpty) {
      if (kDebugMode) {
        final customTimesStr = cfg.customTimes
            .map((t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}')
            .join(', ');
        debugPrint('✅ _resolveTimes: 使用自訂時間模式，customTimes: [$customTimesStr]');
      }
      final list = List<TimeOfDay>.from(cfg.customTimes)
        ..sort((a, b) => _todToMin(a).compareTo(_todToMin(b)));
      final result = list.take(5).toList();
      if (kDebugMode) {
        final resultStr = result
            .map((t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}')
            .join(', ');
        debugPrint('✅ _resolveTimes: 返回自訂時間列表: [$resultStr]');
      }
      return result;
    }
    if (kDebugMode) {
      debugPrint('ℹ️ _resolveTimes: 使用預設時間模式，timeMode: ${cfg.timeMode.name}, customTimes.isEmpty: ${cfg.customTimes.isEmpty}');
    }
    final slots = cfg.presetSlots.isEmpty ? ['night'] : cfg.presetSlots;
    final list = slots
        .map((s) => presetSlotTimes[s] ?? presetSlotTimes['night']!)
        .toList()
      ..sort((a, b) => _todToMin(a).compareTo(_todToMin(b)));
    return list.take(5).toList();
  }

  static List<TimeOfDay> _applyFreq(List<TimeOfDay> times, int freq, PushTimeMode timeMode, int minIntervalMinutes) {
    freq = freq.clamp(1, 5);
    if (times.isEmpty) return [presetSlotTimes['night']!];

    if (freq <= times.length) return times.take(freq).toList();

    // ✅ 自訂時間模式：如果 freq 大於 customTimes 數量，基於現有時間擴展
    // 例如：customTimes=[07:14], freq=2 → [07:14, 09:14]（間隔 2 小時）
    if (timeMode == PushTimeMode.custom) {
      final base = List<TimeOfDay>.from(times);
      while (base.length < freq) {
        final last = base.last;
        final mins = _todToMin(last) + minIntervalMinutes; // 使用用戶設定的間隔
        final newTime = TimeOfDay(hour: (mins ~/ 60) % 24, minute: mins % 60);
        // 確保不超過當天結束（23:59）且不與現有時間重複
        if (mins < 24 * 60 && !base.any((x) => _todToMin(x) == _todToMin(newTime))) {
          base.add(newTime);
        } else {
          break; // 無法再擴展
        }
      }
      base.sort((a, b) => _todToMin(a).compareTo(_todToMin(b)));
      return base.take(5).toList();
    }

    // ✅ 預設模式：擴展時間列表
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
      final mins = _todToMin(last) + minIntervalMinutes;
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

  /// 按順序推播未學習的內容：從 nextSeq 起依序找第一個未學習的。
  /// 回傳 (picked, isLastInProduct)。若全部已學習則 picked 為 null。
  static (ContentItem? picked, bool isLastInProduct) _pickSequentialUnlearned({
    required List<ContentItem> itemsSorted,
    required ProgressState progress,
    required Map<String, SavedContent> savedMap,
    Set<String> missedContentItemIds = const {},
  }) {
    if (itemsSorted.isEmpty) return (null, false);

    ContentItem? bySeq(int seq) {
      final idx = itemsSorted.indexWhere((e) => e.seq == seq);
      return idx >= 0 ? itemsSorted[idx] : null;
    }

    final maxSeq = itemsSorted.map((e) => e.seq).reduce((a, b) => a > b ? a : b);

    for (int seq = progress.nextSeq; seq <= maxSeq; seq++) {
      final item = bySeq(seq);
      if (item == null) continue;
      if (savedMap[item.id]?.learned ?? false) continue;
      // ✅ 已被使用者滑掉/判定 missed 的內容：重排時排除，避免一直推同一則
      if (missedContentItemIds.contains(item.id)) continue;
      final isLast = (seq == maxSeq);
      return (item, isLast);
    }
    return (null, false);
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

    // ✅ 新增：missed 的 contentItemId（用於排除已滑掉/錯過的內容）
    Set<String> missedContentItemIds = const {},
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
        if (kDebugMode && lp.pushConfig.timeMode == PushTimeMode.custom) {
          final baseTimesStr = baseTimes
              .map((t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}')
              .join(', ');
          debugPrint('  📅 buildSchedule: ${lp.productId} 在 ${date.year}-${date.month}-${date.day}，baseTimes: [$baseTimesStr]');
        }
        
        final times = _applyFreq(baseTimes, lp.pushConfig.freqPerDay, lp.pushConfig.timeMode, lp.pushConfig.minIntervalMinutes);
        if (kDebugMode && lp.pushConfig.timeMode == PushTimeMode.custom) {
          final timesStr = times
              .map((t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}')
              .join(', ');
          debugPrint('  📅 buildSchedule: ${lp.productId} 在 ${date.year}-${date.month}-${date.day}，應用頻率後 times: [$timesStr] (freq: ${lp.pushConfig.freqPerDay})');
        }

        // 避開 quiet hours（僅全域）
        final filtered = times.where((t) {
          final inGlobal = _inQuiet(global.quietHours, t);
          return !inGlobal;
        }).toList();
        
        if (kDebugMode && lp.pushConfig.timeMode == PushTimeMode.custom) {
          final filteredStr = filtered
              .map((t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}')
              .join(', ');
          final removedCount = times.length - filtered.length;
          debugPrint('  📅 buildSchedule: ${lp.productId} 在 ${date.year}-${date.month}-${date.day}，勿擾時段過濾後: [$filteredStr] (移除了 $removedCount 個時間)');
        }
        
        if (filtered.isEmpty) {
          if (kDebugMode && lp.pushConfig.timeMode == PushTimeMode.custom) {
            debugPrint('  ⚠️ buildSchedule: ${lp.productId} 在 ${date.year}-${date.month}-${date.day}，所有自訂時間都被過濾掉！');
          }
          continue;
        }

        final dts = filtered.map((t) => _at(date, t)).toList()..sort();
        
        // ✅ 自訂時間模式：即使小於最短間隔，仍以自訂時間為主
        final enforced = lp.pushConfig.timeMode == PushTimeMode.custom
            ? dts.take(5).toList() // 自訂時間模式：不強制執行最短間隔
            : _enforceMinInterval(dts, lp.pushConfig.minIntervalMinutes)
                .take(5)
                .toList();
        
        if (kDebugMode && lp.pushConfig.timeMode == PushTimeMode.custom) {
          final enforcedStr = enforced
              .map((dt) => '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}')
              .join(', ');
          debugPrint('  📅 buildSchedule: ${lp.productId} 在 ${date.year}-${date.month}-${date.day}，最終排程時間: [$enforcedStr] (自訂時間模式，不強制最短間隔)');
        }

        final items =
            List<ContentItem>.from(contentByProduct[lp.productId] ?? const [])
              ..sort((a, b) => a.seq.compareTo(b.seq));

        final (picked, isLastInProduct) = _pickSequentialUnlearned(
          itemsSorted: items,
          progress: lp.progress,
          savedMap: savedMap,
          missedContentItemIds: missedContentItemIds,
        );
        if (picked == null) continue;

        for (final when in enforced) {
          if (di == 0 && when.isBefore(now.add(const Duration(minutes: 1)))) {
            continue;
          }
          dayCandidates.add(PushTask(
            productId: lp.productId,
            when: when,
            item: picked,
            isLastInProduct: isLastInProduct,
          ));
        }
      }

      // 全域每日上限
      final dailyCap = global.dailyTotalCap.clamp(1, 50);
      
      if (dayCandidates.length > dailyCap) {
        // ✅ 修復：按產品分組，確保同一個產品的多個排程優先保留
        // 計算每個產品的優先分數
        int productPrio(String productId) {
          final lp = libraryByProductId[productId]!;
          int score = 0;
          
          final oi = idxOf(productId);
          score += (1000000 - oi).clamp(0, 1000000);
          
          if (lp.isFavorite) score += 2000;
          if (lp.lastOpenedAt != null) score += 300;
          score += lp.purchasedAt.millisecondsSinceEpoch ~/ 100000000;
          
          return score;
        }
        
        // 按產品分組
        final byProduct = <String, List<PushTask>>{};
        for (final task in dayCandidates) {
          byProduct.putIfAbsent(task.productId, () => []).add(task);
        }
        
        // ✅ 頻率優先於產品優先分數：先依 freqPerDay 降序，再依 productPrio
        int freqOf(String pid) => libraryByProductId[pid]!.pushConfig.freqPerDay;
        final sortedProducts = byProduct.keys.toList()
          ..sort((a, b) {
            final fa = freqOf(a);
            final fb = freqOf(b);
            if (fa != fb) return fb.compareTo(fa);
            return productPrio(b).compareTo(productPrio(a));
          });
        
        // 優先保留高頻率／高優先產品的所有排程
        final kept = <PushTask>[];
        for (final productId in sortedProducts) {
          final productTasks = byProduct[productId]!;
          // 按時間排序
          productTasks.sort((a, b) => a.when.compareTo(b.when));
          
          if (kept.length + productTasks.length <= dailyCap) {
            // 空間足夠，保留該產品的所有排程
            kept.addAll(productTasks);
          } else {
            // 空間不足，只保留能放下的部分
            final remaining = dailyCap - kept.length;
            if (remaining > 0) {
              kept.addAll(productTasks.take(remaining));
            }
            break;
          }
        }
        
        kept.sort((a, b) => a.when.compareTo(b.when));
        tasks.addAll(kept);
      } else {
        dayCandidates.sort((a, b) => a.when.compareTo(b.when));
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
