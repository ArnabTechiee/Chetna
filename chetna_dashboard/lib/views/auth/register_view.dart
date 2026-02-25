// views/auth/register_view.dart - A++ PROFESSIONAL VERSION
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../utils/constants.dart';

class MedicalRegisterView extends StatefulWidget {
  const MedicalRegisterView({super.key});

  @override
  State<MedicalRegisterView> createState() => _MedicalRegisterViewState();
}

class _MedicalRegisterViewState extends State<MedicalRegisterView>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _licenseController = TextEditingController();
  final _hospitalController = TextEditingController();
  final _phoneController = TextEditingController();

  String? _selectedSpecialty;
  final List<String> _specialties = [
    'Geriatric Medicine',
    'Emergency Medicine',
    'Neurology',
    'Cardiology',
    'General Practice',
    'Rehabilitation',
    'Psychiatry',
    'Nursing',
    'Physical Therapy',
    'Occupational Therapy',
    'Gerontology',
    'Family Medicine',
  ];

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  int _currentStep = 0;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _slideAnimation = Tween<Offset>(
      begin: Offset(1.0, 0.0),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          return Opacity(
            opacity: _fadeAnimation.value,
            child: SlideTransition(
              position: _slideAnimation,
              child: Row(
                children: [
                  // Left Side - Registration Info
                  if (size.width > 800)
                    Expanded(
                      flex: 5,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              AppColors.primary.withOpacity(0.1),
                              AppColors.primary.withOpacity(0.03),
                              Colors.white,
                            ],
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 60,
                          vertical: 40,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Back Button
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              style: TextButton.styleFrom(
                                foregroundColor: AppColors.textSecondary,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.arrow_back_ios_new_rounded,
                                    size: 16,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'Back to Login',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 40),

                            // Title
                            ShaderMask(
                              shaderCallback:
                                  (bounds) => LinearGradient(
                                    colors: [
                                      AppColors.primary,
                                      Color(0xFF4A6FA5),
                                    ],
                                    begin: Alignment.centerLeft,
                                    end: Alignment.centerRight,
                                  ).createShader(bounds),
                              child: Text(
                                'Join Our Medical\nNetwork',
                                style: TextStyle(
                                  fontSize: 44,
                                  fontWeight: FontWeight.w900,
                                  height: 1.1,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),

                            // Description
                            Text(
                              'Register as a medical professional to access real-time patient monitoring, emergency alerts, and AI-powered health analytics for elderly care.',
                              style: TextStyle(
                                fontSize: 18,
                                color: AppColors.textSecondary,
                                height: 1.6,
                              ),
                            ),
                            const SizedBox(height: 50),

                            // Requirements Grid
                            _buildRequirementsGrid(),
                            const SizedBox(height: 50),

                            // Verification Info
                            Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    AppColors.primary.withOpacity(0.05),
                                    AppColors.primary.withOpacity(0.02),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: AppColors.primary.withOpacity(0.1),
                                  width: 1.5,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.verified_rounded,
                                    size: 32,
                                    color: AppColors.primary,
                                  ),
                                  const SizedBox(width: 20),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Verification Process',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          'Your medical credentials will be verified within 24-48 hours.',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Right Side - Registration Form
                  Expanded(
                    flex: size.width > 800 ? 4 : 5,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        boxShadow:
                            size.width <= 800
                                ? null
                                : [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 40,
                                    offset: Offset(-10, 0),
                                  ),
                                ],
                      ),
                      child: SingleChildScrollView(
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: size.width > 800 ? 60 : 40,
                            vertical: 40,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Mobile Back Button
                              if (size.width <= 800)
                                IconButton(
                                  onPressed: () => Navigator.pop(context),
                                  icon: Icon(
                                    Icons.arrow_back_ios_new_rounded,
                                    size: 20,
                                  ),
                                  color: AppColors.textSecondary,
                                ),
                              const SizedBox(height: 20),

                              // Progress Steps
                              _buildEnhancedProgressSteps(),
                              const SizedBox(height: 40),

                              // Form
                              Form(
                                key: _formKey,
                                child:
                                    _currentStep == 0
                                        ? _buildEnhancedPersonalInfoStep()
                                        : _buildEnhancedProfessionalInfoStep(),
                              ),

                              const SizedBox(height: 40),

                              // Navigation Buttons
                              _buildEnhancedNavigationButtons(),

                              const SizedBox(height: 40),

                              // Terms & Privacy
                              Container(
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: AppColors.border,
                                    width: 1.5,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.03),
                                      blurRadius: 10,
                                      offset: Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.shield_outlined,
                                          size: 22,
                                          color: AppColors.primary,
                                        ),
                                        const SizedBox(width: 12),
                                        Text(
                                          'HIPAA Compliance & Data Security',
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      'By registering, you agree to maintain patient confidentiality as per HIPAA regulations. All data is encrypted end-to-end and access is audit logged for security compliance.',
                                      style: TextStyle(
                                        fontSize: 13.5,
                                        color: AppColors.textSecondary,
                                        height: 1.6,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
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
      ),
    );
  }

  Widget _buildRequirementsGrid() {
    final requirements = [
      {
        'icon': Icons.verified_user_rounded,
        'title': 'License Verification',
        'subtitle': 'Valid medical license required',
        'color': Color(0xFF00B894),
      },
      {
        'icon': Icons.security_rounded,
        'title': 'HIPAA Compliant',
        'subtitle': 'End-to-end encrypted data',
        'color': Color(0xFF6C5CE7),
      },
      {
        'icon': Icons.access_time_rounded,
        'title': '24/7 Access',
        'subtitle': 'Round-the-clock monitoring',
        'color': Color(0xFFFD79A8),
      },
      {
        'icon': Icons.group_rounded,
        'title': 'Multi-disciplinary',
        'subtitle': 'Network of professionals',
        'color': Color(0xFF00CEC9),
      },
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 20,
        mainAxisSpacing: 20,
        childAspectRatio: 3.2,
      ),
      itemCount: requirements.length,
      itemBuilder: (context, index) {
        final req = requirements[index];
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 8,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: req['color'] as Color? ?? AppColors.primary,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(
                  req['icon'] as IconData? ?? Icons.circle,
                  size: 18,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      req['title'] as String? ?? '',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      req['subtitle'] as String? ?? '',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEnhancedProgressSteps() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Medical Professional Registration',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Step ${_currentStep + 1} of 2',
          style: TextStyle(fontSize: 15, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 24),
        Container(
          height: 4,
          decoration: BoxDecoration(
            color: AppColors.border,
            borderRadius: BorderRadius.circular(2),
          ),
          child: Row(
            children: [
              Expanded(
                flex: _currentStep == 0 ? 1 : 2,
                child: AnimatedContainer(
                  duration: Duration(milliseconds: 500),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppColors.primary, Color(0xFF4A6FA5)],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Expanded(flex: _currentStep == 0 ? 1 : 0, child: Container()),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildStepIndicator('Personal Info', 1, _currentStep >= 0),
            _buildStepIndicator('Professional Info', 2, _currentStep >= 1),
          ],
        ),
      ],
    );
  }

  Widget _buildStepIndicator(String label, int step, bool isActive) {
    return Column(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            gradient:
                isActive
                    ? LinearGradient(
                      colors: [AppColors.primary, Color(0xFF4A6FA5)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                    : null,
            color: isActive ? null : Colors.white,
            shape: BoxShape.circle,
            border: Border.all(
              color: isActive ? Colors.transparent : AppColors.border,
              width: 2,
            ),
            boxShadow:
                isActive
                    ? [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.3),
                        blurRadius: 8,
                        offset: Offset(0, 4),
                      ),
                    ]
                    : [],
          ),
          child: Center(
            child: Text(
              step.toString(),
              style: TextStyle(
                color: isActive ? Colors.white : AppColors.textTertiary,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: isActive ? AppColors.primary : AppColors.textTertiary,
            fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildEnhancedPersonalInfoStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Personal Information',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Enter your basic information to get started',
          style: TextStyle(fontSize: 16, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 32),

        // Full Name
        _buildEnhancedFormField(
          controller: _fullNameController,
          label: 'Full Name',
          icon: Icons.person_outline_rounded,
          hintText: 'Dr. John Smith',
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter your full name';
            }
            return null;
          },
        ),
        const SizedBox(height: 24),

        // Email
        _buildEnhancedFormField(
          controller: _emailController,
          label: 'Professional Email',
          icon: Icons.email_outlined,
          hintText: 'doctor@hospital.in',
          keyboardType: TextInputType.emailAddress,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter your email';
            }
            if (!value.contains('@') || !value.contains('.')) {
              return 'Please enter a valid email address';
            }
            return null;
          },
        ),
        const SizedBox(height: 24),

        // Phone
        _buildEnhancedFormField(
          controller: _phoneController,
          label: 'Contact Phone',
          icon: Icons.phone_android_outlined,
          hintText: '+91 98765 43210',
          keyboardType: TextInputType.phone,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter your phone number';
            }
            if (value.length < 10) {
              return 'Please enter a valid phone number';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildEnhancedProfessionalInfoStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Professional Credentials',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Verify your medical qualifications and credentials',
          style: TextStyle(fontSize: 16, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 32),

        // License Number
        _buildEnhancedFormField(
          controller: _licenseController,
          label: 'Medical License Number',
          icon: Icons.badge_outlined,
          hintText: 'MHMC/12345/2023',
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter your license number';
            }
            return null;
          },
        ),
        const SizedBox(height: 24),

        // Hospital/Institution
        _buildEnhancedFormField(
          controller: _hospitalController,
          label: 'Hospital/Institution',
          icon: Icons.local_hospital_outlined,
          hintText: 'AIIMS Bhopal, Apollo Hospitals, etc.',
        ),
        const SizedBox(height: 24),

        // Specialty Dropdown
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Medical Specialty',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.02),
                    blurRadius: 8,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: DropdownButtonFormField<String>(
                value: _selectedSpecialty,
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 18,
                  ),
                  border: InputBorder.none,
                  prefixIcon: Icon(
                    Icons.medical_services_outlined,
                    color: AppColors.textTertiary.withOpacity(0.7),
                    size: 22,
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
                items:
                    _specialties
                        .map(
                          (specialty) => DropdownMenuItem(
                            value: specialty,
                            child: Text(
                              specialty,
                              style: TextStyle(
                                fontSize: 16,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                onChanged: (value) {
                  setState(() => _selectedSpecialty = value);
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please select your specialty';
                  }
                  return null;
                },
                hint: Text(
                  'Select your medical specialty',
                  style: TextStyle(color: AppColors.textTertiary, fontSize: 15),
                ),
                dropdownColor: Colors.white,
                borderRadius: BorderRadius.circular(14),
                elevation: 4,
                icon: Icon(
                  Icons.arrow_drop_down_rounded,
                  color: AppColors.textTertiary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Password
        _buildEnhancedPasswordField(
          controller: _passwordController,
          label: 'Password',
          obscure: _obscurePassword,
          onToggle: () => setState(() => _obscurePassword = !_obscurePassword),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter a password';
            }
            if (value.length < 8) {
              return 'Password must be at least 8 characters';
            }
            return null;
          },
        ),
        const SizedBox(height: 24),

        // Confirm Password
        _buildEnhancedPasswordField(
          controller: _confirmPasswordController,
          label: 'Confirm Password',
          obscure: _obscureConfirm,
          onToggle: () => setState(() => _obscureConfirm = !_obscureConfirm),
          validator: (value) {
            if (value != _passwordController.text) {
              return 'Passwords do not match';
            }
            return null;
          },
        ),
        const SizedBox(height: 8),

        // Password Requirements
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Text(
            '• Minimum 8 characters\n• Include letters and numbers',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textTertiary,
              height: 1.6,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEnhancedFormField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hintText,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 8,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            style: TextStyle(fontSize: 16, color: AppColors.textPrimary),
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 18,
              ),
              border: InputBorder.none,
              prefixIcon: Icon(
                icon,
                color: AppColors.textTertiary.withOpacity(0.7),
                size: 22,
              ),
              hintText: hintText,
              hintStyle: TextStyle(color: AppColors.textTertiary, fontSize: 15),
              filled: true,
              fillColor: Colors.white,
            ),
            validator: validator,
          ),
        ),
      ],
    );
  }

  Widget _buildEnhancedPasswordField({
    required TextEditingController controller,
    required String label,
    required bool obscure,
    required VoidCallback onToggle,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 8,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: TextFormField(
            controller: controller,
            obscureText: obscure,
            style: TextStyle(fontSize: 16, color: AppColors.textPrimary),
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 18,
              ),
              border: InputBorder.none,
              prefixIcon: Icon(
                Icons.lock_outline_rounded,
                color: AppColors.textTertiary.withOpacity(0.7),
                size: 22,
              ),
              suffixIcon: IconButton(
                onPressed: onToggle,
                icon: Icon(
                  obscure
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded,
                  color: AppColors.textTertiary,
                  size: 22,
                ),
              ),
              hintText: 'Enter your password',
              hintStyle: TextStyle(color: AppColors.textTertiary, fontSize: 15),
              filled: true,
              fillColor: Colors.white,
            ),
            validator: validator,
          ),
        ),
      ],
    );
  }

  Widget _buildEnhancedNavigationButtons() {
    return Row(
      children: [
        if (_currentStep > 0)
          Expanded(
            child: OutlinedButton(
              onPressed: () {
                setState(() => _currentStep--);
              },
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: AppColors.border, width: 1.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 20),
                backgroundColor: Colors.white,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.arrow_back_rounded,
                    size: 20,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Back',
                    style: TextStyle(
                      fontSize: 16,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (_currentStep > 0) const SizedBox(width: 16),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: LinearGradient(
                colors: [AppColors.primary, Color(0xFF4A6FA5)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              boxShadow:
                  _isLoading
                      ? []
                      : [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.3),
                          blurRadius: 15,
                          offset: Offset(0, 8),
                        ),
                      ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: _isLoading ? null : _handleNextStep,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child:
                        _isLoading
                            ? SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2.5,
                              ),
                            )
                            : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  _currentStep == 0
                                      ? 'Continue to Professional Info'
                                      : 'Complete Registration',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Icon(
                                  _currentStep == 0
                                      ? Icons.arrow_forward_rounded
                                      : Icons.check_circle_rounded,
                                  size: 22,
                                  color: Colors.white,
                                ),
                              ],
                            ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _handleNextStep() async {
    if (_currentStep == 0) {
      // Validate personal info
      if (_formKey.currentState!.validate()) {
        setState(() => _currentStep++);
      }
    } else {
      // Final registration
      if (_formKey.currentState!.validate() && _selectedSpecialty != null) {
        await _register();
      } else if (_selectedSpecialty == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Please select your medical specialty'),
            backgroundColor: AppColors.danger,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }

  Future<void> _register() async {
    setState(() => _isLoading = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final result = await authProvider.register(
        email: _emailController.text,
        password: _passwordController.text,
        fullName: _fullNameController.text,
        licenseNumber: _licenseController.text,
        hospital: _hospitalController.text,
        specialty: _selectedSpecialty!,
        phone: _phoneController.text,
      );

      if (result['success'] == true) {
        _showSuccessDialog();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['error'] ?? 'Registration failed'),
            backgroundColor: AppColors.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: AppColors.danger,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
            ),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
              ),
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Success Icon
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF00B894), Color(0xFF00CEC9)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Color(0xFF00B894).withOpacity(0.3),
                            blurRadius: 20,
                            offset: Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.check_rounded,
                        size: 50,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Title
                    Text(
                      'Registration Successful!',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),

                    // Message
                    Text(
                      'Welcome to the Chetna Medical Network. Your account is pending verification (24-48 hours). You will receive access to the dashboard upon approval.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: AppColors.textSecondary,
                        height: 1.6,
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Dashboard Button
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        gradient: LinearGradient(
                          colors: [AppColors.primary, Color(0xFF4A6FA5)],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.3),
                            blurRadius: 15,
                            offset: Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () {
                            Navigator.pop(context); // Close dialog
                            Navigator.pushReplacementNamed(
                              context,
                              '/dashboard',
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 32,
                              vertical: 20,
                            ),
                            child: Center(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.dashboard_rounded,
                                    size: 22,
                                    color: Colors.white,
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    'Go to Dashboard',
                                    style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Return to Login
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context); // Close dialog
                        Navigator.pop(context); // Go to login
                      },
                      child: Text(
                        'Return to Login',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
    );
  }
}
