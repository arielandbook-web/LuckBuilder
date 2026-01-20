class Segment {
  final String id;
  final String title;
  final int order;
  final String mode; // "all" | "tag"
  final String? tag;
  final bool published;

  Segment({
    required this.id,
    required this.title,
    required this.order,
    required this.mode,
    required this.published,
    this.tag,
  });

  factory Segment.fromMap(Map<String, dynamic> m) => Segment(
    id: m['id'] ?? '',
    title: m['title'] ?? '',
    order: (m['order'] ?? 0) as int,
    mode: m['mode'] ?? 'all',
    tag: m['tag'],
    published: (m['published'] ?? true) as bool,
  );
}

class Topic {
  final String id;
  final String title;
  final bool published;
  final int order;
  final List<String> tags;
  final String? bubbleImageUrl;

  Topic({
    required this.id,
    required this.title,
    required this.published,
    required this.order,
    required this.tags,
    this.bubbleImageUrl,
  });

  factory Topic.fromDoc(String id, Map<String, dynamic> m) => Topic(
    id: id,
    title: m['title'] ?? '',
    published: (m['published'] ?? true) as bool,
    order: (m['order'] ?? 0) as int,
    tags: List<String>.from(m['tags'] ?? const []),
    bubbleImageUrl: m['bubbleImageUrl'],
  );
}

class FeaturedList {
  final String id;
  final String title;
  final bool published;
  final int order;
  final List<String> productIds;

  FeaturedList({
    required this.id,
    required this.title,
    required this.published,
    required this.order,
    required this.productIds,
  });

  factory FeaturedList.fromDoc(String id, Map<String, dynamic> m) => FeaturedList(
    id: id,
    title: m['title'] ?? '',
    published: (m['published'] ?? true) as bool,
    order: (m['order'] ?? 0) as int,
    productIds: List<String>.from(m['productIds'] ?? const []),
  );
}

class Product {
  final String id;
  final String title;
  final String topicId;
  final String level;
  final bool published;

  final String? coverImageUrl;
  final String? levelGoal;
  final String? levelBenefit;

  final String? spec1Label;
  final String? spec2Label;
  final String? spec3Label;
  final String? spec4Label;

  final int trialLimit;

  Product({
    required this.id,
    required this.title,
    required this.topicId,
    required this.level,
    required this.published,
    this.coverImageUrl,
    this.levelGoal,
    this.levelBenefit,
    this.spec1Label,
    this.spec2Label,
    this.spec3Label,
    this.spec4Label,
    required this.trialLimit,
  });

  factory Product.fromDoc(String id, Map<String, dynamic> m) => Product(
    id: id,
    title: m['title'] ?? '',
    topicId: m['topicId'] ?? '',
    level: m['level'] ?? 'L1',
    published: (m['published'] ?? true) as bool,
    coverImageUrl: m['coverImageUrl'],
    levelGoal: m['levelGoal'],
    levelBenefit: m['levelBenefit'],
    spec1Label: m['spec1Label'],
    spec2Label: m['spec2Label'],
    spec3Label: m['spec3Label'],
    spec4Label: m['spec4Label'],
    trialLimit: (m['trialLimit'] ?? 3) as int,
  );
}

class ContentItem {
  final String id;
  final String productId;
  final String anchor;
  final String content;
  final String intent;
  final int difficulty;
  final int seq;
  final bool isPreview;

  ContentItem({
    required this.id,
    required this.productId,
    required this.anchor,
    required this.content,
    required this.intent,
    required this.difficulty,
    required this.seq,
    required this.isPreview,
  });

  factory ContentItem.fromDoc(String id, Map<String, dynamic> m) => ContentItem(
    id: id,
    productId: m['productId'] ?? '',
    anchor: m['anchor'] ?? '',
    content: m['content'] ?? '',
    intent: m['intent'] ?? '',
    difficulty: (m['difficulty'] ?? 1) as int,
    seq: (m['seq'] ?? 0) as int,
    isPreview: (m['isPreview'] ?? false) as bool,
  );
}
