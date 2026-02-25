import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // NATIVE HAPTICS
import 'package:speech_to_text/speech_to_text.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:record/record.dart'; // v6.1.2
import 'package:path_provider/path_provider.dart';
import 'package:flutter_background/flutter_background.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart'; // NEW

enum GuardianState { idle, listening, calming, escalating }

class VoiceGuardianService {
  final SpeechToText _speech = SpeechToText();
  final AudioPlayer _audioPlayer = AudioPlayer();
  final AudioRecorder _recorder = AudioRecorder();
  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin(); // NEW

  final List<String> _triggers = [
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
  ];

  GuardianState currentState = GuardianState.idle;
  String? _trustedVoicePath;
  Timer? _escalationTimer;

  Function? onEscalationTriggered;
  Function(String)? onStatusChanged;

  List<String> get currentTriggers => List.unmodifiable(_triggers);

  void addTrigger(String newWord) {
    if (newWord.isNotEmpty && !_triggers.contains(newWord.toLowerCase())) {
      _triggers.add(newWord.toLowerCase());
      _updateStatus("Added trigger: '$newWord'");
    }
  }

  Future<void> initialize() async {
    // 1. Init Background Mode
    await _enableBackgroundMode();

    // 2. Init Notifications
    await _initNotifications();

    if (await _recorder.hasPermission()) {
      // Mic checked
    }

    bool available = await _speech.initialize(
      onError: (e) {
        if (e.errorMsg != 'error_no_match') {
          // _updateStatus("Error: ${e.errorMsg}");
        }
        if (currentState == GuardianState.listening) {
          Future.delayed(const Duration(seconds: 1), () => startListening());
        }
      },
      onStatus: (status) {
        if ((status == 'done' || status == 'notListening') &&
            currentState == GuardianState.listening) {
          Future.delayed(const Duration(milliseconds: 500), () {
            if (currentState == GuardianState.listening) startListening();
          });
        }
      },
    );

    if (available) {
      _updateStatus("Guardian System Ready");
      await _loadSavedVoice();
    } else {
      _updateStatus("Voice Engine Unavailable");
    }
  }

  Future<void> _enableBackgroundMode() async {
    final androidConfig = FlutterBackgroundAndroidConfig(
      notificationTitle: "Chetna Voice Guardian",
      notificationText: "Active Listening for SOS keywords...",
      notificationImportance: AndroidNotificationImportance.normal,
      notificationIcon: AndroidResource(name: 'ic_launcher', defType: 'mipmap'),
      enableWifiLock: true,
    );

    try {
      bool hasPermissions = await FlutterBackground.initialize(
        androidConfig: androidConfig,
      );
      if (hasPermissions) {
        await FlutterBackground.enableBackgroundExecution();
      }
    } catch (e) {
      print("Background Init Failed: $e");
    }
  }

  // --- NEW NOTIFICATION LOGIC ---
  Future<void> _initNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    await _notifications.initialize(initializationSettings);
  }

  Future<void> _showNotification(String title, String body) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
          'emergency_channel', // id
          'Emergency Alerts', // name
          channelDescription: 'Notifications for SOS events',
          importance: Importance.max,
          priority: Priority.high,
          ticker: 'ticker',
          fullScreenIntent: true, // Tries to pop up even if screen off
        );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
    );

    await _notifications.show(0, title, body, platformChannelSpecifics);
  }
  // ------------------------------

  Future<void> startRecordingTrustedVoice() async {
    if (await _recorder.hasPermission()) {
      final directory = await getApplicationDocumentsDirectory();
      String path = '${directory.path}/trusted_voice.m4a';
      const config = RecordConfig(encoder: AudioEncoder.aacLc);
      await _recorder.start(config, path: path);
      _updateStatus("Recording...");
    }
  }

  Future<void> stopRecordingTrustedVoice() async {
    final path = await _recorder.stop();
    if (path != null) {
      _trustedVoicePath = path;
      _updateStatus("Trusted Voice Saved");
    }
  }

  Future<void> _loadSavedVoice() async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/trusted_voice.m4a');
    if (await file.exists()) {
      _trustedVoicePath = file.path;
      _updateStatus("Trusted Voice Loaded");
    }
  }

  void startListening() {
    if (currentState == GuardianState.calming ||
        currentState == GuardianState.escalating)
      return;

    currentState = GuardianState.listening;

    _speech.listen(
      onResult: (result) {
        String spokenWords = result.recognizedWords.toLowerCase();

        if (onStatusChanged != null)
          onStatusChanged!("Heard: \"$spokenWords\"");

        for (String word in _triggers) {
          if (spokenWords.contains(word)) {
            _triggerCalmingPhase();
            break;
          }
        }
      },
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 10),
      partialResults: true,
      onDevice: true,
      localeId: "en_IN",
      cancelOnError: false,
      listenMode: ListenMode.dictation,
    );
  }

  void stopListening() {
    currentState = GuardianState.idle;
    _speech.stop();
    _updateStatus("Guardian Paused");
  }

  Future<void> _triggerCalmingPhase() async {
    currentState = GuardianState.calming;
    await _speech.stop();

    _updateStatus("⚠️ KEYWORD DETECTED");

    // --- 1. SEND IMMEDIATE NOTIFICATION ---
    _showNotification(
      "⚠️ Emergency Detected!",
      "Trigger heard. SOS in 10 seconds.",
    );
    // --------------------------------------

    await HapticFeedback.heavyImpact();
    await Future.delayed(const Duration(milliseconds: 200));
    await HapticFeedback.heavyImpact();

    if (_trustedVoicePath != null) {
      await _audioPlayer.play(DeviceFileSource(_trustedVoicePath!));
    } else {
      _updateStatus("No Voice Found - Skipping");
    }

    _startEscalationTimer();
  }

  void _startEscalationTimer() {
    int countdown = 10;
    _escalationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (currentState != GuardianState.calming) {
        timer.cancel();
        return;
      }

      countdown--;
      _updateStatus("SOS in $countdown seconds...");

      if (countdown <= 0) {
        timer.cancel();
        _triggerFullSOS();
      }
    });
  }

  void _triggerFullSOS() {
    currentState = GuardianState.escalating;
    _updateStatus("🚨 SOS TRIGGERED 🚨");

    // --- 2. SEND FINAL NOTIFICATION ---
    _showNotification(
      "🚨 SOS SENT",
      "Emergency contacts have been notified with location.",
    );
    // ----------------------------------

    if (onEscalationTriggered != null) {
      onEscalationTriggered!();
    }
  }

  void cancelAlert() {
    _escalationTimer?.cancel();
    _audioPlayer.stop();
    currentState = GuardianState.idle;
    _updateStatus("Alert Cancelled.");

    // Cancel any active notification (ID 0)
    _notifications.cancel(0);

    Future.delayed(const Duration(seconds: 2), () {
      startListening();
    });
  }

  void _updateStatus(String msg) {
    if (onStatusChanged != null) onStatusChanged!(msg);
  }
}
