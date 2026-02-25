import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:light/light.dart';
import 'package:noise_meter/noise_meter.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:vibration/vibration.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:telephony/telephony.dart';
import 'package:flutter_background/flutter_background.dart' as fb;
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'dart:math';

class SensorService {
  final _db = FirebaseDatabase.instance.ref();
  final String apiKey = "bb62fd0da5305d48c953b6f2f45038ea";

  // Telephony Instance for Background SMS
  final Telephony telephony = Telephony.instance;

  String get userId => FirebaseAuth.instance.currentUser?.uid ?? "guest_user";

  static const String _channelWellness = 'chetna_wellness';
  static const String _channelEmergency = 'chetna_emergency';
  static const String _channelService = 'chetna_service_sticky';
  static const int _stickyNotificationId = 888;

  Interpreter? _wellnessInterpreter;
  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  final AudioPlayer _audioPlayer = AudioPlayer();
  final AudioPlayer _whiteNoisePlayer = AudioPlayer();

  Box? _settingsBox;
  bool isSirenEnabled = true;
  bool isHushEnabled = true;
  bool isMonitoringEnabled = true;
  bool isAiEnabled = true;
  bool isSmsEnabled = true;
  bool isDialogShowing = false;
  bool isPendingAlert = false;
  bool isAlertActive = false;
  bool _isSirenPlaying = false;

  bool _isWhiteNoisePlaying = false;
  int _highNoiseCounter = 0;
  Timer? _hushPlaybackTimer;

  Timer? _focusTimer;
  int _focusSeconds = 0;
  bool isFocusSessionActive = false;
  double? _homeLat;
  double? _homeLng;

  String _caregiverPhone = "9608425857";

  final List<Map<String, String>> _notificationQueue = [];
  bool _isProcessingQueue = false;
  final Map<String, int> _diagToId = {
    "Sensory Overload": 101,
    "Visual Stress": 102,
    "Acoustic Hazard": 103,
    "Respiratory Risk": 104,
    "Social Isolation": 105,
    "Toxic Environment": 106,
    "Geofence Breach": 107,
    "Focus Distraction": 201,
    "Manual SOS": 999,
  };

  double _currentTemp = 25.0;
  int _currentAQI = 1;
  int _lastLightValue = 500;
  double _lastNoiseValue = 50.0;

  // Track the subscription and state management
  StreamSubscription<NoiseReading>? _noiseSubscription;

  // STATE FLAGS - UPDATED WITH BETTER NAMING
  bool _cachedVoiceGuardianState = false; // The Master Toggle
  bool _isRecordingTrusted = false; // The Recording Lock

  final _accelController = StreamController<double>.broadcast();
  final _wellnessController = StreamController<String>.broadcast();
  final _fallAlertController = StreamController<bool>.broadcast();
  final _envDataController = StreamController<Map<String, dynamic>>.broadcast();
  final _lightUIController = StreamController<int>.broadcast();
  final _noiseUIController = StreamController<double>.broadcast();
  final _sirenStateController = StreamController<bool>.broadcast();
  final _hushStateController = StreamController<bool>.broadcast();
  final _aiStateController = StreamController<bool>.broadcast();
  final _audioStateController = StreamController<bool>.broadcast();
  final _syncStatusController = StreamController<String>.broadcast();
  final _focusTimeController = StreamController<int>.broadcast();
  final _geofenceStatusController = StreamController<String>.broadcast();
  final _connectivityController = StreamController<bool>.broadcast();
  final _voiceModeController = StreamController<bool>.broadcast();

  Stream<double> get accelerationStream => _accelController.stream;
  Stream<String> get wellnessStream => _wellnessController.stream;
  Stream<bool> get fallStream => _fallAlertController.stream;
  Stream<Map<String, dynamic>> get envDataStream => _envDataController.stream;
  Stream<int> get lightStream => _lightUIController.stream;
  Stream<double> get noiseUIStream => _noiseUIController.stream;
  Stream<bool> get sirenStateStream => _sirenStateController.stream;
  Stream<bool> get hushStateStream => _hushStateController.stream;
  Stream<bool> get aiStateStream => _aiStateController.stream;
  Stream<bool> get audioStateStream => _audioStateController.stream;
  Stream<String> get syncStatusStream => _syncStatusController.stream;
  Stream<int> get focusTimeStream => _focusTimeController.stream;
  Stream<String> get geofenceStream => _geofenceStatusController.stream;
  Stream<bool> get connectivityStream => _connectivityController.stream;
  Stream<bool> get voiceModeStream => _voiceModeController.stream;

  // ========== VOICE GUARDIAN PERSISTENCE & STATE MANAGEMENT ==========

  /// Get the current voice guardian state from persistence
  bool get isVoiceGuardianEnabled => _cachedVoiceGuardianState;

  /// Set and persist the voice guardian state - UPDATED WITH ROBUST LOGIC
  void setVoiceGuardianState(bool enabled) {
    // Even if state matches, we force the save to ensure consistency
    _cachedVoiceGuardianState = enabled;

    // Save to persistent storage
    _settingsBox?.put('voiceGuardianEnabled', enabled);

    // Broadcast the change
    _voiceModeController.add(enabled);

    if (enabled) {
      // User turned ON Voice Guardian -> Stop Noise Meter
      _stopNoiseTracking();

      _logToFirebase("VOICE_GUARDIAN_ENABLED", {
        "timestamp": DateTime.now().millisecondsSinceEpoch,
        "reason": "user_toggle",
      });
      debugPrint("✅ [PERSISTENCE] Voice Guardian state saved: ON");
    } else {
      // User turned OFF Voice Guardian -> Start Noise Meter
      // Small delay to let mic free up
      Future.delayed(const Duration(milliseconds: 500), _startNoiseTracking);

      _logToFirebase("VOICE_GUARDIAN_DISABLED", {
        "timestamp": DateTime.now().millisecondsSinceEpoch,
        "reason": "user_toggle",
      });
      debugPrint("✅ [PERSISTENCE] Voice Guardian state saved: OFF");
    }
  }

  /// Enable Voice Mode (Stops Noise Meter)
  void enableVoiceMode() {
    debugPrint("🎤 Switching to VOICE MODE. Stopping Noise Meter.");
    _stopNoiseTracking();
  }

  /// Disable Voice Mode (Starts Noise Meter)
  void disableVoiceMode() {
    debugPrint("👂 Switching to NOISE MODE. Starting Noise Meter.");
    // Wait for voice engine to fully release hardware
    Future.delayed(const Duration(milliseconds: 1000), _startNoiseTracking);
  }

  // ========== TRUSTED VOICE RECORDING BLOCKER ==========

  /// Pause sensors for Trusted Voice recording - prevents conflicts
  Future<void> pauseForTrustedRecording() async {
    debugPrint("⏸️ [SENSOR] Pausing mic for Recording...");
    _isRecordingTrusted = true;
    _stopNoiseTracking();

    // Small delay to ensure mic is released
    await Future.delayed(const Duration(milliseconds: 200));

    // Log the pause event
    _logToFirebase("TRUSTED_VOICE_RECORDING_START", {
      "timestamp": DateTime.now().millisecondsSinceEpoch,
      "voiceGuardianEnabled": _cachedVoiceGuardianState,
    });

    debugPrint("✅ [SENSOR] Microphone ready for trusted voice recording");
  }

  /// Resume sensors after Trusted Voice recording
  Future<void> resumeAfterTrustedRecording() async {
    debugPrint("▶️ [SENSOR] Recording Done.");
    _isRecordingTrusted = false;

    // Only resume noise meter if Voice Guardian is OFF
    if (!_cachedVoiceGuardianState) {
      _startNoiseTracking();
    }

    // Log the resume event
    _logToFirebase("TRUSTED_VOICE_RECORDING_END", {
      "timestamp": DateTime.now().millisecondsSinceEpoch,
      "voiceGuardianEnabled": _cachedVoiceGuardianState,
    });

    debugPrint("✅ [SENSOR] Sensors resumed based on toggle state");
  }

  // ========== NOISE TRACKING (THE FIX) ==========

  void _stopNoiseTracking() {
    _noiseSubscription?.cancel();
    _noiseSubscription = null;
    _noiseUIController.add(0.0);
  }

  void _startNoiseTracking() {
    // STRICT CHECK: If Voice Guardian is ON, or Recording is ON, DO NOT START.
    if (_cachedVoiceGuardianState || _isRecordingTrusted) {
      debugPrint(
        "🎤 [NOISE] Skipping noise tracking - Voice Guardian: $_cachedVoiceGuardianState, Recording: $_isRecordingTrusted",
      );
      return;
    }

    _noiseSubscription?.cancel();

    try {
      debugPrint("🎤 [SENSOR] Starting Noise Meter...");
      _noiseSubscription = NoiseMeter().noise.listen(
        (reading) {
          // Double check inside the stream
          if (_cachedVoiceGuardianState || _isRecordingTrusted) {
            _stopNoiseTracking();
            return;
          }

          // FIX: FILTER INFINITY & NaN VALUES (Prevents Firebase Crash)
          if (reading.meanDecibel.isInfinite ||
              reading.meanDecibel.isNaN ||
              reading.meanDecibel < 0) {
            // Don't log this, just ignore invalid readings
            debugPrint(
              "⚠️ [NOISE] Invalid reading detected: ${reading.meanDecibel}",
            );
            return;
          }

          // Valid reading
          double db = reading.meanDecibel;
          _lastNoiseValue = db;
          _noiseUIController.add(db);
          debugPrint("🔊 Noise reading: ${db}dB");

          if (isAlertActive) return;

          if (!isMonitoringEnabled || !isHushEnabled || _isWhiteNoisePlaying)
            return;

          if (db > 78) {
            _highNoiseCounter++;
          } else {
            _highNoiseCounter = 0;
          }

          if (_highNoiseCounter >= 10) {
            _triggerHushCycle();
          }
        },
        onError: (e) {
          debugPrint("❌ [NOISE METER ERROR] $e");
          _stopNoiseTracking();
          // Retry logic
          if (!_cachedVoiceGuardianState) {
            Future.delayed(const Duration(seconds: 2), _startNoiseTracking);
          }
        },
      );

      debugPrint("✅ [NOISE] Noise tracking started successfully");
    } catch (e) {
      debugPrint("❌ [NOISE METER INIT FAILED] $e");
      // Auto-retry on exception
      if (!_cachedVoiceGuardianState) {
        Timer(const Duration(seconds: 3), _startNoiseTracking);
      }
    }
  }

  // ========== FIREBASE LOGGING METHODS WITH SANITIZATION ==========

  Future<void> _logToFirebase(
    String eventType,
    Map<String, dynamic> data,
  ) async {
    try {
      // Sanitize Data - Remove Infinity & NaN values
      final sanitizedData = data.map<String, dynamic>((key, value) {
        if (value is double && (value.isInfinite || value.isNaN)) {
          debugPrint("⚠️ [FIREBASE] Sanitizing $key: $value -> 0.0");
          return MapEntry(key, 0.0); // Replace Infinity/NaN with 0
        }
        if (value is num && (value.isInfinite || value.isNaN)) {
          return MapEntry(key, 0); // Replace Infinity/NaN with 0
        }
        return MapEntry(key, value);
      });

      if (userId == "guest_user") return;

      final eventRef = _db.child("users/$userId/events").push();
      await eventRef.set({
        "type": eventType,
        "timestamp": ServerValue.timestamp,
        "userId": userId,
        "data": sanitizedData, // Use sanitized data
        "status": "logged",
      });

      debugPrint("📝 [FIREBASE] Logged $eventType");
    } catch (e) {
      debugPrint("❌ [FIREBASE ERROR] $e");
    }
  }

  Future<void> _logAlertToFirebase(
    String alertType,
    String title,
    String message,
    Map<String, dynamic> extraData,
  ) async {
    try {
      // Sanitize data before logging
      final sanitizedData = extraData.map<String, dynamic>((key, value) {
        if (value is double && (value.isInfinite || value.isNaN)) {
          return MapEntry(key, 0.0);
        }
        if (value is num && (value.isInfinite || value.isNaN)) {
          return MapEntry(key, 0);
        }
        return MapEntry(key, value);
      });

      if (userId == "guest_user") return;

      final alertRef = _db.child("alerts").push();
      await alertRef.set({
        "userId": userId,
        "type": alertType,
        "title": title,
        "message": message,
        "timestamp": ServerValue.timestamp,
        "data": sanitizedData, // Use sanitized data
      });

      debugPrint("🚨 [ALERT LOGGED] $alertType");
    } catch (e) {
      debugPrint("❌ [ALERT LOG ERROR] $e");
    }
  }

  // ========== CAREGIVER PHONE MANAGEMENT ==========

  Future<void> updateCaregiverPhone(String newPhone) async {
    try {
      if (userId == "guest_user") return;

      _caregiverPhone = newPhone;

      // Update in Firebase
      await _db.child("users/$userId/profile").update({
        "caregiverPhone": newPhone,
        "lastUpdated": ServerValue.timestamp,
      });

      // Log the change
      await _logToFirebase("CAREGIVER_UPDATED", {
        "oldPhone": _caregiverPhone,
        "newPhone": newPhone,
      });

      debugPrint("✅ [CAREGIVER] Updated to: $newPhone");
    } catch (e) {
      debugPrint("❌ [CAREGIVER UPDATE ERROR] $e");
      rethrow;
    }
  }

  Future<String> getCaregiverPhone() async {
    try {
      if (userId == "guest_user") return _caregiverPhone;

      final snapshot = await _db.child("users/$userId/profile").get();
      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        _caregiverPhone = data['caregiverPhone']?.toString() ?? "9608425857";
      }
      return _caregiverPhone;
    } catch (e) {
      debugPrint("❌ [CAREGIVER FETCH ERROR] $e");
      return _caregiverPhone;
    }
  }

  // ========== EXISTING METHODS WITH UPDATES ==========

  Future<void> start() async {
    debugPrint("🚀 [SYSTEM] Booting Chetna Engine...");

    try {
      await Permission.notification.request();

      final androidConfig = fb.FlutterBackgroundAndroidConfig(
        notificationTitle: "Chetna Safety Shield",
        notificationText: "Protection Active: Monitoring for Falls & SOS",
        notificationImportance: fb.AndroidNotificationImportance.normal,
        notificationIcon: fb.AndroidResource(
          name: 'ic_launcher',
          defType: 'mipmap',
        ),
        enableWifiLock: true,
      );

      bool hasPermissions = await fb.FlutterBackground.initialize(
        androidConfig: androidConfig,
      );

      if (hasPermissions) {
        await fb.FlutterBackground.enableBackgroundExecution();
        debugPrint("🛡️ [BACKGROUND] Service wake-lock active.");
      }
    } catch (e) {
      debugPrint("❌ [BG ERROR] $e");
    }

    await Hive.initFlutter();
    _settingsBox = await Hive.openBox('app_settings');

    // Load all settings including voice guardian state
    isSirenEnabled =
        _settingsBox?.get('isSirenEnabled', defaultValue: true) ?? true;
    isHushEnabled =
        _settingsBox?.get('isHushEnabled', defaultValue: true) ?? true;
    isAiEnabled = _settingsBox?.get('isAiEnabled', defaultValue: true) ?? true;
    isSmsEnabled =
        _settingsBox?.get('isSmsEnabled', defaultValue: true) ?? true;

    // LOAD SAVED VOICE GUARDIAN STATE
    _cachedVoiceGuardianState =
        _settingsBox?.get('voiceGuardianEnabled', defaultValue: false) ?? false;
    debugPrint(
      "💾 Loaded Saved State: Voice Guardian is ${_cachedVoiceGuardianState ? 'ON' : 'OFF'}",
    );

    _homeLat = _settingsBox?.get('homeLat');
    _homeLng = _settingsBox?.get('homeLng');

    await _audioPlayer.setReleaseMode(ReleaseMode.loop);
    await _whiteNoisePlayer.setReleaseMode(ReleaseMode.loop);

    await _loadModels();
    await _initNotifications();
    await _requestPermissions();

    await _showStickyServiceNotification();

    _startMotionTracking();
    _startLightTracking();

    // UPDATED START LOGIC: Only start noise tracking if Voice Guardian is OFF
    if (!_cachedVoiceGuardianState) {
      _startNoiseTracking();
    } else {
      _noiseUIController.add(0.0); // Clear noise value when in voice mode
    }

    _startPeriodicWellnessCheck();
    _startGeofenceCheck();
    _initConnectivityMonitor();

    updateExternalStats();
    _syncStatusController.add("synced");

    // Broadcast initial voice guardian state
    _voiceModeController.add(_cachedVoiceGuardianState);

    // Log app start to Firebase
    await _logToFirebase("APP_STARTED", {
      "features": {
        "siren": isSirenEnabled,
        "hush": isHushEnabled,
        "ai": isAiEnabled,
        "sms": isSmsEnabled,
        "monitoring": isMonitoringEnabled,
        "voiceGuardianEnabled": _cachedVoiceGuardianState,
      },
    });

    debugPrint(
      "✅ [ONLINE] Ready. Voice Guardian State: $_cachedVoiceGuardianState",
    );
  }

  Future<void> _showStickyServiceNotification() async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
          _channelService,
          'Chetna Service Status',
          channelDescription: 'Maintains background sensor connection',
          importance: Importance.max,
          priority: Priority.max,
          ongoing: true,
          autoCancel: false,
          showWhen: true,
          visibility: NotificationVisibility.public,
          icon: '@mipmap/ic_launcher',
        );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
    );

    await _notifications.show(
      _stickyNotificationId,
      'Chetna Safety Shield',
      'Active Monitoring for Fall and SOS',
      platformChannelSpecifics,
    );
  }

  Future<void> _requestPermissions() async {
    await [
      Permission.location,
      Permission.locationAlways,
      Permission.sensors,
      Permission.microphone,
      Permission.notification,
      Permission.sms,
    ].request();

    bool isOptimizing = await Permission.ignoreBatteryOptimizations.isGranted;
    if (!isOptimizing) {
      await Permission.ignoreBatteryOptimizations.request();
    }
  }

  void _initConnectivityMonitor() {
    Connectivity().onConnectivityChanged.listen((
      List<ConnectivityResult> result,
    ) {
      bool isOnline =
          result.contains(ConnectivityResult.mobile) ||
          result.contains(ConnectivityResult.wifi);
      _connectivityController.add(isOnline);
    });
  }

  // Add this public method to SensorService class
  Future<void> logEvent(String eventType, Map<String, dynamic> data) async {
    await _logToFirebase(eventType, data);
  }

  // Also add this method to handle voice events specifically
  Future<void> handleVoiceSOS() async {
    debugPrint("🆘 [VOICE SOS] Triggered via voice command");
    await triggerImmediateSOS(isManual: false);

    // Log voice-specific event
    await _logToFirebase("VOICE_SOS_TRIGGERED", {
      "timestamp": DateTime.now().millisecondsSinceEpoch,
      "source": "voice_guardian",
    });
  }

  Future<void> _triggerHushCycle() async {
    debugPrint("🛡️ [HUSH] High noise persisted. Activating Shield.");
    _isWhiteNoisePlaying = true;
    _highNoiseCounter = 0;
    _audioStateController.add(true);
    await _whiteNoisePlayer.play(
      AssetSource('audio/white_noise.mp3'),
      volume: 0.6,
    );

    // Log hush activation
    _logToFirebase("HUSH_ACTIVATED", {
      "reason": "high_noise",
      "noiseLevel": _lastNoiseValue,
    });

    _hushPlaybackTimer?.cancel();
    _hushPlaybackTimer = Timer(const Duration(seconds: 10), () async {
      await _whiteNoisePlayer.stop();
      _isWhiteNoisePlaying = false;
      _audioStateController.add(false);
    });
  }

  Future<void> playSiren() async {
    if (!isSirenEnabled) return;
    if (_isSirenPlaying) return;

    _isSirenPlaying = true;
    _audioStateController.add(true);
    await _audioPlayer.setVolume(1.0);
    await _audioPlayer.play(AssetSource('audio/siren.mp3'));

    // Log siren activation
    _logToFirebase("SIREN_ACTIVATED", {
      "reason": "emergency",
      "timestamp": DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> stopAllAudio() async {
    await _audioPlayer.stop();
    await _whiteNoisePlayer.stop();
    _hushPlaybackTimer?.cancel();
    _isSirenPlaying = false;
    _isWhiteNoisePlaying = false;
    _audioStateController.add(false);
  }

  // UPDATED: SOS Message Logic
  Future<void> triggerImmediateSOS({bool isManual = false}) async {
    debugPrint("🆘 [SOS] Triggering...");
    isAlertActive = true;
    isPendingAlert = false;
    isDialogShowing = true;

    // Play siren if enabled
    if (isSirenEnabled) {
      await _audioPlayer.setVolume(1.0);
      await _audioPlayer.play(AssetSource('audio/siren.mp3'));
      _isSirenPlaying = true;
    }

    try {
      // 1. GET LOCATION
      Position pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      String googleMapsLink =
          "http://maps.google.com/?q=${pos.latitude},${pos.longitude}";

      // 2. UPDATED MESSAGE CONTENT
      String caregiverPhone = await getCaregiverPhone();
      String message = isManual
          ? "SOS! Manual Alert via Chetna App. Location: $googleMapsLink"
          : "SOS! I am in distress, help me! Location: $googleMapsLink";

      // Log SOS event to Firebase
      await _logToFirebase("SOS_TRIGGERED", {
        "isManual": isManual,
        "location": {"lat": pos.latitude, "lng": pos.longitude},
        "caregiverPhone": caregiverPhone,
        "timestamp": DateTime.now().millisecondsSinceEpoch,
      });

      // Log alert to Firebase
      await _logAlertToFirebase(
        "EMERGENCY_SOS",
        isManual ? "MANUAL SOS" : "AUTOMATIC SOS",
        isManual
            ? "User manually triggered SOS"
            : "Fall detected, SOS triggered",
        {
          "location": {"lat": pos.latitude, "lng": pos.longitude},
          "isManual": isManual,
          "caregiverPhone": caregiverPhone,
        },
      );

      // 3. SEND SMS
      if (isSmsEnabled && caregiverPhone.isNotEmpty) {
        try {
          await telephony.sendSms(to: caregiverPhone, message: message);
          debugPrint("✅ SMS Sent to $caregiverPhone");
          await _logToFirebase("SMS_SENT", {"phone": caregiverPhone});
        } catch (e) {
          debugPrint("❌ SMS Failed: $e");
          await _logToFirebase("SMS_FAILED", {
            "error": e.toString(),
            "phone": caregiverPhone,
          });
        }
      }

      String title = isManual ? "MANUAL SOS ALERT" : "EMERGENCY ACTIVE";
      String body = isSmsEnabled
          ? "SMS Sent to caregiver."
          : "Impact detected.";

      await _triggerLocalNudge(title, body, 999, _channelEmergency);
      _fallAlertController.add(true);
    } catch (e) {
      debugPrint("❌ SOS Failed: $e");
      await _logToFirebase("SOS_ERROR", {
        "error": e.toString(),
        "isManual": isManual,
      });
    }
  }

  // UPDATED: "I AM SAFE" Message Logic
  Future<void> sendSafeMessage() async {
    if (!isSmsEnabled) return;

    try {
      String caregiverPhone = await getCaregiverPhone();
      String message =
          "I am safe now. The alert has been resolved. False alarm.";

      await telephony.sendSms(to: caregiverPhone, message: message);

      debugPrint("✅ Safe SMS Sent");
      await _logToFirebase("SAFE_SMS_SENT", {"phone": caregiverPhone});
    } catch (e) {
      debugPrint("❌ Safe SMS Failed: $e");
    }
  }

  Future<void> resolveSOS() async {
    debugPrint("✅ [SOS] Resolved.");
    isPendingAlert = false;
    isDialogShowing = false;
    isAlertActive = false;

    // Log SOS resolution
    await _logToFirebase("SOS_RESOLVED", {
      "timestamp": DateTime.now().millisecondsSinceEpoch,
    });

    await stopAllAudio();
    await stopVibration();
    _fallAlertController.add(false);
    await _db.child("readings/$userId/emergencies").remove();
    await _notifications.cancelAll();
  }

  void resetFallDetection() {
    isPendingAlert = false;
    _fallAlertController.add(false);
  }

  void toggleAi() {
    isAiEnabled = !isAiEnabled;
    _settingsBox?.put('isAiEnabled', isAiEnabled);
    _aiStateController.add(isAiEnabled);

    // Log AI toggle
    _logToFirebase("AI_TOGGLED", {"newState": isAiEnabled});
  }

  void toggleSms() {
    isSmsEnabled = !isSmsEnabled;
    _settingsBox?.put('isSmsEnabled', isSmsEnabled);

    // Log SMS toggle
    _logToFirebase("SMS_TOGGLED", {"newState": isSmsEnabled});
  }

  void toggleSiren() {
    isSirenEnabled = !isSirenEnabled;
    _settingsBox?.put('isSirenEnabled', isSirenEnabled);
    _sirenStateController.add(isSirenEnabled);

    // Log siren toggle
    _logToFirebase("SIREN_TOGGLED", {"newState": isSirenEnabled});

    if (!isSirenEnabled) stopAllAudio();
  }

  void toggleHush() {
    isHushEnabled = !isHushEnabled;
    _settingsBox?.put('isHushEnabled', isHushEnabled);
    _hushStateController.add(isHushEnabled);

    // Log hush toggle
    _logToFirebase("HUSH_TOGGLED", {"newState": isHushEnabled});

    if (!isHushEnabled) stopAllAudio();
  }

  Future<void> stopVibration() async => await Vibration.cancel();

  void _startMotionTracking() {
    int motionCounter = 0;

    userAccelerometerEventStream().listen((event) async {
      double acc = sqrt(pow(event.x, 2) + pow(event.y, 2) + pow(event.z, 2));
      _accelController.add(acc / 9.8);

      // Log motion data (sample every 20 readings)
      motionCounter++;
      if (motionCounter % 20 == 0) {
        _logToFirebase("MOTION_READING", {
          "acceleration": acc,
          "gForce": acc / 9.8,
        });
      }

      if (acc > 32.0 && !isDialogShowing && isMonitoringEnabled) {
        isPendingAlert = true;
        _fallAlertController.add(true);

        // Log fall detection
        await _logToFirebase("FALL_DETECTED", {
          "acceleration": acc,
          "gForce": acc / 9.8,
          "x": event.x,
          "y": event.y,
          "z": event.z,
          "status": "PENDING_ALERT",
        });

        // Log alert
        await _logAlertToFirebase(
          "FALL_DETECTED",
          "⚠️ Fall Detected",
          "High impact detected. SOS will trigger in 15 seconds if not canceled.",
          {"acceleration": acc, "gForce": acc / 9.8},
        );
      }
    });
  }

  void _startLightTracking() => Light().lightSensorStream.listen((lux) {
    _lastLightValue = lux;
    _lightUIController.add(lux);
  });

  void _startPeriodicWellnessCheck() => Timer.periodic(
    const Duration(seconds: 30),
    (_) => runWellnessInference(),
  );

  Future<void> updateExternalStats() async {
    try {
      Position pos = await Geolocator.getCurrentPosition();
      final responses = await Future.wait([
        http.get(
          Uri.parse(
            "https://api.openweathermap.org/data/2.5/weather?lat=${pos.latitude}&lon=${pos.longitude}&appid=$apiKey&units=metric",
          ),
        ),
        http.get(
          Uri.parse(
            "https://api.openweathermap.org/data/2.5/air_pollution?lat=${pos.latitude}&lon=${pos.longitude}&appid=$apiKey",
          ),
        ),
      ]);
      if (responses[0].statusCode == 200) {
        _currentTemp = jsonDecode(responses[0].body)['main']['temp'].toDouble();
        _currentAQI = jsonDecode(responses[1].body)['list'][0]['main']['aqi'];
        _envDataController.add({'temp': _currentTemp, 'aqi': _currentAQI});

        // Log environmental data
        _logToFirebase("ENVIRONMENT_DATA", {
          "temperature": _currentTemp,
          "aqi": _currentAQI,
          "location": {"lat": pos.latitude, "lng": pos.longitude},
        });
      }
    } catch (e) {
      debugPrint("🌍 [ENV ERROR] $e");
    }
  }

  void runWellnessInference() {
    if (_wellnessInterpreter == null || !isMonitoringEnabled || !isAiEnabled)
      return;
    try {
      String result = "Ideal/Healthy";
      String advice = "Environment is safe.";
      Map<String, dynamic> envData = {
        "light": _lastLightValue,
        "noise": _lastNoiseValue,
        "temp": _currentTemp,
        "aqi": _currentAQI,
      };

      // If voice guardian is active, use last known noise value or default
      double effectiveNoise = _cachedVoiceGuardianState
          ? 50.0
          : _lastNoiseValue;

      if (_lastLightValue > 1500) {
        result = "Visual Stress";
        advice = "Extreme light detected.";
      } else if (effectiveNoise > 70 && _lastLightValue > 500) {
        result = "Sensory Overload";
        advice = "Combined bright and loud environment.";
      } else if (effectiveNoise > 82) {
        result = "Acoustic Hazard";
        advice = "Hazardous noise levels.";
      } else if (_currentTemp > 35 && _currentAQI >= 4) {
        result = "Respiratory Risk";
        advice = "Heat and poor air quality.";
      } else if (_currentAQI >= 5) {
        result = "Toxic Environment";
        advice = "Hazardous air quality.";
      }

      _wellnessController.add(result);

      // Log environmental diagnosis
      _logToFirebase("ENVIRONMENT_DIAGNOSIS", {
        ...envData,
        "diagnosis": result,
        "advice": advice,
        "voiceGuardianEnabled": _cachedVoiceGuardianState,
      });

      if (result != "Ideal/Healthy") {
        // Log environmental alert
        _logAlertToFirebase(
          "ENVIRONMENTAL_ALERT",
          "🏥 Chetna AI: $result",
          advice,
          {
            "diagnosis": result,
            "advice": advice,
            ...envData,
            "voiceGuardianEnabled": _cachedVoiceGuardianState,
          },
        );

        _notificationQueue.add({
          "title": "🏥 Chetna AI: $result",
          "body": advice,
          "type": result,
          "channel": _channelWellness,
        });
        _processNotificationQueue();
      }
    } catch (e) {
      debugPrint("❌ [AI ERROR] $e");
    }
  }

  Future<void> _processNotificationQueue() async {
    if (_isProcessingQueue || _notificationQueue.isEmpty) return;
    _isProcessingQueue = true;
    while (_notificationQueue.isNotEmpty) {
      final alert = _notificationQueue.removeAt(0);
      final id = _diagToId[alert['type']] ?? 999;
      if (!(await _isNotificationActive(id))) {
        await _triggerLocalNudge(
          alert['title']!,
          alert['body']!,
          id,
          alert['channel']!,
        );
        await Future.delayed(const Duration(seconds: 10));
      }
    }
    _isProcessingQueue = false;
  }

  Future<bool> _isNotificationActive(int id) async {
    final active = await _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.getActiveNotifications();
    return active?.any((n) => n.id == id) ?? false;
  }

  Future<void> _loadModels() async {
    try {
      _wellnessInterpreter = await Interpreter.fromAsset(
        'assets/models/wellness_diagnostic.tflite',
      );
    } catch (e) {
      debugPrint("🧠 [MODEL ERROR] $e");
    }
  }

  Future<void> _initNotifications() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _notifications.initialize(
      const InitializationSettings(android: android),
    );

    await _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            _channelService,
            'Chetna Service Status',
            importance: Importance.max,
            playSound: false,
            enableVibration: false,
          ),
        );

    await _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            _channelWellness,
            'Chetna Wellness',
            importance: Importance.high,
            playSound: false,
            enableVibration: true,
          ),
        );

    await _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            _channelEmergency,
            'Chetna Emergency',
            importance: Importance.max,
            playSound: true,
            enableVibration: true,
          ),
        );
  }

  Future<void> _triggerLocalNudge(
    String title,
    String msg,
    int id,
    String channelId,
  ) async {
    final android = AndroidNotificationDetails(
      channelId,
      channelId,
      importance: Importance.max,
      priority: Priority.high,
      playSound: channelId == _channelEmergency,
    );
    await _notifications.show(
      id,
      title,
      msg,
      NotificationDetails(android: android),
    );

    // Log notification
    _logToFirebase("NOTIFICATION_SENT", {
      "title": title,
      "message": msg,
      "channel": channelId,
      "notificationId": id,
    });
  }

  Future<String> setHomeLocation() async {
    try {
      Position pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      _homeLat = pos.latitude;
      _homeLng = pos.longitude;
      await _settingsBox?.put('homeLat', _homeLat);
      await _settingsBox?.put('homeLng', _homeLng);

      // Log home location set
      await _logToFirebase("HOME_LOCATION_SET", {
        "lat": _homeLat,
        "lng": _homeLng,
      });

      _geofenceStatusController.add("Home Set");
      return "${_homeLat!.toStringAsFixed(4)}, ${_homeLng!.toStringAsFixed(4)}";
    } catch (e) {
      debugPrint("❌ [HOME LOCATION ERROR] $e");
      return "Error";
    }
  }

  String getSavedHomeLocation() {
    if (_homeLat != null && _homeLng != null)
      return "${_homeLat!.toStringAsFixed(4)}, ${_homeLng!.toStringAsFixed(4)}";
    return "Not Set";
  }

  void _startGeofenceCheck() {
    Timer.periodic(const Duration(minutes: 15), (timer) async {
      if (_homeLat == null || !isMonitoringEnabled) return;
      try {
        Position currentPos = await Geolocator.getCurrentPosition();
        double dist = Geolocator.distanceBetween(
          _homeLat!,
          _homeLng!,
          currentPos.latitude,
          currentPos.longitude,
        );

        // Log location check
        _logToFirebase("LOCATION_CHECK", {
          "distance": dist,
          "homeLocation": {"lat": _homeLat, "lng": _homeLng},
          "currentLocation": {
            "lat": currentPos.latitude,
            "lng": currentPos.longitude,
          },
        });

        if (dist > 500) {
          _triggerLocalNudge(
            "Safety Alert",
            "Geofence Breach ($dist m).",
            107,
            _channelEmergency,
          );

          // Log geofence breach
          await _logToFirebase("GEOFENCE_BREACH", {
            "distance": dist,
            "homeLocation": {"lat": _homeLat, "lng": _homeLng},
            "currentLocation": {
              "lat": currentPos.latitude,
              "lng": currentPos.longitude,
            },
          });

          // Log alert
          await _logAlertToFirebase(
            "GEOFENCE_BREACH",
            "📍 Geofence Breach",
            "User is ${dist.toStringAsFixed(0)}m away from home location",
            {
              "distance": dist,
              "homeLocation": {"lat": _homeLat, "lng": _homeLng},
              "currentLocation": {
                "lat": currentPos.latitude,
                "lng": currentPos.longitude,
              },
            },
          );
        }
      } catch (e) {
        debugPrint("❌ [GEOFENCE ERROR] $e");
      }
    });
  }

  Future<void> saveUserProfile({
    required String name,
    required String phone,
    required String caregiverPhone,
  }) async {
    try {
      _caregiverPhone = caregiverPhone;

      await _db.child("users/$userId/profile").set({
        "name": name,
        "phone": phone,
        "caregiverPhone": caregiverPhone,
        "createdAt": ServerValue.timestamp,
        "updatedAt": ServerValue.timestamp,
        "status": "active_monitoring",
      });

      // Log profile creation
      await _logToFirebase("PROFILE_CREATED", {
        "name": name,
        "phone": phone,
        "caregiverPhone": caregiverPhone,
      });

      debugPrint("✅ [PROFILE] Saved to Firebase");
    } catch (e) {
      debugPrint("❌ [PROFILE ERROR] $e");
      rethrow;
    }
  }

  void logMood(String mood) {
    // Log mood to Firebase
    _logToFirebase("MOOD_LOG", {"mood": mood});

    // Log alert
    _logAlertToFirebase(
      "MOOD_REPORTED",
      "😊 Mood Updated",
      "User reported feeling: $mood",
      {"mood": mood},
    );
  }

  void toggleFocusSession() {
    if (isFocusSessionActive) {
      _stopFocusSession();
      // Log focus session ended
      _logToFirebase("FOCUS_SESSION_ENDED", {"duration": _focusSeconds});
    } else {
      _startFocusSession();
      // Log focus session started
      _logToFirebase("FOCUS_SESSION_STARTED", {});
    }
  }

  void _startFocusSession() {
    isFocusSessionActive = true;
    _focusSeconds = 0;
    _focusTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _focusSeconds++;
      _focusTimeController.add(_focusSeconds);
      if (_focusSeconds % 5 == 0) _runEdgeAIFocusCheck();
    });
  }

  void _runEdgeAIFocusCheck() {
    // Use effective noise value (account for voice guardian)
    double effectiveNoise = _cachedVoiceGuardianState ? 50.0 : _lastNoiseValue;

    if (effectiveNoise > 75) {
      // Log focus distraction
      _logToFirebase("FOCUS_DISTRACTION", {
        "reason": "high_noise",
        "noiseLevel": effectiveNoise,
        "voiceGuardianEnabled": _cachedVoiceGuardianState,
      });
      _triggerLocalNudge(
        "Focus Alert",
        "High noise detected.",
        201,
        _channelWellness,
      );
    } else if (_lastLightValue < 40) {
      // Log focus distraction
      _logToFirebase("FOCUS_DISTRACTION", {
        "reason": "low_light",
        "lightLevel": _lastLightValue,
      });
      _triggerLocalNudge("Focus Alert", "Too dark.", 201, _channelWellness);
    }
  }

  void _stopFocusSession() {
    isFocusSessionActive = false;
    _focusTimer?.cancel();
    _focusTimeController.add(0);
  }

  // ========== COMPATIBILITY METHODS (Keep for backward compatibility) ==========

  /// Temporary pause for Voice Guardian (compatibility with existing code)
  Future<void> pauseForVoice() async {
    debugPrint("⏸️ [COMPATIBILITY] Pausing for Voice Guardian");
    if (!_cachedVoiceGuardianState) {
      _stopNoiseTracking();
    }

    // Log the pause event
    await _logToFirebase("SENSOR_PAUSED", {
      "reason": "voice_guardian",
      "timestamp": DateTime.now().millisecondsSinceEpoch,
      "voiceGuardianEnabled": _cachedVoiceGuardianState,
    });
  }

  /// Resume after Voice Guardian (compatibility with existing code)
  Future<void> resumeAfterVoice() async {
    debugPrint("▶️ [COMPATIBILITY] Resuming after Voice Guardian");
    if (!_cachedVoiceGuardianState) {
      // Give the OS 1 second to fully release the mic
      await Future.delayed(const Duration(seconds: 1));
      _startNoiseTracking();
    }

    // Log the resume event
    await _logToFirebase("SENSOR_RESUMED", {
      "reason": "voice_guardian_complete",
      "timestamp": DateTime.now().millisecondsSinceEpoch,
      "voiceGuardianEnabled": _cachedVoiceGuardianState,
    });
  }

  // ========== TOGGLE METHOD (for UI) ==========

  void toggleVoiceMode() {
    setVoiceGuardianState(!_cachedVoiceGuardianState);
  }

  void dispose() {
    // Save voice guardian state before disposing
    _settingsBox?.put('voiceGuardianEnabled', _cachedVoiceGuardianState);

    // Cancel noise subscription
    _stopNoiseTracking();

    // Log app closing
    _logToFirebase("APP_CLOSED", {
      "timestamp": DateTime.now().millisecondsSinceEpoch,
      "voiceGuardianEnabled": _cachedVoiceGuardianState,
    });

    _notifications.cancel(_stickyNotificationId);
    _accelController.close();
    _wellnessController.close();
    _fallAlertController.close();
    _envDataController.close();
    _lightUIController.close();
    _noiseUIController.close();
    _sirenStateController.close();
    _hushStateController.close();
    _aiStateController.close();
    _audioStateController.close();
    _syncStatusController.close();
    _focusTimeController.close();
    _geofenceStatusController.close();
    _connectivityController.close();
    _voiceModeController.close();
  }
}
