// lib/services/ai_summary_service.dart
import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

class AISummaryService {
  static const String _apiKey =
      'AIzaSyBpDB9ti93Dy4ywAKnNFiXhE8aHbW2AE1Y'; 
  static final GenerativeModel _model = GenerativeModel(
    model: 'gemini-2.5-flash-lite',
    apiKey: _apiKey,
  );

  // Generate executive summary from healthcare data
  static Future<String> generateExecutiveSummary({
    required List<Map<String, dynamic>> events,
    required List<Map<String, dynamic>> alerts,
    required List<Map<String, dynamic>> users,
    required Map<String, dynamic> analytics,
    required String timeRange,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      // DEBUG: Check what data we have
      debugPrint('🤖 AI Service - Debug Info:');
      debugPrint('  - Total events: ${events.length}');
      debugPrint(
        '  - Event types: ${events.take(5).map((e) => e['type']).toList()}',
      );
      debugPrint('  - Analytics keys: ${analytics.keys.toList()}');
      debugPrint('  - Analytics data:');
      analytics.forEach((key, value) {
        debugPrint('    - $key: $value (${value.runtimeType})');
      });

      // Extract fall and SOS counts from analytics with type safety
      final fallsDetected = _extractIntFromAnalytics(
        analytics,
        'fallsDetected',
        'fallCount',
        'fallCount',
      );
      final sosTriggers = _extractIntFromAnalytics(
        analytics,
        'sosTriggers',
        'sosCount',
        'sosCount',
      );
      final criticalAlerts = _extractIntFromAnalytics(
        analytics,
        'criticalAlerts',
        'criticalAlerts',
      );
      final environmentalAlerts = _extractIntFromAnalytics(
        analytics,
        'environmentalAlerts',
        'envCount',
      );
      final moodLogs = _extractIntFromAnalytics(
        analytics,
        'moodLogs',
        'moodEvents',
      );
      final totalEvents = _getTotalEvents(analytics, events);

      debugPrint('  - Falls Detected: $fallsDetected');
      debugPrint('  - SOS Triggers: $sosTriggers');
      debugPrint('  - Critical Alerts: $criticalAlerts');
      debugPrint('  - Environmental Alerts: $environmentalAlerts');
      debugPrint('  - Mood Logs: $moodLogs');
      debugPrint('  - Total Events: $totalEvents');

      // Count falls and SOS manually for verification
      final manualFallCount = _countEventType(events, [
        'FALL',
        'FALL_DETECTED',
        'Fall Detected',
      ]);
      final manualSosCount = _countEventType(events, [
        'SOS',
        'SOS_TRIGGERED',
        'SOS Triggered',
        'EMERGENCY_SOS',
      ]);

      debugPrint('  - Manual fall count: $manualFallCount');
      debugPrint('  - Manual SOS count: $manualSosCount');

      if (_apiKey == 'YOUR_GEMINI_API_KEY') {
        throw Exception(
          'Please configure your Gemini API key in AISummaryService',
        );
      }

      // Prepare structured data for AI analysis
      final prompt = _buildAIPrompt(
        events: events,
        alerts: alerts,
        users: users,
        analytics: analytics,
        timeRange: timeRange,
        startDate: startDate,
        endDate: endDate,
        fallsDetected: fallsDetected,
        sosTriggers: sosTriggers,
        criticalAlerts: criticalAlerts,
        environmentalAlerts: environmentalAlerts,
        moodLogs: moodLogs,
        totalEvents: totalEvents,
      );

      debugPrint('🤖 Sending request to Gemini AI...');
      debugPrint('Prompt length: ${prompt.length} chars');

      final content = Content.text(prompt);
      final response = await _model.generateContent([content]);

      if (response.text == null) {
        throw Exception('No response from Gemini AI');
      }

      debugPrint('✅ Gemini AI response received');
      debugPrint('Response length: ${response.text!.length} chars');

      return response.text!;
    } catch (e) {
      debugPrint('❌ Gemini AI error: $e');

      // Fallback to template-based summary if AI fails
      return _generateFallbackSummary(
        events: events,
        alerts: alerts,
        analytics: analytics,
        timeRange: timeRange,
      );
    }
  }

  // Helper method to get total events safely
  static int _getTotalEvents(
    Map<String, dynamic> analytics,
    List<Map<String, dynamic>> events,
  ) {
    if (analytics.containsKey('totalEvents')) {
      final value = analytics['totalEvents'];
      if (value is int) return value;
      if (value is double) return value.toInt();
      if (value is String) {
        final intVal = int.tryParse(value);
        return intVal ?? events.length;
      }
    }
    return events.length;
  }

  // Helper method to extract integer from analytics with multiple possible keys
  static int _extractIntFromAnalytics(
    Map<String, dynamic> analytics,
    String primaryKey, [
    String? secondaryKey,
    String? tertiaryKey,
  ]) {
    try {
      // Try primary key
      var value = analytics[primaryKey];
      if (value != null) {
        if (value is int) return value;
        if (value is double) return value.toInt();
        if (value is String) {
          final intVal = int.tryParse(value);
          if (intVal != null) return intVal;
        }
      }

      // Try secondary key
      if (secondaryKey != null) {
        value = analytics[secondaryKey];
        if (value != null) {
          if (value is int) return value;
          if (value is double) return value.toInt();
          if (value is String) {
            final intVal = int.tryParse(value);
            if (intVal != null) return intVal;
          }
        }
      }

      // Try tertiary key
      if (tertiaryKey != null) {
        value = analytics[tertiaryKey];
        if (value != null) {
          if (value is int) return value;
          if (value is double) return value.toInt();
          if (value is String) {
            final intVal = int.tryParse(value);
            if (intVal != null) return intVal;
          }
        }
      }

      return 0;
    } catch (e) {
      debugPrint('Error extracting $primaryKey from analytics: $e');
      return 0;
    }
  }

  // Helper method to count specific event types
  static int _countEventType(
    List<Map<String, dynamic>> events,
    List<String> typePatterns,
  ) {
    return events.where((e) {
      final type = e['type']?.toString() ?? '';
      final typeUpper = type.toUpperCase();

      for (final pattern in typePatterns) {
        if (typeUpper.contains(pattern.toUpperCase()) || type == pattern) {
          return true;
        }
      }
      return false;
    }).length;
  }

  // Build comprehensive prompt for medical analysis
  static String _buildAIPrompt({
    required List<Map<String, dynamic>> events,
    required List<Map<String, dynamic>> alerts,
    required List<Map<String, dynamic>> users,
    required Map<String, dynamic> analytics,
    required String timeRange,
    required DateTime startDate,
    required DateTime endDate,
    required int fallsDetected,
    required int sosTriggers,
    required int criticalAlerts,
    required int environmentalAlerts,
    required int moodLogs,
    required int totalEvents,
  }) {
    // Get event breakdown for analysis
    final eventBreakdown = _parseEventBreakdown(analytics['eventBreakdown']);

    return '''
You are a professional healthcare analyst reviewing patient monitoring data. 
Generate a concise, actionable executive summary for medical staff.

**REPORT DATA SUMMARY:**
- Time Period: $timeRange (${DateFormat('MMM dd, yyyy').format(startDate)} to ${DateFormat('MMM dd, yyyy').format(endDate)})
- Total Patients: ${users.length}
- Total Events: $totalEvents

**CRITICAL SAFETY METRICS (ACTUAL NUMBERS):**
- Falls Detected: $fallsDetected
- SOS Triggers: $sosTriggers
- Critical Alerts: $criticalAlerts
- Environmental Alerts: $environmentalAlerts
- Mood Assessments: $moodLogs

**EVENT DISTRIBUTION:**
${_formatEventBreakdownForPrompt(eventBreakdown)}

**ANALYSIS REQUEST:**
Based on the exact numbers above, provide a professional medical analysis including:

1. **Risk Assessment:** Evaluate safety risks based on $fallsDetected falls and $sosTriggers SOS events
2. **Pattern Analysis:** Identify any temporal patterns or correlations
3. **Patient Safety:** Assess overall patient safety status
4. **Recommendations:** Provide specific, actionable recommendations for medical staff

**OUTPUT FORMAT:**
Use this exact format:

**Executive Summary:**
[2-3 sentence overview focusing on actual event counts: $fallsDetected falls, $sosTriggers SOS events]

**Key Findings:**
- [Factual finding 1 based on the data]
- [Factual finding 2 about patient engagement]
- [Factual finding 3 about safety metrics]

**Risk Assessment:**
- [Risk level matching the actual event counts - be realistic]

**Actionable Recommendations:**
- [Specific recommendation 1]
- [Specific recommendation 2]
- [Specific recommendation 3]

**Monitoring Priorities:**
- [Priority 1]
- [Priority 2]

**IMPORTANT:** Base all analysis on the actual numbers provided above. If falls are 0, don't mention fall patterns. If SOS is 0, don't mention SOS issues. Be factual.
''';
  }

  // Parse event breakdown with type safety
  static Map<String, int> _parseEventBreakdown(dynamic breakdown) {
    final Map<String, int> result = {};

    if (breakdown == null) return result;

    if (breakdown is Map<String, int>) {
      return Map<String, int>.from(breakdown);
    }

    if (breakdown is Map) {
      breakdown.forEach((key, value) {
        try {
          final String keyString = key?.toString() ?? 'Unknown';
          final int valueInt =
              (value is int)
                  ? value
                  : (value is double)
                  ? value.toInt()
                  : (value is String)
                  ? int.tryParse(value) ?? 0
                  : 0;
          result[keyString] = valueInt;
        } catch (e) {
          debugPrint('Error parsing event breakdown entry: $e');
        }
      });
    }

    return result;
  }

  // Format event breakdown for the prompt
  static String _formatEventBreakdownForPrompt(Map<String, int> breakdown) {
    if (breakdown.isEmpty) return 'No detailed breakdown available';

    final sortedEntries =
        breakdown.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    final topEvents = sortedEntries.take(10);

    final buffer = StringBuffer();
    for (final entry in topEvents) {
      buffer.writeln('- ${entry.key}: ${entry.value} events');
    }

    return buffer.toString();
  }

  // Extract statistics from events
  static Map<String, dynamic> _extractEventStatistics(
    List<Map<String, dynamic>> events,
  ) {
    final criticalEvents =
        events.where((e) {
          final type = e['type']?.toString() ?? '';
          final typeUpper = type.toUpperCase();

          // Check for all possible fall event types
          if (typeUpper.contains('FALL') ||
              type == 'Fall Detected' ||
              type == 'fall_detected') {
            return true;
          }

          // Check for all possible SOS event types
          if (typeUpper.contains('SOS') ||
              type == 'SOS Triggered' ||
              type == 'sos_triggered' ||
              type == 'SOS_TRIGGERED') {
            return true;
          }

          return typeUpper.contains('EMERGENCY');
        }).toList();

    final environmentalEvents =
        events.where((e) {
          final type = e['type']?.toString() ?? '';
          final typeUpper = type.toUpperCase();

          return typeUpper.contains('TEMP') ||
              typeUpper.contains('NOISE') ||
              typeUpper.contains('LIGHT') ||
              typeUpper.contains('ENVIRONMENT') ||
              typeUpper.contains('AQI') ||
              type == 'Environmental Alert' ||
              type == 'Environment Data';
        }).toList();

    final wellnessEvents =
        events.where((e) {
          final type = e['type']?.toString() ?? '';
          final typeUpper = type.toUpperCase();

          return typeUpper.contains('MOOD') ||
              typeUpper.contains('SLEEP') ||
              typeUpper.contains('ACTIVITY') ||
              type == 'Mood Log';
        }).toList();

    return {
      'critical': _countByType(criticalEvents),
      'environmental': _countByType(environmentalEvents),
      'wellness': _countByType(wellnessEvents),
      'total': events.length,
    };
  }

  // Count events by type
  static Map<String, int> _countByType(List<Map<String, dynamic>> events) {
    final counts = <String, int>{};
    for (final event in events) {
      final type = event['type']?.toString() ?? 'UNKNOWN';
      counts[type] = (counts[type] ?? 0) + 1;
    }
    return counts;
  }

  // Extract alert statistics
  static Map<String, int> _extractAlertStatistics(
    List<Map<String, dynamic>> alerts,
  ) {
    return _countByType(alerts);
  }

  // Extract time-based patterns
  static List<Map<String, dynamic>> _extractTimePatterns(
    List<Map<String, dynamic>> events,
  ) {
    final patterns = <Map<String, dynamic>>[];

    // Morning (6 AM - 12 PM)
    final morningEvents =
        events.where((e) {
          final timestamp = _parseTimestamp(e['timestamp']);
          return timestamp.hour >= 6 && timestamp.hour < 12;
        }).toList();

    // Afternoon (12 PM - 6 PM)
    final afternoonEvents =
        events.where((e) {
          final timestamp = _parseTimestamp(e['timestamp']);
          return timestamp.hour >= 12 && timestamp.hour < 18;
        }).toList();

    // Evening (6 PM - 12 AM)
    final eveningEvents =
        events.where((e) {
          final timestamp = _parseTimestamp(e['timestamp']);
          return timestamp.hour >= 18 && timestamp.hour < 24;
        }).toList();

    // Night (12 AM - 6 AM)
    final nightEvents =
        events.where((e) {
          final timestamp = _parseTimestamp(e['timestamp']);
          return timestamp.hour >= 0 && timestamp.hour < 6;
        }).toList();

    patterns.add({
      'period': 'Morning (6AM-12PM)',
      'events': morningEvents.length,
      'types': _getTopEventTypes(morningEvents),
    });

    patterns.add({
      'period': 'Afternoon (12PM-6PM)',
      'events': afternoonEvents.length,
      'types': _getTopEventTypes(afternoonEvents),
    });

    patterns.add({
      'period': 'Evening (6PM-12AM)',
      'events': eveningEvents.length,
      'types': _getTopEventTypes(eveningEvents),
    });

    patterns.add({
      'period': 'Night (12AM-6AM)',
      'events': nightEvents.length,
      'types': _getTopEventTypes(nightEvents),
    });

    return patterns;
  }

  // Get top event types
  static List<String> _getTopEventTypes(
    List<Map<String, dynamic>> events, [
    int limit = 3,
  ]) {
    final counts = _countByType(events);
    final sorted =
        counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    return sorted.take(limit).map((e) => e.key).toList();
  }

  // Extract user patterns
  static List<Map<String, dynamic>> _extractUserPatterns(
    List<Map<String, dynamic>> events,
    List<Map<String, dynamic>> users,
  ) {
    final userEvents = <String, List<Map<String, dynamic>>>{};

    for (final event in events) {
      final userId = event['userId']?.toString();
      if (userId != null) {
        userEvents.putIfAbsent(userId, () => []).add(event);
      }
    }

    final patterns = <Map<String, dynamic>>[];

    for (final entry in userEvents.entries.take(5)) {
      final userId = entry.key;
      final userEvents = entry.value;

      final lastEvent = userEvents.isNotEmpty ? userEvents.last : null;

      final lastActive =
          lastEvent != null
              ? DateFormat(
                'MMM dd, HH:mm',
              ).format(_parseTimestamp(lastEvent['timestamp']))
              : 'Never';

      final criticalCount =
          userEvents.where((e) {
            final type = e['type']?.toString().toUpperCase() ?? '';
            return type.contains('FALL') || type.contains('SOS');
          }).length;

      patterns.add({
        'user': userId.length > 8 ? '${userId.substring(0, 8)}...' : userId,
        'events': userEvents.length,
        'critical': criticalCount,
        'lastActive': lastActive,
      });
    }

    return patterns;
  }

  // Extract temperature anomalies
  static String _extractTemperatureAnomalies(
    List<Map<String, dynamic>> events,
  ) {
    final tempEvents =
        events.where((e) {
          final type = e['type']?.toString().toUpperCase() ?? '';
          return type.contains('TEMP') || type.contains('ENVIRONMENT');
        }).toList();

    if (tempEvents.isEmpty) return 'No temperature data';

    final highTemps =
        tempEvents.where((e) {
          final data = e['data'];
          if (data is Map) {
            final temp = double.tryParse(
              data['temperature']?.toString() ?? '0',
            );
            return temp != null && temp > 30.0;
          }
          return false;
        }).length;

    return '$highTemps events >30°C';
  }

  // Extract air quality issues
  static String _extractAirQualityIssues(List<Map<String, dynamic>> events) {
    final aqEvents =
        events.where((e) {
          final type = e['type']?.toString().toUpperCase() ?? '';
          return type.contains('AQI') ||
              (e['data'] is Map && e['data']['aqi'] != null);
        }).toList();

    if (aqEvents.isEmpty) return 'No air quality data';

    final poorAirQuality =
        aqEvents.where((e) {
          final data = e['data'];
          if (data is Map) {
            final aqi = int.tryParse(data['aqi']?.toString() ?? '0');
            return aqi != null && aqi > 100;
          }
          return false;
        }).length;

    return '$poorAirQuality events with AQI >100';
  }

  // Extract mood trends
  static String _extractMoodTrends(List<Map<String, dynamic>> events) {
    final moodEvents =
        events.where((e) {
          final type = e['type']?.toString().toUpperCase() ?? '';
          return type.contains('MOOD');
        }).toList();

    if (moodEvents.isEmpty) return 'No mood data available';

    final moodCounts = <String, int>{};
    for (final event in moodEvents) {
      final data = event['data'];
      if (data is Map) {
        final mood = data['mood']?.toString().toLowerCase() ?? 'neutral';
        moodCounts[mood] = (moodCounts[mood] ?? 0) + 1;
      }
    }

    final totalMoods = moodCounts.values.fold(0, (sum, count) => sum + count);
    final anxiousPct =
        moodCounts['anxious'] != null
            ? (moodCounts['anxious']! / totalMoods * 100).toStringAsFixed(1)
            : '0.0';

    final topMood =
        moodCounts.entries.isNotEmpty
            ? moodCounts.entries.reduce((a, b) => a.value > b.value ? a : b).key
            : 'none';

    return 'Total mood logs: $totalMoods | Most common: $topMood | Anxious: ${anxiousPct}%';
  }

  // Generate fallback summary if AI fails
  static String _generateFallbackSummary({
    required List<Map<String, dynamic>> events,
    required List<Map<String, dynamic>> alerts,
    required Map<String, dynamic> analytics,
    required String timeRange,
  }) {
    // Extract values with type safety
    final fallsDetected = _extractIntFromAnalytics(
      analytics,
      'fallsDetected',
      'fallCount',
      'fallCount',
    );
    final sosTriggers = _extractIntFromAnalytics(
      analytics,
      'sosTriggers',
      'sosCount',
      'sosCount',
    );
    final environmentalAlerts = _extractIntFromAnalytics(
      analytics,
      'environmentalAlerts',
      'envCount',
    );
    final moodLogs = _extractIntFromAnalytics(
      analytics,
      'moodLogs',
      'moodEvents',
    );

    final criticalEvents = fallsDetected + sosTriggers;

    return '''
**Executive Summary:**
Health monitoring data for $timeRange shows $criticalEvents critical events requiring attention. Patient safety remains the primary concern with $fallsDetected fall incidents and $sosTriggers SOS alerts triggered during this period.

**Key Findings:**
- **Fall incidents detected:** $fallsDetected requiring immediate review
- **SOS alerts activated:** $sosTriggers emergency calls
- **Environmental alerts:** $environmentalAlerts environmental factors recorded
- **Mood assessments:** $moodLogs wellness check-ins completed

**Risk Assessment:**
${_getRiskAssessment(fallsDetected, sosTriggers)}

**Actionable Recommendations:**
${_getRecommendations(fallsDetected, sosTriggers, environmentalAlerts)}

**Monitoring Priorities:**
1. ${fallsDetected > 0 ? 'High-risk patients with multiple fall incidents' : 'General patient safety monitoring'}
2. Environmental adjustments for comfort and safety
3. Regular wellness check-in reinforcement
''';
  }

  // Helper for risk assessment
  static String _getRiskAssessment(int fallsDetected, int sosTriggers) {
    final totalCritical = fallsDetected + sosTriggers;

    if (totalCritical >= 10) {
      return '- **High Risk:** Significant safety concerns with $totalCritical critical events';
    } else if (totalCritical >= 5) {
      return '- **Medium Risk:** Moderate safety concerns requiring attention';
    } else if (totalCritical > 0) {
      return '- **Low Risk:** Minor safety events observed';
    } else {
      return '- **No Critical Risk:** No falls or SOS events detected';
    }
  }

  // Helper for recommendations
  static String _getRecommendations(
    int fallsDetected,
    int sosTriggers,
    int environmentalAlerts,
  ) {
    final recommendations = <String>[];

    if (fallsDetected > 0) {
      recommendations.add(
        'Review $fallsDetected fall incidents for common patterns (time, location, activity)',
      );
    }

    if (sosTriggers > 0) {
      recommendations.add(
        'Follow up with patients showing $sosTriggers SOS activations',
      );
    }

    if (environmentalAlerts > 0) {
      recommendations.add(
        'Check environmental controls for $environmentalAlerts temperature and air quality issues',
      );
    }

    recommendations.add(
      'Schedule wellness checks for patients with limited engagement',
    );
    recommendations.add('Review system alerts and response times');

    return recommendations.map((rec) => '1. $rec').join('\n');
  }

  // Helper to parse timestamps
  static DateTime _parseTimestamp(dynamic timestamp) {
    try {
      if (timestamp is DateTime) return timestamp;
      if (timestamp is String) {
        // Try parsing ISO string
        final parsed = DateTime.tryParse(timestamp);
        if (parsed != null) return parsed;

        // Try parsing from milliseconds
        final millis = int.tryParse(timestamp);
        if (millis != null) {
          return DateTime.fromMillisecondsSinceEpoch(millis);
        }
      }
      if (timestamp is int) {
        return DateTime.fromMillisecondsSinceEpoch(timestamp);
      }
      return DateTime.now();
    } catch (e) {
      debugPrint('Error parsing timestamp $timestamp: $e');
      return DateTime.now();
    }
  }
}
