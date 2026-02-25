// widgets/charts/line_chart.dart - A++ PROFESSIONAL VERSION
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

class EnhancedEventLineChart extends StatelessWidget {
  final List<Map<String, dynamic>> events;

  const EnhancedEventLineChart({super.key, required this.events});

  @override
  Widget build(BuildContext context) {
    // Group events by hour for last 24 hours
    final now = DateTime.now();
    final List<ChartData> chartData = [];

    for (int i = 23; i >= 0; i--) {
      final hourStart = now.subtract(Duration(hours: i));
      final hourEnd = hourStart.add(const Duration(hours: 1));

      final eventsInHour =
          events.where((e) {
            final timestamp = e['timestamp'] as DateTime;
            return timestamp.isAfter(hourStart) && timestamp.isBefore(hourEnd);
          }).length;

      chartData.add(ChartData('${hourStart.hour}:00', eventsInHour, hourStart));
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: SfCartesianChart(
        plotAreaBorderWidth: 0,
        primaryXAxis: CategoryAxis(
          labelStyle: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
          axisLine: const AxisLine(width: 0),
          majorGridLines: const MajorGridLines(width: 0),
          majorTickLines: const MajorTickLines(size: 0),
        ),
        primaryYAxis: NumericAxis(
          labelStyle: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
          axisLine: const AxisLine(width: 0),
          majorGridLines: const MajorGridLines(
            color: Color(0xFFF1F5F9),
            width: 1,
          ),
          majorTickLines: const MajorTickLines(size: 0),
        ),
        series: <CartesianSeries>[
          SplineAreaSeries<ChartData, String>(
            dataSource: chartData,
            xValueMapper: (ChartData data, _) => data.x,
            yValueMapper: (ChartData data, _) => data.y,
            gradient: LinearGradient(
              colors: [
                const Color(0xFF0A4DA2).withOpacity(0.3),
                const Color(0xFF4A6FA5).withOpacity(0.1),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderColor: const Color(0xFF0A4DA2),
            borderWidth: 2,
            markerSettings: const MarkerSettings(
              isVisible: true,
              shape: DataMarkerType.circle,
              borderWidth: 2,
              borderColor: Colors.white,
              color: Color(0xFF0A4DA2),
              height: 8,
              width: 8,
            ),
            dataLabelSettings: const DataLabelSettings(isVisible: false),
          ),
        ],
        tooltipBehavior: TooltipBehavior(
          enable: true,
          header: '',
          format: 'point.x\npoint.y events',
          color: const Color(0xFF1E293B),
          textStyle: const TextStyle(color: Colors.white, fontSize: 12),
        ),
      ),
    );
  }
}

class ChartData {
  final String x;
  final int y;
  final DateTime time;

  ChartData(this.x, this.y, this.time);
}
