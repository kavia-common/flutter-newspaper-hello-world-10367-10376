import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';

import 'src/app.dart';
import 'src/data/db/saved_news_db.dart';
import 'src/state/news_app_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load config. If .env is missing, app still runs but API calls will fail with a clear message.
  await dotenv.load(fileName: '.env');

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
