import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';

import 'src/app.dart';
import 'src/data/db/saved_news_db.dart';
import 'src/state/news_app_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load config, but do not hard-fail if the .env file is missing.
  // This keeps Flutter preview / Appetize / CI running without manual env setup.
  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {
    // Intentionally ignore. The app will fall back to mock data and show a setup message.
  }

  runApp(const MyApp());
}

/// Root Flutter application for the migrated newspaper/news reader app.
///
/// Important: This widget owns the app-wide Provider wiring so that previews,
/// widget tests, and any embedding that pumps `MyApp()` will always include the
/// required dependencies (e.g., `NewsAppState`).
class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final SavedNewsDb _db;
  late final Future<void> _initFuture;

  @override
  void initState() {
    super.initState();
    _db = SavedNewsDb();
    _initFuture = _db.ensureInitialized();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _initFuture,
      builder: (context, snapshot) {
        // If DB init fails for some reason, show a visible error rather than a blank screen.
        if (snapshot.hasError) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            home: Scaffold(
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('Failed to initialize app: ${snapshot.error}'),
                ),
              ),
            ),
          );
        }

        // While DB initializes, show a lightweight splash/progress screen.
        if (snapshot.connectionState != ConnectionState.done) {
          return const MaterialApp(
            debugShowCheckedModeBanner: false,
            home: Scaffold(
              body: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        return MultiProvider(
          providers: [
            Provider<SavedNewsDb>.value(value: _db),
            ChangeNotifierProvider<NewsAppState>(
              create: (_) => NewsAppState(db: _db)..init(),
            ),
          ],
          child: const NewsApp(),
        );
      },
    );
  }
}
