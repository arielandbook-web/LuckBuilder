import argparse
import pandas as pd
import firebase_admin
from firebase_admin import credentials, firestore

def split_semicolon(s):
    if pd.isna(s) or s is None:
        return []
    return [x.strip() for x in str(s).split(";") if x.strip()]

def none_if_nan(v):
    return None if pd.isna(v) else v

def to_bool(v):
    if isinstance(v, bool):
        return v
    if pd.isna(v) or v is None:
        return False
    return str(v).strip().lower() in ("true", "1", "yes", "y", "t")

def safe_str(v):
    if pd.isna(v) or v is None:
        return ""
    return str(v).strip()

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--key", required=True, help="service account json path")
    ap.add_argument("--excel", required=True, help="xlsx path")
    args = ap.parse_args()

    cred = credentials.Certificate(args.key)
    firebase_admin.initialize_app(cred)
    db = firestore.client()

    xlsx = args.excel

    # helper: batched writes (<=500 per batch)
    def commit_in_batches(writes, batch_size=450):
        for i in range(0, len(writes), batch_size):
            b = db.batch()
            for fn in writes[i:i+batch_size]:
                fn(b)
            b.commit()

    # 1) UI_SEGMENTS -> ui/segments_v1
    seg_df = pd.read_excel(xlsx, sheet_name="UI_SEGMENTS")
    segments = []
    for _, r in seg_df.iterrows():
        seg_id = safe_str(r.get("segmentId"))
        title = safe_str(r.get("title"))
        if not seg_id or not title:
            continue
        segments.append({
            "id": seg_id,
            "title": title,
            "order": int(r.get("order")) if not pd.isna(r.get("order")) else 0,
            "mode": safe_str(r.get("mode")) or "tag",
            "tag": none_if_nan(r.get("tag")),
            "published": to_bool(r.get("published")),
        })
    segments = [s for s in segments if s.get("published", True)]
    segments.sort(key=lambda x: x.get("order", 0))
    db.collection("ui").document("segments_v1").set({"segments": segments}, merge=True)

    # 2) TOPICS -> topics/{topicId}
    topics_df = pd.read_excel(xlsx, sheet_name="TOPICS")
    topic_writes = []
    for _, r in topics_df.iterrows():
        tid = safe_str(r.get("topicId"))
        if not tid:
            continue
        data = {
            "title": safe_str(r.get("title")),
            "published": to_bool(r.get("published")),
            "order": int(r.get("order")) if not pd.isna(r.get("order")) else 0,
            "tags": split_semicolon(r.get("tags")),
            "bubbleImageUrl": none_if_nan(r.get("bubbleImageUrl")),
            "bubbleStorageFile": none_if_nan(r.get("bubbleStorageFile")),
            "bubbleGradStart": none_if_nan(r.get("bubbleGradStart")),
            "bubbleGradEnd": none_if_nan(r.get("bubbleGradEnd")),
        }
        topic_writes.append(lambda b, tid=tid, data=data: b.set(db.collection("topics").document(tid), data, merge=True))
    commit_in_batches(topic_writes)

    # 3) PRODUCTS -> products/{productId}
    prod_df = pd.read_excel(xlsx, sheet_name="PRODUCTS")
    prod_writes = []
    for _, r in prod_df.iterrows():
        pid = safe_str(r.get("productId"))
        if not pid:
            continue

        topic_id = safe_str(r.get("topicId"))
        level = safe_str(r.get("level"))

        data = {
            "type": none_if_nan(r.get("type")),
            "topicId": topic_id,
            "level": level,
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
            # Search MVP（前綴搜尋用）
            "titleLower": safe_str(r.get("titleLower")).lower() or None,
            # title: use Excel if provided, else fallback
            "title": none_if_nan(r.get("title")) or f"{topic_id} {level}".strip(),
        }
        prod_writes.append(lambda b, pid=pid, data=data: b.set(db.collection("products").document(pid), data, merge=True))
    commit_in_batches(prod_writes)

    # 4) FEATURED_LISTS -> featured_lists/{listId} (PATCHED)
    #    Supports your Excel:
    #      - type = products/topics (or productIds/topicIds)
    #      - columns: productIds / topicIds (semicolon separated)
    fl_df = pd.read_excel(xlsx, sheet_name="FEATURED_LISTS")
    fl_writes = []
    for _, r in fl_df.iterrows():
        lid = safe_str(r.get("listId"))
        if not lid:
            continue

        ftype = safe_str(r.get("type")).lower()

        data = {
            "title": safe_str(r.get("title")) or lid,
            "published": to_bool(r.get("published")) if r.get("published") is not None else True,
            "order": int(r.get("order")) if not pd.isna(r.get("order")) else 0,
        }

        if ftype in ("products", "product", "productids", "productids", "productids"):
            ids = split_semicolon(r.get("productIds")) or split_semicolon(r.get("ids"))
            data["productIds"] = ids
        elif ftype in ("topics", "topic", "topicids"):
            ids = split_semicolon(r.get("topicIds")) or split_semicolon(r.get("ids"))
            data["topicIds"] = ids
        elif ftype in ("productids", "productids", "productids") or ftype == "productids":
            ids = split_semicolon(r.get("productIds")) or split_semicolon(r.get("ids"))
            data["productIds"] = ids
        elif ftype == "productids" or ftype == "productids":
            ids = split_semicolon(r.get("productIds")) or split_semicolon(r.get("ids"))
            data["productIds"] = ids
        elif ftype == "productids" or ftype == "productids":
            ids = split_semicolon(r.get("productIds")) or split_semicolon(r.get("ids"))
            data["productIds"] = ids
        elif ftype == "productids" or ftype == "productids":
            ids = split_semicolon(r.get("productIds")) or split_semicolon(r.get("ids"))
            data["productIds"] = ids
        elif ftype == "productids" or ftype == "productids":
            ids = split_semicolon(r.get("productIds")) or split_semicolon(r.get("ids"))
            data["productIds"] = ids
        elif ftype == "productids" or ftype == "productids":
            ids = split_semicolon(r.get("productIds")) or split_semicolon(r.get("ids"))
            data["productIds"] = ids
        elif ftype == "productids" or ftype == "productids":
            ids = split_semicolon(r.get("productIds")) or split_semicolon(r.get("ids"))
            data["productIds"] = ids
        elif ftype == "productids" or ftype == "productids":
            ids = split_semicolon(r.get("productIds")) or split_semicolon(r.get("ids"))
            data["productIds"] = ids
        elif ftype == "productids" or ftype == "productids":
            ids = split_semicolon(r.get("productIds")) or split_semicolon(r.get("ids"))
            data["productIds"] = ids
        elif ftype == "productids":
            ids = split_semicolon(r.get("productIds")) or split_semicolon(r.get("ids"))
            data["productIds"] = ids
        elif ftype == "topicids":
            ids = split_semicolon(r.get("topicIds")) or split_semicolon(r.get("ids"))
            data["topicIds"] = ids
        else:
            # fallback: keep ids, but still try to salvage productIds/topicIds first
            ids = split_semicolon(r.get("productIds")) or split_semicolon(r.get("topicIds")) or split_semicolon(r.get("ids"))
            data["ids"] = ids

        fl_writes.append(lambda b, lid=lid, data=data: b.set(db.collection("featured_lists").document(lid), data, merge=True))
    commit_in_batches(fl_writes)

    # 5) CONTENT_ITEMS -> content_items/{itemId}
    ci_df = pd.read_excel(xlsx, sheet_name="CONTENT_ITEMS")
    ci_writes = []
    for _, r in ci_df.iterrows():
        iid = safe_str(r.get("itemId"))
        if not iid:
            continue

        data = {
            "productId": safe_str(r.get("productId")),
            "type": none_if_nan(r.get("type")),
            "topicId": none_if_nan(r.get("topicId")),
            "level": none_if_nan(r.get("level")),
            "levelGoal": none_if_nan(r.get("levelGoal")),
            "levelBenefit": none_if_nan(r.get("levelBenefit")),
            "anchorGroup": none_if_nan(r.get("anchorGroup")),
            "anchor": safe_str(r.get("anchor")),
            "intent": safe_str(r.get("intent")),
            "difficulty": int(r.get("difficulty")) if not pd.isna(r.get("difficulty")) else 1,
            "content": safe_str(r.get("content")),
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
    commit_in_batches(ci_writes)

    print("✅ Upload done: UI_SEGMENTS / TOPICS / PRODUCTS / FEATURED_LISTS / CONTENT_ITEMS")

if __name__ == "__main__":
    main()
