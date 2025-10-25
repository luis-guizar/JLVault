import 'package:flutter/foundation.dart';

enum AppLanguage { english, spanish }

class LanguageService extends ChangeNotifier {
  static final LanguageService _instance = LanguageService._internal();
  static LanguageService get instance => _instance;

  LanguageService._internal();

  AppLanguage _currentLanguage = AppLanguage.spanish; // Default to Spanish

  AppLanguage get currentLanguage => _currentLanguage;
  bool get isSpanish => _currentLanguage == AppLanguage.spanish;
  bool get isEnglish => _currentLanguage == AppLanguage.english;

  void setLanguage(AppLanguage language) {
    if (_currentLanguage != language) {
      _currentLanguage = language;
      notifyListeners();
    }
  }

  void toggleLanguage() {
    setLanguage(
      _currentLanguage == AppLanguage.spanish
          ? AppLanguage.english
          : AppLanguage.spanish,
    );
  }

  String get languageCode {
    switch (_currentLanguage) {
      case AppLanguage.english:
        return 'en';
      case AppLanguage.spanish:
        return 'es';
    }
  }

  String get languageName {
    switch (_currentLanguage) {
      case AppLanguage.english:
        return 'English';
      case AppLanguage.spanish:
        return 'Español';
    }
  }
}
