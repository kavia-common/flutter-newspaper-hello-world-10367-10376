import 'package:flutter/material.dart';

/// Global navigation service used for cases where we must navigate without a
/// BuildContext (e.g., local notification action callbacks).
class NavigationService {
  NavigationService._();

  /// PUBLIC_INTERFACE
  /// Global navigator key for the app.
  ///
  /// This allows navigation from background callbacks (e.g., notification taps)
  /// without relying on BuildContext.
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  /// PUBLIC_INTERFACE
  /// Push a named route if the navigator is currently available.
  static Future<void> pushNamed(String routeName, {Object? arguments}) async {
    final nav = navigatorKey.currentState;
    if (nav == null) return;
    await nav.pushNamed(routeName, arguments: arguments);
  }

  /// PUBLIC_INTERFACE
  /// Pop until the first route, then push [routeName].
  ///
  /// Useful to reliably take the user to a top-level screen (e.g., Saved News).
  static Future<void> popToRootAndPushNamed(String routeName, {Object? arguments}) async {
    final nav = navigatorKey.currentState;
    if (nav == null) return;

    nav.popUntil((route) => route.isFirst);
    await nav.pushNamed(routeName, arguments: arguments);
  }
}
