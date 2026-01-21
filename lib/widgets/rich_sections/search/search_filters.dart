enum SearchSort { relevance, newest, titleAZ }

class SearchFilters {
  final bool purchasedOnly;
  final bool wishlistOnly;
  final bool pushingOnly;
  final bool trialOnly;
  final Set<String> levels; // e.g. {"L1","L2"}
  final SearchSort sort;

  const SearchFilters({
    this.purchasedOnly = false,
    this.wishlistOnly = false,
    this.pushingOnly = false,
    this.trialOnly = false,
    this.levels = const {},
    this.sort = SearchSort.relevance,
  });

  SearchFilters copyWith({
    bool? purchasedOnly,
    bool? wishlistOnly,
    bool? pushingOnly,
    bool? trialOnly,
    Set<String>? levels,
    SearchSort? sort,
  }) {
    return SearchFilters(
      purchasedOnly: purchasedOnly ?? this.purchasedOnly,
      wishlistOnly: wishlistOnly ?? this.wishlistOnly,
      pushingOnly: pushingOnly ?? this.pushingOnly,
      trialOnly: trialOnly ?? this.trialOnly,
      levels: levels ?? this.levels,
      sort: sort ?? this.sort,
    );
  }

  bool get hasAny =>
      purchasedOnly ||
      wishlistOnly ||
      pushingOnly ||
      trialOnly ||
      levels.isNotEmpty;

  String summaryText() {
    final parts = <String>[];
    if (purchasedOnly) parts.add('已購買');
    if (wishlistOnly) parts.add('未購買收藏');
    if (pushingOnly) parts.add('推播中');
    if (trialOnly) parts.add('可試讀');
    if (levels.isNotEmpty) parts.add(levels.join(','));
    return parts.isEmpty ? '篩選' : parts.join(' · ');
  }

  String sortText() {
    switch (sort) {
      case SearchSort.relevance:
        return '最相關';
      case SearchSort.newest:
        return '最新';
      case SearchSort.titleAZ:
        return '名稱 A→Z';
    }
  }
}
