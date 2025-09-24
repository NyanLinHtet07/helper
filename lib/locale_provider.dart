import 'package:flutter/material.dart';

class LocaleProvider with ChangeNotifier {
  Locale? _locale;

  LocaleProvider(this._locale);

  Locale? get locale => _locale;

  void setLocale(Locale newLocale) {
    if (_locale != newLocale) {
      _locale = newLocale;
      notifyListeners();
    }
  }

  void clearLocale() {
    _locale = null;
    notifyListeners();
  }
}
