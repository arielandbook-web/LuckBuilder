# Excel 圖片欄位格式規格說明

## 📋 總則

**所有圖片欄位統一使用 Firebase Storage 路徑格式**

- ✅ 使用：`StorageFile` 或 `Storage` 欄位
- ❌ 不使用：`Url` 欄位（可留空）

---

## 1. TOPICS Sheet - 主題圖片

### `bubbleStorageFile` - 氣泡圖示

**用途：** 分類頁面中顯示的主題氣泡圖示

**格式：** Firebase Storage 路徑（字串）

**路徑範例：** `images/topics/{topicId}/bubble.png`

**圖片規格：**
- **尺寸：** 512x512 px（正方形）
- **格式：** PNG（支援透明背景）
- **檔案大小：** 建議 < 100 KB
- **背景：** 透明或漸層背景
- **內容：** 主題相關的圖示或插圖
- **建議：** 使用圓形或圓角設計，符合氣泡風格

**範例：**
```
images/topics/growth/bubble.png
images/topics/finance/bubble.png
images/topics/tech/bubble.png
```

### `bubbleGradStart` - 漸層開始顏色

**用途：** 氣泡漸層效果的開始顏色

**格式：** HEX 顏色代碼（字串）

**範例：** `#FF5733` 或 `#FF6B9D`

**規格：**
- **格式：** HEX（6 位數，包含 #）
- **範例：** `#FF5733`, `#33FF57`, `#5733FF`

### `bubbleGradEnd` - 漸層結束顏色

**用途：** 氣泡漸層效果的結束顏色

**格式：** HEX 顏色代碼（字串）

**範例：** `#33FF57` 或 `#9D6BFF`

**規格：**
- **格式：** HEX（6 位數，包含 #）
- **範例：** `#33FF57`, `#9D6BFF`, `#FF9D33`
- **建議：** 與 `bubbleGradStart` 形成和諧的漸層效果

---

## 2. PRODUCTS Sheet - 產品圖片

### `coverStorageFile` - 產品封面圖

**用途：** 產品詳情頁的封面圖片

**格式：** Firebase Storage 路徑（字串）

**路徑範例：** `images/products/{productId}/cover.jpg`

**圖片規格：**
- **尺寸：** 1200x800 px（3:2 比例）
- **格式：** JPG 或 PNG
- **檔案大小：** 建議 < 300 KB
- **背景：** 可為實色或漸層
- **內容：** 產品主題相關的視覺設計
- **建議：** 使用高品質圖片，符合產品風格

**範例：**
```
images/products/growth_l1_a/cover.jpg
images/products/finance_l1_a/cover.jpg
images/products/tech_l1_a/cover.jpg
```

### `spec1Icon` - 規格 1 圖示

**用途：** 產品規格標籤的圖示（例如：時間、難度等）

**格式：** Material Icons 名稱（字串）

**範例：** `timer`, `star`, `schedule`

**規格：**
- **格式：** Material Design Icons 標準名稱
- **命名規則：** 小寫，使用底線分隔
- **常用圖示：**
  - `timer` - 時間相關
  - `star` - 評分/等級
  - `schedule` - 排程
  - `trending_up` - 成長/趨勢
  - `book` - 學習/書籍
  - `lightbulb` - 想法/創意
  - `check_circle` - 完成/確認
  - `favorite` - 收藏/喜好

**參考：** https://fonts.google.com/icons

### `spec2Icon` - 規格 2 圖示

**格式：** 同 `spec1Icon`

**常用圖示：** `schedule`, `trending_up`, `book`

### `spec3Icon` - 規格 3 圖示

**格式：** 同 `spec1Icon`

**常用圖示：** `lightbulb`, `check_circle`, `school`

### `spec4Icon` - 規格 4 圖示

**格式：** 同 `spec1Icon`

**常用圖示：** `favorite`, `bookmark`, `share`

---

## 3. CONTENT_ITEMS Sheet - 內容項目

### `storageFile` - 內容檔案

**用途：** 內容項目的檔案（PDF、圖片等）

**格式：** Firebase Storage 路徑（字串）

**路徑範例：** `content/items/{itemId}/file.pdf`

**檔案規格：**
- **格式：** PDF、PNG、JPG（根據內容類型）
- **PDF 規格：**
  - 頁面尺寸：A4 或自訂
  - 檔案大小：建議 < 5 MB
- **圖片規格：**
  - 尺寸：根據內容需求（建議最大 2000px 寬度）
  - 格式：PNG（透明）或 JPG
  - 檔案大小：建議 < 1 MB

**範例：**
```
content/items/item_001/file.pdf
content/items/item_002/card.png
content/items/item_003/image.jpg
```

---

## 📐 圖片規格總結表

| 欄位 | 用途 | 尺寸 | 格式 | 檔案大小 | 路徑格式 |
|------|------|------|------|----------|----------|
| `bubbleStorageFile` | 主題氣泡圖 | 512x512 px | PNG | < 100 KB | `images/topics/{topicId}/bubble.png` |
| `coverStorageFile` | 產品封面 | 1200x800 px | JPG/PNG | < 300 KB | `images/products/{productId}/cover.jpg` |
| `spec1Icon` ~ `spec4Icon` | 規格圖示 | - | Material Icons | - | 圖示名稱字串 |
| `storageFile` | 內容檔案 | 依內容 | PDF/PNG/JPG | < 5 MB | `content/items/{itemId}/file.*` |

---

## 🎨 設計建議

### 氣泡圖示 (bubbleStorageFile)
- 使用圓形或圓角設計
- 保持簡潔，避免過多細節
- 顏色與漸層色調和諧
- 確保在小尺寸下仍清晰可見

### 產品封面 (coverStorageFile)
- 使用高品質圖片
- 保持品牌一致性
- 文字清晰可讀（如有文字）
- 符合產品主題和風格

### 圖示 (spec1Icon ~ spec4Icon)
- 選擇語義清晰的圖示
- 保持圖示風格一致
- 避免使用過於複雜的圖示

---

## 📝 Excel 填寫範例

### TOPICS Sheet
```
topicId: growth
bubbleStorageFile: images/topics/growth/bubble.png
bubbleGradStart: #FF5733
bubbleGradEnd: #33FF57
bubbleImageUrl: (留空)
```

### PRODUCTS Sheet
```
productId: growth_l1_a
coverStorageFile: images/products/growth_l1_a/cover.jpg
spec1Icon: timer
spec2Icon: star
spec3Icon: book
spec4Icon: lightbulb
coverImageUrl: (留空)
```

### CONTENT_ITEMS Sheet
```
itemId: item_001
storageFile: content/items/item_001/file.pdf
```

---

## ⚠️ 注意事項

1. **統一使用 Storage 欄位**：所有圖片都使用 `StorageFile` 或 `Storage` 欄位，不使用 `Url` 欄位
2. **路徑格式**：使用相對路徑，不包含 `gs://` 前綴
3. **檔案命名**：使用小寫字母、數字和底線，避免特殊字符
4. **檔案大小**：注意檔案大小限制，建議壓縮圖片
5. **格式一致性**：同一類型的圖片使用相同的格式和尺寸
6. **Material Icons**：確保圖示名稱正確，參考官方文檔

---

## 🔗 參考資源

- **Material Icons：** https://fonts.google.com/icons
- **Firebase Storage 文檔：** https://firebase.google.com/docs/storage
- **圖片壓縮工具：** TinyPNG, ImageOptim, Squoosh
