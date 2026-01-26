import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'push_orchestrator.dart';
import '../models/global_push_settings.dart';

/// 單一排程入口，確保所有排程操作都透過此入口執行
/// 
/// 功能：
/// - 防抖機制：短時間內多次調用只執行一次
/// - 錯誤處理：排程失敗不會影響 app 運行
/// - 追蹤來源：記錄誰觸發了排程（用於 debug）
class NotificationScheduler {
  static final NotificationScheduler _instance = NotificationScheduler._();
  factory NotificationScheduler() => _instance;
  NotificationScheduler._();

  Timer? _debounceTimer;
  bool _isScheduling = false;
  DateTime? _lastScheduledAt;
  String? _lastScheduleSource;

  /// 防抖時間：短時間內多次調用只執行一次
  static const _debounceDuration = Duration(milliseconds: 500);

  /// 最短排程間隔：避免過於頻繁的排程操作
  static const _minScheduleInterval = Duration(seconds: 2);

  /// 單一排程入口
  /// 
  /// [ref] - Riverpod WidgetRef
  /// [days] - 排程天數（預設 3 天）
  /// [source] - 觸發來源（用於 debug）
  /// [overrideGlobal] - 覆蓋的全域設定（用於立即更新）
  /// [immediate] - 是否立即執行（跳過防抖，用於緊急情況）
  Future<RescheduleResult?> schedule({
    required WidgetRef ref,
    int days = 3,
    String source = 'unknown',
    GlobalPushSettings? overrideGlobal,
    bool immediate = false,
  }) async {
    if (kDebugMode) {
      debugPrint('🔄 NotificationScheduler.schedule 請求：source=$source, immediate=$immediate');
    }

    // ✅ 防止重複執行：如果正在排程，則忽略
    if (_isScheduling) {
      if (kDebugMode) {
        debugPrint('⚠️ 排程已在執行中，忽略此次請求：source=$source');
      }
      return null;
    }

    // ✅ 最短間隔檢查：避免過於頻繁的排程
    if (!immediate && _lastScheduledAt != null) {
      final elapsed = DateTime.now().difference(_lastScheduledAt!);
      if (elapsed < _minScheduleInterval) {
        if (kDebugMode) {
          debugPrint('⚠️ 排程間隔過短（${elapsed.inMilliseconds}ms < ${_minScheduleInterval.inMilliseconds}ms），使用防抖');
        }
        // 使用防抖機制
        return _scheduleDebounced(ref, days, source, overrideGlobal);
      }
    }

    // ✅ 立即執行或防抖執行
    if (immediate) {
      return _executeSchedule(ref, days, source, overrideGlobal);
    } else {
      return _scheduleDebounced(ref, days, source, overrideGlobal);
    }
  }

  /// 防抖執行：延遲執行，如果期間有新請求則取消舊的
  Future<RescheduleResult?> _scheduleDebounced(
    WidgetRef ref,
    int days,
    String source,
    GlobalPushSettings? overrideGlobal,
  ) async {
    // 取消之前的計時器
    _debounceTimer?.cancel();

    final completer = Completer<RescheduleResult?>();

    _debounceTimer = Timer(_debounceDuration, () async {
      try {
        final result = await _executeSchedule(ref, days, source, overrideGlobal);
        completer.complete(result);
      } catch (e) {
        completer.completeError(e);
      }
    });

    return completer.future;
  }

  /// 實際執行排程
  Future<RescheduleResult?> _executeSchedule(
    WidgetRef ref,
    int days,
    String source,
    GlobalPushSettings? overrideGlobal,
  ) async {
    _isScheduling = true;
    _lastScheduleSource = source;

    try {
      if (kDebugMode) {
        debugPrint('🚀 開始執行排程：source=$source, days=$days');
      }

      final result = await PushOrchestrator.rescheduleNextDays(
        ref: ref,
        days: days,
        overrideGlobal: overrideGlobal,
      );

      _lastScheduledAt = DateTime.now();

      if (kDebugMode) {
        debugPrint('✅ 排程完成：source=$source, scheduledCount=${result.scheduledCount}');
      }

      return result;
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('❌ 排程失敗：source=$source, error=$e');
        debugPrint('Stack trace: $stackTrace');
      }
      // 不拋出異常，確保 app 不會爆炸
      return null;
    } finally {
      _isScheduling = false;
    }
  }

  /// 取消待執行的防抖排程
  void cancelPending() {
    _debounceTimer?.cancel();
    _debounceTimer = null;
  }

  /// 重置狀態（用於測試）
  void reset() {
    _debounceTimer?.cancel();
    _debounceTimer = null;
    _isScheduling = false;
    _lastScheduledAt = null;
    _lastScheduleSource = null;
  }

  /// 獲取排程狀態（用於 debug）
  Map<String, dynamic> getStatus() {
    return {
      'isScheduling': _isScheduling,
      'lastScheduledAt': _lastScheduledAt?.toIso8601String(),
      'lastScheduleSource': _lastScheduleSource,
      'hasPendingDebounce': _debounceTimer?.isActive ?? false,
    };
  }
}

/// Provider：提供單例 NotificationScheduler
final notificationSchedulerProvider = Provider<NotificationScheduler>((ref) {
  return NotificationScheduler();
});
