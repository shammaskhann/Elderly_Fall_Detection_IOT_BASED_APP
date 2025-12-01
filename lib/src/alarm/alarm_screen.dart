// import 'dart:async';
// import 'dart:developer';
// import 'package:audioplayers/audioplayers.dart';
// import 'package:flutter/material.dart';
// import 'package:geolocator/geolocator.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import 'package:telephony/telephony.dart';
// import 'package:torch_light/torch_light.dart';
// import 'package:vibration/vibration.dart';

// class AlarmScreen extends StatefulWidget {
//   static const String routeName = '/alarm';
//   const AlarmScreen({super.key});

//   @override
//   State<AlarmScreen> createState() => _AlarmScreenState();
// }

// class _AlarmScreenState extends State<AlarmScreen> {
//   final AudioPlayer _player = AudioPlayer();
//   Timer? _sirenTimer;
//   Timer? _flashTimer;
//   Timer? _autoSmsTimer;
//   bool _phaseAlt = false;
//   bool _flashOn = false;
//   bool _sending = false;
//   int _secondsLeft = 60;

//   @override
//   void initState() {
//     super.initState();
//     _startAlarm();
//   }

//   @override
//   void dispose() {
//     // Ensure everything is stopped when screen is disposed
//     _stopAlarm();
//     super.dispose();
//   }

//   Future<void> _startAlarm() async {
//     _startSiren();
//     _startVibration();
//     _startFlash();
//     _startAutoSmsCountdown();
//   }

//   Future<void> _stopAlarm() async {
//     log('Stopping alarm - canceling timers and stopping all effects');

//     // Cancel all timers first
//     _sirenTimer?.cancel();
//     _flashTimer?.cancel();
//     _autoSmsTimer?.cancel();
//     _sirenTimer = null;
//     _flashTimer = null;
//     _autoSmsTimer = null;

//     // Stop audio
//     try {
//       await _player.stop();
//     } catch (e) {
//       log('Error stopping audio: $e');
//     }

//     // Stop vibration
//     try {
//       Vibration.cancel();
//     } catch (e) {
//       log('Error canceling vibration: $e');
//     }

//     // Force turn off flashlight - try multiple times to ensure it's off
//     for (int i = 0; i < 3; i++) {
//       try {
//         await TorchLight.disableTorch();
//         _flashOn = false;
//         // Small delay between attempts
//         if (i < 2) {
//           await Future.delayed(const Duration(milliseconds: 100));
//         }
//       } catch (e) {
//         log('Error disabling torch (attempt ${i + 1}): $e');
//       }
//     }

//     log('Alarm stopped successfully');
//   }

//   void _startSiren() {
//     // Alternate between two tones every few seconds
//     _playTone(_phaseAlt ? 880 : 1200);
//     _sirenTimer = Timer.periodic(const Duration(seconds: 4), (t) {
//       _phaseAlt = !_phaseAlt;
//       _playTone(_phaseAlt ? 880 : 1200);
//     });
//   }

//   Future<void> _playTone(int hz) async {
//     // Use synthesised tone via url source data-URI, or bundle assets in future
//     await _player.stop();
//     await _player.setVolume(1.0);
//     // Use a short beep loop; fallback to repeating a short asset would be better
//     await _player.play(
//       AssetSource("alarm_sound.mp3"),
//       volume: 1.0,
//     ); // no-op to init
//   }

//   void _startVibration() async {
//     final hasVibrator = await Vibration.hasVibrator();
//     if (hasVibrator == true) {
//       Vibration.vibrate(
//         pattern: [0, 1000, 500, 1000, 500],
//         intensities: [128, 255, 128, 255, 128], // ✅ Now 5 values
//         repeat: 0,
//       );
//     }
//   }

//   void _startFlash() {
//     _flashTimer = Timer.periodic(const Duration(milliseconds: 600), (t) async {
//       if (!mounted) {
//         t.cancel();
//         return;
//       }
//       try {
//         if (_flashOn) {
//           await TorchLight.disableTorch();
//           if (mounted) {
//             setState(() {
//               _flashOn = false;
//             });
//           }
//         } else {
//           await TorchLight.enableTorch();
//           if (mounted) {
//             setState(() {
//               _flashOn = true;
//             });
//           }
//         }
//       } catch (e) {
//         log('Error toggling flash: $e');
//       }
//     });
//   }

//   void _startAutoSmsCountdown() {
//     _autoSmsTimer = Timer.periodic(const Duration(seconds: 1), (t) async {
//       if (!mounted) return;
//       setState(() => _secondsLeft = _secondsLeft - 1);
//       if (_secondsLeft <= 0) {
//         _autoSmsTimer?.cancel();
//         await _sendHelpSms();
//       }
//     });
//   }

//   Future<void> _sendHelpSms() async {
//     if (_sending) return;
//     _sending = true;
//     final prefs = await SharedPreferences.getInstance();
//     final phone = prefs.getString('emergency_phone');
//     if (phone == null || phone.isEmpty) {
//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(content: Text('No emergency contact set')),
//         );
//       }
//       return;
//     }
//     Position? pos;
//     try {
//       pos = await Geolocator.getCurrentPosition(
//         timeLimit: const Duration(seconds: 8),
//       );
//     } catch (_) {
//       try {
//         pos = await Geolocator.getLastKnownPosition();
//       } catch (_) {}
//     }
//     final locationText = pos != null
//         ? 'Location: https://maps.google.com/?q=${pos.latitude},${pos.longitude}'
//         : 'Location unavailable';
//     final msg =
//         'Emergency! Possible fall detected. Please check immediately. $locationText';
//     try {
//       final telephony = Telephony.instance;
//       await telephony.sendSms(to: phone, message: msg, isMultipart: true);
//       if (mounted) {
//         ScaffoldMessenger.of(
//           context,
//         ).showSnackBar(const SnackBar(content: Text('Emergency SMS sent')));
//       }
//     } catch (_) {
//       if (mounted) {
//         ScaffoldMessenger.of(
//           context,
//         ).showSnackBar(const SnackBar(content: Text('Failed to send SMS')));
//       }
//     }
//   }

//   Future<void> _cancelAlarm() async {
//     log('cancelAlarm - stopping alarm and navigating back');
//     await _stopAlarm();
//     if (mounted) {
//       // Navigate back to home screen, removing all routes
//       Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
//     }
//   }

//   Future<void> _confirmEmergency() async {
//     await _sendHelpSms();
//     await _stopAlarm();
//     if (mounted) {
//       // Navigate back to home screen after sending SMS
//       Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Colors.black,
//       body: SafeArea(
//         child: Column(
//           children: [
//             const SizedBox(height: 24),
//             const Text(
//               'Emergency Detected',
//               style: TextStyle(
//                 color: Colors.white,
//                 fontSize: 28,
//                 fontWeight: FontWeight.bold,
//               ),
//             ),
//             const SizedBox(height: 8),
//             Text(
//               'Sending SMS in $_secondsLeft s',
//               style: const TextStyle(color: Colors.white70),
//             ),
//             const SizedBox(height: 24),
//             Expanded(
//               child: Center(
//                 child: Icon(
//                   Icons.warning_amber_rounded,
//                   color: Colors.red.shade400,
//                   size: 160,
//                 ),
//               ),
//             ),
//             Padding(
//               padding: const EdgeInsets.all(16.0),
//               child: _SwipeAction(
//                 color: Colors.green,
//                 icon: Icons.check,
//                 label: 'Call Help',
//                 onConfirmed: _confirmEmergency,
//               ),
//             ),
//             Padding(
//               padding: const EdgeInsets.all(16.0),
//               child: _SwipeAction(
//                 color: Colors.grey.shade700,
//                 icon: Icons.close,
//                 label: 'I am OK',
//                 onConfirmed: _cancelAlarm,
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }

// class _SwipeAction extends StatefulWidget {
//   const _SwipeAction({
//     required this.color,
//     required this.icon,
//     required this.label,
//     required this.onConfirmed,
//   });
//   final Color color;
//   final IconData icon;
//   final String label;
//   final Future<void> Function() onConfirmed; // ✅ allows awaiting

//   @override
//   State<_SwipeAction> createState() => _SwipeActionState();
// }

// class _SwipeActionState extends State<_SwipeAction> {
//   double _progress = 0.0;
//   double _dragStartX = 0.0;
//   bool _isDragging = false;

//   @override
//   Widget build(BuildContext context) {
//     final screenWidth = MediaQuery.of(context).size.width;
//     final buttonWidth =
//         screenWidth - 32; // Account for padding (16px on each side)

//     return GestureDetector(
//       onHorizontalDragStart: (details) {
//         // Record the global position where drag started
//         _dragStartX = details.globalPosition.dx;
//         setState(() {
//           _isDragging = true;
//           _progress = 0.0;
//         });
//       },
//       onHorizontalDragUpdate: (details) {
//         // Calculate how far user has dragged from start (right = positive)
//         final dragDistance = details.globalPosition.dx - _dragStartX;
//         // Only allow positive drag (right swipe)
//         final newProgress = (dragDistance / buttonWidth).clamp(0.0, 1.0);
//         setState(() {
//           _progress = newProgress;
//         });
//       },
//       onHorizontalDragEnd: (details) async {
//         setState(() {
//           _isDragging = false;
//         });

//         // If swiped more than 75% of the button width, trigger action
//         if (_progress >= 0.75) {
//           log('Swipe action confirmed: ${widget.label} (progress: $_progress)');
//           await widget.onConfirmed();
//         } else {
//           // Reset progress if not swiped enough
//           log('Swipe action cancelled: ${widget.label} (progress: $_progress)');
//           setState(() {
//             _progress = 0.0;
//           });
//         }
//       },
//       onHorizontalDragCancel: () {
//         setState(() {
//           _isDragging = false;
//           _progress = 0.0;
//         });
//       },
//       child: Container(
//         height: 64,
//         width: double.infinity,
//         decoration: BoxDecoration(
//           color: widget.color,
//           borderRadius: BorderRadius.circular(16),
//         ),
//         child: Stack(
//           clipBehavior: Clip.none,
//           children: [
//             // Background label
//             Positioned.fill(
//               child: Center(
//                 child: Opacity(
//                   opacity: 1.0 - (_progress * 0.7),
//                   child: Text(
//                     widget.label,
//                     style: const TextStyle(
//                       color: Colors.white,
//                       fontSize: 18,
//                       fontWeight: FontWeight.w600,
//                     ),
//                   ),
//                 ),
//               ),
//             ),
//             // Progress overlay (white overlay from left)
//             Align(
//               alignment: Alignment.centerLeft,
//               child: FractionallySizedBox(
//                 widthFactor: _progress,
//                 child: Container(
//                   decoration: BoxDecoration(
//                     color: Colors.white.withOpacity(0.3),
//                     borderRadius: BorderRadius.circular(16),
//                   ),
//                 ),
//               ),
//             ),
//             // Icon that moves with swipe
//             if (_progress > 0.05)
//               Positioned(
//                 left: 12 + (_progress * (buttonWidth - 52)),
//                 top: 12,
//                 bottom: 12,
//                 child: Container(
//                   width: 40,
//                   height: 40,
//                   decoration: BoxDecoration(
//                     color: Colors.white,
//                     borderRadius: BorderRadius.circular(12),
//                     boxShadow: [
//                       BoxShadow(
//                         color: Colors.black.withOpacity(0.3),
//                         blurRadius: 6,
//                         offset: const Offset(0, 2),
//                       ),
//                     ],
//                   ),
//                   child: Icon(widget.icon, color: widget.color, size: 24),
//                 ),
//               ),
//             // Visual feedback when swipe is almost complete (75% threshold)
//             if (_progress >= 0.75)
//               Positioned.fill(
//                 child: Container(
//                   decoration: BoxDecoration(
//                     color: Colors.white.withOpacity(0.15),
//                     borderRadius: BorderRadius.circular(16),
//                   ),
//                 ),
//               ),
//             // Swipe hint (show when not dragging)
//             if (!_isDragging && _progress < 0.1)
//               Positioned(
//                 right: 16,
//                 top: 0,
//                 bottom: 0,
//                 child: Center(
//                   child: Icon(
//                     Icons.arrow_forward_ios,
//                     color: Colors.white.withOpacity(0.5),
//                     size: 20,
//                   ),
//                 ),
//               ),
//           ],
//         ),
//       ),
//     );
//   }
// }
import 'dart:async';
import 'dart:math';
import 'package:audioplayers/audioplayers.dart';
import 'package:fall_detection_app/main.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:telephony/telephony.dart';
import 'package:torch_light/torch_light.dart';
import 'package:vibration/vibration.dart';

class AlarmScreen extends StatefulWidget {
  static const String routeName = '/alarm';
  const AlarmScreen({super.key});

  @override
  State<AlarmScreen> createState() => _AlarmScreenState();
}

class _AlarmScreenState extends State<AlarmScreen>
    with SingleTickerProviderStateMixin {
  final AudioPlayer _player = AudioPlayer();
  Timer? _sirenTimer;
  Timer? _flashTimer;
  Timer? _autoSmsTimer;
  Timer? _pulseTimer;
  bool _phaseAlt = false;
  bool _flashOn = false;
  bool _sending = false;
  int _secondsLeft = 60;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

    // Initialize pulse animation
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOutCubic),
    );

    _startAlarm();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _stopAlarm();
    super.dispose();
  }

  Future<void> _startAlarm() async {
    _startSiren();
    _startVibration();
    _startFlash();
    _startAutoSmsCountdown();
  }

  Future<void> _stopAlarm() async {
    _sirenTimer?.cancel();
    _flashTimer?.cancel();
    _autoSmsTimer?.cancel();
    _pulseTimer?.cancel();

    try {
      await _player.stop();
      Vibration.cancel();

      // Ensure flashlight is turned off
      for (int i = 0; i < 3; i++) {
        try {
          await TorchLight.disableTorch();
          if (i < 2) await Future.delayed(const Duration(milliseconds: 100));
        } catch (_) {}
      }
    } catch (_) {}

    _flashOn = false;
  }

  void _startSiren() {
    _playTone(_phaseAlt ? 880 : 1200);
    _sirenTimer = Timer.periodic(const Duration(seconds: 4), (t) {
      _phaseAlt = !_phaseAlt;
      _playTone(_phaseAlt ? 880 : 1200);
    });
  }

  Future<void> _playTone(int hz) async {
    await _player.stop();
    await _player.setVolume(1.0);
    await _player.play(AssetSource("alarm_sound.mp3"), volume: 1.0);
  }

  void _startVibration() async {
    final hasVibrator = await Vibration.hasVibrator();
    if (hasVibrator == true) {
      Vibration.vibrate(
        pattern: [0, 1000, 500, 1000, 500],
        intensities: [128, 255, 128, 255, 128],
        repeat: 0,
      );
    }
  }

  void _startFlash() {
    _flashTimer = Timer.periodic(const Duration(milliseconds: 600), (t) async {
      if (!mounted) {
        t.cancel();
        return;
      }
      try {
        if (_flashOn) {
          await TorchLight.disableTorch();
          if (mounted) setState(() => _flashOn = false);
        } else {
          await TorchLight.enableTorch();
          if (mounted) setState(() => _flashOn = true);
        }
      } catch (_) {}
    });
  }

  void _startAutoSmsCountdown() {
    _autoSmsTimer = Timer.periodic(const Duration(seconds: 1), (t) async {
      if (!mounted) return;
      setState(() => _secondsLeft = _secondsLeft - 1);
      if (_secondsLeft <= 0) {
        t.cancel();
        await _sendHelpSms();
      }
    });
  }

  Future<void> _sendHelpSms() async {
    if (_sending) return;
    _sending = true;

    final prefs = await SharedPreferences.getInstance();
    final phone = prefs.getString('emergency_phone');
    if (phone == null || phone.isEmpty) {
      if (mounted) {
        _showFeedback('No emergency contact set', warningColor);
      }
      _sending = false;
      return;
    }

    Position? pos;
    try {
      pos = await Geolocator.getCurrentPosition(
        timeLimit: const Duration(seconds: 8),
      );
    } catch (_) {
      try {
        pos = await Geolocator.getLastKnownPosition();
      } catch (_) {}
    }

    final locationText = pos != null
        ? 'Location: https://maps.google.com/?q=${pos.latitude},${pos.longitude}'
        : 'Location unavailable';
    final msg =
        'Emergency! Possible fall detected. Please check immediately. $locationText';

    try {
      final telephony = Telephony.instance;
      await telephony.sendSms(to: phone, message: msg, isMultipart: true);
      if (mounted) {
        _showFeedback('Emergency SMS sent', successColor);
      }
    } catch (_) {
      if (mounted) {
        _showFeedback('Failed to send SMS', dangerColor);
      }
    }

    _sending = false;
  }

  void _showFeedback(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              color == successColor ? Icons.check_circle : Icons.error_outline,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(message),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Future<void> _cancelAlarm() async {
    await _stopAlarm();
    if (mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
    }
  }

  Future<void> _confirmEmergency() async {
    await _sendHelpSms();
    await _stopAlarm();
    if (mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
    }
  }

  Widget _buildCountdownCircle() {
    return SizedBox(
      width: 200,
      height: 200,
      child: Stack(
        children: [
          // Background circle
          Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: surfaceColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.red.withOpacity(0.3),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),

          // Animated pulse ring
          ScaleTransition(
            scale: _pulseAnimation,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.red.withOpacity(0.4),
                  width: 4,
                ),
              ),
            ),
          ),

          // Countdown text
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$_secondsLeft',
                  style: const TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.w800,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'SECONDS',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: textSecondary,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
          ),

          // Progress indicator
          SizedBox(
            width: 200,
            height: 200,
            child: CircularProgressIndicator(
              value: _secondsLeft / 60,
              strokeWidth: 4,
              backgroundColor: Colors.red.withOpacity(0.2),
              valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusRow() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Column(
            children: [
              Icon(Icons.volume_up, color: Colors.red, size: 20),
              const SizedBox(height: 4),
              const Text(
                'Siren',
                style: TextStyle(fontSize: 12, color: textSecondary),
              ),
            ],
          ),
          Column(
            children: [
              Icon(
                Icons.vibration,
                color: _flashOn ? Colors.red : Colors.grey,
                size: 20,
              ),
              const SizedBox(height: 4),
              const Text(
                'Vibration',
                style: TextStyle(fontSize: 12, color: textSecondary),
              ),
            ],
          ),
          Column(
            children: [
              Icon(
                Icons.flash_on,
                color: _flashOn ? Colors.yellow : Colors.grey,
                size: 20,
              ),
              const SizedBox(height: 4),
              const Text(
                'Flash',
                style: TextStyle(fontSize: 12, color: textSecondary),
              ),
            ],
          ),
          Column(
            children: [
              Icon(
                Icons.notifications_active,
                color: _secondsLeft <= 15 ? Colors.red : textSecondary,
                size: 20,
              ),
              const SizedBox(height: 4),
              const Text(
                'SMS Alert',
                style: TextStyle(fontSize: 12, color: textSecondary),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          color: Colors.red,
                          size: 24,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'FALL DETECTED',
                          style: TextStyle(
                            color: Colors.red,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Emergency Alert Activated',
                      style: TextStyle(color: textSecondary, fontSize: 14),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Countdown and main content
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      _buildCountdownCircle(),

                      const SizedBox(height: 32),

                      const Text(
                        'Automatic SMS will be sent to your\nemergency contact',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: textSecondary,
                          fontSize: 14,
                          height: 1.5,
                        ),
                      ),

                      const SizedBox(height: 4),

                      Text(
                        _secondsLeft > 0
                            ? 'in $_secondsLeft seconds'
                            : 'Sending now...',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _secondsLeft <= 15 ? Colors.red : textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),

                      const SizedBox(height: 32),

                      _buildStatusRow(),

                      const SizedBox(height: 32),

                      const Text(
                        'Please confirm your status immediately',
                        style: TextStyle(color: textSecondary, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),

              // Swipe Actions
              Column(
                children: [
                  // Emergency Action
                  ModernSwipeButton(
                    title: 'SEND EMERGENCY ALERT',
                    subtitle: 'Immediately notify emergency contact',
                    color: dangerColor,
                    icon: Icons.emergency_outlined,
                    onSwipeComplete: _confirmEmergency,
                    swipeDirection: SwipeDirection.right,
                  ),

                  const SizedBox(height: 16),

                  // Cancel Action
                  ModernSwipeButton(
                    title: 'I AM SAFE',
                    subtitle: 'Cancel the emergency alert',
                    color: successColor,
                    icon: Icons.check_circle_outline,
                    onSwipeComplete: _cancelAlarm,
                    swipeDirection: SwipeDirection.right,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum SwipeDirection { left, right }

class ModernSwipeButton extends StatefulWidget {
  final String title;
  final String subtitle;
  final Color color;
  final IconData icon;
  final VoidCallback onSwipeComplete;
  final SwipeDirection swipeDirection;

  const ModernSwipeButton({
    super.key,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.icon,
    required this.onSwipeComplete,
    required this.swipeDirection,
  });

  @override
  State<ModernSwipeButton> createState() => _ModernSwipeButtonState();
}

class _ModernSwipeButtonState extends State<ModernSwipeButton> {
  double _progress = 0.0;
  bool _isSwiping = false;
  bool _isComplete = false;
  // initialize to 0 and compute fallback in build/handlers to avoid LateInitializationError
  double _containerWidth = 0.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _containerWidth = MediaQuery.of(context).size.width - 40;
        });
      }
    });
  }

  void _onHorizontalDragStart(DragStartDetails details) {
    if (_isComplete) return;
    setState(() {
      _isSwiping = true;
      _progress = 0.0;
    });
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    if (_isComplete) return;

    final dx = details.delta.dx;
    // use computed width if not yet initialized
    final cw = _containerWidth > 0
        ? _containerWidth
        : MediaQuery.of(context).size.width - 40;
    final newProgress = _progress + (dx / cw);

    setState(() {
      // Only allow positive progress
      _progress = newProgress.clamp(0.0, 1.0);
    });
  }

  void _onHorizontalDragEnd(DragEndDetails details) async {
    if (_isComplete) return;

    if (_progress >= 0.75) {
      // Swipe successful
      setState(() {
        _isComplete = true;
      });

      // Add haptic feedback
      await Vibration.vibrate(duration: 100);

      // Trigger the callback
      widget.onSwipeComplete();
    } else {
      // Swipe not far enough - reset with animation
      _resetProgress();
    }
  }

  void _resetProgress() {
    setState(() {
      _isSwiping = false;
      _progress = 0.0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isRightSwipe = widget.swipeDirection == SwipeDirection.right;
    final isLeftSwipe = widget.swipeDirection == SwipeDirection.left;

    // fallback container width if post-frame callback hasn't set it yet
    final containerWidth = _containerWidth > 0
        ? _containerWidth
        : MediaQuery.of(context).size.width - 40;

    return GestureDetector(
      onHorizontalDragStart: _onHorizontalDragStart,
      onHorizontalDragUpdate: _onHorizontalDragUpdate,
      onHorizontalDragEnd: _onHorizontalDragEnd,
      child: Container(
        height: 80,
        width: double.infinity,
        margin: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: widget.color.withOpacity(0.3), width: 2),
        ),
        child: Stack(
          children: [
            // Background fill that expands with swipe
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: containerWidth * _progress,
              decoration: BoxDecoration(
                color: widget.color.withOpacity(0.15),
                borderRadius: isRightSwipe
                    ? const BorderRadius.horizontal(left: Radius.circular(14))
                    : isLeftSwipe
                    ? const BorderRadius.horizontal(right: Radius.circular(14))
                    : BorderRadius.circular(14),
              ),
            ),

            // Content
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Icon and text (left side for right swipe, right side for left swipe)
                  if (isRightSwipe) ...[
                    _buildContent(),
                    _buildArrowAndProgress(),
                  ] else if (isLeftSwipe) ...[
                    _buildArrowAndProgress(reverse: true),
                    _buildContent(),
                  ],
                ],
              ),
            ),

            // Draggable thumb
            if (_progress > 0 && !_isComplete)
              Positioned(
                left: isRightSwipe ? _progress * (containerWidth - 56) : null,
                right: isLeftSwipe ? _progress * (containerWidth - 56) : null,
                top: 12,
                bottom: 12,
                child: Container(
                  width: 56,
                  decoration: BoxDecoration(
                    color: widget.color,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: widget.color.withOpacity(0.5),
                        blurRadius: 8,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Icon(widget.icon, color: Colors.white, size: 24),
                ),
              ),

            // Success overlay
            if (_isComplete)
              Container(
                decoration: BoxDecoration(
                  color: widget.color.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(widget.icon, color: Colors.white, size: 24),
                      const SizedBox(width: 12),
                      Text(
                        '${widget.title} • CONFIRMED',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    return Flexible(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.title,
            style: const TextStyle(
              color: textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            widget.subtitle,
            style: TextStyle(color: textSecondary, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildArrowAndProgress({bool reverse = false}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Progress indicator
        if (_progress > 0 && _progress < 0.75)
          SizedBox(
            width: 40,
            child: LinearProgressIndicator(
              value: _progress,
              backgroundColor: Colors.transparent,
              valueColor: AlwaysStoppedAnimation<Color>(widget.color),
              borderRadius: BorderRadius.circular(10),
            ),
          ),

        const SizedBox(width: 8),

        // Arrow
        Transform.rotate(
          angle: reverse ? pi : 0,
          child: Icon(
            _progress >= 0.75 ? Icons.check : Icons.arrow_forward_ios_rounded,
            color: _progress >= 0.75 ? widget.color : textSecondary,
            size: _progress >= 0.75 ? 24 : 20,
          ),
        ),
      ],
    );
  }
}
