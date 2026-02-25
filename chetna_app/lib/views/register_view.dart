// register_view.dart - Updated to match app's medical design system
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import '../sensor_service.dart';

class RegisterPage extends StatefulWidget {
  final SensorService sensorService;
  const RegisterPage({super.key, required this.sensorService});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage>
    with TickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _caregiverController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;

  // Updated to light blue colors
  static const Color _primaryColor = Color(0xFF3B82F6);
  static const Color _accentColor = Color(0xFF60A5FA);
  static const Color _bgColor = Colors.white;
  static const Color _cardColor = Colors.white;
  static const Color _alertColor = Color(0xFFEF4444);
  static const Color _successColor = Color(0xFF10B981);
  static const Color _warningColor = Color(0xFFF59E0B);
  static const Color _textPrimary = Color(0xFF1E293B);
  static const Color _textSecondary = Color(0xFF64748B);
  static const Color _borderColor = Color(0xFFE2E8F0);

  final Gradient _activeGradient = const LinearGradient(
    colors: [Color(0xFF3B82F6), Color(0xFF60A5FA)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  final List<bool> _stepCompletion = [false, false, false, false, false];
  int _currentStep = 0;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _updateStepCompletion(int step, bool isCompleted) {
    if (mounted) {
      setState(() {
        _stepCompletion[step] = isCompleted;
        _currentStep = step;
      });
    }
  }

  Future<void> _handleRegister() async {
    if (_nameController.text.isEmpty ||
        _emailController.text.isEmpty ||
        _passwordController.text.isEmpty) {
      _showToast(
        "Please fill in all required fields (Name, Email, Password)",
        _alertColor,
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      await widget.sensorService.saveUserProfile(
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        caregiverPhone: _caregiverController.text.trim(),
      );

      if (mounted) {
        _showToast(
          "Account created successfully! Welcome to Chetna",
          _successColor,
        );

        await Future.delayed(const Duration(seconds: 1));
        Navigator.pop(context);
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        _showToast(
          "Registration Error: ${e.message ?? 'Authentication failed'}",
          _alertColor,
        );
      }
    } catch (e) {
      if (mounted) {
        _showToast("System Error: Please try again", _alertColor);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showToast(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
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
                child: Icon(
                  color == _alertColor
                      ? Icons.warning_amber
                      : Icons.check_circle,
                  color: color,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      color == _alertColor ? "Alert" : "Success",
                      style: TextStyle(
                        color: _textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      msg,
                      style: TextStyle(color: _textSecondary, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: _cardColor,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 20,
            color: _textPrimary,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Create Account",
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: _textPrimary,
          ),
        ),
        centerTitle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
        ),
      ),
      body: AnimationLimiter(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: AnimationConfiguration.toStaggeredList(
                duration: const Duration(milliseconds: 400),
                childAnimationBuilder: (widget) => SlideAnimation(
                  verticalOffset: 30.0,
                  child: FadeInAnimation(child: widget),
                ),
                children: [
                  _buildHeader(),
                  const SizedBox(height: 24),
                  _buildRegistrationProgress(),
                  const SizedBox(height: 24),
                  _buildRegistrationFormCard(),
                  const SizedBox(height: 24),
                  _buildSecurityAssurance(),
                  const SizedBox(height: 24),
                  _buildRegistrationButton(),
                  const SizedBox(height: 20),
                  _buildTermsAndPrivacy(),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            ScaleTransition(
              scale: _pulseAnimation,
              child: Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _primaryColor.withOpacity(0.15),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _primaryColor.withOpacity(0.2),
                      blurRadius: 20,
                      spreadRadius: 3,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(25),
                  child: Image.asset(
                    "assets/icon/app_icon.jpeg",
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        decoration: BoxDecoration(
                          gradient: _activeGradient,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.person_add_alt_1_rounded,
                          size: 24,
                          color: Colors.white,
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "New Account Setup",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: _textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Join the Chetna Health Monitoring Network",
                    style: TextStyle(
                      fontSize: 13,
                      color: _textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _primaryColor.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _primaryColor.withOpacity(0.1)),
          ),
          child: Row(
            children: [
              Icon(Icons.medical_information, size: 16, color: _primaryColor),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  "For healthcare providers, caregivers, and family members",
                  style: TextStyle(
                    fontSize: 12,
                    color: _textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRegistrationProgress() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _borderColor, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 30,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Setup Steps",
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: _textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          _buildProgressStep(0, "Personal Details", Icons.person_outline),
          _buildProgressStep(1, "Account Credentials", Icons.email_outlined),
          _buildProgressStep(2, "Security Setup", Icons.lock_outline),
          _buildProgressStep(3, "Contact Information", Icons.phone_outlined),
          _buildProgressStep(
            4,
            "Emergency Contacts",
            Icons.contact_emergency_outlined,
          ),
        ],
      ),
    );
  }

  Widget _buildProgressStep(int step, String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _stepCompletion[step]
                  ? _successColor.withOpacity(0.1)
                  : (step <= _currentStep
                        ? _primaryColor.withOpacity(0.1)
                        : Color(0xFFF8FAFC)),
              shape: BoxShape.circle,
              border: Border.all(
                color: _stepCompletion[step]
                    ? _successColor
                    : (step <= _currentStep ? _primaryColor : _borderColor),
                width: 1.5,
              ),
            ),
            child: Center(
              child: _stepCompletion[step]
                  ? Icon(Icons.check, size: 16, color: _successColor)
                  : Icon(
                      icon,
                      size: 16,
                      color: step <= _currentStep
                          ? _primaryColor
                          : _textSecondary,
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _stepCompletion[step]
                    ? _successColor
                    : (step <= _currentStep ? _textPrimary : _textSecondary),
              ),
            ),
          ),
          if (step == _currentStep && !_stepCompletion[step])
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: _primaryColor,
                shape: BoxShape.circle,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRegistrationFormCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _borderColor, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Registration Form",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: _textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            "All fields are required for monitoring setup",
            style: TextStyle(fontSize: 13, color: _textSecondary),
          ),
          const SizedBox(height: 24),

          // Name Field
          _buildTextField(
            label: "Full Name",
            hint: "John A. Smith",
            controller: _nameController,
            icon: Icons.person_outline_rounded,
            onChanged: (value) => _updateStepCompletion(0, value.isNotEmpty),
          ),
          const SizedBox(height: 20),

          // Email Field
          _buildTextField(
            label: "Email Address",
            hint: "your.email@example.com",
            controller: _emailController,
            icon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
            onChanged: (value) => _updateStepCompletion(1, value.isNotEmpty),
          ),
          const SizedBox(height: 20),

          // Password Field
          _buildTextField(
            label: "Password",
            hint: "Create secure password",
            controller: _passwordController,
            icon: Icons.lock_outline_rounded,
            isPassword: true,
            obscureText: _obscurePassword,
            onChanged: (value) => _updateStepCompletion(2, value.isNotEmpty),
            onToggleVisibility: () =>
                setState(() => _obscurePassword = !_obscurePassword),
          ),
          const SizedBox(height: 20),

          // Phone Field
          _buildTextField(
            label: "Phone Number",
            hint: "+91 12345 67890",
            controller: _phoneController,
            icon: Icons.phone_android_rounded,
            keyboardType: TextInputType.phone,
            onChanged: (value) => _updateStepCompletion(3, value.isNotEmpty),
          ),
          const SizedBox(height: 20),

          // Emergency Contact Field
          _buildTextField(
            label: "Emergency Contact",
            hint: "Caregiver phone number",
            controller: _caregiverController,
            icon: Icons.contact_emergency_rounded,
            keyboardType: TextInputType.phone,
            onChanged: (value) => _updateStepCompletion(4, value.isNotEmpty),
          ),

          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _alertColor.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _alertColor.withOpacity(0.1)),
            ),
            child: Row(
              children: [
                Icon(Icons.warning_amber_rounded, size: 16, color: _alertColor),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    "Emergency contact receives SMS alerts for falls and SOS triggers",
                    style: TextStyle(
                      fontSize: 12,
                      color: _textSecondary,
                      fontWeight: FontWeight.w500,
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

  Widget _buildTextField({
    required String label,
    required String hint,
    required TextEditingController controller,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool isPassword = false,
    bool obscureText = false,
    ValueChanged<String>? onChanged,
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
          height: 48,
          decoration: BoxDecoration(
            color: Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _borderColor, width: 1.5),
          ),
          child: Row(
            children: [
              const SizedBox(width: 14),
              Icon(icon, size: 18, color: _accentColor),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: controller,
                  keyboardType: keyboardType,
                  obscureText: obscureText,
                  onChanged: onChanged,
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
                    color: _accentColor,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  constraints: const BoxConstraints(),
                ),
              const SizedBox(width: 14),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSecurityAssurance() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _primaryColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _primaryColor.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.security_rounded,
                  size: 20,
                  color: _primaryColor,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                "SECURITY & PRIVACY",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: _primaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildSecurityFeature(
            "End-to-end encrypted data transmission",
            Icons.lock_rounded,
          ),
          _buildSecurityFeature(
            "HIPAA compliant architecture",
            Icons.health_and_safety_rounded,
          ),
          _buildSecurityFeature(
            "Secure data storage",
            Icons.verified_user_rounded,
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _successColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.verified_rounded, size: 16, color: _successColor),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    "All health data is protected and encrypted",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _successColor,
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

  Widget _buildSecurityFeature(String text, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 14, color: _primaryColor),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                color: _textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRegistrationButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _handleRegister,
        style: ElevatedButton.styleFrom(
          backgroundColor: _primaryColor,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 0,
          shadowColor: _primaryColor.withOpacity(0.3),
        ),
        child: _isLoading
            ? SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.app_registration_rounded, size: 20),
                  const SizedBox(width: 10),
                  Text(
                    "Create Account",
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildTermsAndPrivacy() {
    return Column(
      children: [
        Divider(color: _borderColor),
        const SizedBox(height: 16),
        RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            children: [
              TextSpan(
                text: "By creating an account, you agree to our ",
                style: TextStyle(fontSize: 11, color: _textSecondary),
              ),
              TextSpan(
                text: "Terms",
                style: TextStyle(
                  fontSize: 11,
                  color: _primaryColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
              TextSpan(
                text: " and ",
                style: TextStyle(fontSize: 11, color: _textSecondary),
              ),
              TextSpan(
                text: "Privacy Policy",
                style: TextStyle(
                  fontSize: 11,
                  color: _primaryColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            _buildFeatureBadge("Fall Detection"),
            _buildFeatureBadge("Voice Guardian"),
            _buildFeatureBadge("AI Monitoring"),
            _buildFeatureBadge("24/7 Support"),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          "© 2024 Chetna Health Systems",
          style: TextStyle(
            fontSize: 11,
            color: _textSecondary.withOpacity(0.6),
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildFeatureBadge(String feature) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _primaryColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _primaryColor.withOpacity(0.1), width: 1),
      ),
      child: Text(
        feature,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: _primaryColor,
        ),
      ),
    );
  }
}
