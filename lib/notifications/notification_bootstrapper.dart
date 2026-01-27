import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../bubble_library/providers/providers.dart';
import '../bubble_library/notifications/notification_service.dart';
import '../bubble_library/notifications/notification_scheduler.dart';
import 'push_exclusion_store.dart';
import 'push_timeline_provider.dart';

class NotificationBootstrapper extends ConsumerStatefulWidget {
  final Widget child;
  const NotificationBootstrapper({super.key, required this.child});

  @override
  ConsumerState<NotificationBootstrapper> createState() => _NotificationBootstrapperState();
}

class _NotificationBootstrapperState extends ConsumerState<NotificationBootstrapper> with WidgetsBindingObserver {
  bool _configured = false;
  Timer? _sweepTimer;
  String? _currentUid;

  @override
  void initState() {
    super.initState();
    // 監聽 app 生命週期
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sweepTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    // ✅ 當 app 從背景恢復到前景時，立即執行 sweepMissed
    // 這可以處理用戶在 app 背景時滑掉通知的情況
    if (state == AppLifecycleState.resumed && _currentUid != null) {
      debugPrint('📱 App 恢復前景，執行 sweepMissed...');
      _sweepAndRefresh();
    }
  }

  Future<void> _sweepAndRefresh() async {
    if (!mounted || _currentUid == null) return;
    try {
      // ✅ 處理待處理的滑掉事件（來自背景回調）
      await NotificationService.processPendingDismisses(_currentUid!);
      
      // ✅ 掃描過期通知（5 分鐘標準）
      await PushExclusionStore.sweepExpired(_currentUid!);
      
      if (mounted) {
        ref.invalidate(upcomingTimelineProvider);
        ref.invalidate(scheduledCacheProvider);
      }
      debugPrint('✅ sweepMissed 完成');
    } catch (e) {
      debugPrint('❌ sweepMissed error: $e');
    }
  }

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
      if (_configured) {
        _configured = false;
        _sweepTimer?.cancel();
        _sweepTimer = null;
        _currentUid = null;
      }
      return widget.child;
    }

    // 登入後：配置回調（只在首次或 uid 變化時執行）
    if (!_configured || _currentUid != uid) {
      // ✅ 使用 WidgetsBinding.instance.addPostFrameCallback 確保只在首次渲染後執行
      // 避免在 build 方法中觸發 state 變化
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        
        _configured = true;
        _currentUid = uid;

        // 配置 NotificationService 的狀態變化回調
        // 注意：configure 可以多次調用，不會覆蓋 onLearned
        final ns = NotificationService();
        ns.configure(
          onStatusChanged: () {
            // ✅ 通知狀態變化時刷新相關 UI
            if (mounted) {
              ref.invalidate(upcomingTimelineProvider);
              ref.invalidate(scheduledCacheProvider);
            }
          },
          onReschedule: () async {
            // ✅ 重排未來 3 天
            try {
              // ✅ 使用統一排程入口（避免爆炸）
              final scheduler = ref.read(notificationSchedulerProvider);
              await scheduler.schedule(
                ref: ref,
                days: 3,
                source: 'notification_bootstrapper',
              );
            } catch (e) {
              debugPrint('❌ onReschedule error: $e');
            }
          },
        );

        // ✅ 定期掃描過期通知（每 2 分鐘）
        _sweepTimer?.cancel();
        _sweepTimer = Timer.periodic(const Duration(minutes: 2), (_) async {
          if (!mounted || _currentUid == null) return;
          try {
            await PushExclusionStore.sweepExpired(_currentUid!);
          } catch (e) {
            debugPrint('❌ sweepExpired error: $e');
          }
        });

        // ✅ 立即執行一次掃描
        Future.microtask(() async {
          if (!mounted || uid == null) return;
          try {
            await PushExclusionStore.sweepExpired(uid);
          } catch (e) {
            debugPrint('❌ Initial sweepExpired error: $e');
          }
        });
      });
    }

    return widget.child;
  }
}
