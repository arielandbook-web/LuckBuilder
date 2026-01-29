# Excel 模板欄位變更說明

## 📊 欄位統計

### 總覽
- **UI_SEGMENTS**: 6 個欄位（5 必要 + 1 選填）
- **TOPICS**: 9 個欄位（4 必要 + 5 選填）
- **PRODUCTS**: 32 個欄位（3 必要 + 29 選填，**含 2 個新增欄位**）
- **FEATURED_LISTS**: 4 個欄位（4 必要）
- **CONTENT_ITEMS**: 22 個欄位（2 必要 + 20 選填）

---

## ⭐ 新增欄位

### PRODUCTS 工作表

#### 1. `releaseAtMs` ⭐ 新增
- **類型**: 整數（毫秒時間戳）
- **說明**: 產品發布時間戳（毫秒），用於排序和顯示「本週新泡泡」
- **是否必要**: 否（選填）
- **預設值**: `None`
- **計算方式**: 
  ```python
  import time
  release_at_ms = int(time.time() * 1000)
  # 或
  from datetime import datetime
  release_at_ms = int(datetime.now().timestamp() * 1000)
  ```
- **用途**: 
  - 在首頁「本週新泡泡」區塊中，用於判斷產品是否為新上架
  - 用於產品排序（有 `releaseAtMs` 的按 `releaseAtMs` 排序，否則按 `order` 排序）

#### 2. `createdAtMs` ⭐ 新增
- **類型**: 整數（毫秒時間戳）
- **說明**: 產品建立時間戳（毫秒），用於排序和顯示「本週新泡泡」
- **是否必要**: 否（選填）
- **預設值**: `None`
- **計算方式**: 同 `releaseAtMs`
- **用途**: 
  - 在首頁「本週新泡泡」區塊中，用於判斷產品是否為新上架
  - 用於產品排序（有 `createdAtMs` 的按 `createdAtMs` 排序）

---

## 📋 完整欄位清單

### UI_SEGMENTS (6 欄位)
| 欄位名稱 | 類型 | 必要 | 說明 |
|---------|------|------|------|
| segmentId | 文字 | ⭐ | 區段 ID（唯一識別碼） |
| title | 文字 | ⭐ | 區段標題 |
| order | 數字 | ⭐ | 排序順序（越小越前面） |
| mode | 文字 | ⭐ | 模式（如：library, featured） |
| published | 布林 | ⭐ | 是否發布（true/false） |
| tag | 文字 | 選填 | 標籤 |

### TOPICS (9 欄位)
| 欄位名稱 | 類型 | 必要 | 說明 |
|---------|------|------|------|
| topicId | 文字 | ⭐ | 主題 ID（唯一識別碼） |
| title | 文字 | ⭐ | 主題標題 |
| published | 布林 | ⭐ | 是否發布（true/false） |
| order | 數字 | ⭐ | 排序順序（越小越前面） |
| tags | 文字 | 選填 | 標籤（多個用分號 ; 分隔） |
| bubbleImageUrl | 文字 | 選填 | 泡泡圖片 URL |
| bubbleStorageFile | 文字 | 選填 | 泡泡圖片儲存檔案路徑 |
| bubbleGradStart | 文字 | 選填 | 漸層起始顏色 |
| bubbleGradEnd | 文字 | 選填 | 漸層結束顏色 |

### PRODUCTS (32 欄位)
| 欄位名稱 | 類型 | 必要 | 說明 |
|---------|------|------|------|
| productId | 文字 | ⭐ | 產品 ID（唯一識別碼） |
| topicId | 文字 | ⭐ | 所屬主題 ID |
| level | 文字 | ⭐ | 等級（如：L1, L2） |
| title | 文字 | 選填 | 產品標題（留空則自動生成：topicId + level） |
| titleLower | 文字 | 選填 | 產品標題小寫（留空則自動生成） |
| order | 數字 | 選填 | 排序順序（預設 0） |
| type | 文字 | 選填 | 產品類型 |
| published | 布林 | 選填 | 是否發布（預設 true） |
| levelGoal | 文字 | 選填 | 等級目標描述 |
| levelBenefit | 文字 | 選填 | 等級效益描述 |
| anchorGroup | 文字 | 選填 | 錨點群組 |
| version | 文字 | 選填 | 版本號 |
| coverImageUrl | 文字 | 選填 | 封面圖片 URL |
| coverStorageFile | 文字 | 選填 | 封面圖片儲存檔案路徑 |
| itemCount | 數字 | 選填 | 內容項目數量 |
| wordCountAvg | 數字 | 選填 | 平均字數 |
| pushStrategy | 文字 | 選填 | 推播策略（如：seq） |
| sourceType | 文字 | 選填 | 來源類型 |
| source | 文字 | 選填 | 來源 |
| sourceUrl | 文字 | 選填 | 來源 URL |
| spec1Label | 文字 | 選填 | 規格 1 標籤 |
| spec2Label | 文字 | 選填 | 規格 2 標籤 |
| spec3Label | 文字 | 選填 | 規格 3 標籤 |
| spec4Label | 文字 | 選填 | 規格 4 標籤 |
| spec1Icon | 文字 | 選填 | 規格 1 圖示 |
| spec2Icon | 文字 | 選填 | 規格 2 圖示 |
| spec3Icon | 文字 | 選填 | 規格 3 圖示 |
| spec4Icon | 文字 | 選填 | 規格 4 圖示 |
| trialMode | 文字 | 選填 | 試用模式（如：previewFlag） |
| trialLimit | 數字 | 選填 | 試用限制數量（預設 3） |
| **releaseAtMs** | **數字** | **選填** | **⭐ 新增：發布時間戳（毫秒）** |
| **createdAtMs** | **數字** | **選填** | **⭐ 新增：建立時間戳（毫秒）** |

### FEATURED_LISTS (4 欄位)
| 欄位名稱 | 類型 | 必要 | 說明 |
|---------|------|------|------|
| listId | 文字 | ⭐ | 清單 ID（唯一識別碼） |
| title | 文字 | ⭐ | 清單標題 |
| type | 文字 | ⭐ | 類型（productIds 或 topicIds） |
| ids | 文字 | ⭐ | ID 列表（多個用分號 ; 分隔） |

### CONTENT_ITEMS (22 欄位)
| 欄位名稱 | 類型 | 必要 | 說明 |
|---------|------|------|------|
| itemId | 文字 | ⭐ | 內容項目 ID（唯一識別碼） |
| productId | 文字 | ⭐ | 所屬產品 ID |
| type | 文字 | 選填 | 內容類型 |
| topicId | 文字 | 選填 | 所屬主題 ID |
| level | 文字 | 選填 | 等級 |
| levelGoal | 文字 | 選填 | 等級目標描述 |
| levelBenefit | 文字 | 選填 | 等級效益描述 |
| anchorGroup | 文字 | 選填 | 錨點群組 |
| anchor | 文字 | 選填 | 錨點 |
| intent | 文字 | 選填 | 意圖 |
| difficulty | 數字 | 選填 | 難度（1-5，預設 1） |
| content | 文字 | 選填 | 內容文字 |
| wordCount | 數字 | 選填 | 字數 |
| reusable | 布林 | 選填 | 是否可重複使用（預設 false） |
| sourceType | 文字 | 選填 | 來源類型 |
| source | 文字 | 選填 | 來源 |
| sourceUrl | 文字 | 選填 | 來源 URL |
| version | 文字 | 選填 | 版本號 |
| pushOrder | 數字 | 選填 | 推播順序（Day N） |
| storageFile | 文字 | 選填 | 儲存檔案路徑 |
| seq | 數字 | 選填 | 序列號（預設 0） |
| isPreview | 布林 | 選填 | 是否為預覽（預設 false） |

---

## 🔄 上傳腳本更新

`upload_v3_excel.py` 已更新，現在支援 `releaseAtMs` 和 `createdAtMs` 欄位：

```python
"releaseAtMs": int(r.get("releaseAtMs")) if not pd.isna(r.get("releaseAtMs")) else None,
"createdAtMs": int(r.get("createdAtMs")) if not pd.isna(r.get("createdAtMs")) else None,
```

---

## 📝 使用範例

### 填寫時間戳欄位

在 Excel 的 `PRODUCTS` 工作表中，填寫 `releaseAtMs` 和 `createdAtMs`：

```python
# Python 範例
import time
from datetime import datetime

# 方法 1: 使用 time.time()
release_at_ms = int(time.time() * 1000)  # 例如：1737907200000

# 方法 2: 使用 datetime
now = datetime.now()
release_at_ms = int(now.timestamp() * 1000)

# 方法 3: 指定日期
target_date = datetime(2024, 1, 26, 12, 0, 0)
release_at_ms = int(target_date.timestamp() * 1000)
```

在 Excel 中，可以直接填入數字，例如：
- `1737907200000` (2024-01-26 12:00:00 UTC)

---

## ✅ 檢查清單

使用新模板前，請確認：

- [ ] 已下載新的模板檔案 `learning_bubble_template_new.xlsx`
- [ ] 了解新增欄位 `releaseAtMs` 和 `createdAtMs` 的用途
- [ ] 已更新 `upload_v3_excel.py` 腳本（已自動更新）
- [ ] 測試上傳流程是否正常運作

---

## 📞 問題回報

如有任何問題，請檢查：
1. 時間戳格式是否正確（必須是毫秒，不是秒）
2. 數字是否為整數（不能有小數點）
3. 上傳腳本是否已更新到最新版本
