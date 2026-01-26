# 通知與進度系統架構文件

## 架構原則：SSOT + Queue

### 核心規則

1. **Firestore 是唯一真相來源（SSOT）**
   - 所有用戶學習進度（learned, snoozed, dismissed, opened）存儲在 `users/{uid}/progress/{contentId}`
   - 所有內容資料（content_items, products, topics）永遠只讀 Firestore

2. **SharedPreferences 只做 cache/queue**
   - `local_action_queue_v1`：待同步事件佇列（learned/snooze/opened/dismissed）
   - `scheduled_push_cache`：本地排程快取（用於去重和 UI 顯示）
   - **不能**作為最終狀態儲存

3. **所有狀態變更必須通過統一入口**
   - UI 不准直接寫 Firestore / SharedPreferences
   - 必須使用 `ProgressService` 或 `NotificationActionHandler`

4. **排程只看合併後狀態**
   - Firestore progress + local pending queue
   - 待同步的 action 視為已生效（避免重複排程）

5. **寫入流程：立即生效 + 背景同步**
   - 先寫入本地 queue → 立即更新 UI → 背景補寫 Firestore

## 檔案結構

### 核心服務

#### `lib/services/progress_service.dart`
**職責：** 統一的進度管理服務（SSOT + Queue 架構）

**主要功能：**
- `markLearned()`: 標記為已學會
- `markSnoozed()`: 延後再學
- `markOpened()`: 標記為已開啟
- `markDismissed()`: 標記為滑掉
- `getMergedProgress()`: 獲取合併後的進度（Firestore + local queue）
- `getMergedProgressBatch()`: 批量獲取合併後的進度（用於排程）
- `forceSyncNow()`: 強制同步本地 queue 到 Firestore

**資料結構：**

**Firestore:** `users/{uid}/progress/{contentId}`
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
  expiredAt: Timestamp?,
  updatedAt: Timestamp
}
```

**SharedPreferences:** `local_action_queue_v1`
```dart
[
  {
    id: string,           // uuid
    contentId: string,
    action: 'learned' | 'snooze' | 'opened' | 'dismissed',
    atMs: int,           // epoch milliseconds
    payload: {
      uid: string,
      topicId: string,
      productId: string,
      pushOrder: int?,
      snoozedUntilMs: int?
    },
    synced: bool
  }
]
```

#### `lib/bubble_library/notifications/notification_action_handler.dart`
**職責：** 通知動作處理器（統一入口）

**主要功能：**
- `handleLearned()`: 處理「已學會」動作
- `handleSnooze()`: 處理「稍候再學」動作（延後 5 分鐘）
- `handleOpened()`: 處理「已開啟」動作
- `handleDismissed()`: 處理「滑掉」動作

**使用原則：**
- UI 必須透過此 handler 處理所有通知相關動作
- 所有方法都會調用 `ProgressService`，確保狀態一致

#### `lib/bubble_library/notifications/notification_scheduler.dart`
**職責：** 統一的通知排程服務（防爆炸架構）

**主要功能：**
- `schedule()`: 統一排程入口（**唯一可被外部調用的方法**）

**特性：**
- **節流**：避免短時間內重複排程（預設 3 秒）
- **去重**：同一時間不重複排程同一 contentId
- **排除**：自動排除 learned/dismissed/snoozed/expired 的內容
- **合併狀態**：從 `ProgressService.getMergedProgressBatch()` 獲取最新狀態

**參數：**
```dart
await scheduler.schedule(
  ref: ref,
  days: 3,              // 排程未來 N 天
  source: 'source_id',  // 來源標記（用於診斷）
  immediate: false,     // 是否立即執行（跳過節流）
);
```

### 啟動與生命週期管理

#### `lib/bubble_library/bootstrapper.dart`
**職責：** 主應用啟動器

**主要功能：**
- 初始化 `NotificationService`
- 配置通知 action 回調（使用 `NotificationActionHandler`）
- 啟動後排程未來 3 天

#### `lib/notifications/notification_bootstrapper.dart`
**職責：** 通知系統生命週期管理

**主要功能：**
- 配置 `NotificationService` 回調（onStatusChanged, onReschedule）
- 監聽 app 生命週期，恢復前景時強制同步 progress queue
- 定期強制同步（每 5 分鐘，確保離線操作最終被同步到 Firestore）

### 通知核心

#### `lib/bubble_library/notifications/notification_service.dart`
**職責：** 本地通知服務（Flutter Local Notifications 封裝）

**主要功能：**
- `init()`: 初始化通知系統
- `configure()`: 配置 action 回調（可多次調用）
- `schedule()`: 排程單個通知
- `cancelAll()`: 取消所有通知
- `cancelByContentItemId()`: 取消特定內容的通知

**重要事項：**
- 不再直接處理狀態變更，全部委託給 `NotificationActionHandler`
- 只負責通知的排程、取消、回調轉發

## 狀態流轉

### 1. 用戶按下「完成」按鈕

```
1. NotificationService 收到 action 回調
2. 調用 NotificationActionHandler.handleLearned()
3. ProgressService.markLearned()
   a. 寫入本地 queue
   b. 背景同步到 Firestore (users/{uid}/progress/{contentId})
4. 觸發 onReschedule 回調
5. NotificationScheduler.schedule()
   a. 讀取 Firestore progress + local queue
   b. 合併狀態，排除已學會的內容
   c. 重新排程未來 3 天
6. UI 刷新（透過 Riverpod provider invalidation）
```

### 2. 用戶滑掉通知

```
1. iOS 觸發 customDismissAction 回調
2. NotificationService 收到 dismiss action
3. 調用 NotificationActionHandler.handleDismissed()
4. ProgressService.markDismissed()
   a. 寫入本地 queue (state: dismissed)
   b. 背景同步到 Firestore
5. 立即觸發 onReschedule（避免下一輪又推同一則）
6. NotificationScheduler.schedule()
   a. 合併狀態，排除 dismissed 的內容
   b. 重新排程
```

### 3. App 從背景恢復前景

```
1. NotificationBootstrapper 監聽到 AppLifecycleState.resumed
2. 調用 ProgressService.forceSyncNow()
   a. 同步所有待處理的 local queue 到 Firestore
   b. 標記已同步的項目為 synced: true
   c. 清理已同步超過 7 天的記錄
3. 刷新所有相關 UI provider
```

### 4. 排程邏輯

```
NotificationScheduler.schedule() 執行流程：

1. 節流檢查（避免短時間內重複排程）
2. 並發檢查（避免同時執行多個排程）
3. 刷新所有相關 provider（libraryProducts, savedItems, globalPushSettings）
4. 讀取最新狀態
   - Firestore: products, topics, content_items, library, push_settings
   - Local: daily_routine, scheduled_push_cache
5. 批量獲取合併進度
   - ProgressService.getMergedProgressBatch()
   - 合併 Firestore progress + local queue
6. 建立排除集合
   - 過濾 learned/dismissed/snoozed/expired 的內容
7. 調用 PushScheduler.buildSchedule()
   - 傳入排除集合 (missedContentItemIds)
   - 產生未來 N 天的排程
8. 取消所有舊排程
9. 註冊新排程（含完成通知）
10. 刷新 UI provider
```

## 重要 Provider

### `notificationSchedulerProvider`
```dart
final notificationSchedulerProvider = Provider<NotificationScheduler>((ref) {
  return NotificationScheduler();
});
```

**使用方式：**
```dart
final scheduler = ref.read(notificationSchedulerProvider);
await scheduler.schedule(
  ref: ref,
  days: 3,
  source: 'push_center',
);
```

## Firestore 安全規則

```javascript
match /users/{userId} {
  // ... 其他集合 ...
  
  // ✅ 新增：進度管理（SSOT）
  match /progress/{contentId} {
    allow read: if request.auth != null && request.auth.uid == userId;
    
    allow create: if request.auth != null 
                  && request.auth.uid == userId
                  && request.resource.data.keys().hasAll(['contentId', 'state', 'updatedAt'])
                  && request.resource.data.contentId == contentId;
    
    allow update: if request.auth != null 
                  && request.auth.uid == userId
                  && request.resource.data.contentId == resource.data.contentId;
    
    allow delete: if request.auth != null && request.auth.uid == userId;
  }
}
```

## 除錯指令

### 檢查本地 queue 狀態
```dart
final progressService = ProgressService();
// 在開發模式下可以使用內部方法檢查 queue（需要改為 public）
```

### 強制同步
```dart
final progressService = ProgressService();
await progressService.forceSyncNow();
```

### 清空本地 queue（測試用）
```dart
final progressService = ProgressService();
await progressService.clearQueue();
```

### 檢查合併後的進度
```dart
final progressService = ProgressService();
final merged = await progressService.getMergedProgress(
  uid: uid,
  contentId: contentId,
);
print('State: ${merged?.state}');
print('Should exclude: ${merged?.shouldExclude}');
```

## 遷移指南

### 從舊系統遷移

1. **移除舊的進度管理**
   - `LearningProgressService` → `ProgressService`
   - `NotificationInboxStore` → 不再需要（合併到 `ProgressService`）

2. **更新所有寫入點**
   - 直接寫 Firestore → `ProgressService.markXXX()`
   - 直接寫 SharedPreferences → `ProgressService.markXXX()`

3. **更新排程邏輯**
   - `PushOrchestrator.rescheduleNextDays()` → `NotificationScheduler.schedule()`

4. **更新 UI**
   - 從 Firestore 讀取 → 從 `ProgressService.getMergedProgress()` 讀取

## 常見問題

### Q: 為什麼需要 local queue？
**A:** 
1. **即時回饋**：用戶按下按鈕後立即生效，不需要等待 Firestore 寫入完成
2. **離線支援**：離線時也能記錄操作，恢復網路後自動同步
3. **效能**：減少 Firestore 讀取次數，合併多個操作後批量同步

### Q: 如何確保 local queue 最終被同步到 Firestore？
**A:**
1. **背景自動同步**：每次寫入 queue 後會立即觸發背景同步
2. **定期同步**：`NotificationBootstrapper` 每 5 分鐘強制同步一次
3. **生命週期同步**：App 恢復前景時強制同步
4. **重試機制**：同步失敗的項目會保留在 queue 中，下次同步時重試

### Q: 如何處理 Firestore 與 local queue 衝突？
**A:**
- **優先順序**：local queue > Firestore
- **時間戳**：local queue 的 action 一定比 Firestore 更新
- **合併邏輯**：`getMergedProgress()` 會優先使用 local queue 中最新的 action

### Q: 為什麼排程還是會推已經 learned 的內容？
**A:** 檢查以下幾點：
1. local queue 是否有該 contentId 的 learned action？
2. Firestore 是否有該 contentId 的 progress 記錄？
3. `getMergedProgressBatch()` 是否正確合併了狀態？
4. `NotificationScheduler.schedule()` 是否正確排除了該內容？

## 性能考量

### 批量操作
- `getMergedProgressBatch()` 使用批量讀取，避免 N+1 查詢
- 排程時一次性處理所有內容，而非逐一處理

### 快取策略
- `scheduled_push_cache` 減少通知系統的查詢次數
- Riverpod provider 快取減少重複計算

### 節流控制
- `NotificationScheduler` 預設 3 秒節流，避免短時間內重複排程
- 並發控制，避免同時執行多個排程

## 未來優化方向

1. **批量同步**：合併多個 local action 為單一 Firestore 批次寫入
2. **增量同步**：只同步變更的項目，而非每次都檢查所有項目
3. **優先級隊列**：重要操作（如 learned）優先同步
4. **衝突解決**：處理多裝置同時操作的衝突情況
5. **過期清理**：自動清理 Firestore 中過期的 progress 記錄（如 30 天前的 opened 記錄）
