import argparse
import pandas as pd
import firebase_admin
from firebase_admin import credentials, firestore

def split_semicolon(s):
    if pd.isna(s) or s is None: return []
    return [x.strip() for x in str(s).split(";") if x.strip()]

def none_if_nan(v):
    return None if pd.isna(v) else v

def to_bool(v):
    if isinstance(v, bool): return v
    if pd.isna(v): return False
    return str(v).strip().lower() in ("true", "1", "yes", "y")

def _parse_difficulty(v):
    """解析難度值：支援數字（1-5）或文字（easy=1, medium=2, hard=3）"""
    if pd.isna(v):
        return 1
    if isinstance(v, (int, float)):
        return int(v)
    v_str = str(v).strip().lower()
    # 文字映射
    difficulty_map = {
        "easy": 1,
        "medium": 2,
        "hard": 3,
        "very hard": 4,
        "expert": 5,
    }
    if v_str in difficulty_map:
        return difficulty_map[v_str]
    # 嘗試轉換為數字
    try:
        return int(float(v_str))
    except (ValueError, TypeError):
        return 1  # 預設值

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--key", required=True, help="service account json path")
    ap.add_argument("--excel", required=True, help="xlsx path")
    args = ap.parse_args()

    cred = credentials.Certificate(args.key)
    firebase_admin.initialize_app(cred)
    db = firestore.client()

    xlsx = args.excel

    # 1) UI_SEGMENTS -> ui/segments_v1
    # ✅ Excel 結構：第一行=英文列名，第二行=中文說明，第三行開始=數據
    seg_df = pd.read_excel(xlsx, sheet_name="UI_SEGMENTS")
    segments = []
    for idx, r in seg_df.iterrows():
        # 跳過第一行數據（中文說明行）
        if idx == 0:
            continue
        # 跳過空行或無效行
        if pd.isna(r.get("segmentId")) or pd.isna(r.get("title")):
            continue
        try:
            segments.append({
                "id": str(r["segmentId"]).strip(),
                "title": str(r["title"]).strip(),
                "order": int(r["order"]) if not pd.isna(r.get("order")) else 0,
                "mode": str(r["mode"]).strip() if not pd.isna(r.get("mode")) else "tag",
                "tag": none_if_nan(r.get("tag")),
                "published": to_bool(r["published"]),
            })
        except (ValueError, KeyError) as e:
            print(f"⚠️  跳過無效行: {e}")
            continue
    segments = [s for s in segments if s["published"]]
    segments.sort(key=lambda x: x["order"])
    # 只有在有資料時才更新，避免空值覆蓋現有資料
    if segments:
        db.collection("ui").document("segments_v1").set({"segments": segments}, merge=True)
        print(f"✅ UI_SEGMENTS: 已更新 {len(segments)} 筆區段")
    else:
        print("⏭️  UI_SEGMENTS: 工作表為空，跳過更新（保留現有資料）")

    # helper: batched writes (<=500 per batch)
    def commit_in_batches(writes, batch_size=450):
        for i in range(0, len(writes), batch_size):
            b = db.batch()
            for fn in writes[i:i+batch_size]:
                fn(b)
            b.commit()

    # 2) TOPICS -> topics/{topicId}
    # ✅ Excel 結構：第一行=英文列名，第二行=中文說明，第三行開始=數據
    topics_df = pd.read_excel(xlsx, sheet_name="TOPICS")
    topic_writes = []
    for idx, r in topics_df.iterrows():
        # 跳過第一行數據（中文說明行）
        if idx == 0:
            continue
        # 跳過空行或無效行
        if pd.isna(r.get("topicId")) or pd.isna(r.get("title")):
            continue
        try:
            tid = str(r["topicId"]).strip()
            data = {
                "title": str(r["title"]).strip(),
                "published": to_bool(r["published"]),
                "order": int(r["order"]) if not pd.isna(r.get("order")) else 0,
                "tags": split_semicolon(r.get("tags")),
                "bubbleImageUrl": none_if_nan(r.get("bubbleImageUrl")),
                "bubbleStorageFile": none_if_nan(r.get("bubbleStorageFile")),
                "bubbleGradStart": none_if_nan(r.get("bubbleGradStart")),
                "bubbleGradEnd": none_if_nan(r.get("bubbleGradEnd")),
            }
            topic_writes.append(lambda b, tid=tid, data=data: b.set(db.collection("topics").document(tid), data, merge=True))
        except (ValueError, KeyError) as e:
            print(f"⚠️  跳過無效行: {e}")
            continue
    commit_in_batches(topic_writes)
    print(f"✅ TOPICS: 已更新 {len(topic_writes)} 筆主題")

    # 3) PRODUCTS -> products/{productId}
    # ✅ Excel 結構：第一行=英文列名，第二行=中文說明，第三行開始=數據
    prod_df = pd.read_excel(xlsx, sheet_name="PRODUCTS")
    prod_writes = []
    for idx, r in prod_df.iterrows():
        # 跳過第一行數據（中文說明行）
        if idx == 0:
            continue
        # 跳過空行或無效行
        if pd.isna(r.get("productId")) or pd.isna(r.get("topicId")):
            continue
        try:
            pid = str(r["productId"]).strip()
            # 生成 title（優先使用 Excel 中的 title，否則使用 topicId + level）
            title = none_if_nan(r.get("title")) or f'{str(r["topicId"]).strip()} {str(r["level"]).strip()}'
            # 生成 titleLower（優先使用 Excel 中的 titleLower，否則從 title 自動生成小寫版本）
            title_lower = none_if_nan(r.get("titleLower"))
            if not title_lower:
                title_lower = title.lower().strip()
            # 處理 order 欄位（如果 Excel 中有就使用，沒有就設為 0）
            order_value = int(r.get("order")) if not pd.isna(r.get("order")) else 0
            
            data = {
                "type": none_if_nan(r.get("type")),
                "topicId": str(r["topicId"]).strip(),
                "level": str(r["level"]).strip(),
                "title": title,
                "titleLower": title_lower,
                "order": order_value,
                "levelGoal": none_if_nan(r.get("levelGoal")),
                "levelBenefit": none_if_nan(r.get("levelBenefit")),
                "anchorGroup": none_if_nan(r.get("anchorGroup")),
                "version": none_if_nan(r.get("version")),
                "published": to_bool(r.get("published")),
                "coverImageUrl": none_if_nan(r.get("coverImageUrl")),
                "coverStorageFile": none_if_nan(r.get("coverStorageFile")),
                "itemCount": int(r.get("itemCount")) if not pd.isna(r.get("itemCount")) else None,
                "wordCountAvg": int(r.get("wordCountAvg")) if not pd.isna(r.get("wordCountAvg")) else None,
                "pushStrategy": none_if_nan(r.get("pushStrategy")),
                "sourceType": none_if_nan(r.get("sourceType")),
                "source": none_if_nan(r.get("source")),
                "sourceUrl": none_if_nan(r.get("sourceUrl")),
                "spec1Label": none_if_nan(r.get("spec1Label")),
                "spec2Label": none_if_nan(r.get("spec2Label")),
                "spec3Label": none_if_nan(r.get("spec3Label")),
                "spec4Label": none_if_nan(r.get("spec4Label")),
                "spec1Icon": none_if_nan(r.get("spec1Icon")),
                "spec2Icon": none_if_nan(r.get("spec2Icon")),
                "spec3Icon": none_if_nan(r.get("spec3Icon")),
                "spec4Icon": none_if_nan(r.get("spec4Icon")),
                "trialMode": none_if_nan(r.get("trialMode")),
                "trialLimit": int(r.get("trialLimit")) if not pd.isna(r.get("trialLimit")) else 3,
                "releaseAtMs": int(r.get("releaseAtMs")) if not pd.isna(r.get("releaseAtMs")) else None,
                "createdAtMs": int(r.get("createdAtMs")) if not pd.isna(r.get("createdAtMs")) else None,
            }
            prod_writes.append(lambda b, pid=pid, data=data: b.set(db.collection("products").document(pid), data, merge=True))
        except (ValueError, KeyError) as e:
            print(f"⚠️  跳過無效行: {e}")
            continue
        except (ValueError, KeyError) as e:
            print(f"⚠️  跳過無效行: {e}")
            continue
    commit_in_batches(prod_writes)
    print(f"✅ PRODUCTS: 已更新 {len(prod_writes)} 筆產品")

    # 4) FEATURED_LISTS -> featured_lists/{listId}
    # ✅ Excel 結構：第一行=英文列名，第二行=中文說明，第三行開始=數據
    fl_df = pd.read_excel(xlsx, sheet_name="FEATURED_LISTS")
    fl_writes = []
    for idx, r in fl_df.iterrows():
        # 跳過第一行數據（中文說明行）
        if idx == 0:
            continue
        # 跳過空行或無效行
        if pd.isna(r.get("listId")) or pd.isna(r.get("title")):
            continue
        try:
            lid = str(r["listId"]).strip()
            ids = split_semicolon(r.get("ids"))
            ftype = str(r.get("type")).strip() if not pd.isna(r.get("type")) else "productIds"
            data = {
                "title": str(r["title"]).strip(),
                "published": True,
                "order": 0,
            }
            # 依 type 決定放哪個欄位
            if ftype == "productIds":
                data["productIds"] = ids
            elif ftype == "topicIds":
                data["topicIds"] = ids
            else:
                data["ids"] = ids  # 不確定就保留原始
            fl_writes.append(lambda b, lid=lid, data=data: b.set(db.collection("featured_lists").document(lid), data, merge=True))
        except (ValueError, KeyError) as e:
            print(f"⚠️  跳過無效行: {e}")
            continue
    commit_in_batches(fl_writes)
    print(f"✅ FEATURED_LISTS: 已更新 {len(fl_writes)} 筆精選清單")

    # 5) CONTENT_ITEMS -> content_items/{itemId}
    # ✅ CONTENT_ITEMS 第一行就是數據（沒有中文說明行）
    ci_df = pd.read_excel(xlsx, sheet_name="CONTENT_ITEMS")
    ci_writes = []
    for idx, r in ci_df.iterrows():
        # 跳過空行或無效行
        if pd.isna(r.get("itemId")) or pd.isna(r.get("productId")):
            continue
        try:
            iid = str(r["itemId"]).strip()
            data = {
                "productId": str(r["productId"]).strip(),
                "type": none_if_nan(r.get("type")),
                "topicId": none_if_nan(r.get("topicId")),
                "level": none_if_nan(r.get("level")),
                "levelGoal": none_if_nan(r.get("levelGoal")),
                "levelBenefit": none_if_nan(r.get("levelBenefit")),
                "anchorGroup": none_if_nan(r.get("anchorGroup")),
                "anchor": str(r.get("anchor")).strip() if not pd.isna(r.get("anchor")) else "",
                "intent": str(r.get("intent")).strip() if not pd.isna(r.get("intent")) else "",
                "difficulty": _parse_difficulty(r.get("difficulty")),
                "content": str(r.get("content")).strip() if not pd.isna(r.get("content")) else "",
                "wordCount": int(r.get("wordCount")) if not pd.isna(r.get("wordCount")) else None,
                "reusable": to_bool(r.get("reusable")),
                "sourceType": none_if_nan(r.get("sourceType")),
                "source": none_if_nan(r.get("source")),
                "sourceUrl": none_if_nan(r.get("sourceUrl")),
                "version": none_if_nan(r.get("version")),
                "pushOrder": int(r.get("pushOrder")) if not pd.isna(r.get("pushOrder")) else None,
                "storageFile": none_if_nan(r.get("storageFile")),
                "seq": int(r.get("seq")) if not pd.isna(r.get("seq")) else 0,
                "isPreview": to_bool(r.get("isPreview")),
            }
            ci_writes.append(lambda b, iid=iid, data=data: b.set(db.collection("content_items").document(iid), data, merge=True))
        except (ValueError, KeyError) as e:
            print(f"⚠️  跳過無效行: {e}")
            continue
    commit_in_batches(ci_writes)
    print(f"✅ CONTENT_ITEMS: 已更新 {len(ci_writes)} 筆內容項目")

    print("\n✅ Upload done: UI_SEGMENTS / TOPICS / PRODUCTS / FEATURED_LISTS / CONTENT_ITEMS")

if __name__ == "__main__":
    main()