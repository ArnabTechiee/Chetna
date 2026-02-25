// services/auth_service.dart - COMPLETE FIXED VERSION
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseReference _db = FirebaseDatabase.instance.ref();

  // Medical professional registration
  Future<Map<String, dynamic>> registerMedicalProfessional({
    required String email,
    required String password,
    required String fullName,
    String licenseNumber = '',
    String hospital = '',
    String specialty = '',
    String phone = '',
  }) async {
    try {
      print('🎯 Starting registration for: $email');

      // Create user with Firebase Auth
      final UserCredential credential =
          await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      // Store additional medical profile data
      final User? user = credential.user;
      if (user != null) {
        print('✅ Auth user created with UID: ${user.uid}');

        // Create medical admin record
        final medicalAdminData = {
          'email': email,
          'fullName': fullName,
          'licenseNumber': licenseNumber,
          'hospital': hospital,
          'specialty': specialty,
          'phone': phone,
          'role': 'medical_admin',
          'createdAt': ServerValue.timestamp,
          'isVerified': true,
          'permissions': {
            'viewAlerts': true,
            'resolveAlerts': true,
            'viewUsers': true,
            'viewAnalytics': true,
            'emergencyActions': true,
            'exportData': true,
          },
        };

        print('📝 Creating medicalAdmin record...');
        await _db.child('medicalAdmins/${user.uid}').set(medicalAdminData);
        print('✅ MedicalAdmin record created successfully');

        return {
          'success': true,
          'user': user,
          'message': 'Registration successful.',
        };
      }
      return {'success': false, 'error': 'User creation failed'};
    } on FirebaseAuthException catch (e) {
      print('❌ Registration error: ${e.code} - ${e.message}');
      return {'success': false, 'error': _getAuthErrorMessage(e)};
    } catch (e) {
      print('❌ Unexpected registration error: $e');
      return {'success': false, 'error': 'Registration failed: $e'};
    }
  }

  // Medical professional login - FIXED TYPE CASTING
  Future<Map<String, dynamic>> loginMedicalProfessional({
    required String email,
    required String password,
  }) async {
    try {
      print('🎯 Attempting login for: $email');

      // First, sign in with Firebase Auth
      final UserCredential credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      print('✅ Firebase Auth successful for UID: ${credential.user!.uid}');

      // Check if user has medical admin privileges
      final snapshot =
          await _db.child('medicalAdmins/${credential.user!.uid}').get();

      Map<String, dynamic> profileData;

      if (!snapshot.exists) {
        print(
            '⚠️ No medicalAdmins record found for UID: ${credential.user!.uid}');

        // Create a basic medical admin record automatically
        print('🔄 Creating medicalAdmins record automatically...');
        final newAdminData = {
          'email': email,
          'fullName': 'Medical Professional',
          'role': 'medical_admin',
          'createdAt': ServerValue.timestamp,
          'isVerified': true,
          'permissions': {
            'viewAlerts': true,
            'resolveAlerts': true,
            'viewUsers': true,
            'viewAnalytics': true,
            'emergencyActions': true,
            'exportData': true,
          },
        };

        await _db
            .child('medicalAdmins/${credential.user!.uid}')
            .set(newAdminData);
        print('✅ Auto-created medicalAdmins record');

        profileData = newAdminData;
      } else {
        print('✅ Found existing medicalAdmins record');

        // FIXED: Safely handle Firebase data types
        final dynamic rawData = snapshot.value;
        profileData = _safeConvertToMap(rawData);
      }

      return {
        'success': true,
        'user': credential.user,
        'profile': profileData, // Now properly typed
      };
    } on FirebaseAuthException catch (e) {
      print('❌ Login error: ${e.code} - ${e.message}');
      return {'success': false, 'error': _getAuthErrorMessage(e)};
    } catch (e) {
      print('❌ Unexpected login error: $e');
      return {'success': false, 'error': 'Login failed: $e'};
    }
  }

  // SAFE TYPE CONVERSION METHOD - KEY FIX
  Map<String, dynamic> _safeConvertToMap(dynamic data) {
    if (data == null) return {};

    if (data is Map) {
      final Map<String, dynamic> result = {};

      data.forEach((key, value) {
        if (key != null) {
          final String stringKey = key.toString();

          if (value is Map) {
            result[stringKey] = _safeConvertToMap(value);
          } else if (value is List) {
            result[stringKey] = _safeConvertList(value);
          } else {
            result[stringKey] = value;
          }
        }
      });

      return result;
    }

    return {'data': data.toString()};
  }

  List<dynamic> _safeConvertList(List<dynamic> list) {
    return list.map((item) {
      if (item is Map) {
        return _safeConvertToMap(item);
      }
      return item;
    }).toList();
  }

  String _getAuthErrorMessage(FirebaseAuthException e) {
    print('🔍 Auth error code: ${e.code}');
    switch (e.code) {
      case 'invalid-email':
        return 'Please enter a valid email address';
      case 'user-disabled':
        return 'Account disabled. Contact administrator';
      case 'user-not-found':
        return 'No account found with this email';
      case 'wrong-password':
        return 'Incorrect password. Please try again';
      case 'email-already-in-use':
        return 'Email already registered';
      case 'too-many-requests':
        return 'Too many attempts. Try again later';
      case 'network-request-failed':
        return 'Network error. Check your connection';
      default:
        return 'Authentication failed: ${e.message}';
    }
  }

  // Password reset for medical professionals
  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  // Get current medical admin profile - FIXED TYPE CASTING
  Future<Map<String, dynamic>?> getMedicalProfile() async {
    final User? user = _auth.currentUser;
    if (user == null) return null;

    final snapshot = await _db.child('medicalAdmins/${user.uid}').get();
    if (snapshot.exists) {
      return _safeConvertToMap(snapshot.value);
    }
    return null;
  }

  // Logout
  Future<void> logout() async {
    await _auth.signOut();
  }
}
