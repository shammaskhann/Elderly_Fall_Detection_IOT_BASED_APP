# Fall Detection App

A Flutter-based mobile application designed to automatically detect falls using smartphone accelerometer sensors and trigger emergency alerts. This app is particularly useful for elderly individuals or anyone at risk of falls, providing automatic detection and emergency response capabilities.

## 📋 Table of Contents

- [Overview](#overview)
- [Features](#features)
- [How It Works](#how-it-works)
- [Fall Detection Algorithm](#fall-detection-algorithm)
- [Installation](#installation)
- [Usage](#usage)
- [Architecture](#architecture)
- [Technical Details](#technical-details)
- [Permissions](#permissions)
- [Project Structure](#project-structure)
- [Dependencies](#dependencies)
- [Terms & Glossary](#terms--glossary)
- [Troubleshooting](#troubleshooting)
- [Contributing](#contributing)
- [License](#license)

## 🎯 Overview

The Fall Detection App is a real-time monitoring system that continuously tracks user movement patterns using the device's built-in accelerometer. When a potential fall is detected, the app immediately triggers a full-screen alarm with multiple alert mechanisms and can automatically send an emergency SMS with location information to a pre-configured emergency contact.

### Key Capabilities

- **Continuous Monitoring**: Runs in the background using a foreground service
- **Real-time Detection**: Analyzes accelerometer data at 20Hz (50ms intervals)
- **Multi-modal Alerts**: Audio, vibration, and visual (flashlight) alerts
- **Emergency SMS**: Automatic SMS with GPS location after 60-second countdown
- **User Confirmation**: Swipe-to-confirm interface to prevent false alarms

## ✨ Features

### Core Features

1. **Background Monitoring**
   - Foreground service keeps the app running even when the screen is off
   - Wakelock prevents CPU sleep during monitoring
   - Continuous accelerometer sampling at 20Hz

2. **Intelligent Fall Detection**
   - Two-phase detection algorithm (spike + stillness)
   - Configurable sensitivity thresholds
   - Duplicate alarm suppression (20-second cooldown)

3. **Emergency Response System**
   - Full-screen alarm interface
   - Alternating audio siren tones
   - Pattern-based vibration alerts
   - Strobing flashlight effect
   - 60-second countdown to automatic SMS

4. **Location Services**
   - GPS location capture on fall detection
   - Google Maps link in emergency SMS
   - Fallback to last known position if GPS unavailable

5. **User Interface**
   - Simple start/stop monitoring controls
   - Real-time sample count display
   - Settings page for emergency contact configuration
   - Test alarm functionality

## 🔬 How It Works

### System Flow

```
┌─────────────────┐
│  User Starts    │
│   Monitoring    │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ Foreground      │
│ Service Starts  │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ Accelerometer   │
│ Stream Active   │
│ (20Hz sampling) │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ Fall Detector   │
│ Analyzes Each   │
│ Sample          │
└────────┬────────┘
         │
    ┌────┴────┐
    │         │
    ▼         ▼
┌──────┐  ┌──────────┐
│ No   │  │ Potential│
│ Fall │  │   Fall   │
└──────┘  └────┬─────┘
               │
               ▼
      ┌────────────────┐
      │ Alarm Screen   │
      │ Activated      │
      └────────┬───────┘
               │
               ▼
      ┌────────────────┐
      │ 60s Countdown  │
      │ Auto-SMS       │
      └────────────────┘
```

## 🧮 Fall Detection Algorithm

### Detection Methodology

The app uses a **two-phase heuristic algorithm** to identify potential falls:

#### Phase 1: Acceleration Spike Detection

The algorithm first detects a significant acceleration spike, which typically occurs when a person hits the ground during a fall.

**Calculation:**
```dart
// Acceleration magnitude in g-force units
magnitude_g = √(x² + y² + z²) / 9.80665

where:
- x, y, z = accelerometer readings in m/s²
- 9.80665 = standard gravity acceleration (m/s²)
- magnitude_g = total acceleration in g-force units
```

**Threshold:**
- **Spike Threshold**: `2.5g` (2.5 times Earth's gravity)
- When acceleration exceeds this threshold, the system records the timestamp and enters Phase 2 monitoring

#### Phase 2: Stillness Window Detection

After a spike, the algorithm monitors for a period of relative stillness, which indicates the person may be lying down after a fall.

**Parameters:**
- **Stillness Threshold**: `0.2g` (very low movement)
- **Stillness Window**: `700 milliseconds` (0.7 seconds)
- **Detection Logic**: If acceleration drops below 0.2g within 700ms after a spike, a fall is detected

### Algorithm Pseudocode

```
1. For each accelerometer sample:
   a. Calculate magnitude_g = √(x² + y² + z²) / 9.80665
   
2. If magnitude_g > 2.5g:
   a. Record current timestamp as spike_time
   b. Continue monitoring
   
3. If spike_time exists:
   a. Calculate elapsed = current_time - spike_time
   b. If elapsed ≤ 700ms AND magnitude_g < 0.2g:
      → FALL DETECTED
   c. If elapsed > 700ms:
      → Reset spike_time (false alarm)
```

### Mathematical Formula

The complete detection condition is:

```
FALL_DETECTED = (magnitude_g(t_spike) > 2.5g) 
                AND 
                (magnitude_g(t_current) < 0.2g) 
                AND 
                (t_current - t_spike ≤ 700ms)
```

Where:
- `t_spike` = timestamp when acceleration spike occurred
- `t_current` = current timestamp
- `magnitude_g(t)` = acceleration magnitude at time t

### Why This Algorithm Works

1. **Spike Detection (2.5g)**: Normal activities rarely exceed 2.5g. Falls typically produce 3-8g impacts.
2. **Stillness Window (0.2g)**: After a fall, a person usually remains still. Normal movement maintains >0.5g.
3. **Time Window (700ms)**: Falls happen quickly. The 700ms window captures the immediate post-fall stillness.

### False Positive Mitigation

- **Duplicate Suppression**: 20-second cooldown between alarms prevents spam
- **User Confirmation**: Swipe-to-confirm interface allows users to cancel false alarms
- **Configurable Thresholds**: Thresholds can be tuned based on real-world data

### Data Buffer

The app maintains a rolling buffer of the last 200 accelerometer samples (~10 seconds at 20Hz) for:
- Debugging and analysis
- Potential future algorithm improvements
- Post-detection analysis

## 📱 Installation

### Prerequisites

- Flutter SDK 3.9.0 or higher
- Dart SDK (included with Flutter)
- Android Studio / Xcode (for mobile development)
- Physical device with accelerometer (required for testing)

### Setup Steps

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd fall_detection_app
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Configure permissions** (see [Permissions](#permissions) section)

4. **Run the app**
   ```bash
   flutter run
   ```

### Platform-Specific Setup

#### Android

1. Ensure `minSdkVersion` is 21 or higher in `android/app/build.gradle`
2. Permissions are automatically configured in `AndroidManifest.xml`
3. The app requires Android 5.0 (API 21) or higher

#### iOS

1. Ensure iOS deployment target is 12.0 or higher
2. Permissions are configured in `Info.plist`
3. Requires physical device for accelerometer access (simulator doesn't support sensors)

## 🚀 Usage

### Initial Setup

1. **Launch the app** on your device
2. **Navigate to Settings** (gear icon in app bar)
3. **Enter emergency contact phone number** (include country code, e.g., +11234567890)
4. **Save settings**

### Starting Monitoring

1. **Tap "Start Monitoring"** button on the home screen
2. **Grant required permissions** when prompted:
   - Activity Recognition
   - Location (Always)
   - SMS
   - Notifications
   - Camera (for flashlight)
3. **Monitoring begins** - you'll see a persistent notification
4. **Sample count** updates in real-time on the home screen

### During Monitoring

- The app runs in the background
- A foreground service notification is displayed
- Accelerometer data is continuously analyzed
- The app remains active even when the screen is off

### When a Fall is Detected

1. **Full-screen alarm activates** automatically
2. **Multiple alerts trigger**:
   - Audio siren (alternating tones)
   - Vibration pattern
   - Flashlight strobe
3. **60-second countdown begins** to automatic SMS
4. **User options**:
   - **Swipe "Call Help"** (green): Immediately sends SMS and stops alarm
   - **Swipe "I am OK"** (gray): Cancels alarm (no SMS sent)

### Stopping Monitoring

1. **Tap "Stop Monitoring"** button on the home screen
2. All services stop and notification disappears

### Testing

- Use the **"Trigger Test Alarm"** button to test the alarm interface without detecting an actual fall
- Useful for:
  - Verifying emergency contact setup
  - Testing SMS functionality
  - Familiarizing users with the interface

## 🏗️ Architecture

### System Architecture

```
┌─────────────────────────────────────────────────┐
│                  Main App                       │
│  ┌──────────────┐  ┌─────────────────────────┐ │
│  │  HomePage    │  │   SettingsPage          │ │
│  │  (UI Layer)  │  │   (Configuration)       │ │
│  └──────┬───────┘  └─────────────────────────┘ │
│         │                                       │
│         ▼                                       │
│  ┌──────────────────────────────────────────┐  │
│  │      SensorMonitor (Singleton)           │  │
│  │  - Accelerometer Stream (20Hz)           │  │
│  │  - Rolling Buffer (200 samples)         │  │
│  │  - Fall Detection Logic                 │  │
│  └──────────────┬───────────────────────────┘  │
│                 │                               │
│                 ▼                               │
│  ┌──────────────────────────────────────────┐  │
│  │         FallDetector                     │  │
│  │  - Spike Detection (2.5g threshold)      │  │
│  │  - Stillness Detection (0.2g threshold)  │  │
│  │  - Time Window Analysis (700ms)          │  │
│  └──────────────────────────────────────────┘  │
└─────────────────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────────────────┐
│         Foreground Service                      │
│  ┌──────────────────────────────────────────┐  │
│  │   FlutterForegroundTask                  │  │
│  │   - Keeps app alive in background        │  │
│  │   - Persistent notification               │  │
│  └──────────────────────────────────────────┘  │
└─────────────────────────────────────────────────┘
         │
         ▼ (On Fall Detection)
┌─────────────────────────────────────────────────┐
│            Alarm Screen                         │
│  ┌──────────────────────────────────────────┐  │
│  │  - Audio Player (Siren)                  │  │
│  │  - Vibration Controller                  │  │
│  │  - Flashlight Controller                 │  │
│  │  - SMS Sender (with GPS)                 │  │
│  │  - Countdown Timer (60s)                 │  │
│  └──────────────────────────────────────────┘  │
└─────────────────────────────────────────────────┘
```

### Component Breakdown

#### 1. **Main App (`main.dart`)**
- Application entry point
- Initializes foreground task
- Sets up notification system
- Configures navigation routes

#### 2. **SensorMonitor (`sensor_monitor.dart`)**
- Singleton service managing accelerometer stream
- Processes sensor data at 20Hz
- Maintains rolling buffer of recent samples
- Triggers alarm on fall detection
- Handles notification display

#### 3. **FallDetector (`fall_detector.dart`)**
- Core detection algorithm
- Calculates acceleration magnitude
- Implements spike + stillness detection
- Stateless utility class

#### 4. **AlarmScreen (`alarm_screen.dart`)**
- Full-screen emergency interface
- Manages audio, vibration, and flashlight
- Handles SMS sending with location
- Swipe-to-confirm UI

#### 5. **Foreground Task (`fall_foreground_task.dart`)**
- Background service handler
- Keeps app process alive
- Note: Sensor monitoring happens in main isolate (sensors_plus limitation)

#### 6. **RollingBuffer (`rolling_buffer.dart`)**
- Circular buffer implementation
- Stores last 200 accelerometer samples
- Used for data analysis and debugging

## 🔧 Technical Details

### Sampling Rate

- **Frequency**: 20Hz (20 samples per second)
- **Interval**: 50 milliseconds between samples
- **Rationale**: Balances battery life with detection accuracy

### Data Storage

- **SharedPreferences**: Stores emergency contact and last event timestamp
- **Rolling Buffer**: In-memory buffer (200 samples, ~10 seconds)

### Battery Optimization

- **Foreground Service**: Required for continuous monitoring
- **Wakelock**: Prevents CPU sleep during active monitoring
- **Efficient Sampling**: 20Hz is sufficient for fall detection while conserving battery

### Platform Considerations

#### Android
- Uses foreground service with persistent notification
- Requires `FOREGROUND_SERVICE` permission
- Full-screen intent for alarm notifications
- Background execution limitations handled via foreground service

#### iOS
- Background modes configured for location and notifications
- Sensor access requires physical device
- More restrictive background execution policies

### Notification System

- **Foreground Service Notification**: Persistent notification while monitoring
- **Alarm Notification**: High-priority full-screen notification on fall detection
- **Channel Configuration**: Separate channels for service and alarms

## 🔐 Permissions

The app requires the following permissions:

### Android Permissions

1. **`ACTIVITY_RECOGNITION`**
   - Purpose: Access accelerometer for motion detection
   - Required: Yes

2. **`ACCESS_FINE_LOCATION`** / **`ACCESS_COARSE_LOCATION`**
   - Purpose: Get GPS coordinates for emergency SMS
   - Required: Yes (for location in SMS)

3. **`ACCESS_BACKGROUND_LOCATION`**
   - Purpose: Location access when app is in background
   - Required: Yes (for background monitoring)

4. **`SEND_SMS`**
   - Purpose: Send emergency SMS to contact
   - Required: Yes (for emergency alerts)

5. **`POST_NOTIFICATIONS`**
   - Purpose: Display foreground service and alarm notifications
   - Required: Yes

6. **`CAMERA`**
   - Purpose: Control flashlight for visual alerts
   - Required: Yes (for flashlight feature)

7. **`FOREGROUND_SERVICE`**
   - Purpose: Run continuous monitoring service
   - Required: Yes

8. **`WAKE_LOCK`**
   - Purpose: Keep CPU active during monitoring
   - Required: Yes

### iOS Permissions

1. **Motion & Fitness**
   - Purpose: Access accelerometer
   - Required: Yes

2. **Location (Always)**
   - Purpose: GPS coordinates for emergency SMS
   - Required: Yes

3. **Notifications**
   - Purpose: Display alerts
   - Required: Yes

4. **Camera**
   - Purpose: Flashlight control
   - Required: Yes

### Permission Handling

- Permissions are requested when starting monitoring
- Users must grant all permissions for full functionality
- App gracefully handles denied permissions with user feedback

## 📁 Project Structure

```
fall_detection_app/
├── lib/
│   ├── main.dart                          # App entry point
│   └── src/
│       ├── alarm/
│       │   └── alarm_screen.dart          # Emergency alarm interface
│       ├── service/
│       │   ├── fall_foreground_task.dart  # Background service handler
│       │   └── sensor_monitor.dart        # Accelerometer monitoring
│       ├── settings/
│       │   └── settings_page.dart         # Configuration UI
│       └── utils/
│           ├── app_navigator.dart         # Global navigation key
│           ├── fall_detector.dart         # Detection algorithm
│           ├── navigation_helper.dart     # Navigation utilities
│           └── rolling_buffer.dart        # Circular buffer
├── android/                               # Android platform files
├── ios/                                   # iOS platform files
├── assets/
│   └── alarm_sound.mp3                    # Alarm audio file
├── pubspec.yaml                           # Dependencies
└── README.md                              # This file
```

## 📦 Dependencies

### Core Dependencies

| Package | Version | Purpose |
|---------|---------|---------|
| `flutter` | SDK | Flutter framework |
| `sensors_plus` | ^6.0.1 | Accelerometer access |
| `flutter_foreground_task` | ^6.3.0 | Background service |
| `geolocator` | ^13.0.2 | GPS location services |
| `permission_handler` | ^11.3.1 | Runtime permissions |
| `flutter_local_notifications` | ^17.2.3 | Local notifications |
| `wakelock_plus` | ^1.2.7 | Prevent CPU sleep |
| `vibration` | ^3.1.4 | Haptic feedback |
| `torch_light` | ^1.0.1 | Flashlight control |
| `audioplayers` | ^6.1.0 | Audio playback |
| `telephony` | ^0.2.0 | SMS sending |
| `shared_preferences` | ^2.3.2 | Local data storage |
| `get` | ^4.7.2 | State management |

### Development Dependencies

- `flutter_test`: Testing framework
- `flutter_lints`: Code linting rules

## 📚 Terms & Glossary

### Accelerometer Terms

- **Accelerometer**: A sensor that measures acceleration forces in three dimensions (X, Y, Z axes)
- **G-force (g)**: A unit of acceleration equal to Earth's gravitational acceleration (9.80665 m/s²)
- **Magnitude**: The total acceleration vector length, calculated as √(x² + y² + z²)
- **Sampling Rate**: The frequency at which sensor data is collected (20Hz = 20 samples per second)
- **m/s²**: Meters per second squared, the SI unit for acceleration

### Detection Terms

- **Spike**: A sudden, large increase in acceleration magnitude
- **Stillness Window**: A time period after a spike where low acceleration indicates potential immobility
- **Threshold**: A predefined value used to classify sensor readings (e.g., 2.5g spike threshold)
- **False Positive**: An incorrect fall detection when no actual fall occurred
- **False Negative**: A missed detection when an actual fall occurs
- **Cooldown Period**: A time window (20 seconds) preventing duplicate alarms

### Technical Terms

- **Foreground Service**: An Android service that runs with a persistent notification, preventing system termination
- **Wakelock**: A mechanism to prevent the device CPU from entering sleep mode
- **Isolate**: A Dart execution context (main isolate vs. background isolate)
- **Stream**: A sequence of asynchronous data events (accelerometer stream)
- **Singleton**: A design pattern ensuring only one instance of a class exists
- **Rolling Buffer**: A circular data structure that maintains the most recent N items

### App-Specific Terms

- **Monitoring State**: Whether the app is actively tracking accelerometer data
- **Sample Count**: The total number of accelerometer readings processed since monitoring started
- **Emergency Contact**: The phone number configured to receive fall detection alerts
- **Full-Screen Intent**: A high-priority notification that displays over the lock screen
- **Swipe Action**: A gesture-based UI control requiring horizontal swipe to confirm

### Medical/Safety Terms

- **Fall Detection**: The process of identifying when a person has fallen
- **Emergency Alert**: A notification system triggered on potential fall detection
- **Location Services**: GPS-based positioning for emergency response
- **Emergency SMS**: An automated text message sent to a contact with fall alert and location

## 🐛 Troubleshooting

### Common Issues

#### Monitoring Not Starting

**Problem**: "Start Monitoring" button doesn't activate monitoring

**Solutions**:
- Check that all permissions are granted
- Ensure device has accelerometer (physical device required, not emulator)
- Restart the app and try again
- Check device battery optimization settings (may need to whitelist app)

#### False Alarms

**Problem**: App triggers alarms during normal activities

**Solutions**:
- The algorithm may need tuning for your activity level
- Consider adjusting thresholds in `fall_detector.dart`:
  - Increase `spikeG` (e.g., 2.5g → 3.0g) for less sensitivity
  - Increase `stillG` (e.g., 0.2g → 0.3g) to require more stillness
- Use "I am OK" swipe to cancel false alarms

#### SMS Not Sending

**Problem**: Emergency SMS fails to send

**Solutions**:
- Verify emergency contact is set in Settings
- Check SMS permission is granted
- Ensure phone number includes country code (e.g., +1 for US)
- Verify device has cellular connectivity
- Check device SMS sending limits/carrier restrictions

#### Battery Drain

**Problem**: App consumes too much battery

**Solutions**:
- This is expected - continuous monitoring requires active sensors
- Ensure device is charged regularly
- Consider charging device overnight
- The 20Hz sampling rate is optimized for battery life

#### Alarm Not Appearing

**Problem**: Fall detected but alarm screen doesn't show

**Solutions**:
- Check notification permissions are granted
- Verify app is not in battery optimization "sleep" mode
- Ensure foreground service notification is visible
- Try triggering test alarm to verify functionality

#### Location Unavailable

**Problem**: SMS shows "Location unavailable"

**Solutions**:
- Grant location permissions (Always, not just When In Use)
- Ensure GPS is enabled on device
- Try moving to area with better GPS signal
- App will use last known position if current GPS fails

### Debug Mode

Enable Flutter debug logging to see detailed sensor data:

```bash
flutter run --verbose
```

Look for log tags:
- `COORDS`: Accelerometer readings (every 50 samples)
- `FALL_DETECTED`: When a fall is detected
- `ERROR`: Any errors in the system

## 🤝 Contributing

Contributions are welcome! Areas for improvement:

1. **Algorithm Enhancement**: Machine learning models, better thresholds
2. **UI/UX**: Improved interfaces, accessibility features
3. **Testing**: Unit tests, integration tests, real-world validation
4. **Documentation**: Additional guides, video tutorials
5. **Features**: Multiple emergency contacts, cloud backup, family dashboard

### Development Guidelines

1. Follow Flutter/Dart style guidelines
2. Add comments for complex logic
3. Test on physical devices (sensors don't work in emulators)
4. Update this README for significant changes
5. Ensure all permissions are documented

## 📄 License

[Specify your license here - e.g., MIT, Apache 2.0, etc.]

## ⚠️ Disclaimer

**IMPORTANT**: This app is provided as-is for educational and personal use. Fall detection algorithms have limitations and may produce false positives or miss actual falls. This app should not be the sole means of emergency response for at-risk individuals. Always have backup emergency systems in place.

### Limitations

- Detection accuracy depends on device placement and user movement patterns
- False positives may occur during vigorous activities
- False negatives are possible if fall characteristics don't match algorithm parameters
- Requires device to be carried/worn consistently
- Battery consumption is significant due to continuous monitoring
- SMS delivery depends on cellular connectivity

### Recommendations

- Test the app thoroughly before relying on it
- Keep device charged and accessible
- Inform emergency contacts about the system
- Have alternative emergency response methods available
- Regularly verify emergency contact information is current

---

**Version**: 1.0.0+1  
**Last Updated**: [Current Date]  
**Flutter SDK**: ^3.9.0
