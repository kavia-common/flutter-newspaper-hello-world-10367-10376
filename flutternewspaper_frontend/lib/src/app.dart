import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth/error_codes.dart' as local_auth_errors;
import 'package:provider/provider.dart';

import 'core/firebase_messaging_service.dart';
import 'core/local_notifications.dart';
import 'core/navigation_service.dart';
import 'screens/device_token/device_token_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/notification_test/notification_test_screen.dart';
import 'screens/read/read_article_screen.dart';
import 'screens/saved/saved_news_screen.dart';
import 'state/news_app_state.dart';

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
    // Gate the entire app UI behind biometric auth. Once authenticated, we render
    // the SAME MaterialApp / routes as before (no changes to post-auth flows).
    return _BiometricGate(
      child: _NotificationBootstrapper(
        child: MaterialApp(
          navigatorKey: NavigationService.navigatorKey,
          title: 'News App',
          debugShowCheckedModeBanner: false,
          theme: _theme(),
          routes: {
            HomeScreen.routeName: (_) => const HomeScreen(),
            SavedNewsScreen.routeName: (_) => const SavedNewsScreen(),
            DeviceTokenScreen.routeName: (_) => const DeviceTokenScreen(),
            NotificationTestScreen.routeName: (_) => const NotificationTestScreen(),
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
        ),
      ),
    );
  }
}

/// Initializes local + push notification plumbing at the app root.
///
/// This keeps the existing “Notification Test” and “Device Token” screens as UI
/// surfaces, but ensures their underlying services are wired from `app.dart`
/// (not implicitly “owned” by HomeScreen tool UI).
class _NotificationBootstrapper extends StatefulWidget {
  const _NotificationBootstrapper({required this.child});

  final Widget child;

  @override
  State<_NotificationBootstrapper> createState() => _NotificationBootstrapperState();
}

class _NotificationBootstrapperState extends State<_NotificationBootstrapper> {
  bool _didInit = false;

  @override
  void initState() {
    super.initState();

    // Defer work until after first frame; avoids early platform-channel edge cases.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _init();
    });
  }

  Future<void> _init() async {
    if (_didInit) return;

    // IMPORTANT: no BuildContext usage after awaits (project rule). We grab
    // dependencies synchronously before doing async work.
    final state = context.read<NewsAppState>();

    // Local notifications: init is idempotent and keeps latest state handler.
    await LocalNotifications.init(state: state);

    // Push notifications: ensure firebase init and request permission once.
    await FirebaseMessagingService.ensureInitialized();
    await FirebaseMessagingService.requestPermission();

    // Only update primitive state after await.
    setState(() {
      _didInit = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

/// A blocking app-launch biometric gate.
///
/// Design goals:
/// - Must run BEFORE Home renders.
/// - Must not change any existing navigation/routes once authenticated.
/// - Must re-trigger on every cold app launch (no persisted session token).
class _BiometricGate extends StatefulWidget {
  const _BiometricGate({required this.child});

  final Widget child;

  @override
  State<_BiometricGate> createState() => _BiometricGateState();
}

class _BiometricGateState extends State<_BiometricGate> with WidgetsBindingObserver {
  final LocalAuthentication _auth = LocalAuthentication();

  bool _isChecking = true;
  bool _isAuthed = false;

  /// How long the app may remain in background before we require re-auth.
  static const Duration _backgroundLockTimeout = Duration(seconds: 30);

  /// When true, the next time the app returns to the foreground we must re-auth.
  ///
  /// IMPORTANT: this is only set after the app has actually backgrounded
  /// (inactive/paused) for longer than [_backgroundLockTimeout], so we do not
  /// prompt on brief transitions (e.g., quick app switcher, notifications).
  bool _shouldReauthOnResume = false;

  /// Timestamp recorded when the app first transitioned to inactive/paused while
  /// authenticated. Used to decide whether to lock on resume.
  DateTime? _backgroundedAt;

  /// Human-friendly message for why auth isn't completed yet.
  String? _message;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    // Run on next frame; avoids edge-case issues with calling platform channels
    // too early during app bootstrap.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndAuthenticate();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // We only "re-lock" after the app actually leaves the foreground.
    //
    // - inactive: app is transitioning away (e.g., app switcher, incoming call).
    // - paused: app is not visible to the user (background).
    //
    // We DO NOT lock immediately on inactive/paused. Instead, we remember the
    // time and decide on resume whether enough time has elapsed.
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      // Only track backgrounding time if the user is currently authenticated.
      // If already locked, keep background timestamp cleared.
      if (_isAuthed && _backgroundedAt == null) {
        _backgroundedAt = DateTime.now();
      }
      return;
    }

    if (state == AppLifecycleState.resumed) {
      // Decide if we should re-auth based on how long we were backgrounded.
      final bgAt = _backgroundedAt;
      _backgroundedAt = null;

      if (_isAuthed && bgAt != null) {
        final elapsed = DateTime.now().difference(bgAt);
        if (elapsed > _backgroundLockTimeout) {
          // Mark for re-auth; keep actual UI change deferred to next frame.
          _shouldReauthOnResume = true;
        }
      }

      // Trigger re-auth only if we were backgrounded longer than timeout.
      if (_shouldReauthOnResume) {
        setState(() {
          _shouldReauthOnResume = false;
          _isAuthed = false;
          _isChecking = true;
          _message = null;
        });

        // Kick off re-auth on next frame to avoid lifecycle re-entrancy.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _checkAndAuthenticate();
        });
      }
    }
  }

  // PUBLIC_INTERFACE
  /// Triggers app-launch authentication.
  ///
  /// Requirements:
  /// - Prefer biometrics when available.
  /// - Allow fallback to the device system passcode/PIN/pattern when biometrics
  ///   are unavailable, not enrolled, or fail (recommended UX).
  ///
  /// Returns `true` if authentication was successful, `false` otherwise.
  Future<bool> authenticate() async {
    try {
      // isDeviceSupported() is the broad capability check; it can still be true
      // when biometrics aren't enrolled because device credentials exist.
      final isSupported = await _auth.isDeviceSupported();
      if (!isSupported) return false;

      // Biometrics list is used only for better prompt wording; it may be empty
      // if biometrics aren't available or enrolled.
      final biometrics = await _auth.getAvailableBiometrics();

      // IMPORTANT: biometricOnly=false is what enables device credential fallback
      // (Android) and "passcode" fallback (iOS via LocalAuthentication policy).
      final didAuthenticate = await _auth.authenticate(
        localizedReason: _localizedReasonWithFallbackHint(biometrics),
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
          useErrorDialogs: true,
          sensitiveTransaction: true,
        ),
      );

      return didAuthenticate;
    } catch (e) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('BiometricGate.authenticate error: $e');
      }
      return false;
    }
  }

  String _localizedReasonWithFallbackHint(List<BiometricType> biometrics) {
    if (biometrics.contains(BiometricType.face)) {
      return 'Authenticate with Face ID (or device passcode) to continue';
    }
    if (biometrics.contains(BiometricType.fingerprint)) {
      return 'Authenticate with fingerprint (or device passcode) to continue';
    }
    // If biometrics list is empty, the OS may still allow device credentials.
    return 'Authenticate with device passcode to continue';
  }

  Future<void> _checkAndAuthenticate() async {
    // IMPORTANT: no BuildContext usage after awaits (per project rule).
    String? nextMessage;
    bool isAuthed = false;

    try {
      // We intentionally DO NOT treat "canCheckBiometrics == false" as a blocker,
      // because we still want passcode/PIN fallback via device credentials.
      final isSupported = await _auth.isDeviceSupported();

      if (!isSupported) {
        nextMessage = 'Authentication is not available on this device.';
      } else {
        isAuthed = await authenticate();
        if (!isAuthed) {
          // Authentication failed/cancelled; show retry affordance.
          nextMessage = 'Authentication required to use the app.';
        }
      }
    } on PlatformException catch (e) {
      // Provide clearer messaging for common cases.
      if (e.code == local_auth_errors.notAvailable) {
        nextMessage = 'Authentication is not available.';
      } else if (e.code == local_auth_errors.notEnrolled) {
        // With passcode fallback enabled, "notEnrolled" can still allow device credentials.
        // We prompt the user to retry (system should offer passcode if configured).
        nextMessage = 'Biometrics not enrolled. Use device passcode to continue.';
      } else if (e.code == local_auth_errors.lockedOut || e.code == local_auth_errors.permanentlyLockedOut) {
        // Locked out biometrics should still allow passcode fallback on supported devices.
        nextMessage = 'Biometrics locked. Use device passcode to continue.';
      } else {
        nextMessage = 'Unable to authenticate. Please try again.';
      }
      if (kDebugMode) {
        // ignore: avoid_print
        print('BiometricGate PlatformException: ${e.code} ${e.message}');
      }
    } catch (e) {
      nextMessage = 'Unable to authenticate. Please try again.';
      if (kDebugMode) {
        // ignore: avoid_print
        print('BiometricGate unexpected error: $e');
      }
    }

    // Only update primitive state after await.
    setState(() {
      _isChecking = false;
      _isAuthed = isAuthed;
      _message = nextMessage;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isAuthed) return widget.child;

    // Minimal blocking screen (no impact on the actual app UI once authenticated).
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: scheme.surface,
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.lock_outline, size: 56, color: scheme.primary),
                  const SizedBox(height: 16),
                  Text(
                    'Locked',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _message ?? 'Authentication required to continue.',
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 18),
                  if (_isChecking)
                    const CircularProgressIndicator()
                  else
                    FilledButton(
                      onPressed: () {
                        // Button handler is sync; it just triggers async flow.
                        setState(() {
                          _isChecking = true;
                          _message = null;
                        });
                        _checkAndAuthenticate();
                      },
                      child: const Text('Authenticate'),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
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
