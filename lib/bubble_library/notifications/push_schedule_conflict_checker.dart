import 'package:flutter/material.dart';
import '../models/global_push_settings.dart';
import '../models/push_config.dart';
import '../models/user_library.dart';
import '../models/content_item.dart';
import '../../notifications/skip_next_store.dart';

/// 衝突報告項目
class ConflictReport {
  final ConflictType type;
  final String productId;
  final String message;
  final Severity severity;

  ConflictReport({
    required this.type,
    required this.productId,
    required this.message,
    required this.severity,
  });

  @override
  String toString() => '[${severity.name.toUpperCase()}] $productId: $message';
}

enum ConflictType {
  daysOfWeekNoOverlap,
  freqExceedsDailyCap,
  allTimesInQuietHours,
  customTimesEmpty,
  minIntervalTooLarge,
  skipBlocksAllContent,
}

enum Severity { warning, error }

/// 推播排程衝突檢查器
class PushScheduleConflictChecker {
  /// 將 TimeOfDay 轉換為分鐘數
  static int _todToMin(TimeOfDay t) => t.hour * 60 + t.minute;

  /// 檢查時間是否在勿擾時段內
  static bool _inQuiet(TimeRange q, TimeOfDay t) {
    final start = _todToMin(q.start);
    final end = _todToMin(q.end);
    final cur = _todToMin(t);

    if (start == end) return false;

    if (start < end) return cur >= start && cur < end;
    return cur >= start || cur < end;
  }

  /// 檢查所有衝突
  static Future<List<ConflictReport>> checkAll({
    required GlobalPushSettings global,
    required Map<String, UserLibraryProduct> libraryByProductId,
    required Map<String, List<ContentItem>> contentByProduct,
    required Map<String, SavedContent> savedMap,
    required String uid,
  }) async {
    final reports = <ConflictReport>[];

    // 只檢查啟用推播且未隱藏的產品
    final enabledProducts = libraryByProductId.values
        .where((p) => p.pushEnabled && !p.isHidden)
        .toList();

    for (final product in enabledProducts) {
      // 1. daysOfWeek 衝突檢查
      reports.addAll(_checkDaysOfWeek(global, product));

      // 2. customTimes 驗證
      reports.addAll(_checkCustomTimes(product));

      // 3. quietHours 衝突檢查
      reports.addAll(_checkQuietHours(global, product));

      // 4. minIntervalMinutes 合理性檢查
      reports.addAll(_checkMinInterval(product));

      // 5. SkipNextStore 影響檢查
      final skipReports = await _checkSkipNext(
        product,
        contentByProduct[product.productId] ?? [],
        savedMap,
        uid,
      );
      reports.addAll(skipReports);
    }

    // 6. freqPerDay 總和與 dailyTotalCap 衝突檢查（全域）
    reports.addAll(_checkFreqTotal(enabledProducts, global));

    return reports;
  }

  /// 檢查 daysOfWeek 衝突（全域 vs 產品）
  static List<ConflictReport> _checkDaysOfWeek(
    GlobalPushSettings global,
    UserLibraryProduct product,
  ) {
    final reports = <ConflictReport>[];
    final globalDays = global.daysOfWeek;
    final productDays = product.pushConfig.daysOfWeek;

    // 檢查是否有交集
    final intersection = globalDays.intersection(productDays);
    if (intersection.isEmpty) {
      reports.add(ConflictReport(
        type: ConflictType.daysOfWeekNoOverlap,
        productId: product.productId,
        message:
            '產品的推播星期設定（${productDays.toList()..sort()}）與全域設定（${globalDays.toList()..sort()}）沒有交集，該產品將永遠不會推播',
        severity: Severity.error,
      ));
    }

    return reports;
  }

  /// 檢查 customTimes 驗證
  static List<ConflictReport> _checkCustomTimes(UserLibraryProduct product) {
    final reports = <ConflictReport>[];
    final config = product.pushConfig;

    if (config.timeMode == PushTimeMode.custom && config.customTimes.isEmpty) {
      reports.add(ConflictReport(
        type: ConflictType.customTimesEmpty,
        productId: product.productId,
        message:
            '時間模式設為「自訂時間」但未設定任何自訂時間，將回退到預設時段',
        severity: Severity.warning,
      ));
    }

    return reports;
  }

  /// 檢查 quietHours 衝突
  static List<ConflictReport> _checkQuietHours(
    GlobalPushSettings global,
    UserLibraryProduct product,
  ) {
    final reports = <ConflictReport>[];
    final config = product.pushConfig;

    // 解析推播時間（使用與 PushScheduler 相同的邏輯）
    List<TimeOfDay> times;
    if (config.timeMode == PushTimeMode.custom && config.customTimes.isNotEmpty) {
      times = List<TimeOfDay>.from(config.customTimes);
    } else {
      final presetSlotTimes = {
        'morning': TimeOfDay(hour: 9, minute: 10),
        'noon': TimeOfDay(hour: 12, minute: 30),
        'evening': TimeOfDay(hour: 18, minute: 40),
        'night': TimeOfDay(hour: 21, minute: 40),
      };
      final slots = config.presetSlots.isEmpty ? ['night'] : config.presetSlots;
      times = slots
          .map((s) => presetSlotTimes[s] ?? presetSlotTimes['night']!)
          .toList();
    }

    // 應用頻率擴展（簡化版，不考慮 minInterval）
    final effectiveTimes = times.take(config.freqPerDay).toList();

    // 檢查是否所有時間都在勿擾時段內
    final allInQuiet = effectiveTimes.every((t) => _inQuiet(global.quietHours, t));
    if (allInQuiet && effectiveTimes.isNotEmpty) {
      reports.add(ConflictReport(
        type: ConflictType.allTimesInQuietHours,
        productId: product.productId,
        message:
            '該產品的所有推播時間都在勿擾時段內（${global.quietHours.start.hour}:${global.quietHours.start.minute.toString().padLeft(2, '0')}-${global.quietHours.end.hour}:${global.quietHours.end.minute.toString().padLeft(2, '0')}），當天不會推播',
        severity: Severity.warning,
      ));
    }

    return reports;
  }

  /// 檢查 minIntervalMinutes 合理性
  static List<ConflictReport> _checkMinInterval(UserLibraryProduct product) {
    final reports = <ConflictReport>[];
    final minInterval = product.pushConfig.minIntervalMinutes;

    // 檢查是否超過 24 小時
    if (minInterval > 24 * 60) {
      reports.add(ConflictReport(
        type: ConflictType.minIntervalTooLarge,
        productId: product.productId,
        message:
            '最短間隔（$minInterval 分鐘）超過 24 小時，可能導致時間計算異常',
        severity: Severity.warning,
      ));
    }

    return reports;
  }

  /// 檢查 freqPerDay 總和與 dailyTotalCap
  static List<ConflictReport> _checkFreqTotal(
    List<UserLibraryProduct> enabledProducts,
    GlobalPushSettings global,
  ) {
    final reports = <ConflictReport>[];
    final totalFreq = enabledProducts.fold<int>(
      0,
      (sum, p) => sum + p.pushConfig.freqPerDay,
    );
    final dailyCap = global.dailyTotalCap;

    if (totalFreq > dailyCap) {
      reports.add(ConflictReport(
        type: ConflictType.freqExceedsDailyCap,
        productId: 'GLOBAL',
        message:
            '所有產品的推播頻率總和（$totalFreq）超過每日上限（$dailyCap），部分產品的推播次數可能少於設定值',
        severity: Severity.warning,
      ));
    }

    return reports;
  }

  /// 檢查 SkipNextStore 影響
  static Future<List<ConflictReport>> _checkSkipNext(
    UserLibraryProduct product,
    List<ContentItem> contentItems,
    Map<String, SavedContent> savedMap,
    String uid,
  ) async {
    final reports = <ConflictReport>[];

    // 載入 skip 清單
    final globalSkip = await SkipNextStore.load(uid);
    final scopedSkip = await SkipNextStore.loadForProduct(uid, product.productId);
    final allSkip = globalSkip.union(scopedSkip);

    if (allSkip.isEmpty) return reports;

    // 找出未學習的內容
    final unlearnedItems = contentItems.where((item) {
      return !(savedMap[item.id]?.learned ?? false);
    }).toList();

    // 檢查 skip 清單中的內容是否為唯一未學習內容
    final skipItems = unlearnedItems.where((item) => allSkip.contains(item.id)).toList();
    final remainingItems = unlearnedItems.where((item) => !allSkip.contains(item.id)).toList();

    if (skipItems.isNotEmpty && remainingItems.isEmpty && unlearnedItems.isNotEmpty) {
      reports.add(ConflictReport(
        type: ConflictType.skipBlocksAllContent,
        productId: product.productId,
        message:
            '跳過清單包含所有未學習的內容（${skipItems.length} 則），該產品在下次排程時可能無法推播',
        severity: Severity.warning,
      ));
    }

    return reports;
  }

  /// 格式化衝突報告為可讀字符串
  static String formatReports(List<ConflictReport> reports) {
    if (reports.isEmpty) return '✅ 未發現衝突';

    final buffer = StringBuffer();
    buffer.writeln('發現 ${reports.length} 個衝突：\n');

    final byType = <ConflictType, List<ConflictReport>>{};
    for (final report in reports) {
      byType.putIfAbsent(report.type, () => []).add(report);
    }

    for (final entry in byType.entries) {
      buffer.writeln('${entry.key.name}:');
      for (final report in entry.value) {
        buffer.writeln('  - ${report.message}');
      }
      buffer.writeln();
    }

    return buffer.toString();
  }
}
