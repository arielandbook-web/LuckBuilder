import 'dart:convert';
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

  static const String actionFavorite = 'ACTION_FAVORITE';
  static const String actionLearned = 'ACTION_LEARNED';
  static const String actionSnooze = 'ACTION_SNOOZE';
  static const String actionDisableProduct = 'ACTION_DISABLE_PRODUCT';

  Future<void> init({
    required String uid,
    void Function(Map<String, dynamic> data)? onTap,
    void Function(String? payload, String? actionId)? onSelect,
  }) async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');

    final iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
      notificationCategories: [
        DarwinNotificationCategory(
          'bubble_actions',
          actions: <DarwinNotificationAction>[
            DarwinNotificationAction.plain(actionFavorite, '加入最愛'),
            DarwinNotificationAction.plain(actionLearned, '我學會了'),
            DarwinNotificationAction.plain(actionSnooze, '稍後提醒'),
            DarwinNotificationAction.plain(actionDisableProduct, '關閉此商品推播'),
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
        await handlePayload(resp.payload);

        // 調用舊的 onSelect 回調（向後兼容）
        if (onSelect != null) {
          onSelect(resp.payload, resp.actionId);
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

    await plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
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
    final androidDetails = AndroidNotificationDetails(
      'bubble_channel',
      'Learning Bubble',
      channelDescription: 'Daily learning bubbles',
      importance: Importance.high,
      priority: Priority.high,
      styleInformation: BigTextStyleInformation(body),
      actions: const [
        AndroidNotificationAction(actionFavorite, '最愛'),
        AndroidNotificationAction(actionLearned, '學會'),
        AndroidNotificationAction(actionSnooze, '稍後'),
        AndroidNotificationAction(actionDisableProduct, '關閉'),
      ],
    );

    const iosDetails = DarwinNotificationDetails(
      categoryIdentifier: 'bubble_actions',
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

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

    // 同步更新 cache
    await _cache.add(ScheduledPushEntry(
      when: when,
      title: title,
      body: body,
      payload: payload,
    ));
  }
}
