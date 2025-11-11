import '../alarm/alarm_screen.dart';
import 'app_navigator.dart';

/// Navigate to alarm screen from anywhere in the app
/// This function can be called from background services or any part of the app
void navigateToAlarmScreen() {
  navigatorKey.currentState?.pushNamedAndRemoveUntil(
    AlarmScreen.routeName,
    (route) => false, // Remove all previous routes
  );
}
