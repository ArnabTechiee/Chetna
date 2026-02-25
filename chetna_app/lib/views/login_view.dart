// login_view.dart - Professional Medical AI Login with Medical Features
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'register_view.dart';
import '../sensor_service.dart';

class LoginPage extends StatefulWidget {
  final SensorService sensorService;
  const LoginPage({super.key, required this.sensorService});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with TickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  int _currentFeature = 0;
  late AnimationController _featureController;
  late Animation<double> _featureAnimation;

  // Professional Color Palette
  static const Color _primaryColor = Color(0xFF2563EB);
  static const Color _bgColor = Color(0xFFF8FAFC);
  static const Color _cardColor = Colors.white;
  static const Color _textPrimary = Color(0xFF1E293B);
  static const Color _textSecondary = Color(0xFF64748B);
  static const Color _borderColor = Color(0xFFE2E8F0);
  static const Color _feature1 = Color(0xFF8B5CF6);
  static const Color _feature2 = Color(0xFFF59E0B);
  static const Color _feature3 = Color(0xFF10B981);
  static const Color _feature4 = Color(0xFF3B82F6);

  final List<Map<String, dynamic>> _features = [
    {
      'icon': Icons.medication_rounded,
      'title': 'Vital Monitoring AI',
      'color': Color(0xFF8B5CF6),
      'desc': 'Smart health tracking',
    },
    {
      'icon': Icons.thermostat_rounded,
      'title': 'Environmental AI',
      'color': Color(0xFFF59E0B),
      'desc': 'Smart environment analysis',
    },
    {
      'icon': Icons.health_and_safety_rounded,
      'title': 'Emergency Response',
      'color': Color(0xFF10B981),
      'desc': '24/7 medical alert system',
    },
    {
      'icon': Icons.analytics_rounded,
      'title': 'Health Analytics',
      'color': Color(0xFF3B82F6),
      'desc': 'Detailed health insights',
    },
  ];

  // Medical stats widgets
  final List<Map<String, dynamic>> _medicalStats = [
    {
      'icon': Icons.favorite_rounded,
      'value': '99.8%',
      'label': 'Accuracy',
      'color': Color(0xFFEF4444),
    },
    {
      'icon': Icons.timer_rounded,
      'value': '24/7',
      'label': 'Monitoring',
      'color': Color(0xFF3B82F6),
    },
    {
      'icon': Icons.security_rounded,
      'value': 'HIPAA',
      'label': 'Compliant',
      'color': Color(0xFF10B981),
    },
  ];

  @override
  void initState() {
    super.initState();
    _featureController = AnimationController(
      duration: const Duration(seconds: 6),
      vsync: this,
    )..repeat();

    _featureAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _featureController, curve: Curves.easeInOut),
    );

    // Auto-rotate features
    _featureController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() {
          _currentFeature = (_currentFeature + 1) % _features.length;
        });
      }
    });
  }

  @override
  void dispose() {
    _featureController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      _showToast("Please enter your credentials");
      return;
    }

    setState(() => _isLoading = true);

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
    } on FirebaseAuthException catch (e) {
      _showToast("Authentication failed: ${e.message}");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showToast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Column(
              children: [
                // Clean Logo Section
                _buildLogoSection(),
                const SizedBox(height: 32),

                // Medical Stats Row
                _buildMedicalStats(),
                const SizedBox(height: 32),

                // Animated Feature Display
                _buildFeatureDisplay(),
                const SizedBox(height: 32),

                // Simple Login Form
                _buildLoginFormCard(),
                const SizedBox(height: 32),

                // Minimal Footer
                _buildFooter(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Clean Circular Logo with subtle shadow
        Container(
          width: 100,
          height: 100,
          margin: const EdgeInsets.only(bottom: 20),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: _primaryColor.withOpacity(0.15),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: _primaryColor.withOpacity(0.1),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(50),
            child: Image.asset(
              "assets/icon/app_icon.jpeg",
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [_primaryColor, Color(0xFF3B82F6)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Icon(
                      Icons.health_and_safety_rounded,
                      size: 42,
                      color: Colors.white,
                    ),
                  ),
                );
              },
            ),
          ),
        ),

        // App Title
        Text(
          "CHETNA AI",
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: _textPrimary,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          "Intelligent Medical Guardian",
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: _textSecondary,
          ),
        ),
        const SizedBox(height: 8),

        // Security Badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: _primaryColor.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _primaryColor.withOpacity(0.15),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.verified_rounded, size: 14, color: _primaryColor),
              const SizedBox(width: 6),
              Text(
                "Medical Grade Security",
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: _primaryColor,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMedicalStats() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _borderColor, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: _medicalStats.map((stat) {
          final color = stat['color'] as Color;
          return Column(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(stat['icon'] as IconData, color: color, size: 20),
              ),
              const SizedBox(height: 8),
              Text(
                stat['value'] as String,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: _textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                stat['label'] as String,
                style: TextStyle(
                  fontSize: 10,
                  color: _textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildFeatureDisplay() {
    final feature = _features[_currentFeature];
    final color = feature['color'] as Color;

    return GestureDetector(
      onTap: () {
        setState(() {
          _currentFeature = (_currentFeature + 1) % _features.length;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [color.withOpacity(0.08), color.withOpacity(0.03)],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.15), width: 1),
        ),
        child: Row(
          children: [
            // Icon with animation
            AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(feature['icon'] as IconData, color: color, size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    feature['title'] as String,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: _textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    feature['desc'] as String,
                    style: TextStyle(fontSize: 12, color: _textSecondary),
                  ),
                ],
              ),
            ),
            // Progress indicator
            SizedBox(
              width: 24,
              height: 24,
              child: AnimatedBuilder(
                animation: _featureAnimation,
                builder: (context, child) {
                  return CircularProgressIndicator(
                    value: _featureAnimation.value,
                    strokeWidth: 2,
                    color: color,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoginFormCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _borderColor, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Secure Sign In",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: _textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "Access your medical health dashboard",
                style: TextStyle(fontSize: 13, color: _textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 28),

          // Email Field
          _buildTextField(
            label: "Email",
            hint: "your@email.com",
            controller: _emailController,
            icon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 20),

          // Password Field
          _buildTextField(
            label: "Password",
            hint: "••••••••",
            controller: _passwordController,
            icon: Icons.lock_outline_rounded,
            isPassword: true,
            obscureText: _obscurePassword,
            onToggleVisibility: () =>
                setState(() => _obscurePassword = !_obscurePassword),
          ),
          const SizedBox(height: 24),

          // Enhanced Login Button
          Container(
            width: double.infinity,
            height: 56,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: _primaryColor.withOpacity(0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 4),
                  spreadRadius: 0,
                ),
              ],
            ),
            child: ElevatedButton(
              onPressed: _isLoading ? null : _handleLogin,
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 24),
              ),
              child: _isLoading
                  ? SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        color: Colors.white,
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.login_rounded,
                            size: 18,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          "Sign In to Dashboard",
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 20),

          // Register Link
          Center(
            child: TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        RegisterPage(sensorService: widget.sensorService),
                  ),
                );
              },
              style: TextButton.styleFrom(
                foregroundColor: _primaryColor,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: _primaryColor.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _primaryColor.withOpacity(0.1),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.person_add_alt_1_rounded,
                      size: 16,
                      color: _primaryColor,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      "Create new account",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _primaryColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required String hint,
    required TextEditingController controller,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool isPassword = false,
    bool obscureText = false,
    VoidCallback? onToggleVisibility,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: _textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 50,
          decoration: BoxDecoration(
            color: _bgColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _borderColor, width: 1.5),
          ),
          child: Row(
            children: [
              const SizedBox(width: 16),
              Icon(icon, size: 18, color: _primaryColor),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: controller,
                  keyboardType: keyboardType,
                  obscureText: obscureText,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: _textPrimary,
                  ),
                  decoration: InputDecoration(
                    hintText: hint,
                    hintStyle: TextStyle(
                      color: Colors.grey.shade400,
                      fontWeight: FontWeight.w400,
                    ),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
              if (isPassword && onToggleVisibility != null)
                IconButton(
                  onPressed: onToggleVisibility,
                  icon: Icon(
                    obscureText
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    size: 18,
                    color: _primaryColor,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  constraints: const BoxConstraints(),
                ),
              const SizedBox(width: 16),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFooter() {
    return Column(
      children: [
        // Feature Dots Indicator
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(_features.length, (index) {
            return Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _currentFeature == index ? _primaryColor : _borderColor,
              ),
            );
          }),
        ),
        const SizedBox(height: 16),

        Divider(color: _borderColor, height: 20, thickness: 1),
        const SizedBox(height: 16),

        Column(
          children: [
            Text(
              "For medical emergencies: SOS button in dashboard",
              style: TextStyle(
                fontSize: 11,
                color: _feature1,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              "© 2024 Chetna AI Medical Systems",
              style: TextStyle(
                fontSize: 10,
                color: _textSecondary.withOpacity(0.6),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ],
    );
  }
}
