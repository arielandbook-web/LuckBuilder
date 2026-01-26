# 推播排程衝突檢查文檔

## 概述

本文檔說明推播排程系統中可能出現的衝突類型、影響和解決方法。

## 衝突類型

### 1. daysOfWeek 無交集衝突

**類型**：`daysOfWeekNoOverlap`

**嚴重程度**：ERROR

**描述**：
- 全域設定和產品層級的 `daysOfWeek` 沒有交集
- 由於使用 AND 邏輯，該產品將永遠不會推播

**範例**：
- 全域設定：{1,2,3,4,5}（週一到週五）
- 產品設定：{6,7}（週六週日）
- 結果：該產品永遠不會推播

**解決方法**：
1. 調整全域或產品的 `daysOfWeek` 設定，確保有交集
2. 或考慮修改邏輯為 OR（任一滿足即可）

**檢查位置**：`push_scheduler.dart` 第 107-110 行

---

### 2. 頻率總和超過每日上限

**類型**：`freqExceedsDailyCap`

**嚴重程度**：WARNING

**描述**：
- 所有產品的 `freqPerDay` 總和超過 `global.dailyTotalCap`
- 系統會按優先級截斷，導致部分產品的實際推播次數少於設定值

**範例**：
- 產品 A：freqPerDay = 3
- 產品 B：freqPerDay = 4
- 產品 C：freqPerDay = 3
- 總和：10
- dailyTotalCap：8
- 結果：部分產品可能只推播 1-2 次而非設定的 3-4 次

**解決方法**：
1. 增加 `dailyTotalCap`
2. 減少某些產品的 `freqPerDay`
3. 在 UI 顯示警告，讓用戶知道實際推播次數可能少於設定

**檢查位置**：`push_scheduler.dart` 第 238-299 行

---

### 3. 所有時間都在勿擾時段內

**類型**：`allTimesInQuietHours`

**嚴重程度**：WARNING

**描述**：
- 產品的所有推播時間都在 `global.quietHours` 內
- 該產品當天不會推播

**範例**：
- 產品推播時間：22:30, 23:00
- 勿擾時段：22:00-08:00
- 結果：該產品當天不會推播

**解決方法**：
1. 調整產品的推播時間，避開勿擾時段
2. 或調整全域勿擾時段設定

**檢查位置**：`push_scheduler.dart` 第 201-206 行

---

### 4. 自訂時間為空

**類型**：`customTimesEmpty`

**嚴重程度**：WARNING

**描述**：
- `timeMode` 設為 `custom` 但 `customTimes` 為空
- 系統會回退到預設時段（night）

**解決方法**：
1. 在 UI 層面確保 `timeMode=custom` 時至少有一個 `customTimes`
2. 或在保存時驗證並提示用戶

**檢查位置**：`push_scheduler.dart` 第 47-59 行

---

### 5. 最短間隔過大

**類型**：`minIntervalTooLarge`

**嚴重程度**：WARNING

**描述**：
- `minIntervalMinutes` 超過 24 小時（1440 分鐘）
- 可能導致時間計算異常

**解決方法**：
1. 將 `minIntervalMinutes` 限制在合理範圍內（建議 < 24 小時）
2. 在 UI 層面限制輸入範圍

**檢查位置**：`push_config.dart` 第 99-100 行（已有 clamp 限制）

---

### 6. SkipNextStore 阻塞所有內容

**類型**：`skipBlocksAllContent`

**嚴重程度**：WARNING

**描述**：
- SkipNextStore 中的內容包含所有未學習的內容
- 該產品在下次排程時可能無法推播

**範例**：
- 產品有 10 則內容，其中 8 則已學習
- 剩餘 2 則未學習內容都在 skip 清單中
- 結果：該產品無法推播

**解決方法**：
1. 檢查 skip 清單，移除不必要的項目
2. 或自動移除會阻塞所有內容的 skip 項目

**檢查位置**：`push_orchestrator.dart` 第 194-212 行

---

## 衝突檢查工具

### PushScheduleConflictChecker

**位置**：`lib/bubble_library/notifications/push_schedule_conflict_checker.dart`

**使用方法**：

```dart
final reports = await PushScheduleConflictChecker.checkAll(
  global: global,
  libraryByProductId: libMap,
  contentByProduct: contentByProduct,
  savedMap: savedMap,
  uid: uid,
);

if (reports.isNotEmpty) {
  print(PushScheduleConflictChecker.formatReports(reports));
}
```

**整合位置**：
- `push_orchestrator.dart` 第 135-150 行（在 reschedule 前檢查）

---

## 變數影響層級

### 全域層級 (GlobalPushSettings)
- `enabled`：總開關
- `dailyTotalCap`：每日上限
- `quietHours`：勿擾時段
- `daysOfWeek`：全域允許的星期幾

### 產品層級 (UserLibraryProduct + PushConfig)
- `isHidden`：是否隱藏
- `pushEnabled`：是否啟用推播
- `freqPerDay`：每日頻率
- `timeMode`：時間模式
- `presetSlots` / `customTimes`：推播時間
- `daysOfWeek`：產品允許的星期幾
- `minIntervalMinutes`：最短間隔

### 內容層級
- `savedMap[contentItemId].learned`：是否已學習
- `contentItem.seq`：序列號

### 本地存儲
- `DailyRoutineStore`：產品優先順序
- `SkipNextStore`：跳過清單

---

## 建議

1. **在 UI 層面驗證**：在保存設定時檢查衝突並提示用戶
2. **定期檢查**：在 reschedule 時自動檢查並記錄警告
3. **文檔化**：確保用戶了解各設定的影響
4. **自動修復**：對於某些衝突（如 customTimes 為空），可以自動回退到安全值

---

## 更新記錄

- 2026-01-23：初始版本，整理所有衝突類型和檢查方法
