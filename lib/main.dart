import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/auth_service.dart';
import 'services/theme_service.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';

void main() {
  // Ensure Flutter binding is initialized
  WidgetsFlutterBinding.ensureInitialized();
  
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeService()),
        ChangeNotifierProvider(create: (_) => AuthService()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeService = Provider.of<ThemeService>(context);
    final authService = Provider.of<AuthService>(context);

    // Curated Harmonious Modern Theme Systems
    
    // Sleek, futuristic slate Dark theme
    final darkTheme = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF1E3C72),
        brightness: Brightness.dark,
        primary: const Color(0xFF2A5298),
        secondary: const Color(0xFF00BCD4),
        surface: const Color(0xFF1E293B),
      ),
      scaffoldBackgroundColor: const Color(0xFF0F172A),
      cardTheme: const CardThemeData(
        color: Color(0xFF1E293B),
        elevation: 2,
        margin: EdgeInsets.zero,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF0F172A),
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      tabBarTheme: const TabBarThemeData(
        labelColor: Colors.blueAccent,
        unselectedLabelColor: Colors.white60,
      ),
    );

    // Sleek, clean minimalist Light theme
    final lightTheme = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF1E3C72),
        brightness: Brightness.light,
        primary: const Color(0xFF1E3C72),
        secondary: const Color(0xFF00BCD4),
        surface: Colors.white,
      ),
      scaffoldBackgroundColor: const Color(0xFFF8FAFC),
      cardTheme: const CardThemeData(
        color: Colors.white,
        elevation: 1,
        margin: EdgeInsets.zero,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: Color(0xFF1E3C72),
        elevation: 0.5,
        centerTitle: true,
      ),
      tabBarTheme: const TabBarThemeData(
        labelColor: Color(0xFF1E3C72),
        unselectedLabelColor: Colors.black54,
      ),
    );

    return MaterialApp(
      title: 'ProdTrack',
      debugShowCheckedModeBanner: false,
      themeMode: themeService.themeMode,
      theme: lightTheme,
      darkTheme: darkTheme,
      home: authService.isAuthenticated ? const DashboardScreen() : const LoginScreen(),
    );
  }
}
