# ProgressService 使用指南

## 🎯 核心概念

`ProgressService` 是用戶學習進度管理的**唯一入口**。所有狀態變更（已學會、延後、開啟、滑掉）都必須通過此服務。

## 📦 架構

```
UI 操作
  ↓
ProgressService.markXXX()
  ↓
本地 Queue（立即生效，UI 立刻看到變化）
  ↓
背景同步到 Firestore（網絡失敗時自動重試）
```

## 🚀 快速開始

### 1. 在 Riverpod 中使用

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

class MyWidget extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progressService = ref.read(progressServiceProvider);
    
    return ElevatedButton(
      onPressed: () async {
        await progressService.markLearned(
          uid: ref.read(uidProvider),
          contentId: 'ai_l1_a0001',
          topicId: 'topic_123',
          productId: 'product_ai_l1',
          pushOrder: 5,
        );
      },
      child: Text('我學會了'),
    );
  }
}
```

### 2. 直接使用（不使用 Riverpod）

```dart
import 'package:learningbubbles/services/progress_service.dart';

final progressService = ProgressService();

await progressService.markLearned(
  uid: currentUserId,
  contentId: 'ai_l1_a0001',
  topicId: 'topic_123',
  productId: 'product_ai_l1',
  pushOrder: 5,
);
```

## 📚 API 參考

### markLearned - 標記為已學會

```dart
await progressService.markLearned(
  uid: String,           // 必填：用戶 ID
  contentId: String,     // 必填：內容項目 ID
  topicId: String,       // 必填：主題 ID
  productId: String,     // 必填：產品 ID
  pushOrder: int?,       // 可選：推播順序
);
```

**用途：** 用戶點擊「我學會了」按鈕時使用。

**行為：**
- 立即寫入本地 queue
- 背景同步到 `users/{uid}/progress/{contentId}`
- 設置 `state: 'learned'`, `learnedAt: <timestamp>`

---

### markSnoozed - 延後再學

```dart
await progressService.markSnoozed(
  uid: String,              // 必填：用戶 ID
  contentId: String,        // 必填：內容項目 ID
  topicId: String,          // 必填：主題 ID
  productId: String,        // 必填：產品 ID
  snoozedUntil: DateTime,   // 必填：延後到何時
  pushOrder: int?,          // 可選：推播順序
);
```

**用途：** 用戶點擊「稍候再學」按鈕時使用。

**行為：**
- 立即寫入本地 queue
- 背景同步到 `users/{uid}/progress/{contentId}`
- 設置 `state: 'snoozed'`, `snoozedUntil: <timestamp>`

---

### markOpened - 標記為已開啟

```dart
await progressService.markOpened(
  uid: String,           // 必填：用戶 ID
  contentId: String,     // 必填：內容項目 ID
  topicId: String,       // 必填：主題 ID
  productId: String,     // 必填：產品 ID
  pushOrder: int?,       // 可選：推播順序
);
```

**用途：** 用戶點擊通知或打開內容時使用。

**行為：**
- 立即寫入本地 queue
- 背景同步到 `users/{uid}/progress/{contentId}`
- 設置 `state: 'opened'`, `openedAt: <timestamp>`

---

### markDismissed - 標記為滑掉

```dart
await progressService.markDismissed(
  uid: String,           // 必填：用戶 ID
  contentId: String,     // 必填：內容項目 ID
  topicId: String,       // 必填：主題 ID
  productId: String,     // 必填：產品 ID
  pushOrder: int?,       // 可選：推播順序
);
```

**用途：** 用戶滑掉通知時使用。

**行為：**
- 立即寫入本地 queue
- 背景同步到 `users/{uid}/progress/{contentId}`
- 設置 `state: 'dismissed'`, `dismissedAt: <timestamp>`

---

### getMergedProgress - 獲取合併後的進度

```dart
final progress = await progressService.getMergedProgress(
  uid: String,           // 必填：用戶 ID
  contentId: String,     // 必填：內容項目 ID
);

if (progress != null) {
  print('狀態: ${progress.state}');
  print('是否已學會: ${progress.state == ProgressState.learned}');
}
```

**用途：** 查詢某個內容項目的當前狀態。

**行為：**
- 優先返回本地 queue 中的最新狀態
- 如果本地沒有，返回 Firestore 中的狀態
- 返回合併後的 `MergedProgress` 對象

---

### getMergedProgressBatch - 批量獲取進度

```dart
final progressMap = await progressService.getMergedProgressBatch(
  uid: String,                // 必填：用戶 ID
  contentIds: List<String>,   // 必填：內容項目 ID 列表
);

for (final entry in progressMap.entries) {
  print('${entry.key}: ${entry.value.state}');
}
```

**用途：** 批量查詢多個內容項目的狀態（性能優化）。

**行為：**
- 一次性讀取本地 queue 和 Firestore
- 返回 `Map<String, MergedProgress>`

---

### forceSyncNow - 強制立即同步

```dart
await progressService.forceSyncNow();
```

**用途：** 手動觸發同步（測試或特殊情況使用）。

**行為：**
- 立即嘗試同步本地 queue 中的所有未同步項目
- 同步成功的項目會被標記為 `synced: true`

---

### clearQueue - 清空本地佇列

```dart
await progressService.clearQueue();
```

**用途：** 清空本地 queue（測試或重置用）。

**⚠️ 警告：** 這會刪除所有未同步的狀態變更！

## 🎨 完整範例

### 範例 1：學習完成流程

```dart
class ContentDetailPage extends ConsumerWidget {
  final String contentId;
  final String topicId;
  final String productId;
  final int pushOrder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progressService = ref.read(progressServiceProvider);
    final uid = ref.read(uidProvider);

    return Scaffold(
      appBar: AppBar(title: Text('內容詳情')),
      body: Column(
        children: [
          // 內容展示
          Text('這是學習內容...'),
          
          // 操作按鈕
          Row(
            children: [
              ElevatedButton(
                onPressed: () async {
                  try {
                    // 標記為已學會
                    await progressService.markLearned(
                      uid: uid,
                      contentId: contentId,
                      topicId: topicId,
                      productId: productId,
                      pushOrder: pushOrder,
                    );
                    
                    // 顯示成功訊息
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('已標記為學會！')),
                    );
                    
                    // 返回上一頁
                    Navigator.of(context).pop();
                  } catch (e) {
                    // 錯誤處理
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('操作失敗：$e')),
                    );
                  }
                },
                child: Text('我學會了'),
              ),
              
              SizedBox(width: 10),
              
              ElevatedButton(
                onPressed: () async {
                  // 延後 6 小時
                  final snoozedUntil = DateTime.now().add(Duration(hours: 6));
                  
                  await progressService.markSnoozed(
                    uid: uid,
                    contentId: contentId,
                    topicId: topicId,
                    productId: productId,
                    snoozedUntil: snoozedUntil,
                    pushOrder: pushOrder,
                  );
                  
                  Navigator.of(context).pop();
                },
                child: Text('稍後再學'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
```

### 範例 2：查詢學習狀態

```dart
class LearningStatusWidget extends ConsumerWidget {
  final String contentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progressService = ref.read(progressServiceProvider);
    final uid = ref.read(uidProvider);

    return FutureBuilder<MergedProgress?>(
      future: progressService.getMergedProgress(
        uid: uid,
        contentId: contentId,
      ),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return CircularProgressIndicator();
        }
        
        final progress = snapshot.data;
        if (progress == null) {
          return Text('尚未開始學習');
        }
        
        switch (progress.state) {
          case ProgressState.learned:
            return Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green),
                Text('已學會'),
              ],
            );
          case ProgressState.snoozed:
            return Text('延後到 ${progress.snoozedUntil}');
          case ProgressState.opened:
            return Text('已開啟');
          default:
            return Text('學習中');
        }
      },
    );
  }
}
```

### 範例 3：通知動作處理

```dart
// 在通知處理器中
class MyNotificationHandler {
  final ProgressService _progressService = ProgressService();

  Future<void> handleNotificationAction({
    required String action,
    required Map<String, dynamic> payload,
  }) async {
    final uid = payload['uid'] as String;
    final contentId = payload['contentId'] as String;
    final topicId = payload['topicId'] as String;
    final productId = payload['productId'] as String;
    final pushOrder = payload['pushOrder'] as int?;

    switch (action) {
      case 'learned':
        await _progressService.markLearned(
          uid: uid,
          contentId: contentId,
          topicId: topicId,
          productId: productId,
          pushOrder: pushOrder,
        );
        break;
        
      case 'snooze':
        final snoozedUntil = DateTime.now().add(Duration(minutes: 5));
        await _progressService.markSnoozed(
          uid: uid,
          contentId: contentId,
          topicId: topicId,
          productId: productId,
          snoozedUntil: snoozedUntil,
          pushOrder: pushOrder,
        );
        break;
        
      case 'opened':
        await _progressService.markOpened(
          uid: uid,
          contentId: contentId,
          topicId: topicId,
          productId: productId,
          pushOrder: pushOrder,
        );
        break;
    }
  }
}
```

## ⚠️ 注意事項

### ❌ 不要這樣做

```dart
// ❌ 不要直接寫 Firestore
await FirebaseFirestore.instance
  .collection('users')
  .doc(uid)
  .collection('contentState')
  .doc(contentId)
  .set({'status': 'learned'});

// ❌ 不要直接寫 SharedPreferences
final prefs = await SharedPreferences.getInstance();
await prefs.setString('learned_$contentId', 'true');

// ❌ 不要使用舊的 LearningProgressService
final oldService = ref.read(learningProgressServiceProvider);
await oldService.markLearnedAndAdvance(...);
```

### ✅ 應該這樣做

```dart
// ✅ 通過 ProgressService 統一入口
final progressService = ref.read(progressServiceProvider);
await progressService.markLearned(
  uid: uid,
  contentId: contentId,
  topicId: topicId,
  productId: productId,
  pushOrder: pushOrder,
);
```

## 🔍 常見問題

### Q: 網絡失敗時狀態會丟失嗎？
**A:** 不會。狀態變更會先寫入本地 queue，背景自動同步。網絡恢復後會自動重試。

### Q: 如何知道同步是否成功？
**A:** 查看 Debug Console，成功會顯示 `✅ 已同步`，失敗會顯示 `❌ 同步失敗，保留在佇列`。

### Q: 本地 queue 會無限增長嗎？
**A:** 不會。已同步超過 7 天的記錄會自動清理。

### Q: 為什麼需要這麼多參數？
**A:** 為了確保數據完整性和可追蹤性。所有狀態變更都需要知道是哪個用戶、哪個內容、屬於哪個主題和產品。

### Q: 可以在沒有網絡的情況下使用嗎？
**A:** 可以。所有操作都會立即寫入本地 queue，網絡恢復後自動同步到 Firestore。

## 📊 狀態流轉

```
queued (排隊中)
  ↓
scheduled (已排程)
  ↓
delivered (已送達)
  ↓
opened (已開啟) ─────→ dismissed (滑掉)
  ↓
learned (已學會) or snoozed (延後)
```

## 🎉 總結

使用 `ProgressService` 的好處：
- ✅ 統一入口，代碼更清晰
- ✅ 自動同步，不用擔心網絡失敗
- ✅ 狀態可追蹤，便於調試
- ✅ 更好的錯誤處理
- ✅ 性能優化（批量查詢）

記住：**所有用戶狀態變更都要通過 ProgressService！**
