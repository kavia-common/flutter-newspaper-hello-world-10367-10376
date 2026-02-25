import 'package:flutter/material.dart';

import 'screens/home/home_screen.dart';
import 'screens/read/read_article_screen.dart';
import 'screens/saved/saved_news_screen.dart';

class NewsApp extends StatelessWidget {
  const NewsApp({super.key});

  static const _primary = Color(0xFFFFFFFF);
  static const _onPrimary = Color(0xFF1B262C);
  static const _secondary = Color(0xFF0F4C75);
  static const _accent = Color(0xFF1E90FF);

  ThemeData _theme() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: _secondary,
      brightness: Brightness.light,
      primary: _primary,
      onPrimary: _onPrimary,
      secondary: _secondary,
      onSecondary: Colors.white,
      surface: Colors.white,
      onSurface: _onPrimary,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: Colors.white,
      appBarTheme: const AppBarTheme(
        backgroundColor: _primary,
        foregroundColor: _onPrimary,
        centerTitle: true,
        elevation: 0,
      ),
      tabBarTheme: const TabBarTheme(
        labelColor: _accent,
        unselectedLabelColor: _onPrimary,
        indicatorColor: _accent,
        tabAlignment: TabAlignment.start,
        isScrollable: true,
      ),
      cardTheme: CardTheme(
        color: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'News App',
      debugShowCheckedModeBanner: false,
      theme: _theme(),
      routes: {
        HomeScreen.routeName: (_) => const HomeScreen(),
        SavedNewsScreen.routeName: (_) => const SavedNewsScreen(),
      },
      // ReadArticle uses arguments, so it is handled by onGenerateRoute
      onGenerateRoute: (settings) {
        if (settings.name == ReadArticleScreen.routeName) {
          final args = settings.arguments;
          if (args is ReadArticleArgs) {
            return MaterialPageRoute<void>(
              builder: (_) => ReadArticleScreen(args: args),
              settings: settings,
            );
          }
          return MaterialPageRoute<void>(
            builder: (_) => const _BadRouteScreen(message: 'Missing ReadArticleArgs'),
            settings: settings,
          );
        }
        return null;
      },
      initialRoute: HomeScreen.routeName,
    );
  }
}

class _BadRouteScreen extends StatelessWidget {
  const _BadRouteScreen({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Navigation error')),
      body: Center(child: Text(message)),
    );
  }
}
