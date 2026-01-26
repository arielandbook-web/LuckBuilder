import 'package:cloud_firestore/cloud_firestore.dart';
import 'push_config.dart';

class ProgressState {
  final int nextSeq; // 從 1 開始
  final int learnedCount;

  const ProgressState({required this.nextSeq, required this.learnedCount});

  static ProgressState defaults() =>
      const ProgressState(nextSeq: 1, learnedCount: 0);

  Map<String, dynamic> toMap() =>
      {'nextSeq': nextSeq, 'learnedCount': learnedCount};

  factory ProgressState.fromMap(Map<String, dynamic>? m) {
    if (m == null) return ProgressState.defaults();
    return ProgressState(
      nextSeq: ((m['nextSeq'] ?? 1) as num).toInt(),
      learnedCount: ((m['learnedCount'] ?? 0) as num).toInt(),
    );
  }

  ProgressState copyWith({int? nextSeq, int? learnedCount}) => ProgressState(
      nextSeq: nextSeq ?? this.nextSeq,
      learnedCount: learnedCount ?? this.learnedCount);
}

class UserLibraryProduct {
  final String productId;
  final DateTime purchasedAt;
  final bool isFavorite;
  final bool isHidden; // 刪除=隱藏
  final bool pushEnabled; // 推播中
  final ProgressState progress;
  final DateTime? lastOpenedAt;
  final PushConfig pushConfig;
  final DateTime? completedAt; // 全部內容學習完成的時間戳

  const UserLibraryProduct({
    required this.productId,
    required this.purchasedAt,
    required this.isFavorite,
    required this.isHidden,
    required this.pushEnabled,
    required this.progress,
    required this.lastOpenedAt,
    required this.pushConfig,
    this.completedAt,
  });

  factory UserLibraryProduct.fromMap(String productId, Map<String, dynamic> m) {
    final ts = m['purchasedAt'] as Timestamp?;
    final last = m['lastOpenedAt'] as Timestamp?;
    final completed = m['completedAt'] as Timestamp?;
    return UserLibraryProduct(
      productId: productId,
      purchasedAt: ts?.toDate() ?? DateTime.now(),
      isFavorite: (m['isFavorite'] ?? false) as bool,
      isHidden: (m['isHidden'] ?? false) as bool,
      pushEnabled: (m['pushEnabled'] ?? false) as bool,
      progress: ProgressState.fromMap(
          (m['progress'] as Map?)?.cast<String, dynamic>()),
      lastOpenedAt: last?.toDate(),
      pushConfig: PushConfig.fromMap(
          (m['pushConfig'] as Map?)?.cast<String, dynamic>()),
      completedAt: completed?.toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
        'productId': productId,
        'purchasedAt': Timestamp.fromDate(purchasedAt),
        'isFavorite': isFavorite,
        'isHidden': isHidden,
        'pushEnabled': pushEnabled,
        'progress': progress.toMap(),
        'lastOpenedAt':
            lastOpenedAt == null ? null : Timestamp.fromDate(lastOpenedAt!),
        'pushConfig': pushConfig.toMap(),
        'completedAt':
            completedAt == null ? null : Timestamp.fromDate(completedAt!),
      };

  UserLibraryProduct copyWith({
    bool? isFavorite,
    bool? isHidden,
    bool? pushEnabled,
    ProgressState? progress,
    DateTime? lastOpenedAt,
    PushConfig? pushConfig,
    DateTime? completedAt,
  }) {
    return UserLibraryProduct(
      productId: productId,
      purchasedAt: purchasedAt,
      isFavorite: isFavorite ?? this.isFavorite,
      isHidden: isHidden ?? this.isHidden,
      pushEnabled: pushEnabled ?? this.pushEnabled,
      progress: progress ?? this.progress,
      lastOpenedAt: lastOpenedAt ?? this.lastOpenedAt,
      pushConfig: pushConfig ?? this.pushConfig,
      completedAt: completedAt ?? this.completedAt,
    );
  }
}

class WishlistItem {
  final String productId;
  final DateTime addedAt;
  final bool isFavorite;

  const WishlistItem({
    required this.productId,
    required this.addedAt,
    required this.isFavorite,
  });

  factory WishlistItem.fromMap(String productId, Map<String, dynamic> m) {
    final ts = m['addedAt'] as Timestamp?;
    return WishlistItem(
      productId: productId,
      addedAt: ts?.toDate() ?? DateTime.now(),
      isFavorite: (m['isFavorite'] ?? false) as bool,
    );
  }
}

class SavedContent {
  final String contentItemId;
  final bool favorite;
  final bool learned;
  final bool reviewLater;

  const SavedContent({
    required this.contentItemId,
    required this.favorite,
    required this.learned,
    required this.reviewLater,
  });

  factory SavedContent.fromMap(String id, Map<String, dynamic> m) =>
      SavedContent(
        contentItemId: id,
        favorite: (m['favorite'] ?? false) as bool,
        learned: (m['learned'] ?? false) as bool,
        reviewLater: (m['reviewLater'] ?? false) as bool,
      );
}
