// providers/dashboard_provider.dart
import 'package:flutter/material.dart';
import '../services/firebase_service.dart';
import 'dart:async';

class DashboardProvider with ChangeNotifier {
  final FirebaseService _firebaseService = FirebaseService();

  List<Map<String, dynamic>> _events = [];
  List<Map<String, dynamic>> _alerts = [];
  List<Map<String, dynamic>> _users = [];
  Map<String, dynamic> _stats = {
    'totalUsers': 0,
    'activeUsers': 0,
    'fallsToday': 0,
    'sosToday': 0,
    'environmentalAlerts': 0,
    'moodLogs': 0,
    'criticalAlertsToday': 0,
    'systemUptime': '0%',
    'avgResponseTime': '0s',
  };

  bool _isLoading = true;
  bool _isConnected = false;
  Timer? _activityTimer;
  Timer? _statsTimer; // NEW: Timer for auto-refreshing stats

  List<Map<String, dynamic>> get events => _events;
  List<Map<String, dynamic>> get alerts => _alerts;
  List<Map<String, dynamic>> get users => _users;
  Map<String, dynamic> get stats => _stats;
  bool get isLoading => _isLoading;
  bool get isConnected => _isConnected;

  // Critical alerts count (active alerts)
  int get criticalAlertsCount {
    return _alerts.where((a) {
      final type = a['type']?.toString() ?? '';
      final status = a['status']?.toString() ?? 'active';
      return (type.contains('EMERGENCY') || type.contains('SOS')) &&
          status == 'active';
    }).length;
  }

  // Warning alerts count (active alerts)
  int get warningAlertsCount {
    return _alerts.where((a) {
      final type = a['type']?.toString() ?? '';
      final status = a['status']?.toString() ?? 'active';
      return (type.contains('FALL') ||
              type.contains('GEOFENCE') ||
              type.contains('ENVIRONMENTAL')) &&
          status == 'active';
    }).length;
  }

  // Get active users count - NOW calculates dynamically
  int get activeUsersCount {
    final now = DateTime.now();
    return _users.where((user) {
      final lastActive = user['lastActive'];
      if (lastActive == null) return false;

      // User is active if last activity was within 5 minutes
      final timeDiff = now.difference(lastActive);
      return timeDiff.inMinutes < 1;
    }).length;
  }

  DashboardProvider() {
    _initializeData();
  }

  Future<void> _initializeData() async {
    try {
      // Listen to real-time events
      _firebaseService.getEventsStream().listen((events) {
        _events = events;
        _isConnected = true;

        // When new events come in, update user activity status
        _updateUserActivityStatus();

        // NEW: Update stats in real-time when events change
        _updateRealTimeStats();

        notifyListeners();
      }, onError: (error) {
        _isConnected = false;
        debugPrint('Error in events stream: $error');
        notifyListeners();
      });

      // Listen to real-time alerts
      _firebaseService.getAlertsStream().listen((alerts) {
        _alerts = alerts;

        // NEW: Update stats in real-time when alerts change
        _updateRealTimeStats();

        notifyListeners();
      }, onError: (error) {
        debugPrint('Error listening to alerts: $error');
      });

      // Listen to real-time users
      _firebaseService.getUsersStream().listen((users) {
        _users = users;

        // Update statistics with current active users
        _updateStatisticsWithActiveCount();

        notifyListeners();
      }, onError: (error) {
        debugPrint('Error listening to users: $error');
      });

      // Load initial statistics
      await _loadStatistics();

      // Start activity monitoring timer (every 30 seconds)
      _startActivityMonitoring();

      // NEW: Start stats auto-refresh timer (every 10 seconds)
      _startStatsMonitoring();

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      debugPrint('Error initializing dashboard: $e');
      _isLoading = false;
      notifyListeners();
    }
  }

  void _startActivityMonitoring() {
    // Cancel any existing timer
    _activityTimer?.cancel();

    // Start new timer to check user activity every 30 seconds
    _activityTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _updateUserActivityStatus();
      _updateStatisticsWithActiveCount();
    });
  }

  // NEW: Start stats monitoring timer
  void _startStatsMonitoring() {
    _statsTimer?.cancel();
    _statsTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      _updateRealTimeStats();
    });
  }

  // NEW: Update stats in real-time from current events and alerts
  void _updateRealTimeStats() {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);

    // Count today's events from real-time data
    int fallsToday = 0;
    int sosToday = 0;
    int environmentalAlerts = 0;
    int moodLogs = 0;

    for (var event in _events) {
      final timestamp = event['timestamp'];
      if (timestamp is DateTime && timestamp.isAfter(todayStart)) {
        final type = event['type']?.toString() ?? '';
        if (type == 'FALL_DETECTED') fallsToday++;
        if (type == 'SOS_TRIGGERED') sosToday++;
        if (type == 'ENVIRONMENT_DIAGNOSIS') environmentalAlerts++;
        if (type == 'MOOD_LOG') moodLogs++;
      }
    }

    // Count today's critical alerts
    int criticalAlertsToday = 0;
    for (var alert in _alerts) {
      final timestamp = alert['timestamp'];
      if (timestamp is DateTime && timestamp.isAfter(todayStart)) {
        final type = alert['type']?.toString() ?? '';
        if (type.contains('EMERGENCY') || type.contains('SOS')) {
          criticalAlertsToday++;
        }
      }
    }

    // Update stats without resetting other values
    _stats['fallsToday'] = fallsToday;
    _stats['sosToday'] = sosToday;
    _stats['environmentalAlerts'] = environmentalAlerts;
    _stats['moodLogs'] = moodLogs;
    _stats['criticalAlertsToday'] = criticalAlertsToday;

    notifyListeners();
  }

  void _updateUserActivityStatus() {
    final now = DateTime.now();
    bool hasChanges = false;

    for (var user in _users) {
      final lastActive = user['lastActive'];
      if (lastActive != null) {
        final timeDiff = now.difference(lastActive);
        final wasOnline = user['isOnline'] ?? false;
        final isNowOnline = timeDiff.inMinutes < 1;

        if (wasOnline != isNowOnline) {
          user['isOnline'] = isNowOnline;
          user['timeSinceLastActivity'] = timeDiff.inMinutes;
          hasChanges = true;
        }
      } else if (user['isOnline'] == true) {
        // User has no last activity but was marked online
        user['isOnline'] = false;
        user['timeSinceLastActivity'] = 999;
        hasChanges = true;
      }
    }

    if (hasChanges) {
      notifyListeners();
    }
  }

  void _updateStatisticsWithActiveCount() {
    _stats['activeUsers'] = activeUsersCount;
    notifyListeners();
  }

  Future<void> _loadStatistics() async {
    try {
      _stats = await _firebaseService.getStatistics();
      // Override the Firebase activeUsers with our real-time count
      _stats['activeUsers'] = activeUsersCount; // Add this line
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading statistics: $e');
    }
  }

  Future<void> refreshData() async {
    _isLoading = true;
    notifyListeners();

    await _loadStatistics();

    _isLoading = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _activityTimer?.cancel();
    _statsTimer?.cancel(); // NEW: Cancel stats timer
    super.dispose();
  }

  Future<void> resolveAlert(String alertId) async {
    try {
      await _firebaseService.resolveAlert(alertId);
      // Update local alert status
      final index = _alerts.indexWhere((a) => a['id'] == alertId);
      if (index != -1) {
        _alerts[index]['status'] = 'resolved';
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error resolving alert: $e');
    }
  }

  Future<void> updateCaregiverPhone(String userId, String phone) async {
    try {
      await _firebaseService.updateCaregiverPhone(userId, phone);
      // Update local user data
      final index = _users.indexWhere((u) => u['id'] == userId);
      if (index != -1) {
        _users[index]['caregiverPhone'] = phone;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error updating caregiver phone: $e');
    }
  }

  Future<void> sendEmergencyMessage(String userId, String message) async {
    try {
      await _firebaseService.sendEmergencyMessage(userId, message);
    } catch (e) {
      debugPrint('Error sending emergency message: $e');
    }
  }

  // Get user-specific events
  Future<List<Map<String, dynamic>>> getUserEvents(String userId) async {
    try {
      final events = await _firebaseService.getUserEventsStream(userId).first;
      return events;
    } catch (e) {
      debugPrint('Error getting user events: $e');
      return [];
    }
  }

  // Get environmental data for a user
  Future<List<Map<String, dynamic>>> getUserEnvironmentalData(
      String userId) async {
    try {
      return await _firebaseService.getEnvironmentalData(userId);
    } catch (e) {
      debugPrint('Error getting environmental data: $e');
      return [];
    }
  }
}
