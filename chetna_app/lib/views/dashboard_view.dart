import 'dart:async';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:vibration/vibration.dart';
import 'package:url_launcher/url_launcher.dart';
import '../sensor_service.dart';
import '../models/chart_data.dart';

class ChetnaDashboard extends StatefulWidget {
  final SensorService sensorService;
  const ChetnaDashboard({super.key, required this.sensorService});

  @override
  State<ChetnaDashboard> createState() => _ChetnaDashboardState();
}

class _ChetnaDashboardState extends State<ChetnaDashboard> {
  final List<ChartData> _data = [];
  ChartSeriesController? _chartController;
  final List<StreamSubscription> _subs = [];

  int _lux = 0;
  double _noise = 0.0;
  bool _sosSent = false;
  bool _isProcessingSOS = false;
  int _okayPressCount = 0;
  bool _isConnected = true;

  @override
  void initState() {
    super.initState();
    _initSubscriptions();
  }

  void _initSubscriptions() {
    _subs.add(
      widget.sensorService.lightStream.listen((l) {
        if (mounted) setState(() => _lux = l);
      }),
    );
    _subs.add(
      widget.sensorService.noiseUIStream.listen((n) {
        if (mounted) setState(() => _noise = n);
      }),
    );
    _subs.add(widget.sensorService.accelerationStream.listen(_updateChart));

    _subs.add(
      widget.sensorService.connectivityStream.listen((isConnected) {
        if (mounted) setState(() => _isConnected = isConnected);
      }),
    );

    _subs.add(
      widget.sensorService.wellnessStream.listen((status) {
        if (widget.sensorService.isMonitoringEnabled &&
            status != "Ideal/Healthy") {
          _showWellnessNotification(status);
        }
      }),
    );

    _subs.add(
      widget.sensorService.fallStream.listen((f) {
        if (f == true && !widget.sensorService.isDialogShowing && !_sosSent) {
          _showEmergencyDialog();
        }
      }),
    );
  }

  void _updateChart(double val) {
    if (!mounted || _chartController == null) return;

    setState(() {
      _data.add(ChartData(DateTime.now(), val));
      if (_data.length > 30) {
        _data.removeAt(0);
        _chartController?.updateDataSource(
          addedDataIndex: _data.length - 1,
          removedDataIndex: 0,
        );
      } else {
        _chartController?.updateDataSource(addedDataIndex: _data.length - 1);
      }
    });
  }

  void _showWellnessNotification(String status) {
    if (!mounted) return;

    final snackBar = SnackBar(
      content: Row(
        children: [
          Icon(Icons.health_and_safety, color: Colors.white, size: 20),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              "AI Alert: $status Detected",
              style: TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 14,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
      backgroundColor: Color(0xFF2563EB),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
      duration: const Duration(seconds: 4),
    );

    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

  Future<void> _triggerSOS() async {
    setState(() => _isProcessingSOS = true);
    try {
      await widget.sensorService.triggerImmediateSOS(isManual: false);
      if (mounted) {
        setState(() {
          _sosSent = true;
          _isProcessingSOS = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isProcessingSOS = false);
    }
  }

  void _showEmergencyDialog() {
    if (widget.sensorService.isDialogShowing) return;

    int countdown = 15;
    _okayPressCount = 0;
    Timer? timer;

    widget.sensorService.isDialogShowing = true;
    widget.sensorService.stopVibration();
    Vibration.vibrate(duration: 500);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          timer ??= Timer.periodic(const Duration(seconds: 1), (t) {
            if (countdown > 0) {
              setDialogState(() => countdown--);
            } else {
              t.cancel();
              Navigator.pop(dialogContext, 'trigger');
            }
          });

          return AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            title: Column(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Color(0xFFFEF2F2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.warning_amber_rounded,
                    color: Color(0xFFDC2626),
                    size: 32,
                  ),
                ),
                SizedBox(height: 16),
                Text(
                  "Fall Detected!",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "SOS will trigger in",
                  style: TextStyle(color: Color(0xFF64748B), fontSize: 14),
                ),
                SizedBox(height: 8),
                Text(
                  "$countdown",
                  style: TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFDC2626),
                  ),
                ),
                SizedBox(height: 16),
                LinearProgressIndicator(
                  value: (15 - countdown) / 15,
                  backgroundColor: Color(0xFFE2E8F0),
                  color: Color(0xFFDC2626),
                  minHeight: 6,
                ),
                SizedBox(height: 16),
                Text(
                  "Tap 'I'm Safe' 3 times to cancel",
                  style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
                ),
              ],
            ),
            actions: [
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        setDialogState(() => _okayPressCount++);
                        if (_okayPressCount >= 3) {
                          Navigator.pop(dialogContext, 'cancel');
                        }
                      },
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        side: BorderSide(color: Color(0xFF10B981)),
                      ),
                      child: Text(
                        "I'M SAFE (${3 - _okayPressCount})",
                        style: TextStyle(
                          color: Color(0xFF10B981),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    ).then((result) {
      timer?.cancel();
      widget.sensorService.stopVibration();
      widget.sensorService.isDialogShowing = false;
      widget.sensorService.resetFallDetection();

      if (result == 'trigger') {
        _triggerSOS();
      } else if (result == 'cancel') {
        widget.sensorService.resolveSOS();
      }

      if (mounted) setState(() => _okayPressCount = 0);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF8FAFC),
      appBar: AppBar(
        elevation: 0,
        title: Row(
          children: [
            // App Icon on top-left side
            Container(
              width: 32,
              height: 32,
              margin: EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.white.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(7),
                child: Image.asset(
                  "assets/icon/app_icon.jpeg",
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    // Fallback if image fails to load
                    return Container(
                      color: Color(0xFF2563EB),
                      child: Icon(
                        Icons.medical_services,
                        size: 18,
                        color: Colors.white,
                      ),
                    );
                  },
                ),
              ),
            ),
            Text("Chetna Health Monitor"),
          ],
        ),
        actions: [
          Container(
            margin: EdgeInsets.only(right: 16),
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _isConnected ? Color(0xFFD1FAE5) : Color(0xFFFEE2E2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Icon(
                  _isConnected ? Icons.cloud_done : Icons.cloud_off,
                  size: 14,
                  color: _isConnected ? Color(0xFF10B981) : Color(0xFFDC2626),
                ),
                SizedBox(width: 4),
                Text(
                  _isConnected ? "Online" : "Offline",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: _isConnected ? Color(0xFF10B981) : Color(0xFFDC2626),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            _buildStatusCard(),
            if (_isProcessingSOS) _buildSOSProgress(),
            if (_sosSent) _buildSOSActiveCard(),
            SizedBox(height: 20),
            _buildVitalsGrid(),
            SizedBox(height: 20),
            _buildActivityChart(),
            SizedBox(height: 20),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showMoodPicker,
        icon: Icon(Icons.mood, color: Colors.white),
        label: Text("Log Mood"),
        backgroundColor: Color(0xFF2563EB),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  Widget _buildStatusCard() {
    return StreamBuilder<bool>(
      stream: widget.sensorService.fallStream,
      builder: (context, snapshot) {
        final isFall = snapshot.data ?? false;
        return Card(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: isFall ? Color(0xFFFEF2F2) : Color(0xFFF0F9FF),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isFall ? Icons.warning : Icons.verified_user,
                    color: isFall ? Color(0xFFDC2626) : Color(0xFF0EA5E9),
                    size: 24,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isFall ? "Attention Required" : "All Systems Normal",
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        isFall
                            ? "Fall detected. System monitoring"
                            : "AI protection active",
                        style: TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    "Live",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSOSProgress() {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      child: LinearProgressIndicator(
        backgroundColor: Color(0xFFFEE2E2),
        color: Color(0xFFDC2626),
        minHeight: 3,
      ),
    );
  }

  Widget _buildSOSActiveCard() {
    return Card(
      color: Color(0xFFDC2626),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Icon(Icons.emergency, color: Colors.white, size: 24),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    "SOS ACTIVE • Emergency Alert Sent",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => launchUrl(
                      Uri.parse("https://maps.google.com"),
                      mode: LaunchMode.externalApplication,
                    ),
                    icon: Icon(Icons.location_on, size: 16),
                    label: Text("View Location"),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: BorderSide(color: Colors.white),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      await widget.sensorService.resolveSOS();
                      setState(() => _sosSent = false);
                      _showResolvedDialog();
                    },
                    icon: Icon(Icons.check, size: 16),
                    label: Text("Resolve"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Color(0xFFDC2626),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVitalsGrid() {
    return StreamBuilder<Map<String, dynamic>>(
      stream: widget.sensorService.envDataStream,
      builder: (context, snapshot) {
        final env = snapshot.data ?? {'temp': 25.0, 'aqi': 1};
        final temp = env['temp'] ?? 25.0;
        final aqi = env['aqi'] ?? 1;

        return GridView.count(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.2,
          children: [
            _buildVitalCard(
              title: "Temperature",
              value: "${temp.toStringAsFixed(1)}°C",
              icon: Icons.thermostat,
              color: Color(0xFFF97316),
              unit: "Normal",
            ),
            _buildVitalCard(
              title: "Air Quality",
              value: "AQI $aqi",
              icon: Icons.air,
              color: Color(0xFF10B981),
              unit: _getAQILevel(aqi),
            ),
            _buildVitalCard(
              title: "Light Level",
              value: "$_lux Lx",
              icon: Icons.light_mode,
              color: Color(0xFFF59E0B),
              unit: _getLightLevel(_lux),
            ),
            _buildVitalCard(
              title: "Noise Level",
              value: "${_noise.toStringAsFixed(0)} dB",
              icon: Icons.volume_up,
              color: Color(0xFF3B82F6),
              unit: _getNoiseLevel(_noise),
            ),
          ],
        );
      },
    );
  }

  Widget _buildVitalCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required String unit,
  }) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    unit,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1E293B),
              ),
            ),
            SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityChart() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Activity Signature (G-Force)",
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: Color(0xFF1E293B),
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    "Real-time",
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: SfCartesianChart(
                margin: EdgeInsets.zero,
                primaryXAxis: DateTimeAxis(
                  majorGridLines: MajorGridLines(width: 0),
                  labelStyle: TextStyle(fontSize: 10),
                ),
                primaryYAxis: NumericAxis(
                  maximum: 3.5,
                  minimum: 0.0,
                  interval: 0.5,
                  labelStyle: TextStyle(fontSize: 10),
                  plotBands: <PlotBand>[
                    PlotBand(
                      start: 2.5,
                      end: 3.5,
                      color: Color(0xFFFEE2E2).withOpacity(0.3),
                      text: 'Alert Zone',
                      textStyle: TextStyle(
                        color: Color(0xFFDC2626),
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                series: <SplineAreaSeries<ChartData, DateTime>>[
                  SplineAreaSeries(
                    onRendererCreated: (c) => _chartController = c,
                    dataSource: _data,
                    xValueMapper: (ChartData d, _) => d.timestamp,
                    yValueMapper: (ChartData d, _) => d.value,
                    gradient: LinearGradient(
                      colors: [
                        Color(0xFF2563EB).withOpacity(0.2),
                        Colors.transparent,
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    borderColor: Color(0xFF2563EB),
                    borderWidth: 2,
                    color: Colors.transparent,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showResolvedDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.check_circle, color: Color(0xFF10B981), size: 24),
            SizedBox(width: 12),
            Text("SOS Resolved", style: TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
        content: Text(
          "Emergency alert has been deactivated.",
          style: TextStyle(color: Color(0xFF64748B)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Close", style: TextStyle(color: Color(0xFF64748B))),
          ),
          if (widget.sensorService.isSmsEnabled)
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                widget.sensorService.sendSafeMessage();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text("Safe message sent to caregiver"),
                    backgroundColor: Color(0xFF10B981),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF10B981),
                foregroundColor: Colors.white,
              ),
              child: Text("Notify Caregiver"),
            ),
        ],
      ),
    );
  }

  void _showMoodPicker() {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Container(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "How are you feeling?",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1E293B),
              ),
            ),
            SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildMoodOption(
                  Icons.sentiment_very_satisfied,
                  "Great",
                  Colors.green,
                ),
                _buildMoodOption(
                  Icons.sentiment_satisfied,
                  "Good",
                  Colors.blue,
                ),
                _buildMoodOption(Icons.sentiment_neutral, "Okay", Colors.amber),
                _buildMoodOption(
                  Icons.sentiment_dissatisfied,
                  "Stressed",
                  Colors.orange,
                ),
                _buildMoodOption(
                  Icons.sentiment_very_dissatisfied,
                  "Anxious",
                  Colors.red,
                ),
              ],
            ),
            SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildMoodOption(IconData icon, String label, Color color) {
    return Column(
      children: [
        IconButton(
          onPressed: () {
            widget.sensorService.logMood(label);
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text("Mood logged: $label"),
                backgroundColor: Color(0xFF2563EB),
              ),
            );
          },
          icon: Icon(icon, size: 32),
          color: color,
        ),
        SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
      ],
    );
  }

  String _getAQILevel(int aqi) {
    if (aqi == 1) return "Excellent";
    if (aqi <= 3) return "Fair";
    return "Poor";
  }

  String _getLightLevel(int lux) {
    if (lux < 100) return "Low";
    if (lux < 500) return "Normal";
    if (lux < 1500) return "Bright";
    return "Very Bright";
  }

  String _getNoiseLevel(double db) {
    if (db < 40) return "Quiet";
    if (db < 70) return "Normal";
    if (db < 85) return "Loud";
    return "Very Loud";
  }

  @override
  void dispose() {
    for (var s in _subs) {
      s.cancel();
    }
    super.dispose();
  }
}
