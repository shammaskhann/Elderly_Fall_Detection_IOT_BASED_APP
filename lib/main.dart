import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

// Custom theme colors
const Color primaryColor = Color(0xFF667EEA); // Soft blue
const Color secondaryColor = Color(0xFF764BA2); // Purple accent
const Color successColor = Color(0xFF48BB78); // Green
const Color dangerColor = Color(0xFFF56565); // Red
const Color warningColor = Color(0xFFED8936); // Orange
const Color backgroundColor = Color(0xFFF7FAFC); // Light gray background
const Color surfaceColor = Colors.white;
const Color textPrimary = Color(0xFF2D3748);
const Color textSecondary = Color(0xFF718096);

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
      interval: 500,
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
      developer.log(
        'Notification tapped: payload=${response.payload}, actionId=${response.actionId}',
      );
      if (response.payload == AlarmScreen.routeName) {
        // User tapped notification - navigate to alarm screen
        // This is critical for background + screen ON case where full-screen intent doesn't work
        developer.log('Navigating to alarm screen from notification tap');
        Future.delayed(const Duration(milliseconds: 100), () {
          navigateToAlarmScreen();
        });
      }
    },
  );

  // Handle case where app was launched (cold start) from a notification tap
  try {
    final details = await plugin.getNotificationAppLaunchDetails();
    if (details != null && details.didNotificationLaunchApp) {
      final payload = details.notificationResponse?.payload;
      developer.log('App launched from notification: payload=$payload');
      if (payload == AlarmScreen.routeName) {
        // Wait for app to fully initialize before navigating
        Future.delayed(const Duration(milliseconds: 500), () {
          navigateToAlarmScreen();
        });
      }
    }
  } catch (e) {
    developer.log('Error checking notification launch details: $e');
  }

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

  SensorMonitor.setNotificationPlugin(plugin);
}

class FallDetectionApp extends StatefulWidget {
  const FallDetectionApp({super.key});

  @override
  State<FallDetectionApp> createState() => _FallDetectionAppState();
}

class _FallDetectionAppState extends State<FallDetectionApp>
    with WidgetsBindingObserver {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FallGuard',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: primaryColor),
        useMaterial3: true,
      ),
      navigatorKey: navigatorKey,
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
  bool _initializing = false;
  DateTime? _serviceStartTime;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
    _updateTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
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
    setState(() => _initializing = true);

    await _ensurePermissions();
    await WakelockPlus.enable();

    await FlutterForegroundTask.startService(
      notificationTitle: 'FallGuard Active',
      notificationText: 'Monitoring for falls...',
      callback: startFallForegroundTask,
    );

    await SensorMonitor().startMonitoring();

    setState(() {
      _serviceRunning = true;
      _serviceStartTime = DateTime.now();
      _initializing = false;
    });
  }

  Future<void> _stopService() async {
    await SensorMonitor().stopMonitoring();
    await FlutterForegroundTask.stopService();
    await WakelockPlus.disable();

    setState(() {
      _serviceRunning = false;
      _serviceStartTime = null;
    });
  }

  String _formatDuration(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    final hours = two(d.inHours);
    final minutes = two(d.inMinutes.remainder(60));
    final seconds = two(d.inSeconds.remainder(60));
    return '$hours:$minutes:$seconds';
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 20, color: color),
              ),
              const Spacer(),
              if (title == "Status")
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: _serviceRunning ? successColor : textSecondary,
                    shape: BoxShape.circle,
                    boxShadow: _serviceRunning
                        ? [
                            BoxShadow(
                              color: successColor.withOpacity(0.5),
                              blurRadius: 8,
                              spreadRadius: 2,
                            ),
                          ]
                        : null,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: Theme.of(context).textTheme.displayMedium?.copyWith(
              color: textPrimary,
              fontSize: MediaQuery.of(context).size.width * 0.04,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontSize: MediaQuery.of(context).size.width * 0.03,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final samples = SensorMonitor().sampleCount;
    final uptime = (_serviceRunning && _serviceStartTime != null)
        ? _formatDuration(DateTime.now().difference(_serviceStartTime!))
        : '--:--:--';

    return Scaffold(
      body: Stack(
        children: [
          // Background gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [backgroundColor, Color(0xFFEDF2F7)],
              ),
            ),
          ),

          // Main content
          SingleChildScrollView(
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'FallGuard',
                              style: Theme.of(context).textTheme.displayLarge
                                  ?.copyWith(
                                    color: primaryColor,
                                    fontSize: 32,
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Fall Detection System',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.settings_outlined),
                          onPressed: () async {
                            await Navigator.pushNamed(
                              context,
                              SettingsPage.routeName,
                            );
                            await _loadPrefs();
                          },
                          style: IconButton.styleFrom(
                            backgroundColor: surfaceColor,
                            padding: const EdgeInsets.all(12),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 32),

                    // Status card
                    _buildStatCard(
                      "Status",
                      _serviceRunning ? "Active" : "Inactive",
                      _serviceRunning
                          ? Icons.check_circle_outline
                          : Icons.pause_circle_outline,
                      _serviceRunning ? successColor : textSecondary,
                    ),

                    const SizedBox(height: 16),

                    // Emergency contact info
                    if (_emergencyPhone != null && _emergencyPhone!.isNotEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: primaryColor.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: primaryColor.withOpacity(0.2),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.emergency_outlined,
                              color: primaryColor,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Emergency Contact',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(fontWeight: FontWeight.w600),
                                  ),
                                  Text(
                                    _emergencyPhone!,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodyMedium,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 32),

                    // Stats grid
                    GridView(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: 0.8,
                          ),
                      children: [
                        _buildStatCard(
                          "Samples",
                          samples.toString(),
                          Icons.insights_outlined,
                          primaryColor,
                        ),
                        _buildStatCard(
                          "Uptime",
                          uptime,
                          Icons.access_time_outlined,
                          secondaryColor,
                        ),
                        _buildStatCard(
                          "Alerts",
                          "0",
                          Icons.notifications_outlined,
                          warningColor,
                        ),
                      ],
                    ),

                    const SizedBox(height: 32),

                    // Action buttons
                    Column(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed: _serviceRunning
                                ? _stopService
                                : _startService,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _serviceRunning
                                  ? dangerColor
                                  : successColor,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  _serviceRunning
                                      ? Icons.stop
                                      : Icons.play_arrow,
                                  size: 24,
                                  color: backgroundColor,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _serviceRunning
                                      ? 'Stop Monitoring'
                                      : 'Start Monitoring',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: backgroundColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: OutlinedButton(
                            onPressed: () {
                              Navigator.pushNamed(
                                context,
                                AlarmScreen.routeName,
                              );
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: warningColor,
                              side: BorderSide(color: warningColor, width: 1.5),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.warning_amber_outlined, size: 20),
                                SizedBox(width: 8),
                                Text(
                                  'Test Alarm',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 32),

                    // Information note
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: surfaceColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.grey.shade200,
                          width: 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                color: primaryColor,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Important Note',
                                style: Theme.of(context).textTheme.bodyLarge
                                    ?.copyWith(fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'This app runs a foreground service to continuously monitor for falls, even when your screen is off. Keep the app running for maximum protection.',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Modern loading overlay
          if (_initializing)
            Container(
              color: Colors.black.withOpacity(0.6),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        // Outer rotating ring
                        SizedBox(
                          width: 80,
                          height: 80,
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation(primaryColor),
                            strokeWidth: 3,
                            backgroundColor: primaryColor.withOpacity(0.1),
                          ),
                        ),
                        // Inner pulsing circle
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 1000),
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: primaryColor.withOpacity(0.2),
                          ),
                        ),
                        // App icon/logo
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: primaryColor,
                          ),
                          child: const Icon(
                            Icons.security_outlined,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Initializing FallGuard...',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Starting monitoring service',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
