import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'views/dashboard_view.dart';
import 'views/ai_view.dart';
import 'views/auth_wrapper.dart';
import 'voice/voice_guardian_view.dart';
import 'sensor_service.dart';
import 'voice/voice_guardian_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const ChetnaApp());
}

class ChetnaApp extends StatefulWidget {
  const ChetnaApp({super.key});

  @override
  State<ChetnaApp> createState() => _ChetnaAppState();
}

class _ChetnaAppState extends State<ChetnaApp> {
  late SensorService sensors;

  @override
  void initState() {
    super.initState();
    sensors = SensorService();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Chetna Health Shield',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2563EB),
          brightness: Brightness.light,
          primary: const Color(0xFF2563EB),
          secondary: const Color(0xFF10B981),
          tertiary: const Color(0xFF8B5CF6),
        ),
        fontFamily: 'Inter',
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            color: Color(0xFF1E293B),
            fontSize: 18,
            fontWeight: FontWeight.w600,
            fontFamily: 'Inter',
          ),
        ),
        cardTheme: CardThemeData(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          color: Colors.white,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
        ),
      ),
      home: AuthWrapper(sensors: sensors),
    );
  }
}

class ChetnaDashboardWrapper extends StatefulWidget {
  final SensorService sensors;
  const ChetnaDashboardWrapper({super.key, required this.sensors});

  @override
  State<ChetnaDashboardWrapper> createState() => _ChetnaDashboardWrapperState();
}

class _ChetnaDashboardWrapperState extends State<ChetnaDashboardWrapper> {
  int _currentIndex = 0;
  late VoiceGuardianService voiceGuardian;
  bool _isVoiceGuardianReady = false;
  bool _isInitializing = true;
  String _initializationStatus = "Starting up...";

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    try {
      setState(() {
        _initializationStatus = "Initializing Sensor Service...";
      });

      // 1. Initialize Sensors FIRST
      await widget.sensors.start();

      setState(() {
        _initializationStatus =
            "Sensor Service ready. Initializing Voice Guardian...";
      });

      // 2. Pass initialized sensors to Voice Guardian
      voiceGuardian = VoiceGuardianService(sensorService: widget.sensors);

      setState(() {
        _initializationStatus = "Requesting microphone permissions...";
      });

      bool voiceInitialized = await voiceGuardian.initialize();

      if (voiceInitialized && mounted) {
        setState(() {
          _isVoiceGuardianReady = true;
          _isInitializing = false;
          _initializationStatus = "All services ready!";
        });

        // ✅ IMPORTANT CHANGE: REMOVED automatic startListening() call
        // The VoiceGuardianService.initialize() method now handles
        // auto-start based on the saved preference in SensorService.
        // If we call it here unconditionally, it overrides the 'OFF' setting.

        // ❌ REMOVED: voiceGuardian.startListening();
        // ✅ REASON: initialize() now checks sensorService.isVoiceGuardianEnabled
        // and will auto-start ONLY if the user had previously turned it ON.

        debugPrint(
          "✅ Voice Guardian initialized. Listening state depends on saved preference.",
        );
      } else {
        setState(() {
          _isInitializing = false;
          _initializationStatus = "Voice Guardian initialization failed";
        });

        // Start sensors anyway even if voice fails
        debugPrint(
          "⚠️ Voice Guardian initialization failed, but sensors are running",
        );
      }
    } catch (e) {
      debugPrint("❌ Service initialization error: $e");
      setState(() {
        _isInitializing = false;
        _initializationStatus = "Initialization error: $e";
      });
    }
  }

  void _restartVoiceGuardian() async {
    setState(() {
      _isInitializing = true;
      _initializationStatus = "Restarting Voice Guardian...";
    });

    // Dispose existing instance
    voiceGuardian.dispose();

    // Reinitialize
    voiceGuardian = VoiceGuardianService(sensorService: widget.sensors);
    bool success = await voiceGuardian.initialize();

    setState(() {
      _isVoiceGuardianReady = success;
      _isInitializing = false;
      _initializationStatus = success
          ? "Voice Guardian restarted!"
          : "Failed to restart";
    });

    // ✅ IMPORTANT: Do NOT call startListening() automatically
    // The service will handle its own state based on saved preference
    if (success) {
      debugPrint("✅ Voice Guardian restarted successfully.");
      // The service will auto-start if it was previously enabled
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show loading screen if still initializing
    if (_isInitializing) {
      return _buildInitializationScreen();
    }

    // Show voice guardian loading screen if not ready
    if (_currentIndex == 2 && !_isVoiceGuardianReady) {
      return _buildVoiceGuardianRetryScreen();
    }

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          ChetnaDashboard(sensorService: widget.sensors),
          ChetnaAIView(sensorService: widget.sensors),
          VoiceGuardianView(
            sensorService: widget.sensors,
            voiceService: voiceGuardian,
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() => _currentIndex = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.assessment_outlined),
            selectedIcon: Icon(Icons.assessment),
            label: "Monitor",
          ),
          NavigationDestination(
            icon: Icon(Icons.insights_outlined),
            selectedIcon: Icon(Icons.insights),
            label: "Insights",
          ),
          NavigationDestination(
            icon: Icon(Icons.mic_outlined),
            selectedIcon: Icon(Icons.mic),
            label: "Voice Help",
          ),
        ],
      ),
    );
  }

  Widget _buildInitializationScreen() {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 80,
              height: 80,
              child: CircularProgressIndicator(
                strokeWidth: 4,
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2563EB)),
              ),
            ),
            const SizedBox(height: 30),
            Text(
              "Starting Chetna Shield...",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 15),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Text(
                _initializationStatus,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              "Please wait while we set up all safety systems",
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVoiceGuardianRetryScreen() {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Voice Guardian"),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.mic_off, size: 80, color: Colors.orange),
              const SizedBox(height: 20),
              const Text(
                "Voice Guardian Not Ready",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                "Microphone permissions are required for voice commands.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: _restartVoiceGuardian,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 30,
                    vertical: 15,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  "Try Again",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 15),
              TextButton(
                onPressed: () {
                  setState(() {
                    _currentIndex = 0; // Go back to dashboard
                  });
                },
                child: const Text(
                  "Go to Dashboard",
                  style: TextStyle(color: Colors.blue),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    voiceGuardian.dispose();
    super.dispose();
  }
}
