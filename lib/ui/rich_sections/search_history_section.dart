import 'package:flutter/material.dart';
import 'user_state_store.dart';

class SearchHistorySection extends StatefulWidget {
  final void Function(String) onTapQuery;
  const SearchHistorySection({super.key, required this.onTapQuery});

  @override
  State<SearchHistorySection> createState() => SearchHistorySectionState();
}

class SearchHistorySectionState extends State<SearchHistorySection> {
  final _store = UserStateStore();
  bool _loading = true;
  List<String> _recent = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final r = await _store.getRecentSearches();
    if (mounted) {
      setState(() {
        _recent = r;
        _loading = false;
      });
    }
  }

  Future<void> reload() async {
    await _load();
  }

  Future<void> _clear() async {
    await _store.clearRecentSearches();
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const LinearProgressIndicator();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
                child: Text('歷史記錄',
                    style: TextStyle(fontWeight: FontWeight.w800))),
            if (_recent.isNotEmpty)
              IconButton(
                onPressed: _clear,
                icon: const Icon(Icons.delete_outline),
                tooltip: '清除',
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (_recent.isEmpty)
          Text('還沒有搜尋紀錄', style: Theme.of(context).textTheme.bodySmall)
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _recent
                .map((q) => ActionChip(
                      label: Text(q),
                      onPressed: () => widget.onTapQuery(q),
                    ))
                .toList(),
          ),
      ],
    );
  }
}
