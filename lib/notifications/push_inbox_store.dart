import 'package:shared_preferences/shared_preferences.dart';

class PushInboxStore {
  static const _prefix = 'push_opened_v1';

  String _key(String contentItemId) => '$_prefix:$contentItemId';

  Future<void> markOpened(String contentItemId) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setBool(_key(contentItemId), true);
  }

  Future<bool> isOpened(String contentItemId) async {
    final sp = await SharedPreferences.getInstance();
    return sp.getBool(_key(contentItemId)) == true;
  }
}
