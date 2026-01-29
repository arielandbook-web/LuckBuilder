# releaseAtMs 和 createdAtMs 欄位填寫指南

## 📋 快速參考

| 欄位名稱 | 類型 | 是否必填 | 說明 | 用途 |
|---------|------|---------|------|------|
| `releaseAtMs` | **整數**（13位數字） | ❌ 選填 | 產品發布時間戳（毫秒） | 用於「即將上架」功能 |
| `createdAtMs` | **整數**（13位數字） | ❌ 選填 | 產品建立時間戳（毫秒） | 用於「本週新泡泡」功能 |

---

## 🎯 什麼時候需要填寫？

### `createdAtMs`（建立時間戳）- **建議必填**

✅ **應該填寫的情況**：
- 新產品上架時
- 希望產品出現在「本週新泡泡」區塊
- 需要按建立時間排序

❌ **可以留空的情況**：
- 舊產品資料（歷史資料）
- 不需要顯示在「本週新泡泡」

### `releaseAtMs`（發布時間戳）- **可選**

✅ **應該填寫的情況**：
- 產品計劃未來發布（預告功能）
- 需要顯示在「即將上架」區塊
- 有明確的發布時間點

❌ **可以留空的情況**：
- 產品已立即發布（使用 `createdAtMs` 即可）
- 沒有特定發布時間
- 不需要「即將上架」功能

---

## 📝 如何填寫？

### 方法 1：使用 Python 計算（推薦）

```python
import time
from datetime import datetime

# ✅ 當前時間戳（毫秒）
current_ms = int(time.time() * 1000)
print(f"當前時間戳: {current_ms}")
# 輸出範例：1737907200000

# ✅ 指定日期時間戳（毫秒）
target_date = datetime(2024, 1, 26, 12, 0, 0)  # 2024-01-26 12:00:00
target_ms = int(target_date.timestamp() * 1000)
print(f"指定時間戳: {target_ms}")
# 輸出範例：1737907200000

# ✅ 從字串轉換
date_str = "2024-01-26 12:00:00"
date_obj = datetime.strptime(date_str, "%Y-%m-%d %H:%M:%S")
timestamp_ms = int(date_obj.timestamp() * 1000)
print(f"從字串轉換: {timestamp_ms}")
```

### 方法 2：使用線上工具

1. **訪問**：https://www.unixtimestamp.com/
2. **輸入日期時間**（例如：2024-01-26 12:00:00）
3. **選擇「Milliseconds」**
4. **複製結果數字**（例如：`1737907200000`）

### 方法 3：在 Excel 中直接填入數字

**重要**：直接填入**數字**，不要填入日期格式！

```
✅ 正確範例：
releaseAtMs: 1737907200000
createdAtMs: 1737907200000

❌ 錯誤範例：
releaseAtMs: 2024-01-26
createdAtMs: 2024/1/26
```

---

## 📊 Excel 填寫範例

### 範例 1：新產品立即發布

```
productId    | releaseAtMs    | createdAtMs
-------------|----------------|----------------
product_001  | 1737907200000  | 1737907200000
```

**說明**：建立時間和發布時間相同，產品立即上架。

### 範例 2：預告即將上架的產品

```
productId    | releaseAtMs    | createdAtMs
-------------|----------------|----------------
product_002  | 1738512000000  | 1737907200000
```

**說明**：
- `createdAtMs`: 2024-01-26 12:00:00（今天建立）
- `releaseAtMs`: 2024-02-02 12:00:00（下週發布）
- 產品會出現在「即將上架」區塊

### 範例 3：只有建立時間

```
productId    | releaseAtMs    | createdAtMs
-------------|----------------|----------------
product_003  |                | 1737907200000
```

**說明**：只有建立時間，沒有發布時間。產品會出現在「本週新泡泡」（如果建立時間在過去7天內）。

### 範例 4：舊產品（留空）

```
productId    | releaseAtMs    | createdAtMs
-------------|----------------|----------------
product_004  |                |
```

**說明**：舊產品資料，兩個欄位都留空。系統會使用 `order` 欄位排序。

---

## 🔢 時間戳格式說明

### 格式要求

- **類型**：整數（Integer）
- **長度**：13位數字
- **單位**：毫秒（Milliseconds）
- **基準**：1970-01-01 00:00:00 UTC（Unix 紀元）

### 時間戳對照表

| 日期時間 | 時間戳（毫秒） | 說明 |
|---------|--------------|------|
| 2024-01-01 00:00:00 UTC | `1704067200000` | 2024年元旦 |
| 2024-01-26 12:00:00 UTC | `1737907200000` | 範例時間 |
| 2024-12-31 23:59:59 UTC | `1735689599000` | 2024年最後一秒 |
| 2025-01-01 00:00:00 UTC | `1735689600000` | 2025年元旦 |

---

## ✅ 填寫檢查清單

在 Excel 中填寫時間戳前，請確認：

- [ ] 時間戳是**13位數字**（不是10位或12位）
- [ ] 時間戳是**整數**（沒有小數點）
- [ ] 直接填入**數字**（不是日期格式）
- [ ] `createdAtMs` 建議填寫（用於「本週新泡泡」）
- [ ] `releaseAtMs` 可選（只有需要「即將上架」時才填）

---

## ⚠️ 常見錯誤

### ❌ 錯誤 1：使用秒級時間戳

```python
# ❌ 錯誤：使用秒級時間戳（10位數字）
timestamp_seconds = int(time.time())  # 例如：1737907200

# ✅ 正確：使用毫秒級時間戳（13位數字）
timestamp_milliseconds = int(time.time() * 1000)  # 例如：1737907200000
```

### ❌ 錯誤 2：在 Excel 中填入日期格式

```
# ❌ 錯誤：填入日期格式
releaseAtMs: 2024-01-26
createdAtMs: 2024/1/26

# ✅ 正確：填入數字
releaseAtMs: 1737907200000
createdAtMs: 1737907200000
```

### ❌ 錯誤 3：保留小數點

```python
# ❌ 錯誤：保留小數點
timestamp = time.time() * 1000  # 例如：1737907200.123

# ✅ 正確：轉換為整數
timestamp = int(time.time() * 1000)  # 例如：1737907200000
```

---

## 🛠️ 實用工具腳本

### Python 腳本：快速計算時間戳

```python
#!/usr/bin/env python3
"""快速計算時間戳工具"""
import time
from datetime import datetime

def get_current_timestamp_ms():
    """獲取當前時間戳（毫秒）"""
    return int(time.time() * 1000)

def get_timestamp_from_date(date_str, time_str="00:00:00"):
    """從日期字串計算時間戳（毫秒）
    
    Args:
        date_str: 日期字串，格式：YYYY-MM-DD
        time_str: 時間字串，格式：HH:MM:SS
    
    Returns:
        時間戳（毫秒）
    """
    dt_str = f"{date_str} {time_str}"
    dt = datetime.strptime(dt_str, "%Y-%m-%d %H:%M:%S")
    return int(dt.timestamp() * 1000)

# 使用範例
if __name__ == "__main__":
    # 當前時間戳
    now = get_current_timestamp_ms()
    print(f"當前時間戳: {now}")
    
    # 指定日期時間戳
    ts = get_timestamp_from_date("2024-01-26", "12:00:00")
    print(f"指定時間戳: {ts}")
    
    # 驗證
    dt = datetime.fromtimestamp(ts / 1000)
    print(f"驗證日期: {dt}")
```

### Excel 公式（不推薦，但可用）

```excel
# 假設 A1 是日期時間（例如：2024-01-26 12:00:00）
# 在 B1 中輸入公式：
=(A1-DATE(1970,1,1))*86400000

# ⚠️ 注意：Excel 的日期計算可能因時區而異，建議使用 Python 或線上工具
```

---

## 🔍 驗證時間戳是否正確

### 方法 1：使用 Python 驗證

```python
from datetime import datetime

# 假設時間戳是 1737907200000
timestamp_ms = 1737907200000

# 轉換回日期時間
dt = datetime.fromtimestamp(timestamp_ms / 1000)
print(f"日期時間: {dt}")  # 應該顯示：2024-01-26 12:00:00
```

### 方法 2：使用線上工具驗證

1. 訪問：https://www.unixtimestamp.com/
2. 在「Timestamp to Human date」欄位輸入時間戳
3. 選擇「Milliseconds」
4. 查看轉換後的日期時間是否正確

---

## 💡 最佳實踐建議

### 1. 統一使用 UTC 時間

```python
from datetime import datetime, timezone

# ✅ 推薦：使用 UTC 時間
utc_now = datetime.now(timezone.utc)
utc_ms = int(utc_now.timestamp() * 1000)
```

### 2. 建立時間建議必填

- 用於「本週新泡泡」功能
- 即使沒有發布時間，也建議填寫建立時間
- 建議填寫實際建立時間，不要填寫未來時間

### 3. 發布時間可選

- 只有需要「即將上架」功能時才填寫
- 如果產品已立即發布，可以留空（使用 `createdAtMs` 即可）

### 4. 使用腳本自動化

- 建立 Python 腳本自動計算時間戳
- 避免手動計算錯誤
- 批量處理多個產品

---

## 📞 問題排查

### Q1: 填寫時間戳後，產品沒有出現在「本週新泡泡」？

**檢查步驟**：
1. ✅ 確認 `createdAtMs` 是否填寫
2. ✅ 確認時間戳是否為毫秒（13位數字）
3. ✅ 確認時間戳是否在過去7天內
4. ✅ 檢查 Firestore 中資料是否正確寫入

**驗證方法**：
```python
from datetime import datetime, timedelta

# 檢查時間戳是否在過去7天內
timestamp_ms = 1737907200000  # 您的時間戳
dt = datetime.fromtimestamp(timestamp_ms / 1000)
now = datetime.now()
seven_days_ago = now - timedelta(days=7)

if dt > seven_days_ago:
    print("✅ 時間戳在過去7天內")
else:
    print("❌ 時間戳超過7天")
```

### Q2: 填寫時間戳後，產品沒有出現在「即將上架」？

**檢查步驟**：
1. ✅ 確認 `releaseAtMs` 是否填寫
2. ✅ 確認時間戳是否為未來時間
3. ✅ 確認 `published` 是否為 `false`（未發布）

**驗證方法**：
```python
from datetime import datetime

# 檢查時間戳是否為未來時間
timestamp_ms = 1738512000000  # 您的時間戳
dt = datetime.fromtimestamp(timestamp_ms / 1000)
now = datetime.now()

if dt > now:
    print("✅ 時間戳是未來時間")
else:
    print("❌ 時間戳不是未來時間")
```

### Q3: 時間戳轉換後的日期時間不對？

**檢查步驟**：
1. ✅ 確認是否使用毫秒（不是秒）
2. ✅ 確認時區設定（建議使用 UTC）
3. ✅ 使用驗證工具檢查時間戳是否正確

---

## 📚 相關文檔

- [TIMESTAMP_GUIDE.md](./TIMESTAMP_GUIDE.md) - 詳細的時間戳說明文檔
- [EXCEL_TEMPLATE_CHANGES.md](./EXCEL_TEMPLATE_CHANGES.md) - Excel 模板變更說明

---

**最後更新**：2026-01-26  
**版本**：1.0
