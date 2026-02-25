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

  @override
  void initState() {
    super.initState();
    _db = SavedNewsDb();

    // Fire-and-forget initialization so the UI is never blocked (prevents blank
    // preview/test screens in environments where sqflite isn't supported).
    //
    // Note: no BuildContext usage here.
    _db.ensureInitialized();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<SavedNewsDb>.value(value: _db),
        ChangeNotifierProvider<NewsAppState>(
          create: (_) => NewsAppState(db: _db)..init(),
        ),
      ],
      child: const NewsApp(),
    );
  }
}
