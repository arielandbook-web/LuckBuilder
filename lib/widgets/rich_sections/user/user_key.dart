import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../bubble_library/providers/providers.dart';

class UserKey {
  static const local = 'local';

  /// 可在任何有 BuildContext 的地方使用（不用 WidgetRef）
  static String uidOrLocalFromContext(BuildContext context) {
    try {
      return ProviderScope.containerOf(context).read(uidProvider);
    } catch (_) {
      return local;
    }
  }
}
