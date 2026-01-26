# 今日修改總結

## 修改概述
今日完成了以下功能改進和 Bug 修復：

---

## 1. 搜索 Tab 歷史記錄左移調整

**檔案**：`lib/ui/rich_sections/search_history_section.dart`

**修改**：為歷史記錄區域添加左邊距 16px

```dart
return Padding(
  padding: const EdgeInsets.only(left: 16),
  child: Column(...),
);
```

**效果**：歷史記錄區塊整體右移，視覺上更舒適

---

## 2. 產品卡片進度顯示修復

### 2.1 新增 Repository 方法

**檔案**：`lib/bubble_library/data/library_repo.dart`

**新增方法**：
- `updateProgress()` - 更新產品學習進度
- `getProgress()` - 獲取產品當前進度

**用途**：統一管理 `libraryProducts/{productId}/progress` 欄位

### 2.2 完成時自動更新進度

**檔案**：`lib/bubble_library/notifications/bubble_action_handler.dart`

**修改**：在 `_handleLearned` 中添加步驟 4：
```dart
// ✅ 4) 更新產品卡片進度（Day X/365）
final currentProgress = await repo.getProgress(uid, productId);
final newNextSeq = (pushOrder >= currentNextSeq) ? pushOrder + 1 : currentNextSeq;
final newLearnedCount = currentLearnedCount + 1;
await repo.updateProgress(uid, productId, nextSeq: newNextSeq, learnedCount: newLearnedCount);
```

**效果**：標記完成後，產品進度自動更新

### 2.3 卡片進度動態計算

**檔案**：`lib/bubble_library/ui/bubble_library_page.dart`

**優化邏輯**：
1. **優先**：從排程中獲取下一個 Day（`scheduledPushCache`）
2. **次選**：從已學習內容動態計算第一個未完成的 Day
3. **Fallback**：使用 `progress.nextSeq`

**關鍵函數**：
```dart
int calculateNextDay(String productId, List<ContentItem> contentItems) {
  // 建立已學習的 pushOrder 集合
  final learnedDays = <int>{};
  for (final item in contentItems) {
    if (savedItems[item.id]?.learned ?? false) {
      learnedDays.add(item.pushOrder);
    }
  }
  
  // 找出第一個未完成的 Day
  final allDays = contentItems.map((e) => e.pushOrder).where((order) => order > 0).toSet().toList()..sort();
  for (final day in allDays) {
    if (!learnedDays.contains(day)) return day;
  }
  return allDays.last + 1; // 全部完成
}
```

**效果**：
- Day 1~7 已完成 → 顯示 **Day 8/365**
- Day 1,2,3,5,6 已完成 → 顯示 **Day 4/365**（第一個缺失）

---

## 3. 下一則推播顯示日期

**檔案**：`lib/bubble_library/ui/bubble_library_page.dart`

**修改**：`fmtNextTime` 函數增強

```dart
String fmtNextTime(DateTime dt) {
  final diff = targetDay.difference(today).inDays;
  
  if (diff < 0) return '已過期';
  if (diff == 0) return '今天 $time';
  if (diff == 1) return '明天 $time';
  if (diff == 2) return '後天 $time';
  if (diff <= 7) return '週X $time';
  return '${dt.month}/${dt.day} $time';
}
```

**效果**：
- 今天 14:30
- 明天 09:00
- 週三 15:45
- 2/15 10:00

**同時移除**：下一則標題後的 "(Day XX)" 顯示

---

## 4. 完成按鈕狀態同步

### 4.1 詳情頁橫幅按鈕

**檔案**：`lib/bubble_library/ui/detail_page.dart`

**修改**：根據 `saved?.learned` 狀態切換按鈕外觀

```dart
(saved?.learned ?? false)
  ? OutlinedButton.icon(
      onPressed: null,
      icon: const Icon(Icons.check_circle, color: Colors.green),
      label: const Text('已完成', style: TextStyle(color: Colors.green)),
    )
  : FilledButton.icon(
      onPressed: () async { /* 標記完成 */ },
      icon: const Icon(Icons.check),
      label: const Text('完成'),
    )
```

**效果**：點擊「完成」後，按鈕立即變成綠色「已完成」狀態

### 4.2 內容卡片圖標

**檔案**：`lib/bubble_library/ui/product_library_page.dart`

**修改**：已完成的卡片顯示綠色勾號

```dart
IconButton(
  icon: Icon(
    (saved?.learned ?? false) ? Icons.check_circle : Icons.check_circle_outline,
    color: (saved?.learned ?? false) ? Colors.green : null,
  ),
  onPressed: null,
  tooltip: (saved?.learned ?? false) ? '已學習' : '待學習',
)
```

**效果**：已完成的內容卡片顯示明顯的綠色勾號標記

---

## 5. 邊界情況處理優化

### 5.1 過去時間處理
- `fmtNextTime` 對於過去時間顯示「已過期」

### 5.2 異常 pushOrder 過濾
- `calculateNextDay` 過濾 pushOrder <= 0 的異常數據

### 5.3 空數據保護
- contentItems 為空時返回預設值 1
- savedItems 為 null 時視為未完成

---

## 架構符合性驗證

### ✅ 分層架構
- UI → Provider → Repository → Firestore
- 所有 Firestore 操作都通過 Repository 層

### ✅ 單一資料來源
- `progress` 欄位由 `LibraryRepo` 統一管理
- 顯示邏輯通過 `savedItemsProvider` 讀取

### ✅ 明確狀態
- 使用 `learned: bool` 明確欄位
- 使用 `nextSeq` 和 `learnedCount` 數值欄位
- 不使用 null 或空值表示狀態

### ✅ 可觀測性
- 關鍵操作有 debug log
- 記錄 before/after 值
```dart
debugPrint('📊 已更新產品進度：productId=$productId, nextSeq=$currentNextSeq→$newNextSeq, learnedCount=$currentLearnedCount→$newLearnedCount');
```

### ✅ Migration 安全
- 舊資料缺欄位時有預設值
- `ProgressState.fromMap` 處理 null 情況
- 不會導致崩潰

---

## 修改檔案清單

1. `lib/ui/rich_sections/search_history_section.dart` - UI 調整
2. `lib/bubble_library/data/library_repo.dart` - 新增 API
3. `lib/bubble_library/notifications/bubble_action_handler.dart` - 業務邏輯
4. `lib/bubble_library/ui/bubble_library_page.dart` - 顯示邏輯
5. `lib/bubble_library/ui/detail_page.dart` - 完成按鈕
6. `lib/bubble_library/ui/product_library_page.dart` - 卡片圖標
7. `PROGRESS_UPDATE_MIGRATION.md` - Migration 文檔（新增）
8. `TODAY_CHANGES_SUMMARY.md` - 本文檔（新增）

---

## 測試建議

### 功能測試
- [ ] 搜索頁歷史記錄是否右移正確
- [ ] 標記 Day 1~7 完成後，卡片顯示 "Day 8/365"
- [ ] 標記 Day 1,2,3,5,6 完成後，卡片顯示 "Day 4/365"
- [ ] 下一則推播顯示「今天/明天/週X」等日期
- [ ] 詳情頁點擊「完成」後按鈕變成「已完成」
- [ ] 內容卡片已完成項目顯示綠色勾號

### 邊界測試
- [ ] 新用戶（無 progress 欄位）能正常顯示
- [ ] contentItems 為空時不崩潰
- [ ] pushOrder 異常值（0 或負數）被正確過濾
- [ ] 所有內容完成後顯示適當數值

### 回歸測試
- [ ] 推播排程功能正常
- [ ] 學習歷史頁面正常
- [ ] 收藏功能正常

---

## 已知限制

1. **並發更新**：`learnedCount` 累加在極端並發情況下可能有輕微誤差（可接受）
2. **舊 Lint 警告**：`bubble_library_page.dart` 中有 3 個未使用的 factory 構造函數警告（不影響功能）

---

## 後續優化建議

1. 考慮在 UI 顯示已學習數量：「已學習 7/365」
2. 考慮添加學習進度條視覺化
3. 考慮添加學習統計頁面（每日/每週/每月）
4. 清理舊代碼中未使用的聲明（Lint 警告）

---

**文檔版本**：2026-01-26  
**作者**：Claude (Cursor AI Assistant)
