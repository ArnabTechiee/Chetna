// services/firebase_service.dart
import 'package:firebase_database/firebase_database.dart';
import 'dart:async';

class FirebaseService {
  final DatabaseReference _db = FirebaseDatabase.instance.ref();

  // Get real-time events from all users
  Stream<List<Map<String, dynamic>>> getEventsStream() {
    return _db.child('users').onValue.map((event) {
      if (event.snapshot.value == null) return [];

      final dynamic data = event.snapshot.value;
      if (data is! Map) return [];

      final users = data as Map<dynamic, dynamic>;
      List<Map<String, dynamic>> events = [];

      users.forEach((userId, userData) {
        if (userData != null && userData is Map) {
          final userEvents = userData['events'];
          if (userEvents != null && userEvents is Map) {
            final eventsMap = userEvents as Map<dynamic, dynamic>;
            eventsMap.forEach((eventId, eventData) {
              if (eventData != null && eventData is Map) {
                final timestamp = eventData['timestamp'];
                events.add({
                  'id': eventId?.toString() ?? '',
                  'userId': userId?.toString() ?? '',
                  'type': eventData['type']?.toString() ?? 'Unknown',
                  'timestamp': _parseTimestamp(timestamp),
                  'data': eventData['data'] is Map
                      ? Map<String, dynamic>.from(eventData['data'] as Map)
                      : {},
                  'status': eventData['status']?.toString() ?? 'logged',
                });
              }
            });
          }
        }
      });

      // Sort by timestamp descending
      events.sort((a, b) => b['timestamp'].compareTo(a['timestamp']));
      return events;
    });
  }

  // Get real-time alerts
  Stream<List<Map<String, dynamic>>> getAlertsStream() {
    return _db.child('alerts').onValue.map((event) {
      if (event.snapshot.value == null) return [];

      final dynamic data = event.snapshot.value;
      if (data is! Map) return [];

      final alerts = data as Map<dynamic, dynamic>;
      List<Map<String, dynamic>> alertList = [];

      alerts.forEach((alertId, alertData) {
        if (alertData != null && alertData is Map) {
          final timestamp = alertData['timestamp'];
          alertList.add({
            'id': alertId?.toString() ?? '',
            'userId': alertData['userId']?.toString() ?? 'unknown',
            'type': alertData['type']?.toString() ?? 'Unknown',
            'title': alertData['title']?.toString() ?? 'Alert',
            'message': alertData['message']?.toString() ?? '',
            'timestamp': _parseTimestamp(timestamp),
            'data': alertData['data'] is Map
                ? Map<String, dynamic>.from(alertData['data'] as Map)
                : {},
          });
        }
      });

      // Sort by timestamp descending
      alertList.sort((a, b) => b['timestamp'].compareTo(a['timestamp']));
      return alertList;
    });
  }

  // Get real-time users - UPDATED
  Stream<List<Map<String, dynamic>>> getUsersStream() {
    return _db.child('users').onValue.map((event) {
      if (event.snapshot.value == null) return [];

      final dynamic data = event.snapshot.value;
      if (data is! Map) return [];

      final users = data as Map<dynamic, dynamic>;
      List<Map<String, dynamic>> userList = [];
      final now = DateTime.now();

      users.forEach((userId, userData) {
        if (userData != null && userData is Map) {
          final profile = userData['profile'];
          if (profile != null && profile is Map) {
            final profileMap = profile as Map<dynamic, dynamic>;

            // Find last activity timestamp from events
            DateTime? lastActive;
            final userEvents = userData['events'];
            if (userEvents != null && userEvents is Map) {
              final eventsMap = userEvents as Map<dynamic, dynamic>;
              if (eventsMap.isNotEmpty) {
                final sortedEvents = eventsMap.values.toList();
                sortedEvents.sort((a, b) {
                  final aTime =
                      _parseTimestamp(a['timestamp']).millisecondsSinceEpoch;
                  final bTime =
                      _parseTimestamp(b['timestamp']).millisecondsSinceEpoch;
                  return bTime.compareTo(aTime);
                });
                final lastEvent = sortedEvents.first;
                if (lastEvent is Map) {
                  lastActive = _parseTimestamp(lastEvent['timestamp']);

                  // Calculate time since last activity
                  final timeDiff = now.difference(lastActive!);
                  final isCurrentlyActive = timeDiff.inMinutes < 1;

                  userList.add({
                    'id': userId?.toString() ?? '',
                    'name': profileMap['name']?.toString() ?? 'Unknown User',
                    'email': '',
                    'phone': profileMap['phone']?.toString() ?? '',
                    'caregiverPhone':
                        profileMap['caregiverPhone']?.toString() ?? 'Not Set',
                    'lastActive': lastActive,
                    'isOnline': isCurrentlyActive,
                    'timeSinceLastActivity': timeDiff.inMinutes,
                    'createdAt': _parseTimestamp(profileMap['createdAt']),
                    'updatedAt': _parseTimestamp(profileMap['updatedAt']),
                    'status':
                        profileMap['status']?.toString() ?? 'active_monitoring',
                  });
                }
              } else {
                // No events yet - user is offline
                userList.add({
                  'id': userId?.toString() ?? '',
                  'name': profileMap['name']?.toString() ?? 'Unknown User',
                  'email': '',
                  'phone': profileMap['phone']?.toString() ?? '',
                  'caregiverPhone':
                      profileMap['caregiverPhone']?.toString() ?? 'Not Set',
                  'lastActive': null,
                  'isOnline': false,
                  'timeSinceLastActivity':
                      999, // Large number indicating offline
                  'createdAt': _parseTimestamp(profileMap['createdAt']),
                  'updatedAt': _parseTimestamp(profileMap['updatedAt']),
                  'status':
                      profileMap['status']?.toString() ?? 'active_monitoring',
                });
              }
            } else {
              // No events - user is offline
              userList.add({
                'id': userId?.toString() ?? '',
                'name': profileMap['name']?.toString() ?? 'Unknown User',
                'email': '',
                'phone': profileMap['phone']?.toString() ?? '',
                'caregiverPhone':
                    profileMap['caregiverPhone']?.toString() ?? 'Not Set',
                'lastActive': null,
                'isOnline': false,
                'timeSinceLastActivity': 999,
                'createdAt': _parseTimestamp(profileMap['createdAt']),
                'updatedAt': _parseTimestamp(profileMap['updatedAt']),
                'status':
                    profileMap['status']?.toString() ?? 'active_monitoring',
              });
            }
          }
        }
      });

      return userList;
    });
  }

  // Get statistics from events and alerts
  Future<Map<String, dynamic>> getStatistics() async {
    final usersSnapshot = await _db.child('users').get();
    final alertsSnapshot = await _db.child('alerts').get();

    int totalUsers = 0;
    int activeUsers = 0;
    int fallsToday = 0;
    int sosToday = 0;
    int environmentalAlerts = 0;
    int moodLogs = 0;

    if (usersSnapshot.exists) {
      final dynamic data = usersSnapshot.value;
      if (data is Map) {
        final users = data as Map<dynamic, dynamic>;
        totalUsers = users.length;

        // Check for active users (last event within 5 minutes)
        final now = DateTime.now().millisecondsSinceEpoch;
        users.forEach((userId, userData) {
          if (userData != null && userData is Map) {
            final events = userData['events'];
            if (events != null && events is Map) {
              final eventsMap = events as Map<dynamic, dynamic>;
              if (eventsMap.isNotEmpty) {
                final sortedEvents = eventsMap.values.toList();
                sortedEvents.sort((a, b) {
                  final aTime =
                      _parseTimestamp(a['timestamp']).millisecondsSinceEpoch;
                  final bTime =
                      _parseTimestamp(b['timestamp']).millisecondsSinceEpoch;
                  return bTime.compareTo(aTime);
                });
                final lastEvent = sortedEvents.first;
                if (lastEvent is Map) {
                  final lastEventTime = _parseTimestamp(lastEvent['timestamp'])
                      .millisecondsSinceEpoch;
                  if (now - lastEventTime < 300000) {
                    // 5 minutes
                    activeUsers++;
                  }

                  // Count today's events
                  final today = DateTime.now();
                  final todayStart =
                      DateTime(today.year, today.month, today.day)
                          .millisecondsSinceEpoch;

                  eventsMap.forEach((eventId, eventData) {
                    if (eventData is Map) {
                      final eventTime = _parseTimestamp(eventData['timestamp'])
                          .millisecondsSinceEpoch;
                      final eventType = eventData['type']?.toString() ?? '';

                      if (eventTime > todayStart) {
                        if (eventType == 'FALL_DETECTED') fallsToday++;
                        if (eventType == 'SOS_TRIGGERED') sosToday++;
                        if (eventType == 'ENVIRONMENT_DIAGNOSIS')
                          environmentalAlerts++;
                        if (eventType == 'MOOD_LOG') moodLogs++;
                      }
                    }
                  });
                }
              }
            }
          }
        });
      }
    }

    // Count today's alerts
    int criticalAlertsToday = 0;
    if (alertsSnapshot.exists) {
      final dynamic data = alertsSnapshot.value;
      if (data is Map) {
        final alerts = data as Map<dynamic, dynamic>;
        final today = DateTime.now();
        final todayStart =
            DateTime(today.year, today.month, today.day).millisecondsSinceEpoch;

        alerts.forEach((alertId, alertData) {
          if (alertData != null && alertData is Map) {
            final alertTime =
                _parseTimestamp(alertData['timestamp']).millisecondsSinceEpoch;
            if (alertTime > todayStart) {
              criticalAlertsToday++;
            }
          }
        });
      }
    }

    return {
      'totalUsers': totalUsers,
      'activeUsers': activeUsers,
      'fallsToday': fallsToday,
      'sosToday': sosToday,
      'environmentalAlerts': environmentalAlerts,
      'moodLogs': moodLogs,
      'criticalAlertsToday': criticalAlertsToday,
      'systemUptime': '99.8%',
      'avgResponseTime': '45s',
    };
  }

  // Helper to parse timestamp - handles Firebase ServerValue.timestamp
  DateTime _parseTimestamp(dynamic timestamp) {
    if (timestamp == null) return DateTime.now();

    if (timestamp is int) {
      return DateTime.fromMillisecondsSinceEpoch(timestamp);
    } else if (timestamp is String) {
      try {
        return DateTime.parse(timestamp);
      } catch (e) {
        return DateTime.now();
      }
    } else if (timestamp is Map && timestamp.containsKey('.sv')) {
      // Firebase ServerValue.timestamp
      return DateTime.now();
    } else {
      return DateTime.now();
    }
  }

  // Resolve an alert
  Future<void> resolveAlert(String alertId) async {
    await _db.child('alerts/$alertId/status').set('resolved');
  }

  // Update caregiver phone
  Future<void> updateCaregiverPhone(String userId, String phone) async {
    await _db.child('users/$userId/profile/caregiverPhone').set(phone);
    await _db
        .child('users/$userId/profile/updatedAt')
        .set(ServerValue.timestamp);
  }

  // Send emergency message to user
  Future<void> sendEmergencyMessage(String userId, String message) async {
    final eventRef = _db.child('users/$userId/events').push();
    await eventRef.set({
      'type': 'ADMIN_EMERGENCY_MESSAGE',
      'timestamp': ServerValue.timestamp,
      'message': message,
      'adminId': 'dashboard_admin',
      'status': 'logged',
    });
  }

  // Get user events for specific user
  Stream<List<Map<String, dynamic>>> getUserEventsStream(String userId) {
    return _db.child('users/$userId/events').onValue.map((event) {
      if (event.snapshot.value == null) return [];

      final dynamic data = event.snapshot.value;
      if (data is! Map) return [];

      final events = data as Map<dynamic, dynamic>;
      List<Map<String, dynamic>> eventList = [];

      events.forEach((eventId, eventData) {
        if (eventData != null && eventData is Map) {
          final timestamp = eventData['timestamp'];
          eventList.add({
            'id': eventId?.toString() ?? '',
            'userId': userId,
            'type': eventData['type']?.toString() ?? 'Unknown',
            'timestamp': _parseTimestamp(timestamp),
            'data': eventData['data'] is Map
                ? Map<String, dynamic>.from(eventData['data'] as Map)
                : {},
            'status': eventData['status']?.toString() ?? 'logged',
          });
        }
      });

      // Sort by timestamp descending
      eventList.sort((a, b) => b['timestamp'].compareTo(a['timestamp']));
      return eventList;
    });
  }

  // Get environmental data trends
  Future<List<Map<String, dynamic>>> getEnvironmentalData(String userId) async {
    final snapshot = await _db.child('users/$userId/events').get();
    if (!snapshot.exists) return [];

    final dynamic data = snapshot.value;
    if (data is! Map) return [];

    final events = data as Map<dynamic, dynamic>;
    List<Map<String, dynamic>> envData = [];

    events.forEach((eventId, eventData) {
      if (eventData != null && eventData is Map) {
        final type = eventData['type']?.toString() ?? '';
        if (type == 'ENVIRONMENT_DATA' || type == 'ENVIRONMENT_DIAGNOSIS') {
          final timestamp = eventData['timestamp'];
          final dataMap = eventData['data'] is Map
              ? Map<String, dynamic>.from(eventData['data'] as Map)
              : {};

          envData.add({
            'timestamp': _parseTimestamp(timestamp),
            'type': type,
            'data': dataMap,
          });
        }
      }
    });

    // Sort by timestamp
    envData.sort((a, b) => a['timestamp'].compareTo(b['timestamp']));
    return envData;
  }
}
