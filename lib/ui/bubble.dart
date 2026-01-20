import 'package:flutter/material.dart';

class BubbleCircle extends StatelessWidget {
  final String title;
  final VoidCallback onTap;

  const BubbleCircle({super.key, required this.title, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        width: 96,
        child: Column(
          children: [
            Container(
              width: 82,
              height: 82,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.30),
                border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
              ),
              child: const Center(child: Icon(Icons.auto_awesome, size: 22)),
            ),
            const SizedBox(height: 8),
            Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
