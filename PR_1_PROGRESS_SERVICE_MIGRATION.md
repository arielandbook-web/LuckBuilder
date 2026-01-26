# PR 1 | 鎖住「用戶狀態的唯一入口」

## 🎯 目的
結束「誰都可以亂改狀態」的混亂，建立統一的用戶狀態管理入口。

## ✅ 已完成

### 1. 核心服務已實現
- ✅ `ProgressService` 已創建 (`lib/services/progress_service.dart`)
  - Queue-based 架構：本地 queue + Firestore SSOT
  - 提供統一 API：`markLearned()`, `markSnoozed()`, `markOpened()`, `markDismissed()`
  - 自動背景同步機制
  - 合併狀態查詢（本地 + 雲端）

### 2. 代碼遷移完成
- ✅ `NotificationActionHandler` 已使用 `ProgressService`
  - 處理通知動作的統一入口
  - 所有狀態變更通過 `ProgressService`
- ✅ `BubbleActionHandler` 已遷移到 `ProgressService`
  - 更新 `_handleLearned()` 使用 `markLearned()`
  - 更新 `_handleSnoozed()` 使用 `markSnoozed()`
  - 移除對舊 `LearningProgressService` 的依賴

### 3. Provider 層完成
- ✅ 創建 `progressServiceProvider` (`lib/bubble_library/providers/providers.dart`)
  - 與現有 Firestore provider 整合
  - 可通過 Riverpod 在整個應用中使用
- ✅ 標記 `learningProgressServiceProvider` 為 `@Deprecated`

### 4. Firestore Rules 已更新
- ✅ 添加 `users/{userId}/progress/{contentId}` 規則
  - 允許用戶讀寫自己的進度資料
  - 確保 `contentId` 一致性檢查
  - 支持 `set() with merge: true` 操作
  - 修復 `updatedAt` 字段驗證問題

### 5. 舊代碼標記
- ✅ `LearningProgressService` 標記為 `@Deprecated`
  - 添加詳細的遷移說明
  - 保留向後兼容性

## 🚧 待完成（可選）

### 1. 檢查其他直接訪問點（優先級：低）
**已發現的文件（需要檢查是否使用舊服務）：**
- `lib/notifications/notification_inbox_store.dart`
- `lib/services/learning_progress_service.dart` （可能需要標記為 deprecated）
- `lib/data/repository.dart`
- `lib/notifications/favorite_sentences_store.dart`
- `lib/notifications/daily_routine_store.dart`
- `lib/collections/wishlist_store.dart`
- `lib/notifications/skip_next_store.dart`
- `lib/notifications/coming_soon_remind_store.dart`
- `lib/notifications/push_skip_store.dart`
- `lib/widgets/rich_sections/user/learn_log_store.dart`
- `lib/widgets/rich_sections/user/me_prefs_store.dart`
- `lib/widgets/rich_sections/user_learning_store.dart`
- `lib/ui/rich_sections/user_state_store.dart`
- `lib/theme/theme_controller.dart`

**注意：** 這些文件可能不直接操作用戶進度狀態，需要逐個檢查確認。

### 2. UI 層遷移檢查（優先級：低）
確保所有 UI 組件通過 `ProgressService` 更新狀態，不再直接：
- ❌ 呼叫 `FirebaseFirestore.instance.collection(...)`
- ❌ 直接寫入 `SharedPreferences`
- ❌ 使用舊的 `LearningProgressService`

## 📋 遷移檢查清單

- [x] 創建 `ProgressService` 核心服務
- [x] 實現 Queue-based 同步機制
- [x] 更新 Firestore Rules
- [x] `NotificationActionHandler` 遷移完成
- [x] 創建 `progressServiceProvider`
- [x] 遷移 `BubbleActionHandler` 到 `ProgressService`
- [x] 標記 `LearningProgressService` 為 deprecated
- [ ] 檢查並遷移所有 Firestore 直接訪問點（可選）
- [ ] 更新相關文檔（可選）
- [ ] 測試所有狀態變更路徑

## 🎯 成功標準

1. **唯一入口**：所有用戶狀態變更必須通過 `ProgressService`
2. **無直接訪問**：UI/Provider 不再直接寫 Firestore 或 SharedPreferences
3. **一致性**：本地 queue + Firestore SSOT 確保狀態一致
4. **可測試**：所有狀態變更可追蹤、可回放
5. **錯誤處理**：網絡失敗時狀態保留在本地 queue，自動重試

## 📝 使用範例

```dart
// ✅ 正確：通過 ProgressService 標記已學會
final progressService = ref.read(progressServiceProvider);
await progressService.markLearned(
  uid: currentUid,
  contentId: 'ai_l1_a0001',
  topicId: 'topic_123',
  productId: 'product_ai_l1',
  pushOrder: 5,
);

// ✅ 正確：查詢合併後的狀態
final mergedProgress = await progressService.getMergedProgress(
  uid: currentUid,
  contentId: 'ai_l1_a0001',
);

if (mergedProgress?.state == ProgressState.learned) {
  // 該內容已學會
}

// ❌ 錯誤：直接寫入 Firestore
await FirebaseFirestore.instance
  .collection('users')
  .doc(uid)
  .collection('contentState')
  .doc(contentId)
  .set({'status': 'learned'}); // 不要這樣做！

// ❌ 錯誤：使用舊服務
final oldProgress = ref.read(learningProgressServiceProvider);
await oldProgress.markLearnedAndAdvance(...); // 已過時！
```

## 🔧 下一步行動

1. 創建 `progressServiceProvider`
2. 更新 `BubbleActionHandler` 使用新 Provider
3. 逐個檢查上述文件列表，遷移直接訪問
4. 運行測試確保所有路徑正常工作
5. 部署更新的 Firestore Rules

## 📚 相關文檔

- [MIGRATION_GUIDE.md](./MIGRATION_GUIDE.md) - 完整遷移指南
- [NOTIFICATION_ARCHITECTURE.md](./NOTIFICATION_ARCHITECTURE.md) - 通知架構文檔
- [DATA_ARCHITECTURE.md](./DATA_ARCHITECTURE.md) - 數據架構設計
