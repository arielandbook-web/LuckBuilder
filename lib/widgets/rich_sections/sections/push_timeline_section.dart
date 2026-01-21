import 'package:flutter/material.dart';
import '../../../theme/app_tokens.dart';
import '../../app_card.dart';

class PushTimelineSection extends StatelessWidget {
  const PushTimelineSection({super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    // 先用示意資料，之後接你現有排程（你已經是排 3 天）
    final items = [
      ('今天 08:30', '宇宙 L1', 'Day 12：黑洞是什麼？'),
      ('明天 08:30', 'AI 入門', 'Day 3：什麼是模型？'),
      ('後天 08:30', '美學', 'Day 5：配色三原則'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('未來 3 天推播',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: tokens.textPrimary)),
        const SizedBox(height: 10),
        AppCard(
          child: Column(
            children: items.map((e) {
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.notifications, color: tokens.primary),
                title: Text(e.$2,
                    style: TextStyle(
                        color: tokens.textPrimary,
                        fontWeight: FontWeight.w700)),
                subtitle: Text('${e.$1} · ${e.$3}',
                    style: TextStyle(color: tokens.textSecondary)),
                trailing:
                    Icon(Icons.chevron_right, color: tokens.textSecondary),
                onTap: () {},
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 14),
        Text('勿擾時段',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: tokens.textPrimary)),
        const SizedBox(height: 10),
        AppCard(
          child: Row(
            children: [
              Icon(Icons.bedtime, color: tokens.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text('22:30 - 08:00（示意）',
                    style: TextStyle(
                        color: tokens.textPrimary,
                        fontWeight: FontWeight.w700)),
              ),
              OutlinedButton(
                onPressed: () {},
                child: const Text('設定'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
