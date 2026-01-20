import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';

class TimezoneInit {
  static bool _inited = false;

  static Future<void> ensureInitialized() async {
    if (_inited) return;
    tz.initializeTimeZones();
    final localTz = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(localTz));
    _inited = true;
  }
}
