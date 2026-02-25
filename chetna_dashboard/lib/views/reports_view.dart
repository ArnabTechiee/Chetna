// views/reports_view.dart - COMPLETE UPDATED VERSION WITH AI EXECUTIVE SUMMARY
import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import 'package:syncfusion_flutter_xlsio/xlsio.dart'
    hide Column, Row, Border, Stack;
import 'package:universal_html/html.dart' as html;
import 'package:shimmer/shimmer.dart';
import '../providers/dashboard_provider.dart';
import '../utils/constants.dart';
import '../services/ai_summary_service.dart'; // NEW IMPORT
import 'dart:math' as math;
import 'package:flutter/services.dart';

class ReportsView extends StatefulWidget {
  const ReportsView({super.key});

  @override
  State<ReportsView> createState() => _ReportsViewState();
}

class _ReportsViewState extends State<ReportsView> {
  String _reportType = 'daily_summary';
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 7));
  DateTime _endDate = DateTime.now();
  bool _isGenerating = false;
  bool _isExporting = false;
  Map<String, dynamic> _reportData = {};
  List<Map<String, dynamic>> _filteredEvents = [];
  List<Map<String, dynamic>> _filteredAlerts = [];
  String _selectedUserId = 'all';

  // NEW: AI Executive Summary state
  bool _isGeneratingSummary = false;
  String? _aiSummary;
  bool _showAISummary = false;

  // Report categories
  final List<String> _reportCategories = [
    'daily_summary',
    'safety_incidents',
    'wellness_analysis',
    'environmental',
    'user_activity',
    'system_audit',
  ];

  // Store scaffold key to safely show snackbars
  final GlobalKey<ScaffoldMessengerState> _scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();

  @override
  Widget build(BuildContext context) {
    return ScaffoldMessenger(
      key: _scaffoldMessengerKey,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Medical Reports & Analytics'),
          actions: [
            // NEW: AI Summary action button
            if (_reportData.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.psychology),
                onPressed: _generateAIExecutiveSummary,
                tooltip: 'AI Executive Summary',
              ),
            if (_reportData.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.print),
                onPressed: _printReport,
                tooltip: 'Print Report',
              ),
            IconButton(
              icon: const Icon(Icons.history),
              onPressed: _showReportHistory,
              tooltip: 'Report History',
            ),
          ],
        ),
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    return Stack(
      children: [
        Consumer<DashboardProvider>(
          builder: (context, provider, child) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Report Generator
                  _buildReportGenerator(provider),
                  const SizedBox(height: 24),

                  // Report Preview
                  if (_reportData.isNotEmpty) ...[
                    _buildReportPreview(),
                    const SizedBox(height: 24),
                  ],

                  // Report Templates
                  _buildReportTemplates(),
                  const SizedBox(height: 24),

                  // Export Options - UPDATED WITH AI SUMMARY
                  _buildExportOptions(),

                  // NEW: AI Summary Section (if available)
                  if (_aiSummary != null && _showAISummary) ...[
                    const SizedBox(height: 24),
                    _buildAISummaryCard(),
                  ],
                ],
              ),
            );
          },
        ),

        // AI Loading Overlay
        if (_isGeneratingSummary)
          Positioned.fill(
            child: Container(
              color: Colors.black.withOpacity(0.5),
              child: Center(child: _buildAILoadingOverlay()),
            ),
          ),
      ],
    );
  }

  // ==================== REPORT GENERATOR ====================
  Widget _buildReportGenerator(DashboardProvider provider) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.analytics, color: AppColors.primary),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Generate Medical Report',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        'Create comprehensive reports from real-time monitoring data',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // Report Configuration
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Report Configuration',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 16),

                // Date Range
                Row(
                  children: [
                    Expanded(
                      child: _buildDatePicker(
                        'Start Date',
                        _startDate,
                        (date) => setState(() => _startDate = date),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildDatePicker(
                        'End Date',
                        _endDate,
                        (date) => setState(() => _endDate = date),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // User Filter
                _buildUserFilter(provider),
                const SizedBox(height: 16),

                // Report Type Selector
                _buildReportTypeSelector(),
              ],
            ),
            const SizedBox(height: 32),

            // Generate Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed:
                    _isGenerating ? null : () => _generateReport(provider),
                icon:
                    _isGenerating
                        ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                        : const Icon(Icons.play_arrow),
                label: Text(
                  _isGenerating ? 'Analyzing Data...' : 'Generate Report',
                  style: const TextStyle(fontSize: 16),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserFilter(DashboardProvider provider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Filter by User',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _selectedUserId,
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
            fillColor: Colors.white,
            hintText: 'Select User',
          ),
          items: [
            const DropdownMenuItem(value: 'all', child: Text('All Users')),
            ...provider.users.map((user) {
              final name = user['name']?.toString() ?? 'Unknown User';
              return DropdownMenuItem(
                value: user['id']?.toString(),
                child: Text(name),
              );
            }).toList(),
          ],
          onChanged: (value) {
            setState(() => _selectedUserId = value ?? 'all');
          },
        ),
      ],
    );
  }

  Widget _buildReportTypeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Report Type',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children:
              _reportCategories.map((category) {
                final isSelected = _reportType == category;
                return ChoiceChip(
                  label: Text(_getReportTypeLabel(category)),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() => _reportType = category);
                  },
                  backgroundColor:
                      isSelected ? AppColors.primary : Colors.white,
                  selectedColor: AppColors.primary,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : AppColors.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(
                      color: isSelected ? AppColors.primary : AppColors.border,
                    ),
                  ),
                );
              }).toList(),
        ),
      ],
    );
  }

  String _getReportTypeLabel(String category) {
    switch (category) {
      case 'daily_summary':
        return 'Daily Summary';
      case 'safety_incidents':
        return 'Safety Incidents';
      case 'wellness_analysis':
        return 'Wellness Analysis';
      case 'environmental':
        return 'Environmental';
      case 'user_activity':
        return 'User Activity';
      case 'system_audit':
        return 'System Audit';
      default:
        return category;
    }
  }

  // ==================== REPORT PREVIEW ====================
  Widget _buildReportPreview() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Report Header
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.success.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.description,
                    color: AppColors.success,
                  ),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Report Preview',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        'Generated from real-time monitoring data',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.success.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_reportData['totalEvents'] ?? 0} Events',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.success,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Report Metadata
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildReportMeta(
                    'Period',
                    '${DateFormat('MMM dd').format(_startDate)} - ${DateFormat('MMM dd, yyyy').format(_endDate)}',
                  ),
                  _buildReportMeta(
                    'Users',
                    _selectedUserId == 'all'
                        ? 'All Users'
                        : _reportData['userName']?.toString() ??
                            'Specific User',
                  ),
                  _buildReportMeta(
                    'Generated',
                    DateFormat('MMM dd, hh:mm a').format(DateTime.now()),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Key Metrics
            const Text(
              'Key Metrics',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 4,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.5,
              children: [
                _buildMetricCard(
                  title: 'Total Events',
                  value: (_reportData['totalEvents'] ?? 0).toString(),
                  icon: Icons.event,
                  color: AppColors.primary,
                ),
                _buildMetricCard(
                  title: 'Critical Alerts',
                  value: (_reportData['criticalAlerts'] ?? 0).toString(),
                  icon: Icons.warning,
                  color: AppColors.danger,
                ),
                _buildMetricCard(
                  title: 'Falls Detected',
                  value: (_reportData['fallsDetected'] ?? 0).toString(),
                  icon: Icons.warning_amber,
                  color: AppColors.warning,
                ),
                _buildMetricCard(
                  title: 'SOS Triggers',
                  value: (_reportData['sosTriggers'] ?? 0).toString(),
                  icon: Icons.emergency,
                  color: AppColors.danger,
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Event Breakdown
            _buildEventBreakdown(),
            const SizedBox(height: 24),

            // Data Preview
            _buildDataPreview(),
          ],
        ),
      ),
    );
  }

  Widget _buildReportMeta(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildEventBreakdown() {
    final breakdown = _reportData['eventBreakdown'] as Map<String, int>? ?? {};
    final sortedEntries =
        breakdown.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Event Type Breakdown',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 16),
        ...sortedEntries.take(5).map((entry) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _formatEventType(entry.key),
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Container(
                  width: 40,
                  child: Text(
                    entry.value.toString(),
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: LinearProgressIndicator(
                    value:
                        entry.value /
                        (breakdown.values.reduce((a, b) => a + b)),
                    backgroundColor: AppColors.border,
                    color: _getEventColor(entry.key),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildDataPreview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Sample Data',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Showing ${_filteredEvents.take(5).length} of ${_filteredEvents.length} events',
          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: DataTable(
            columns: const [
              DataColumn(label: Text('Time')),
              DataColumn(label: Text('Type')),
              DataColumn(label: Text('User')),
              DataColumn(label: Text('Details')),
            ],
            rows:
                _filteredEvents.take(5).map((event) {
                  return DataRow(
                    cells: [
                      DataCell(Text(_formatTime(event['timestamp']))),
                      DataCell(
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: _getEventColor(
                              event['type'].toString(),
                            ).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            _formatEventType(event['type'].toString()),
                            style: TextStyle(
                              fontSize: 11,
                              color: _getEventColor(event['type'].toString()),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      DataCell(
                        Text(
                          event['userId']?.toString().substring(0, 8) ??
                              'Unknown',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                      DataCell(
                        Text(
                          _truncateText(
                            _getEventDetails(event) ?? 'No details',
                            20,
                          ),
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  );
                }).toList(),
          ),
        ),
      ],
    );
  }

  // ==================== REPORT TEMPLATES ====================
  Widget _buildReportTemplates() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Report Templates',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Generate pre-configured reports with one click',
          style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 20),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 3,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 2.5,
          children: [
            _buildTemplateCard(
              title: 'Daily Safety Report',
              subtitle: 'Falls, SOS, Emergencies',
              icon: Icons.security,
              color: AppColors.danger,
              onTap: () => _generateTemplateReport('safety'),
            ),
            _buildTemplateCard(
              title: 'Weekly Wellness',
              subtitle: 'Mood, Focus, Environment',
              icon: Icons.psychology,
              color: AppColors.success,
              onTap: () => _generateTemplateReport('wellness'),
            ),
            _buildTemplateCard(
              title: 'Monthly Audit',
              subtitle: 'System performance & usage',
              icon: Icons.assignment,
              color: AppColors.primary,
              onTap: () => _generateTemplateReport('audit'),
            ),
            _buildTemplateCard(
              title: 'Environmental Trends',
              subtitle: 'Temperature, AQI, Noise',
              icon: Icons.thermostat,
              color: AppColors.warning,
              onTap: () => _generateTemplateReport('environmental'),
            ),
            _buildTemplateCard(
              title: 'User Activity',
              subtitle: 'Usage patterns & engagement',
              icon: Icons.people,
              color: AppColors.info,
              onTap: () => _generateTemplateReport('user_activity'),
            ),
            _buildTemplateCard(
              title: 'Caregiver Summary',
              subtitle: 'Patient updates for caregivers',
              icon: Icons.health_and_safety,
              color: AppColors.secondary,
              onTap: () => _generateTemplateReport('caregiver'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTemplateCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: AppColors.textTertiary),
            ],
          ),
        ),
      ),
    );
  }

  // ==================== EXPORT OPTIONS - UPDATED WITH AI SUMMARY ====================
  Widget _buildExportOptions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Export & Share',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Export your report in various formats',
          style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 20),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 4,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 2.2,
          children: [
            // NEW: AI Executive Summary option
            _buildExportOption(
              label: 'AI Executive Summary',
              icon: Icons.psychology,
              color: Colors.purple,
              onTap: _generateAIExecutiveSummary,
            ),
            _buildExportOption(
              label: 'Export as PDF',
              icon: Icons.picture_as_pdf,
              color: AppColors.danger,
              onTap: () => _exportToPDF(),
            ),
            _buildExportOption(
              label: 'Export as Excel',
              icon: Icons.table_chart,
              color: AppColors.success,
              onTap: () => _exportToExcel(),
            ),
            _buildExportOption(
              label: 'Export as CSV',
              icon: Icons.grid_on,
              color: AppColors.info,
              onTap: () => _exportToCSV(),
            ),
            _buildExportOption(
              label: 'Share Report',
              icon: Icons.share,
              color: AppColors.primary,
              onTap: _shareReport,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildExportOption({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(height: 8),
              Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: AppColors.textPrimary,
                ),
              ),
              // NEW: Subtitle for AI option
              if (label == 'AI Executive Summary') const SizedBox(height: 4),
              if (label == 'AI Executive Summary')
                Text(
                  'Smart Insights',
                  style: TextStyle(fontSize: 10, color: color.withOpacity(0.7)),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ==================== AI EXECUTIVE SUMMARY FEATURES ====================

  // NEW: Generate AI Executive Summary
  Future<void> _generateAIExecutiveSummary() async {
    if (_reportData.isEmpty) {
      _scaffoldMessengerKey.currentState?.showSnackBar(
        const SnackBar(
          content: Text('Please generate a report first'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    if (!mounted) return;

    setState(() {
      _isGeneratingSummary = true;
      _showAISummary = true;
    });

    try {
      final provider = Provider.of<DashboardProvider>(context, listen: false);

      debugPrint('🤖 Generating AI executive summary for report...');

      final summary = await AISummaryService.generateExecutiveSummary(
        events: _filteredEvents,
        alerts: _filteredAlerts,
        users: provider.users,
        analytics: _reportData,
        timeRange: 'custom',
        startDate: _startDate,
        endDate: _endDate,
      );

      if (mounted) {
        setState(() {
          _aiSummary = summary;
          _isGeneratingSummary = false;
        });

        // Show the summary dialog
        _showAISummaryDialog(summary);
      }
    } catch (e) {
      debugPrint('❌ AI summary generation error: $e');

      if (mounted) {
        setState(() {
          _isGeneratingSummary = false;
        });

        _scaffoldMessengerKey.currentState?.showSnackBar(
          SnackBar(
            content: const Text('Failed to generate AI summary'),
            backgroundColor: AppColors.danger,
            action: SnackBarAction(
              label: 'Retry',
              onPressed: _generateAIExecutiveSummary,
            ),
          ),
        );
      }
    }
  }

  // NEW: Show AI Summary Dialog
  void _showAISummaryDialog(String summary) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.purple, Colors.purpleAccent],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.psychology,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'AI Executive Summary',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                  Text(
                    'Powered by Gemini AI',
                    style: TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 500),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Summary Period
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.primary.withOpacity(0.1),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.calendar_today,
                          size: 16,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Period: ${DateFormat('MMM dd, yyyy').format(_startDate)} - ${DateFormat('MMM dd, yyyy').format(_endDate)}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const Spacer(),
                        Icon(
                          Icons.analytics,
                          size: 16,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _getReportTypeLabel(_reportType),
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // AI Summary Content
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Format and display the AI summary with markdown-like styling
                        ..._formatAISummary(summary),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Data Accuracy Disclaimer
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.amber.withOpacity(0.2)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 16,
                          color: Colors.amber.shade700,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'AI-generated insights are based on available data. Always verify with clinical assessment.',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.amber.shade700,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Close'),
            ),
            ElevatedButton(
              onPressed: () {
                _shareAISummary(summary);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('Share Summary'),
            ),
          ],
        );
      },
    );
  }

  // NEW: Format AI Summary with styling
  List<Widget> _formatAISummary(String summary) {
    final lines = summary.split('\n');
    final widgets = <Widget>[];

    for (final line in lines) {
      if (line.trim().isEmpty) {
        widgets.add(const SizedBox(height: 8));
        continue;
      }

      if (line.startsWith('**') && line.endsWith('**')) {
        // Bold section headers
        final text = line.substring(2, line.length - 2);
        widgets.add(
          Text(
            text,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
        );
        widgets.add(const SizedBox(height: 8));
      } else if (line.contains('**')) {
        // Mixed formatting
        final parts = line.split('**');
        final richText = Text.rich(
          TextSpan(
            children:
                parts.asMap().entries.map((entry) {
                  final index = entry.key;
                  final part = entry.value;
                  return TextSpan(
                    text: part,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight:
                          index % 2 == 1 ? FontWeight.w700 : FontWeight.normal,
                      color: AppColors.textPrimary,
                    ),
                  );
                }).toList(),
          ),
        );
        widgets.add(richText);
        widgets.add(const SizedBox(height: 4));
      } else if (line.trim().startsWith('- ')) {
        // Bullet points
        widgets.add(
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('• ', style: TextStyle(fontSize: 16)),
              Expanded(
                child: Text(
                  line.substring(2),
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        );
      } else {
        // Regular text
        widgets.add(
          Text(
            line,
            style: TextStyle(fontSize: 13, color: AppColors.textPrimary),
          ),
        );
      }
    }

    return widgets;
  }

  // NEW: Share AI Summary
  Future<void> _shareAISummary(String summary) async {
    try {
      // For now, show a share dialog
      // You can integrate with share_plus package for actual sharing
      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Share Summary'),
            content: const Text('Summary copied to clipboard.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          );
        },
      );

      // Copy to clipboard
      await Clipboard.setData(ClipboardData(text: summary));

      _scaffoldMessengerKey.currentState?.showSnackBar(
        const SnackBar(
          content: Text('AI summary copied to clipboard'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      _scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(
          content: const Text('Failed to share summary'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  // NEW: Build AI Summary Card
  Widget _buildAISummaryCard() {
    if (_aiSummary == null) return const SizedBox.shrink();

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.purple, Colors.purpleAccent],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.psychology, color: Colors.white),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'AI Executive Summary',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        'AI-powered insights for quick decision making',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(
                    _showAISummary ? Icons.expand_less : Icons.expand_more,
                    color: AppColors.textTertiary,
                  ),
                  onPressed: () {
                    setState(() {
                      _showAISummary = !_showAISummary;
                    });
                  },
                ),
              ],
            ),

            if (_showAISummary) ...[
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 16),

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ..._formatAISummary(
                      _aiSummary!.substring(
                            0,
                            math.min(200, _aiSummary!.length),
                          ) +
                          '...',
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () => _showAISummaryDialog(_aiSummary!),
                        icon: const Icon(Icons.open_in_full, size: 14),
                        label: const Text('View Full Summary'),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.purple,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton.icon(
                    onPressed: () {
                      setState(() {
                        _aiSummary = null;
                        _showAISummary = false;
                      });
                    },
                    icon: const Icon(Icons.close, size: 16),
                    label: const Text('Dismiss'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: () => _shareAISummary(_aiSummary!),
                    icon: const Icon(Icons.share, size: 16),
                    label: const Text('Share'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  // NEW: AI Loading Overlay Widget
  Widget _buildAILoadingOverlay() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Shimmer.fromColors(
            baseColor: Colors.purple.withOpacity(0.2),
            highlightColor: Colors.purple.withOpacity(0.4),
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.purple,
                borderRadius: BorderRadius.circular(30),
              ),
              child: const Icon(
                Icons.psychology,
                color: Colors.white,
                size: 30,
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Generating AI Insights...',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.purple,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Analyzing patient data with Gemini AI',
            style: TextStyle(fontSize: 13, color: Colors.grey),
          ),
          const SizedBox(height: 16),
          const SizedBox(
            width: 40,
            height: 40,
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.purple),
              strokeWidth: 3,
            ),
          ),
        ],
      ),
    );
  }

  // ==================== HELPER METHODS ====================
  Widget _buildDatePicker(
    String label,
    DateTime date,
    Function(DateTime) onDateChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: () async {
            final pickedDate = await showDatePicker(
              context: context,
              initialDate: date,
              firstDate: DateTime(2020),
              lastDate: DateTime.now(),
              builder: (context, child) {
                return Theme(
                  data: Theme.of(context).copyWith(
                    colorScheme: const ColorScheme.light(
                      primary: AppColors.primary,
                      onPrimary: Colors.white,
                    ),
                  ),
                  child: child!,
                );
              },
            );
            if (pickedDate != null) {
              onDateChanged(pickedDate);
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_today,
                  size: 18,
                  color: AppColors.textTertiary,
                ),
                const SizedBox(width: 12),
                Text(
                  DateFormat('MMM dd, yyyy').format(date),
                  style: const TextStyle(fontSize: 14),
                ),
                const Spacer(),
                Icon(Icons.arrow_drop_down, color: AppColors.textTertiary),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _formatTime(dynamic timestamp) {
    try {
      if (timestamp == null) return 'N/A';

      if (timestamp is int) {
        return DateFormat(
          'hh:mm a',
        ).format(DateTime.fromMillisecondsSinceEpoch(timestamp));
      } else if (timestamp is String) {
        // Try to parse ISO string
        final parsed = DateTime.tryParse(timestamp);
        if (parsed != null) {
          return DateFormat('hh:mm a').format(parsed);
        }
        // Try to parse from milliseconds
        final millis = int.tryParse(timestamp);
        if (millis != null) {
          return DateFormat(
            'hh:mm a',
          ).format(DateTime.fromMillisecondsSinceEpoch(millis));
        }
      } else if (timestamp is DateTime) {
        return DateFormat('hh:mm a').format(timestamp);
      }

      return 'Invalid Time';
    } catch (e) {
      return 'Error: $e';
    }
  }

  String _formatEventType(String type) {
    final Map<String, String> eventNames = {
      'FALL_DETECTED': 'Fall Detected',
      'SOS_TRIGGERED': 'SOS Triggered',
      'ENVIRONMENT_DIAGNOSIS': 'Environmental Alert',
      'MOOD_LOG': 'Mood Log',
      'GEOFENCE_BREACH': 'Geofence Breach',
      'MOTION_READING': 'Motion Reading',
      'ENVIRONMENT_DATA': 'Environment Data',
      'FOCUS_SESSION_STARTED': 'Focus Session',
      'APP_STARTED': 'App Started',
      'APP_CLOSED': 'App Closed',
      'SAFE_MESSAGE_SENT': 'Safe Message',
      'SMS_SENT': 'SMS Sent',
      'PROFILE_CREATED': 'Profile Created',
      'CAREGIVER_UPDATED': 'Caregiver Updated',
      'ENVIRONMENTAL_ALERT': 'Environmental Alert',
      'EMERGENCY_SOS': 'Emergency SOS',
      'MOOD_REPORTED': 'Mood Reported',
      'HUSH_ACTIVATED': 'Noise Alert',
      'SIREN_TOGGLED': 'Siren Toggled',
      'AI_TOGGLED': 'AI Toggled',
      'HUSH_TOGGLED': 'Hush Toggled',
      'SMS_TOGGLED': 'SMS Toggled',
      'FOCUS_SESSION_ENDED': 'Focus Ended',
      'FOCUS_DISTRACTION': 'Focus Distraction',
      'HOME_LOCATION_SET': 'Home Set',
      'SOS_RESOLVED': 'SOS Resolved',
      'SMS_FAILED': 'SMS Failed',
    };
    return eventNames[type] ?? type.replaceAll('_', ' ');
  }

  Color _getEventColor(String type) {
    if (type.contains('FALL') ||
        type.contains('SOS') ||
        type.contains('EMERGENCY')) {
      return AppColors.danger;
    } else if (type.contains('ENVIRONMENT') ||
        type.contains('DIAGNOSIS') ||
        type.contains('HUSH')) {
      return AppColors.warning;
    } else if (type.contains('MOOD') || type.contains('FOCUS')) {
      return AppColors.success;
    } else if (type.contains('GEOFENCE') || type.contains('BREACH')) {
      return AppColors.info;
    } else if (type.contains('APP') ||
        type.contains('SMS') ||
        type.contains('MESSAGE')) {
      return AppColors.primary;
    }
    return AppColors.textTertiary;
  }

  String _truncateText(String text, int maxLength) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength)}...';
  }

  String? _getEventDetails(Map<String, dynamic> event) {
    final type = event['type']?.toString() ?? '';
    final data = event['data'] ?? {};

    if (data is Map) {
      switch (type) {
        case 'FALL_DETECTED':
          final gForce = data['gForce'] ?? data['g_force'] ?? 'N/A';
          final lat = data['lat'] ?? 'N/A';
          final lng = data['lng'] ?? 'N/A';
          return 'G-Force: $gForce, Location: $lat,$lng';

        case 'ENVIRONMENT_DATA':
          final temp = data['temperature'] ?? data['temp'] ?? 'N/A';
          final aqi = data['aqi'] ?? data['air_quality'] ?? 'N/A';
          final noise = data['noise'] ?? data['sound_level'] ?? 'N/A';
          return 'Temp: ${temp}°C, AQI: $aqi, Noise: $noise dB';

        case 'ENVIRONMENT_DIAGNOSIS':
        case 'ENVIRONMENTAL_ALERT':
          final diagnosis = data['diagnosis'] ?? data['message'] ?? 'N/A';
          final advice = data['advice'] ?? 'N/A';
          return '$diagnosis - $advice';

        case 'SOS_TRIGGERED':
        case 'EMERGENCY_SOS':
          final isManual = data['isManual'] ?? data['manual'] ?? false;
          final caregiver = data['caregiverPhone'] ?? 'Not Set';
          return '${isManual ? 'Manual' : 'Auto'}, Caregiver: $caregiver';

        case 'MOOD_LOG':
        case 'MOOD_REPORTED':
          final mood = data['mood'] ?? data['value'] ?? 'N/A';
          final reason = data['reason'] ?? data['notes'] ?? '';
          return 'Mood: $mood ${reason.isNotEmpty ? '($reason)' : ''}';

        case 'MOTION_READING':
          final accX = data['accX'] ?? data['acc_x'] ?? 'N/A';
          final accY = data['accY'] ?? data['acc_y'] ?? 'N/A';
          final accZ = data['accZ'] ?? data['acc_z'] ?? 'N/A';
          return 'Acc: X=$accX, Y=$accY, Z=$accZ';

        case 'SMS_SENT':
          final to = data['to'] ?? 'N/A';
          final msg = data['message'] ?? '';
          return 'To: $to, ${msg.length > 10 ? '${msg.substring(0, 10)}...' : msg}';

        case 'FOCUS_SESSION_STARTED':
          final duration = data['duration'] ?? data['plannedDuration'] ?? 'N/A';
          return 'Planned: ${duration}min';

        case 'FOCUS_SESSION_ENDED':
          final actual = data['actualDuration'] ?? data['duration'] ?? 'N/A';
          return 'Actual: ${actual}min';

        default:
          if (data.isNotEmpty) {
            return data.toString();
          }
      }
    }

    return event['message']?.toString() ??
        event['title']?.toString() ??
        'No details';
  }

  // ==================== REPORT GENERATION ====================
  Future<void> _generateReport(DashboardProvider provider) async {
    if (!mounted) return;
    setState(() => _isGenerating = true);

    try {
      // Filter events by date range and user
      final filteredEvents =
          provider.events.where((event) {
            final timestamp = event['timestamp'];
            if (timestamp == null) return false;

            DateTime? eventTime;

            // Handle different timestamp formats
            if (timestamp is int) {
              eventTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
            } else if (timestamp is String) {
              eventTime = DateTime.tryParse(timestamp);
              if (eventTime == null) {
                final millis = int.tryParse(timestamp);
                if (millis != null) {
                  eventTime = DateTime.fromMillisecondsSinceEpoch(millis);
                }
              }
            } else if (timestamp is DateTime) {
              eventTime = timestamp;
            }

            if (eventTime == null) return false;

            // Date filter (include the entire end date)
            final startOfDay = DateTime(
              _startDate.year,
              _startDate.month,
              _startDate.day,
            );
            final endOfDay = DateTime(
              _endDate.year,
              _endDate.month,
              _endDate.day,
              23,
              59,
              59,
            );

            final isInDateRange =
                !eventTime.isBefore(startOfDay) && !eventTime.isAfter(endOfDay);

            // User filter
            final userId = event['userId']?.toString();
            final isUserMatch =
                _selectedUserId == 'all' || userId == _selectedUserId;

            return isInDateRange && isUserMatch;
          }).toList();

      // Filter alerts similarly
      final filteredAlerts =
          provider.alerts.where((alert) {
            final timestamp = alert['timestamp'];
            if (timestamp == null) return false;

            DateTime? alertTime;

            if (timestamp is int) {
              alertTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
            } else if (timestamp is String) {
              alertTime = DateTime.tryParse(timestamp);
              if (alertTime == null) {
                final millis = int.tryParse(timestamp);
                if (millis != null) {
                  alertTime = DateTime.fromMillisecondsSinceEpoch(millis);
                }
              }
            } else if (timestamp is DateTime) {
              alertTime = timestamp;
            }

            if (alertTime == null) return false;

            final startOfDay = DateTime(
              _startDate.year,
              _startDate.month,
              _startDate.day,
            );
            final endOfDay = DateTime(
              _endDate.year,
              _endDate.month,
              _endDate.day,
              23,
              59,
              59,
            );

            final isInDateRange =
                !alertTime.isBefore(startOfDay) && !alertTime.isAfter(endOfDay);

            final userId = alert['userId']?.toString();
            final isUserMatch =
                _selectedUserId == 'all' || userId == _selectedUserId;

            return isInDateRange && isUserMatch;
          }).toList();

      // Calculate metrics
      final eventBreakdown = <String, int>{};
      int criticalAlerts = 0;
      int fallsDetected = 0;
      int sosTriggers = 0;
      int environmentalAlerts = 0;
      int moodLogs = 0;
      int geofenceBreaches = 0;

      for (var event in filteredEvents) {
        final type = event['type']?.toString() ?? 'Unknown';
        eventBreakdown[type] = (eventBreakdown[type] ?? 0) + 1;

        if (type.contains('FALL')) fallsDetected++;
        if (type.contains('SOS') || type.contains('EMERGENCY')) sosTriggers++;
        if (type.contains('ENVIRONMENT') || type.contains('DIAGNOSIS'))
          environmentalAlerts++;
        if (type.contains('MOOD')) moodLogs++;
        if (type.contains('GEOFENCE')) geofenceBreaches++;
      }

      for (var alert in filteredAlerts) {
        final type = alert['type']?.toString() ?? '';
        if (type.contains('EMERGENCY') ||
            type.contains('SOS') ||
            type.contains('FALL')) {
          criticalAlerts++;
        }
      }

      // Get user name if specific user selected
      String? userName;
      if (_selectedUserId != 'all') {
        final user = provider.users.firstWhere(
          (u) => u['id']?.toString() == _selectedUserId,
          orElse: () => {},
        );
        userName = user['name']?.toString() ?? 'Unknown User';
      }

      // Prepare report data
      _reportData = {
        'period':
            '${DateFormat('MMM dd').format(_startDate)} - ${DateFormat('MMM dd, yyyy').format(_endDate)}',
        'totalEvents': filteredEvents.length,
        'totalAlerts': filteredAlerts.length,
        'criticalAlerts': criticalAlerts,
        'fallsDetected': fallsDetected,
        'sosTriggers': sosTriggers,
        'environmentalAlerts': environmentalAlerts,
        'moodLogs': moodLogs,
        'geofenceBreaches': geofenceBreaches,
        'eventBreakdown': eventBreakdown,
        'userName': userName,
        'generatedAt': DateTime.now(),
        'reportType': _reportType,
        'userFilter':
            _selectedUserId == 'all'
                ? 'All Users'
                : userName ?? 'Specific User',
      };

      // Store filtered data for preview and export
      _filteredEvents = filteredEvents;
      _filteredAlerts = filteredAlerts;

      if (mounted) {
        setState(() {});
      }

      // Show success using the scaffold messenger key
      _scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Text(
            'Report generated: ${filteredEvents.length} events analyzed',
          ),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (mounted) {
        _scaffoldMessengerKey.currentState?.showSnackBar(
          SnackBar(
            content: Text('Error generating report: ${e.toString()}'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isGenerating = false);
      }
    }
  }

  void _generateTemplateReport(String template) {
    // Set date range based on template
    final now = DateTime.now();
    switch (template) {
      case 'safety':
        _startDate = now.subtract(const Duration(days: 1));
        _endDate = now;
        _reportType = 'safety_incidents';
        break;
      case 'wellness':
        _startDate = now.subtract(const Duration(days: 7));
        _endDate = now;
        _reportType = 'wellness_analysis';
        break;
      case 'audit':
        _startDate = DateTime(now.year, now.month, 1);
        _endDate = now;
        _reportType = 'system_audit';
        break;
      case 'environmental':
        _startDate = now.subtract(const Duration(days: 30));
        _endDate = now;
        _reportType = 'environmental';
        break;
      case 'user_activity':
        _startDate = now.subtract(const Duration(days: 14));
        _endDate = now;
        _reportType = 'user_activity';
        break;
      case 'caregiver':
        _startDate = now.subtract(const Duration(days: 30));
        _endDate = now;
        _reportType = 'daily_summary';
        break;
    }

    // Trigger report generation
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final provider = Provider.of<DashboardProvider>(context, listen: false);
        _generateReport(provider);
      }
    });

    _scaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Text(
          'Generating ${_getReportTypeLabel(_reportType)} report...',
        ),
        backgroundColor: AppColors.primary,
      ),
    );
  }

  // ==================== EXPORT FUNCTIONS ====================
  Future<void> _exportToPDF() async {
    if (_reportData.isEmpty || _filteredEvents.isEmpty) {
      _scaffoldMessengerKey.currentState?.showSnackBar(
        const SnackBar(
          content: Text('No report data available to export'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    if (!mounted) return;
    setState(() => _isExporting = true);

    try {
      // For web, use html export
      if (html.window.navigator.userAgent.contains('Web')) {
        final htmlContent = '''
        <!DOCTYPE html>
        <html>
        <head>
          <title>Chetna AI Medical Report</title>
          <style>
            @import url('https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700&display=swap');
            * { margin: 0; padding: 0; box-sizing: border-box; }
            body { 
              font-family: 'Inter', sans-serif; 
              padding: 40px; 
              color: #333;
              line-height: 1.6;
            }
            .header { 
              border-bottom: 3px solid #0A4DA2; 
              padding-bottom: 20px; 
              margin-bottom: 30px;
            }
            h1 { 
              color: #0A4DA2; 
              font-size: 32px; 
              margin-bottom: 10px;
              font-weight: 700;
            }
            .subtitle { 
              color: #666; 
              font-size: 16px; 
              margin-bottom: 20px;
            }
            .meta-info { 
              display: flex; 
              justify-content: space-between; 
              margin-bottom: 30px;
              background: #f8f9fa;
              padding: 20px;
              border-radius: 8px;
            }
            .metric-grid { 
              display: grid; 
              grid-template-columns: repeat(4, 1fr); 
              gap: 20px; 
              margin: 30px 0;
            }
            .metric-card { 
              border: 1px solid #e0e0e0; 
              padding: 20px; 
              border-radius: 8px;
              text-align: center;
              box-shadow: 0 2px 4px rgba(0,0,0,0.05);
            }
            .metric-value { 
              font-size: 28px; 
              font-weight: 700; 
              color: #0A4DA2; 
              margin: 10px 0;
            }
            .metric-label { 
              color: #666; 
              font-size: 14px;
            }
            .section { 
              margin: 30px 0; 
              page-break-inside: avoid;
            }
            h2 { 
              color: #333; 
              margin-bottom: 15px; 
              padding-bottom: 10px;
              border-bottom: 2px solid #f0f0f0;
              font-weight: 600;
            }
            table { 
              width: 100%; 
              border-collapse: collapse; 
              margin: 20px 0;
              font-size: 14px;
            }
            th { 
              background: #f8f9fa; 
              padding: 12px 15px; 
              text-align: left; 
              border-bottom: 2px solid #e0e0e0;
              font-weight: 600;
              color: #555;
            }
            td { 
              padding: 12px 15px; 
              border-bottom: 1px solid #f0f0f0;
            }
            .event-type { 
              display: inline-block; 
              padding: 4px 12px; 
              border-radius: 20px; 
              font-size: 12px; 
              font-weight: 600;
            }
            .danger { background: #fff5f5; color: #dc3545; }
            .warning { background: #fff8e1; color: #ff9800; }
            .success { background: #f0fff4; color: #28a745; }
            .info { background: #e3f2fd; color: #2196f3; }
            .footer { 
              margin-top: 50px; 
              padding-top: 20px; 
              border-top: 1px solid #e0e0e0; 
              color: #999; 
              font-size: 12px;
              text-align: center;
            }
          </style>
        </head>
        <body>
          <div class="header">
            <h1>Chetna AI Medical Report</h1>
            <div class="subtitle">Comprehensive Safety & Wellness Monitoring Analysis</div>
          </div>
          
          <div class="meta-info">
            <div>
              <strong>Report Period:</strong><br>
              ${_reportData['period']}
            </div>
            <div>
              <strong>Users Included:</strong><br>
              ${_reportData['userFilter']}
            </div>
            <div>
              <strong>Generated:</strong><br>
              ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}
            </div>
            <div>
              <strong>Report Type:</strong><br>
              ${_getReportTypeLabel(_reportType)}
            </div>
          </div>
          
          <div class="section">
            <h2>Key Metrics Summary</h2>
            <div class="metric-grid">
              <div class="metric-card">
                <div class="metric-value">${_reportData['totalEvents'] ?? 0}</div>
                <div class="metric-label">Total Events</div>
              </div>
              <div class="metric-card">
                <div class="metric-value">${_reportData['criticalAlerts'] ?? 0}</div>
                <div class="metric-label">Critical Alerts</div>
              </div>
              <div class="metric-card">
                <div class="metric-value">${_reportData['fallsDetected'] ?? 0}</div>
                <div class="metric-label">Falls Detected</div>
              </div>
              <div class="metric-card">
                <div class="metric-value">${_reportData['sosTriggers'] ?? 0}</div>
                <div class="metric-label">SOS Triggers</div>
              </div>
            </div>
          </div>
          
          <div class="section">
            <h2>Event Breakdown</h2>
            <table>
              <thead>
                <tr>
                  <th>Event Type</th>
                  <th>Count</th>
                  <th>Percentage</th>
                </tr>
              </thead>
              <tbody>
                ${_generateEventBreakdownRows()}
              </tbody>
            </table>
          </div>
          
          <div class="section">
            <h2>Recent Events (Sample)</h2>
            <table>
              <thead>
                <tr>
                  <th>Time</th>
                  <th>Type</th>
                  <th>User</th>
                  <th>Details</th>
                </tr>
              </thead>
              <tbody>
                ${_generateSampleEventsRows()}
              </tbody>
            </table>
          </div>
          
          <div class="footer">
            <p>Generated by Chetna AI Safety System • ${DateFormat('yyyy-MM-dd').format(DateTime.now())}</p>
            <p>Confidential - For authorized personnel only</p>
          </div>
        </body>
        </html>
        ''';

        final blob = html.Blob([htmlContent], 'text/html');
        final url = html.Url.createObjectUrlFromBlob(blob);
        html.AnchorElement(href: url)
          ..setAttribute(
            'download',
            'chetna_report_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.html',
          )
          ..click();
        html.Url.revokeObjectUrl(url);
      }

      _scaffoldMessengerKey.currentState?.showSnackBar(
        const SnackBar(
          content: Text('PDF report prepared for download'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      _scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Text('Export error: ${e.toString()}'),
          backgroundColor: AppColors.danger,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  String _generateEventBreakdownRows() {
    final breakdown = _reportData['eventBreakdown'] as Map<String, int>? ?? {};
    final total = breakdown.values.fold(0, (sum, value) => sum + value);

    return breakdown.entries.map((entry) {
      final percentage =
          total > 0 ? ((entry.value / total) * 100).toStringAsFixed(1) : '0.0';
      final typeLabel = _formatEventType(entry.key);
      return '''
        <tr>
          <td>$typeLabel</td>
          <td>${entry.value}</td>
          <td>$percentage%</td>
        </tr>
      ''';
    }).join();
  }

  String _generateSampleEventsRows() {
    return _filteredEvents.take(10).map((event) {
      final type = event['type']?.toString() ?? 'Unknown';
      final time = _formatTime(event['timestamp']);
      final userId = event['userId']?.toString().substring(0, 8) ?? 'Unknown';
      final details = _getEventDetails(event) ?? 'No details';
      final typeClass = _getEventTypeClass(type);

      return '''
        <tr>
          <td>$time</td>
          <td><span class="event-type $typeClass">${_formatEventType(type)}</span></td>
          <td>$userId</td>
          <td>$details</td>
        </tr>
      ''';
    }).join();
  }

  String _getEventTypeClass(String type) {
    if (type.contains('FALL') ||
        type.contains('SOS') ||
        type.contains('EMERGENCY')) {
      return 'danger';
    } else if (type.contains('ENVIRONMENT') ||
        type.contains('DIAGNOSIS') ||
        type.contains('HUSH')) {
      return 'warning';
    } else if (type.contains('MOOD') || type.contains('FOCUS')) {
      return 'success';
    } else if (type.contains('GEOFENCE') || type.contains('BREACH')) {
      return 'info';
    }
    return '';
  }

  Future<void> _exportToExcel() async {
    if (_reportData.isEmpty || _filteredEvents.isEmpty) {
      _scaffoldMessengerKey.currentState?.showSnackBar(
        const SnackBar(
          content: Text('No report data available to export'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    if (!mounted) return;
    setState(() => _isExporting = true);

    try {
      // Create Excel workbook
      final Workbook workbook = Workbook();

      // Get the first sheet (automatically created) and rename it
      final Worksheet summarySheet = workbook.worksheets[0];
      summarySheet.name = 'Report Summary';

      // Set column widths
      summarySheet.getRangeByName('A1').columnWidth = 30;
      summarySheet.getRangeByName('B1').columnWidth = 20;

      // Add headers with styling
      final Range titleCell = summarySheet.getRangeByName('A1');
      titleCell.setText('Chetna AI Medical Report');
      titleCell.cellStyle.fontSize = 16;
      titleCell.cellStyle.bold = true;
      titleCell.cellStyle.hAlign = HAlignType.center;

      summarySheet
          .getRangeByName('A2')
          .setText('Period: ${_reportData['period']}');
      summarySheet
          .getRangeByName('A3')
          .setText(
            'Generated: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}',
          );
      summarySheet
          .getRangeByName('A4')
          .setText('Users: ${_reportData['userFilter']}');
      summarySheet
          .getRangeByName('A5')
          .setText('Report Type: ${_getReportTypeLabel(_reportType)}');

      // Add metrics header
      final Range metricsHeader = summarySheet.getRangeByName('A7');
      metricsHeader.setText('Key Metrics');
      metricsHeader.cellStyle.fontSize = 14;
      metricsHeader.cellStyle.bold = true;
      metricsHeader.cellStyle.backColor = '#f0f0f0';

      // Add metrics data
      final List<List<dynamic>> metrics = [
        ['Total Events', _reportData['totalEvents']],
        ['Critical Alerts', _reportData['criticalAlerts']],
        ['Falls Detected', _reportData['fallsDetected']],
        ['SOS Triggers', _reportData['sosTriggers']],
        ['Environmental Alerts', _reportData['environmentalAlerts']],
        ['Mood Logs', _reportData['moodLogs']],
        ['Geofence Breaches', _reportData['geofenceBreaches']],
      ];

      for (int i = 0; i < metrics.length; i++) {
        final row = 8 + i;
        summarySheet.getRangeByIndex(row, 1).setText(metrics[i][0].toString());
        final valueCell = summarySheet.getRangeByIndex(row, 2);
        valueCell.setNumber(
          metrics[i][1] is int ? (metrics[i][1] as int).toDouble() : 0.0,
        );
      }

      // Add event breakdown sheet
      final Worksheet breakdownSheet = workbook.worksheets.add();
      breakdownSheet.name = 'Event Breakdown';

      breakdownSheet.getRangeByName('A1').columnWidth = 40;
      breakdownSheet.getRangeByName('B1').columnWidth = 15;
      breakdownSheet.getRangeByName('C1').columnWidth = 15;

      // Add headers
      breakdownSheet.getRangeByName('A1').setText('Event Type');
      breakdownSheet.getRangeByName('B1').setText('Count');
      breakdownSheet.getRangeByName('C1').setText('Percentage');

      // Style headers
      final Range breakdownHeader = breakdownSheet.getRangeByName('A1:C1');
      breakdownHeader.cellStyle.bold = true;
      breakdownHeader.cellStyle.backColor = '#f0f0f0';

      // Add breakdown data
      final breakdown =
          _reportData['eventBreakdown'] as Map<String, int>? ?? {};
      final total = breakdown.values.fold(0, (sum, value) => sum + value);
      int row = 2;
      breakdown.forEach((key, value) {
        final percentage = total > 0 ? (value / total) * 100 : 0;
        breakdownSheet.getRangeByIndex(row, 1).setText(_formatEventType(key));
        breakdownSheet.getRangeByIndex(row, 2).setNumber(value.toDouble());
        breakdownSheet.getRangeByIndex(row, 3).setNumber(percentage.toDouble());
        row++;
      });

      // Add events data sheet
      final Worksheet eventsSheet = workbook.worksheets.add();
      eventsSheet.name = 'Events Data';

      // Set column widths
      eventsSheet.getRangeByName('A1').columnWidth = 20;
      eventsSheet.getRangeByName('B1').columnWidth = 25;
      eventsSheet.getRangeByName('C1').columnWidth = 15;
      eventsSheet.getRangeByName('D1').columnWidth = 40;

      // Add headers
      eventsSheet.getRangeByName('A1').setText('Timestamp');
      eventsSheet.getRangeByName('B1').setText('Type');
      eventsSheet.getRangeByName('C1').setText('User ID');
      eventsSheet.getRangeByName('D1').setText('Details');

      // Style headers
      final Range eventsHeader = eventsSheet.getRangeByName('A1:D1');
      eventsHeader.cellStyle.bold = true;
      eventsHeader.cellStyle.backColor = '#f0f0f0';

      // Add events data (limit to 1000 rows)
      final int maxRows =
          _filteredEvents.length < 1000 ? _filteredEvents.length : 1000;
      for (int i = 0; i < maxRows; i++) {
        final event = _filteredEvents[i];
        final rowNum = i + 2;

        eventsSheet
            .getRangeByIndex(rowNum, 1)
            .setText(_formatTime(event['timestamp']));
        eventsSheet
            .getRangeByIndex(rowNum, 2)
            .setText(_formatEventType(event['type']?.toString() ?? 'Unknown'));
        eventsSheet
            .getRangeByIndex(rowNum, 3)
            .setText(event['userId']?.toString() ?? '');

        final details = _getEventDetails(event) ?? '';
        eventsSheet.getRangeByIndex(rowNum, 4).setText(details);
      }

      // Save file
      final List<int> bytes = workbook.saveAsStream();
      workbook.dispose();

      // For web, download the file
      if (html.window.navigator.userAgent.contains('Web')) {
        final blob = html.Blob([
          bytes,
        ], 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
        final url = html.Url.createObjectUrlFromBlob(blob);
        html.AnchorElement(href: url)
          ..setAttribute(
            'download',
            'chetna_report_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.xlsx',
          )
          ..click();
        html.Url.revokeObjectUrl(url);
      }

      _scaffoldMessengerKey.currentState?.showSnackBar(
        const SnackBar(
          content: Text('Excel file downloaded successfully'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e, stackTrace) {
      print('Excel export error: $e');
      print('Stack trace: $stackTrace');
      _scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Text('Export error: ${e.toString()}'),
          backgroundColor: AppColors.danger,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  Future<void> _exportToCSV() async {
    if (_reportData.isEmpty || _filteredEvents.isEmpty) {
      _scaffoldMessengerKey.currentState?.showSnackBar(
        const SnackBar(
          content: Text('No report data available to export'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    if (!mounted) return;
    setState(() => _isExporting = true);

    try {
      // Create CSV content
      final csvBuffer = StringBuffer();

      // Header
      csvBuffer.writeln('Chetna AI Medical Report');
      csvBuffer.writeln('Period: ${_reportData['period']}');
      csvBuffer.writeln(
        'Generated: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}',
      );
      csvBuffer.writeln('Users: ${_reportData['userFilter']}');
      csvBuffer.writeln('Report Type: ${_getReportTypeLabel(_reportType)}');
      csvBuffer.writeln('');

      // Metrics
      csvBuffer.writeln('KEY METRICS');
      csvBuffer.writeln('Metric,Value');
      csvBuffer.writeln('Total Events,${_reportData['totalEvents']}');
      csvBuffer.writeln('Critical Alerts,${_reportData['criticalAlerts']}');
      csvBuffer.writeln('Falls Detected,${_reportData['fallsDetected']}');
      csvBuffer.writeln('SOS Triggers,${_reportData['sosTriggers']}');
      csvBuffer.writeln(
        'Environmental Alerts,${_reportData['environmentalAlerts']}',
      );
      csvBuffer.writeln('Mood Logs,${_reportData['moodLogs']}');
      csvBuffer.writeln('Geofence Breaches,${_reportData['geofenceBreaches']}');
      csvBuffer.writeln('');

      // Event breakdown
      csvBuffer.writeln('EVENT BREAKDOWN');
      csvBuffer.writeln('Event Type,Count,Percentage');
      final breakdown =
          _reportData['eventBreakdown'] as Map<String, int>? ?? {};
      final total = breakdown.values.fold(0, (sum, value) => sum + value);
      breakdown.forEach((key, value) {
        final percentage =
            total > 0 ? ((value / total) * 100).toStringAsFixed(1) : '0.0';
        csvBuffer.writeln('${_formatEventType(key)},$value,$percentage%');
      });
      csvBuffer.writeln('');

      // Events data
      csvBuffer.writeln('EVENTS DATA');
      csvBuffer.writeln('Timestamp,Event Type,User ID,Details');
      for (final event in _filteredEvents.take(1000)) {
        final details = _getEventDetails(event)?.replaceAll(',', ';') ?? '';
        csvBuffer.writeln(
          '${_formatTime(event['timestamp'])},${_formatEventType(event['type']?.toString() ?? 'Unknown')},${event['userId'] ?? ''},"$details"',
        );
      }

      // For web, download the file
      if (html.window.navigator.userAgent.contains('Web')) {
        final blob = html.Blob([csvBuffer.toString()], 'text/csv');
        final url = html.Url.createObjectUrlFromBlob(blob);
        html.AnchorElement(href: url)
          ..setAttribute(
            'download',
            'chetna_report_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.csv',
          )
          ..click();
        html.Url.revokeObjectUrl(url);
      }

      _scaffoldMessengerKey.currentState?.showSnackBar(
        const SnackBar(
          content: Text('CSV file downloaded successfully'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      _scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Text('Export error: ${e.toString()}'),
          backgroundColor: AppColors.danger,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  void _shareReport() {
    if (_reportData.isEmpty) {
      _scaffoldMessengerKey.currentState?.showSnackBar(
        const SnackBar(
          content: Text('No report data available to share'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    // Implement sharing logic
    _scaffoldMessengerKey.currentState?.showSnackBar(
      const SnackBar(
        content: Text('Report prepared for sharing (implement share dialog)'),
        backgroundColor: AppColors.info,
      ),
    );
  }

  void _printReport() {
    if (_reportData.isEmpty) {
      _scaffoldMessengerKey.currentState?.showSnackBar(
        const SnackBar(
          content: Text('No report data available to print'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    // Print report
    _scaffoldMessengerKey.currentState?.showSnackBar(
      const SnackBar(
        content: Text('Print dialog opened (implement print functionality)'),
        backgroundColor: AppColors.primary,
      ),
    );
  }

  void _showReportHistory() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Report History'),
            content: SizedBox(
              width: 400,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Recently generated reports will appear here'),
                  const SizedBox(height: 20),
                  if (_reportData.isNotEmpty) ...[
                    ListTile(
                      leading: const Icon(Icons.description),
                      title: Text(
                        _getReportTypeLabel(
                          _reportData['reportType']?.toString() ?? '',
                        ),
                      ),
                      subtitle: Text(
                        '${_reportData['period']} • ${_reportData['totalEvents']} events',
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.download),
                        onPressed: () => _exportToCSV(),
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  TextButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.history),
                    label: const Text('View Full History'),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
}
