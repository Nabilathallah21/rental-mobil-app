import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart'; // <-- 1. Import dotenv
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/main_navigation_wrapper.dart';

// Inisialisasi global client Supabase agar bisa dipanggil di mana saja
final supabase = Supabase.instance.client;

Future<void> main() async {
  // Wajib ada untuk inisialisasi async sebelum runApp
  WidgetsFlutterBinding.ensureInitialized();

  // 2. Muat file .env terlebih dahulu
  await dotenv.load(fileName: ".env");

  // 3. Inisialisasi koneksi Supabase menggunakan data dari .env
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    publishableKey: dotenv.env['SUPABASE_ANON_KEY']!, 
  );

  runApp(const ZahiraTransApp());
}

class ZahiraTransApp extends StatefulWidget {
  const ZahiraTransApp({super.key});

  @override
  State<ZahiraTransApp> createState() => _ZahiraTransAppState();
}

class _ZahiraTransAppState extends State<ZahiraTransApp> {
  ThemeMode _themeMode = ThemeMode.dark;

  void _toggleTheme() {
    setState(() {
      _themeMode =
          _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Zahira Trans',
      themeMode: _themeMode,
      theme: ThemeData(
        brightness: Brightness.light,
        primaryColor: const Color(0xFF10B981),
        scaffoldBackgroundColor: const Color(0xFFF3F4F6),
        cardColor: Colors.white,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF10B981),
          brightness: Brightness.light,
        ),
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: const Color(0xFF10B981),
        scaffoldBackgroundColor: const Color(0xFF1A1A1A),
        cardColor: const Color(0xFF242424),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF10B981),
          brightness: Brightness.dark,
        ),
      ),
      home: MainNavigationWrapper(
        toggleTheme: _toggleTheme,
        themeMode: _themeMode,
      ),
    );
  }
}