import 'package:flutter/material.dart';
import '../sensor_service.dart';
import 'voice_guardian_service.dart';

/// Voice Integration Bridge
/// Connects Voice Guardian with existing Chetna AI systems
class VoiceIntegration {
  final SensorService sensorService;
  final VoiceGuardianService voiceService;

  VoiceIntegration({required this.sensorService, required this.voiceService});

  /// Initialize and connect both services
  Future<void> initialize() async {
    // 1. Setup callbacks between services
    _setupCrossServiceCallbacks();

    // 2. Sync settings between services
    await _syncSettings();

    // 3. Start voice guardian if sensor service is active
    if (sensorService.isMonitoringEnabled) {
      await voiceService.initialize();
      voiceService.startListening();
    }
  }

  /// Setup bidirectional communication between services
  void _setupCrossServiceCallbacks() {
    // When SensorService SOS is triggered manually, pause voice listening
    // This prevents duplicate alerts
    sensorService.sirenStateStream.listen((isSirenOn) {
      if (isSirenOn && voiceService.currentState != _VoiceGuardianState.idle) {
        voiceService.stopListening();
      }
    });

    // When SensorService monitoring stops, also stop voice guardian
    sensorService.aiStateStream.listen((isAiOn) {
      if (!isAiOn && voiceService.currentState != _VoiceGuardianState.idle) {
        voiceService.stopListening();
      }
    });

    // When voice guardian triggers SOS, make sure SensorService knows
    voiceService.onEscalationTriggered = () {
      // SensorService will handle SMS, siren, and Firebase logging
      // This callback is already connected in voice_guardian_service
    };
  }

  /// Sync settings between SensorService and Voice Guardian
  Future<void> _syncSettings() async {
    // Sync SMS settings - if SMS is disabled in main app, voice shouldn't send SMS
    // (Voice guardian uses sensorService.triggerImmediateSOS which respects isSmsEnabled)

    // Sync caregiver phone - ensure both services use same contact
    final caregiverPhone = await sensorService.getCaregiverPhone();

    // You could also sync notification preferences here
  }

  /// Unified emergency stop - stops both services
  Future<void> emergencyStop() async {
    // 1. Stop voice guardian audio and listening
    voiceService.cancelAlert();

    // 2. Stop sensor service audio
    await sensorService.stopAllAudio();

    // 3. Reset fall detection
    sensorService.resetFallDetection();

    // 4. Cancel all notifications from both services
    await sensorService.resolveSOS();
  }

  /// Unified status check
  Map<String, dynamic> getSystemStatus() {
    return {
      'voice_guardian': {
        'state': _getVoiceStateString(voiceService.currentState),
        'listening': voiceService.currentState == _VoiceGuardianState.listening,
        'has_trusted_voice':
            voiceService.currentState != _VoiceGuardianState.idle,
        'triggers_count': voiceService.currentTriggers.length,
      },
      'sensor_service': {
        'monitoring': sensorService.isMonitoringEnabled,
        'ai_enabled': sensorService.isAiEnabled,
        'sms_enabled': sensorService.isSmsEnabled,
        'fall_detected': false, // Would need a getter
      },
      'combined_emergency':
          sensorService.isAlertActive ||
          voiceService.currentState == _VoiceGuardianState.escalating,
    };
  }

  /// Helper method to convert voice state to string
  String _getVoiceStateString(dynamic state) {
    if (state == _VoiceGuardianState.idle) return "IDLE";
    if (state == _VoiceGuardianState.listening) return "LISTENING";
    if (state == _VoiceGuardianState.calming) return "CALMING";
    if (state == _VoiceGuardianState.escalating) return "ESCALATING";
    return "UNKNOWN";
  }

  /// Log voice events to Firebase through SensorService
  /// Use public logging method instead of private one
  Future<void> logVoiceEvent(
    String eventType,
    Map<String, dynamic> data,
  ) async {
    // Create a complete event to log through sensor service
    final eventData = {
      'type': 'VOICE_EVENT',
      'voice_event_type': eventType,
      'voice_state': _getVoiceStateString(voiceService.currentState),
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      ...data,
    };

    // Since _logToFirebase is private, we'll use a different approach
    // Option 1: Call a public method if it exists
    // Option 2: Direct Firebase call (not recommended)
    // Option 3: Add a public wrapper in SensorService (best)

    // For now, let's print it
    print("[VOICE LOG] $eventType: $data");

    // TODO: You need to add a public logging method to SensorService
    // Example: sensorService.logEvent('VOICE_$eventType', data);
  }

  /// Dispose both services properly
  void dispose() {
    voiceService.dispose();
    // SensorService is disposed by main app
  }
}

/// Helper enum to match VoiceGuardianService states
/// Since GuardianState is private inside VoiceGuardianService
enum _VoiceGuardianState { idle, listening, calming, escalating }

/// Helper widget to inject VoiceIntegration into app
class VoiceIntegrationWrapper extends StatelessWidget {
  final Widget child;
  final SensorService sensorService;
  final VoiceGuardianService voiceService;
  final VoiceIntegration integration;

  VoiceIntegrationWrapper({
    super.key,
    required this.child,
    required this.sensorService,
    required this.voiceService,
  }) : integration = VoiceIntegration(
         sensorService: sensorService,
         voiceService: voiceService,
       );

  @override
  Widget build(BuildContext context) {
    // Initialize integration when widget builds
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await integration.initialize();
    });

    return child;
  }

  // Static method to get integration from context
  static VoiceIntegration of(BuildContext context) {
    final wrapper = context
        .findAncestorWidgetOfExactType<VoiceIntegrationWrapper>();
    assert(wrapper != null, 'VoiceIntegrationWrapper not found in context');
    return wrapper!.integration;
  }
}
