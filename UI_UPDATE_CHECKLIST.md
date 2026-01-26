# UI 層更新清單

## 需要更新的檔案

### 🔴 高優先級（核心學習流程）

#### 1. Detail Page（內容詳情頁）
**檔案：** `lib/bubble_library/ui/detail_page.dart`

**需要更新的位置：**
- [ ] 「完成」按鈕點擊事件
- [ ] 「稍後再學」按鈕點擊事件
- [ ] 「加入收藏」按鈕點擊事件（如果影響排程）

**替換模式：**
```dart
// ❌ 舊代碼
await libraryRepo.setSavedItem(uid, contentId, {'learned': true});

// ✅ 新代碼
final actionHandler = NotificationActionHandler();
await actionHandler.handleLearned(
  uid: uid,
  payload: {
    'contentItemId': contentId,
    'topicId': topicId,
    'productId': productId,
    'pushOrder': pushOrder,
  },
);

// 重新排程
final scheduler = ref.read(notificationSchedulerProvider);
await scheduler.schedule(
  ref: ref,
  days: 3,
  source: 'detail_page_learned',
);
```

#### 2. Bubble Library Page（泡泡庫列表頁）
**檔案：** `lib/bubble_library/ui/bubble_library_page.dart`

**需要更新的位置：**
- [ ] 列表項目的「已完成」標記
- [ ] 批量操作（如果有）
- [ ] 篩選已學習項目（查詢方式可能需要調整）

**替換模式：**
```dart
// ❌ 舊代碼（查詢）
final savedMap = await ref.read(savedItemsProvider.future);
final isLearned = savedMap[contentId]?.learned ?? false;

// ✅ 新代碼（查詢）
final progressService = ProgressService();
final merged = await progressService.getMergedProgress(
  uid: uid,
  contentId: contentId,
);
final isLearned = merged?.state == ProgressState.learned;
```

#### 3. Home Today Task Section（首頁今日任務）
**檔案：** `lib/ui/rich_sections/home_today_task_section.dart`

**需要更新的位置：**
- [ ] 快速完成按鈕
- [ ] 任務狀態顯示

#### 4. Product Library Page（商品庫頁面）
**檔案：** `lib/bubble_library/ui/product_library_page.dart`

**需要更新的位置：**
- [ ] 加入/移除圖書館按鈕（如果影響排程）
- [ ] 推播開關（應該已經正確連接到排程系統）

### 🟡 中優先級（推播設定）

#### 5. Push Center Page（推播中心）
**檔案：** `lib/bubble_library/ui/push_center_page.dart`

**需要更新的位置：**
- [x] 全域推播設定變更後重新排程（已更新）
- [x] 測試通知按鈕（已更新）

**已完成：**
```dart
// ✅ 已經使用新的排程入口
final scheduler = ref.read(notificationSchedulerProvider);
await scheduler.schedule(
  ref: ref,
  days: 3,
  source: 'push_center',
);
```

#### 6. Push Product Config Page（商品推播設定）
**檔案：** `lib/bubble_library/ui/push_product_config_page.dart`

**需要更新的位置：**
- [ ] 商品推播設定變更後重新排程
- [ ] 推播時間設定變更

**替換模式：**
```dart
// ❌ 舊代碼
await PushOrchestrator.rescheduleNextDays(ref: ref, days: 3);

// ✅ 新代碼
final scheduler = ref.read(notificationSchedulerProvider);
await scheduler.schedule(
  ref: ref,
  days: 3,
  source: 'product_config_changed',
);
```

### 🟢 低優先級（其他 UI）

#### 7. Rich Sections（首頁各種區塊）
**檔案：** `lib/ui/rich_sections/*.dart`

**需要檢查的檔案：**
- [ ] `home_today_task_section.dart`（已列在高優先級）
- [ ] `home_unread_notifications_card.dart`
- [ ] 其他可能有快速操作按鈕的區塊

#### 8. Product Page（商品詳情頁）
**檔案：** `lib/pages/product_page.dart`

**需要更新的位置：**
- [ ] 加入圖書館後的排程觸發
- [ ] 移除圖書館後的排程取消

**注意事項：**
```dart
// ✅ cancel 方法已更新，應該可以正常使用
await NotificationService().cancel(notifId);
```

## 搜尋指令

### 找出所有需要更新的地方

```bash
# 搜尋舊的 API 調用
cd /Users/Ariel/開發中APP/LearningBubbles

# 1. 舊的進度服務調用
rg "markLearnedAndAdvance|markSnooze|snoozeContent" lib/

# 2. 直接寫 Firestore
rg "setSavedItem.*learned|setSavedItem.*reviewLater" lib/

# 3. 舊的排程調用
rg "PushOrchestrator\.rescheduleNextDays|PushOrchestrator\." lib/

# 4. 舊的 inbox store 調用
rg "NotificationInboxStore\." lib/

# 5. 查詢 saved_items 的地方（可能需要改為查詢 progress）
rg "savedItemsProvider|savedMap\[" lib/
```

## 更新檢查清單

### 對於每個檔案，檢查以下幾點：

- [ ] **寫入操作**：是否有標記 learned/reviewed/favorited 等操作？
  - 改為使用 `NotificationActionHandler`

- [ ] **查詢操作**：是否查詢學習狀態？
  - 改為使用 `ProgressService.getMergedProgress()`

- [ ] **排程觸發**：操作後是否需要重新排程？
  - 改為使用 `NotificationScheduler.schedule()`

- [ ] **必要資訊**：是否有 `topicId`, `productId`, `pushOrder`？
  - 確保 payload 包含完整資訊

- [ ] **錯誤處理**：是否有適當的錯誤處理？
  - 新系統會自動重試，但仍需 try-catch

## 測試計畫

### 對於每個更新的檔案，執行以下測試：

#### 1. 基本功能測試
- [ ] 按鈕是否正常點擊
- [ ] UI 是否立即更新
- [ ] 是否有錯誤訊息

#### 2. 狀態同步測試
- [ ] 關閉 app 後重開，狀態是否保持
- [ ] 檢查 Firestore，資料是否正確同步
- [ ] 離線操作後上線，是否自動同步

#### 3. 排程測試
- [ ] 操作後是否立即重新排程
- [ ] 下次推播是否排除已學習的內容
- [ ] 推播時間表是否正確更新

#### 4. 效能測試
- [ ] 連續點擊多次，是否有節流
- [ ] UI 是否流暢（不應該等待 Firestore）
- [ ] 背景同步是否影響前景操作

## 批量更新腳本（可選）

```bash
#!/bin/bash

# 備份原始檔案
mkdir -p backup/ui_files
cp lib/bubble_library/ui/detail_page.dart backup/ui_files/
cp lib/bubble_library/ui/bubble_library_page.dart backup/ui_files/

# 批量替換（需謹慎使用，建議手動檢查後再執行）
# sed -i '' 's/PushOrchestrator\.rescheduleNextDays/NotificationScheduler\.schedule/g' lib/**/*.dart

# 查找需要更新的檔案數量
echo "需要更新的檔案數量："
rg -l "markLearnedAndAdvance|PushOrchestrator\.rescheduleNextDays|NotificationInboxStore\." lib/ | wc -l
```

## 優先順序建議

### 第一階段（核心功能）
1. `detail_page.dart` - 最重要的學習流程
2. `home_today_task_section.dart` - 首頁快速操作
3. `bubble_library_page.dart` - 庫存管理

### 第二階段（推播設定）
4. `push_product_config_page.dart` - 商品推播設定
5. `product_page.dart` - 商品詳情頁

### 第三階段（其他 UI）
6. 其他 rich sections
7. 其他可能有操作的頁面

## 注意事項

### 1. payload 必須包含完整資訊
```dart
// ✅ 完整的 payload
payload: {
  'contentItemId': contentId,  // 或 'contentId'
  'topicId': topicId,          // 必要
  'productId': productId,      // 必要
  'pushOrder': pushOrder,      // 可選但建議提供
}
```

### 2. 錯誤處理
```dart
try {
  await actionHandler.handleLearned(...);
  await scheduler.schedule(...);
} catch (e) {
  // 顯示錯誤訊息給用戶
  if (mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('操作失敗：$e')),
    );
  }
}
```

### 3. 載入狀態
```dart
// 可選：顯示載入狀態
setState(() => _isLoading = true);
try {
  await actionHandler.handleLearned(...);
} finally {
  if (mounted) {
    setState(() => _isLoading = false);
  }
}
```

### 4. 向後兼容
```dart
// 如果無法取得新的資訊，可以使用舊的 fallback
final topicId = payload['topicId'] ?? 'unknown';
final productId = payload['productId'] ?? 'unknown';
```

## 完成標記

更新完成後，在此處打勾：

- [ ] `detail_page.dart`
- [ ] `bubble_library_page.dart`
- [ ] `home_today_task_section.dart`
- [ ] `push_product_config_page.dart`
- [ ] `product_page.dart`
- [ ] 其他 rich sections
- [ ] 執行測試
- [ ] 部署到生產環境

---

**預估工作量：** 3-5 小時（取決於檔案數量）  
**測試時間：** 2-3 小時  
**總計：** 5-8 小時
