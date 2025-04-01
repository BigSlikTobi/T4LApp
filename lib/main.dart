import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import 'package:app/utils/logger.dart';
import 'package:provider/provider.dart';
import 'package:app/providers/language_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:app/config.dart';
import 'navbar.dart';
import 'news.dart';
import 'teams_page.dart';
import 'package:app/widgets/custom_app_bar.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize logger
  AppLogger.initialize();

  // Initialize Supabase
  await Supabase.initialize(
    url: 'https://yqtiuzhedkfacwgormhn.supabase.co',
    anonKey: AppConfig.apiKey,
  );

  // Set system UI overlay style globally to prevent dark status bar
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent, // Transparent status bar
      statusBarIconBrightness:
          Brightness.dark, // Dark icons for light background
      statusBarBrightness: Brightness.light, // Light status bar for iOS
    ),
  );

  runApp(
    MultiProvider(
      providers: [ChangeNotifierProvider(create: (_) => LanguageProvider())],
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  // Define our custom colors
  static const metallicGreen = Color(0xFF1A472A);
  static const deepMetallicGreen = Color(0xFF0D3320);

  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mocked App',
      locale:
          Provider.of<LanguageProvider>(context).currentLanguage ==
                  LanguageProvider.german
              ? const Locale('de', 'DE')
              : const Locale('en', 'US'),
      theme: ThemeData(
        // Base colors
        primaryColor: metallicGreen,
        scaffoldBackgroundColor: Colors.white,
        fontFamily: 'Noto Sans',

        // AppBar theme - Updated to use transparent background
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent, // Transparent background
          elevation: 0,
          systemOverlayStyle: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.dark,
            statusBarBrightness: Brightness.light,
          ),
        ),

        // Text theme with Noto Sans
        textTheme: const TextTheme(
          headlineLarge: TextStyle(
            fontFamily: 'Noto Sans',
            color: Colors.white,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
          headlineMedium: TextStyle(
            fontFamily: 'Noto Sans',
            color: metallicGreen,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
          bodyLarge: TextStyle(
            fontFamily: 'Noto Sans',
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
          bodyMedium: TextStyle(
            fontFamily: 'Noto Sans',
            fontWeight: FontWeight.w500,
            letterSpacing: 0.3,
          ),
        ),

        // Button themes
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: Colors.white,
            textStyle: TextStyle(
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ),

        // Icon theme
        iconTheme: IconThemeData(color: Colors.white),

        // Color scheme
        colorScheme: ColorScheme.light(
          primary: metallicGreen,
          secondary: deepMetallicGreen,
          onPrimary: Colors.white,
          onSecondary: Colors.white,
        ),
      ),
      darkTheme: ThemeData(
        // Dark theme with similar styling but darker background
        primaryColor: deepMetallicGreen,
        scaffoldBackgroundColor: Colors.grey[900],
        fontFamily: 'Noto Sans',

        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent, // Transparent background
          elevation: 0,
          systemOverlayStyle: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.dark,
            statusBarBrightness: Brightness.light,
          ),
        ),

        textTheme: const TextTheme(
          headlineLarge: TextStyle(
            fontFamily: 'Noto Sans',
            color: Colors.white,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
          headlineMedium: TextStyle(
            fontFamily: 'Noto Sans',
            color: Colors.white,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
          bodyLarge: TextStyle(
            fontFamily: 'Noto Sans',
            color: Colors.white,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
          bodyMedium: TextStyle(
            fontFamily: 'Noto Sans',
            color: Colors.white,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.3,
          ),
        ),

        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: Colors.white,
            textStyle: TextStyle(
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ),

        iconTheme: IconThemeData(color: Colors.white),

        colorScheme: ColorScheme.dark(
          primary: metallicGreen,
          secondary: deepMetallicGreen,
          onPrimary: Colors.white,
          onSecondary: Colors.white,
          surface: Colors.grey[850]!,
        ),
      ),
      home: const GlassmorphicHome(),
    );
  }
}

class GlassmorphicHome extends StatefulWidget {
  const GlassmorphicHome({super.key});

  @override
  State<GlassmorphicHome> createState() => _GlassmorphicHomeState();
}

class _GlassmorphicHomeState extends State<GlassmorphicHome> {
  int _currentIndex = 0;

  final List<Widget> _pages = [
    News(),
    Center(child: Text('Drills')),
    TeamsPage(),
    Center(child: Text('Schedule')),
  ];

  void _onNavigationChange(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(),
      body: SafeArea(child: _pages[_currentIndex]),
      bottomNavigationBar: Navbar(onIndexChanged: _onNavigationChange),
    );
  }
}
