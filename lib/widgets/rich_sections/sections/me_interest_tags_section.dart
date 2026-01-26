import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../theme/app_tokens.dart';
import '../../app_card.dart';
import '../../../bubble_library/providers/providers.dart';
import '../../../collections/wishlist_provider.dart';
import '../user/me_prefs_store.dart';

class MeInterestTagsSection extends ConsumerStatefulWidget {
  const MeInterestTagsSection({super.key});

  @override
  ConsumerState<MeInterestTagsSection> createState() =>
      _MeInterestTagsSectionState();
}

class _MeInterestTagsSectionState extends ConsumerState<MeInterestTagsSection> {
  static const _localKey = 'local';
  List<String> _tags = [];
  List<String> _custom = [];
  bool _loading = true;

  String _uidOrLocal() {
    try {
      return ref.read(uidProvider);
    } catch (_) {
      return _localKey;
    }
  }

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final key = _uidOrLocal();
    final tags = await MePrefsStore.getInterestTags(key);
    final custom = await MePrefsStore.getCustomTags(key);
    if (!mounted) return;
    setState(() {
      _tags = tags;
      _custom = custom;
      _loading = false;
    });
  }

  Future<void> _save(List<String> nextTags) async {
    final key = _uidOrLocal();
    await MePrefsStore.setInterestTags(key, nextTags);
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    // 建議標籤：從你已擁有/收藏的產品 topicId 推出（不改後端）
    final productsMapAsync = ref.watch(productsMapProvider);
    final libAsync = _safeLib();
    final wishAsync = _safeWish();

    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('興趣標籤',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: tokens.textPrimary)),
              const Spacer(),
              TextButton.icon(
                onPressed: _loading
                    ? null
                    : () async {
                        final next = await _openEditSheet(context);
                        if (next != null) await _save(next);
                      },
                icon: const Icon(Icons.edit, size: 18),
                label: const Text('編輯'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else if (_tags.isEmpty)
            Text('先選幾個標籤，我會用來做推薦與排序',
                style: TextStyle(color: tokens.textSecondary))
          else
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _tags.map((t) => _chip(context, t)).toList(),
            ),
          const SizedBox(height: 14),
          Text('建議你可以選',
              style: TextStyle(
                  color: tokens.textSecondary, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          productsMapAsync.when(
            data: (productsMap) {
              return libAsync.when(
                data: (lib) {
                  return wishAsync.when(
                    data: (wish) {
                      final suggested = _suggestTags(productsMap, lib, wish)
                          .where((t) => !_tags.contains(t))
                          .take(10)
                          .toList();

                      if (suggested.isEmpty) {
                        return Text('你目前收藏較少，先從下面熱門標籤開始也可以',
                            style: TextStyle(color: tokens.textSecondary));
                      }

                      return Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: suggested.map((t) {
                          return ActionChip(
                            label: Text(t),
                            onPressed: () => _save([..._tags, t]),
                          );
                        }).toList(),
                      );
                    },
                    loading: () => const SizedBox(
                        height: 36,
                        child: Center(child: CircularProgressIndicator())),
                    error: (e, _) => Text('$e',
                        style: TextStyle(color: tokens.textSecondary)),
                  );
                },
                loading: () => const SizedBox(
                    height: 36,
                    child: Center(child: CircularProgressIndicator())),
                error: (e, _) =>
                    Text('$e', style: TextStyle(color: tokens.textSecondary)),
              );
            },
            loading: () => const SizedBox(
                height: 36, child: Center(child: CircularProgressIndicator())),
            error: (e, _) =>
                Text('$e', style: TextStyle(color: tokens.textSecondary)),
          ),
        ],
      ),
    );
  }

  AsyncValue<List<dynamic>> _safeLib() {
    try {
      ref.read(uidProvider);
      return ref.watch(libraryProductsProvider);
    } catch (_) {
      return const AsyncValue.data(<dynamic>[]);
    }
  }

  AsyncValue<List<dynamic>> _safeWish() {
    try {
      ref.read(uidProvider);
      return ref.watch(localWishlistProvider);
    } catch (_) {
      return const AsyncValue.data(<dynamic>[]);
    }
  }

  List<String> _suggestTags(
      Map<String, dynamic> productsMap, List<dynamic> lib, List<dynamic> wish) {
    // 用 title 前綴當作建議 tag（因 bubble_library Product 沒有 topicId）
    final count = <String, int>{};

    void addPid(String pid) {
      final p = productsMap[pid];
      if (p == null) return;
      try {
        final tid = (p as dynamic).title.toString().split(' ').first;
        if (tid.isEmpty) return;
        count[tid] = (count[tid] ?? 0) + 1;
      } catch (_) {}
    }

    for (final lp in lib) {
      try {
        if ((lp as dynamic).isHidden == true) continue;
        addPid((lp as dynamic).productId.toString());
      } catch (_) {}
    }
    for (final w in wish) {
      try {
        addPid((w as dynamic).productId.toString());
      } catch (_) {}
    }

    final list = count.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return list.map((e) => e.key).toList();
  }

  Widget _chip(BuildContext context, String text) {
    final tokens = context.tokens;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: tokens.chipBg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: tokens.cardBorder),
      ),
      child:
          Text(text, style: TextStyle(color: tokens.textPrimary, fontSize: 12)),
    );
  }

  Future<List<String>?> _openEditSheet(BuildContext context) async {
    final tokens = context.tokens;
    final key = _uidOrLocal();

    // 內建 + 自訂
    final builtin = <String>[
      'AI',
      '宇宙',
      '美學',
      '理財',
      '健康',
      '心理',
      '親子',
      '生產力',
      '程式',
      '職涯',
      '閱讀',
      '溝通',
      '英文',
      '寫作',
      '習慣',
      '冥想',
      '營養',
      '運動',
      '設計',
      '創業',
    ];

    final all = {...builtin, ..._custom}.toList()..sort();
    final selected = {..._tags};
    final controller = TextEditingController();

    return showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setModal) {
            Widget chip(String t) {
              final isSel = selected.contains(t);
              return FilterChip(
                label: Text(t),
                selected: isSel,
                onSelected: (_) => setModal(() {
                  if (isSel) {
                    selected.remove(t);
                  } else {
                    selected.add(t);
                  }
                }),
              );
            }

            return Container(
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: context.tokens.cardBg,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: context.tokens.cardBorder),
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('編輯興趣標籤',
                        style: TextStyle(
                            color: tokens.textPrimary,
                            fontWeight: FontWeight.w900,
                            fontSize: 16)),
                    const SizedBox(height: 10),
                    Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: all.map(chip).toList()),
                    const SizedBox(height: 14),
                    Text('新增自訂標籤',
                        style: TextStyle(
                            color: tokens.textSecondary,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: controller,
                            style: TextStyle(color: tokens.textPrimary),
                            decoration: InputDecoration(
                              hintText: '例如：睡前學習、通勤碎片…',
                              hintStyle: TextStyle(color: tokens.textSecondary),
                              filled: true,
                              fillColor: tokens.cardBg.withValues(alpha: 0.5),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide(
                                    color: tokens.cardBorder),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton(
                          onPressed: () async {
                            final t = controller.text.trim();
                            if (t.isEmpty) return;
                            await MePrefsStore.addCustomTag(key, t);
                            controller.clear();
                            final fresh = await MePrefsStore.getCustomTags(key);
                            setModal(() {
                              _custom = fresh;
                              all
                                ..clear()
                                ..addAll(
                                    {...builtin, ...fresh}.toList()..sort());
                            });
                          },
                          child: const Text('加入'),
                        )
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => setModal(() => selected.clear()),
                            child: const Text('清除'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => Navigator.of(context)
                                .pop(selected.toList()..sort()),
                            child: const Text('儲存'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
