import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../bubble_library/providers/providers.dart';
import '../navigation/app_nav.dart';
import '../bubble_library/ui/product_library_page.dart';
import '../bubble_library/notifications/notification_service.dart';

class NotificationBootstrapper extends ConsumerStatefulWidget {
  final Widget child;
  const NotificationBootstrapper({super.key, required this.child});

  @override
  ConsumerState<NotificationBootstrapper> createState() => _NotificationBootstrapperState();
}

class _NotificationBootstrapperState extends ConsumerState<NotificationBootstrapper> {
  String? _initedUid;

  @override
  Widget build(BuildContext context) {
    String? uid;
    try {
      uid = ref.read(uidProvider);
    } catch (_) {
      uid = null;
    }

    // 未登入：重置
    if (uid == null) {
      _initedUid = null;
      return widget.child;
    }

    // 登入後：只 init 一次（或 uid 換人）
    if (_initedUid != uid) {
      _initedUid = uid;

      // 避免 build 期間直接 await
      scheduleMicrotask(() async {
        await NotificationService().init(
          uid: uid!,
          onTap: (data) {
            // ✅ 點通知 → 直接跳到那張卡（你已做好 initialContentItemId 滾動）
            final pid = (data['productId'] ?? '').toString();
            final cid = (data['contentItemId'] ?? '').toString();
            if (pid.isEmpty) return;

            rootNavKey.currentState?.push(
              MaterialPageRoute(
                builder: (_) => ProductLibraryPage(
                  productId: pid,
                  isWishlistPreview: false,
                  initialContentItemId: cid.isNotEmpty ? cid : null,
                ),
              ),
            );
          },
        );
      });
    }

    return widget.child;
  }
}
