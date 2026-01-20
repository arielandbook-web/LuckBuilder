import argparse
import pandas as pd
import firebase_admin
from firebase_admin import credentials, firestore


def _is_nan(v) -> bool:
    try:
        return pd.isna(v)
    except Exception:
        return v is None


def as_str(v, default=None):
    if _is_nan(v):
        return default
    s = str(v).strip()
    return s if s else default


def as_int(v, default=None):
    if _is_nan(v):
        return default
    try:
        return int(v)
    except Exception:
        try:
            return int(float(v))
        except Exception:
            return default


def as_bool(v, default=False):
    if isinstance(v, bool):
        return v
    if _is_nan(v):
        return default
    s = str(v).strip().lower()
    return s in ("true", "1", "yes", "y", "t")


def split_semicolon(v):
    """Excel 常用 'a;b;c' 轉成 ['a','b','c']"""
    s = as_str(v, "")
    if not s:
        return []
    return [x.strip() for x in s.split(";") if x.strip()]


def commit_in_batches(db, write_fns, batch_size=450):
    """Firestore 一次 batch 上限 500，保守用 450"""
    for i in range(0, len(write_fns), batch_size):
        b = db.batch()
        for fn in write_fns[i:i + batch_size]:
            fn(b)
        b.commit()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--key", required=True, help="service account json path")
    ap.add_argument("--excel", required=True, help="xlsx path")
    args = ap.parse_args()

    firebase_admin.initialize_app(credentials.Certificate(args.key))
    db = firestore.client()

    xlsx = args.excel
    xls = pd.ExcelFile(xlsx)
    sheets = set(xls.sheet_names)

    print("✅ Found sheets:", xls.sheet_names)

    # -----------------------------
    # UI_SEGMENTS -> ui/segments_v1
    # -----------------------------
    if "UI_SEGMENTS" in sheets:
        seg_df = pd.read_excel(xlsx, sheet_name="UI_SEGMENTS")
        segments = []
        for _, r in seg_df.iterrows():
            segments.append({
                "id": as_str(r.get("segmentId")),
                "title": as_str(r.get("title")),
                "order": as_int(r.get("order"), 0),
                "mode": as_str(r.get("mode"), "tag"),
                "tag": as_str(r.get("tag")),
                "published": as_bool(r.get("published"), True),
            })
        segments = [s for s in segments if s.get("id") and s.get("title") and s.get("published")]
        segments.sort(key=lambda x: x.get("order", 0))

        db.collection("ui").document("segments_v1").set({"segments": segments}, merge=True)
        print(f"✅ Wrote ui/segments_v1 (segments={len(segments)})")
    else:
        print("ℹ️ No UI_SEGMENTS sheet, skip.")

    # -------------
    # TOPICS
    # -------------
    if "TOPICS" in sheets:
        topics_df = pd.read_excel(xlsx, sheet_name="TOPICS")
        writes = []
        for _, r in topics_df.iterrows():
            topic_id = as_str(r.get("topicId"))
            if not topic_id:
                continue
            data = {
                "title": as_str(r.get("title")),
                "published": as_bool(r.get("published"), True),
                "order": as_int(r.get("order"), 0),
                "tags": split_semicolon(r.get("tags")),
                "bubbleImageUrl": as_str(r.get("bubbleImageUrl")),
                "bubbleStorageFile": as_str(r.get("bubbleStorageFile")),
                "bubbleGradStart": as_str(r.get("bubbleGradStart")),
                "bubbleGradEnd": as_str(r.get("bubbleGradEnd")),
            }
            writes.append(lambda b, tid=topic_id, d=data: b.set(db.collection("topics").document(tid), d, merge=True))
        commit_in_batches(db, writes)
        print(f"✅ Wrote topics ({len(writes)})")
    else:
        print("⚠️ TOPICS sheet missing (topics will not be updated).")

    # -------------
    # PRODUCTS
    # -------------
    if "PRODUCTS" in sheets:
        prod_df = pd.read_excel(xlsx, sheet_name="PRODUCTS")
        writes = []
        for _, r in prod_df.iterrows():
            pid = as_str(r.get("productId"))
            if not pid:
                continue

            title = as_str(r.get("title")) or f"{as_str(r.get('topicId'), '')} {as_str(r.get('level'), '')}".strip()
            title_lower = as_str(r.get("titleLower")) or title.lower()

            data = {
                "type": as_str(r.get("type")),
                "topicId": as_str(r.get("topicId")),
                "level": as_str(r.get("level")),
                "title": title,
                "titleLower": title_lower,
                "levelGoal": as_str(r.get("levelGoal")),
                "levelBenefit": as_str(r.get("levelBenefit")),
                "anchorGroup": as_str(r.get("anchorGroup")),
                "version": as_str(r.get("version")),
                "published": as_bool(r.get("published"), True),

                "coverImageUrl": as_str(r.get("coverImageUrl")),
                "coverStorageFile": as_str(r.get("coverStorageFile")),

                "itemCount": as_int(r.get("itemCount")),
                "wordCountAvg": as_int(r.get("wordCountAvg")),

                "pushStrategy": as_str(r.get("pushStrategy")),
                "sourceType": as_str(r.get("sourceType")),
                "source": as_str(r.get("source")),
                "sourceUrl": as_str(r.get("sourceUrl")),

                "spec1Label": as_str(r.get("spec1Label")),
                "spec2Label": as_str(r.get("spec2Label")),
                "spec3Label": as_str(r.get("spec3Label")),
                "spec4Label": as_str(r.get("spec4Label")),
                "spec1Icon": as_str(r.get("spec1Icon")),
                "spec2Icon": as_str(r.get("spec2Icon")),
                "spec3Icon": as_str(r.get("spec3Icon")),
                "spec4Icon": as_str(r.get("spec4Icon")),

                "trialMode": as_str(r.get("trialMode")),
                "trialLimit": as_int(r.get("trialLimit"), 3),
            }

            writes.append(lambda b, pid=pid, d=data: b.set(db.collection("products").document(pid), d, merge=True))
        commit_in_batches(db, writes)
        print(f"✅ Wrote products ({len(writes)})")
    else:
        print("⚠️ PRODUCTS sheet missing (products will not be updated).")

    # ----------------
    # FEATURED_LISTS
    # ----------------
    if "FEATURED_LISTS" in sheets:
        fl_df = pd.read_excel(xlsx, sheet_name="FEATURED_LISTS")
        writes = []
        for _, r in fl_df.iterrows():
            list_id = as_str(r.get("listId"))
            if not list_id:
                continue

            ftype = as_str(r.get("type"), "")
            ids = split_semicolon(r.get("ids"))

            data = {
                "title": as_str(r.get("title"), list_id),
                "published": as_bool(r.get("published"), True),
                "order": as_int(r.get("order"), 0),
            }

            # 你 Excel 的 type 會告訴它用 productIds 還 topicIds
            if ftype == "productIds":
                data["productIds"] = ids
            elif ftype == "topicIds":
                data["topicIds"] = ids
            else:
                # 不確定就保留原始 ids
                data["ids"] = ids

            writes.append(lambda b, lid=list_id, d=data: b.set(db.collection("featured_lists").document(lid), d, merge=True))

        commit_in_batches(db, writes)
        print(f"✅ Wrote featured_lists ({len(writes)})")
    else:
        print("⚠️ FEATURED_LISTS sheet missing (featured_lists will not be updated).")

    # --------------
    # CONTENT_ITEMS
    # --------------
    if "CONTENT_ITEMS" in sheets:
        ci_df = pd.read_excel(xlsx, sheet_name="CONTENT_ITEMS")
        writes = []
        for _, r in ci_df.iterrows():
            item_id = as_str(r.get("itemId"))
            if not item_id:
                continue

            data = {
                "productId": as_str(r.get("productId")),
                "type": as_str(r.get("type")),
                "topicId": as_str(r.get("topicId")),
                "level": as_str(r.get("level")),
                "levelGoal": as_str(r.get("levelGoal")),
                "levelBenefit": as_str(r.get("levelBenefit")),
                "anchorGroup": as_str(r.get("anchorGroup")),
                "anchor": as_str(r.get("anchor"), ""),
                "intent": as_str(r.get("intent"), ""),
                "difficulty": as_int(r.get("difficulty"), 1),
                "content": as_str(r.get("content"), ""),
                "wordCount": as_int(r.get("wordCount")),
                "reusable": as_bool(r.get("reusable"), False),
                "sourceType": as_str(r.get("sourceType")),
                "source": as_str(r.get("source")),
                "sourceUrl": as_str(r.get("sourceUrl")),
                "version": as_str(r.get("version")),
                "pushOrder": as_int(r.get("pushOrder")),
                "storageFile": as_str(r.get("storageFile")),
                "seq": as_int(r.get("seq"), 0),
                "isPreview": as_bool(r.get("isPreview"), False),
            }

            writes.append(lambda b, iid=item_id, d=data: b.set(db.collection("content_items").document(iid), d, merge=True))

        commit_in_batches(db, writes)
        print(f"✅ Wrote content_items ({len(writes)})")
    else:
        print("⚠️ CONTENT_ITEMS sheet missing (content_items will not be updated).")

    print("🎉 DONE")


if __name__ == "__main__":
    main()
