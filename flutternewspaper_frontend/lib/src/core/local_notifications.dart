import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../models/news_article.dart';
import '../screens/saved/saved_news_screen.dart';
import '../state/news_app_state.dart';
import 'navigation_service.dart';

/// Local notification helper for the app.
///
/// Responsibilities:
/// - Initialize flutter_local_notifications for Android/iOS.
/// - Define notification channel (Android) and category (iOS) with action buttons.
/// - Route notification taps/actions into app navigation and state (Undo).
class LocalNotifications {
  LocalNotifications._();

  static final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

  static const String _channelId = 'saved_articles';
  static const String _channelName = 'Saved articles';
  static const String _channelDescription = 'Notifications shown when an article is saved.';

  static const String actionOpenSaved = 'open_saved';
  static const String actionUndoSave = 'undo_save';

  static const int _savedNotificationId = 1001;

  static const String _payloadArticleJsonKey = 'article_json';

  /// Whether init() has been called.
  static bool _initialized = false;

  /// Whether the OS currently allows notifications for this app.
  ///
  /// This can be false if:
  /// - Android 13+ permission wasn't granted (POST_NOTIFICATIONS)
  /// - User disabled notifications at OS level
  /// - Some preview/emulator environments suppress notification UI
  static bool _notificationsEnabled = true;

  /// Handler set by the app to allow notification actions to mutate saved state
  /// without using BuildContext.
  static NewsAppState? _stateHandler;

  void _debugLog(String message) {
    if (kDebugMode) {
      // ignore: avoid_print
      print(message);
    }
  }

  /// PUBLIC_INTERFACE
  /// Initializes local notifications and registers action handlers.
  ///
  /// Call once during app startup.
  /// - [state] is stored as a weak-ish reference for Undo action.
  static Future<void> init({required NewsAppState state}) async {
    if (_initialized) {
      // Always keep the latest state instance (hot restart / provider rebuild).
      _stateHandler = state;
      return;
    }

    _stateHandler = state;

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
      notificationCategories: <DarwinNotificationCategory>[
        DarwinNotificationCategory(
          'saved_article_category',
          actions: <DarwinNotificationAction>[
            DarwinNotificationAction.plain(
              actionOpenSaved,
              'Open Saved',
              options: <DarwinNotificationActionOption>{
                DarwinNotificationActionOption.foreground,
              },
            ),
            DarwinNotificationAction.plain(
              actionUndoSave,
              'Undo',
              options: <DarwinNotificationActionOption>{},
            ),
          ],
        ),
      ],
    );

    const initSettings = InitializationSettings(android: androidInit, iOS: iosInit);

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onDidReceiveNotificationResponse,
      onDidReceiveBackgroundNotificationResponse: _onDidReceiveBackgroundNotificationResponse,
    );

    // Android channel (required on Android 8+).
    const androidChannel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDescription,
      importance: Importance.defaultImportance,
    );

    final androidSpecific = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await androidSpecific?.createNotificationChannel(androidChannel);

    // Android 13+: request POST_NOTIFICATIONS at runtime.
    //
    // IMPORTANT:
    // - Declaring POST_NOTIFICATIONS in AndroidManifest.xml is necessary but not sufficient.
    // - On Android 13+ the user must grant it at runtime, otherwise notifications won't appear.
    // - In some preview/emulator environments, the permission dialog may not show or the system UI
    //   may suppress notifications; we handle that gracefully.
    try {
      final granted = await androidSpecific?.requestNotificationsPermission();
      if (granted == false) {
        if (kDebugMode) {
          // ignore: avoid_print
          print('LocalNotifications.init: Android notifications permission NOT granted (Android 13+).');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('LocalNotifications.init: requestNotificationsPermission failed: $e');
      }
    }

    // Record whether the OS says notifications are enabled for the app.
    // If they are disabled, calling show() will silently do nothing.
    try {
      final enabled = await _plugin
              .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
              ?.areNotificationsEnabled() ??
          await _plugin
              .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
              ?.areNotificationsEnabled() ??
          true;

      _notificationsEnabled = enabled;

      if (!enabled && kDebugMode) {
        // ignore: avoid_print
        print(
          'LocalNotifications.init: Notifications appear disabled in this environment. '
          'In some preview/emulator setups, system notifications may not be displayed.',
        );
      }
    } catch (e) {
      _notificationsEnabled = true;
      if (kDebugMode) {
        // ignore: avoid_print
        print('LocalNotifications.init: areNotificationsEnabled check failed (ignored): $e');
      }
    }

    _initialized = true;
  }

  /// PUBLIC_INTERFACE
  /// Shows a "Saved" notification with action buttons:
  /// - Open Saved: navigates to Saved News screen
  /// - Undo: removes the saved article (by headline)
  ///
  /// Note: the payload includes a serialized article JSON for Undo.
  static Future<void> showSavedArticleNotification(NewsArticle article) async {
    if (!_initialized) return;

    // If notifications are disabled, no-op (but keep the in-app snackbar behavior intact).
    if (!_notificationsEnabled) {
      if (kDebugMode) {
        // ignore: avoid_print
        print(
          'LocalNotifications.showSavedArticleNotification: skipped because notifications are disabled. '
          'If you are running in a preview/emulator, try a full device/emulator run and ensure '
          'notifications are enabled in OS settings.',
        );
      }
      return;
    }

    final payloadMap = <String, Object?>{
      _payloadArticleJsonKey: jsonEncode(_toPayloadJson(article)),
    };
    final payload = jsonEncode(payloadMap);

    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      actions: <AndroidNotificationAction>[
        AndroidNotificationAction(
          actionOpenSaved,
          'Open Saved',
          showsUserInterface: true,
          cancelNotification: true,
        ),
        AndroidNotificationAction(
          actionUndoSave,
          'Undo',
          showsUserInterface: false,
          cancelNotification: true,
        ),
      ],
    );

    const iosDetails = DarwinNotificationDetails(
      categoryIdentifier: 'saved_article_category',
      presentAlert: true,
      presentSound: true,
      presentBadge: false,
    );

    const details = NotificationDetails(android: androidDetails, iOS: iosDetails);

    try {
      await _plugin.show(
        _savedNotificationId,
        'Saved',
        article.headLine,
        details,
        payload: payload,
      );
    } catch (e) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('LocalNotifications.showSavedArticleNotification: show() failed: $e');
      }
    }
  }

  static Map<String, Object?> _toPayloadJson(NewsArticle article) {
    // Keep payload minimal but sufficient for undo and optional future navigation.
    return <String, Object?>{
      'headline': article.headLine,
      'url': article.url,
      'source': article.source,
      'time': article.time,
      'image': article.image,
      'description': article.description,
      'content': article.content,
    };
  }

  static NewsArticle? _articleFromPayload(String? payload) {
    if (payload == null || payload.trim().isEmpty) return null;

    try {
      final decoded = jsonDecode(payload);
      if (decoded is! Map) return null;
      final map = Map<String, Object?>.from(decoded);

      final articleJsonRaw = map[_payloadArticleJsonKey];
      if (articleJsonRaw is! String) return null;

      final articleDecoded = jsonDecode(articleJsonRaw);
      if (articleDecoded is! Map) return null;
      final a = Map<String, Object?>.from(articleDecoded);

      return NewsArticle(
        headLine: (a['headline'] as String?) ?? '',
        image: a['image'] as String?,
        description: a['description'] as String?,
        url: a['url'] as String?,
        source: a['source'] as String?,
        time: a['time'] as String?,
        content: a['content'] as String?,
      );
    } catch (e) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('LocalNotifications: failed to decode payload: $e');
      }
      return null;
    }
  }

  static Future<void> _handleAction(String? actionId, String? payload) async {
    if (actionId == null || actionId.isEmpty) {
      // Generic tap on the notification body -> open Saved.
      await NavigationService.popToRootAndPushNamed(SavedNewsScreen.routeName);
      return;
    }

    switch (actionId) {
      case actionOpenSaved:
        await NavigationService.popToRootAndPushNamed(SavedNewsScreen.routeName);
        return;
      case actionUndoSave:
        final article = _articleFromPayload(payload);
        final headline = article?.headLine.trim() ?? '';
        if (headline.isEmpty) return;

        // Undo save by deleting from DB/state.
        await _stateHandler?.deleteSavedByHeadline(headline);
        return;
      default:
        // Unknown action -> do nothing.
        return;
    }
  }

  static Future<void> _onDidReceiveNotificationResponse(NotificationResponse response) async {
    await _handleAction(response.actionId, response.payload);
  }

  @pragma('vm:entry-point')
  static Future<void> _onDidReceiveBackgroundNotificationResponse(NotificationResponse response) async {
    // In background isolate, navigation may not be possible; Undo is still useful.
    // We attempt to handle both, but only Undo is guaranteed if app isn't foregrounded.
    await _handleAction(response.actionId, response.payload);
  }
}
