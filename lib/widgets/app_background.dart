import 'package:flutter/material.dart';
import '../theme/app_tokens.dart';

class AppBackground extends StatelessWidget {
  final Widget child;
  const AppBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: t.bg,
        gradient: t.bgGradient,
      ),
      child: child,
    );
  }
}
