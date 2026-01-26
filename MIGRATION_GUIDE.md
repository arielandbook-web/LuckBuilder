# 通知系統遷移指南

## 從舊系統遷移到 SSOT + Queue 架構

### 概述

舊系統存在的問題：
1. **多處狀態來源**：`NotificationInboxStore`, `LearningProgressService`, `savedItems` 各自管理狀態
2. **同步問題**：SharedPreferences 作為最終狀態儲存，與 Firestore 不一致
3. **排程爆炸**：多處觸發排程，缺乏節流和去重機制
4. **狀態混亂**：missed, opened, learned 狀態在不同系統間不一致

新架構解決方案：
1. **唯一真相來源**：Firestore `users/{uid}/progress/{contentId}` 是最終狀態
2. **本地佇列**：SharedPreferences 只做待同步事件佇列
3. **統一入口**：所有狀態變更必須通過 `ProgressService`
4. **合併狀態**：排程時合併 Firestore + local queue
5. **統一排程**：只有 `NotificationScheduler.schedule()` 可被外部調用

## 架構變更對照表

### 核心服務

| 舊系統 | 新系統 | 說明 |
|--------|--------|------|
| `LearningProgressService` | `ProgressService` | 統一的進度管理，包含 SSOT + Queue 邏輯 |
| `NotificationInboxStore` | 移除（合併到 `ProgressService`） | 不再需要單獨的 inbox 管理 |
| `PushOrchestrator` | `NotificationScheduler` | 統一排程入口，防止爆炸 |
| - | `NotificationActionHandler` | 新增：通知動作統一處理器 |

### 資料結構變更

#### Firestore

**舊系統：**
- `users/{uid}/topicProgress/{topicId}` - 主題進度
- `users/{uid}/contentState/{contentId}` - 內容狀態
- `users/{uid}/saved_items/{contentId}` - 儲存項目

**新系統：**
- `users/{uid}/progress/{contentId}` - **統一進度管理**
  ```dart
  {
    contentId: string,
    topicId: string,
    productId: string,
    state: 'queued' | 'scheduled' | 'delivered' | 'opened' | 'learned' | 'snoozed' | 'dismissed' | 'expired',
    pushOrder: int?,
    scheduledFor: Timestamp?,
    snoozedUntil: Timestamp?,
    openedAt: Timestamp?,
    learnedAt: Timestamp?,
    dismissedAt: Timestamp?,
    updatedAt: Timestamp
  }
  ```
- `users/{uid}/saved_items/{contentId}` - 保留（向後兼容）

#### SharedPreferences

**舊系統：**
- `notification_inbox_scheduled_{uid}` - 排程通知清單
- `notification_inbox_missed_{uid}` - 錯過通知清單
- `notification_inbox_opened_{uid}` - 已開啟通知清單

**新系統：**
- `local_action_queue_v1` - **統一待同步事件佇列**
  ```dart
  [
    {
      id: string,
      contentId: string,
      action: 'learned' | 'snooze' | 'opened' | 'dismissed',
      atMs: int,
      payload: { uid, topicId, productId, pushOrder, ... },
      synced: bool
    }
  ]
  ```
- `scheduled_push_cache_v1` - 排程快取（僅用於 UI 顯示和去重）

### API 變更

#### 標記為已學會

**舊系統：**
```dart
// 方式 1：LearningProgressService
await progress.markLearnedAndAdvance(
  topicId: topicId,
  contentId: contentId,
  pushOrder: pushOrder,
);

// 方式 2：直接寫 Firestore
await libraryRepo.setSavedItem(uid, contentId, {'learned': true});

// 方式 3：NotificationInboxStore
await NotificationInboxStore.markOpened(uid, productId: pid, contentItemId: cid);
```

**新系統：**
```dart
// 唯一方式：ProgressService
final progressService = ProgressService();
await progressService.markLearned(
  uid: uid,
  contentId: contentId,
  topicId: topicId,
  productId: productId,
  pushOrder: pushOrder,
);
```

或使用統一的 action handler：
```dart
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
```

#### 排程通知

**舊系統：**
```dart
// 方式 1：PushOrchestrator
await PushOrchestrator.rescheduleNextDays(ref: ref, days: 3);

// 方式 2：直接調用 NotificationService
final ns = NotificationService();
await ns.schedule(...);
```

**新系統：**
```dart
// 唯一方式：NotificationScheduler
final scheduler = ref.read(notificationSchedulerProvider);
await scheduler.schedule(
  ref: ref,
  days: 3,
  source: 'source_name',  // 用於診斷
  immediate: false,       // 是否跳過節流
);
```

#### 查詢進度狀態

**舊系統：**
```dart
// 方式 1：從 Firestore 讀取
final savedMap = await ref.read(savedItemsProvider.future);
final isLearned = savedMap[contentId]?.learned ?? false;

// 方式 2：從 NotificationInboxStore 讀取
final opened = await NotificationInboxStore.loadOpenedGlobal(uid);
final isOpened = opened.containsKey(contentId);
```

**新系統：**
```dart
// 唯一方式：ProgressService（合併 Firestore + local queue）
final progressService = ProgressService();
final merged = await progressService.getMergedProgress(
  uid: uid,
  contentId: contentId,
);

print('State: ${merged?.state}');
print('Should exclude: ${merged?.shouldExclude}');
```

批量查詢（排程用）：
```dart
final progressService = ProgressService();
final mergedBatch = await progressService.getMergedProgressBatch(
  uid: uid,
  contentIds: ['content1', 'content2', ...],
);

for (final entry in mergedBatch.entries) {
  print('${entry.key}: ${entry.value.state}');
}
```

## 需要修改的檔案

### 1. UI 層（按鈕點擊）

**需修改的檔案：**
- `lib/bubble_library/ui/detail_page.dart`
- `lib/bubble_library/ui/bubble_library_page.dart`
- `lib/ui/rich_sections/*.dart`

**修改範例：**

**舊代碼：**
```dart
// ❌ 直接寫 Firestore
await libraryRepo.setSavedItem(uid, contentId, {'learned': true});

// ❌ 或使用 LearningProgressService
await progress.markLearnedAndAdvance(...);
```

**新代碼：**
```dart
// ✅ 使用 NotificationActionHandler
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

// ✅ 觸發重新排程
final scheduler = ref.read(notificationSchedulerProvider);
await scheduler.schedule(
  ref: ref,
  days: 3,
  source: 'detail_page_learned_button',
);
```

### 2. 推播中心（排程觸發）

**需修改的檔案：**
- `lib/bubble_library/ui/push_center_page.dart`
- `lib/bubble_library/ui/push_product_config_page.dart`

**修改範例：**

**舊代碼：**
```dart
// ❌ 使用 PushOrchestrator
await PushOrchestrator.rescheduleNextDays(ref: ref, days: 3);
```

**新代碼：**
```dart
// ✅ 使用 NotificationScheduler
final scheduler = ref.read(notificationSchedulerProvider);
await scheduler.schedule(
  ref: ref,
  days: 3,
  source: 'push_center_settings_changed',
);
```

### 3. 通知回調（已自動處理）

**已修改的檔案：**
- `lib/bubble_library/bootstrapper.dart`
- `lib/notifications/notification_bootstrapper.dart`
- `lib/bubble_library/notifications/notification_service.dart`

這些檔案已經更新為使用新架構，**不需要額外修改**。

## 資料遷移

### Firestore 資料遷移

如果需要將舊資料遷移到新的 `progress` 集合，可以使用以下 Cloud Function：

```javascript
const functions = require('firebase-functions');
const admin = require('firebase-admin');

exports.migrateToProgress = functions.https.onRequest(async (req, res) => {
  const db = admin.firestore();
  const usersSnapshot = await db.collection('users').get();
  
  let migratedCount = 0;
  
  for (const userDoc of usersSnapshot.docs) {
    const uid = userDoc.id;
    
    // 遷移 saved_items
    const savedItemsSnapshot = await db
      .collection('users')
      .doc(uid)
      .collection('saved_items')
      .get();
    
    for (const itemDoc of savedItemsSnapshot.docs) {
      const contentId = itemDoc.id;
      const data = itemDoc.data();
      
      let state = 'queued';
      let learnedAt = null;
      let openedAt = null;
      
      if (data.learned) {
        state = 'learned';
        learnedAt = data.learnedAt || admin.firestore.FieldValue.serverTimestamp();
      }
      
      await db
        .collection('users')
        .doc(uid)
        .collection('progress')
        .doc(contentId)
        .set({
          contentId: contentId,
          topicId: data.topicId || '',
          productId: data.productId || '',
          state: state,
          pushOrder: data.pushOrder || null,
          learnedAt: learnedAt,
          openedAt: openedAt,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        }, { merge: true });
      
      migratedCount++;
    }
  }
  
  res.json({ success: true, migratedCount });
});
```

### SharedPreferences 清理

舊的 SharedPreferences 資料會自動被新系統忽略，無需手動清理。如果需要清理：

```dart
final sp = await SharedPreferences.getInstance();

// 清理舊的 notification inbox 資料
for (var key in sp.getKeys()) {
  if (key.startsWith('notification_inbox_')) {
    await sp.remove(key);
  }
}
```

## 測試計畫

### 1. 單元測試

```dart
void main() {
  group('ProgressService', () {
    test('markLearned should write to local queue', () async {
      final service = ProgressService();
      await service.markLearned(
        uid: 'test_uid',
        contentId: 'content1',
        topicId: 'topic1',
        productId: 'product1',
      );
      
      final merged = await service.getMergedProgress(
        uid: 'test_uid',
        contentId: 'content1',
      );
      
      expect(merged?.state, ProgressState.learned);
    });
    
    test('getMergedProgress should prioritize local queue', () async {
      // TODO: 實現測試
    });
  });
}
```

### 2. 整合測試

1. **標記為已學會**：
   - [ ] 按下「完成」按鈕
   - [ ] 檢查 UI 立即更新
   - [ ] 檢查 Firestore 最終同步（可能需要等待）
   - [ ] 檢查下次排程不包含該內容

2. **滑掉通知**：
   - [ ] 滑掉橫幅通知
   - [ ] 檢查狀態變為 dismissed
   - [ ] 檢查立即重新排程
   - [ ] 檢查下次不推同一則

3. **離線操作**：
   - [ ] 關閉網路
   - [ ] 完成多則學習
   - [ ] 恢復網路
   - [ ] 檢查所有操作最終同步到 Firestore

4. **App 生命週期**：
   - [ ] App 進入背景
   - [ ] 在背景滑掉通知
   - [ ] App 恢復前景
   - [ ] 檢查狀態正確同步

### 3. 效能測試

1. **批量操作**：
   - [ ] 一次標記 100 則為已學會
   - [ ] 檢查 UI 響應時間
   - [ ] 檢查 Firestore 寫入次數（應該批量寫入）

2. **排程效能**：
   - [ ] 重複觸發排程（短時間內）
   - [ ] 檢查是否正確節流
   - [ ] 檢查通知數量沒有爆炸

## 回滾計畫

如果新系統出現嚴重問題，可以暫時回滾：

1. **Git 回滾**：
   ```bash
   git revert <commit_hash>
   ```

2. **Firestore 規則回滾**：
   - 移除 `users/{userId}/progress` 規則
   - 恢復舊的 `topicProgress` 和 `contentState` 規則

3. **清理本地 queue**：
   ```dart
   final progressService = ProgressService();
   await progressService.clearQueue();
   ```

## 常見問題

### Q: 遷移後舊的 saved_items 資料怎麼辦？
**A:** 舊資料會保留在 Firestore，新系統向後兼容。排程時會同時檢查 `progress` 和 `saved_items`。

### Q: 如何確保 local queue 最終被同步？
**A:** 
1. 每次寫入 queue 後立即觸發背景同步
2. 每 5 分鐘定期同步
3. App 恢復前景時強制同步
4. 失敗的項目會保留在 queue 中重試

### Q: 多裝置同時操作會衝突嗎？
**A:** 目前版本使用 "last write wins" 策略。未來版本可考慮：
1. 使用 Firestore Timestamp 判斷
2. 合併策略（learned > opened > queued）

### Q: 如何診斷排程問題？
**A:** 
1. 檢查 `source` 參數（每次排程會記錄來源）
2. 使用 `getMergedProgressBatch()` 檢查合併後的狀態
3. 檢查 Firestore 的 `progress` 集合
4. 檢查 SharedPreferences 的 `local_action_queue_v1`

## 下一步

1. ✅ 完成核心架構重構
2. ⏳ 更新 UI 層所有寫入點
3. ⏳ 實施資料遷移（Firestore + SharedPreferences）
4. ⏳ 撰寫單元測試
5. ⏳ 執行整合測試
6. ⏳ 效能測試與優化
7. ⏳ 部署到生產環境

## 相關文件

- [通知與進度系統架構文件](./NOTIFICATION_ARCHITECTURE.md)
- [Firestore 安全規則](./firestore.rules)
- [API 文件](./API_DOCUMENTATION.md)（待建立）
