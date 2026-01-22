# 📊 資料架構設計文檔

本文檔明確區分 Firestore（雲端同步）與本地儲存（SharedPreferences）的使用場景。

---

## 🔥 **Firestore 資料（雲端，多設備同步）**

### **使用原則**
- ✅ 需要跨設備同步的資料
- ✅ 用戶的核心資料（學習進度、設定、收藏等）
- ✅ 需要持久化且不依賴單一設備的資料

### **資料類別**

#### **1. 內容資料（只讀，由管理後台上傳）**
- `products/{productId}` - 產品資訊
- `content_items/{itemId}` - 內容項目
- `topics/{topicId}` - 主題
- `featured_lists/{listId}` - 精選清單
- `ui/segments_v1` - UI 區段配置

#### **2. 用戶資料（讀寫，每個用戶獨立）**
- `users/{uid}/library_products/{productId}` - 用戶產品庫
  - `productId`, `purchasedAt`, `isFavorite`, `isHidden`
  - `pushEnabled`, `pushConfig`, `progress` (nextSeq, learnedCount)
  - `lastOpenedAt`
- `users/{uid}/wishlist/{productId}` - 願望清單 ✅ **已統一使用 Firestore**
  - `productId`, `addedAt`, `isFavorite`
- `users/{uid}/saved_items/{contentItemId}` - 已儲存內容
  - `learned`, `favorite`, `reviewLater` 等狀態
- `users/{uid}/push_settings/global` - 全域推播設定 ✅ **已統一使用 Firestore**
  - `enabled`, `dailyTotalCap`, `styleMode`, `quietHours`, `daysOfWeek`
- `users/{uid}/topicProgress/{topicId}` - 主題進度（LearningProgressService）
  - `nextPushOrder`, `lastLearned`
- `users/{uid}/contentState/{contentId}` - 內容狀態（LearningProgressService）
  - `status` (learned/snoozed), `learnedAt`, `snoozeUntil`

---

## 💾 **本地資料（SharedPreferences，單設備）**

### **使用原則**
- ✅ 設備特定的資料（如本地通知排程）
- ✅ 臨時快取（用於效能優化）
- ✅ 不需要同步的偏好設定
- ✅ 本機操作狀態（如跳過清單）

### **資料類別**

#### **1. 推播相關（本機操作）**
- `daily_routine_v1_{uid}` - 日常順序（產品優先順序）
  - **理由**：本機操作順序，不需要跨設備同步
  - `orderedProductIds`, `updatedAtMs`
- `skip_next_global_{uid}` - 全域跳過清單
  - **理由**：臨時操作，reschedule 時消耗
  - `[contentItemId, ...]`
- `skip_next_scoped_{uid}_{productId}` - 商品範圍跳過清單
  - **理由**：臨時操作，reschedule 時消耗
  - `[contentItemId, ...]`
- `scheduled_push_cache_v1` - 排程快取（未來 3 天）
  - **理由**：本機通知排程快取，每個設備的排程可能不同
  - `[{when, title, body, payload}, ...]`
- `inbox_opened_{uid}` - 收件匣已讀（全域）
  - **理由**：本機已讀狀態，快速查詢
  - `{contentItemId: openedAtMs, ...}`
- `inbox_opened_{uid}_{productId}` - 收件匣已讀（商品範圍）
  - **理由**：本機已讀狀態，快速查詢
  - `{contentItemId: openedAtMs, ...}`
- `inbox_scheduled_{uid}` - 收件匣排程項目
  - **理由**：本機通知排程，與 `scheduled_push_cache_v1` 同步
  - `[InboxItem, ...]`
- `inbox_missed_{uid}` - 收件匣錯過項目
  - **理由**：本機通知狀態，快速查詢
  - `[InboxItem, ...]`

#### **2. 用戶狀態與偏好（本機）**
- `learned_v1:{productId}:{YYYYMMDD}` - 每日學習記錄（產品範圍）
  - **理由**：本機統計，用於快速查詢
  - `bool` (true = 已學)
- `learned_global_v1:{YYYYMMDD}` - 每日學習記錄（全域）
  - **理由**：本機統計，用於快速查詢
  - `bool` (true = 已學)
- `learn_days_{uidOrLocal}` - 學習日誌
  - **理由**：本機統計，用於快速查詢
  - `[YYYY-MM-DD, ...]`
- `me_interest_tags_{uidOrLocal}` - 興趣標籤
  - **理由**：本機偏好，不需要同步
  - `[tag, ...]`
- `me_custom_interest_tags_{uidOrLocal}` - 自訂標籤
  - **理由**：本機偏好，不需要同步
  - `[tag, ...]`
- `recent_searches_v1` - 搜尋歷史
  - **理由**：本機偏好，不需要同步
  - `[query, ...]`
- `last_view_topic_id_v1` / `last_view_day_v1` / `last_view_title_v1` - 繼續學習
  - **理由**：本機狀態，不需要同步
- `today_key_v1` / `learned_today_v1` - 今日進度
  - **理由**：本機統計，用於快速查詢
- `lb_coming_soon_remind_{uid}` - Coming Soon 提醒
  - **理由**：本機提醒設定，不需要同步
  - `{productId: remindAtMs, ...}`
- `app_theme_id` - 主題設定
  - **理由**：本機 UI 偏好，不需要同步

---

## 🔄 **資料同步策略**

### **已實現的同步機制**

#### **1. 推播排程同步**
- `ScheduledPushCache` 與 `NotificationInboxStore` 在 `push_orchestrator.dart` 中同步更新
- 確保兩個快取保持一致

#### **2. 學習進度統一入口**
- 優先使用 `LearningProgressService`（需要 `topicId` 和 `pushOrder`）
- UI 操作使用 `setSavedItem` 作為降級方案（簡單快速）

---

## 📋 **未來優化建議**

### **可考慮遷移到 Firestore 的資料**

#### **1. 收件匣（NotificationInboxStore）**
- **現狀**：本地儲存
- **建議**：如果用戶需要在多設備上查看收件匣，可考慮遷移到 Firestore
- **權衡**：
  - ✅ 優點：多設備同步，資料不丟失
  - ❌ 缺點：增加 Firestore 讀寫成本，需要處理離線情況

#### **2. 學習統計（UserLearningStore）**
- **現狀**：本地儲存（每日學習記錄、學習日誌）
- **建議**：如果需要跨設備查看學習統計，可考慮遷移到 Firestore
- **權衡**：
  - ✅ 優點：多設備同步，統計更準確
  - ❌ 缺點：增加 Firestore 讀寫成本

### **應保持本地的資料**

#### **1. 排程快取（ScheduledPushCache）**
- **理由**：每個設備的本地通知排程可能不同（時區、設備狀態等）
- **建議**：保持本地，但與 `NotificationInboxStore` 同步

#### **2. 跳過清單（SkipNextStore）**
- **理由**：臨時操作，reschedule 時消耗
- **建議**：保持本地

#### **3. 日常順序（DailyRoutineStore）**
- **理由**：本機操作順序，不需要跨設備同步
- **建議**：保持本地

#### **4. UI 偏好（主題、搜尋歷史等）**
- **理由**：設備特定的偏好設定
- **建議**：保持本地

---

## ✅ **已修復的問題**

### **優先級 1：資料重複與不同步**
1. ✅ **願望清單**：統一使用 Firestore，移除本地 `WishlistStore`
2. ✅ **勿擾時段**：統一使用 Firestore 全域設定，移除本地 `dnd_start_min_v1`
3. ✅ **學習狀態**：統一使用 `LearningProgressService`，避免在 `saved_items` 重複記錄

### **優先級 2：資料同步**
1. ✅ **推播排程**：確保 `ScheduledPushCache` 與 `NotificationInboxStore` 同步更新
2. ✅ **學習進度**：統一進度更新入口，避免多處寫入

---

## 📝 **使用指南**

### **何時使用 Firestore**
- 用戶的核心資料（學習進度、設定、收藏）
- 需要跨設備同步的資料
- 需要持久化且不依賴單一設備的資料

### **何時使用本地儲存**
- 設備特定的資料（本地通知排程）
- 臨時快取（用於效能優化）
- 不需要同步的偏好設定
- 本機操作狀態（如跳過清單）

---

## 🔍 **檢查清單**

在新增資料儲存時，請考慮：

- [ ] 這份資料需要跨設備同步嗎？
- [ ] 這份資料是臨時快取還是持久化資料？
- [ ] 這份資料是設備特定的還是用戶特定的？
- [ ] 這份資料的讀寫頻率如何？（影響 Firestore 成本）

---

**最後更新**：2024年（修復優先級 1 和 2 後）
