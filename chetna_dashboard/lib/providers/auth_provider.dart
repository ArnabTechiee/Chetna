// providers/auth_provider.dart - COMPLETE FIXED VERSION
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';

class AuthProvider with ChangeNotifier {
  final AuthService _authService = AuthService();

  bool _isLoading = false;
  bool _isAuthenticated = false;
  Map<String, dynamic>? _currentUser;
  Map<String, dynamic>? _medicalProfile;

  bool get isLoading => _isLoading;
  bool get isAuthenticated => _isAuthenticated;
  Map<String, dynamic>? get currentUser => _currentUser;
  Map<String, dynamic>? get medicalProfile => _medicalProfile;

  AuthProvider() {
    // Initialize auth state silently
    _checkAuthStateSilently();
  }

  Future<void> _checkAuthStateSilently() async {
    try {
      final User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final profile = await _authService.getMedicalProfile();
        if (profile != null && profile.isNotEmpty) {
          _isAuthenticated = true;
          _currentUser = {'uid': user.uid, 'email': user.email};
          _medicalProfile = profile;
        }
      }
    } catch (e) {
      debugPrint('Silent auth check error: $e');
    }
  }

  // Medical professional login - FIXED RESPONSE HANDLING
  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final result = await _authService.loginMedicalProfessional(
        email: email,
        password: password,
      );

      print('AuthProvider: Login result - success: ${result['success']}');

      if (result['success'] == true) {
        _isAuthenticated = true;
        _currentUser = {
          'uid': result['user']?.uid,
          'email': result['user']?.email,
        };

        // Safely extract profile data
        final dynamic profileData = result['profile'];
        if (profileData is Map<String, dynamic>) {
          _medicalProfile = profileData;
        } else if (profileData is Map) {
          // Convert any Map type to Map<String, dynamic>
          _medicalProfile = {};
          profileData.forEach((key, value) {
            if (key != null) {
              _medicalProfile![key.toString()] = value;
            }
          });
        } else {
          _medicalProfile = {'email': email, 'role': 'medical_admin'};
        }

        print('AuthProvider: User authenticated successfully');
        print('AuthProvider: Profile data: $_medicalProfile');
      }

      _isLoading = false;
      notifyListeners();
      return result;
    } catch (e) {
      print('AuthProvider: Exception during login: $e');
      _isLoading = false;
      notifyListeners();
      return {'success': false, 'error': e.toString()};
    }
  }

  // Medical professional registration
  Future<Map<String, dynamic>> register({
    required String email,
    required String password,
    required String fullName,
    String licenseNumber = '',
    String hospital = '',
    String specialty = '',
    String phone = '',
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final result = await _authService.registerMedicalProfessional(
        email: email,
        password: password,
        fullName: fullName,
        licenseNumber: licenseNumber,
        hospital: hospital,
        specialty: specialty,
        phone: phone,
      );

      if (result['success'] == true && result['user'] != null) {
        _isAuthenticated = true;
        _currentUser = {
          'uid': result['user'].uid,
          'email': result['user'].email,
        };
        _medicalProfile = {
          'email': email,
          'fullName': fullName,
          'role': 'medical_admin',
        };
      }

      _isLoading = false;
      notifyListeners();
      return result;
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return {'success': false, 'error': e.toString()};
    }
  }

  // Password reset
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _authService.sendPasswordResetEmail(email);
    } catch (e) {
      debugPrint('Password reset error: $e');
      rethrow;
    }
  }

  // Logout
  Future<void> logout() async {
    try {
      await _authService.logout();
      _isAuthenticated = false;
      _currentUser = null;
      _medicalProfile = null;
      notifyListeners();
    } catch (e) {
      debugPrint('Logout error: $e');
    }
  }
}
