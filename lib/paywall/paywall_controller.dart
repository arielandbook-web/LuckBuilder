// lib/paywall/paywall_controller.dart
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'paywall_state.dart';

/// 單一產品（單一 IAP）購買/恢復/查詢狀態
abstract class PurchaseService {
  Future<void> purchaseProduct(String productId);
  Future<void> restorePurchases(); // restore 通常是全域 restore
  Future<bool> isProductUnlocked(String productId);
}

/// Stub（假實作）— 先讓 UI/流程跑通
class StubPurchaseService implements PurchaseService {
  final Set<String> _unlockedProductIds = {};

  @override
  Future<void> purchaseProduct(String productId) async {
    await Future.delayed(const Duration(milliseconds: 1200));
    _unlockedProductIds.add(productId);
  }

  @override
  Future<void> restorePurchases() async {
    await Future.delayed(const Duration(milliseconds: 600));
    // Stub：不做事，或你要測 restore 可以在這裡塞回已購買清單
    // _unlockedProductIds.addAll([...]);
  }

  @override
  Future<bool> isProductUnlocked(String productId) async {
    await Future.delayed(const Duration(milliseconds: 100));
    return _unlockedProductIds.contains(productId);
  }
}

final purchaseServiceProvider = Provider<PurchaseService>((ref) {
  return StubPurchaseService();
});

/// ✅ 重要：每個 productId 都有自己的 controller/state
final paywallControllerProvider = NotifierProviderFamily<PaywallController,
    PaywallState, String>(PaywallController.new);

class PaywallController extends FamilyNotifier<PaywallState, String> {
  PurchaseService get _svc => ref.read(purchaseServiceProvider);

  String get productId => arg;

  @override
  PaywallState build(String arg) {
    // 初始 locked，再同步查一次 entitlement
    _syncEntitlement();
    return const PaywallState.locked();
  }

  Future<void> _syncEntitlement() async {
    try {
      final unlocked = await _svc.isProductUnlocked(productId);
      if (unlocked) state = const PaywallState.unlocked();
      // 注意：library 狀態的檢查應該在產品頁面中進行
      // 因為 libraryProductsProvider 是 StreamProvider，需要持續監聽
    } catch (_) {
      // ignore
    }
  }

  Future<void> purchase() async {
    if (state.status == PaywallStatus.purchasing) return;
    state = const PaywallState.purchasing();
    try {
      await _svc.purchaseProduct(productId);
      state = const PaywallState.unlocked();
    } catch (_) {
      state = PaywallState.error('購買未完成，請稍後再試');
    }
  }

  Future<void> restore() async {
    if (state.status == PaywallStatus.purchasing) return;
    state = const PaywallState.purchasing();
    try {
      await _svc.restorePurchases();
      final unlocked = await _svc.isProductUnlocked(productId);
      state =
          unlocked ? const PaywallState.unlocked() : const PaywallState.locked();
    } catch (_) {
      state = PaywallState.error('恢復購買失敗，請稍後再試');
    }
  }

  void clearErrorToLocked() {
    state = const PaywallState.locked();
  }
}
