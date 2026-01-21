import 'package:flutter/material.dart';

class SearchSuggestionsSection extends StatelessWidget {
  final void Function(String) onTap;
  const SearchSuggestionsSection({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    const guess = ['flutter ui 介面設計', '錯題本 app 推薦', '推播習慣怎麼設定'];
    const trending = ['AI', '宇宙', '美學', '健康', '理財', '心態鍛鍊'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        const Text('猜你想搜', style: TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        ...guess.map((e) => ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(e),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => onTap(e),
            )),
        const SizedBox(height: 10),
        const Text('熱門關鍵字', style: TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: trending
              .map((t) => ActionChip(
                    label: Text(t),
                    onPressed: () => onTap(t),
                  ))
              .toList(),
        ),
      ],
    );
  }
}
