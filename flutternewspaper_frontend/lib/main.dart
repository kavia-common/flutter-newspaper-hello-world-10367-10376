import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'src/app.dart';
import 'src/core/env.dart';
import 'src/data/db/saved_news_db.dart';
import 'src/state/news_app_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Ensure Flutter framework errors don't take down the preview for recoverable
  // issues (e.g., offline DNS failures). We still report them for debugging.
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    if (kDebugMode) {
      // ignore: avoid_print
      print('Non-fatal FlutterError: ${details.exception}');
    }
  };

  // Catch any uncaught async exceptions that would otherwise crash the preview.
  await runZonedGuarded<Future<void>>(() async {
    // Load config. If .env is missing/unavailable, app still runs but API calls
    // will fail with a clear message (and the UI falls back to mock data).
    await Env.load();

    final db = SavedNewsDb();
    await db.ensureInitialized();

    runApp(
      MultiProvider(
        providers: [
          Provider<SavedNewsDb>.value(value: db),
          ChangeNotifierProvider<NewsAppState>(
            // init() is async; any unexpected uncaught errors will now be trapped by the zone.
            create: (_) => NewsAppState(db: db)..init(),
          ),
        ],
        child: const MyApp(),
      ),
    );
  }, (Object error, StackTrace stackTrace) {
    if (kDebugMode) {
      // ignore: avoid_print
      print('Non-fatal uncaught error (guarded zone): $error');
      // ignore: avoid_print
      print(stackTrace);
    }
  });
}

/// Root Flutter application for the migrated newspaper/news reader app.
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const NewsApp();
  }
}
