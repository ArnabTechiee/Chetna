// models/alert_model.dart
class AlertModel {
  final String id;
  final String userId;
  final String type;
  final String title;
  final String message;
  final DateTime timestamp;
  final Map<String, dynamic> data;
  final String status;

  AlertModel({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.message,
    required this.timestamp,
    required this.data,
    this.status = 'active',
  });

  factory AlertModel.fromFirebase(String id, dynamic data) {
    final timestamp = data['timestamp'] != null
        ? DateTime.fromMillisecondsSinceEpoch(data['timestamp'] as int)
        : DateTime.now();

    return AlertModel(
      id: id,
      userId: data['userId']?.toString() ?? 'unknown',
      type: data['type']?.toString() ?? 'Unknown',
      title: data['title']?.toString() ?? 'Alert',
      message: data['message']?.toString() ?? '',
      timestamp: timestamp,
      data: Map<String, dynamic>.from(data['data'] ?? {}),
      status: data['status']?.toString() ?? 'active',
    );
  }

  bool get isCritical => type.contains('EMERGENCY') || type.contains('SOS');
  bool get isWarning => type.contains('FALL') || type.contains('GEOFENCE');
  bool get isInfo => !isCritical && !isWarning;

  int get severityColorValue {
    if (isCritical) return 0xFFDC2626;
    if (isWarning) return 0xFFF59E0B;
    return 0xFF3B82F6;
  }
}
