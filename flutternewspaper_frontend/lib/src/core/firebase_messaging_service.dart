import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

/// Firebase Cloud Messaging helper utilities.
///
/// Notes:
/// - This app already includes Android `google-services.json`.
/// - On iOS, additional Apple Push Notification setup is required for real device tokens.
///
/// This service is intentionally minimal: it exists to support a UI screen that
/// can display/copy the current FCM registration token for push testing.
class FirebaseMessagingService {
  FirebaseMessagingService._();

  static bool _initialized = false;

  /// PUBLIC_INTERFACE
  /// Ensures Firebase is initialized.
  ///
  /// Safe to call multiple times; subsequent calls are no-ops.
  static Future<void> ensureInitialized() async {
    if (_initialized) return;

    try {
      // In normal app runs, this initializes using platform config.
      // If already initialized elsewhere, this throws; we treat that as non-fatal.
      await Firebase.initializeApp();
    } catch (e) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('FirebaseMessagingService.ensureInitialized: Firebase.initializeApp failed/ignored: $e');
      }
    }

    _initialized = true;
  }

  /// PUBLIC_INTERFACE
  /// Requests notification permissions where applicable.
  ///
  /// Returns the resulting settings. If unavailable, returns null.
  static Future<NotificationSettings?> requestPermission() async {
    try {
      final messaging = FirebaseMessaging.instance;

      // iOS/macOS: prompts user; Android: generally returns authorized by default.
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      return settings;
    } catch (e) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('FirebaseMessagingService.requestPermission failed: $e');
      }
      return null;
    }
  }

  /// PUBLIC_INTERFACE
  /// Fetches the current FCM registration token for this device/app install.
  ///
  /// Returns null if:
  /// - Firebase isn't properly configured for the current platform, or
  /// - permissions/environment prevent token generation.
  static Future<String?> getDeviceToken() async {
    await ensureInitialized();

    // Best-effort: ensure permission prompt has been handled before token fetch.
    // This keeps token UI “read-only” and moves wiring to service/app bootstrap.
    await requestPermission();

    try {
      final token = await FirebaseMessaging.instance.getToken();
      return token;
    } catch (e) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('FirebaseMessagingService.getDeviceToken failed: $e');
      }
      return null;
    }
  }
}
