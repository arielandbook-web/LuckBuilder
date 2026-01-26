# 通知系統快速參考（SSOT + Queue 架構）

## 🎯 硬規則（不可違反）

1. **內容永遠只讀 Firestore**
   - `content_items`, `products`, `topics` → 只讀

2. **Firestore 是唯一真相**
   - `users/{uid}/progress/{contentId}` → 最終狀態
   - `users/{uid}/saved_items` → 向後兼容（可選保留）

3. **SharedPreferences 只能當 cache/queue**
   - `local_action_queue_v1` → 待同步事件
   - `scheduled_push_cache_v1` → UI 顯示和去重
   - ❌ **不能當最終狀態**

4. **排程只看合併後狀態**
   - Firestore progress + local pending queue
   - 待同步的 action 視為已生效

5. **所有按鈕行為先落本地 queue**
   - 先寫 queue → 立即更新 UI → 背景補寫 Firestore

## 📋 API 速查表

### 標記為已學會
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

### 延後再學（5 分鐘）
```dart
final actionHandler = NotificationActionHandler();
await actionHandler.handleSnooze(uid: uid, payload: {...});
```

### 標記為已開啟
```dart
final actionHandler = NotificationActionHandler();
await actionHandler.handleOpened(uid: uid, payload: {...});
```

### 標記為滑掉
```dart
final actionHandler = NotificationActionHandler();
await actionHandler.handleDismissed(uid: uid, payload: {...});
```

### 排程通知（唯一入口）
```dart
final scheduler = ref.read(notificationSchedulerProvider);
await scheduler.schedule(
  ref: ref,
  days: 3,
  source: 'push_center',  // 用於診斷
  immediate: false,       // true = 跳過節流
);
```

### 查詢合併後的進度
```dart
final progressService = ProgressService();
final merged = await progressService.getMergedProgress(
  uid: uid,
  contentId: contentId,
);

print('State: ${merged?.state}');
print('Should exclude: ${merged?.shouldExclude}');
```

### 批量查詢（排程用）
```dart
final progressService = ProgressService();
final mergedBatch = await progressService.getMergedProgressBatch(
  uid: uid,
  contentIds: ['content1', 'content2', ...],
);
```

### 強制同步（測試用）
```dart
final progressService = ProgressService();
await progressService.forceSyncNow();
```

## 🚫 禁止的寫法

### ❌ 直接寫 Firestore
```dart
// ❌ 不要這樣做
await libraryRepo.setSavedItem(uid, contentId, {'learned': true});
```

### ❌ 直接寫 SharedPreferences
```dart
// ❌ 不要這樣做
final sp = await SharedPreferences.getInstance();
await sp.setString('some_state', 'value');
```

### ❌ 使用舊的排程 API
```dart
// ❌ 不要這樣做
await PushOrchestrator.rescheduleNextDays(ref: ref, days: 3);
```

### ❌ 使用舊的進度服務
```dart
// ❌ 不要這樣做
await progress.markLearnedAndAdvance(...);
```

### ❌ 使用 NotificationInboxStore
```dart
// ❌ 不要這樣做（已移除）
await NotificationInboxStore.markOpened(...);
await NotificationInboxStore.markMissedByContentItemId(...);
```

## 🔄 完整流程範例

### 按下「完成」按鈕
```dart
// 1. 標記為已學會
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

// 2. 重新排程（避免下次推同一則）
final scheduler = ref.read(notificationSchedulerProvider);
await scheduler.schedule(
  ref: ref,
  days: 3,
  source: 'detail_page_learned_button',
);

// 3. UI 自動刷新（透過 Riverpod provider invalidation）
```

### 推播設定變更後
```dart
// 1. 儲存設定（使用既有的 repo）
await pushRepo.saveSetting(...);

// 2. 立即重新排程
final scheduler = ref.read(notificationSchedulerProvider);
await scheduler.schedule(
  ref: ref,
  days: 3,
  source: 'push_center_settings_changed',
  immediate: true,  // 跳過節流
);
```

### 滑掉通知
```dart
// 已自動處理，不需要手動調用
// NotificationService 會自動：
// 1. 調用 handleDismissed()
// 2. 觸發 onReschedule 回調
// 3. 刷新 UI
```

## 🐛 除錯指令

### 檢查 local queue 狀態
```dart
// 在開發模式下，讀取 SharedPreferences
final sp = await SharedPreferences.getInstance();
final queueJson = sp.getString('local_action_queue_v1');
print('Local queue: $queueJson');
```

### 檢查 Firestore progress
```dart
// 在 Firebase Console 查看：
// users/{uid}/progress/{contentId}
```

### 檢查排程快取
```dart
final cache = ScheduledPushCache();
final all = await cache.loadAll();
print('Scheduled: ${all.length} notifications');
```

### 檢查合併後的狀態
```dart
final progressService = ProgressService();
final merged = await progressService.getMergedProgress(
  uid: uid,
  contentId: contentId,
);
print('State: ${merged?.state}');
print('Should exclude: ${merged?.shouldExclude}');
```

## 📊 狀態優先順序

### 合併狀態規則
```
local queue (未同步) > Firestore progress > 預設值
```

### 排除規則
```dart
shouldExclude = 
  state == learned ||
  state == dismissed ||
  state == expired ||
  (state == snoozed && snoozedUntil > now)
```

### 狀態流轉
```
queued → scheduled → delivered → opened → learned
                              ↓
                          dismissed
                              ↓
                          expired
                              ↓
                          snoozed
```

## ⚡ 效能要點

1. **節流**：排程預設 3 秒節流，避免短時間內重複排程
2. **批量查詢**：使用 `getMergedProgressBatch()` 而非逐一查詢
3. **快取**：Riverpod provider 和 local cache 減少重複計算
4. **背景同步**：寫入 queue 後立即返回，不等待 Firestore 完成

## 📚 相關文件

- [完整架構文件](./NOTIFICATION_ARCHITECTURE.md)
- [遷移指南](./MIGRATION_GUIDE.md)
- [重構總結](./REFACTORING_SUMMARY.md)
- [Firestore 規則](./firestore.rules)

## 🎨 一句話總結

> **Firestore 是成績單，SharedPreferences 是草稿 + 待寄出的郵件。**

---

**記住：** 所有狀態變更必須通過 `ProgressService` 或 `NotificationActionHandler`，所有排程必須通過 `NotificationScheduler`！
