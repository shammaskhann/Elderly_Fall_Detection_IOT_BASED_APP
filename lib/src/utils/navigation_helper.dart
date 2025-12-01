import 'dart:async';
import 'dart:developer';

import 'package:flutter/material.dart';

import '../alarm/alarm_screen.dart';
import 'app_navigator.dart';

/// Navigate to alarm screen from anywhere in the app.
///
/// Navigation requests can come from background services or notification
/// callbacks when the app is not yet in a state where the `Navigator` is
/// available. To make navigation reliable, we retry for a short window until
/// the global `navigatorKey` has a valid state/context.
void navigateToAlarmScreen() {
  log('Request to navigate to Alarm Screen received.');
  _attemptNavigate(retries: 0);
}

void _attemptNavigate({required int retries, bool immediate = false}) {
  const int maxRetries =
      25; // ~25 * 300ms = 7.5s retry window (increased for background case)
  const Duration retryDelay = Duration(milliseconds: 300);
  final initialDelay = immediate ? 0 : 500; // Wait longer if not immediate

  log(
    'Attempting to navigate to Alarm Screen, try #$retries (immediate: $immediate)',
  );

  // If navigator state is available, use it.
  final navState = navigatorKey.currentState;
  if (navState != null) {
    try {
      navState.pushNamedAndRemoveUntil(AlarmScreen.routeName, (route) => false);
      log('Navigation successful using navigator state');
      return;
    } catch (e) {
      log(
        'Navigator state push failed: $e, will retry with context if available.',
      );
    }
  }

  // If we have a context, use Navigator.of to attempt navigation.
  final navContext = navigatorKey.currentContext;
  if (navContext != null) {
    try {
      Navigator.of(
        navContext,
        rootNavigator: true,
      ).pushNamedAndRemoveUntil(AlarmScreen.routeName, (route) => false);
      log('Navigation successful using navigator context');
      return;
    } catch (e) {
      log('Navigator context push failed: $e');
    }
  }

  // If we haven't succeeded and we still have retries left, schedule another attempt.
  if (retries < maxRetries) {
    final delay = retries == 0 ? initialDelay : retryDelay.inMilliseconds;
    Timer(
      Duration(milliseconds: delay),
      () => _attemptNavigate(retries: retries + 1, immediate: false),
    );
  } else {
    log(
      'Navigation failed after $maxRetries attempts. '
      'User can tap notification to navigate manually.',
      name: 'ERROR',
    );
  }
}
