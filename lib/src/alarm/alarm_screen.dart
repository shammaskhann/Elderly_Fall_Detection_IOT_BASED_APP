import 'dart:async';
import 'dart:developer';
import 'package:audioplayers/audioplayers.dart';
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

class _AlarmScreenState extends State<AlarmScreen> {
  final AudioPlayer _player = AudioPlayer();
  Timer? _sirenTimer;
  Timer? _flashTimer;
  Timer? _autoSmsTimer;
  bool _phaseAlt = false;
  bool _flashOn = false;
  bool _sending = false;
  int _secondsLeft = 60;

  @override
  void initState() {
    super.initState();
    _startAlarm();
  }

  @override
  void dispose() {
    // Ensure everything is stopped when screen is disposed
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
    log('Stopping alarm - canceling timers and stopping all effects');

    // Cancel all timers first
    _sirenTimer?.cancel();
    _flashTimer?.cancel();
    _autoSmsTimer?.cancel();
    _sirenTimer = null;
    _flashTimer = null;
    _autoSmsTimer = null;

    // Stop audio
    try {
      await _player.stop();
    } catch (e) {
      log('Error stopping audio: $e');
    }

    // Stop vibration
    try {
      Vibration.cancel();
    } catch (e) {
      log('Error canceling vibration: $e');
    }

    // Force turn off flashlight - try multiple times to ensure it's off
    for (int i = 0; i < 3; i++) {
      try {
        await TorchLight.disableTorch();
        _flashOn = false;
        // Small delay between attempts
        if (i < 2) {
          await Future.delayed(const Duration(milliseconds: 100));
        }
      } catch (e) {
        log('Error disabling torch (attempt ${i + 1}): $e');
      }
    }

    log('Alarm stopped successfully');
  }

  void _startSiren() {
    // Alternate between two tones every few seconds
    _playTone(_phaseAlt ? 880 : 1200);
    _sirenTimer = Timer.periodic(const Duration(seconds: 4), (t) {
      _phaseAlt = !_phaseAlt;
      _playTone(_phaseAlt ? 880 : 1200);
    });
  }

  Future<void> _playTone(int hz) async {
    // Use synthesised tone via url source data-URI, or bundle assets in future
    await _player.stop();
    await _player.setVolume(1.0);
    // Use a short beep loop; fallback to repeating a short asset would be better
    await _player.play(
      AssetSource("alarm_sound.mp3"),
      volume: 1.0,
    ); // no-op to init
  }

  void _startVibration() async {
    final hasVibrator = await Vibration.hasVibrator();
    if (hasVibrator == true) {
      Vibration.vibrate(
        pattern: [0, 1000, 500, 1000, 500],
        intensities: [128, 255, 128, 255, 128], // ✅ Now 5 values
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
          if (mounted) {
            setState(() {
              _flashOn = false;
            });
          }
        } else {
          await TorchLight.enableTorch();
          if (mounted) {
            setState(() {
              _flashOn = true;
            });
          }
        }
      } catch (e) {
        log('Error toggling flash: $e');
      }
    });
  }

  void _startAutoSmsCountdown() {
    _autoSmsTimer = Timer.periodic(const Duration(seconds: 1), (t) async {
      if (!mounted) return;
      setState(() => _secondsLeft = _secondsLeft - 1);
      if (_secondsLeft <= 0) {
        _autoSmsTimer?.cancel();
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No emergency contact set')),
        );
      }
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Emergency SMS sent')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Failed to send SMS')));
      }
    }
  }

  Future<void> _cancelAlarm() async {
    log('cancelAlarm - stopping alarm and navigating back');
    await _stopAlarm();
    if (mounted) {
      // Navigate back to home screen, removing all routes
      Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
    }
  }

  Future<void> _confirmEmergency() async {
    await _sendHelpSms();
    await _stopAlarm();
    if (mounted) {
      // Navigate back to home screen after sending SMS
      Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 24),
            const Text(
              'Emergency Detected',
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Sending SMS in $_secondsLeft s',
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: Center(
                child: Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.red.shade400,
                  size: 160,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: _SwipeAction(
                color: Colors.green,
                icon: Icons.check,
                label: 'Call Help',
                onConfirmed: _confirmEmergency,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: _SwipeAction(
                color: Colors.grey.shade700,
                icon: Icons.close,
                label: 'I am OK',
                onConfirmed: _cancelAlarm,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SwipeAction extends StatefulWidget {
  const _SwipeAction({
    required this.color,
    required this.icon,
    required this.label,
    required this.onConfirmed,
  });
  final Color color;
  final IconData icon;
  final String label;
  final Future<void> Function() onConfirmed; // ✅ allows awaiting

  @override
  State<_SwipeAction> createState() => _SwipeActionState();
}

class _SwipeActionState extends State<_SwipeAction> {
  double _progress = 0.0;
  double _dragStartX = 0.0;
  bool _isDragging = false;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final buttonWidth =
        screenWidth - 32; // Account for padding (16px on each side)

    return GestureDetector(
      onHorizontalDragStart: (details) {
        // Record the global position where drag started
        _dragStartX = details.globalPosition.dx;
        setState(() {
          _isDragging = true;
          _progress = 0.0;
        });
      },
      onHorizontalDragUpdate: (details) {
        // Calculate how far user has dragged from start (right = positive)
        final dragDistance = details.globalPosition.dx - _dragStartX;
        // Only allow positive drag (right swipe)
        final newProgress = (dragDistance / buttonWidth).clamp(0.0, 1.0);
        setState(() {
          _progress = newProgress;
        });
      },
      onHorizontalDragEnd: (details) async {
        setState(() {
          _isDragging = false;
        });

        // If swiped more than 75% of the button width, trigger action
        if (_progress >= 0.75) {
          log('Swipe action confirmed: ${widget.label} (progress: $_progress)');
          await widget.onConfirmed();
        } else {
          // Reset progress if not swiped enough
          log('Swipe action cancelled: ${widget.label} (progress: $_progress)');
          setState(() {
            _progress = 0.0;
          });
        }
      },
      onHorizontalDragCancel: () {
        setState(() {
          _isDragging = false;
          _progress = 0.0;
        });
      },
      child: Container(
        height: 64,
        width: double.infinity,
        decoration: BoxDecoration(
          color: widget.color,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Background label
            Positioned.fill(
              child: Center(
                child: Opacity(
                  opacity: 1.0 - (_progress * 0.7),
                  child: Text(
                    widget.label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
            // Progress overlay (white overlay from left)
            Align(
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: _progress,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
            // Icon that moves with swipe
            if (_progress > 0.05)
              Positioned(
                left: 12 + (_progress * (buttonWidth - 52)),
                top: 12,
                bottom: 12,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(widget.icon, color: widget.color, size: 24),
                ),
              ),
            // Visual feedback when swipe is almost complete (75% threshold)
            if (_progress >= 0.75)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            // Swipe hint (show when not dragging)
            if (!_isDragging && _progress < 0.1)
              Positioned(
                right: 16,
                top: 0,
                bottom: 0,
                child: Center(
                  child: Icon(
                    Icons.arrow_forward_ios,
                    color: Colors.white.withOpacity(0.5),
                    size: 20,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
