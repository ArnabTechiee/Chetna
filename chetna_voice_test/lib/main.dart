import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'voice_guardian_service.dart';

void main() {
  runApp(
    const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: VoiceGuardianPage(),
    ),
  );
}

class VoiceGuardianPage extends StatefulWidget {
  const VoiceGuardianPage({super.key});

  @override
  State<VoiceGuardianPage> createState() => _VoiceGuardianPageState();
}

class _VoiceGuardianPageState extends State<VoiceGuardianPage>
    with SingleTickerProviderStateMixin {
  final VoiceGuardianService _guardian = VoiceGuardianService();
  final TextEditingController _triggerController = TextEditingController();

  String _status = "Initializing System...";
  bool _isRecording = false;
  bool _isGuardianActive = false;

  // Animation for the "Listening" pulse
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _initSystem();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _triggerController.dispose();
    super.dispose();
  }

  Future<void> _initSystem() async {
    await [
      Permission.microphone,
      Permission.storage,
      Permission.speech,
      Permission.notification,
    ].request();

    await _guardian.initialize();

    _guardian.onStatusChanged = (msg) {
      if (!mounted) return;
      setState(() => _status = msg);

      if (msg.contains("Heard:")) {
        // Just transcribed text, don't change state logic
      } else if (msg.contains("KEYWORD")) {
        _showCalmingDialog();
      } else if (msg.contains("SOS")) {
        // Handled by onEscalationTriggered usually, but good for logs
      }
    };

    _guardian.onEscalationTriggered = _showSOSDialog;
  }

  void _toggleGuardian(bool value) {
    setState(() => _isGuardianActive = value);
    if (value) {
      _guardian.startListening();
      _pulseController.repeat(reverse: true);
    } else {
      _guardian.stopListening();
      _pulseController.stop();
      _pulseController.reset();
    }
  }

  void _addNewTrigger() {
    if (_triggerController.text.trim().isNotEmpty) {
      _guardian.addTrigger(_triggerController.text.trim());
      _triggerController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("New Trigger Added Successfully"),
          backgroundColor: Color(0xFF00796B),
        ),
      );
    }
  }

  // UI Components
  void _showCalmingDialog() {
    // We can show a non-dismissible overlay here if we want,
    // but the guardian service handles the audio playback.
  }

  void _showSOSDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFFFFEBEE),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: const [
            Icon(Icons.warning_amber_rounded, color: Colors.red, size: 30),
            SizedBox(width: 10),
            Text(
              "SOS ACTIVATED",
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: const Text(
          "Emergency protocols initiated.\n\n• Siren Sounding\n• SMS Sent to Caregiver\n• Location Shared",
          style: TextStyle(fontSize: 16),
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00796B),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () {
                Navigator.pop(context);
                _guardian.cancelAlert();
              },
              child: const Text(
                "I AM SAFE - CANCEL",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text(
          "Voice Guardian",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. STATUS CARD
            _buildStatusCard(),

            const SizedBox(height: 24),

            // 2. TRUSTED VOICE SECTION
            _buildSectionHeader("1. Trusted Voice Setup"),
            const SizedBox(height: 12),
            _buildVoiceRecorder(),

            const SizedBox(height: 24),

            // 3. TRIGGER WORDS SECTION
            _buildSectionHeader("2. Custom Triggers"),
            const SizedBox(height: 12),
            _buildTriggerInput(),

            const SizedBox(height: 24),

            // 4. ACTIVATION TOGGLE
            _buildSectionHeader("3. Protection Status"),
            const SizedBox(height: 12),
            _buildActivationSwitch(),

            const SizedBox(height: 30),
            const Text(
              "Medical Grade NLP • Zero-Touch Activation",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _isGuardianActive ? const Color(0xFFE0F2F1) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _isGuardianActive
              ? const Color(0xFF00796B)
              : Colors.grey.shade300,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          ScaleTransition(
            scale: _pulseAnimation,
            child: Icon(
              _isGuardianActive ? Icons.mic : Icons.mic_off,
              size: 40,
              color: _isGuardianActive ? const Color(0xFF00796B) : Colors.grey,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _status,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: _isGuardianActive
                  ? const Color(0xFF004D40)
                  : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVoiceRecorder() {
    return GestureDetector(
      onLongPressStart: (_) async {
        setState(() => _isRecording = true);
        await _guardian.startRecordingTrustedVoice();
      },
      onLongPressEnd: (_) async {
        setState(() => _isRecording = false);
        await _guardian.stopRecordingTrustedVoice();
      },
      child: Container(
        height: 70,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: _isRecording
                ? [const Color(0xFFE53935), const Color(0xFFD32F2F)]
                : [const Color(0xFF26A69A), const Color(0xFF00796B)],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: (_isRecording ? Colors.red : Colors.teal).withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _isRecording ? Icons.fiber_manual_record : Icons.mic,
              color: Colors.white,
            ),
            const SizedBox(width: 12),
            Text(
              _isRecording ? "Release to Save" : "Hold to Record Trusted Voice",
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTriggerInput() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _triggerController,
              decoration: const InputDecoration(
                hintText: "Add new trigger (e.g. 'Papa')",
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 16),
              ),
            ),
          ),
          Container(
            margin: const EdgeInsets.only(right: 4),
            decoration: const BoxDecoration(
              color: Color(0xFF00796B),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(Icons.add, color: Colors.white),
              onPressed: _addNewTrigger,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivationSwitch() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: SwitchListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        activeColor: const Color(0xFF00796B),
        title: const Text(
          "System Active",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: const Text("Listen for triggers in background"),
        value: _isGuardianActive,
        onChanged: _toggleGuardian,
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title.toUpperCase(),
      style: const TextStyle(
        color: Color(0xFF757575),
        fontWeight: FontWeight.w700,
        fontSize: 12,
        letterSpacing: 1.0,
      ),
    );
  }
}
