import 'package:flutter/material.dart';
import '../../../theme/app_tokens.dart';
import '../../app_card.dart';

class CategoryDynamicRailsSection extends StatelessWidget {
  const CategoryDynamicRailsSection({super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    const recent = ['AI', '宇宙', '理財'];
    const tryMore = ['美學', '健康'];

    Widget chip(String s) => Padding(
          padding: const EdgeInsets.only(right: 8),
          child: ActionChip(
            label: Text(s),
            labelStyle: TextStyle(color: tokens.textPrimary),
            backgroundColor: tokens.chipBg,
            side: BorderSide(color: tokens.cardBorder),
            onPressed: () {},
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('你最近常看',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: tokens.textPrimary)),
        const SizedBox(height: 8),
        AppCard(
          child: Wrap(children: recent.map(chip).toList()),
        ),
        const SizedBox(height: 14),
        Text('你可能想試',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: tokens.textPrimary)),
        const SizedBox(height: 8),
        AppCard(
          child: Wrap(children: tryMore.map(chip).toList()),
        ),
      ],
    );
  }
}
