import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter_local_notifications/flutter_local_notifications.dart'
    as fln;
import 'package:sensors_plus/sensors_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../alarm/alarm_screen.dart';
import '../utils/fall_detector.dart';
import '../utils/navigation_helper.dart';
import '../utils/rolling_buffer.dart';

/// Sensor monitor that runs in the main isolate (sensors_plus requires main isolate)
class SensorMonitor {
  static final SensorMonitor _instance = SensorMonitor._internal();
  factory SensorMonitor() => _instance;
  SensorMonitor._internal();

  static fln.FlutterLocalNotificationsPlugin? _notificationPlugin;

  /// Set the notification plugin instance (called from main.dart)
  static void setNotificationPlugin(
    fln.FlutterLocalNotificationsPlugin plugin,
  ) {
    _notificationPlugin = plugin;
  }

  final RollingBuffer<AccelerometerEvent> _buffer = RollingBuffer(
    capacity: 200,
  ); // ~10s at 20Hz
  late final FallDetector _detector;
  StreamSubscription<AccelerometerEvent>? _accelSub;
  DateTime _lastFullScreenLaunch = DateTime.fromMillisecondsSinceEpoch(0);
  bool _isMonitoring = false;
  int _sampleCount = 0;

  /// Start monitoring accelerometer in main isolate
  Future<void> startMonitoring() async {
    if (_isMonitoring) {
      developer.log('SensorMonitor: Already monitoring');
      return;
    }

    _detector = FallDetector();
    _isMonitoring = true;
    _sampleCount = 0;

    developer.log('SensorMonitor: Starting accelerometer stream');

    _accelSub =
        accelerometerEventStream(
          samplingPeriod: const Duration(milliseconds: 50), // 20Hz
        ).listen(
          _onAccelerometerEvent,
          onError: (error) {
            developer.log(
              'SensorMonitor: Accelerometer error: $error',
              name: 'ERROR',
            );
          },
          cancelOnError: false,
        );

    developer.log('SensorMonitor: Accelerometer stream started');
  }

  /// Stop monitoring
  Future<void> stopMonitoring() async {
    if (!_isMonitoring) {
      return;
    }

    developer.log('SensorMonitor: Stopping monitoring');
    await _accelSub?.cancel();
    _accelSub = null;
    _isMonitoring = false;
    _sampleCount = 0;
  }

  /// Handle accelerometer event
  void _onAccelerometerEvent(AccelerometerEvent event) {
    _sampleCount++;
    _buffer.add(event);

    // Log coordinates every 50 samples (~2.5 seconds at 20Hz) to avoid spam
    if (_sampleCount % 50 == 0) {
      final magnitudeG = FallDetector.getMagnitudeG(event);
      developer.log(
        'SensorMonitor: Sample $_sampleCount | '
        'x=${event.x.toStringAsFixed(2)} m/s², '
        'y=${event.y.toStringAsFixed(2)} m/s², '
        'z=${event.z.toStringAsFixed(2)} m/s², '
        'magnitude=${magnitudeG.toStringAsFixed(2)}g',
        name: 'COORDS',
      );
    }

    // Check for potential fall
    final isRisk = _detector.isPotentialFall(event);
    if (!isRisk) return;

    developer.log(
      'SensorMonitor: Potential fall detected! | '
      'x=${event.x.toStringAsFixed(2)}, y=${event.y.toStringAsFixed(2)}, z=${event.z.toStringAsFixed(2)}, '
      'magnitude=${FallDetector.getMagnitudeG(event).toStringAsFixed(2)}g',
      name: 'FALL_DETECTED',
    );

    // Guard: suppress spamming full-screen every few seconds
    final now = DateTime.now();
    if (now.difference(_lastFullScreenLaunch).inSeconds < 20) {
      developer.log(
        'SensorMonitor: Suppressing duplicate alarm (within 20s window)',
      );
      return;
    }
    _lastFullScreenLaunch = now;

    // Persist last event timestamp
    _saveLastEventTimestamp(now);

    // Show high-priority full-screen notification and navigate to alarm screen
    _showFullScreenAlarmNotification();
  }

  Future<void> _saveLastEventTimestamp(DateTime timestamp) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_event_ts', timestamp.toIso8601String());
    } catch (e) {
      developer.log(
        'SensorMonitor: Failed to save timestamp: $e',
        name: 'ERROR',
      );
    }
  }

  Future<void> _showFullScreenAlarmNotification() async {
    try {
      if (_notificationPlugin == null) {
        developer.log(
          'SensorMonitor: Notification plugin not initialized',
          name: 'ERROR',
        );
        return;
      }

      final plugin = _notificationPlugin!;

      final androidDetails = fln.AndroidNotificationDetails(
        'fall_alarm_channel',
        'Fall Alarm',
        channelDescription: 'Alerts for detected fall',
        importance: fln.Importance.max,
        priority: fln.Priority.max,
        fullScreenIntent: true,
        category: fln.AndroidNotificationCategory.alarm,
        ongoing: true,
        visibility: fln.NotificationVisibility.public,
        playSound: true,
        enableVibration: true,
        styleInformation: const fln.DefaultStyleInformation(true, true),
      );

      await plugin.show(
        9999,
        'Possible fall detected',
        'Emergency alert - fall detected',
        fln.NotificationDetails(android: androidDetails),
        payload: AlarmScreen.routeName,
      );

      developer.log('SensorMonitor: Full-screen alarm notification shown');

      // Navigate to alarm screen immediately
      // Full-screen intent will bring app to foreground, then we navigate
      // Use a small delay to ensure app is in foreground
      Future.delayed(const Duration(milliseconds: 500), () {
        try {
          navigateToAlarmScreen();
          developer.log('SensorMonitor: Navigated to alarm screen');
        } catch (e) {
          developer.log(
            'SensorMonitor: Failed to navigate to alarm screen: $e',
            name: 'ERROR',
          );
        }
      });
    } catch (e) {
      developer.log(
        'SensorMonitor: Failed to show notification: $e',
        name: 'ERROR',
      );
    }
  }

  bool get isMonitoring => _isMonitoring;
  int get sampleCount => _sampleCount;
}
