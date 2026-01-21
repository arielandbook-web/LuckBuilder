import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/v2_providers.dart';
import '../widgets/app_card.dart';
import '../theme/app_tokens.dart';
import '../ui/rich_sections/user_state_store.dart';
import '../ui/rich_sections/search_history_section.dart';
import '../ui/rich_sections/search_suggestions_section.dart';
import '../bubble_library/providers/providers.dart';
import '../widgets/rich_sections/search/search_filters.dart';
import '../widgets/rich_sections/user_learning_store.dart';
import 'product_page.dart';

class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key});

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  final _store = UserStateStore();
  final _searchController = TextEditingController();
  final _historyKey = GlobalKey<SearchHistorySectionState>();
  SearchFilters _filters = const SearchFilters();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _submitSearch(String q) async {
    if (q.trim().isEmpty) return;
    await _store.addRecentSearch(q);
    ref.read(searchQueryProvider.notifier).state = q;
    _searchController.text = q;
    // 重新載入歷史紀錄
    _historyKey.currentState?.reload();
  }

  @override
  Widget build(BuildContext context) {
    final query = ref.watch(searchQueryProvider);
    final results = ref.watch(searchResultsProvider);
    final tokens = context.tokens;

    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: AppCard(
              padding: EdgeInsets.zero,
              child: Container(
                decoration: BoxDecoration(
                  gradient: tokens.searchBarGradient,
                  borderRadius: BorderRadius.circular(tokens.cardRadius),
                ),
                child: TextField(
                  controller: _searchController,
                  autofocus: true,
                  style: TextStyle(color: tokens.textPrimary),
                  decoration: InputDecoration(
                    hintText: '搜尋產品 / 主題…',
                    hintStyle: TextStyle(color: tokens.textSecondary),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    icon: Padding(
                      padding: const EdgeInsets.only(left: 16),
                      child: Icon(Icons.search, color: tokens.textSecondary),
                    ),
                    suffixIcon: query.isNotEmpty
                        ? IconButton(
                            icon:
                                Icon(Icons.clear, color: tokens.textSecondary),
                            onPressed: () {
                              _searchController.clear();
                              ref.read(searchQueryProvider.notifier).state = '';
                            },
                          )
                        : null,
                  ),
                  onChanged: (value) {
                    ref.read(searchQueryProvider.notifier).state = value;
                  },
                  onSubmitted: _submitSearch,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                ActionChip(
                  label: Text(_filters.summaryText()),
                  onPressed: () async {
                    final next = await _openFiltersSheet(context);
                    if (next != null) setState(() => _filters = next);
                  },
                ),
                ActionChip(
                  label: Text('排序：${_filters.sortText()}'),
                  onPressed: () async {
                    final next = await _openFiltersSheet(context);
                    if (next != null) setState(() => _filters = next);
                  },
                ),
                if (_filters.hasAny)
                  InputChip(
                    label: const Text('清除'),
                    onDeleted: () =>
                        setState(() => _filters = const SearchFilters()),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: results.when(
              data: (products) {
                if (query.isEmpty) {
                  // 顯示歷史記錄和建議區塊
                  return ListView(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: SearchHistorySection(
                          key: _historyKey,
                          onTapQuery: (q) {
                            _submitSearch(q);
                          },
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: SearchSuggestionsSection(
                          onTap: (q) {
                            _submitSearch(q);
                          },
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  );
                }

                // 篩選/排序邏輯
                final filtered = _applyFilters(products);

                if (filtered.isEmpty) {
                  return Center(
                    child: Text('找不到「$query」的結果',
                        style: TextStyle(
                            fontSize: 16, color: tokens.textSecondary)),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (_, index) {
                    final product = filtered[index];
                    return AppCard(
                      onTap: () {
                        unawaited(UserLearningStore().markGlobalLearnedToday());
                        Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => ProductPage(productId: product.id),
                        ));
                      },
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            product.title,
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: tokens.textPrimary),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${product.topicId} · ${product.level}',
                            style: TextStyle(color: tokens.textSecondary),
                          ),
                          if (product.levelGoal != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              product.levelGoal!,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: tokens.textSecondary),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: AppCard(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('搜尋錯誤:',
                            style: TextStyle(
                                color: tokens.textPrimary,
                                fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text(
                          '$error',
                          style: TextStyle(
                              color: tokens.textSecondary, fontSize: 12),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<dynamic> _applyFilters(List<dynamic> products) {
    // 讀使用者狀態（已購買/推播/願望清單）——未登入就視為空集合
    final purchasedIds = <String>{};
    final pushingIds = <String>{};
    final wishlistIds = <String>{};

    try {
      ref.read(uidProvider);
      final libData = ref.read(libraryProductsProvider).asData?.value;
      if (libData != null) {
        for (final lp in libData) {
          final pid = (lp as dynamic).productId?.toString();
          if (pid != null) purchasedIds.add(pid);
          try {
            if ((lp as dynamic).pushEnabled == true) pushingIds.add(pid!);
          } catch (_) {}
        }
      }
      final wishData = ref.read(wishlistProvider).asData?.value;
      if (wishData != null) {
        for (final w in wishData) {
          final pid = (w as dynamic).productId?.toString();
          if (pid != null) wishlistIds.add(pid);
        }
      }
    } catch (_) {
      // not logged in
    }

    List<dynamic> filtered = List.from(products);

    // 篩選：已購買
    if (_filters.purchasedOnly) {
      filtered = filtered
          .where(
              (p) => purchasedIds.contains((p as dynamic).id?.toString() ?? ''))
          .toList();
    }
    // 篩選：未購買收藏
    if (_filters.wishlistOnly) {
      filtered = filtered
          .where(
              (p) => wishlistIds.contains((p as dynamic).id?.toString() ?? ''))
          .toList();
    }
    // 篩選：推播中
    if (_filters.pushingOnly) {
      filtered = filtered
          .where(
              (p) => pushingIds.contains((p as dynamic).id?.toString() ?? ''))
          .toList();
    }

    // 篩選：可試讀（trialLimit > 0）
    if (_filters.trialOnly) {
      filtered = filtered.where((p) {
        try {
          final dyn = p as dynamic;
          final tl = dyn.trialLimit;
          if (tl is num && tl > 0) return true;
        } catch (_) {}
        return false;
      }).toList();
    }

    // 篩選：Level
    if (_filters.levels.isNotEmpty) {
      filtered = filtered.where((p) {
        try {
          final lv = (p as dynamic).level?.toString();
          return lv != null && _filters.levels.contains(lv);
        } catch (_) {
          return false;
        }
      }).toList();
    }

    // 排序
    if (_filters.sort == SearchSort.newest) {
      filtered.sort((a, b) {
        final oa = _orderOf(a);
        final ob = _orderOf(b);
        return ob.compareTo(oa);
      });
    } else if (_filters.sort == SearchSort.titleAZ) {
      filtered.sort((a, b) {
        final ta = _titleOf(a);
        final tb = _titleOf(b);
        return ta.compareTo(tb);
      });
    }

    return filtered;
  }

  int _orderOf(dynamic p) {
    try {
      final v = p.order;
      if (v is int) return v;
      if (v is num) return v.toInt();
    } catch (_) {}
    return -999999;
  }

  String _titleOf(dynamic p) {
    try {
      return (p.title ?? '').toString();
    } catch (_) {
      return '';
    }
  }

  Future<SearchFilters?> _openFiltersSheet(BuildContext context) {
    final tokens = context.tokens;

    return showModalBottomSheet<SearchFilters>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        SearchFilters temp = _filters;
        return StatefulBuilder(
          builder: (context, setModal) {
            Widget chip(String text, bool selected, VoidCallback onTap) {
              return FilterChip(
                label: Text(text),
                selected: selected,
                onSelected: (_) => onTap(),
              );
            }

            return Container(
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.75),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('篩選與排序',
                        style: TextStyle(
                            color: tokens.textPrimary,
                            fontWeight: FontWeight.w900,
                            fontSize: 16)),
                    const SizedBox(height: 12),
                    Text('狀態', style: TextStyle(color: tokens.textSecondary)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 10,
                      children: [
                        chip('已購買', temp.purchasedOnly, () {
                          setModal(() => temp = temp.copyWith(
                              purchasedOnly: !temp.purchasedOnly));
                        }),
                        chip('未購買收藏', temp.wishlistOnly, () {
                          setModal(() => temp =
                              temp.copyWith(wishlistOnly: !temp.wishlistOnly));
                        }),
                        chip('推播中', temp.pushingOnly, () {
                          setModal(() => temp =
                              temp.copyWith(pushingOnly: !temp.pushingOnly));
                        }),
                        chip('可試讀', temp.trialOnly, () {
                          setModal(() =>
                              temp = temp.copyWith(trialOnly: !temp.trialOnly));
                        }),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text('等級', style: TextStyle(color: tokens.textSecondary)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 10,
                      children: [
                        for (final lv in const ['L1', 'L2', 'L3', 'L4', 'L5'])
                          chip(lv, temp.levels.contains(lv), () {
                            final next = {...temp.levels};
                            if (next.contains(lv)) {
                              next.remove(lv);
                            } else {
                              next.add(lv);
                            }
                            setModal(() => temp = temp.copyWith(levels: next));
                          }),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text('排序', style: TextStyle(color: tokens.textSecondary)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 10,
                      children: [
                        chip('最相關', temp.sort == SearchSort.relevance, () {
                          setModal(() =>
                              temp = temp.copyWith(sort: SearchSort.relevance));
                        }),
                        chip('最新', temp.sort == SearchSort.newest, () {
                          setModal(() =>
                              temp = temp.copyWith(sort: SearchSort.newest));
                        }),
                        chip('名稱 A→Z', temp.sort == SearchSort.titleAZ, () {
                          setModal(() =>
                              temp = temp.copyWith(sort: SearchSort.titleAZ));
                        }),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () =>
                                setModal(() => temp = const SearchFilters()),
                            child: const Text('清除'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => Navigator.of(context).pop(temp),
                            child: const Text('套用'),
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
