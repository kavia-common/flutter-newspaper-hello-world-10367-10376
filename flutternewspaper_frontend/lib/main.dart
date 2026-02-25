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

  final db = SavedNewsDb();
  await db.ensureInitialized();

  runApp(
    MultiProvider(
      providers: [
        Provider<SavedNewsDb>.value(value: db),
        ChangeNotifierProvider<NewsAppState>(
          create: (_) => NewsAppState(db: db)..init(),
        ),
      ],
      child: const MyApp(),
    ),
  );
}

/// Root Flutter application for the migrated newspaper/news reader app.
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const NewsApp();
  }
}
