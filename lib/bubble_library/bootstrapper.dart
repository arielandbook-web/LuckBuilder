import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

    final ns = NotificationService();
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

      final repo = ref.read(libraryRepoProvider);

      // action：先寫回資料
      final cid = contentItemId;
      final pid = productId;
      if (actionId == NotificationService.actionFavorite && cid != null) {
        await repo.setSavedItem(uid, cid, {'favorite': true});
      } else if (actionId == NotificationService.actionLearned && cid != null) {
        await repo.setSavedItem(uid, cid, {'learned': true});
      } else if (actionId == NotificationService.actionSnooze && cid != null) {
        await repo.setSavedItem(uid, cid, {'reviewLater': true});
      } else if (actionId == NotificationService.actionDisableProduct &&
          pid != null) {
        await repo.setPushEnabled(uid, pid, false);
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
