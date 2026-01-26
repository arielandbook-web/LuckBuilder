# Missed 通知處理流程

## 兩種加入 Missed 的方式

### 1. 滑掉通知：立即加入 (0 秒)

**觸發時機：** 用戶主動滑掉通知

**處理邏輯：**
```dart
// lib/bubble_library/notifications/notification_service.dart:179-208

// 滑掉通知：立即標記為錯失
if (actionId != null && dismissActionIds.contains(actionId)) {
  final pid = (payload['productId'] ?? '').toString();
  final cid = (payload['contentItemId'] ?? '').toString();
  if (pid.isNotEmpty && cid.isNotEmpty) {
    // ✅ 檢查是否已經開啟過（opened 優先於 missed）
    final isOpened = await NotificationInboxStore.isOpenedGlobal(uid, cid);
    if (!isOpened) {
      // 立即標記為錯失（不等待 5 分鐘）
      await NotificationInboxStore.markMissedByContentItemId(
        uid,
        productId: pid,
        contentItemId: cid,
      );
      // ✅ 立刻重排：避免下一輪又排到同一則
      await _onReschedule?.call();
      // ✅ 刷新 UI
      _onStatusChanged?.call();
    }
  }
}
```

**關鍵方法：** `markMissedByContentItemId`
- 位置：`lib/notifications/notification_inbox_store.dart:163-237`
- 特點：立即標記，不等待 5 分鐘
- 註解：「此方法會立即標記為錯失，不等待 5 分鐘過期時間」

**設計原因：**
- 用戶滑掉表示明確不想看此內容
- 應立即排除，避免下次再排到同一則
- 立刻重新排程，確保下一則推播是新的內容

---

### 2. 自動過期：5 分鐘後加入

**觸發時機：** 通知排程時間過期 5 分鐘以上且未開啟

**判斷標準：**
```dart
// lib/notifications/notification_inbox_store.dart:244-252

/// 錯失通知的判斷標準：過期時間必須超過此值（毫秒）
static const int _missedExpirationThresholdMs = 5 * 60 * 1000; // 5分鐘

/// 判斷通知是否已過期（用於錯失判斷）
static bool _isExpiredForMissed(int whenMs, int nowMs) {
  return whenMs < (nowMs - _missedExpirationThresholdMs);
}
```

**處理邏輯：** `sweepMissed` 方法
```dart
// lib/notifications/notification_inbox_store.dart:444-502

static Future<void> sweepMissed(String uid) async {
  final now = DateTime.now().millisecondsSinceEpoch;
  final opened = await loadOpenedGlobal(uid);

  final scheduled = await _loadItems(_kScheduled(uid));
  final missed = await _loadItems(_kMissed(uid));

  // 處理 scheduled 項目
  for (final item in scheduled) {
    if (opened.containsKey(item.contentItemId)) {
      // 已開啟，不加入任何列表（opened 優先）
      continue;
    } else if (_isExpiredForMissed(item.whenMs, now)) {
      // 已過期5分鐘以上且未開啟 → 加入 missed
      newMissed.add(item);
    } else {
      // 未來 → 保留在 scheduled
      newScheduled.add(item);
    }
  }

  await _saveItems(_kScheduled(uid), newScheduled);
  await _saveItems(_kMissed(uid), newMissed);
}
```

**調用時機：** `sweepMissed` 在以下情況被調用

1. **App 啟動時**
   - `lib/notifications/notification_bootstrapper.dart:89, 104`
   - 確保過期通知被正確標記

2. **排程前**
   - `lib/bubble_library/notifications/push_orchestrator.dart:64`
   - 確保不會重新排到已過期的內容

3. **載入收件匣時**
   - `lib/notifications/notification_inbox_store.dart:263`
   - 確保顯示最新狀態

4. **通知動作處理前**
   - `lib/bubble_library/notifications/bubble_action_handler.dart:82`
   - `lib/bubble_library/notifications/notification_service.dart:123, 226`
   - `lib/bubble_library/bootstrapper.dart:288, 335`
   - 確保狀態一致

**設計原因：**
- 給用戶 5 分鐘緩衝時間，避免太快標記為錯過
- 用戶可能在忙，看到通知但未立即點擊
- 5 分鐘後仍未開啟，視為真正錯過

---

## 兩種方式對比

| 項目 | 滑掉通知 | 自動過期 |
|------|---------|---------|
| **觸發條件** | 用戶主動滑掉 | 排程時間過期 5 分鐘以上且未開啟 |
| **等待時間** | 立即（0 秒） | 5 分鐘 |
| **處理方法** | `markMissedByContentItemId` | `sweepMissed` |
| **用戶意圖** | 明確不想看 | 可能忘記或沒看到 |
| **後續動作** | 立即重新排程 | 等待下次排程時排除 |
| **設計理由** | 用戶明確拒絕，立即排除 | 給予緩衝時間，避免誤判 |

---

## 狀態優先順序

在所有處理中，都遵循以下優先順序：

```
opened > missed > scheduled
```

### 優先順序規則

1. **opened 優先於一切**
   - 已開啟的內容不會被標記為 missed
   - 已開啟的內容不會重新排程

2. **missed 優先於 scheduled**
   - 同一個 `contentItemId` 如果已在 missed，不會被新的 scheduled 覆蓋
   - 排程時會排除所有 missed 的內容

3. **scheduled 是最低優先級**
   - 只有未開啟且未錯過的內容才會顯示為 scheduled

---

## 排程排除邏輯

### 排除 missed 的流程

1. **載入 missed 列表**
```dart
// lib/bubble_library/notifications/push_orchestrator.dart:98-100

// ✅ Missed 清單（本機）：滑掉/錯過的內容，重排時應排除
final missedContentItemIds =
    await NotificationInboxStore.loadMissedContentItemIds(uid);
```

2. **過濾已開啟的內容**
```dart
// lib/notifications/notification_inbox_store.dart:510-531

static Future<Set<String>> loadMissedContentItemIds(String uid) async {
  final missed = await _loadItems(_kMissed(uid));
  final opened = await loadOpenedGlobal(uid);
  
  // ✅ 過濾掉已開啟的內容（opened 優先於 missed）
  final missedIds = <String>{};
  for (final item in missed) {
    // 如果已開啟，則不加入 missed 列表（opened 優先）
    if (!opened.containsKey(item.contentItemId)) {
      missedIds.add(item.contentItemId);
    }
  }
  
  return missedIds;
}
```

3. **排程時排除**
```dart
// lib/bubble_library/notifications/push_scheduler.dart:170-195

static (ContentItem? picked, bool isLastInProduct) _pickSequentialUnlearned({
  required List<ContentItem> itemsSorted,
  required ProgressState progress,
  required Map<String, SavedContent> savedMap,
  Set<String> missedContentItemIds = const {},
}) {
  for (int seq = progress.nextSeq; seq <= maxSeq; seq++) {
    final item = bySeq(seq);
    if (item == null) continue;
    if (savedMap[item.id]?.learned ?? false) continue;
    // ✅ 已被使用者滑掉/判定 missed 的內容：重排時排除，避免一直推同一則
    if (missedContentItemIds.contains(item.id)) continue;
    final isLast = (seq == maxSeq);
    return (item, isLast);
  }
  return (null, false);
}
```

---

## 完整流程圖

### 滑掉通知流程
```
用戶滑掉通知
    ↓
檢查是否已開啟 (opened 優先)
    ↓
否 → 立即標記為 missed (0秒)
    ↓
立即重新排程 (排除此 contentItemId)
    ↓
刷新 UI
```

### 自動過期流程
```
排程時間到期
    ↓
5 分鐘後
    ↓
sweepMissed 執行
    ↓
檢查是否已開啟 (opened 優先)
    ↓
否 → 標記為 missed
    ↓
下次排程時自動排除
```

### 下次排程選擇內容流程
```
開始排程
    ↓
載入 missedContentItemIds (已過濾 opened)
    ↓
遍歷所有內容
    ↓
過濾條件：
- learned? → 跳過
- missed? → 跳過
- opened? → 跳過
    ↓
選擇符合條件的內容
```

---

## 關鍵常數

```dart
/// 錯失通知的過期時間閾值
static const int _missedExpirationThresholdMs = 5 * 60 * 1000; // 5分鐘
```

**為什麼是 5 分鐘？**
- 給用戶合理的反應時間
- 不會太短（避免誤判）
- 不會太長（確保及時更新狀態）

---

## 測試要點

### 測試場景 1：滑掉通知
1. 收到通知
2. 用戶滑掉通知
3. ✅ 立即加入 missed
4. ✅ 下次排程不會再推此內容
5. ✅ 立即重新排程，推送新內容

### 測試場景 2：自動過期
1. 收到通知
2. 用戶不點擊，等待 5 分鐘
3. ✅ 5 分鐘後自動加入 missed
4. ✅ 下次排程不會再推此內容

### 測試場景 3：已開啟優先
1. 收到通知
2. 用戶點擊並開啟
3. 用戶滑掉或通知過期
4. ✅ 不會加入 missed（opened 優先）
5. ✅ 下次排程仍會排除（因為 learned）

### 測試場景 4：排程排除
1. 有內容在 missed 列表
2. 重新排程
3. ✅ missed 的內容不會被選入
4. ✅ 排程選擇其他未學習的內容

---

## 總結

兩種加入 missed 的方式各有其用途：

1. **滑掉通知（立即）**
   - 用戶明確拒絕
   - 立即排除，立即重排
   - 確保用戶體驗流暢

2. **自動過期（5分鐘）**
   - 用戶可能暫時忙碌
   - 給予緩衝時間
   - 避免過於激進的判斷

這樣的設計確保：
- ✅ 用戶明確不想看的內容立即排除
- ✅ 給予用戶合理的反應時間（5分鐘）
- ✅ 排程不會重複推送已錯過的內容
- ✅ 已開啟的內容永遠優先（不會誤判為 missed）
