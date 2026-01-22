import 'package:flutter/material.dart';
import '../data/models.dart';
import '../theme/app_tokens.dart';
import 'app_card.dart';
import '../pages/product_page.dart';
import '../widgets/rich_sections/user_learning_store.dart';
import 'dart:async';

enum ProductRailSize { large, medium, small }

class ProductRail extends StatelessWidget {
  final List<Product> products;
  final ProductRailSize size;
  final String? badgeText;
  final String? ctaText;
  final bool dim; // tone: dim
  final bool showReleaseDate;
  final VoidCallback? onTapViewAll;

  const ProductRail({
    super.key,
    required this.products,
    this.size = ProductRailSize.medium,
    this.badgeText,
    this.ctaText,
    this.dim = false,
    this.showReleaseDate = false,
    this.onTapViewAll,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    
    // 根據 size 決定尺寸
    final height = switch (size) {
      ProductRailSize.large => 210.0,
      ProductRailSize.medium => 190.0,
      ProductRailSize.small => 180.0,
    };
    
    final cardWidth = switch (size) {
      ProductRailSize.large => 280.0,
      ProductRailSize.medium => 280.0,
      ProductRailSize.small => 220.0,
    };
    
    final imageHeight = switch (size) {
      ProductRailSize.large => 120.0,
      ProductRailSize.medium => 110.0,
      ProductRailSize.small => 105.0,
    };
    
    final titleFontSize = switch (size) {
      ProductRailSize.large => 16.0,
      ProductRailSize.medium => 16.0,
      ProductRailSize.small => 14.0,
    };
    
    final subtitleFontSize = switch (size) {
      ProductRailSize.large => 14.0,
      ProductRailSize.medium => 12.0,
      ProductRailSize.small => 12.0,
    };

    return SizedBox(
      height: height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: products.length + (onTapViewAll != null ? 1 : 0),
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, i) {
          // 最後一個項目是「查看全部」按鈕
          if (onTapViewAll != null && i == products.length) {
            return SizedBox(
              width: cardWidth,
              child: AppCard(
                onTap: onTapViewAll,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.arrow_forward, 
                          color: tokens.primary, size: 32),
                      const SizedBox(height: 8),
                      Text('查看全部',
                          style: TextStyle(
                              color: tokens.primary,
                              fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ),
            );
          }
          
          final p = products[i];
          final dt = p.releaseAt;
          final badge = badgeText != null
              ? (showReleaseDate && dt != null
                  ? '${dt.month}/${dt.day}'
                  : badgeText!)
              : null;

          return AppCard(
            padding: EdgeInsets.zero,
            onTap: () {
              unawaited(UserLearningStore().markGlobalLearnedToday());
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => ProductPage(productId: p.id)),
              );
            },
            child: SizedBox(
              width: cardWidth,
              height: height,
              child: Stack(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 封面圖片
                      if (p.coverImageUrl != null &&
                          p.coverImageUrl!.isNotEmpty)
                        ClipRRect(
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(20)),
                          child: Image.network(
                            p.coverImageUrl!,
                            width: double.infinity,
                            height: imageHeight,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                Container(
                              height: imageHeight,
                              color: tokens.chipBg,
                              child: Icon(Icons.image_not_supported,
                                  color: tokens.textSecondary),
                            ),
                          ),
                        )
                      else
                        Container(
                          height: imageHeight,
                          color: tokens.chipBg,
                          child: Icon(Icons.auto_awesome,
                              color: tokens.textSecondary),
                        ),
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.all(size == ProductRailSize.small ? 10 : 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      p.title,
                                      maxLines: size == ProductRailSize.small ? 2 : 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: titleFontSize,
                                        fontWeight: FontWeight.w900,
                                        color: tokens.textPrimary.withValues(
                                            alpha: dim ? 0.75 : 1.0),
                                      ),
                                    ),
                                  ),
                                  // Badge 在內容區（非 small size 時）
                                  if (badge != null && size != ProductRailSize.small) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: tokens.primary
                                            .withValues(alpha: 0.18),
                                        borderRadius: BorderRadius.circular(999),
                                        border: Border.all(
                                            color: tokens.primary
                                                .withValues(alpha: 0.35)),
                                      ),
                                      child: Text(
                                        badge,
                                        style: TextStyle(
                                          color: tokens.primary,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              SizedBox(height: size == ProductRailSize.small ? 2 : 4),
                              Flexible(
                                child: Text('${p.topicId} · ${p.level}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: subtitleFontSize,
                                      color: tokens.textSecondary.withValues(
                                          alpha: dim ? 0.65 : 1.0),
                                    )),
                              ),
                              if (dim && showReleaseDate) ...[
                                SizedBox(height: size == ProductRailSize.small ? 1 : 2),
                                Text(
                                  dt == null
                                      ? '即將上架'
                                      : '上架：${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: tokens.textSecondary.withValues(alpha: 0.7),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                              if (ctaText != null) ...[
                                const Spacer(),
                                Align(
                                  alignment: Alignment.bottomRight,
                                  child: Text(
                                    ctaText!,
                                    style: TextStyle(
                                      color: tokens.primary,
                                      fontWeight: FontWeight.w700,
                                      fontSize: size == ProductRailSize.small ? 12 : 14,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  // Badge 在左上角（small size 或特定樣式）
                  if (badge != null && size == ProductRailSize.small)
                    Positioned(
                      top: 10,
                      left: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(999),
                          color: Colors.black.withValues(alpha: 0.35),
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.18)),
                        ),
                        child: Text(
                          badge,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
