class ContentItem {
  final String id;
  final String productId;
  final String anchorGroup;
  final String anchor;
  final String intent;
  final int difficulty;
  final String content;
  final String sourceUrl; // ; separated
  final int pushOrder; // Day N
  final int seq;
  final int isPreview; // 0/1

  const ContentItem({
    required this.id,
    required this.productId,
    required this.anchorGroup,
    required this.anchor,
    required this.intent,
    required this.difficulty,
    required this.content,
    required this.sourceUrl,
    required this.pushOrder,
    required this.seq,
    required this.isPreview,
  });

  factory ContentItem.fromMap(String id, Map<String, dynamic> m) {
    // 處理 isPreview：Firebase 可能是 bool 或 int
    int isPreviewValue = 0;
    final isPreviewField = m['isPreview'];
    if (isPreviewField is bool) {
      isPreviewValue = isPreviewField ? 1 : 0;
    } else if (isPreviewField is int) {
      isPreviewValue = isPreviewField;
    } else if (isPreviewField != null) {
      isPreviewValue = (isPreviewField as num).toInt();
    }

    // 處理 pushOrder：可能是 null
    int pushOrderValue = 0;
    final pushOrderField = m['pushOrder'];
    if (pushOrderField != null) {
      pushOrderValue = (pushOrderField as num).toInt();
    }

    return ContentItem(
      id: id,
      productId: (m['productId'] ?? '') as String,
      anchorGroup: (m['anchorGroup'] ?? '') as String,
      anchor: (m['anchor'] ?? '') as String,
      intent: (m['intent'] ?? '') as String,
      difficulty: (m['difficulty'] ?? 1) as int,
      content: (m['content'] ?? '') as String,
      sourceUrl: (m['sourceUrl'] ?? '') as String,
      pushOrder: pushOrderValue,
      seq: (m['seq'] ?? 0) as int,
      isPreview: isPreviewValue,
    );
  }
}
