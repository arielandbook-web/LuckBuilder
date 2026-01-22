import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/learning_progress_service.dart';
import 'notifications/notification_service.dart';
import 'notifications/push_orchestrator.dart';
import 'providers/providers.dart';
import 'ui/detail_page.dart';
import 'ui/product_library_page.dart';

class BubbleBootstrapper extends ConsumerStatefulWidget {
  final Widget child;
  const BubbleBootstrapper({super.key, required this.child});

  @override
  ConsumerState<BubbleBootstrapper> createState() => _BubbleBootstrapperState();
}

class _BubbleBootstrapperState extends ConsumerState<BubbleBootstrapper> {
  bool _inited = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_inited) return;
    _inited = true;

    // 未登入時直接不處理（避免 crash）
    String uid;
    try {
      uid = ref.read(uidProvider);
    } catch (_) {
      return;
    }

    // 初始化 LearningProgressService
    final progress = LearningProgressService();

    // 配置 NotificationService 的 action callbacks
    final ns = NotificationService();
    ns.configure(
      onLearned: (payload) async {
        if (kDebugMode) {
          debugPrint('📱 onLearned called with payload: $payload');
        }
        
        // payload 可能包含 contentId 或 contentItemId，統一處理
        final topicId = payload['topicId'] as String?;
        final contentId = payload['contentId'] as String? ??
            payload['contentItemId'] as String?;
        final pushOrderRaw = payload['pushOrder'];
        
        // JSON decode 後 pushOrder 可能是 num 而非 int，需要轉換
        int? pushOrder;
        if (pushOrderRaw is int) {
          pushOrder = pushOrderRaw;
        } else if (pushOrderRaw is num) {
          pushOrder = pushOrderRaw.toInt();
        }

        if (kDebugMode) {
          debugPrint('📋 Parsed: topicId=$topicId contentId=$contentId pushOrder=$pushOrder (raw: $pushOrderRaw, type: ${pushOrderRaw.runtimeType})');
        }

        if (topicId == null || contentId == null || pushOrder == null) {
          if (kDebugMode) {
            debugPrint(
                '⚠️ markLearnedAndAdvance: missing fields topicId=$topicId contentId=$contentId pushOrder=$pushOrder');
          }
          return;
        }

        try {
          await progress.markLearnedAndAdvance(
            topicId: topicId,
            contentId: contentId,
            pushOrder: pushOrder,
            source: 'ios_action',
          );
          if (kDebugMode) {
            debugPrint(
                '✅ markLearnedAndAdvance: topicId=$topicId contentId=$contentId pushOrder=$pushOrder');
          }
        } catch (e, stackTrace) {
          if (kDebugMode) {
            debugPrint('❌ markLearnedAndAdvance error: $e');
            debugPrint('Stack trace: $stackTrace');
          }
        }
      },
      onLater: (payload) async {
        if (kDebugMode) {
          debugPrint('📱 onLater called with payload: $payload');
        }
        
        // payload 可能包含 contentId 或 contentItemId，統一處理
        final topicId = payload['topicId'] as String?;
        final contentId = payload['contentId'] as String? ??
            payload['contentItemId'] as String?;
        final pushOrderRaw = payload['pushOrder'];
        
        // JSON decode 後 pushOrder 可能是 num 而非 int，需要轉換
        int? pushOrder;
        if (pushOrderRaw is int) {
          pushOrder = pushOrderRaw;
        } else if (pushOrderRaw is num) {
          pushOrder = pushOrderRaw.toInt();
        }

        if (kDebugMode) {
          debugPrint('📋 Parsed: topicId=$topicId contentId=$contentId pushOrder=$pushOrder (raw: $pushOrderRaw, type: ${pushOrderRaw.runtimeType})');
        }

        if (topicId == null || contentId == null || pushOrder == null) {
          if (kDebugMode) {
            debugPrint(
                '⚠️ snoozeContent: missing fields topicId=$topicId contentId=$contentId pushOrder=$pushOrder');
          }
          return;
        }

        try {
          await progress.snoozeContent(
            topicId: topicId,
            contentId: contentId,
            pushOrder: pushOrder,
            duration: const Duration(hours: 6), // ✅ 可改成明天 9:00（之後可調整）
            source: 'ios_action',
          );
          if (kDebugMode) {
            debugPrint(
                '🌙 snoozeContent: topicId=$topicId contentId=$contentId pushOrder=$pushOrder');
          }
        } catch (e, stackTrace) {
          if (kDebugMode) {
            debugPrint('❌ snoozeContent error: $e');
            debugPrint('Stack trace: $stackTrace');
          }
        }
      },
    );

    ns.init(
      uid: uid,
      onTap: (data) {
        // 導航等邏輯在這裡處理
        // 目前先不做導航，只保留原有的 onSelect 邏輯
      },
      onSelect: (payload, actionId) async {
        final data = PushOrchestrator.decodePayload(payload);
        if (data == null) return;

        // 注意：自動標記已讀已在 NotificationService.init 內部處理

        final productId = data['productId'] as String?;
        final contentItemId = data['contentItemId'] as String?;
        // ✅ 從 payload 獲取 topicId 和 pushOrder（已在 push_orchestrator 中加入）
        final topicId = data['topicId'] as String?;
        final contentId = data['contentId'] as String? ?? contentItemId;
        final pushOrderRaw = data['pushOrder'];

      final repo = ref.read(libraryRepoProvider);

      // action：先寫回資料
      final cid = contentItemId;
      final pid = productId;
      
      // 新的 2 個 action
      if (actionId == NotificationService.actionLearned && cid != null) {
        // ✅ 使用 LearningProgressService 標記為已學會（統一學習狀態管理）
        int? pushOrder;
        if (pushOrderRaw is int) {
          pushOrder = pushOrderRaw;
        } else if (pushOrderRaw is num) {
          pushOrder = pushOrderRaw.toInt();
        }

        if (topicId != null && contentId != null && pushOrder != null) {
          try {
            await progress.markLearnedAndAdvance(
              topicId: topicId,
              contentId: contentId,
              pushOrder: pushOrder,
              source: 'notification_action',
            );
            if (kDebugMode) {
              debugPrint('✅ LEARNED: product=$pid content=$cid -> advance next');
            }
          } catch (e) {
            if (kDebugMode) {
              debugPrint('❌ markLearnedAndAdvance error: $e');
            }
            // 降級：如果 LearningProgressService 失敗，使用舊方法
            await repo.setSavedItem(uid, cid, {'learned': true});
          }
        } else {
          // 如果 payload 缺少必要資訊，使用舊方法
          await repo.setSavedItem(uid, cid, {'learned': true});
        }
      } else if (actionId == NotificationService.actionLater && cid != null) {
        // ✅ 使用 LearningProgressService 稍後再學（統一學習狀態管理）
        int? pushOrder;
        if (pushOrderRaw is int) {
          pushOrder = pushOrderRaw;
        } else if (pushOrderRaw is num) {
          pushOrder = pushOrderRaw.toInt();
        }

        if (topicId != null && contentId != null && pushOrder != null) {
          try {
            await progress.snoozeContent(
              topicId: topicId,
              contentId: contentId,
              pushOrder: pushOrder,
              duration: const Duration(hours: 6),
              source: 'notification_action',
            );
            if (kDebugMode) {
              debugPrint('🌙 LATER: product=$pid content=$cid -> snooze');
            }
          } catch (e) {
            if (kDebugMode) {
              debugPrint('❌ snoozeContent error: $e');
            }
            // 降級：如果 LearningProgressService 失敗，使用舊方法
            await repo.setSavedItem(uid, cid, {'reviewLater': true});
          }
        } else {
          // 如果 payload 缺少必要資訊，使用舊方法
          await repo.setSavedItem(uid, cid, {'reviewLater': true});
        }
      }

      // 點通知本體：跳轉
      if (!mounted) return;
      if (cid != null) {
        Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => DetailPage(contentItemId: cid)));
      } else if (pid != null) {
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) =>
              ProductLibraryPage(productId: pid, isWishlistPreview: false),
        ));
      }

      // 重排未來 3 天
      await PushOrchestrator.rescheduleNextDays(ref: ref, days: 3);
    });

    // App 啟動：登入後會自動重排一次（若此刻未登入會略過）
    Future.microtask(() async {
      try {
        await PushOrchestrator.rescheduleNextDays(ref: ref, days: 3);
      } catch (_) {}
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
