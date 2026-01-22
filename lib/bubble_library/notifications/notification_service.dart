import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'scheduled_push_cache.dart';
import '../../notifications/notification_inbox_store.dart';
import 'push_orchestrator.dart';

class NotificationService {
  static final NotificationService _i = NotificationService._();
  factory NotificationService() => _i;
  NotificationService._();

  final _cache = ScheduledPushCache();

  final FlutterLocalNotificationsPlugin plugin =
      FlutterLocalNotificationsPlugin();

  // ---- iOS Action IDs ----
  static const String iosCategoryBubbleActions = 'bubble_actions_v2';
  static const String actionLearned = 'ACTION_LEARNED';
  static const String actionLater = 'ACTION_LATER';

  // 保留舊的常數以向後兼容（但不再使用）
  @Deprecated('Use actionLearned instead')
  static const String actionFavorite = 'ACTION_FAVORITE';
  @Deprecated('Use actionLater instead')
  static const String actionSnooze = 'ACTION_SNOOZE';
  @Deprecated('No longer used')
  static const String actionDisableProduct = 'ACTION_DISABLE_PRODUCT';

  // （可選）回調函數，用於處理 action 點擊
  Future<void> Function(Map<String, dynamic> payload)? _onLearned;
  Future<void> Function(Map<String, dynamic> payload)? _onLater;

  /// 配置 action 回調（可選）
  void configure({
    Future<void> Function(Map<String, dynamic> payload)? onLearned,
    Future<void> Function(Map<String, dynamic> payload)? onLater,
  }) {
    _onLearned = onLearned;
    _onLater = onLater;
  }

  Future<void> init({
    required String uid,
    void Function(Map<String, dynamic> data)? onTap,
    void Function(String? payload, String? actionId)? onSelect,
  }) async {
    if (kDebugMode) {
      debugPrint('🔔 NotificationService.init 開始... uid=$uid');
    }

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS init：只保留兩顆 action
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
              '我學會了',
            ),
            DarwinNotificationAction.plain(
              actionLater,
              '之後再學',
              // 不設 foreground，避免「按一下就跳App」打擾
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

      // ✅ 自動已讀（收件匣）
      if (data['type'] == 'bubble') {
        final pid = (data['productId'] ?? '').toString();
        final cid = (data['contentItemId'] ?? '').toString();
        if (pid.isNotEmpty && cid.isNotEmpty) {
          await NotificationInboxStore.markOpened(
            uid,
            productId: pid,
            contentItemId: cid,
          );
        }
      }

      onTap?.call(data);
    }

    await plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (resp) async {
        final String? payloadStr = resp.payload;
        Map<String, dynamic> payload = {};
        if (payloadStr != null && payloadStr.isNotEmpty) {
          try {
            payload = jsonDecode(payloadStr) as Map<String, dynamic>;
          } catch (_) {}
        }

        final actionId = resp.actionId;

        if (kDebugMode) {
          debugPrint('[Notification] actionId=$actionId payload=$payload');
        }

        // 點通知本體（非按鍵）：actionId 為 null 或空字串
        if (actionId == null || actionId.isEmpty) {
          await handlePayload(resp.payload);
          onTap?.call(payload);
          return;
        }

        // 點按鍵：我學會了
        if (actionId == actionLearned) {
          if (_onLearned != null) {
            await _onLearned!(payload);
          } else if (onSelect != null) {
            // 向後兼容：調用舊的 onSelect
            onSelect(resp.payload, actionId);
          } else {
            if (kDebugMode) debugPrint('[Notification] onLearned not configured');
          }
          return;
        }

        // 點按鍵：之後再學
        if (actionId == actionLater) {
          if (_onLater != null) {
            await _onLater!(payload);
          } else if (onSelect != null) {
            // 向後兼容：調用舊的 onSelect
            onSelect(resp.payload, actionId);
          } else {
            if (kDebugMode) debugPrint('[Notification] onLater not configured');
          }
          return;
        }

        // 其他 action（向後兼容）
        if (onSelect != null) {
          onSelect(resp.payload, actionId);
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
    // 這裡不要做 heavy work；真正導頁交給 init 後的 onTap
  }

  Future<void> cancelAll() async {
    await plugin.cancelAll();
    await _cache.clear();
  }

  Future<void> cancel(int id) async {
    await plugin.cancel(id);
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
        AndroidNotificationAction(actionLearned, '我學會了'),
        AndroidNotificationAction(actionLater, '之後再學'),
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

    // 同步更新 cache
    await _cache.add(ScheduledPushEntry(
      when: when,
      title: title,
      body: body,
      payload: payload,
    ));
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
        AndroidNotificationAction(actionLearned, '我學會了'),
        AndroidNotificationAction(actionLater, '之後再學'),
      ],
    );

    final details = NotificationDetails(
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
        '點「我學會了」會換下一則；點「之後再學」會延後。',
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
