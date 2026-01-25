# 防止 App 爆炸 - 修復報告

## ✅ 已完成的修復

### 1. 統一 ID 使用（高優先級）

**問題：** `contentId` 和 `contentItemId` 混用導致狀態查詢失敗

**解決方案：**
- 統一使用 `contentItemId` 作為唯一標識
- `LearningProgressService` 的 `contentId` 參數實際上就是 `contentItemId`
- 在調用時統一傳入 `item.id`（即 contentItemId）
- 添加註解說明，避免混淆

**影響範圍：**
- `lib/bubble_library/ui/detail_page.dart`
- `lib/bubble_library/bootstrapper.dart`

---

### 2. 建立單一排程入口（高優先級）

**問題：** `rescheduleNextDays` 在 20+ 處被調用，可能互相覆蓋

**解決方案：**
創建 `NotificationScheduler` 類，提供統一排程入口

```dart
// lib/bubble_library/notifications/notification_scheduler.dart
class NotificationScheduler {
  Future<RescheduleResult?> schedule({
    required WidgetRef ref,
    int days = 3,
    String source = 'unknown',
    GlobalPushSettings? overrideGlobal,
    bool immediate = false,
  })
}
```

**功能：**
- ✅ **防抖機制**：500ms 內多次調用只執行一次
- ✅ **防重複執行**：正在排程時忽略新請求
- ✅ **最短間隔**：2 秒內不重複排程（可用 `immediate: true` 跳過）
- ✅ **錯誤處理**：排程失敗不拋出異常，確保 app 不會爆炸
- ✅ **來源追蹤**：記錄誰觸發了排程（用於 debug）

**已更新位置：**
- `lib/bubble_library/bootstrapper.dart` - App 啟動和通知回調
- `lib/bubble_library/ui/detail_page.dart` - 透過 BubbleActionHandler

---

### 3. 原子操作包裝器（高優先級）

**問題：** 狀態更新、取消通知、重新排程分開執行，部分失敗導致不一致

**解決方案：**
創建 `BubbleActionHandler` 類，統一處理所有泡泡動作

```dart
// lib/bubble_library/notifications/bubble_action_handler.dart
enum BubbleAction { opened, learned, snoozed, dismissed }

class BubbleActionHandler {
  static Future<BubbleActionResult> handle({
    required WidgetRef ref,
    required String contentItemId,
    required String productId,
    required BubbleAction action,
    ...
  })
}
```

**功能：**
- ✅ **統一入口**：所有泡泡狀態更新透過此類
- ✅ **錯誤追蹤**：記錄每個步驟的成功/失敗
- ✅ **保底機制**：`setSavedItem` 先執行，即使後續失敗也有基本狀態
- ✅ **步驟記錄**：返回 `BubbleActionResult` 包含完成的步驟列表

**處理流程（learned 範例）：**
1. sweepMissed（掃描過期）
2. markOpened（標記已讀）
3. setSavedItem（更新 saved_items - 保底）
4. markLearnedAndAdvance（更新 contentState - 可選）
5. cancelNotification（取消通知）
6. invalidate + await（刷新 provider）
7. reschedule（重新排程）

**已更新位置：**
- `lib/bubble_library/ui/detail_page.dart` - 完成和稍候再學按鈕

---

### 4. 強制刷新數據源（中優先級）

**問題：** 排程器可能讀到快取的舊數據

**解決方案：**
在 `rescheduleNextDays` 開頭強制刷新所有相關 provider

```dart
// push_orchestrator.dart
ref.invalidate(libraryProductsProvider);
ref.invalidate(savedItemsProvider);
ref.invalidate(productsMapProvider);
ref.invalidate(globalPushSettingsProvider);
```

**效果：**
- 確保 `savedMap` 讀到最新的 learned/reviewLater 狀態
- 避免「狀態已更新但排程還用舊數據」的問題

**已更新位置：**
- `lib/bubble_library/notifications/push_orchestrator.dart`

---

## 🛡️ 安全機制

### 1. 防抖機制
- 500ms 防抖延遲
- 避免短時間內多次排程

### 2. 防重複執行
- 正在排程時自動忽略新請求
- 避免同時執行多個排程

### 3. 最短間隔
- 2 秒內不重複排程
- 緊急情況可用 `immediate: true` 跳過

### 4. 錯誤不拋出
- 所有錯誤都被捕獲並記錄
- 返回 null 或 failure 結果，不會讓 app 崩潰

### 5. 保底機制
- `setSavedItem` 先執行（UI 可見的最低保證）
- 即使 `LearningProgressService` 失敗，基本狀態已保存

---

## 📊 修復前後對比

### 修復前
```dart
// ❌ 7 個步驟分開執行，任何一個失敗都會導致不一致
await sweepMissed();
await markOpened();
await setSavedItem();
await markLearnedAndAdvance();
await cancelByContentItemId();
ref.invalidate();
await rescheduleNextDays(); // 可能讀到舊數據
```

### 修復後
```dart
// ✅ 統一入口，有錯誤追蹤和保底機制
final result = await BubbleActionHandler.handle(
  action: BubbleAction.learned,
  ...
);

// 內部會：
// 1. 先刷新所有 provider
// 2. 按順序執行所有步驟
// 3. 記錄每個步驟的結果
// 4. 保底機制確保基本狀態已保存
```

---

## 🔍 未解決但已緩解的問題

### 1. 狀態定義分散
**現況：** 仍有 4 個不同的狀態系統
- NotificationInboxStore (scheduled/missed/opened/skipped)
- SavedContent (learned/reviewLater/favorite)
- LearningProgressService (learned/snoozed)
- SkipNextStore (skip 列表)

**緩解措施：**
- 明確定義優先順序：opened > missed > scheduled
- 統一使用 contentItemId 作為鍵值
- 添加詳細註解說明各系統用途

**未來改進：**
- 建議長期統一為單一狀態機

### 2. 非 Transaction 操作
**現況：** 操作仍是順序執行，不是真正的 transaction

**緩解措施：**
- 保底機制：`setSavedItem` 先執行
- 錯誤追蹤：記錄失敗的步驟
- 不拋出異常：確保 app 不崩潰

**未來改進：**
- 使用 Firestore Batch Write
- 或建立 compensation transaction（補償事務）

---

## 📝 使用方式

### DetailPage 按鈕（已更新）
```dart
// 完成按鈕
final result = await BubbleActionHandler.handle(
  ref: ref,
  contentItemId: item.id,
  productId: item.productId,
  action: BubbleAction.learned,
  topicId: product.topicId,
  pushOrder: item.pushOrder,
  source: 'detail_page_button',
);

if (result.success) {
  // 成功處理
} else {
  // 失敗：顯示錯誤訊息
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('操作失敗: ${result.error}')),
  );
}
```

### 統一排程入口
```dart
// 任何地方需要重新排程時
final scheduler = ref.read(notificationSchedulerProvider);
await scheduler.schedule(
  ref: ref,
  days: 3,
  source: 'your_source_name', // 用於 debug
  immediate: false, // 是否跳過防抖
);
```

---

## 🧪 測試建議

### 1. 快速測試流程
1. 點擊 detail 頁面「完成」按鈕
2. 觀察 console log，確認：
   - ✅ 每個步驟都執行成功
   - ✅ provider 刷新成功
   - ✅ 排程只執行一次
   - ✅ 內容卡片狀態立即更新

### 2. 壓力測試
1. 快速連續點擊「完成」按鈕 5 次
2. 確認：
   - ✅ 防抖機制生效（只執行一次）
   - ✅ app 不會崩潰
   - ✅ 狀態最終一致

### 3. 錯誤恢復測試
1. 斷網後點擊「完成」
2. 確認：
   - ✅ 顯示錯誤訊息
   - ✅ app 不會崩潰
   - ✅ 恢復網路後可重試

---

## 🎯 核心改進

1. **防止多次排程**：防抖 + 防重複執行
2. **確保數據新鮮**：強制刷新 provider
3. **錯誤不崩潰**：所有錯誤都被捕獲
4. **狀態可追蹤**：記錄每個步驟的結果
5. **保底機制**：基本狀態一定會保存

這些改進確保了 **app 不會爆炸**，即使部分操作失敗，也能保持基本功能正常運行。
