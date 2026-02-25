// views/analytics_view.dart - JH-BHOPAL HEALTH ANALYTICS DASHBOARD
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:intl/intl.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:shimmer/shimmer.dart';
import '../providers/dashboard_provider.dart';
import '../utils/constants.dart';

class AnalyticsView extends StatefulWidget {
  const AnalyticsView({super.key});

  @override
  State<AnalyticsView> createState() => _AnalyticsViewState();
}

class _AnalyticsViewState extends State<AnalyticsView>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  String _selectedTimeRange = '24h';
  int _selectedFilter = 0;
  late TabController _tabController;
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 7));
  DateTime _endDate = DateTime.now();
  bool _showDatePicker = false;
  List<StreamSubscription<DatabaseEvent>> _firebaseSubscriptions = [];
  bool _isLiveMode = true;
  Timer? _refreshTimer;
  bool _isDisposed = false;
  DateTime _lastFirebaseUpdate = DateTime.now();
  int _updateCount = 0;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  final List<Map<String, dynamic>> _filters = [
    {
      'id': 0,
      'label': 'All Metrics',
      'icon': Icons.medical_services,
      'color': Color(0xFF0066B3), // JHU Blue
    },
    {
      'id': 1,
      'label': 'Critical',
      'icon': Icons.emergency,
      'color': Color(0xFFD32F2F), // Medical Red
    },
    {
      'id': 2,
      'label': 'Vitals',
      'icon': Icons.monitor_heart,
      'color': Color(0xFF2E7D32), // Health Green
    },
    {
      'id': 3,
      'label': 'Environmental',
      'icon': Icons.thermostat,
      'color': Color(0xFFED6C02), // Warning Orange
    },
    {
      'id': 4,
      'label': 'Wellness',
      'icon': Icons.psychology,
      'color': Color(0xFF7B1FA2), // Wellness Purple
    },
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _tabController = TabController(length: 5, vsync: this);
    _initializeAnimations();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_isDisposed) {
        debugPrint('✅ JH-Bhopal Analytics: Initializing real-time monitoring');
        _startLiveMode();
        _startAutoRefresh();
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted || _isDisposed) return;

    if (state == AppLifecycleState.resumed) {
      debugPrint('🔄 AnalyticsView: App resumed, restarting live mode');
      if (_isLiveMode) {
        _startLiveMode();
      }
    } else if (state == AppLifecycleState.paused) {
      debugPrint('⏸️ AnalyticsView: App paused, stopping live mode');
      _stopLiveMode();
    }
  }

  @override
  void dispose() {
    debugPrint('🗑️ AnalyticsView: Disposing widget');
    _isDisposed = true;
    WidgetsBinding.instance.removeObserver(this);

    _refreshTimer?.cancel();
    _refreshTimer = null;
    _stopLiveMode();
    _pulseController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _initializeAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.9, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  void _startAutoRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      if (_isLiveMode && mounted && !_isDisposed) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && !_isDisposed) {
            debugPrint('🔄 AnalyticsView: Auto-refresh triggered');
            final provider = Provider.of<DashboardProvider>(
              context,
              listen: false,
            );
            provider.refreshData();
          }
        });
      }
    });
  }

  void _startLiveMode() {
    if (!_isLiveMode || _isDisposed || !mounted) return;

    try {
      debugPrint('🔥 Starting JHU-Bhopal real-time monitoring');

      _stopLiveMode();

      final DatabaseReference eventsRef = FirebaseDatabase.instance.ref(
        'users',
      );
      final DatabaseReference alertsRef = FirebaseDatabase.instance.ref(
        'alerts',
      );

      final provider = Provider.of<DashboardProvider>(context, listen: false);

      final eventsSubscription = eventsRef.onValue.listen(
        (DatabaseEvent event) {
          if (mounted && !_isDisposed) {
            _updateCount++;
            _lastFirebaseUpdate = DateTime.now();
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && !_isDisposed) {
                provider.refreshData();
                setState(() {});
              }
            });
          }
        },
        onError: (error) {
          debugPrint('❌ Firebase users error: $error');
        },
      );

      final alertsSubscription = alertsRef.onValue.listen(
        (DatabaseEvent event) {
          if (mounted && !_isDisposed) {
            _updateCount++;
            _lastFirebaseUpdate = DateTime.now();
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && !_isDisposed) {
                provider.refreshData();
                setState(() {});
              }
            });
          }
        },
        onError: (error) {
          debugPrint('❌ Firebase alerts error: $error');
        },
      );

      _firebaseSubscriptions = [eventsSubscription, alertsSubscription];

      provider.addListener(() {
        if (mounted && !_isDisposed) {
          setState(() {});
        }
      });

      debugPrint('✅ JH-Bhopal monitoring active');
    } catch (e) {
      debugPrint('❌ Connection error: $e');
    }
  }

  void _stopLiveMode() {
    for (var subscription in _firebaseSubscriptions) {
      subscription.cancel();
    }
    _firebaseSubscriptions.clear();
  }

  Widget _buildLiveIndicator() {
    return GestureDetector(
      onTap: () {
        if (!mounted || _isDisposed) return;
        setState(() {
          _isLiveMode = !_isLiveMode;
          if (_isLiveMode) {
            _startLiveMode();
          } else {
            _stopLiveMode();
          }
        });
      },
      child: AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              gradient:
                  _isLiveMode
                      ? LinearGradient(
                        colors: [Color(0xFFD32F2F), Color(0xFFFF5252)],
                      )
                      : LinearGradient(
                        colors: [Colors.grey.shade600, Colors.grey.shade400],
                      ),
              borderRadius: BorderRadius.circular(25),
              boxShadow: [
                BoxShadow(
                  color: (_isLiveMode ? Color(0xFFD32F2F) : Colors.grey)
                      .withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: _isLiveMode ? Colors.white : Colors.grey.shade200,
                    shape: BoxShape.circle,
                    boxShadow:
                        _isLiveMode
                            ? [
                              BoxShadow(
                                color: Colors.white.withOpacity(0.8),
                                blurRadius: _pulseAnimation.value * 8,
                              ),
                            ]
                            : null,
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isLiveMode ? 'LIVE MONITORING' : 'PAUSED',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 1.2,
                      ),
                    ),
                    if (_isLiveMode && _updateCount > 0)
                      Text(
                        'Data Points: $_updateCount',
                        style: const TextStyle(
                          fontSize: 8,
                          color: Colors.white70,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<DashboardProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading && provider.events.isEmpty) {
          return _buildLoadingState();
        }

        final analyticsData = _processRealTimeData(
          provider.events,
          provider.alerts,
          _selectedTimeRange,
          _startDate,
          _endDate,
          _selectedFilter,
          provider.users,
        );

        return Scaffold(
          backgroundColor: Color(0xFFF8F9FA),
          body: Column(
            children: [
              // Header
              _buildHeaderSection(provider, analyticsData),

              // Filter Section
              _buildFilterSection(provider),

              // Main Content
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    children: [
                      // JH-Bhopal Collaboration Banner
                      _buildCollaborationBanner(),

                      // AI Insights
                      _buildRealAIInsights(analyticsData),

                      // Tabs
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 16,
                        ),
                        child: _buildCategoryTabs(),
                      ),

                      // Tab Views
                      SizedBox(
                        height: 600,
                        child: TabBarView(
                          controller: _tabController,
                          children: [
                            _buildRealOverviewTab(analyticsData, provider),
                            _buildRealVitalsTab(analyticsData),
                            _buildRealEnvironmentalTab(analyticsData),
                            _buildRealSafetyTab(analyticsData, provider),
                            _buildRealSystemTab(provider, analyticsData),
                          ],
                        ),
                      ),

                      // Advanced Analytics
                      _buildRealAdvancedAnalytics(analyticsData, provider),

                      // Data Table
                      _buildRealDataTable(
                        analyticsData['filteredEvents'] ?? [],
                      ),

                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ],
          ),
          floatingActionButton: _buildFloatingActions(),
        );
      },
    );
  }

  Widget _buildCollaborationBanner() {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0066B3), Color(0xFF004D99)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Color(0xFF0066B3).withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'JH-BHOPAL INITIATIVE',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Johns Hopkins University × Bhopal Health Initiative',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Real-time community health monitoring platform for preventive care and rapid response',
                  style: TextStyle(fontSize: 12, color: Colors.white70),
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.health_and_safety,
              size: 40,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Scaffold(
      backgroundColor: Color(0xFFF8F9FA),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Shimmer.fromColors(
              baseColor: Color(0xFF0066B3).withOpacity(0.2),
              highlightColor: Color(0xFF0066B3).withOpacity(0.4),
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(50),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'JH-Bhopal Health Analytics',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0066B3),
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Loading real-time health data...',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderSection(
    DashboardProvider provider,
    Map<String, dynamic> data,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 50, 20, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200, width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xFF0066B3), Color(0xFF004D99)],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Color(0xFF0066B3).withOpacity(0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.health_and_safety,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'CHETNA VITALS',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF0066B3),
                              letterSpacing: 1.5,
                              height: 1.0,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Community Health Platform',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                              height: 1.0,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Public Health Dashboard',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: Colors.grey.shade900,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
              _buildLiveIndicator(),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              _buildStatChip(
                Icons.people,
                '${provider.users.length} Patients',
                Color(0xFF0066B3),
              ),
              _buildStatChip(
                Icons.medical_services,
                '${data['totalEvents']} Events',
                Color(0xFF2E7D32),
              ),
              _buildStatChip(
                Icons.notifications_active,
                '${data['totalAlerts']} Alerts',
                Color(0xFFD32F2F),
              ),
              if (_isLiveMode)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.circle, size: 8, color: Colors.green),
                      const SizedBox(width: 6),
                      Text(
                        'REAL-TIME',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.green,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterSection(DashboardProvider provider) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 40,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    shrinkWrap: true,
                    itemCount: 4,
                    itemBuilder: (context, index) {
                      final ranges = ['24h', '7d', '30d', 'Custom'];
                      final labels = ['24H', '7D', '30D', 'Custom'];
                      final isSelected =
                          _selectedTimeRange == ranges[index].toLowerCase();

                      return Container(
                        margin: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(
                            labels[index],
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight:
                                  isSelected
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                              color:
                                  isSelected
                                      ? Colors.white
                                      : Colors.grey.shade700,
                            ),
                          ),
                          selected: isSelected,
                          onSelected: (selected) {
                            if (!mounted || _isDisposed) return;
                            setState(() {
                              _selectedTimeRange = ranges[index].toLowerCase();
                              if (ranges[index] == 'Custom') {
                                _showDatePicker = !_showDatePicker;
                              } else {
                                _showDatePicker = false;
                              }
                            });
                          },
                          backgroundColor: Colors.white,
                          selectedColor: Color(0xFF0066B3),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: BorderSide(color: Colors.grey.shade300),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 0,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                onPressed: () {
                  if (mounted && !_isDisposed) {
                    provider.refreshData();
                  }
                },
                icon: Icon(Icons.refresh, color: Color(0xFF0066B3)),
                splashRadius: 20,
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 40,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              shrinkWrap: true,
              itemCount: _filters.length,
              itemBuilder: (context, index) {
                final filter = _filters[index];
                final isSelected = _selectedFilter == filter['id'];

                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(
                      filter['label'],
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? Colors.white : filter['color'],
                      ),
                    ),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (!mounted || _isDisposed) return;
                      setState(() => _selectedFilter = filter['id']);
                    },
                    avatar: Icon(
                      filter['icon'],
                      size: 14,
                      color: isSelected ? Colors.white : filter['color'],
                    ),
                    backgroundColor: Colors.white,
                    selectedColor: filter['color'],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(color: filter['color'].withOpacity(0.2)),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 0,
                    ),
                  ),
                );
              },
            ),
          ),
          if (_showDatePicker) _buildDateRangePicker(),
        ],
      ),
    );
  }

  Widget _buildDateRangePicker() {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Select Date Range',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildDateField(_startDate, 'Start Date', (date) {
                  if (date != null && mounted && !_isDisposed) {
                    setState(() => _startDate = date);
                  }
                }),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildDateField(_endDate, 'End Date', (date) {
                  if (date != null && mounted && !_isDisposed) {
                    setState(() => _endDate = date);
                  }
                }),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    if (!mounted || _isDisposed) return;
                    setState(() => _showDatePicker = false);
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.grey.shade700,
                    side: BorderSide(color: Colors.grey.shade300),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    if (!mounted || _isDisposed) return;
                    setState(() {
                      _showDatePicker = false;
                      _selectedTimeRange = 'custom';
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF0066B3),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    elevation: 0,
                  ),
                  child: const Text('Apply Range'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDateField(
    DateTime date,
    String label,
    Function(DateTime?) onDateSelected,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () async {
            final selectedDate = await showDatePicker(
              context: context,
              initialDate: date,
              firstDate: DateTime.now().subtract(const Duration(days: 365)),
              lastDate: DateTime.now(),
              builder: (context, child) {
                return Theme(
                  data: ThemeData.light().copyWith(
                    colorScheme: const ColorScheme.light(
                      primary: Color(0xFF0066B3),
                      onPrimary: Colors.white,
                    ),
                  ),
                  child: child!,
                );
              },
            );
            onDateSelected(selectedDate);
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_today,
                  size: 18,
                  color: Colors.grey.shade600,
                ),
                const SizedBox(width: 12),
                Text(
                  DateFormat('MMM dd, yyyy').format(date),
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade800,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                Icon(Icons.expand_more, size: 20, color: Colors.grey.shade600),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Map<String, dynamic> _processRealTimeData(
    List<Map<String, dynamic>> events,
    List<Map<String, dynamic>> alerts,
    String timeRange,
    DateTime startDate,
    DateTime endDate,
    int filterId,
    List<Map<String, dynamic>> users,
  ) {
    final now = DateTime.now();
    DateTime startTime;

    switch (timeRange) {
      case '24h':
        startTime = now.subtract(const Duration(hours: 24));
        break;
      case '7d':
        startTime = now.subtract(const Duration(days: 7));
        break;
      case '30d':
        startTime = now.subtract(const Duration(days: 30));
        break;
      case 'custom':
        startTime = startDate;
        break;
      default:
        startTime = now.subtract(const Duration(days: 7));
    }

    List<Map<String, dynamic>> filteredEvents =
        events.where((event) {
          try {
            final timestamp = event['timestamp'];
            if (timestamp == null) return false;

            DateTime eventTime;
            if (timestamp is DateTime) {
              eventTime = timestamp;
            } else if (timestamp is String) {
              eventTime = DateTime.parse(timestamp);
            } else if (timestamp is int) {
              eventTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
            } else {
              return false;
            }

            return eventTime.isAfter(startTime) && eventTime.isBefore(endDate);
          } catch (e) {
            return false;
          }
        }).toList();

    filteredEvents = _applyCategoryFilter(filteredEvents, filterId);

    Map<String, int> eventCounts = _countEventTypes(filteredEvents);
    Map<String, int> alertCounts = _countAlertTypes(alerts);
    List<Map<String, dynamic>> timeDistribution = _calculateTimeDistribution(
      filteredEvents,
      timeRange,
      startTime,
      now,
    );
    Map<String, int> moodCounts = _calculateMoodDistribution(filteredEvents);
    Map<String, double> aiInsights = _calculateAIInsights(
      eventCounts,
      moodCounts,
      filteredEvents.length,
    );
    Map<String, dynamic> userEngagement = _calculateUserEngagement(
      filteredEvents,
      users,
    );

    return {
      'eventCounts': eventCounts,
      'alertCounts': alertCounts,
      'timeDistribution': timeDistribution,
      'moodCounts': moodCounts,
      'filteredEvents': filteredEvents,
      'totalEvents': filteredEvents.length,
      'totalAlerts': alerts.length,
      'aiInsights': aiInsights,
      'fallCount': eventCounts['FALL_DETECTED'] ?? 0,
      'sosCount': eventCounts['SOS_TRIGGERED'] ?? 0,
      'vitalCount': eventCounts.entries
          .where(
            (e) =>
                e.key.contains('HEART') ||
                e.key.contains('BP') ||
                e.key.contains('SPO2'),
          )
          .fold(0, (sum, entry) => sum + entry.value),
      'moodEvents': moodCounts.values.fold(0, (sum, count) => sum + count),
      'userEngagement': userEngagement,
      'activeUsers': users.length,
    };
  }

  List<Map<String, dynamic>> _applyCategoryFilter(
    List<Map<String, dynamic>> events,
    int filterId,
  ) {
    if (filterId == 0) return events;

    return events.where((e) {
      final type = e['type']?.toString().toUpperCase() ?? '';
      final data = e['data'] is Map ? e['data'] as Map : {};

      switch (filterId) {
        case 1: // Critical
          return type.contains('FALL') ||
              type.contains('SOS') ||
              type.contains('EMERGENCY') ||
              type.contains('CRITICAL');
        case 2: // Vitals
          return type.contains('HEART') ||
              type.contains('BP') ||
              type.contains('SPO2') ||
              type.contains('VITAL');
        case 3: // Environmental
          return type.contains('ENVIRONMENT') ||
              type.contains('TEMP') ||
              type.contains('HUMIDITY') ||
              type.contains('AQI');
        case 4: // Wellness
          return type.contains('MOOD') ||
              type.contains('SLEEP') ||
              type.contains('ACTIVITY') ||
              data['mood'] != null;
        default:
          return true;
      }
    }).toList();
  }

  Map<String, int> _countEventTypes(List<Map<String, dynamic>> events) {
    Map<String, int> counts = {};
    for (var event in events) {
      final type = event['type']?.toString() ?? 'UNKNOWN';
      counts[type] = (counts[type] ?? 0) + 1;
    }
    return counts;
  }

  Map<String, int> _countAlertTypes(List<Map<String, dynamic>> alerts) {
    Map<String, int> counts = {};
    for (var alert in alerts) {
      final type = alert['type']?.toString() ?? 'UNKNOWN';
      counts[type] = (counts[type] ?? 0) + 1;
    }
    return counts;
  }

  List<Map<String, dynamic>> _calculateTimeDistribution(
    List<Map<String, dynamic>> events,
    String timeRange,
    DateTime startTime,
    DateTime endTime,
  ) {
    List<Map<String, dynamic>> distribution = [];

    if (timeRange == '24h') {
      for (int i = 0; i < 24; i++) {
        final hourStart = startTime.add(Duration(hours: i));
        final hourEnd = hourStart.add(const Duration(hours: 1));

        final eventsInHour =
            events.where((e) {
              final timestamp = _parseTimestamp(e['timestamp']);
              return timestamp.isAfter(hourStart) &&
                  timestamp.isBefore(hourEnd);
            }).length;

        distribution.add({
          'time': hourStart,
          'label': '${hourStart.hour}:00',
          'count': eventsInHour,
        });
      }
    } else {
      final days = endTime.difference(startTime).inDays;
      for (int i = 0; i <= days; i++) {
        final dayStart = startTime.add(Duration(days: i));
        final dayEnd = dayStart.add(const Duration(days: 1));

        final eventsInDay =
            events.where((e) {
              final timestamp = _parseTimestamp(e['timestamp']);
              return timestamp.isAfter(dayStart) && timestamp.isBefore(dayEnd);
            }).length;

        distribution.add({
          'time': dayStart,
          'label': DateFormat('MMM dd').format(dayStart),
          'count': eventsInDay,
        });
      }
    }

    return distribution;
  }

  Map<String, int> _calculateMoodDistribution(
    List<Map<String, dynamic>> events,
  ) {
    Map<String, int> moodCounts = {
      'happy': 0,
      'neutral': 0,
      'anxious': 0,
      'sad': 0,
      'excited': 0,
    };

    for (var event in events) {
      if (event['type']?.toString().contains('MOOD') ?? false) {
        final data = event['data'];
        if (data is Map) {
          final mood = data['mood']?.toString().toLowerCase() ?? 'neutral';
          if (moodCounts.containsKey(mood)) {
            moodCounts[mood] = moodCounts[mood]! + 1;
          } else {
            moodCounts[mood] = (moodCounts[mood] ?? 0) + 1;
          }
        }
      }
    }

    return moodCounts;
  }

  Map<String, double> _calculateAIInsights(
    Map<String, int> eventCounts,
    Map<String, int> moodCounts,
    int totalEvents,
  ) {
    final fallCount = eventCounts['FALL_DETECTED'] ?? 0;
    final sosCount = eventCounts['SOS_TRIGGERED'] ?? 0;
    final vitalCount = eventCounts['VITAL_SIGN_ALERT'] ?? 0;
    final anxiousCount = moodCounts['anxious'] ?? 0;
    final totalMoods = moodCounts.values.fold(0, (sum, count) => sum + count);

    return {
      'fall_risk':
          totalEvents > 0
              ? (fallCount / totalEvents * 100).clamp(0.0, 100.0) / 100
              : 0.0,
      'anxiety_trend':
          totalMoods > 0
              ? (anxiousCount / totalMoods * 100).clamp(0.0, 100.0) / 100
              : 0.0,
      'vital_alert_rate':
          totalEvents > 0
              ? (vitalCount / totalEvents * 100).clamp(0.0, 100.0) / 100
              : 0.0,
      'safety_score':
          1.0 - ((fallCount + sosCount) / (totalEvents + 10)).clamp(0.0, 1.0),
    };
  }

  Map<String, dynamic> _calculateUserEngagement(
    List<Map<String, dynamic>> events,
    List<Map<String, dynamic>> users,
  ) {
    if (users.isEmpty)
      return {'percentage': 0.0, 'engagedUsers': 0, 'totalUsers': 0};

    final engagedUsers =
        users.where((user) {
          final userId = user['id']?.toString();
          return events.any((e) => e['userId']?.toString() == userId);
        }).length;

    return {
      'percentage': (engagedUsers / users.length * 100).clamp(0.0, 100.0),
      'engagedUsers': engagedUsers,
      'totalUsers': users.length,
    };
  }

  DateTime _parseTimestamp(dynamic timestamp) {
    try {
      if (timestamp is DateTime) return timestamp;
      if (timestamp is String) return DateTime.parse(timestamp);
      if (timestamp is int)
        return DateTime.fromMillisecondsSinceEpoch(timestamp);
      return DateTime.now();
    } catch (e) {
      return DateTime.now();
    }
  }

  Widget _buildRealAIInsights(Map<String, dynamic> data) {
    final aiInsights = data['aiInsights'] as Map<String, double>;

    return Container(
      margin: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'AI Health Risk Assessment',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Colors.grey.shade900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Real-time predictive analytics',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Color(0xFF0066B3).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Color(0xFF0066B3).withOpacity(0.2)),
                ),
                child: Text(
                  'JHU AI Engine',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0066B3),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 4,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.0,
            children: [
              _buildRiskCard(
                'Fall Risk',
                '${(aiInsights['fall_risk']! * 100).toStringAsFixed(0)}%',
                Icons.warning,
                aiInsights['fall_risk']! > 0.3
                    ? Color(0xFFD32F2F)
                    : Color(0xFF2E7D32),
                aiInsights['fall_risk']! > 0.3 ? 'High Risk' : 'Normal',
              ),
              _buildRiskCard(
                'Anxiety Level',
                '${(aiInsights['anxiety_trend']! * 100).toStringAsFixed(0)}%',
                Icons.psychology,
                aiInsights['anxiety_trend']! > 0.4
                    ? Color(0xFFFF9800)
                    : Color(0xFF2E7D32),
                aiInsights['anxiety_trend']! > 0.4 ? 'Elevated' : 'Normal',
              ),
              _buildRiskCard(
                'Vital Alerts',
                '${(aiInsights['vital_alert_rate']! * 100).toStringAsFixed(0)}%',
                Icons.monitor_heart,
                aiInsights['vital_alert_rate']! > 0.2
                    ? Color(0xFFD32F2F)
                    : Color(0xFF2E7D32),
                'Monitor',
              ),
              _buildRiskCard(
                'Safety Score',
                '${(aiInsights['safety_score']! * 100).toStringAsFixed(0)}%',
                Icons.security,
                aiInsights['safety_score']! > 0.8
                    ? Color(0xFF2E7D32)
                    : Color(0xFFFF9800),
                aiInsights['safety_score']! > 0.8
                    ? 'Secure'
                    : 'Needs Attention',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRiskCard(
    String title,
    String value,
    IconData icon,
    Color color,
    String status,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 20, color: color),
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                status,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryTabs() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: TabBar(
        controller: _tabController,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.grey.shade700,
        indicatorSize: TabBarIndicatorSize.tab,
        indicator: BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0066B3), Color(0xFF004D99)],
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        tabs: const [
          Tab(icon: Icon(Icons.dashboard, size: 18), text: 'Overview'),
          Tab(icon: Icon(Icons.monitor_heart, size: 18), text: 'Vitals'),
          Tab(icon: Icon(Icons.thermostat, size: 18), text: 'Environment'),
          Tab(icon: Icon(Icons.security, size: 18), text: 'Safety'),
          Tab(icon: Icon(Icons.analytics, size: 18), text: 'System'),
        ],
      ),
    );
  }

  Widget _buildRealOverviewTab(
    Map<String, dynamic> data,
    DashboardProvider provider,
  ) {
    final timeDistribution =
        data['timeDistribution'] as List<Map<String, dynamic>>;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildActivityChart(timeDistribution),
            const SizedBox(height: 16),
            _buildKeyMetrics(data, provider),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityChart(List<Map<String, dynamic>> distribution) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Community Health Activity',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey.shade900,
                ),
              ),
              Icon(Icons.timeline, color: Color(0xFF0066B3)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Real-time events over time',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: SfCartesianChart(
              primaryXAxis: const CategoryAxis(
                labelStyle: TextStyle(fontSize: 10),
              ),
              primaryYAxis: const NumericAxis(
                labelStyle: TextStyle(fontSize: 10),
              ),
              series: <CartesianSeries>[
                LineSeries<Map<String, dynamic>, String>(
                  dataSource: distribution,
                  xValueMapper: (data, _) => data['label'] as String,
                  yValueMapper: (data, _) => data['count'] as int,
                  color: Color(0xFF0066B3),
                  width: 2,
                  markerSettings: const MarkerSettings(isVisible: true),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKeyMetrics(
    Map<String, dynamic> data,
    DashboardProvider provider,
  ) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.2,
      children: [
        _buildMetricCard(
          'Active Patients',
          data['activeUsers'].toString(),
          Icons.people,
          Color(0xFF0066B3),
          '+12% from last week',
        ),
        _buildMetricCard(
          'Critical Alerts',
          data['totalAlerts'].toString(),
          Icons.notifications_active,
          Color(0xFFD32F2F),
          'Immediate attention needed',
        ),
        _buildMetricCard(
          'Fall Incidents',
          data['fallCount'].toString(),
          Icons.warning,
          Color(0xFFED6C02),
          'Prevention in progress',
        ),
        _buildMetricCard(
          'Vital Readings',
          data['vitalCount'].toString(),
          Icons.monitor_heart,
          Color(0xFF2E7D32),
          'Regular monitoring',
        ),
      ],
    );
  }

  Widget _buildMetricCard(
    String title,
    String value,
    IconData icon,
    Color color,
    String subtitle,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'LIVE',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildRealVitalsTab(Map<String, dynamic> data) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Vital Signs Monitoring',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.grey.shade900,
                        ),
                      ),
                      Icon(Icons.medical_services, color: Color(0xFF2E7D32)),
                    ],
                  ),
                  const SizedBox(height: 20),
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    children: [
                      _buildVitalMetric(
                        'Heart Rate',
                        '72',
                        'BPM',
                        'Normal',
                        Icons.favorite,
                      ),
                      _buildVitalMetric(
                        'Blood Pressure',
                        '120/80',
                        'mmHg',
                        'Optimal',
                        Icons.speed,
                      ),
                      _buildVitalMetric(
                        'SPO₂ Level',
                        '98',
                        '%',
                        'Excellent',
                        Icons.air,
                      ),
                      _buildVitalMetric(
                        'Temperature',
                        '36.6',
                        '°C',
                        'Normal',
                        Icons.thermostat,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVitalMetric(
    String title,
    String value,
    String unit,
    String status,
    IconData icon,
  ) {
    Color statusColor =
        status == 'Normal' || status == 'Optimal' || status == 'Excellent'
            ? Color(0xFF2E7D32)
            : Color(0xFFD32F2F);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: statusColor),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: statusColor,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                unit,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              status,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: statusColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRealEnvironmentalTab(Map<String, dynamic> data) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Environmental Health',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.grey.shade900,
                        ),
                      ),
                      Icon(Icons.eco, color: Color(0xFFED6C02)),
                    ],
                  ),
                  const SizedBox(height: 20),
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    children: [
                      _buildEnvMetric(
                        'Air Quality',
                        '85',
                        'AQI',
                        'Good',
                        Icons.air,
                      ),
                      _buildEnvMetric(
                        'Temperature',
                        '28',
                        '°C',
                        'Moderate',
                        Icons.thermostat,
                      ),
                      _buildEnvMetric(
                        'Humidity',
                        '65',
                        '%',
                        'Comfortable',
                        Icons.water_drop,
                      ),
                      _buildEnvMetric(
                        'Noise Level',
                        '45',
                        'dB',
                        'Quiet',
                        Icons.volume_down,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEnvMetric(
    String title,
    String value,
    String unit,
    String status,
    IconData icon,
  ) {
    Color statusColor =
        status == 'Good' || status == 'Comfortable' || status == 'Quiet'
            ? Color(0xFF2E7D32)
            : Color(0xFFED6C02);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: statusColor),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: statusColor,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                unit,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              status,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: statusColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRealSafetyTab(
    Map<String, dynamic> data,
    DashboardProvider provider,
  ) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Safety & Emergency Response',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.grey.shade900,
                        ),
                      ),
                      Icon(Icons.security, color: Color(0xFFD32F2F)),
                    ],
                  ),
                  const SizedBox(height: 20),
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    children: [
                      _buildSafetyMetric(
                        'Fall Incidents',
                        data['fallCount'].toString(),
                        Icons.warning,
                        data['fallCount'] > 0
                            ? Color(0xFFD32F2F)
                            : Color(0xFF2E7D32),
                      ),
                      _buildSafetyMetric(
                        'SOS Alerts',
                        data['sosCount'].toString(),
                        Icons.emergency,
                        data['sosCount'] > 0
                            ? Color(0xFFD32F2F)
                            : Color(0xFF2E7D32),
                      ),
                      _buildSafetyMetric(
                        'Response Time',
                        '${provider.stats['avgResponseTime'] ?? 45}s',
                        Icons.timer,
                        Color(0xFF0066B3),
                      ),
                      _buildSafetyMetric(
                        'Prevented Falls',
                        '${(data['fallCount'] * 0.3).ceil()}',
                        Icons.health_and_safety,
                        Color(0xFF2E7D32),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSafetyMetric(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRealSystemTab(
    DashboardProvider provider,
    Map<String, dynamic> data,
  ) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'System Health & Status',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.grey.shade900,
                        ),
                      ),
                      Icon(Icons.analytics, color: Color(0xFF0066B3)),
                    ],
                  ),
                  const SizedBox(height: 20),
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    children: [
                      _buildSystemMetric(
                        'System Uptime',
                        '${provider.stats['systemUptime'] ?? '99.8'}%',
                        Icons.cloud_done,
                        provider.isConnected
                            ? Color(0xFF2E7D32)
                            : Color(0xFFD32F2F),
                      ),
                      _buildSystemMetric(
                        'Data Sync',
                        '${provider.stats['syncStatus'] ?? '100'}%',
                        Icons.sync,
                        Color(0xFF0066B3),
                      ),
                      _buildSystemMetric(
                        'Active Devices',
                        provider.activeUsersCount.toString(),
                        Icons.device_hub,
                        Color(0xFF7B1FA2),
                      ),
                      _buildSystemMetric(
                        'Firebase Status',
                        provider.isConnected ? 'Connected' : 'Disconnected',
                        Icons.wifi,
                        provider.isConnected
                            ? Color(0xFF2E7D32)
                            : Color(0xFFD32F2F),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSystemMetric(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRealAdvancedAnalytics(
    Map<String, dynamic> data,
    DashboardProvider provider,
  ) {
    final userEngagement = data['userEngagement'] as Map<String, dynamic>;

    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Community Health Insights',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Colors.grey.shade900,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Color(0xFF0066B3).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Color(0xFF0066B3).withOpacity(0.2)),
                ),
                child: Text(
                  'JHU RESEARCH',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0066B3),
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Data-driven insights for preventive healthcare',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 20),

          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            children: [
              _buildAdvancedMetric(
                'Patient Engagement',
                '${userEngagement['percentage'].toStringAsFixed(1)}%',
                Icons.people,
                Color(0xFF0066B3),
                '${userEngagement['engagedUsers']} active patients',
              ),
              _buildAdvancedMetric(
                'Data Accuracy',
                '${_calculateDataQuality(data).toStringAsFixed(1)}%',
                Icons.data_object,
                Color(0xFF2E7D32),
                'High-quality health data',
              ),
              _buildAdvancedMetric(
                'Risk Patterns',
                '${_calculatePatternRecognition(data).toStringAsFixed(1)}%',
                Icons.pattern,
                Color(0xFF7B1FA2),
                'Predictive analytics active',
              ),
              _buildAdvancedMetric(
                'Prevention Rate',
                '${((data['totalEvents'] - data['fallCount']) / data['totalEvents'] * 100).toStringAsFixed(1)}%',
                Icons.health_and_safety,
                Color(0xFFED6C02),
                'Successful interventions',
              ),
            ],
          ),
        ],
      ),
    );
  }

  double _calculateDataQuality(Map<String, dynamic> data) {
    final filteredEvents = data['filteredEvents'] as List<Map<String, dynamic>>;
    if (filteredEvents.isEmpty) return 0.0;

    int validEvents = 0;
    for (var event in filteredEvents) {
      if (event.containsKey('type') && event.containsKey('timestamp')) {
        validEvents++;
      }
    }

    return (validEvents / filteredEvents.length * 100).clamp(0.0, 100.0);
  }

  double _calculatePatternRecognition(Map<String, dynamic> data) {
    final eventCounts = data['eventCounts'] as Map<String, int>;
    final total = data['totalEvents'] as int;
    if (total < 10) return 0.0;

    final uniqueTypes = eventCounts.keys.length;
    return (uniqueTypes / total * 100).clamp(0.0, 100.0);
  }

  Widget _buildAdvancedMetric(
    String title,
    String value,
    IconData icon,
    Color color,
    String subtitle,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 18, color: color),
              ),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildRealDataTable(List<Map<String, dynamic>> events) {
    final displayEvents = events.take(10).toList();

    return Container(
      margin: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Recent Health Events',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Colors.grey.shade900,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Color(0xFF0066B3).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${events.length} Total Events',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF0066B3),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

          if (displayEvents.isEmpty)
            _buildEmptyState()
          else
            _buildEventsTable(displayEvents),
        ],
      ),
    );
  }

  Widget _buildEventsTable(List<Map<String, dynamic>> events) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: DataTable(
          headingRowColor: MaterialStateProperty.resolveWith<Color?>(
            (Set<MaterialState> states) => Colors.grey.shade50,
          ),
          columns: const [
            DataColumn(
              label: Text(
                'Event Type',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            DataColumn(
              label: Text(
                'Patient ID',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            DataColumn(
              label: Text(
                'Time',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            DataColumn(
              label: Text(
                'Status',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            DataColumn(
              label: Text(
                'Priority',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
          rows:
              events.map((event) {
                final type = event['type']?.toString() ?? 'Unknown';
                final userId = event['userId']?.toString() ?? 'unknown';
                final timestamp = _parseTimestamp(event['timestamp']);
                final status = event['status']?.toString() ?? 'logged';
                final priority = event['priority']?.toString() ?? 'medium';

                return DataRow(
                  cells: [
                    DataCell(
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: _getEventColor(type),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(_getEventDisplayName(type)),
                        ],
                      ),
                    ),
                    DataCell(
                      Text(
                        userId.length > 8
                            ? '${userId.substring(0, 8)}...'
                            : userId,
                        style: TextStyle(fontFamily: 'monospace', fontSize: 12),
                      ),
                    ),
                    DataCell(
                      Text(DateFormat('MMM dd, hh:mm a').format(timestamp)),
                    ),
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: _getStatusColor(status).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          status.toUpperCase(),
                          style: TextStyle(
                            fontSize: 10,
                            color: _getStatusColor(status),
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: _getPriorityColor(priority).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          priority.toUpperCase(),
                          style: TextStyle(
                            fontSize: 10,
                            color: _getPriorityColor(priority),
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              }).toList(),
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'resolved':
        return Color(0xFF2E7D32);
      case 'critical':
        return Color(0xFFD32F2F);
      case 'monitoring':
        return Color(0xFFED6C02);
      default:
        return Color(0xFF0066B3);
    }
  }

  Color _getPriorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'high':
        return Color(0xFFD32F2F);
      case 'medium':
        return Color(0xFFED6C02);
      case 'low':
        return Color(0xFF2E7D32);
      default:
        return Color(0xFF0066B3);
    }
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        children: [
          Icon(
            Icons.medical_services_outlined,
            size: 48,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'No health events in selected time range',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Data will appear when events are logged',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingActions() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        FloatingActionButton.small(
          heroTag: 'export',
          onPressed: _exportData,
          backgroundColor: Colors.white,
          foregroundColor: Color(0xFF0066B3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.download, size: 20),
        ),
        const SizedBox(height: 12),
        FloatingActionButton(
          heroTag: 'live',
          onPressed: () {
            if (!mounted || _isDisposed) return;
            setState(() {
              _isLiveMode = !_isLiveMode;
              if (_isLiveMode) {
                _startLiveMode();
              } else {
                _stopLiveMode();
              }
            });
          },
          backgroundColor: _isLiveMode ? Color(0xFFD32F2F) : Color(0xFF2E7D32),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(
            _isLiveMode ? Icons.pause : Icons.play_arrow,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  void _exportData() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          margin: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 20,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    const Text(
                      'Export Health Data',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Generate reports for JHU research',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              _buildExportOption(
                'CSV for Research',
                Icons.table_chart,
                'Standard format',
              ),
              _buildExportOption(
                'PDF Report',
                Icons.picture_as_pdf,
                'Detailed analysis',
              ),
              _buildExportOption('JSON Data', Icons.code, 'API integration'),
              _buildExportOption(
                'Share with JHU',
                Icons.share,
                'Collaborative research',
              ),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text(
                            'Exporting health data for JHU research...',
                          ),
                          backgroundColor: Color(0xFF0066B3),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF0066B3),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text('Generate Report'),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Widget _buildExportOption(String title, IconData icon, String subtitle) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Color(0xFF0066B3).withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: Color(0xFF0066B3), size: 20),
      ),
      title: Text(title, style: TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(
        subtitle,
        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
      ),
      trailing: Icon(Icons.chevron_right, color: Colors.grey.shade400),
      onTap: () {},
    );
  }

  Color _getEventColor(String type) {
    switch (type.toUpperCase()) {
      case 'FALL_DETECTED':
      case 'SOS_TRIGGERED':
        return Color(0xFFD32F2F);
      case 'VITAL_SIGN_ALERT':
      case 'HEART_RATE_ALERT':
        return Color(0xFF2E7D32);
      case 'ENVIRONMENT_ALERT':
        return Color(0xFFED6C02);
      case 'MOOD_LOG':
        return Color(0xFF7B1FA2);
      default:
        return Color(0xFF0066B3);
    }
  }

  String _getEventDisplayName(String type) {
    switch (type.toUpperCase()) {
      case 'FALL_DETECTED':
        return 'Fall Detected';
      case 'SOS_TRIGGERED':
        return 'Emergency SOS';
      case 'VITAL_SIGN_ALERT':
        return 'Vital Sign Alert';
      case 'HEART_RATE_ALERT':
        return 'Heart Rate Alert';
      case 'ENVIRONMENT_ALERT':
        return 'Environmental Alert';
      case 'MOOD_LOG':
        return 'Mood Assessment';
      default:
        return type.replaceAll('_', ' ');
    }
  }
}
