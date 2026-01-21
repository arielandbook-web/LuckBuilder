import 'package:flutter/material.dart';
import '../../bubble_library/models/user_library.dart';

String pushHintFor(UserLibraryProduct lp) {
  final cfg = lp.pushConfig;

  final freq = cfg.freqPerDay.clamp(1, 5);
  final mode = cfg.timeMode.name;

  // presetSlots: ['morning','noon','evening','night']
  String slotLabel(String s) {
    switch (s) {
      case 'morning':
        return '早';
      case 'noon':
        return '午';
      case 'evening':
        return '晚';
      case 'night':
        return '夜';
      default:
        return s;
    }
  }

  String tod(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  String timesText() {
    if (cfg.timeMode.name == 'custom' && cfg.customTimes.isNotEmpty) {
      final list = List<TimeOfDay>.from(cfg.customTimes);
      list.sort((a, b) => (a.hour * 60 + a.minute).compareTo(b.hour * 60 + b.minute));
      final shown = list.take(5).map(tod).join('、');
      return '自訂 $shown';
    }

    // preset
    final slots = cfg.presetSlots.isEmpty ? ['night'] : cfg.presetSlots;
    final shown = slots.take(4).map(slotLabel).join('·');
    return '時段 $shown';
  }

  return '頻率 $freq/天 · $mode · ${timesText()}';
}
