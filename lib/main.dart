import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart'
    as fln;
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'src/alarm/alarm_screen.dart';
import 'src/service/fall_foreground_task.dart';
import 'src/service/sensor_monitor.dart';
import 'src/settings/settings_page.dart';
import 'src/utils/app_navigator.dart' show navigatorKey;
import 'src/utils/navigation_helper.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize foreground task
  FlutterForegroundTask.init(
    androidNotificationOptions: AndroidNotificationOptions(
      channelId: 'fall_detect_channel',
      channelName: 'Fall Detection',
      channelDescription: 'Monitoring activity to detect falls',
      channelImportance: NotificationChannelImportance.HIGH,
      priority: NotificationPriority.MAX,
      isSticky: true,
      visibility: NotificationVisibility.VISIBILITY_PUBLIC,
      buttons: [const NotificationButton(id: 'stop', text: 'Stop')],
    ),
    iosNotificationOptions: const IOSNotificationOptions(
      showNotification: true,
    ),
    foregroundTaskOptions: const ForegroundTaskOptions(
      interval: 500, // ms tick for background handler
      isOnceEvent: false,
      autoRunOnBoot: true,
      allowWakeLock: true,
      allowWifiLock: true,
    ),
  );

  // Initialize local notifications for alarm screen navigation
  await _initializeNotifications();

  runApp(const FallDetectionApp());
}

Future<void> _initializeNotifications() async {
  final fln.FlutterLocalNotificationsPlugin plugin =
      fln.FlutterLocalNotificationsPlugin();

  const fln.AndroidInitializationSettings androidInit =
      fln.AndroidInitializationSettings('@mipmap/ic_launcher');

  await plugin.initialize(
    const fln.InitializationSettings(android: androidInit),
    onDidReceiveNotificationResponse: (fln.NotificationResponse response) {
      // Handle notification tap - navigate to alarm screen
      if (response.payload == AlarmScreen.routeName) {
        // Use the same navigation function
        navigateToAlarmScreen();
      }
    },
  );

  // Create notification channel for alarm
  const fln.AndroidNotificationChannel alarmChannel =
      fln.AndroidNotificationChannel(
        'fall_alarm_channel',
        'Fall Alarm',
        description: 'Alerts for detected fall',
        importance: fln.Importance.max,
        playSound: true,
        enableVibration: true,
      );

  await plugin
      .resolvePlatformSpecificImplementation<
        fln.AndroidFlutterLocalNotificationsPlugin
      >()
      ?.createNotificationChannel(alarmChannel);

  // Store plugin instance for SensorMonitor to use
  SensorMonitor.setNotificationPlugin(plugin);
}

class FallDetectionApp extends StatelessWidget {
  const FallDetectionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Elderly Fall Detection',
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey, // Use global navigator key
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      routes: {
        '/': (_) => const HomePage(),
        AlarmScreen.routeName: (_) => const AlarmScreen(),
        SettingsPage.routeName: (_) => const SettingsPage(),
      },
      initialRoute: '/',
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _serviceRunning = false;
  String? _emergencyPhone;
  Timer? _updateTimer;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
    // Update UI every second to show sample count
    _updateTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_serviceRunning && mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _emergencyPhone = prefs.getString('emergency_phone');
    });
  }

  Future<void> _ensurePermissions() async {
    await [
      Permission.activityRecognition,
      Permission.locationAlways,
      Permission.locationWhenInUse,
      Permission.sms,
      Permission.notification,
      Permission.camera,
    ].request();
  }

  Future<void> _startService() async {
    await _ensurePermissions();

    // Enable wakelock to keep CPU active
    await WakelockPlus.enable();

    // Start foreground service (keeps app alive, but doesn't handle sensors)
    await FlutterForegroundTask.startService(
      notificationTitle: 'Fall detection active',
      notificationText: 'Monitoring movements...',
      callback: startFallForegroundTask,
    );

    // Start sensor monitoring in main isolate (sensors_plus requires main isolate)
    await SensorMonitor().startMonitoring();

    setState(() => _serviceRunning = true);
  }

  Future<void> _stopService() async {
    // Stop sensor monitoring first
    await SensorMonitor().stopMonitoring();

    // Stop foreground service
    await FlutterForegroundTask.stopService();

    // Disable wakelock
    await WakelockPlus.disable();

    setState(() => _serviceRunning = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Elderly Fall Detection'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () async {
              await Navigator.pushNamed(context, SettingsPage.routeName);
              await _loadPrefs();
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: ListTile(
                leading: Icon(
                  _serviceRunning
                      ? Icons.health_and_safety
                      : Icons.health_and_safety_outlined,
                  color: _serviceRunning ? Colors.green : null,
                ),
                title: Text(
                  _serviceRunning ? 'Monitoring active' : 'Monitoring inactive',
                ),
                subtitle: Text(
                  _emergencyPhone == null || _emergencyPhone!.isEmpty
                      ? 'Set an emergency contact in Settings'
                      : 'Emergency contact: $_emergencyPhone',
                ),
                trailing: _serviceRunning
                    ? Text(
                        '${SensorMonitor().sampleCount} samples',
                        style: const TextStyle(fontSize: 12),
                      )
                    : null,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              icon: Icon(
                _serviceRunning ? Icons.pause_circle : Icons.play_circle,
              ),
              label: Text(
                _serviceRunning ? 'Stop Monitoring' : 'Start Monitoring',
              ),
              onPressed: _serviceRunning ? _stopService : _startService,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              icon: const Icon(Icons.warning_amber),
              label: const Text('Trigger Test Alarm'),
              onPressed: () {
                Navigator.pushNamed(context, AlarmScreen.routeName);
              },
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
            ),
            const Spacer(),
            const Text(
              'Note: The app uses a foreground service to run continuously, even when the screen is off. '
              'Sensor monitoring runs in the main app to ensure reliable accelerometer access.',
              style: TextStyle(color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }
}
