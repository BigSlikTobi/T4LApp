import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

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

  // Helper method to encode text with UTF-8
  String _encodeText(String text) {
    return base64Encode(utf8.encode(text));
  }

  // Helper method to decode text with UTF-8
  String _decodeText(String encodedText) {
    try {
      return utf8.decode(base64Decode(encodedText));
    } catch (e) {
      return encodedText; // Fallback for non-encoded text
    }
  }

  // Initialize language with saved preference or device language
  Future<void> _initializeLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    final savedLanguage = prefs.getString(_prefsKey);

    if (savedLanguage != null) {
      final decodedLanguage = _decodeText(savedLanguage);
      if (decodedLanguage == english || decodedLanguage == german) {
        _currentLanguage = decodedLanguage;
      } else {
        _currentLanguage = _getDeviceLanguage();
      }
    } else {
      _currentLanguage = _getDeviceLanguage();
    }

    // Save with proper encoding
    await prefs.setString(_prefsKey, _encodeText(_currentLanguage));
    notifyListeners();
  }

  // Change language method
  Future<void> switchLanguage(String languageCode) async {
    if (languageCode == _currentLanguage) return;

    if (languageCode == english || languageCode == german) {
      _currentLanguage = languageCode;

      // Save to SharedPreferences with encoding
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, _encodeText(languageCode));

      notifyListeners();
    }
  }

  // Toggle between English and German
  Future<void> toggleLanguage() async {
    String newLanguage = _currentLanguage == english ? german : english;
    await switchLanguage(newLanguage);
  }
}
