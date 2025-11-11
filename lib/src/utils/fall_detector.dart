import 'dart:math' as math;
import 'package:sensors_plus/sensors_plus.dart';

class FallDetector {
  // Simple heuristic:
  // - Large acceleration spike (> 2.5g), followed by low movement window
  // This is a placeholder; tune thresholds with real data.
  static const double spikeG = 2.5; // g
  static const double stillG = 0.2; // g
  static const int stillWindowMs = 700;

  DateTime? _lastSpikeTime;

  bool isPotentialFall(AccelerometerEvent e) {
    final g = _magnitudeG(e);
    final now = DateTime.now();

    if (g > spikeG) {
      _lastSpikeTime = now;
      return false;
    }

    if (_lastSpikeTime != null) {
      final elapsed = now.difference(_lastSpikeTime!).inMilliseconds;
      if (elapsed <= stillWindowMs && g < stillG) {
        // Spike then stillness within window -> potential fall
        _lastSpikeTime = null;
        return true;
      }
      if (elapsed > stillWindowMs) {
        _lastSpikeTime = null;
      }
    }
    return false;
  }

  double _magnitudeG(AccelerometerEvent e) {
    return getMagnitudeG(e);
  }

  /// Public method to get acceleration magnitude in g units
  static double getMagnitudeG(AccelerometerEvent e) {
    final ax = e.x, ay = e.y, az = e.z;
    final m = math.sqrt(ax * ax + ay * ay + az * az);
    // 1g ~ 9.81 m/s^2; sensors_plus gives m/s^2
    return m / 9.80665;
  }

  /// Instance method wrapper for consistency
  double getMagnitudeGInstance(AccelerometerEvent e) {
    return getMagnitudeG(e);
  }
}
