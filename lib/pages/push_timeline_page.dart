import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../notifications/push_timeline_list.dart';

class PushTimelinePage extends ConsumerWidget {
  const PushTimelinePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('未來 3 天時間表'),
      ),
      body: const PushTimelineList(showTopBar: true),
    );
  }
}


