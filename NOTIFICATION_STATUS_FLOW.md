# 通知狀態流程文件

## 狀態定義

### InboxStatus 枚舉
- **scheduled**: 已排程（未來）
- **missed**: 錯過（已過期但未開啟）
- **opened**: 已開啟
- **skipped**: 已跳過（保留供未來使用）

## 狀態優先順序

**opened > missed > scheduled**

1. **已開啟（opened）** 優先於所有狀態
   - 一旦標記為 opened，不會再被標記為 missed
   - upsertScheduled 時會跳過已開啟的內容

2. **錯過（missed）** 優先於 scheduled
   - 滑掉通知或過期5分鐘以上會標記為 missed
   - missed 狀態會在重排時被排除

3. **排程（scheduled）** 最低優先
   - 只有未來的時間才會被標記為 scheduled
   - 過期5分鐘以上自動轉為 missed

## 狀態轉換觸發點

### 1. scheduled → opened
**觸發條件：**
- 用戶點擊通知本體
- 用戶點擊「完成」按鈕
- 在 DetailPage 點擊「完成」

**執行流程：**
1. `NotificationInboxStore.sweepMissed(uid)` - 掃描過期通知
2. `NotificationInboxStore.markOpened(uid, productId, contentItemId)` - 標記已讀
3. `LearningProgressService.markLearnedAndAdvance()` - 更新學習進度
4. `NotificationService.cancelByContentItemId()` - 取消推播
5. `PushOrchestrator.rescheduleNextDays()` - 重排未來推播
6. `_onStatusChanged?.call()` - 刷新 UI

**位置：**
- `lib/bubble_library/notifications/notification_service.dart` - `actionLearned` 處理
- `lib/bubble_library/bootstrapper.dart` - `_handleNotificationAction()`
- `lib/bubble_library/ui/detail_page.dart` - 完成按鈕

### 2. scheduled → missed
**觸發條件：**
- 用戶滑掉通知（立即標記）
- 排程時間過期5分鐘以上（自動掃描）

**執行流程：**
1. `NotificationInboxStore.markMissedByContentItemId()` - 立即標記為 missed
2. `PushOrchestrator.rescheduleNextDays()` - 重排（排除 missed）
3. `_onStatusChanged?.call()` - 刷新 UI

**位置：**
- `lib/bubble_library/notifications/notification_service.dart` - dismiss action 處理
- `lib/notifications/notification_inbox_store.dart` - `sweepMissed()`

### 3. scheduled → skipped（稍候再學）
**觸發條件：**
- 用戶點擊「稍候再學」按鈕

**執行流程：**
1. `NotificationInboxStore.sweepMissed(uid)` - 掃描過期通知
2. `LearningProgressService.snoozeContent()` - 標記為稍後再學
3. `NotificationService.cancelByContentItemId()` 或 `SkipNextStore.addForProduct()` - 取消推播或標記跳過
4. `PushOrchestrator.rescheduleNextDays()` - 重排未來推播
5. `_onStatusChanged?.call()` - 刷新 UI

**位置：**
- `lib/bubble_library/notifications/notification_service.dart` - `actionLater` 處理
- `lib/bubble_library/bootstrapper.dart` - `_handleNotificationAction()`
- `lib/bubble_library/ui/detail_page.dart` - 稍候再學按鈕

## 自動化機制

### 1. sweepMissed 執行時機
**自動執行點：**
- `PushOrchestrator.rescheduleNextDays()` 開頭（重排前）
- `NotificationInboxStore.load()` 開頭（載入前）
- `NotificationService` 各 action 處理前

**功能：**
- 掃描所有 scheduled 項目
- 將過期5分鐘以上且未開啟的移到 missed 列表
- 使用 contentItemId 去重，避免重複標記

### 2. missed 內容排除
**機制：**
- `PushOrchestrator.rescheduleNextDays()` 載入 `loadMissedContentItemIds()`
- `PushScheduler.buildSchedule()` 接收 `missedContentItemIds` 參數
- `_pickSequentialUnlearned()` 過濾掉 missed 的 contentItemId

**效果：**
- 重排時不會再排程已錯過的內容
- 避免用戶一直收到同一則通知

### 3. opened 優先檢查
**機制：**
- 所有狀態標記前先檢查 `isOpenedGlobal()`
- `upsertScheduled()` 跳過已開啟的內容
- `markMissedByContentItemId()` 跳過已開啟的內容
- `sweepMissed()` 跳過已開啟的內容

**效果：**
- 已開啟的內容不會被錯誤標記為 missed
- 狀態穩定性高，不會出現狀態衝突

## 關鍵數據結構

### NotificationInboxStore
**儲存位置：** SharedPreferences (本地)

**鍵值：**
- `inbox_opened_<uid>` - 全域已開啟（contentItemId → openedAtMs）
- `inbox_opened_<uid>_<productId>` - 產品已開啟（contentItemId → openedAtMs）
- `inbox_scheduled_<uid>` - 排程列表（InboxItem[]）
- `inbox_missed_<uid>` - 錯過列表（InboxItem[]）

**去重機制：**
- 使用 **contentItemId** 作為唯一鍵
- 不再使用 `productId::contentItemId` 複合鍵
- 確保同一內容在不同產品間不會重複

### InboxItem 模型
```dart
class InboxItem {
  final String productId;
  final String contentItemId;      // 唯一鍵
  final int whenMs;                 // 排程時間（毫秒）
  final String title;
  final String body;
  final InboxStatus status;         // scheduled, missed, opened, skipped
}
```

## 過期時間標準

**定義：** `_missedExpirationThresholdMs = 5 * 60 * 1000` (5分鐘)

**判斷邏輯：**
```dart
static bool _isExpiredForMissed(int whenMs, int nowMs) {
  return whenMs < (nowMs - _missedExpirationThresholdMs);
}
```

**應用場景：**
- `sweepMissed()` - 自動掃描過期通知
- `upsertScheduled()` - 判斷舊排程是否需移到 missed
- `load()` - 決定項目顯示為 scheduled 或 missed

## 測試檢查點

### 1. 狀態優先順序驗證
- [ ] opened 狀態不會被 missed 覆蓋
- [ ] missed 狀態不會被新的 scheduled 覆蓋
- [ ] 同一 contentItemId 在 missed 和 scheduled 中只出現一次

### 2. 滑掉通知（Dismiss Action）
- [ ] 滑掉通知立即標記為 missed
- [ ] 如果已開啟則不標記為 missed
- [ ] 重排時排除 missed 內容

### 3. 完成按鈕（Learned Action）
- [ ] 標記為 opened
- [ ] 更新學習進度
- [ ] 取消該內容的推播
- [ ] 重排時不會再排程該內容

### 4. 稍候再學（Later Action）
- [ ] 標記為 reviewLater
- [ ] 取消當前推播或標記跳過
- [ ] 重排時延後推播時間

### 5. 自動過期處理
- [ ] 過期5分鐘以上自動移到 missed
- [ ] sweepMissed 正確執行
- [ ] missed 內容在重排時被排除

### 6. 重複標記防護
- [ ] 同一 contentItemId 不會重複在 missed 列表
- [ ] opened 檢查優先於所有操作
- [ ] 去重機制正常運作

### 7. 重排邏輯
- [ ] rescheduleNextDays 開頭執行 sweepMissed
- [ ] 載入 missedContentItemIds 並傳遞給 buildSchedule
- [ ] _pickSequentialUnlearned 正確過濾 missed 內容

### 8. UI 刷新
- [ ] _onStatusChanged 在狀態變化時被調用
- [ ] provider invalidate 正確執行
- [ ] 今日任務卡片顯示正確狀態

## 常見問題排查

### Q1: 同一則通知重複推播
**可能原因：**
- missed 內容沒有被排除
- sweepMissed 沒有執行
- contentItemId 不一致

**排查步驟：**
1. 檢查 `loadMissedContentItemIds()` 是否返回正確內容
2. 確認 `buildSchedule()` 接收到 `missedContentItemIds`
3. 驗證 `_pickSequentialUnlearned()` 過濾邏輯

### Q2: 已開啟的通知顯示為 missed
**可能原因：**
- markOpened 沒有執行
- sweepMissed 在 markOpened 之前執行
- opened 檢查不完整

**排查步驟：**
1. 確認 markOpened 執行順序（應在 sweepMissed 之後）
2. 檢查 `isOpenedGlobal()` 返回正確值
3. 驗證 `load()` 中的狀態判斷邏輯

### Q3: missed 列表不斷增長
**可能原因：**
- 清理機制沒有執行
- opened 狀態沒有正確標記

**排查步驟：**
1. 檢查 `clearMissed()` 調用時機
2. 確認 opened 的內容在 sweepMissed 時被跳過
3. 驗證去重邏輯正常運作

## 代碼位置索引

### 核心文件
- `lib/notifications/notification_inbox_store.dart` - 狀態儲存與管理
- `lib/bubble_library/notifications/notification_service.dart` - 通知服務與 action 處理
- `lib/bubble_library/notifications/push_orchestrator.dart` - 推播排程編排
- `lib/bubble_library/notifications/push_scheduler.dart` - 排程邏輯
- `lib/bubble_library/bootstrapper.dart` - 應用初始化與通知回調
- `lib/bubble_library/ui/detail_page.dart` - 內容詳情頁操作

### 關鍵方法
- `NotificationInboxStore.markOpened()` - 標記已讀
- `NotificationInboxStore.markMissedByContentItemId()` - 標記錯過
- `NotificationInboxStore.sweepMissed()` - 掃描過期
- `NotificationInboxStore.upsertScheduled()` - 更新排程
- `NotificationInboxStore.load()` - 載入所有項目
- `PushOrchestrator.rescheduleNextDays()` - 重排推播
- `PushScheduler.buildSchedule()` - 建立排程
- `PushScheduler._pickSequentialUnlearned()` - 選擇未學習內容

## 更新記錄

### 2026-01-24
- ✅ 修正 NotificationService 中狀態轉換邏輯，確保 opened 狀態優先於 missed
- ✅ 優化 NotificationInboxStore 的狀態判斷，避免重複標記
- ✅ 確保 PushOrchestrator 中 sweepMissed 執行時機正確
- ✅ 統一 bootstrapper 和 detail_page 中的狀態更新流程
- ✅ 添加 kDebugMode 和 debugPrint 支援
- ✅ 修正所有編譯錯誤
