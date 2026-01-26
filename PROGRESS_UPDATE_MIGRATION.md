# 產品進度更新 - Migration 文檔

## 概述
為了讓產品卡片能正確顯示學習進度（Day X/365），新增了產品進度更新機制。

## 新增欄位

### `users/{uid}/libraryProducts/{productId}`
```typescript
{
  progress: {
    nextSeq: number,      // 下一個要學習的 Day 序號
    learnedCount: number  // 已學習的總數
  }
}
```

## Migration 策略

### 1. 預設值處理
- **舊資料**：如果 `progress` 欄位不存在或為 null
  - `nextSeq`: 預設為 `1`
  - `learnedCount`: 預設為 `0`

### 2. 程式碼處理
在 `UserLibraryProduct.fromMap` 中已實作：
```dart
progress: ProgressState.fromMap(
    (m['progress'] as Map?)?.cast<String, dynamic>()),

// ProgressState.fromMap 中
factory ProgressState.fromMap(Map<String, dynamic>? m) {
  if (m == null) return ProgressState.defaults();
  return ProgressState(
    nextSeq: ((m['nextSeq'] ?? 1) as num).toInt(),
    learnedCount: ((m['learnedCount'] ?? 0) as num).toInt(),
  );
}
```

### 3. 更新時機
`progress` 欄位在以下時機更新：
- 用戶標記內容為已學習時（`BubbleActionHandler._handleLearned`）
- 通過 `LibraryRepo.updateProgress` 統一更新

### 4. 顯示邏輯優先級
產品卡片的 "Day X/365" 顯示優先級：
1. **優先**：從排程中獲取（`scheduledPushCache`）
2. **次選**：從已學習內容動態計算（`savedItems`）
3. **Fallback**：使用 `progress.nextSeq`

## 架構符合性

### ✅ 分層架構
- UI (bubble_library_page.dart) → Provider → Repository (library_repo.dart) → Firestore

### ✅ 單一資料來源
- `progress` 欄位由 `LibraryRepo` 統一管理
- 不允許多頭寫入

### ✅ 明確狀態
- 使用 `nextSeq` 和 `learnedCount` 明確欄位
- 不使用 null 或空值表示狀態

### ✅ 可觀測性
- `BubbleActionHandler` 中有 debug log
- 記錄 before/after 值：
  ```dart
  debugPrint('📊 已更新產品進度：productId=$productId, nextSeq=$currentNextSeq→$newNextSeq, learnedCount=$currentLearnedCount→$newLearnedCount');
  ```

### ✅ Migration 安全
- 舊資料缺欄位時有預設值
- 不會導致崩潰或錯誤顯示

## 測試檢查清單

- [ ] 舊用戶（沒有 progress 欄位）能正常顯示 "Day 1/365"
- [ ] 學習一則內容後，卡片進度正確更新
- [ ] 跳著學習（非連續）時，顯示第一個未完成的 Day
- [ ] 沒有排程時，fallback 到動態計算
- [ ] 所有 365 則完成後，顯示 "Day 366/365" 或適當訊息

## 相關檔案

- `lib/bubble_library/data/library_repo.dart` - Repository 層
- `lib/bubble_library/notifications/bubble_action_handler.dart` - 業務邏輯
- `lib/bubble_library/ui/bubble_library_page.dart` - UI 顯示
- `lib/bubble_library/models/user_library.dart` - 資料模型
