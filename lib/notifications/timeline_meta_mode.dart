import 'package:flutter_riverpod/flutter_riverpod.dart';

enum TimelineMetaMode { day, push, nth }

final timelineMetaModeProvider =
    StateProvider<TimelineMetaMode>((ref) => TimelineMetaMode.day);
