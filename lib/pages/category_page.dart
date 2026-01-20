import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/v2_providers.dart';
import '../widgets/app_card.dart';
import '../theme/app_tokens.dart';
import '../ui/bubble.dart';
import 'product_list_page.dart';

class CategoryPage extends ConsumerWidget {
  const CategoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final segs = ref.watch(segmentsProvider);
    final selected = ref.watch(selectedSegmentProvider);
    final topics = ref.watch(topicsForSelectedSegmentProvider);
    final tokens = context.tokens;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('分類', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: tokens.textPrimary)),
          const SizedBox(height: 12),

          segs.when(
            data: (list) => list.isEmpty
                ? AppCard(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text('區段: 無資料（請檢查 Firestore ui/segments_v1）', 
                        style: TextStyle(color: Colors.red)),
                    ),
                  )
                : SizedBox(
                    height: 46,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: list.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 10),
                      itemBuilder: (_, i) {
                        final s = list[i];
                        final isSel = (selected?.id ?? list.first.id) == s.id;
                        return Builder(
                          builder: (context) {
                            final tokens = context.tokens;
                            return InkWell(
                              onTap: () => ref.read(selectedSegmentProvider.notifier).state = s,
                              borderRadius: BorderRadius.circular(999),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(999),
                                  color: isSel ? tokens.primary.withOpacity(0.2) : tokens.chipBg,
                                  border: Border.all(color: isSel ? tokens.primary : tokens.cardBorder),
                                ),
                                child: Text(
                                  s.title,
                                  style: TextStyle(
                                    fontWeight: isSel ? FontWeight.w800 : FontWeight.w500,
                                    color: isSel ? tokens.primary : tokens.textPrimary,
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
            loading: () => const SizedBox(height: 46, child: Center(child: CircularProgressIndicator())),
            error: (err, stack) => AppCard(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('區段錯誤:', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text('$err', 
                      style: const TextStyle(color: Colors.red, fontSize: 12),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 14),

          topics.when(
            data: (ts) => ts.isEmpty
                ? AppCard(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text('主題: 無資料（請檢查 Firestore topics）', 
                        style: TextStyle(color: Colors.orange)),
                    ),
                  )
                : Wrap(
                    spacing: 14,
                    runSpacing: 14,
                    children: ts.map((t) => BubbleCircle(
                      title: t.title,
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => ProductListPage(topicId: t.id),
                      )),
                    )).toList(),
                  ),
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (err, stack) => AppCard(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('主題錯誤:', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text('$err', 
                      style: const TextStyle(color: Colors.red, fontSize: 12),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
