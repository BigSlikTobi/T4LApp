import 'package:flutter/material.dart';
import 'package:app/services/supabase_service.dart';
import 'package:app/config.dart';
import 'package:app/utils/logger.dart';
import 'package:provider/provider.dart';
import 'package:app/providers/language_provider.dart';
import 'navbar.dart';
import 'news.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize logger
  AppLogger.initialize();

  // Initialize Supabase
  await SupabaseService.initialize(
    url: AppConfig.supabaseUrl,
    anonKey: AppConfig.supabaseAnonKey,
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LanguageProvider()),
      ],
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
      theme: ThemeData(
        // Base colors
        primaryColor: metallicGreen,
        scaffoldBackgroundColor: Colors.white,

        // AppBar theme
        appBarTheme: AppBarTheme(
          backgroundColor: const Color.fromARGB(255, 3, 17, 8),
          elevation: 0,
        ),

        // Text theme
        textTheme: TextTheme(
          headlineLarge: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
          headlineMedium: TextStyle(
            color: metallicGreen,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
          bodyLarge: TextStyle(fontWeight: FontWeight.w600, letterSpacing: 0.5),
          bodyMedium: TextStyle(
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

        appBarTheme: AppBarTheme(
          backgroundColor: deepMetallicGreen,
          elevation: 0,
        ),

        textTheme: TextTheme(
          headlineLarge: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
          headlineMedium: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
          bodyLarge: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
          bodyMedium: TextStyle(
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
      home: HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final List<Widget> _pages = [
    News(),
    Center(child: Text('Drills')),
    Center(child: Text('Teams')),
    Center(child: Text('Schedule')),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: _pages[0], // Start with News page
      ),
      bottomNavigationBar: Navbar(),
    );
  }
}
