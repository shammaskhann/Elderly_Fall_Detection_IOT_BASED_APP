import 'dart:isolate';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

/// Foreground task handler that keeps the app alive in the background
///
/// NOTE: Sensor monitoring is done in the main isolate via SensorMonitor
/// because sensors_plus streams only work in the main isolate, not in
/// background isolates created by FlutterForegroundTask.
@pragma('vm:entry-point')
void startFallForegroundTask() {
  FlutterForegroundTask.setTaskHandler(_FallTaskHandler());
}

class _FallTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, SendPort? sendPort) async {
    // This handler exists only to keep the foreground service running.
    // Actual sensor monitoring is done in the main isolate via SensorMonitor.
    // The foreground service prevents Android from killing the app.
  }

  @override
  Future<void> onRepeatEvent(DateTime timestamp, SendPort? sendPort) async {
    // Periodic tick - not used for sensor monitoring
    // Sensors are handled in main isolate
  }

  @override
  Future<void> onDestroy(DateTime timestamp, SendPort? sendPort) async {
    // Cleanup if needed
  }
}
