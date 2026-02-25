// widgets/charts/pie_chart.dart - A++ PROFESSIONAL VERSION
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

class EnhancedEventPieChart extends StatelessWidget {
  final List<Map<String, dynamic>> events;

  const EnhancedEventPieChart({super.key, required this.events});

  @override
  Widget build(BuildContext context) {
    // Process event data for chart
    final now = DateTime.now();
    final yesterday = now.subtract(const Duration(days: 1));
    final recentEvents =
        events.where((e) {
          final timestamp = e['timestamp'] as DateTime;
          return timestamp.isAfter(yesterday);
        }).toList();

    Map<String, int> eventCounts = {};
    for (var event in recentEvents) {
      final type = event['type'].toString();
      eventCounts[type] = (eventCounts[type] ?? 0) + 1;
    }

    List<ChartData> chartData = [];
    eventCounts.forEach((type, count) {
      chartData.add(
        ChartData(_getDisplayName(type), count, _getChartColor(type)),
      );
    });

    // Sort by count
    chartData.sort((a, b) => b.y.compareTo(a.y));

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: SfCircularChart(
        margin: const EdgeInsets.all(0),
        legend: Legend(
          isVisible: true,
          position: LegendPosition.bottom,
          overflowMode: LegendItemOverflowMode.wrap,
          textStyle: const TextStyle(
            fontSize: 12,
            color: Color(0xFF64748B),
            fontWeight: FontWeight.w500,
          ),
          iconHeight: 12,
          iconWidth: 12,
        ),
        series: <CircularSeries>[
          DoughnutSeries<ChartData, String>(
            dataSource: chartData,
            xValueMapper: (ChartData data, _) => data.x,
            yValueMapper: (ChartData data, _) => data.y,
            pointColorMapper: (ChartData data, _) => data.color,
            dataLabelSettings: const DataLabelSettings(
              isVisible: true,
              labelPosition: ChartDataLabelPosition.inside,
              textStyle: TextStyle(
                fontSize: 11,
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
              showCumulativeValues: true,
            ),
            radius: '70%',
            innerRadius: '40%',
            explode: true,
            explodeOffset: '10%',
            explodeGesture: ActivationMode.singleTap,
          ),
        ],
        tooltipBehavior: TooltipBehavior(
          enable: true,
          format: 'point.x: point.y events',
          color: const Color(0xFF1E293B),
          textStyle: const TextStyle(color: Colors.white, fontSize: 12),
        ),
      ),
    );
  }

  String _getDisplayName(String type) {
    switch (type) {
      case 'FALL_DETECTED':
        return 'Falls';
      case 'SOS_TRIGGERED':
        return 'SOS Alerts';
      case 'ENVIRONMENT_DIAGNOSIS':
        return 'Environment';
      case 'MOOD_LOG':
        return 'Mood Logs';
      case 'GEOFENCE_BREACH':
        return 'Geofence';
      default:
        return 'Other';
    }
  }

  Color _getChartColor(String type) {
    switch (type) {
      case 'FALL_DETECTED':
        return const Color(0xFFDC2626);
      case 'SOS_TRIGGERED':
        return const Color(0xFFF59E0B);
      case 'ENVIRONMENT_DIAGNOSIS':
        return const Color(0xFF0A4DA2);
      case 'MOOD_LOG':
        return const Color(0xFF10B981);
      case 'GEOFENCE_BREACH':
        return const Color(0xFF8B5CF6);
      default:
        return const Color(0xFF94A3B8);
    }
  }
}

class ChartData {
  final String x;
  final int y;
  final Color color;

  ChartData(this.x, this.y, this.color);
}
