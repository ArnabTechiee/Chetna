// models/stats_model.dart
class StatsModel {
  final int totalUsers;
  final int activeUsers;
  final int fallsToday;
  final int sosToday;
  final String systemUptime;
  final String avgResponseTime;

  StatsModel({
    required this.totalUsers,
    required this.activeUsers,
    required this.fallsToday,
    required this.sosToday,
    required this.systemUptime,
    required this.avgResponseTime,
  });
}
