import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import 'scheduled_push_cache.dart';
import '../../notifications/push_exclusion_store.dart';
import 'push_orchestrator.dart';

class NotificationService {
  static final NotificationService _i = NotificationService._();
  factory NotificationService() => _i;
  NotificationService._();

  final _cache = ScheduledPushCache();
  bool _initialized = false;

  final FlutterLocalNotificationsPlugin plugin =
      FlutterLocalNotificationsPlugin();

  // ---- iOS Action IDs ----
  static const String iosCategoryBubbleActions = 'bubble_actions_v2';
  static const String iosCategoryCompletionActions = 'completion_actions_v1';
  static const String actionLearned = 'ACTION_LEARNED';
  static const String actionRestart = 'ACTION_RESTART';

  // 保留舊的常數以向後兼容（但不再使用）
  @Deprecated('No longer used - snooze feature removed')
  static const String actionLater = 'ACTION_LATER';
  @Deprecated('Use actionLearned instead')
  static const String actionFavorite = 'ACTION_FAVORITE';
  @Deprecated('No longer used')
  static const String actionSnooze = 'ACTION_SNOOZE';
  @Deprecated('No longer used')
  static const String actionDisableProduct = 'ACTION_DISABLE_PRODUCT';

  // （可選）回調函數，用於處理 action 點擊
  Future<void> Function(Map<String, dynamic> payload)? _onLearned;
  Future<void> Function(Map<String, dynamic> payload)? _onRestart;
  
  // 狀態變化回調：用於刷新 UI
  void Function()? _onStatusChanged;
  
  // 重排回調：用於在完成後重排
  Future<void> Function()? _onReschedule;

  /// 配置 action 回調（可選）
  /// 可以多次調用，後設的回調會覆蓋先前的
  void configure({
    Future<void> Function(Map<String, dynamic> payload)? onLearned,
    Future<void> Function(Map<String, dynamic> payload)? onRestart,
    void Function()? onStatusChanged,
    Future<void> Function()? onReschedule,
  }) {
    if (onLearned != null) _onLearned = onLearned;
    if (onRestart != null) _onRestart = onRestart;
    if (onStatusChanged != null) _onStatusChanged = onStatusChanged;
    if (onReschedule != null) _onReschedule = onReschedule;
  }

  Future<void> init({
    required String uid,
    void Function(Map<String, dynamic> data)? onTap,
    void Function(String? payload, String? actionId)? onSelect,
    void Function()? onStatusChanged,
  }) async {
    _onStatusChanged = onStatusChanged;
    if (_initialized) return;
    _initialized = true;

    if (kDebugMode) {
      debugPrint('🔔 NotificationService.init 開始... uid=$uid');
    }

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS init：只保留兩顆 action
    // ✅ 將按鈕改為 foreground 模式，避免 iOS 背景執行的限制導致當機
    // ✅ 啟用 customDismissAction 以接收滑掉通知的回調
    final iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
      notificationCategories: <DarwinNotificationCategory>[
        DarwinNotificationCategory(
          iosCategoryBubbleActions,
          actions: <DarwinNotificationAction>[
            DarwinNotificationAction.plain(
              actionLearned,
              '完成',
              options: <DarwinNotificationActionOption>{
                DarwinNotificationActionOption.foreground,
              },
            ),
          ],
          // ✅ 啟用自訂 dismiss action，當用戶滑掉通知時會收到回調
          options: <DarwinNotificationCategoryOption>{
            DarwinNotificationCategoryOption.customDismissAction,
          },
        ),
        // ✅ 完成通知的 category（包含重新學習按鈕）
        DarwinNotificationCategory(
          iosCategoryCompletionActions,
          actions: <DarwinNotificationAction>[
            DarwinNotificationAction.plain(
              actionRestart,
              '重新學習',
              options: <DarwinNotificationActionOption>{
                DarwinNotificationActionOption.foreground,
              },
            ),
          ],
        ),
      ],
    );

    final initSettings =
        InitializationSettings(android: androidInit, iOS: iosInit);

    Future<void> handlePayload(String? payload) async {
      final data = PushOrchestrator.decodePayload(payload);
      if (data == null) return;

      // ✅ 自動標記為已讀（收件匣）
      // 注意：只有 bubble 類型才標記已讀，completion 類型不標記
      if (data['type'] == 'bubble') {
        final pid = (data['productId'] ?? '').toString();
        final cid = (data['contentItemId'] ?? '').toString();
        if (pid.isNotEmpty && cid.isNotEmpty) {
          // ✅ 先掃描過期的，確保狀態一致
          await PushExclusionStore.sweepExpired(uid);
          
          // ✅ 標記為已讀（opened 優先於 missed）
          await PushExclusionStore.markOpened(uid, cid);
          
          // ✅ 刷新 UI
          _onStatusChanged?.call();
        }
      }

      onTap?.call(data);
    }

    await plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (resp) async {
        // ✅ 最優先：記錄所有收到的回調信息
        if (kDebugMode) {
          debugPrint('═══════════════════════════════════════════');
          debugPrint('🔔 [Foreground] onDidReceiveNotificationResponse 觸發');
          debugPrint('   actionId: ${resp.actionId}');
          debugPrint('   notificationResponseType: ${resp.notificationResponseType}');
          debugPrint('   payload: ${resp.payload}');
          debugPrint('═══════════════════════════════════════════');
        }
        
        // #region agent log
        try {
          final logFile = File('/Users/Ariel/開發中APP/LearningBubbles/.cursor/debug.log');
          await logFile.writeAsString('{"sessionId":"debug-session","runId":"run1","hypothesisId":"F","location":"notification_service.dart:105","message":"onDidReceiveNotificationResponse START","data":{"actionId":"${resp.actionId}"},"timestamp":${DateTime.now().millisecondsSinceEpoch}}\n', mode: FileMode.append);
        } catch (_) {}
        // #endregion
        
        // ✅ 確保處理過程不會被系統立即回收
        // 在 iOS 背景 Action 中，過長的延遲或等待 Frame 可能導致當機
        try {
          // #region agent log
          try {
            final logFile = File('/Users/Ariel/開發中APP/LearningBubbles/.cursor/debug.log');
            await logFile.writeAsString('{"sessionId":"debug-session","runId":"run1","hypothesisId":"F","location":"notification_service.dart:110","message":"Processing response directly","timestamp":${DateTime.now().millisecondsSinceEpoch}}\n', mode: FileMode.append);
          } catch (_) {}
          // #endregion
          
          final String? payloadStr = resp.payload;
          Map<String, dynamic> payload = {};
          if (payloadStr != null && payloadStr.isNotEmpty) {
            try {
              payload = jsonDecode(payloadStr) as Map<String, dynamic>;
            } catch (_) {}
          }

          final actionId = resp.actionId;
          const dismissActionIds = {
            'com.apple.UNNotificationDismissActionIdentifier',
            'dismissed',
            'notification_dismissed',
          };

          // ✅ 判斷是否為滑掉動作（通過 actionId）
          // iOS customDismissAction 會觸發特定的 actionId
          final isDismissed = actionId != null && dismissActionIds.contains(actionId);
          
          if (kDebugMode) {
            debugPrint('[Notification] actionId=$actionId payload=$payload');
            debugPrint('[Notification] notificationResponseType=${resp.notificationResponseType}');
            debugPrint('[Notification] 是否為滑掉動作: $isDismissed');
          }

          // 滑掉通知：立即標記為錯失
          if (isDismissed) {
            if (kDebugMode) {
              debugPrint('🔴 [Dismiss] 收到滑掉通知回調，actionId=$actionId');
            }
            final pid = (payload['productId'] ?? '').toString();
            final cid = (payload['contentItemId'] ?? '').toString();
            if (pid.isNotEmpty && cid.isNotEmpty) {
              // ✅ 檢查是否已經開啟過（opened 優先於 missed）
              final isOpened = await PushExclusionStore.isOpened(uid, cid);
              if (!isOpened) {
                // 立即標記為錯失（不等待 5 分鐘）
                await PushExclusionStore.markMissed(uid, cid);
                // ✅ 立刻重排：避免下一輪又排到同一則
                try {
                  await _onReschedule?.call();
                } catch (e) {
                  if (kDebugMode) {
                    debugPrint('❌ _onReschedule after dismiss error: $e');
                  }
                }
                // ✅ 刷新 UI
                _onStatusChanged?.call();
              } else {
                if (kDebugMode) {
                  debugPrint('ℹ️ 通知已開啟，不標記為 missed: $cid');
                }
              }
            }
            return;
          }

          // 點通知本體（非按鍵）：actionId 為 null 或空字串
          if (actionId == null || actionId.isEmpty) {
            await handlePayload(resp.payload);
            onTap?.call(payload);
            return;
          }

          // 點按鍵：我學會了
          if (actionId == actionLearned) {
            if (kDebugMode) {
              debugPrint('🔔 actionLearned: payload=$payload');
            }
            
            // 1) 先掃描過期的，確保狀態一致
            await PushExclusionStore.sweepExpired(uid);
            
            // 2) 標記已讀（opened 優先於 missed）
            final pid = (payload['productId'] ?? '').toString();
            final cid = (payload['contentItemId'] ?? '').toString();
            if (pid.isNotEmpty && cid.isNotEmpty) {
              await PushExclusionStore.markOpened(uid, cid);
            }
            
            // 3) 調用學習完成回調
            if (_onLearned != null) {
              await _onLearned!(payload);
            } else if (onSelect != null) {
              onSelect(resp.payload, actionId);
            }
            
            // 4) 重排未來 3 天（確保下次推播不會是同一則）
            try {
              await _onReschedule?.call();
            } catch (e) {
              if (kDebugMode) {
                debugPrint('❌ _onReschedule error: $e');
              }
            }
            
            // 5) 刷新 UI
            _onStatusChanged?.call();
            return;
          }

          // 點按鍵：重新學習（完成通知）
          if (actionId == actionRestart) {
            if (kDebugMode) {
              debugPrint('🔄 actionRestart: payload=$payload');
            }
            
            // 調用重新學習回調
            if (_onRestart != null) {
              await _onRestart!(payload);
            } else if (onSelect != null) {
              onSelect(resp.payload, actionId);
            }
            
            return;
          }

          // 其他 action（向後兼容）
          if (onSelect != null) {
            onSelect(resp.payload, actionId);
          }
        } catch (e) {
          // #region agent log
          try {
            final logFile = File('/Users/Ariel/開發中APP/LearningBubbles/.cursor/debug.log');
            await logFile.writeAsString('{"sessionId":"debug-session","runId":"run1","hypothesisId":"F","location":"notification_service.dart:180","message":"Error in callback","data":{"error":"$e"},"timestamp":${DateTime.now().millisecondsSinceEpoch}}\n', mode: FileMode.append);
          } catch (_) {}
          // #endregion
          if (kDebugMode) {
            debugPrint('❌ onDidReceiveNotificationResponse error: $e');
          }
        }
      },
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );

    // ✅ 冷啟動：App 是被通知點開的
    final launch = await plugin.getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp == true) {
      final resp = launch!.notificationResponse;
      await handlePayload(resp?.payload);
    }

    // Android 權限請求
    await plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    // ✅ iOS 權限請求（必須明確請求）
    final iosImpl = plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    if (iosImpl != null) {
      final granted = await iosImpl.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      if (kDebugMode) {
        debugPrint('🔔 iOS 通知權限: ${granted == true ? "已授予" : "未授予"}');
      }
    }

    if (kDebugMode) {
      debugPrint('🔔 ✅ NotificationService.init 完成');
    }
  }

  @pragma('vm:entry-point')
  static void notificationTapBackground(NotificationResponse response) {
    // ✅ 最優先：記錄所有收到的背景回調信息
    if (kDebugMode) {
      debugPrint('═══════════════════════════════════════════');
      debugPrint('🔵 [Background] notificationTapBackground 觸發');
      debugPrint('   actionId: ${response.actionId}');
      debugPrint('   notificationResponseType: ${response.notificationResponseType}');
      debugPrint('   payload: ${response.payload}');
      debugPrint('═══════════════════════════════════════════');
    }
    
    // 處理背景通知回調（包括滑掉通知）
    // 注意：這是靜態函數，無法訪問實例變量
    // 將需要處理的事件保存到本地存儲，等 app 恢復前景時處理
    _handleBackgroundResponse(response);
  }

  /// 處理背景通知回調
  /// 由於是靜態函數，需要使用 SharedPreferences 保存待處理的事件
  static Future<void> _handleBackgroundResponse(NotificationResponse response) async {
    try {
      final actionId = response.actionId;
      const dismissActionIds = {
        'com.apple.UNNotificationDismissActionIdentifier',
        'dismissed',
        'notification_dismissed',
      };

      // ✅ 判斷是否為滑掉動作（通過 actionId）
      final isDismissed = actionId != null && dismissActionIds.contains(actionId);

      if (kDebugMode) {
        debugPrint('🔵 [Background] 收到背景通知回調');
        debugPrint('   actionId=$actionId');
        debugPrint('   notificationResponseType=${response.notificationResponseType}');
        debugPrint('   isDismissed=$isDismissed');
      }

      // 滑掉通知：保存到待處理列表
      if (isDismissed) {
        final payloadStr = response.payload;
        if (payloadStr != null && payloadStr.isNotEmpty) {
          try {
            final payload = jsonDecode(payloadStr) as Map<String, dynamic>;
            final pid = (payload['productId'] ?? '').toString();
            final cid = (payload['contentItemId'] ?? '').toString();
            final uid = (payload['uid'] ?? '').toString();

            if (pid.isNotEmpty && cid.isNotEmpty && uid.isNotEmpty) {
              // 保存到待處理列表
              await _savePendingDismiss(uid, pid, cid);
              
              if (kDebugMode) {
                debugPrint('🔴 [Background Dismiss] 已保存待處理：uid=$uid, pid=$pid, cid=$cid');
              }
            }
          } catch (e) {
            if (kDebugMode) {
              debugPrint('❌ [Background] 解析 payload 失敗：$e');
            }
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [Background] 處理失敗：$e');
      }
    }
  }

  /// 保存待處理的滑掉事件
  static Future<void> _savePendingDismiss(String uid, String productId, String contentItemId) async {
    try {
      final sp = await SharedPreferences.getInstance();
      final key = 'pending_dismiss_$uid';
      final existing = sp.getStringList(key) ?? [];
      final entry = '$productId|$contentItemId';
      if (!existing.contains(entry)) {
        existing.add(entry);
        await sp.setStringList(key, existing);
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ _savePendingDismiss 失敗：$e');
      }
    }
  }

  /// 處理待處理的滑掉事件（app 恢復前景時調用）
  static Future<void> processPendingDismisses(String uid) async {
    try {
      final sp = await SharedPreferences.getInstance();
      final key = 'pending_dismiss_$uid';
      final pending = sp.getStringList(key) ?? [];

      if (pending.isEmpty) return;

      if (kDebugMode) {
        debugPrint('📋 處理 ${pending.length} 個待處理的滑掉事件');
      }

      for (final entry in pending) {
        final parts = entry.split('|');
        if (parts.length == 2) {
          final contentItemId = parts[1];

          // 檢查是否已開啟
          final isOpened = await PushExclusionStore.isOpened(uid, contentItemId);
          if (!isOpened) {
            await PushExclusionStore.markMissed(uid, contentItemId);
            
            if (kDebugMode) {
              debugPrint('✅ 已處理滑掉事件：$contentItemId');
            }
          }
        }
      }

      // 清空待處理列表
      await sp.remove(key);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ processPendingDismisses 失敗：$e');
      }
    }
  }

  Future<void> cancelAll() async {
    await plugin.cancelAll();
    await _cache.clear();
  }

  Future<void> cancel(int id) async {
    await plugin.cancel(id);
  }

  /// 根據 contentItemId 取消已排程的通知
  Future<void> cancelByContentItemId(String contentItemId) async {
    final entries = await _cache.loadSortedUpcoming();
    for (final entry in entries) {
      final cid = entry.payload['contentItemId'] as String?;
      if (cid == contentItemId && entry.notificationId != null) {
        await cancel(entry.notificationId!);
        await _cache.removeByNotificationId(entry.notificationId!);
        if (kDebugMode) {
          debugPrint('🔔 已取消通知 (contentItemId: $contentItemId, id: ${entry.notificationId})');
        }
      }
    }
  }

  /// 根據 productId 取消該產品所有已排程的通知（用於重新學習）
  Future<void> cancelByProductId(String productId) async {
    final entries = await _cache.loadSortedUpcoming();
    for (final entry in entries) {
      final pid = entry.payload['productId'] as String?;
      if (pid == productId && entry.notificationId != null) {
        await cancel(entry.notificationId!);
        await _cache.removeByNotificationId(entry.notificationId!);
        if (kDebugMode) {
          debugPrint('🔔 已取消通知 (productId: $productId, id: ${entry.notificationId})');
        }
      }
    }
  }

  Future<void> schedule({
    required int id,
    required DateTime when,
    required String title,
    required String body,
    required Map<String, dynamic> payload,
  }) async {
    if (kDebugMode) {
      debugPrint('🔔 NotificationService.schedule:');
      debugPrint('  - id: $id');
      debugPrint('  - when: $when');
      debugPrint('  - title: $title');
      debugPrint('  - tz.local: ${tz.local}');
    }

    final androidDetails = AndroidNotificationDetails(
      'bubble_channel',
      'Learning Bubble',
      channelDescription: 'Daily learning bubbles',
      importance: Importance.high,
      priority: Priority.high,
      styleInformation: BigTextStyleInformation(body),
      actions: const [
        AndroidNotificationAction(actionLearned, '完成'),
        AndroidNotificationAction(actionLater, '稍候再學'),
      ],
    );

    const iosDetails = DarwinNotificationDetails(
      categoryIdentifier: iosCategoryBubbleActions,
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    try {
      await plugin.zonedSchedule(
        id,
        title,
        body,
        tz.TZDateTime.from(when, tz.local),
        NotificationDetails(android: androidDetails, iOS: iosDetails),
        payload: jsonEncode(payload),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: null,
      );
      if (kDebugMode) {
        debugPrint('  ✅ 排程成功');
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('  ❌ 排程失敗: $e');
        debugPrint('  Stack trace: $stackTrace');
      }
      rethrow;
    }

    // 同步更新 cache（保存 notification ID）
    await _cache.add(ScheduledPushEntry(
      when: when,
      title: title,
      body: body,
      payload: payload,
      notificationId: id,
    ));
  }

  /// 立即顯示完成通知（橫幅通知）
  Future<void> showCompletionBanner({
    required String productTitle,
    required String productId,
    required String uid,
  }) async {
    if (kDebugMode) {
      debugPrint('🎉 showCompletionBanner: $productTitle');
    }

    // iOS 完成通知：包含重新學習按鈕
    const iosDetails = DarwinNotificationDetails(
      categoryIdentifier: iosCategoryCompletionActions,
      presentAlert: true,
      presentSound: true,
      presentBadge: true,
    );

    // Android 完成通知：包含重新學習按鈕
    const androidDetails = AndroidNotificationDetails(
      'completion_channel',
      'Completion',
      channelDescription: 'Product completion notifications',
      importance: Importance.max,
      priority: Priority.high,
      actions: [
        AndroidNotificationAction(actionRestart, '重新學習'),
      ],
    );

    const details = NotificationDetails(
      iOS: iosDetails,
      android: androidDetails,
    );

    final payload = <String, dynamic>{
      'type': 'completion',
      'uid': uid,
      'productId': productId,
    };

    try {
      // 使用當前時間戳作為 ID，確保每次都是新的通知
      final notificationId = DateTime.now().millisecondsSinceEpoch.remainder(1000000);
      await plugin.show(
        notificationId,
        '恭喜完成！🎉',
        '已完成「$productTitle」的所有內容學習！',
        details,
        payload: jsonEncode(payload),
      );
      if (kDebugMode) {
        debugPrint('🎉 ✅ 完成通知發送成功');
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('🎉 ❌ 完成通知發送失敗: $e');
        debugPrint('Stack trace: $stackTrace');
      }
      rethrow;
    }
  }

  /// 排程完成通知（延遲 2 分鐘顯示）
  Future<void> scheduleCompletionBanner({
    required String productTitle,
    required String productId,
    required String uid,
    required DateTime lastItemScheduledTime,
  }) async {
    if (kDebugMode) {
      debugPrint('🎉 scheduleCompletionBanner: $productTitle (2 分鐘後顯示)');
    }

    // 計算 2 分鐘後的時間
    final when = lastItemScheduledTime.add(const Duration(minutes: 2));
    
    // 確保時間在未來（如果最後一則的時間已經過去，則使用當前時間 + 2 分鐘）
    final now = DateTime.now();
    final scheduledTime = when.isAfter(now) ? when : now.add(const Duration(minutes: 2));

    // iOS 完成通知：包含重新學習按鈕
    const iosDetails = DarwinNotificationDetails(
      categoryIdentifier: iosCategoryCompletionActions,
      presentAlert: true,
      presentSound: true,
      presentBadge: true,
    );

    // Android 完成通知：包含重新學習按鈕
    const androidDetails = AndroidNotificationDetails(
      'completion_channel',
      'Completion',
      channelDescription: 'Product completion notifications',
      importance: Importance.max,
      priority: Priority.high,
      actions: [
        AndroidNotificationAction(actionRestart, '重新學習'),
      ],
    );

    final payload = <String, dynamic>{
      'type': 'completion',
      'uid': uid,
      'productId': productId,
    };

    try {
      // 使用產品 ID 的 hash 作為通知 ID，確保同一產品只會有一個完成通知
      final notificationId = (productId.hashCode.abs() % 900000) + 100000;
      
      await plugin.zonedSchedule(
        notificationId,
        '恭喜完成！🎉',
        '已完成「$productTitle」的所有內容學習！',
        tz.TZDateTime.from(scheduledTime, tz.local),
        NotificationDetails(android: androidDetails, iOS: iosDetails),
        payload: jsonEncode(payload),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: null,
      );
      
      // ✅ 同步更新 cache（保存 notification ID，以便重新學習時能正確取消）
      await _cache.add(ScheduledPushEntry(
        when: scheduledTime,
        title: '恭喜完成！🎉',
        body: '已完成「$productTitle」的所有內容學習！',
        payload: payload,
        notificationId: notificationId,
      ));
      
      if (kDebugMode) {
        debugPrint('🎉 ✅ 完成通知已排程：$productTitle (將於 $scheduledTime 顯示)');
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('🎉 ❌ 完成通知排程失敗: $e');
        debugPrint('Stack trace: $stackTrace');
      }
      rethrow;
    }
  }

  /// 推播中心「試播一則」會呼叫這個
  Future<void> showTestBubbleNotification() async {
    if (kDebugMode) {
      debugPrint('🧪 showTestBubbleNotification 開始...');
    }

    // iOS 會用 categoryIdentifier 對應按鍵
    const iosDetails = DarwinNotificationDetails(
      categoryIdentifier: iosCategoryBubbleActions,
      presentAlert: true,
      presentSound: true,
      presentBadge: true,
    );

    // Android 可先簡單帶過
    const androidDetails = AndroidNotificationDetails(
      'bubble_test_channel',
      'Bubble Test',
      channelDescription: 'Test bubble notifications',
      importance: Importance.max,
      priority: Priority.high,
      actions: [
        AndroidNotificationAction(actionLearned, '完成'),
      ],
    );

    const details = NotificationDetails(
      iOS: iosDetails,
      android: androidDetails,
    );

    final payload = <String, dynamic>{
      'type': 'test',
      'contentId': 'test_content_001',
      'topicId': 'test_topic_001',
      'productId': 'test_product_001',
      'contentItemId': 'test_content_001',
      'pushOrder': 1,
      'ts': DateTime.now().toIso8601String(),
    };

    try {
      await plugin.show(
        999001, // 固定 id（測試時覆蓋同一則）
        '學習泡泡🫧 30 秒',
        '點「完成」標記為已學習。',
        details,
        payload: jsonEncode(payload),
      );
      if (kDebugMode) {
        debugPrint('🧪 ✅ 測試通知發送成功');
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('🧪 ❌ 測試通知發送失敗: $e');
        debugPrint('Stack trace: $stackTrace');
      }
      rethrow;
    }
  }
}
