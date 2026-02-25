// models/event_model.dart
class EventModel {
  final String id;
  final String userId;
  final String type;
  final DateTime timestamp;
  final Map<String, dynamic> data;
  final String? location;
  final double? latitude;
  final double? longitude;

  EventModel({
    required this.id,
    required this.userId,
    required this.type,
    required this.timestamp,
    required this.data,
    this.location,
    this.latitude,
    this.longitude,
  });

  factory EventModel.fromFirebase(String userId, String id, dynamic data) {
    final timestamp = data['timestamp'] != null
        ? DateTime.fromMillisecondsSinceEpoch(data['timestamp'] as int)
        : DateTime.now();

    return EventModel(
      id: id,
      userId: userId,
      type: data['type']?.toString() ?? 'Unknown',
      timestamp: timestamp,
      data: Map<String, dynamic>.from(data),
      location: data['location']?.toString(),
      latitude: data['latitude'] != null ? data['latitude'].toDouble() : null,
      longitude:
          data['longitude'] != null ? data['longitude'].toDouble() : null,
    );
  }

  String get displayType {
    switch (type) {
      case 'FALL_DETECTED':
        return 'Fall Detected';
      case 'SOS_TRIGGERED':
        return 'SOS Triggered';
      case 'ENVIRONMENT_DIAGNOSIS':
        return 'Environmental Alert';
      case 'MOOD_LOG':
        return 'Mood Logged';
      case 'GEOFENCE_BREACH':
        return 'Geofence Breach';
      default:
        return type.replaceAll('_', ' ');
    }
  }

  int get typeColorValue {
    switch (type) {
      case 'FALL_DETECTED':
      case 'SOS_TRIGGERED':
        return 0xFFDC2626;
      case 'ENVIRONMENT_DIAGNOSIS':
        return 0xFFF59E0B;
      case 'GEOFENCE_BREACH':
        return 0xFF8B5CF6;
      default:
        return 0xFF3B82F6;
    }
  }

  String get typeIconName {
    switch (type) {
      case 'FALL_DETECTED':
        return 'warning';
      case 'SOS_TRIGGERED':
        return 'emergency';
      case 'ENVIRONMENT_DIAGNOSIS':
        return 'health_and_safety';
      case 'MOOD_LOG':
        return 'emoji_emotions';
      case 'GEOFENCE_BREACH':
        return 'location_off';
      default:
        return 'notifications';
    }
  }
}
