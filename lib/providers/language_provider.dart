import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class LanguageProvider extends ChangeNotifier {
  static const String _prefsKey = 'app_language';

  // Supported languages
  static const String english = 'en';
  static const String german = 'de';

  // Initialize with default value instead of using late
  String _currentLanguage = english; // Default to English

  // Getter for current language
  String get currentLanguage => _currentLanguage;

  // Constructor - initialize with device language or saved preference
  LanguageProvider() {
    _initializeLanguage();
  }

  // Get device language and set initial language
  String _getDeviceLanguage() {
    final deviceLocale =
        ui.PlatformDispatcher.instance.locale.languageCode.toLowerCase();
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
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedLanguage = prefs.getString(_prefsKey);

      String newLanguage;
      if (savedLanguage != null) {
        final decodedLanguage = _decodeText(savedLanguage);
        newLanguage =
            (decodedLanguage == english || decodedLanguage == german)
                ? decodedLanguage
                : _getDeviceLanguage();
      } else {
        newLanguage = _getDeviceLanguage();
      }

      _currentLanguage = newLanguage;
      // Save with proper encoding
      await prefs.setString(_prefsKey, _encodeText(_currentLanguage));
      notifyListeners();
    } catch (e) {
      // Keep default value if initialization fails
      debugPrint('Error initializing language: $e');
    }
  }

  // Change language method
  Future<void> switchLanguage(String languageCode) async {
    if (languageCode == _currentLanguage) return;

    if (languageCode == english || languageCode == german) {
      _currentLanguage = languageCode;

      // Save to SharedPreferences with encoding
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_prefsKey, _encodeText(languageCode));
        notifyListeners();
      } catch (e) {
        debugPrint('Error saving language preference: $e');
      }
    }
  }

  // Toggle between English and German
  Future<void> toggleLanguage() async {
    String newLanguage = _currentLanguage == english ? german : english;
    await switchLanguage(newLanguage);
  }
}
