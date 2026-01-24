import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers/providers.dart';
import '../models/content_item.dart';
import '../models/user_library.dart';
import 'widgets/bubble_card.dart';
import '../../../theme/app_tokens.dart';
import '../../../services/learning_progress_service.dart';

class DetailPage extends ConsumerWidget {
  final String contentItemId;
  const DetailPage({super.key, required this.contentItemId});

  List<String> _splitBullets(String content) {
    final parts = content
        .split(RegExp(r'[，；。]'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    return parts.take(4).toList();
  }

  List<Uri> _parseUrls(String s) {
    final parts = s.split(';').map((e) => e.trim()).where((e) => e.isNotEmpty);
    final out = <Uri>[];
    for (final p in parts) {
      final u = Uri.tryParse(p);
      if (u != null && (u.scheme == 'http' || u.scheme == 'https')) out.add(u);
    }
    return out;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemAsync = ref.watch(contentItemProvider(contentItemId));
    final savedAsync = ref.watch(savedItemsProvider);
    final tokens = context.tokens;

    return Scaffold(
      backgroundColor: tokens.bg,
      appBar: AppBar(
        title: const Text('Detail'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: itemAsync.when(
        data: (item) {
          final bullets = _splitBullets(item.content);
          final urls = _parseUrls(item.sourceUrl);

          return savedAsync.when(
            data: (savedMap) {
              final SavedContent? saved = savedMap[item.id];

              // 檢查是否登入
              String? uid;
              try {
                uid = ref.read(uidProvider);
              } catch (_) {
                return const Center(child: Text('請先登入以使用此功能'));
              }

              final repo = ref.read(libraryRepoProvider);

              return ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  // 0) Header
                  BubbleCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.anchorGroup,
                            style: const TextStyle(
                                fontSize: 20, fontWeight: FontWeight.w900)),
                        const SizedBox(height: 6),
                        Text(item.anchor,
                            style: TextStyle(color: tokens.textSecondary)),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            _chip('intent：${item.intent}'),
                            _chip('◆${item.difficulty}'),
                            _chip('L1'),
                            _chip('Day ${item.pushOrder}/365'),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 1) 今日一句
                  BubbleCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('今日一句',
                            style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w900)),
                        const SizedBox(height: 8),
                        Text(item.content,
                            style: const TextStyle(
                                fontSize: 18,
                                height: 1.35,
                                fontWeight: FontWeight.w800)),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            TextButton.icon(
                              onPressed: () async {
                                await Clipboard.setData(
                                    ClipboardData(text: item.content));
                                // ignore: use_build_context_synchronously
                                ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('已複製')));
                              },
                              icon: const Icon(Icons.copy, size: 18),
                              label: const Text('複製'),
                            ),
                            TextButton.icon(
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('可在此串接分享功能')));
                              },
                              icon: const Icon(Icons.share, size: 18),
                              label: const Text('分享'),
                            ),
                            const Spacer(),
                            IconButton(
                              icon: Icon((saved?.favorite ?? false)
                                  ? Icons.star
                                  : Icons.star_border),
                              onPressed: () => repo.setSavedItem(uid!, item.id,
                                  {'favorite': !(saved?.favorite ?? false)}),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 操作按鈕：完成和稍候再學
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () async {
                            // 獲取 product 和 topicId
                            final productsMap = await ref.read(productsMapProvider.future);
                            final product = productsMap[item.productId];
                            if (product == null) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('無法獲取產品資訊')),
                                );
                              }
                              return;
                            }
                            
                            final progress = LearningProgressService();
                            try {
                              await progress.markLearnedAndAdvance(
                                topicId: product.topicId,
                                contentId: item.id,
                                pushOrder: item.pushOrder,
                                source: 'detail_page',
                              );
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('已標記為完成')),
                                );
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('操作失敗: $e')),
                                );
                              }
                            }
                          },
                          icon: const Icon(Icons.check),
                          label: const Text('完成'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            // 獲取 product 和 topicId
                            final productsMap = await ref.read(productsMapProvider.future);
                            final product = productsMap[item.productId];
                            if (product == null) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('無法獲取產品資訊')),
                                );
                              }
                              return;
                            }
                            
                            final progress = LearningProgressService();
                            try {
                              await progress.snoozeContent(
                                topicId: product.topicId,
                                contentId: item.id,
                                pushOrder: item.pushOrder,
                                duration: const Duration(hours: 6),
                                source: 'detail_page',
                              );
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('已延後 6 小時')),
                                );
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('操作失敗: $e')),
                                );
                              }
                            }
                          },
                          icon: const Icon(Icons.schedule),
                          label: const Text('稍候再學'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // 2) 白話拆解
                  BubbleCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('白話拆解',
                            style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w900)),
                        const SizedBox(height: 10),
                        ...bullets.map((b) => Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('•  '),
                                  Expanded(
                                      child: Text(b,
                                          style:
                                              const TextStyle(height: 1.35))),
                                ],
                              ),
                            )),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 3) 1 分鐘練習（依 intent）
                  BubbleCard(child: _oneMinutePractice(item)),
                  const SizedBox(height: 12),

                  // 4) 常見誤解
                  BubbleCard(child: _commonMisconception(item)),
                  const SizedBox(height: 12),

                  // 5) 延伸閱讀
                  BubbleCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('延伸閱讀',
                            style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w900)),
                        const SizedBox(height: 10),
                        if (urls.isEmpty)
                          Text('目前沒有連結',
                              style: TextStyle(color: tokens.textSecondary))
                        else
                          ...urls.map((u) => Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: InkWell(
                                  onTap: () async {
                                    if (await canLaunchUrl(u)) {
                                      await launchUrl(u,
                                          mode: LaunchMode.externalApplication);
                                    } else {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          const SnackBar(
                                              content: Text('無法開啟此連結')),
                                        );
                                      }
                                    }
                                  },
                                  child: Text(u.toString(),
                                      style: const TextStyle(
                                          decoration:
                                              TextDecoration.underline)),
                                ),
                              )),
                      ],
                    ),
                  ),
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('saved error: $e')),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('detail error: $e')),
      ),
    );
  }

  Widget _oneMinutePractice(ContentItem item) {
    final intent = item.intent.trim();

    if (intent.contains('定義')) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('1 分鐘練習',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          const Text('用你自己的話說一次（像跟朋友解釋）'),
          const SizedBox(height: 10),
          _hintBox('提示：用「它是…」「它會…」「所以可以…」三句話描述'),
        ],
      );
    }

    if (intent.contains('方法') || intent.contains('流程')) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('1 分鐘練習',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          const Text('照做清單'),
          const SizedBox(height: 10),
          _check('把目標寫成一句話'),
          _check('加上限制條件（時間/格式/範圍）'),
          _check('給一個例子讓答案更準'),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('1 分鐘練習',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
        const SizedBox(height: 10),
        const Text('A vs B（兩欄對照）'),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _smallCard('A', '用一句話寫出 A 的特徵')),
            const SizedBox(width: 10),
            Expanded(child: _smallCard('B', '用一句話寫出 B 的特徵')),
          ],
        ),
      ],
    );
  }

  Widget _commonMisconception(ContentItem item) {
    final c = item.content;
    final hasNeg = c.contains('不是') || c.contains('並非') || c.contains('不要');

    final misconception = hasNeg ? '常見誤解：忽略「不是/並非」造成理解相反' : '常見誤解：只看關鍵字就下結論';
    final correct = hasNeg ? '更精準說法：把否定詞後面的限定條件一起讀完' : '更精準說法：先拆成 2–3 個條件再理解';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('常見誤解',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
        const SizedBox(height: 10),
        Text(misconception),
        const SizedBox(height: 8),
        Builder(
          builder: (context) {
            final tokens = context.tokens;
            return Text(correct, style: TextStyle(color: tokens.textPrimary));
          },
        ),
      ],
    );
  }

  Widget _chip(String text) => Builder(
        builder: (context) {
          final tokens = context.tokens;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              gradient: tokens.chipGradient,
              color: tokens.chipGradient == null ? tokens.chipBg : null,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: tokens.cardBorder),
            ),
            child: Text(
              text,
              style: TextStyle(
                  color: tokens.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600),
            ),
          );
        },
      );

  Widget _hintBox(String text) => Builder(
        builder: (context) {
          final tokens = context.tokens;
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: tokens.cardGradient,
              color: tokens.cardGradient == null ? tokens.cardBg : null,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: tokens.cardBorder),
            ),
            child: Text(text, style: TextStyle(color: tokens.textPrimary)),
          );
        },
      );

  Widget _check(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            const Icon(Icons.check_box_outline_blank, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text(text)),
          ],
        ),
      );

  Widget _smallCard(String title, String body) => Builder(
        builder: (context) {
          final tokens = context.tokens;
          return Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: tokens.cardGradient,
              color: tokens.cardGradient == null ? tokens.cardBg : null,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: tokens.cardBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: tokens.textPrimary)),
                const SizedBox(height: 6),
                Text(body, style: TextStyle(color: tokens.textSecondary)),
              ],
            ),
          );
        },
      );
}
