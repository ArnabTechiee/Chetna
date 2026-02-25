import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';
import '../sensor_service.dart';
import 'profile_view.dart';

class ChetnaAIView extends StatefulWidget {
  final SensorService sensorService;
  const ChetnaAIView({super.key, required this.sensorService});

  @override
  State<ChetnaAIView> createState() => _ChetnaAIViewState();
}

class _ChetnaAIViewState extends State<ChetnaAIView> {
  StreamSubscription? _wellnessSub;
  StreamSubscription? _fallSub;
  StreamSubscription? _connectivitySub; // Added this line
  String _currentDiagnosis = "Analyzing...";
  bool _isConnected = true;

  @override
  void initState() {
    super.initState();
    _wellnessSub = widget.sensorService.wellnessStream.listen((status) {
      if (mounted) setState(() => _currentDiagnosis = status);
    });

    _fallSub = widget.sensorService.fallStream.listen((isFall) {
      if (isFall && mounted && !widget.sensorService.isDialogShowing) {
        _showFallCountdownDialog();
      }
    });

    // FIXED: Created separate subscription for connectivity
    _connectivitySub = widget.sensorService.connectivityStream.listen((
      isConnected,
    ) {
      if (mounted) setState(() => _isConnected = isConnected);
    });
  }

  void _showFallCountdownDialog() {
    widget.sensorService.isDialogShowing = true;
    int seconds = 15;
    Timer? timer;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          timer ??= Timer.periodic(const Duration(seconds: 1), (t) {
            if (seconds > 0) {
              if (mounted) setDialogState(() => seconds--);
            } else {
              t.cancel();
              Navigator.pop(context);
              widget.sensorService.triggerImmediateSOS(isManual: false);
              _showStickySOSPanel();
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
                  "Impact Detected",
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
                  "Triggering SOS in",
                  style: TextStyle(color: Color(0xFF64748B), fontSize: 14),
                ),
                SizedBox(height: 8),
                Text(
                  "$seconds seconds",
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFDC2626),
                  ),
                ),
                SizedBox(height: 16),
                LinearProgressIndicator(
                  value: (15 - seconds) / 15,
                  backgroundColor: Color(0xFFE2E8F0),
                  color: Color(0xFFDC2626),
                  minHeight: 6,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  timer?.cancel();
                  widget.sensorService.isPendingAlert = false;
                  widget.sensorService.isDialogShowing = false;
                  widget.sensorService.resetFallDetection();
                  Navigator.pop(context);
                },
                child: Text(
                  "I AM OKAY",
                  style: TextStyle(
                    color: Color(0xFF10B981),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showStickySOSPanel() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Container(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 60,
              height: 4,
              decoration: BoxDecoration(
                color: Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            SizedBox(height: 24),
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Color(0xFFFEE2E2),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.emergency, color: Color(0xFFDC2626), size: 40),
            ),
            SizedBox(height: 16),
            Text(
              "EMERGENCY ACTIVE",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Color(0xFFDC2626),
              ),
            ),
            SizedBox(height: 8),
            Text(
              "SMS alert sent to caregiver",
              style: TextStyle(color: Color(0xFF64748B), fontSize: 14),
            ),
            SizedBox(height: 24),
            Container(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  final Uri url = Uri.parse("https://maps.google.com");
                  if (!await launchUrl(
                    url,
                    mode: LaunchMode.externalApplication,
                  )) {
                    debugPrint("Could not launch maps");
                  }
                },
                icon: Icon(Icons.location_on, size: 20),
                label: Text("View Live Location"),
                style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  side: BorderSide(color: Color(0xFFDC2626)),
                ),
              ),
            ),
            SizedBox(height: 12),
            Container(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  await widget.sensorService.resolveSOS();
                  Navigator.pop(context);
                  _showSOSResolvedSuccess();
                },
                icon: Icon(Icons.check, size: 20),
                label: Text("I Am Safe - Resolve"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFFDC2626),
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showSOSResolvedSuccess() {
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
          "Do you want to notify caregivers that this was a false alarm?",
          style: TextStyle(color: Color(0xFF64748B)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Close", style: TextStyle(color: Color(0xFF64748B))),
          ),
          if (widget.sensorService.isSmsEnabled)
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF10B981),
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.pop(context);
                widget.sensorService.sendSafeMessage();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text("Safe message sent"),
                    backgroundColor: Color(0xFF10B981),
                  ),
                );
              },
              icon: Icon(Icons.message, size: 18),
              label: Text("Text 'I Am Safe'"),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF8FAFC),
      appBar: AppBar(
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
            Text("AI Insights"),
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
          IconButton(
            icon: Icon(Icons.person_outline),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      ChetnaProfileView(sensorService: widget.sensorService),
                ),
              );
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          widget.sensorService.triggerImmediateSOS(isManual: true);
          _showStickySOSPanel();
        },
        backgroundColor: Color(0xFFDC2626),
        icon: Icon(Icons.emergency, color: Colors.white),
        label: Text("SOS"),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            _buildFocusTimer(),
            SizedBox(height: 20),
            _buildControlsSection(),
            SizedBox(height: 20),
            _buildMoodCalendar(),
            SizedBox(height: 20),
            _buildDiagnosisCard(),
            SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _buildFocusTimer() {
    return StreamBuilder<int>(
      stream: widget.sensorService.focusTimeStream,
      initialData: 0,
      builder: (context, snapshot) {
        final seconds = snapshot.data ?? 0;
        final isActive = widget.sensorService.isFocusSessionActive;

        return Card(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "FOCUS SESSION",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF64748B),
                        letterSpacing: 1,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      "${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}",
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    if (isActive) SizedBox(height: 4),
                    if (isActive)
                      Text(
                        "AI monitoring environment",
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF10B981),
                        ),
                      ),
                  ],
                ),
                // FIXED: Changed IconButton.filled to regular IconButton with filled style
                IconButton(
                  onPressed: () {
                    setState(() => widget.sensorService.toggleFocusSession());
                  },
                  icon: Icon(
                    isActive ? Icons.stop : Icons.play_arrow,
                    color: Colors.white,
                  ),
                  style: IconButton.styleFrom(
                    backgroundColor: Color(0xFF2563EB),
                    padding: EdgeInsets.all(16),
                    // Removed 'size' parameter and added iconSize instead
                    iconSize: 24,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildControlsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "CONTROL CENTER",
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF64748B),
            letterSpacing: 1,
          ),
        ),
        SizedBox(height: 12),
        Card(
          child: Column(
            children: [
              _buildControlRow(
                title: "Guardian Siren",
                subtitle: "Audible emergency alert",
                icon: Icons.campaign,
                color: Color(0xFFDC2626),
                value: widget.sensorService.isSirenEnabled,
                onChanged: (v) =>
                    setState(() => widget.sensorService.toggleSiren()),
              ),
              Divider(height: 1, color: Color(0xFFF1F5F9)),
              _buildControlRow(
                title: "SMS Alerts",
                subtitle: "Notify caregivers on SOS",
                icon: Icons.sms,
                color: Color(0xFF10B981),
                value: widget.sensorService.isSmsEnabled,
                onChanged: (v) =>
                    setState(() => widget.sensorService.toggleSms()),
              ),
              Divider(height: 1, color: Color(0xFFF1F5F9)),
              _buildControlRow(
                title: "Smart-Hush Shield",
                subtitle: "White noise for sensory relief",
                icon: Icons.hearing,
                color: Color(0xFF3B82F6),
                value: widget.sensorService.isHushEnabled,
                onChanged: (v) =>
                    setState(() => widget.sensorService.toggleHush()),
              ),
              Divider(height: 1, color: Color(0xFFF1F5F9)),
              _buildControlRow(
                title: "AI Monitoring",
                subtitle: "Environmental analysis",
                icon: Icons.psychology,
                color: Color(0xFF8B5CF6),
                value: widget.sensorService.isAiEnabled,
                onChanged: (v) =>
                    setState(() => widget.sensorService.toggleAi()),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildControlRow({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required bool value,
    required Function(bool) onChanged,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 14,
          color: Color(0xFF1E293B),
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
      ),
      trailing: Switch(value: value, activeColor: color, onChanged: onChanged),
    );
  }

  Widget _buildMoodCalendar() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "MOOD TRACKER",
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF64748B),
            letterSpacing: 1,
          ),
        ),
        SizedBox(height: 12),
        Card(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: TableCalendar(
              firstDay: DateTime.now().subtract(Duration(days: 30)),
              lastDay: DateTime.now().add(Duration(days: 30)),
              focusedDay: DateTime.now(),
              calendarFormat: CalendarFormat.week,
              headerStyle: HeaderStyle(
                formatButtonVisible: false,
                titleCentered: true,
                titleTextStyle: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1E293B),
                ),
                leftChevronIcon: Icon(Icons.chevron_left, size: 20),
                rightChevronIcon: Icon(Icons.chevron_right, size: 20),
              ),
              calendarStyle: CalendarStyle(
                todayDecoration: BoxDecoration(
                  color: Color(0xFF2563EB),
                  shape: BoxShape.circle,
                ),
                selectedDecoration: BoxDecoration(
                  color: Color(0xFF2563EB).withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                // FIXED: Changed 'size' to 'radius' in markerDecoration
                markerDecoration: BoxDecoration(
                  color: Color(0xFF10B981),
                  shape: BoxShape.circle,
                ),
                markersMaxCount: 1,
              ),
              eventLoader: (day) {
                if (day.day == DateTime.now().subtract(Duration(days: 1)).day) {
                  return ['Stressed'];
                }
                if (day.day == DateTime.now().subtract(Duration(days: 2)).day) {
                  return ['Happy'];
                }
                if (day.day == DateTime.now().subtract(Duration(days: 3)).day) {
                  return ['Calm'];
                }
                return [];
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDiagnosisCard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "ENVIRONMENTAL DIAGNOSIS",
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF64748B),
            letterSpacing: 1,
          ),
        ),
        SizedBox(height: 12),
        Card(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              children: [
                Icon(
                  widget.sensorService.isAiEnabled
                      ? Icons.psychology
                      : Icons.pause_circle,
                  size: 40,
                  color: widget.sensorService.isAiEnabled
                      ? Color(0xFF8B5CF6)
                      : Color(0xFF94A3B8),
                ),
                SizedBox(height: 16),
                Text(
                  widget.sensorService.isAiEnabled
                      ? _currentDiagnosis.toUpperCase()
                      : "MONITORING PAUSED",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: widget.sensorService.isAiEnabled
                        ? Color(0xFF1E293B)
                        : Color(0xFF94A3B8),
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  widget.sensorService.isAiEnabled
                      ? "AI Fusion Analysis Active"
                      : "Environmental monitoring disabled",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF64748B), fontSize: 14),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _wellnessSub?.cancel();
    _fallSub?.cancel();
    _connectivitySub?.cancel(); // Added this line
    super.dispose();
  }
}
