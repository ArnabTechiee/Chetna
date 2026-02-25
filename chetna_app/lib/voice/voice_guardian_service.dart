import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_background/flutter_background.dart' as fb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../sensor_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:hive_flutter/hive_flutter.dart'; // ADDED: For saving data

class VoiceGuardianPermissions {
  static Future<bool> requestVoicePermissions() async {
    try {
      var microphoneStatus = await Permission.microphone.request();
      if (!microphoneStatus.isGranted) return false;
      await Permission.notification.request();
      await Permission.ignoreBatteryOptimizations.request();
      return true;
    } catch (e) {
      debugPrint("❌ Permission error: $e");
      return false;
    }
  }
}

enum GuardianState { idle, listening, calming, escalating }

class VoiceGuardianService {
  final SensorService sensorService;
  final SpeechToText _speech = SpeechToText();
  final AudioPlayer _audioPlayer = AudioPlayer();
  final AudioRecorder _recorder = AudioRecorder();
  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static const int _notificationId = 88888;
  static const int _sessionDuration = 120;

  final StreamController<int> _countdownController =
      StreamController<int>.broadcast();
  Stream<int> get countdownStream => _countdownController.stream;

  Timer? _restartTimer;
  Timer? _escalationTimer;
  Timer? _sessionTimer;
  DateTime? _lastStartTime;

  // ADDED: Hive Box for storage
  Box? _voiceBox;

  // CHANGED: Define defaults separately
  static const List<String> _defaultTriggers = [
    'help',
    'elp',
    'hello',
    'bachao',
    'bacho',
    'watch out',
    'batch out',
    'batch',
    'but chow',
    'bot chow',
    'but how',
    'emergency',
    'save me',
    'save',
    'stop',
    'about',
    'papa',
    'mummy',
    'doctor',
    'ambulance',
    'pain',
    'hurt',
    'sos',
  ];

  // CHANGED: The active list is now dynamic
  List<String> _triggers = [];

  GuardianState currentState = GuardianState.idle;
  String? _trustedVoicePath;
  bool get isListening => currentState == GuardianState.listening;

  Function? onCountdownStarted;
  Function? onEscalationTriggered;
  Function(String)? onStatusChanged;

  VoiceGuardianService({required this.sensorService});

  List<String> get currentTriggers => List.unmodifiable(_triggers);

  // CHANGED: Add and Save
  void addTrigger(String newWord) {
    String lowerWord = newWord.toLowerCase();
    if (newWord.isNotEmpty && !_triggers.contains(lowerWord)) {
      _triggers.add(lowerWord);
      _saveTriggers(); // Save to storage
      _updateStatus("✅ Added trigger: '$newWord'");
    }
  }

  // CHANGED: Remove and Save (Feature you requested)
  void removeTrigger(String word) {
    String lowerWord = word.toLowerCase();
    if (_triggers.contains(lowerWord)) {
      _triggers.remove(lowerWord);
      _saveTriggers(); // Save to storage
      _updateStatus("❌ Removed trigger: '$word'");
    }
  }

  // ADDED: Helper to save list to Hive
  Future<void> _saveTriggers() async {
    await _voiceBox?.put('triggers', _triggers);
    debugPrint("💾 Triggers saved to storage.");
  }

  Future<bool> initialize() async {
    try {
      _updateStatus("🔄 Initializing Voice Guardian...");

      bool hasPermissions =
          await VoiceGuardianPermissions.requestVoicePermissions();
      if (!hasPermissions) {
        _updateStatus("❌ Permissions denied.");
        return false;
      }

      // ADDED: Load persisted triggers
      try {
        await Hive.initFlutter();
        _voiceBox = await Hive.openBox('voice_guardian_settings');
        List<dynamic>? saved = _voiceBox?.get('triggers');

        if (saved != null && saved.isNotEmpty) {
          _triggers = List<String>.from(saved);
          debugPrint(
            "📂 Loaded ${_triggers.length} custom triggers from storage.",
          );
        } else {
          _triggers = List<String>.from(_defaultTriggers);
          debugPrint("📂 Loaded default triggers.");
        }
      } catch (e) {
        debugPrint("⚠️ Hive Load Error: $e");
        _triggers = List<String>.from(_defaultTriggers);
      }

      await _initNotifications();
      await _loadSavedVoice();
      await _enableBackgroundMode();

      bool speechAvailable = await _speech.initialize(
        onError: (error) {
          String errorMsg = error.errorMsg.toLowerCase();
          bool isSilence =
              errorMsg.contains('match') || errorMsg.contains('timeout');
          bool isClientError = errorMsg.contains('client');

          if (!isSilence) debugPrint("🗣️ Speech Error: ${error.errorMsg}");

          if (sensorService.isVoiceGuardianEnabled &&
              currentState == GuardianState.listening) {
            int delay = isClientError ? 10 : (isSilence ? 1 : 2);
            if (isClientError)
              debugPrint("⚠️ Busy/Client Error. Cooling down for 10s...");
            _scheduleRestart(delaySeconds: delay);
          }
        },
        onStatus: (status) {
          if (status == 'listening') debugPrint("🗣️ Speech Status: listening");
          if ((status == 'done' || status == 'notListening') &&
              sensorService.isVoiceGuardianEnabled &&
              currentState == GuardianState.listening) {
            _scheduleRestart(delaySeconds: 1);
          }
        },
      );

      if (!speechAvailable) {
        _updateStatus("❌ Speech recognition unavailable");
        return false;
      }

      if (sensorService.isVoiceGuardianEnabled) {
        debugPrint("🔄 Restoring Voice Guardian...");
        await startListening(isRestart: true);
      } else {
        _updateStatus("Ready (Toggle OFF)");
      }

      return true;
    } catch (e) {
      _updateStatus("❌ Initialization failed: $e");
      return false;
    }
  }

  void _scheduleRestart({required int delaySeconds}) {
    if (currentState != GuardianState.listening) return;
    _restartTimer?.cancel();
    _restartTimer = Timer(Duration(seconds: delaySeconds), () {
      if (sensorService.isVoiceGuardianEnabled &&
          currentState == GuardianState.listening) {
        if (!_speech.isListening) {
          startListening(isRestart: true);
        }
      }
    });
  }

  Future<void> _enableBackgroundMode() async {
    try {
      final androidConfig = fb.FlutterBackgroundAndroidConfig(
        notificationTitle: "Chetna Voice Guardian",
        notificationText: "Active Listening...",
        notificationImportance: fb.AndroidNotificationImportance.normal,
        notificationIcon: const fb.AndroidResource(
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
        debugPrint("✅ Voice background mode enabled");
      }
    } catch (e) {
      debugPrint("⚠️ Voice background mode warning: $e");
    }
  }

  Future<void> _initNotifications() async {
    try {
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const InitializationSettings initializationSettings =
          InitializationSettings(android: initializationSettingsAndroid);
      await _notifications.initialize(initializationSettings);

      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'voice_sos_v3',
        'Voice Emergency Alerts',
        description: 'High priority alerts for voice SOS',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
      );

      await _notifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(channel);
    } catch (e) {
      debugPrint("❌ Notification init error: $e");
    }
  }

  Future<void> _showNotification(
    String title,
    String body, {
    bool silentUpdate = false,
  }) async {
    try {
      const AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
            'voice_sos_v3',
            'Voice Emergency Alerts',
            importance: Importance.max,
            priority: Priority.high,
            fullScreenIntent: true,
            onlyAlertOnce: true,
            category: AndroidNotificationCategory.alarm,
          );
      await _notifications.show(
        _notificationId,
        title,
        body,
        NotificationDetails(android: androidDetails),
      );
    } catch (e) {
      debugPrint("❌ Notification error: $e");
    }
  }

  Future<void> startListening({bool isRestart = false}) async {
    if (_speech.isListening) return;

    if (_lastStartTime != null) {
      final diff = DateTime.now().difference(_lastStartTime!).inMilliseconds;
      if (diff < 100) {
        _scheduleRestart(delaySeconds: 1);
        return;
      }
    }
    _lastStartTime = DateTime.now();

    if (!isRestart) {
      sensorService.setVoiceGuardianState(true);
      await Future.delayed(const Duration(milliseconds: 500));
    }

    if (currentState == GuardianState.calming) return;

    currentState = GuardianState.listening;
    if (!isRestart) _updateStatus("✅ Voice Guardian Active");

    await _startSpeechEngine();

    // Master 120s Refresh Loop
    _sessionTimer?.cancel();
    _sessionTimer = Timer.periodic(const Duration(seconds: _sessionDuration), (
      timer,
    ) async {
      if (currentState == GuardianState.listening) {
        debugPrint("🔄 120s Cycle: Refreshing Listener...");
        await _speech.stop();
        await Future.delayed(const Duration(milliseconds: 500));
        await _startSpeechEngine();
      } else {
        timer.cancel();
      }
    });
  }

  Future<void> _startSpeechEngine() async {
    if (currentState != GuardianState.listening) return;
    _restartTimer?.cancel();

    debugPrint("🎤 Starting 120-second speech session...");

    try {
      await _speech.listen(
        onResult: (result) {
          String spokenWords = result.recognizedWords.toLowerCase().trim();

          if (result.finalResult && spokenWords.isNotEmpty) {
            debugPrint(
              "🗣️ Heard: '$spokenWords' (Final: ${result.finalResult})",
            );
            _updateStatus("👂 Heard: \"$spokenWords\"");

            // Check for trigger words
            for (String trigger in _triggers) {
              if (spokenWords.contains(trigger)) {
                debugPrint("🚨 Trigger detected: '$trigger' in '$spokenWords'");
                _triggerCalmingPhase();
                return;
              }
            }
          }
        },
        listenFor: const Duration(seconds: _sessionDuration),
        pauseFor: const Duration(seconds: 20),
        partialResults: true,
        onDevice: true,
        localeId: "en-IN",
        cancelOnError: true,
        listenMode: ListenMode.dictation,
        onSoundLevelChange: (level) {
          // Optional: Visual feedback for audio level
        },
      );
    } catch (e) {
      debugPrint("❌ Speech engine start failed: $e");
      _scheduleRestart(delaySeconds: 2);
    }
  }

  Future<void> stopListening() async {
    debugPrint("🛑 Stopping Voice Guardian.");
    sensorService.setVoiceGuardianState(false);

    _restartTimer?.cancel();
    _sessionTimer?.cancel();
    _escalationTimer?.cancel();
    currentState = GuardianState.idle;
    await _speech.stop();
    _countdownController.add(-1);
    _updateStatus("⏸️ Protection Disabled");
    sensorService.disableVoiceMode();

    try {
      await _notifications.cancel(_notificationId);
    } catch (e) {
      debugPrint("❌ Notification cancel error: $e");
    }
  }

  Future<void> _triggerCalmingPhase() async {
    if (currentState == GuardianState.calming) return;

    currentState = GuardianState.calming;
    _restartTimer?.cancel();
    _sessionTimer?.cancel();
    await _speech.stop();
    _updateStatus("⚠️ VOICE KEYWORD DETECTED");
    _countdownController.add(10);

    if (onCountdownStarted != null) onCountdownStarted!();

    await _showNotification(
      "⚠️ Voice Emergency Detected!",
      "Trigger heard. SOS in 10 seconds.",
    );
    await HapticFeedback.heavyImpact();
    await Future.delayed(const Duration(milliseconds: 300));
    await HapticFeedback.heavyImpact();
    _startEscalationTimer();

    if (_trustedVoicePath != null) {
      final file = File(_trustedVoicePath!);
      if (await file.exists()) {
        try {
          await _audioPlayer.play(DeviceFileSource(_trustedVoicePath!));
          await Future.delayed(const Duration(seconds: 5));
        } catch (e) {
          debugPrint("❌ Trusted voice playback failed: $e");
        }
      } else {
        _updateStatus("ℹ️ No trusted voice - skipping calming phase");
      }
    } else {
      _updateStatus("ℹ️ No trusted voice - skipping calming phase");
    }
  }

  void _startEscalationTimer() {
    int countdown = 10;
    _escalationTimer?.cancel();
    _escalationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (currentState != GuardianState.calming) {
        timer.cancel();
        return;
      }
      countdown--;
      _countdownController.add(countdown);
      _updateStatus("⏳ SOS in $countdown seconds...");

      _showNotification(
        "⚠️ Voice SOS Countdown",
        "Emergency in $countdown seconds...",
        silentUpdate: true,
      );

      if (countdown <= 0) {
        timer.cancel();
        _triggerFullSOS();
      }
    });
  }

  Future<void> _triggerFullSOS() async {
    currentState = GuardianState.escalating;
    _updateStatus("🚨 VOICE SOS TRIGGERED 🚨");
    try {
      await sensorService.triggerImmediateSOS(isManual: false);
      debugPrint("🚨 VOICE SOS: Triggered via voice command");
      await _showNotification(
        "🚨 VOICE SOS SENT",
        "Emergency contacts notified with Location.",
      );
    } catch (e) {
      debugPrint("❌ Voice SOS trigger failed: $e");
      // Fallback: Direct notification
      await _showNotification(
        "🚨 VOICE SOS ACTIVATED",
        "Emergency triggered by voice command.",
      );
    }

    if (onEscalationTriggered != null) onEscalationTriggered!();
  }

  Future<void> cancelAlert() async {
    _escalationTimer?.cancel();
    _restartTimer?.cancel();
    _sessionTimer?.cancel();
    try {
      await _audioPlayer.stop();
      await sensorService.stopAllAudio();
    } catch (e) {
      debugPrint("❌ Audio stop error: $e");
    }

    bool wasEscalating = (currentState == GuardianState.escalating);

    if (sensorService.isVoiceGuardianEnabled) {
      currentState = GuardianState.listening;
    } else {
      currentState = GuardianState.idle;
    }

    _updateStatus("✅ Voice Alert Cancelled");
    try {
      await _notifications.cancel(_notificationId);
    } catch (e) {
      debugPrint("❌ Notification cancel error: $e");
    }

    await sensorService.resolveSOS();

    if (wasEscalating) {
      debugPrint("📱 Sending I AM SAFE Message...");
      await sensorService.sendSafeMessage();
      await _showNotification(
        "✅ SOS Resolved",
        "Caregiver notified that you are safe.",
      );
      Future.delayed(const Duration(seconds: 5), () {
        _notifications.cancel(_notificationId);
      });
    } else {
      await _notifications.cancel(_notificationId);
    }

    _countdownController.add(-1);

    if (sensorService.isVoiceGuardianEnabled) {
      Timer(const Duration(seconds: 2), () {
        if (currentState == GuardianState.listening) {
          startListening(isRestart: true);
        }
      });
    }
  }

  Future<void> startRecordingTrustedVoice() async {
    try {
      if (!await _recorder.hasPermission()) {
        _updateStatus("❌ Microphone permission needed");
        return;
      }
      await sensorService.pauseForTrustedRecording();
      if (_speech.isListening) await _speech.stop();
      _restartTimer?.cancel();
      _sessionTimer?.cancel();

      final directory = await getApplicationDocumentsDirectory();
      String path = '${directory.path}/trusted_voice.m4a';
      final file = File(path);
      if (await file.exists()) await file.delete();

      const config = RecordConfig(
        encoder: AudioEncoder.aacLc,
        sampleRate: 16000,
        numChannels: 1,
        bitRate: 128000,
      );
      await _recorder.start(config, path: path);
      _updateStatus("🎤 Recording... Speak now");
    } catch (e) {
      _updateStatus("❌ Recording failed: ${e.toString()}");
    }
  }

  Future<void> stopRecordingTrustedVoice() async {
    try {
      final path = await _recorder.stop();
      if (path != null) {
        final file = File(path);
        if (await file.exists()) {
          _trustedVoicePath = path;
          _updateStatus("✅ Trusted Voice Saved");
          await _audioPlayer.play(DeviceFileSource(path));
          await Future.delayed(const Duration(seconds: 2));
          await _audioPlayer.stop();
        } else {
          _updateStatus("❌ Recording failed - file not saved");
        }
      } else {
        _updateStatus("❌ Recording failed - no audio saved");
      }
    } catch (e) {
      _updateStatus("❌ Stop recording failed: $e");
    } finally {
      await sensorService.resumeAfterTrustedRecording();
      if (sensorService.isVoiceGuardianEnabled) {
        startListening(isRestart: true);
      }
    }
  }

  Future<void> _loadSavedVoice() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/trusted_voice.m4a');
      if (await file.exists()) {
        _trustedVoicePath = file.path;
        _updateStatus("✅ Trusted Voice Loaded");
      } else {
        _updateStatus("ℹ️ No trusted voice recorded yet");
      }
    } catch (e) {
      debugPrint("❌ Load saved voice error: $e");
    }
  }

  void _updateStatus(String msg) {
    debugPrint("🗣️ Voice Guardian: $msg");
    if (onStatusChanged != null) onStatusChanged!(msg);
  }

  void dispose() {
    _sessionTimer?.cancel();
    _escalationTimer?.cancel();
    _restartTimer?.cancel();
    _speech.stop();
    _audioPlayer.dispose();
    _countdownController.close();
    try {
      _recorder.dispose();
    } catch (e) {
      debugPrint("❌ Recorder dispose error: $e");
    }
    try {
      _notifications.cancel(_notificationId);
    } catch (e) {
      debugPrint("❌ Notification cancel error: $e");
    }
    currentState = GuardianState.idle;
    debugPrint("🗣️ Voice Guardian Disposed");
  }
}
