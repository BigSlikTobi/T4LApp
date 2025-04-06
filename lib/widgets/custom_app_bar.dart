import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:app/providers/language_provider.dart';

// Debug toggle for CustomAppBar
bool customAppBarDebug = false;

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  const CustomAppBar({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    if (customAppBarDebug) {
      debugPrint('[CustomAppBar] Building AppBar');
    }

    final languageProvider = Provider.of<LanguageProvider>(context);
    final double baseHeight = kToolbarHeight - 12;
    final double increasedHeight = baseHeight * 1.5;

    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      toolbarHeight: kToolbarHeight,
      title: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6.0),
        child: FittedBox(
          fit: BoxFit.contain,
          child: Image.asset(
            'assets/images/T4LLogo.png',
            height: increasedHeight,
            errorBuilder: (context, error, stackTrace) {
              if (customAppBarDebug) {
                debugPrint(
                  '[CustomAppBar] Error loading logo asset: $error\nStackTrace: $stackTrace',
                );
              }
              return const Icon(Icons.error);
            },
          ),
        ),
      ),
      centerTitle: true,
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 8.0),
          child: PopupMenuButton<String>(
            offset: const Offset(0, 40),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            onOpened: () {
              if (customAppBarDebug) {
                debugPrint('[CustomAppBar] Language menu opened');
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Color.fromRGBO(0, 0, 0, 0.3)),
              ),
              child: Text(
                languageProvider.currentLanguage == LanguageProvider.german
                    ? '🇩🇪'
                    : '🇺🇸',
                style: const TextStyle(fontSize: 18),
              ),
            ),
            onSelected: (String value) {
              if (customAppBarDebug) {
                debugPrint('[CustomAppBar] Language changed to: $value');
              }
              languageProvider.switchLanguage(value);
            },
            itemBuilder:
                (BuildContext context) => <PopupMenuEntry<String>>[
                  const PopupMenuItem<String>(
                    value: LanguageProvider.english,
                    child: Row(
                      children: [
                        Text('🇺🇸', style: TextStyle(fontSize: 12)),
                        SizedBox(width: 8),
                        Text('English'),
                      ],
                    ),
                  ),
                  const PopupMenuItem<String>(
                    value: LanguageProvider.german,
                    child: Row(
                      children: [
                        Text('🇩🇪', style: TextStyle(fontSize: 12)),
                        SizedBox(width: 8),
                        Text('Deutsch'),
                      ],
                    ),
                  ),
                ],
          ),
        ),
      ],
    );
  }
}
