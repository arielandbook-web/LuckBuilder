import 'package:flutter/material.dart';

class TLRow {
  final bool isHeader;
  final String? dayKey;
  final dynamic item;
  final int? seqInDayForProduct;

  TLRow._({
    required this.isHeader,
    this.dayKey,
    this.item,
    this.seqInDayForProduct,
  });

  factory TLRow.header(String dayKey) => TLRow._(isHeader: true, dayKey: dayKey);

  factory TLRow.item(dynamic item, {int? seqInDayForProduct}) =>
      TLRow._(isHeader: false, item: item, seqInDayForProduct: seqInDayForProduct);
}

String tlDayKey(DateTime dt) {
  final y = dt.year.toString().padLeft(4, '0');
  final m = dt.month.toString().padLeft(2, '0');
  final d = dt.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

String tlTimeOnly(DateTime dt) {
  final hh = dt.hour.toString().padLeft(2, '0');
  final mm = dt.minute.toString().padLeft(2, '0');
  return '$hh:$mm';
}

Widget tlTag(String text, IconData icon) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.white.withValues(alpha: 0.85)),
        const SizedBox(width: 6),
        Text(
          text,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.85),
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}

Widget tlTimelineRow({
  required BuildContext context,
  required DateTime when,
  required String title,
  required String preview,
  required String metaText, // ✅ 新增
  required dynamic saved, // SavedContent?
  required int? seqInDay,
  required bool isFirst,
  required bool isLast,
  required VoidCallback onTap,
  Widget? trailing, // 可選：右下角操作區
}) {
  const axisWidth = 76.0;
  const dotSize = 10.0;

  return Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 左側時間線
        SizedBox(
          width: axisWidth,
          child: Column(
            children: [
              SizedBox(
                height: 10,
                child: Center(
                  child: Container(
                    width: 2,
                    color: isFirst
                        ? Colors.transparent
                        : Colors.white.withValues(alpha: 0.12),
                  ),
                ),
              ),
              Row(
                children: [
                  const SizedBox(width: 10),
                  Container(
                    width: dotSize,
                    height: dotSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${tlTimeOnly(when)}${seqInDay != null ? ' · 第 $seqInDay 則' : ''}',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(
                height: 28,
                child: Center(
                  child: Container(
                    width: 2,
                    color: isLast
                        ? Colors.transparent
                        : Colors.white.withValues(alpha: 0.12),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),

        // 右側卡片
        Expanded(
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 右上 meta
                    Row(
                      children: [
                        const Spacer(),
                        if (metaText.isNotEmpty)
                          Text(
                            metaText,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                    // 狀態 chips
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        if ((saved?.learned ?? false))
                          tlTag('已學會', Icons.check_circle),
                        if ((saved?.favorite ?? false)) tlTag('收藏', Icons.star),
                        if ((saved?.reviewLater ?? false))
                          tlTag('稍後', Icons.schedule),
                      ],
                    ),
                    if ((saved?.learned ?? false) ||
                        (saved?.favorite ?? false) ||
                        (saved?.reviewLater ?? false))
                      const SizedBox(height: 8),
                    Text(title,
                        style: const TextStyle(
                            fontWeight: FontWeight.w900, fontSize: 16)),
                    const SizedBox(height: 6),
                    Text(
                      preview,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (trailing != null) ...[
                      const SizedBox(height: 10),
                      trailing,
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
