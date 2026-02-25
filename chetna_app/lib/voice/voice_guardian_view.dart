import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../sensor_service.dart';
import '../voice/voice_guardian_service.dart';

class VoiceGuardianView extends StatefulWidget {
  final SensorService sensorService;
  final VoiceGuardianService voiceService;
  final VoidCallback? onRetry;

  const VoiceGuardianView({
    super.key,
    required this.sensorService,
    required this.voiceService,
    this.onRetry,
  });

  @override
  State<VoiceGuardianView> createState() => _VoiceGuardianViewState();
}

class _VoiceGuardianViewState extends State<VoiceGuardianView>
    with TickerProviderStateMixin {
  late VoiceGuardianService _guardian;
  final TextEditingController _triggerController = TextEditingController();
  StreamSubscription<int>? _countdownSubscription;

  String _status = "System Ready";
  bool _isRecording = false;
  bool _isGuardianActive = false;
  bool _isInitializing = true;
  bool _hasPermissionError = false;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late AnimationController _buttonAnimationController;
  late Animation<double> _buttonScaleAnimation;

  // Enhanced Color Palette
  final Color _primaryColor = const Color(0xFF0F766E);
  final Color _accentColor = const Color(0xFF14B8A6);
  final Color _alertColor = const Color(0xFFEF4444);
  final Color _successColor = const Color(0xFF10B981);
  final Color _warningColor = const Color(0xFFF59E0B);
  final Color _bgColor = const Color(0xFFF8FAFC);
  final Color _cardColor = Colors.white;
  final Color _textPrimary = const Color(0xFF1E293B);
  final Color _textSecondary = const Color(0xFF64748B);
  final Color _borderColor = const Color(0xFFE2E8F0);

  // Gradient for active state
  final Gradient _activeGradient = const LinearGradient(
    colors: [Color(0xFF0F766E), Color(0xFF14B8A6)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  @override
  void initState() {
    super.initState();
    _guardian = widget.voiceService;

    // Main pulse animation for status
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Button press animation
    _buttonAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _buttonScaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(
        parent: _buttonAnimationController,
        curve: Curves.easeInOut,
      ),
    );

    // Restore saved state
    Future.delayed(Duration.zero, () {
      if (widget.sensorService.isVoiceGuardianEnabled) {
        setState(() {
          _isGuardianActive = true;
          _status = "Voice Guardian Active";
          _pulseController.repeat(reverse: true);
        });
      }
    });

    _initializeVoiceGuardian();
    _setupListeners();
  }

  Future<void> _initializeVoiceGuardian() async {
    setState(() {
      _isInitializing = true;
      _status = "Initializing Voice Guardian...";
    });

    bool initialized = await _guardian.initialize();

    if (!initialized) {
      setState(() {
        _hasPermissionError = true;
        _status = "Microphone permission required";
      });
    } else {
      setState(() {
        _isInitializing = false;
        if (widget.sensorService.isVoiceGuardianEnabled) {
          _isGuardianActive = true;
          _status = "Voice Guardian Active";
          _pulseController.repeat(reverse: true);
          if (!_guardian.isListening) {
            _guardian.startListening();
          }
        } else {
          _status = "Voice Guardian Ready";
        }
      });
    }
  }

  void _setupListeners() {
    _guardian.onStatusChanged = (msg) {
      if (!mounted) return;
      if (!msg.startsWith("Heard:")) {
        setState(() => _status = msg);
      }
    };

    _guardian.onCountdownStarted = _showCountdownDialog;
    _guardian.onEscalationTriggered = _showSOSDialog;
  }

  void _toggleGuardian(bool value) {
    if (_isGuardianActive == value) return;

    setState(() => _isGuardianActive = value);
    widget.sensorService.setVoiceGuardianState(value);

    if (value) {
      if (_hasPermissionError) {
        _initializeVoiceGuardian().then((_) {
          if (!_hasPermissionError) {
            _activateGuardian();
          }
        });
      } else {
        _activateGuardian();
      }
    } else {
      _deactivateGuardian();
    }
  }

  void _activateGuardian() {
    _guardian.startListening();
    _pulseController.repeat(reverse: true);

    // Show beautiful toast notification
    _showStatusToast(
      "Voice Protection Active",
      "Noise monitoring paused",
      Icons.shield_rounded,
      _successColor,
    );

    widget.sensorService.logEvent("VOICE_GUARDIAN_UI_ENABLED", {
      "timestamp": DateTime.now().millisecondsSinceEpoch,
      "fromUI": true,
    });
  }

  void _deactivateGuardian() {
    _guardian.stopListening();
    _pulseController.stop();
    _pulseController.reset();

    _showStatusToast(
      "Voice Protection Off",
      "Noise monitoring resumed",
      Icons.mic_none_rounded,
      _warningColor,
    );

    widget.sensorService.logEvent("VOICE_GUARDIAN_UI_DISABLED", {
      "timestamp": DateTime.now().millisecondsSinceEpoch,
      "fromUI": true,
    });
  }

  void _showStatusToast(
    String title,
    String subtitle,
    IconData icon,
    Color color,
  ) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        content: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _cardColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, 5),
              ),
            ],
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: _textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(color: _textSecondary, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _addNewTrigger() {
    if (_triggerController.text.trim().isNotEmpty) {
      final trigger = _triggerController.text.trim();
      _guardian.addTrigger(trigger);
      _triggerController.clear();
      setState(() {});

      // Trigger added animation feedback
      _buttonAnimationController.forward().then((_) {
        _buttonAnimationController.reverse();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Added trigger: $trigger"),
          backgroundColor: _successColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          duration: const Duration(seconds: 2),
        ),
      );

      widget.sensorService.logEvent("VOICE_TRIGGER_ADDED", {
        "trigger": trigger,
        "timestamp": DateTime.now().millisecondsSinceEpoch,
      });
    }
  }

  void _showCountdownDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (context) {
        return StreamBuilder<int>(
          stream: _guardian.countdownStream,
          initialData: 10,
          builder: (context, snapshot) {
            final seconds = snapshot.data ?? 10;
            final progress = seconds / 10.0;

            if (seconds == -1) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (Navigator.canPop(context)) {
                  Navigator.pop(context);
                }
              });
              return const SizedBox.shrink();
            }

            return Dialog(
              backgroundColor: Colors.transparent,
              elevation: 0,
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: _cardColor,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 30,
                      offset: const Offset(0, 20),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Animated timer circle
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 120,
                          height: 120,
                          child: CircularProgressIndicator(
                            value: progress,
                            backgroundColor: _alertColor.withOpacity(0.1),
                            valueColor: AlwaysStoppedAnimation(_alertColor),
                            strokeWidth: 8,
                            strokeCap: StrokeCap.round,
                          ),
                        ),
                        Column(
                          children: [
                            Text(
                              "$seconds",
                              style: const TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFFEF4444),
                              ),
                            ),
                            Text(
                              "seconds",
                              style: TextStyle(
                                fontSize: 12,
                                color: _textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Text(
                        "Emergency Detected",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: _textPrimary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 8),

                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Text(
                        "SOS will be sent in $seconds seconds",
                        style: TextStyle(fontSize: 14, color: _textSecondary),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // False alarm button with scale animation
                    AnimatedBuilder(
                      animation: _buttonScaleAnimation,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _buttonScaleAnimation.value,
                          child: child,
                        );
                      },
                      child: GestureDetector(
                        onTapDown: (_) => _buttonAnimationController.forward(),
                        onTapUp: (_) => _buttonAnimationController.reverse(),
                        onTapCancel: () => _buttonAnimationController.reverse(),
                        onTap: () {
                          Navigator.pop(context);
                          _guardian.cancelAlert();
                          _showStatusToast(
                            "Alert Cancelled",
                            "False alarm resolved",
                            Icons.check_circle_rounded,
                            _successColor,
                          );
                          widget.sensorService
                              .logEvent("FALSE_ALARM_CANCELLED", {
                                "timestamp":
                                    DateTime.now().millisecondsSinceEpoch,
                                "source": "voice_guardian",
                              });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: 16,
                            horizontal: 24,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: _alertColor, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: _alertColor.withOpacity(0.1),
                                blurRadius: 10,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              "FALSE ALARM - CANCEL",
                              style: TextStyle(
                                color: _alertColor,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showSOSDialog() {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.8),
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [const Color(0xFF1F2937), const Color(0xFF111827)],
            ),
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: _alertColor.withOpacity(0.3),
                blurRadius: 40,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Emergency icon with pulsing effect
              Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _alertColor.withOpacity(0.2),
                    ),
                  ),
                  Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _alertColor.withOpacity(0.4),
                    ),
                  ),
                  Icon(Icons.emergency_rounded, size: 48, color: Colors.white),
                ],
              ),
              const SizedBox(height: 24),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Text(
                  "SOS EMERGENCY",
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 12),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Text(
                  "Emergency message sent with location",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.white70),
                ),
              ),
              const SizedBox(height: 8),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Text(
                  "Siren is active",
                  style: TextStyle(fontSize: 14, color: Colors.white60),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 32),

              // Safe button
              GestureDetector(
                onTapDown: (_) => _buttonAnimationController.forward(),
                onTapUp: (_) => _buttonAnimationController.reverse(),
                onTapCancel: () => _buttonAnimationController.reverse(),
                onTap: () {
                  Navigator.pop(context);
                  _guardian.cancelAlert();
                  _showStatusToast(
                    "Safe Message Sent",
                    "Emergency resolved",
                    Icons.thumb_up_rounded,
                    _successColor,
                  );
                  widget.sensorService.logEvent("SOS_RESOLVED_SAFE", {
                    "timestamp": DateTime.now().millisecondsSinceEpoch,
                    "source": "voice_guardian",
                  });
                },
                child: AnimatedBuilder(
                  animation: _buttonAnimationController,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _buttonScaleAnimation.value,
                      child: child,
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 18,
                      horizontal: 32,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [_successColor, const Color(0xFF34D399)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: _successColor.withOpacity(0.4),
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.check_circle_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          "I AM SAFE - RESOLVE",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitializing) {
      return _buildLoadingScreen();
    }

    if (_hasPermissionError) {
      return _buildPermissionScreen();
    }

    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        title: Row(
          children: [
            // App Icon on top-left side
            Container(
              width: 32,
              height: 32,
              margin: EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.white.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(7),
                child: Image.asset(
                  "assets/icon/app_icon.jpeg",
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    // Fallback if image fails to load
                    return Container(
                      color: Color(0xFF0F766E),
                      child: Icon(
                        Icons.medical_services,
                        size: 18,
                        color: Colors.white,
                      ),
                    );
                  },
                ),
              ),
            ),
            Text(
              "Voice Guardian",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        centerTitle: false, // Changed to false for left alignment
        backgroundColor: _cardColor,
        elevation: 0,
        shadowColor: Colors.black.withOpacity(0.05),
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Color(0xFF1E293B)),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Main Status Card
            _buildStatusCard(),
            const SizedBox(height: 28),

            // Security Controls Section
            _buildSectionHeader(
              title: "Security Controls",
              subtitle: "Manage voice protection settings",
            ),
            const SizedBox(height: 16),

            _buildControlCard(
              title: "Voice Protection",
              subtitle: _isGuardianActive
                  ? "Listening for emergency commands"
                  : "Noise monitoring active",
              icon: Icons.security_rounded,
              trailing: _buildToggleSwitch(),
            ),
            const SizedBox(height: 16),

            _buildTrustedVoiceRecorder(),
            const SizedBox(height: 28),

            // Recognition Database Section
            _buildSectionHeader(
              title: "Recognition Database",
              subtitle: "Manage trigger phrases",
            ),
            const SizedBox(height: 16),

            _buildTriggerList(),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingScreen() {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        title: Row(
          children: [
            // App Icon on top-left side
            Container(
              width: 32,
              height: 32,
              margin: EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.white.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(7),
                child: Image.asset(
                  "assets/icon/app_icon.jpeg",
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    // Fallback if image fails to load
                    return Container(
                      color: Color(0xFF0F766E),
                      child: Icon(
                        Icons.medical_services,
                        size: 18,
                        color: Colors.white,
                      ),
                    );
                  },
                ),
              ),
            ),
            Text(
              "Voice Guardian",
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        centerTitle: false, // Changed to false for left alignment
        backgroundColor: _cardColor,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: _primaryColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                ),
                SizedBox(
                  width: 60,
                  height: 60,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor: AlwaysStoppedAnimation(_primaryColor),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                _status,
                style: TextStyle(
                  fontSize: 16,
                  color: _textPrimary,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 8),
            if (widget.sensorService.isVoiceGuardianEnabled)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  "Restoring saved state...",
                  style: TextStyle(
                    color: _primaryColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionScreen() {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        title: Row(
          children: [
            // App Icon on top-left side
            Container(
              width: 32,
              height: 32,
              margin: EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.white.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(7),
                child: Image.asset(
                  "assets/icon/app_icon.jpeg",
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    // Fallback if image fails to load
                    return Container(
                      color: Color(0xFF0F766E),
                      child: Icon(
                        Icons.medical_services,
                        size: 18,
                        color: Colors.white,
                      ),
                    );
                  },
                ),
              ),
            ),
            Text(
              "Voice Guardian",
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        centerTitle: false, // Changed to false for left alignment
        backgroundColor: _cardColor,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      _primaryColor.withOpacity(0.1),
                      _accentColor.withOpacity(0.1),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.mic_off_rounded,
                  size: 48,
                  color: _warningColor,
                ),
              ),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  "Microphone Access Required",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: _textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  "Voice Guardian needs microphone permission to listen for emergency voice commands.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: _textSecondary,
                    height: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              GestureDetector(
                onTapDown: (_) => _buttonAnimationController.forward(),
                onTapUp: (_) => _buttonAnimationController.reverse(),
                onTapCancel: () => _buttonAnimationController.reverse(),
                onTap: _initializeVoiceGuardian,
                child: AnimatedBuilder(
                  animation: _buttonAnimationController,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _buttonScaleAnimation.value,
                      child: child,
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 16,
                      horizontal: 32,
                    ),
                    decoration: BoxDecoration(
                      gradient: _activeGradient,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: _primaryColor.withOpacity(0.3),
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.mic_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          "Grant Permission",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (widget.onRetry != null) ...[
                const SizedBox(height: 16),
                TextButton(
                  onPressed: widget.onRetry,
                  style: TextButton.styleFrom(
                    foregroundColor: _primaryColor,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 12,
                    ),
                  ),
                  child: Text(
                    "Restart Voice Guardian",
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    bool isRestored =
        widget.sensorService.isVoiceGuardianEnabled &&
        _isGuardianActive &&
        _status.contains("Restoring");

    return Container(
      height: 220,
      decoration: BoxDecoration(
        gradient: _isGuardianActive
            ? LinearGradient(
                colors: [
                  _primaryColor.withOpacity(0.08),
                  _accentColor.withOpacity(0.08),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : LinearGradient(
                colors: [const Color(0xFFF1F5F9), const Color(0xFFF8FAFC)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: _isGuardianActive
              ? _primaryColor.withOpacity(0.2)
              : _borderColor,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Background pattern
          Positioned(
            right: -50,
            top: -50,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _isGuardianActive
                    ? _primaryColor.withOpacity(0.03)
                    : _borderColor.withOpacity(0.3),
              ),
            ),
          ),
          Positioned.fill(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Animated status circle - Wrapped in Flexible
                Flexible(
                  flex: 2,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Outer pulse ring
                      if (_isGuardianActive)
                        AnimatedBuilder(
                          animation: _pulseAnimation,
                          builder: (context, child) {
                            return Container(
                              width: 140 * _pulseAnimation.value,
                              height: 140 * _pulseAnimation.value,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _primaryColor.withOpacity(0.1),
                              ),
                            );
                          },
                        ),
                      // Main circle
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: _isGuardianActive
                              ? _activeGradient
                              : LinearGradient(
                                  colors: [
                                    const Color(0xFFCBD5E1),
                                    const Color(0xFF94A3B8),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                          boxShadow: [
                            BoxShadow(
                              color: _isGuardianActive
                                  ? _primaryColor.withOpacity(0.3)
                                  : Colors.grey.withOpacity(0.3),
                              blurRadius: 15,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Icon(
                          _isGuardianActive
                              ? Icons.shield_rounded
                              : Icons.shield_outlined,
                          size: 40,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Status text - Wrapped in Flexible
                Flexible(
                  flex: 3,
                  child: SizedBox(
                    width: MediaQuery.of(context).size.width * 0.7,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        FittedBox(
                          child: Text(
                            _isGuardianActive
                                ? "ACTIVE PROTECTION"
                                : "STANDBY MODE",
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: _isGuardianActive
                                  ? _primaryColor
                                  : _textSecondary,
                              letterSpacing: 1.5,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: Text(
                            _status,
                            style: TextStyle(
                              fontSize: 14,
                              color: _isGuardianActive
                                  ? _textPrimary
                                  : _textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: _isGuardianActive
                                ? Colors.orange.withOpacity(0.1)
                                : Colors.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: FittedBox(
                            child: Text(
                              _isGuardianActive
                                  ? "Noise Monitoring: PAUSED"
                                  : "Noise Monitoring: ACTIVE",
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: _isGuardianActive
                                    ? Colors.orange
                                    : Colors.green,
                              ),
                            ),
                          ),
                        ),
                        if (isRestored) ...[
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: _successColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: FittedBox(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.restore_rounded,
                                    size: 10,
                                    color: _successColor,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    "Saved state restored",
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: _successColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader({
    required String title,
    required String subtitle,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: _textPrimary,
            letterSpacing: 0.5,
          ),
          maxLines: 1,
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: TextStyle(fontSize: 12, color: _textSecondary),
          maxLines: 1,
        ),
      ],
    );
  }

  Widget _buildControlCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Widget trailing,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _borderColor, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: _primaryColor, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: _textPrimary,
                  ),
                  maxLines: 1,
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 13, color: _textSecondary),
                  maxLines: 2,
                ),
                const SizedBox(height: 4),
                if (_isGuardianActive)
                  Row(
                    children: [
                      Icon(Icons.save_rounded, size: 10, color: _successColor),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          "State saved across app restarts",
                          style: TextStyle(
                            fontSize: 11,
                            color: _successColor,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          trailing,
        ],
      ),
    );
  }

  Widget _buildToggleSwitch() {
    return Transform.scale(
      scale: 1.2,
      child: Switch.adaptive(
        value: _isGuardianActive,
        onChanged: _toggleGuardian,
        activeColor: _primaryColor,
        activeTrackColor: _primaryColor.withOpacity(0.5),
        inactiveThumbColor: const Color(0xFFCBD5E1),
        inactiveTrackColor: const Color(0xFFE2E8F0),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }

  Widget _buildTrustedVoiceRecorder() {
    return GestureDetector(
      onLongPressStart: (_) async {
        setState(() => _isRecording = true);
        await widget.sensorService.pauseForTrustedRecording();
        await _guardian.startRecordingTrustedVoice();
        HapticFeedback.mediumImpact();
        _pulseController.repeat(reverse: true);
      },
      onLongPressEnd: (_) async {
        setState(() => _isRecording = false);
        await _guardian.stopRecordingTrustedVoice();
        await widget.sensorService.resumeAfterTrustedRecording();
        HapticFeedback.mediumImpact();
        _pulseController.stop();
        _pulseController.reset();

        // Show success message
        _showStatusToast(
          "Voice Recording Saved",
          "Calming message recorded successfully",
          Icons.check_circle_rounded,
          _successColor,
        );

        widget.sensorService.logEvent("TRUSTED_VOICE_RECORDED", {
          "timestamp": DateTime.now().millisecondsSinceEpoch,
          "voiceGuardianActive": _isGuardianActive,
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _isRecording ? _alertColor : _cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _isRecording ? _alertColor : _borderColor,
            width: _isRecording ? 2 : 1.5,
          ),
          boxShadow: _isRecording
              ? [
                  BoxShadow(
                    color: _alertColor.withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 5),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _isRecording
                    ? Colors.white.withOpacity(0.2)
                    : _primaryColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _isRecording
                    ? Icons.mic_rounded
                    : Icons.record_voice_over_rounded,
                color: _isRecording ? Colors.white : _primaryColor,
                size: 22,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _isRecording ? "Recording..." : "Trusted Voice Setup",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: _isRecording ? Colors.white : _textPrimary,
                    ),
                    maxLines: 1,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _isRecording
                        ? "Release to save calming message"
                        : "Hold to record trusted voice",
                    style: TextStyle(
                      fontSize: 13,
                      color: _isRecording
                          ? Colors.white.withOpacity(0.9)
                          : _textSecondary,
                    ),
                    maxLines: 2,
                  ),
                ],
              ),
            ),
            if (_isRecording)
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(Colors.white),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTriggerList() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _borderColor, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Add Emergency Trigger",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: _textPrimary,
            ),
            maxLines: 1,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: _bgColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _borderColor),
                  ),
                  child: TextField(
                    controller: _triggerController,
                    decoration: const InputDecoration(
                      hintText: "Enter trigger phrase...",
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      isDense: true,
                    ),
                    style: TextStyle(fontSize: 14, color: _textPrimary),
                    onSubmitted: (_) => _addNewTrigger(),
                    maxLines: 1,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTapDown: (_) => _buttonAnimationController.forward(),
                onTapUp: (_) => _buttonAnimationController.reverse(),
                onTapCancel: () => _buttonAnimationController.reverse(),
                onTap: _addNewTrigger,
                child: AnimatedBuilder(
                  animation: _buttonAnimationController,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _buttonScaleAnimation.value,
                      child: child,
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: _activeGradient,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: _primaryColor.withOpacity(0.2),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.add_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            "Current Triggers",
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: _textPrimary,
            ),
            maxLines: 1,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _guardian.currentTriggers.map((t) {
              return Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.4,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: _bgColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _borderColor),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Expanded(
                      child: Text(
                        t,
                        style: TextStyle(
                          fontSize: 13,
                          color: _textPrimary,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                      ),
                    ),
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: () {
                        _guardian.removeTrigger(t);
                        setState(() {});
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text("Removed trigger: $t"),
                            backgroundColor: _primaryColor,
                            behavior: SnackBarBehavior.floating,
                            duration: const Duration(seconds: 1),
                          ),
                        );
                      },
                      child: Icon(
                        Icons.close_rounded,
                        size: 14,
                        color: _textSecondary,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    // Dispose animation controllers in reverse order
    _buttonAnimationController.dispose();
    _pulseController.dispose();
    _triggerController.dispose();
    _countdownSubscription?.cancel();

    if (_isGuardianActive != widget.sensorService.isVoiceGuardianEnabled) {
      widget.sensorService.setVoiceGuardianState(_isGuardianActive);
    }

    super.dispose();
  }
}
