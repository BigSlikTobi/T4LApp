import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'package:shared_preferences/shared_preferences.dart';

class LanguageProvider extends ChangeNotifier {
  static const String _prefsKey = 'app_language';

  // Supported languages
  static const String english = 'en';
  static const String german = 'de';

  // Current language
  late String _currentLanguage;

  // Getter for current language
  String get currentLanguage => _currentLanguage;

  // Constructor - initialize with device language or saved preference
  LanguageProvider() {
    _initializeLanguage();
  }

  // Get device language and set initial language
  String _getDeviceLanguage() {
    final deviceLocale = ui.window.locale.languageCode.toLowerCase();
    return deviceLocale == german ? german : english;
  }

  // Initialize language with saved preference or device language
  Future<void> _initializeLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    final savedLanguage = prefs.getString(_prefsKey);

    if (savedLanguage != null &&
        (savedLanguage == english || savedLanguage == german)) {
      _currentLanguage = savedLanguage;
    } else {
      _currentLanguage = _getDeviceLanguage();
      // Save the initial language preference
      await prefs.setString(_prefsKey, _currentLanguage);
    }
    notifyListeners();
  }

  // Change language method
  Future<void> switchLanguage(String languageCode) async {
    if (languageCode == _currentLanguage) return;

    if (languageCode == english || languageCode == german) {
      _currentLanguage = languageCode;

      // Save to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, languageCode);

      notifyListeners();
    }
  }

  // Toggle between English and German
  Future<void> toggleLanguage() async {
    String newLanguage = _currentLanguage == english ? german : english;
    await switchLanguage(newLanguage);
  }
}
