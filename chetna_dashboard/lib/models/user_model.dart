// models/user_model.dart
class UserModel {
  final String id;
  final String name;
  final String email;
  final String? phone;
  final String caregiverPhone;
  final DateTime? lastActive;
  final String? location;
  final double? latitude;
  final double? longitude;
  final Map<String, dynamic> preferences;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
    required this.caregiverPhone,
    this.lastActive,
    this.location,
    this.latitude,
    this.longitude,
    this.preferences = const {},
  });

  factory UserModel.fromFirebase(String id, dynamic data) {
    return UserModel(
      id: id,
      name: data['name']?.toString() ?? 'Unknown User',
      email: data['email']?.toString() ?? '',
      phone: data['phone']?.toString(),
      caregiverPhone: data['caregiverPhone']?.toString() ?? 'Not Set',
      lastActive: data['lastActive'] != null
          ? DateTime.fromMillisecondsSinceEpoch(data['lastActive'] as int)
          : null,
      location: data['location']?.toString(),
      latitude: data['latitude']?.toDouble(),
      longitude: data['longitude']?.toDouble(),
      preferences: Map<String, dynamic>.from(data['preferences'] ?? {}),
    );
  }

  bool get isOnline {
    if (lastActive == null) return false;
    final now = DateTime.now();
    return now.difference(lastActive!).inMinutes < 5;
  }

  int get statusColorValue {
    return isOnline ? 0xFF10B981 : 0xFF94A3B8;
  }

  String get statusText {
    return isOnline ? 'Online' : 'Offline';
  }
}
