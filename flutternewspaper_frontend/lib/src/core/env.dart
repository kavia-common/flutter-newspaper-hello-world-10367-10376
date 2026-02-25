import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Utilities for environment/config loading.
///
/// Why this exists:
/// - In some preview/sandbox runtimes, reading `.env` from the process working
///   directory can be unreliable.
/// - Loading from Flutter assets is the most consistent approach because it is
///   bundled into the app when declared under `flutter: assets:` in pubspec.yaml.
class Env {
  Env._();

  // PUBLIC_INTERFACE
  /// Loads environment variables for the app.
  ///
  /// Strategy:
  /// 1) Try to load `.env` from Flutter assets (most reliable in preview).
  /// 2) If that fails, try to load `.env` as a file from the current working dir.
  /// 3) Never throw: the rest of the app will show a clear error message if keys
  ///    are missing, but the UI should still run (and fall back to mock data).
  static Future<void> load() async {
    // Attempt #1: asset-based load (reliable in Flutter runtime environments).
    try {
      final envString = await rootBundle.loadString('.env');
      dotenv.testLoad(fileInput: envString);
      return;
    } catch (e) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('Env.load: could not load .env from assets: $e');
      }
    }

    // Attempt #2: file-based load (useful in local runs where .env sits next to pubspec).
    try {
      await dotenv.load(fileName: '.env');
      return;
    } catch (e) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('Env.load: could not load .env from file system: $e');
      }
    }
  }
}
