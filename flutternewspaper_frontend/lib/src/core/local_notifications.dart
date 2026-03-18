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
  static const int _testNotificationId = 2001;

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

  /// Best-effort view of runtime permission state.
  ///
  /// On Android 13+ this corresponds to POST_NOTIFICATIONS runtime permission.
  /// On iOS this corresponds to the user’s notification permission prompt.
  ///
  /// Note: Some plugin/platform combinations only support "enabled" checks; in
  /// those cases this may stay null.
  static bool? _permissionGranted;

  /// Handler set by the app to allow notification actions to mutate saved state
  /// without using BuildContext.
  static NewsAppState? _stateHandler;

  /// PUBLIC_INTERFACE
  /// Latest diagnostic message from notification attempts (best-effort).
  ///
  /// Used to provide a visible in-app explanation in preview environments where
  /// system notifications may be suppressed.
  static String? get lastDiagnostic => _lastDiagnostic;
  static String? _lastDiagnostic;

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
    //
    // Use HIGH importance so a "Saved" confirmation actually appears in more
    // device configurations. Users can still downgrade it in OS settings.
    const androidChannel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDescription,
      importance: Importance.high,
    );

    final androidSpecific = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await androidSpecific?.createNotificationChannel(androidChannel);

    // Android 13+: request POST_NOTIFICATIONS at runtime.
    try {
      final granted = await androidSpecific?.requestNotificationsPermission();
      _permissionGranted = granted;
      if (granted == false) {
        _lastDiagnostic = 'Android notifications permission not granted.';
        if (kDebugMode) {
          // ignore: avoid_print
          print('LocalNotifications.init: Android notifications permission NOT granted (Android 13+).');
        }
      }
    } catch (e) {
      _permissionGranted = null;
      _lastDiagnostic = 'Failed to request notification permission: $e';
      if (kDebugMode) {
        // ignore: avoid_print
        print('LocalNotifications.init: requestNotificationsPermission failed: $e');
      }
    }

    // Record whether the OS says notifications are enabled for the app.
    try {
      final enabled = await _plugin
              .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
              ?.areNotificationsEnabled() ??
          await _plugin
              .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
              ?.areNotificationsEnabled() ??
          true;

      _notificationsEnabled = enabled;

      if (!enabled) {
        _lastDiagnostic = 'Notifications are disabled or suppressed by the environment.';
        if (kDebugMode) {
          // ignore: avoid_print
          print(
            'LocalNotifications.init: Notifications appear disabled in this environment. '
            'In some preview/emulator setups, system notifications may not be displayed.',
          );
        }
      }
    } catch (e) {
      _notificationsEnabled = true;
      if (kDebugMode) {
        // ignore: avoid_print
        print('LocalNotifications.init: areNotificationsEnabled check failed (ignored): $e');
      }
    }

    // Best-effort: on iOS, requestPermissions returns whether the user granted
    // the permission dialog.
    try {
      final iosSpecific = _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
      final iosGranted = await iosSpecific?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      if (iosGranted != null) {
        _permissionGranted = iosGranted;
      }
    } catch (e) {
      // ignore: avoid_print
      if (kDebugMode) {
        print('LocalNotifications.init: iOS requestPermissions failed (ignored): $e');
      }
    }

    _initialized = true;
  }

  /// Result of attempting to show a local notification.
  ///
  /// Used so UI can show a clear in-app diagnostic when notifications are
  /// disabled/suppressed (common in preview runtimes).
  class ShowResult {
    const ShowResult({required this.didShow, required this.diagnostic});

    final bool didShow;
    final String? diagnostic;
  }

  /// Snapshot of notification diagnostics for the current device/environment.
  class DiagnosticsStatus {
    const DiagnosticsStatus({
      required this.notificationsEnabled,
      required this.permissionGranted,
      required this.platform,
      required this.details,
    });

    final bool notificationsEnabled;
    final bool? permissionGranted;
    final String platform;
    final String details;
  }

  /// PUBLIC_INTERFACE
  /// Returns diagnostic information about notification permission/state.
  ///
  /// This API is intended for an in-app "Notification Test" screen so users can
  /// verify whether notifications are enabled and whether runtime permission was
  /// granted (Android 13+, iOS).
  static Future<DiagnosticsStatus> getDiagnostics() async {
    final platform = defaultTargetPlatform.name;

    bool enabled = _notificationsEnabled;
    bool? permissionGranted = _permissionGranted;

    // Try to refresh "enabled" from platform API (best-effort).
    try {
      enabled = await _plugin
              .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
              ?.areNotificationsEnabled() ??
          await _plugin
              .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
              ?.areNotificationsEnabled() ??
          enabled;
    } catch (_) {
      // Ignore; keep cached value.
    }

    final details = StringBuffer()
      ..writeln('Initialized: $_initialized')
      ..writeln('Last diagnostic: ${_lastDiagnostic ?? "None"}');

    return DiagnosticsStatus(
      notificationsEnabled: enabled,
      permissionGranted: permissionGranted,
      platform: platform,
      details: details.toString().trim(),
    );
  }

  /// PUBLIC_INTERFACE
  /// Shows a simple test local notification.
  ///
  /// This uses the same notification channel as Saved notifications to ensure
  /// channel configuration exists on Android.
  static Future<ShowResult> showTestNotification() async {
    if (!_initialized) {
      const msg = 'LocalNotifications not initialized.';
      _lastDiagnostic = msg;
      return const ShowResult(didShow: false, diagnostic: msg);
    }

    if (!_notificationsEnabled) {
      final msg =
          'System notifications are disabled/suppressed in this environment. '
          'Enable notifications in OS settings, or run on a real device.';
      _lastDiagnostic = msg;
      return ShowResult(didShow: false, diagnostic: msg);
    }

    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.high,
      priority: Priority.high,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentSound: true,
      presentBadge: false,
    );

    const details = NotificationDetails(android: androidDetails, iOS: iosDetails);

    try {
      await _plugin.show(
        _testNotificationId,
        'Test notification',
        'If you can read this, local notifications are working.',
        details,
      );
      _lastDiagnostic = null;
      return const ShowResult(didShow: true, diagnostic: null);
    } catch (e) {
      final msg = 'Test notification show() failed: $e';
      _lastDiagnostic = msg;
      return ShowResult(didShow: false, diagnostic: msg);
    }
  }

  /// PUBLIC_INTERFACE
  /// Shows a "Saved" notification with action buttons.
  ///
  /// Returns a [ShowResult] so callers can show an in-app fallback message if
  /// the OS/environment suppressed notifications.
  static Future<ShowResult> showSavedArticleNotification(NewsArticle article) async {
    if (!_initialized) {
      const msg = 'LocalNotifications not initialized.';
      _lastDiagnostic = msg;
      return const ShowResult(didShow: false, diagnostic: msg);
    }

    if (!_notificationsEnabled) {
      final msg =
          'System notifications are disabled/suppressed in this environment. '
          'If you are running in an emulator/preview, try a full device run and enable '
          'notifications in OS settings for this app.';
      _lastDiagnostic = msg;

      if (kDebugMode) {
        // ignore: avoid_print
        print('LocalNotifications.showSavedArticleNotification: skipped: $msg');
      }
      return ShowResult(didShow: false, diagnostic: msg);
    }

    final payloadMap = <String, Object?>{
      _payloadArticleJsonKey: jsonEncode(_toPayloadJson(article)),
    };
    final payload = jsonEncode(payloadMap);

    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.high,
      priority: Priority.high,
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
      _lastDiagnostic = null;
      return const ShowResult(didShow: true, diagnostic: null);
    } catch (e) {
      final msg = 'Notification show() failed: $e';
      _lastDiagnostic = msg;
      if (kDebugMode) {
        // ignore: avoid_print
        print('LocalNotifications.showSavedArticleNotification: show() failed: $e');
      }
      return ShowResult(didShow: false, diagnostic: msg);
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
