import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kLocaleKey = 'app_locale_mode';

/// `null` = 跟随系统；否则为固定界面语言。
class LocaleController extends ChangeNotifier {
  Locale? _locale;

  Locale? get locale => _locale;

  Future<void> load() async {
    final sp = await SharedPreferences.getInstance();
    final v = sp.getString(_kLocaleKey);
    if (v == null || v == 'system') {
      _locale = null;
    } else if (v == 'en') {
      _locale = const Locale('en', 'US');
    } else {
      _locale = const Locale('zh', 'CN');
    }
    notifyListeners();
  }

  Future<void> setFollowSystem() async {
    _locale = null;
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kLocaleKey, 'system');
    notifyListeners();
  }

  Future<void> setChinese() async {
    _locale = const Locale('zh', 'CN');
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kLocaleKey, 'zh');
    notifyListeners();
  }

  Future<void> setEnglish() async {
    _locale = const Locale('en', 'US');
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kLocaleKey, 'en');
    notifyListeners();
  }

  String get modeLabel {
    if (_locale == null) return 'system';
    if (_locale!.languageCode == 'en') return 'en';
    return 'zh';
  }
}
