class Product {
  final String id;
  final String title;
  final bool published;
  final String pushStrategy; // seq
  final String trialMode; // previewFlag
  final int trialLimit; // 3
  final int order;
  final String topicId;
  final String level;
  final String? levelGoal;

  const Product({
    required this.id,
    required this.title,
    required this.published,
    required this.pushStrategy,
    required this.trialMode,
    required this.trialLimit,
    required this.order,
    this.topicId = '',
    this.level = 'L1',
    this.levelGoal,
  });

  factory Product.fromMap(String id, Map<String, dynamic> m) {
    // 處理可能為 null 的 String 欄位
    final pushStrategyValue = m['pushStrategy'];
    final trialModeValue = m['trialMode'];

    return Product(
      id: id,
      title: (m['title'] ?? '') as String,
      published: (m['published'] ?? false) as bool,
      pushStrategy:
          (pushStrategyValue != null ? pushStrategyValue.toString() : 'seq'),
      trialMode:
          (trialModeValue != null ? trialModeValue.toString() : 'previewFlag'),
      trialLimit: ((m['trialLimit'] ?? 3) as num).toInt(),
      order: ((m['order'] ?? 0) as num).toInt(),
      topicId: m['topicId']?.toString() ?? '',
      level: m['level']?.toString() ?? 'L1',
      levelGoal: m['levelGoal']?.toString(),
    );
  }
}
