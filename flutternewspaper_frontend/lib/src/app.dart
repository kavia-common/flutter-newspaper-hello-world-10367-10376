import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth/error_codes.dart' as local_auth_errors;

import 'screens/home/home_screen.dart';
import 'screens/read/read_article_screen.dart';
import 'screens/saved/saved_news_screen.dart';

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
      child: MaterialApp(
        title: 'News App',
        debugShowCheckedModeBanner: false,
        theme: _theme(),
        routes: {
          HomeScreen.routeName: (_) => const HomeScreen(),
          SavedNewsScreen.routeName: (_) => const SavedNewsScreen(),
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
    );
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

class _BiometricGateState extends State<_BiometricGate> {
  final LocalAuthentication _auth = LocalAuthentication();

  bool _isChecking = true;
  bool _isAuthed = false;

  /// Human-friendly message for why auth isn't completed yet.
  String? _message;

  @override
  void initState() {
    super.initState();
    // Run on next microtask/frame; avoids any edge-case issues with calling
    // platform channels too early during app bootstrap.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndAuthenticate();
    });
  }

  // PUBLIC_INTERFACE
  /// Triggers biometric/device-credential authentication.
  ///
  /// Returns `true` if authentication was successful, `false` otherwise.
  Future<bool> authenticate() async {
    try {
      final isSupported = await _auth.isDeviceSupported();
      final canCheckBiometrics = await _auth.canCheckBiometrics;

      if (!isSupported && !canCheckBiometrics) {
        return false;
      }

      // Get the list of available biometric types; useful for deciding messaging.
      final biometrics = await _auth.getAvailableBiometrics();

      // Use biometrics when available; allow device credentials as fallback on Android.
      // This matches "biometric gating" intent while remaining practical.
      final didAuthenticate = await _auth.authenticate(
        localizedReason: _localizedReason(biometrics),
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

  String _localizedReason(List<BiometricType> biometrics) {
    if (biometrics.contains(BiometricType.face)) return 'Authenticate with Face ID to continue';
    if (biometrics.contains(BiometricType.fingerprint)) return 'Authenticate with fingerprint to continue';
    return 'Authenticate to continue';
  }

  Future<void> _checkAndAuthenticate() async {
    // IMPORTANT: no BuildContext usage after awaits (per project rule).
    String? nextMessage;
    bool isAuthed = false;

    try {
      final isSupported = await _auth.isDeviceSupported();
      final canCheckBiometrics = await _auth.canCheckBiometrics;

      if (!isSupported && !canCheckBiometrics) {
        nextMessage = 'Biometric authentication is not available on this device.';
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
        nextMessage = 'Biometric authentication is not available.';
      } else if (e.code == local_auth_errors.notEnrolled) {
        nextMessage = 'No biometrics enrolled. Please enroll Face ID/Touch ID or fingerprints in device settings.';
      } else if (e.code == local_auth_errors.lockedOut ||
          e.code == local_auth_errors.permanentlyLockedOut) {
        nextMessage = 'Biometrics locked. Please unlock from device settings and try again.';
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
