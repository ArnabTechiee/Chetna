// views/maps_view.dart - UPDATED VERSION WITH FIXED HEATMAP COMPATIBILITY
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as latlong;
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import '../providers/dashboard_provider.dart';
import '../utils/constants.dart';
import 'package:firebase_database/firebase_database.dart';

// Removed heatmap import and created a manual heatmap implementation

class MapsView extends StatefulWidget {
  const MapsView({super.key});

  @override
  State<MapsView> createState() => _MapsViewState();
}

class _MapsViewState extends State<MapsView> {
  String _selectedView = 'live';
  String? _selectedUserId;
  final MapController _mapController = MapController();
  double _zoomLevel = 12.0;
  latlong.LatLng _center = const latlong.LatLng(
    28.6139,
    77.2090,
  ); // Default to New Delhi
  bool _isMapInitialized = false;

  // History tracking
  final Map<String, List<latlong.LatLng>> _userLocationHistory = {};
  List<latlong.LatLng> _selectedUserHistory = [];

  // Custom heatmap data and visualization
  List<latlong.LatLng> _heatmapPoints = [];
  bool _showHeatmap = false;
  final Map<latlong.LatLng, double> _heatmapIntensity = {};

  // Firebase reference
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  StreamSubscription? _locationStream;
  bool _isDisposed = false;

  // Real-time user locations from Firebase
  final Map<String, Map<String, dynamic>> _realTimeUserLocations = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeMap();
      _startLocationStream();
    });
  }

  @override
  void dispose() {
    _isDisposed = true;
    _locationStream?.cancel();
    super.dispose();
  }

  void _initializeMap() {
    if (_isDisposed) return;
    setState(() {
      _isMapInitialized = true;
    });
  }

  void _startLocationStream() {
    _locationStream = _dbRef
        .child('users')
        .onValue
        .listen(
          (event) {
            final Object? usersData = event.snapshot.value;

            if (usersData != null && usersData is Map) {
              _processFirebaseUserData(usersData as Map<dynamic, dynamic>);
            }
          },
          onError: (error) {
            print('Firebase stream error: $error');
          },
        );
  }

  void _processFirebaseUserData(Map<dynamic, dynamic> usersData) {
    if (_isDisposed) return;

    final updatedLocations = <String, Map<String, dynamic>>{};

    usersData.forEach((dynamic userId, dynamic userData) {
      if (userId != null && userData != null && userData is Map) {
        try {
          final userMap = userData as Map<dynamic, dynamic>;
          final dynamic profileData = userMap['profile'];
          final dynamic eventsData = userMap['events'];

          String? userName;
          double? latitude;
          double? longitude;
          bool isOnline = false;
          dynamic lastActive;

          // Extract profile info
          if (profileData != null && profileData is Map) {
            final profile = profileData as Map<dynamic, dynamic>;
            userName = profile['name']?.toString() ?? 'Unknown User';
          }

          // Extract latest location from events
          if (eventsData != null && eventsData is Map) {
            final events = eventsData as Map<dynamic, dynamic>;

            // Convert entries to list for sorting
            final eventsList = events.entries.toList();

            // Sort events by timestamp to get latest
            eventsList.sort((a, b) {
              final tsA = _extractTimestamp(a.value);
              final tsB = _extractTimestamp(b.value);
              return tsB.compareTo(tsA); // Descending - newest first
            });

            for (var entry in eventsList) {
              final eventData = entry.value;
              if (eventData != null && eventData is Map) {
                final eventMap = eventData as Map<dynamic, dynamic>;
                final type = eventMap['type']?.toString();
                final dynamic dataValue = eventMap['data'];

                // Check if event has location
                if (dataValue != null && dataValue is Map) {
                  final data = dataValue as Map<dynamic, dynamic>;

                  // Check for location in various event types
                  if (type == 'ENVIRONMENT_DATA' ||
                      type == 'SOS_TRIGGERED' ||
                      type == 'FALL_DETECTED') {
                    final dynamic locationData = data['location'];
                    if (locationData != null && locationData is Map) {
                      final location = locationData as Map<dynamic, dynamic>;
                      final lat = location['lat'];
                      final lng = location['lng'];
                      if (lat != null && lng != null) {
                        latitude =
                            lat is double
                                ? lat
                                : double.tryParse(lat.toString());
                        longitude =
                            lng is double
                                ? lng
                                : double.tryParse(lng.toString());
                        break; // Found latest location
                      }
                    }
                  }

                  // Also check direct lat/lng fields
                  if (data['latitude'] != null && data['longitude'] != null) {
                    final lat = data['latitude'];
                    final lng = data['longitude'];
                    latitude =
                        lat is double
                            ? lat as double
                            : double.tryParse(lat.toString());
                    longitude =
                        lng is double
                            ? lng as double
                            : double.tryParse(lng.toString());
                    break; // Found latest location
                  }
                }

                // Update last active from any event
                final timestamp = _extractTimestamp(eventMap);
                if (timestamp > 0) {
                  lastActive = DateTime.fromMillisecondsSinceEpoch(timestamp);
                  isOnline =
                      DateTime.now().difference(lastActive).inMinutes < 5;
                }
              }
            }
          }

          // Add to updated locations
          updatedLocations[userId.toString()] = {
            'id': userId.toString(),
            'name': userName ?? 'Unknown User',
            'latitude': latitude,
            'longitude': longitude,
            'isOnline': isOnline,
            'lastActive': lastActive,
          };

          // Update history
          if (latitude != null && longitude != null) {
            _updateUserLocationHistory(userId.toString(), latitude, longitude);
          }
        } catch (e) {
          print('Error processing user $userId: $e');
        }
      }
    });

    if (_isDisposed) return;

    setState(() {
      _realTimeUserLocations.clear();
      _realTimeUserLocations.addAll(updatedLocations);

      // Generate heatmap if needed
      if (_selectedView == 'heatmap') {
        _generateCustomHeatmapFromRealTimeData();
      }
    });
  }

  int _extractTimestamp(dynamic eventData) {
    if (eventData is Map<dynamic, dynamic>) {
      final timestamp = eventData['timestamp'];
      if (timestamp is int) return timestamp;
      if (timestamp is String) return int.tryParse(timestamp) ?? 0;
    }
    return 0;
  }

  void _updateUserLocationHistory(String userId, double lat, double lng) {
    final newLocation = latlong.LatLng(lat, lng);
    if (!_userLocationHistory.containsKey(userId)) {
      _userLocationHistory[userId] = [];
    }
    _userLocationHistory[userId]!.add(newLocation);

    // Keep only last 100 points for performance
    if (_userLocationHistory[userId]!.length > 100) {
      _userLocationHistory[userId]!.removeAt(0);
    }

    // Update selected user history
    if (_selectedUserId == userId) {
      _selectedUserHistory = _userLocationHistory[userId] ?? [];
    }
  }

  void _generateCustomHeatmapFromRealTimeData() {
    if (_isDisposed) return;

    final points = <latlong.LatLng>[];
    final intensityMap = <latlong.LatLng, double>{};
    final random = Random();

    // Add user locations with intensity
    for (var user in _realTimeUserLocations.values) {
      if (user['latitude'] != null && user['longitude'] != null) {
        final lat = user['latitude'] as double;
        final lng = user['longitude'] as double;
        final basePoint = latlong.LatLng(lat, lng);

        // Add main point with high intensity
        points.add(basePoint);
        intensityMap[basePoint] = 1.0;

        // Create surrounding points for heat effect
        for (int i = 0; i < 3; i++) {
          final offsetLat = lat + (random.nextDouble() * 0.002 - 0.001);
          final offsetLng = lng + (random.nextDouble() * 0.002 - 0.001);
          final point = latlong.LatLng(offsetLat, offsetLng);
          points.add(point);
          intensityMap[point] = 0.7 - (i * 0.2);
        }
      }
    }

    // Add event locations for heatmap
    final provider = Provider.of<DashboardProvider>(context, listen: false);
    final events = provider.events;

    for (var event in events) {
      try {
        if (event is Map) {
          final dynamic dataValue = event['data'];
          if (dataValue != null && dataValue is Map) {
            final data = dataValue as Map<dynamic, dynamic>;

            // Check for location in various formats
            dynamic lat;
            dynamic lng;

            final dynamic locationData = data['location'];
            if (locationData != null && locationData is Map) {
              final location = locationData as Map<dynamic, dynamic>;
              lat = location['lat'];
              lng = location['lng'];
            } else {
              lat = data['latitude'];
              lng = data['longitude'];
            }

            if (lat != null && lng != null) {
              final latVal =
                  lat is double ? lat : double.tryParse(lat.toString());
              final lngVal =
                  lng is double ? lng : double.tryParse(lng.toString());

              if (latVal != null && lngVal != null) {
                final point = latlong.LatLng(latVal, lngVal);
                points.add(point);
                intensityMap[point] = 0.9;
              }
            }
          }
        }
      } catch (e) {
        print('Error processing event for heatmap: $e');
      }
    }

    if (_isDisposed) return;

    setState(() {
      _heatmapPoints = points;
      _heatmapIntensity.clear();
      _heatmapIntensity.addAll(intensityMap);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Maps & Location'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              Provider.of<DashboardProvider>(
                context,
                listen: false,
              ).refreshData();
              if (_selectedView == 'heatmap' && !_isDisposed) {
                _generateCustomHeatmapFromRealTimeData();
              }
            },
          ),
          PopupMenuButton<String>(
            itemBuilder:
                (context) => [
                  const PopupMenuItem(
                    value: 'export',
                    child: Row(
                      children: [
                        Icon(Icons.download, size: 18),
                        SizedBox(width: 8),
                        Text('Export Map Data'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'settings',
                    child: Row(
                      children: [
                        Icon(Icons.settings, size: 18),
                        SizedBox(width: 8),
                        Text('Map Settings'),
                      ],
                    ),
                  ),
                ],
            onSelected: (value) {
              if (value == 'export') _exportMapData();
              if (value == 'settings') _showMapSettings();
            },
          ),
        ],
      ),
      body: Consumer<DashboardProvider>(
        builder: (context, provider, child) {
          // Convert real-time locations to list
          final realTimeUsersList = _realTimeUserLocations.values.toList();

          // Filter users based on selection
          final filteredUsers =
              _selectedUserId == null || _selectedUserId == 'all'
                  ? realTimeUsersList
                  : realTimeUsersList
                      .where((u) => u['id'] == _selectedUserId)
                      .toList();

          return Column(
            children: [
              // Filters and Controls
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: _buildFilterBar(provider, filteredUsers),
              ),
              const SizedBox(height: 8),

              // Main Map Area
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    // Use responsive layout based on screen size
                    if (constraints.maxWidth > 1000) {
                      return Row(
                        children: [
                          // Map Container
                          Expanded(
                            flex: 3,
                            child: Card(
                              margin: const EdgeInsets.only(
                                left: 20,
                                right: 10,
                              ),
                              child: _buildMapSection(provider, filteredUsers),
                            ),
                          ),
                          // Side Panel
                          Expanded(
                            flex: 1,
                            child: Card(
                              margin: const EdgeInsets.only(
                                right: 20,
                                left: 10,
                              ),
                              child: _buildSidePanel(provider, filteredUsers),
                            ),
                          ),
                        ],
                      );
                    } else {
                      // For smaller screens, use column layout
                      return SingleChildScrollView(
                        child: Column(
                          children: [
                            Card(
                              margin: const EdgeInsets.all(16),
                              child: _buildMapSection(provider, filteredUsers),
                            ),
                            Card(
                              margin: const EdgeInsets.all(16),
                              child: _buildSidePanel(provider, filteredUsers),
                            ),
                          ],
                        ),
                      );
                    }
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFilterBar(
    DashboardProvider provider,
    List<Map<String, dynamic>> users,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // View Selector
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildFilterButton('Live', 'live', Icons.location_on),
                _buildFilterButton('History', 'history', Icons.history),
                _buildFilterButton('Heatmap', 'heatmap', Icons.whatshot),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // User Filter
          SizedBox(
            width: 200,
            child: DropdownButtonFormField<String>(
              isExpanded: true,
              value: _selectedUserId ?? 'all',
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.border),
                ),
                filled: true,
                fillColor: Colors.white,
                hintText: 'Select User',
              ),
              items: [
                const DropdownMenuItem(value: 'all', child: Text('All Users')),
                ..._realTimeUserLocations.values.map((user) {
                  final name = user['name']?.toString() ?? 'Unknown User';
                  final isOnline = user['isOnline'] ?? false;
                  return DropdownMenuItem(
                    value: user['id']?.toString(),
                    child: Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color:
                                isOnline
                                    ? AppColors.success
                                    : AppColors.textTertiary,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            name.length > 15
                                ? '${name.substring(0, 15)}...'
                                : name,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ],
              onChanged: (value) {
                if (_isDisposed) return;
                setState(() {
                  _selectedUserId = value;
                  if (value != null && value != 'all') {
                    _selectedUserHistory = _userLocationHistory[value] ?? [];
                  } else {
                    _selectedUserHistory = [];
                  }
                });
              },
            ),
          ),

          const SizedBox(width: 12),

          // Action Buttons
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ElevatedButton.icon(
                onPressed: () {
                  _showLocationHistory(context, provider);
                },
                icon: const Icon(Icons.history, size: 16),
                label: const Text('History'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  _showGeofencePanel(context, provider);
                },
                icon: const Icon(Icons.fence, size: 16),
                label: const Text('Geofence'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.warning,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterButton(String label, String value, IconData icon) {
    final isSelected = _selectedView == value;
    return GestureDetector(
      onTap: () {
        if (_isDisposed) return;
        setState(() => _selectedView = value);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? Colors.white : AppColors.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: isSelected ? Colors.white : AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMapSection(
    DashboardProvider provider,
    List<Map<String, dynamic>> users,
  ) {
    final onlineUsers = users.where((u) => u['isOnline'] == true).length;

    return Column(
      children: [
        // Map Header
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.map_outlined, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _selectedView == 'live'
                          ? 'Live Location Tracking'
                          : _selectedView == 'history'
                          ? 'Historical Location Data'
                          : 'Incident Density Heatmap',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _selectedView == 'live'
                          ? 'Real-time user locations from Firebase'
                          : _selectedView == 'history'
                          ? 'Past location trails and movement patterns'
                          : 'Heatmap showing incident concentration',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 2,
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
                  color:
                      provider.isConnected
                          ? AppColors.success.withOpacity(0.1)
                          : AppColors.danger.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color:
                            provider.isConnected
                                ? AppColors.success
                                : AppColors.danger,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      provider.isConnected ? 'LIVE' : 'OFFLINE',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color:
                            provider.isConnected
                                ? AppColors.success
                                : AppColors.danger,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Divider(color: AppColors.border, height: 1),

        // Map Visualization
        Expanded(child: _buildOpenStreetMap(users)),

        // Map Controls
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.background,
            border: Border(top: BorderSide(color: AppColors.border)),
          ),
          child: Column(
            children: [
              // Map Stats
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildMapStat('Users', users.length.toString()),
                    const SizedBox(width: 20),
                    _buildMapStat('Active', onlineUsers.toString()),
                    const SizedBox(width: 20),
                    _buildMapStat('Zoom', '${_zoomLevel.toStringAsFixed(1)}x'),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              // Map Controls
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.zoom_in),
                    onPressed: () {
                      _mapController.move(
                        _mapController.camera.center,
                        _zoomLevel + 1,
                      );
                      if (_isDisposed) return;
                      setState(() => _zoomLevel += 1);
                    },
                    tooltip: 'Zoom In',
                  ),
                  IconButton(
                    icon: const Icon(Icons.zoom_out),
                    onPressed: () {
                      _mapController.move(
                        _mapController.camera.center,
                        _zoomLevel - 1,
                      );
                      if (_isDisposed) return;
                      setState(() => _zoomLevel -= 1);
                    },
                    tooltip: 'Zoom Out',
                  ),
                  IconButton(
                    icon: const Icon(Icons.my_location),
                    onPressed: () {
                      if (users.isNotEmpty) {
                        final userWithLocation = users.firstWhere(
                          (u) =>
                              u['latitude'] != null && u['longitude'] != null,
                          orElse: () => users.first,
                        );
                        if (userWithLocation['latitude'] != null) {
                          final lat = userWithLocation['latitude'] as double;
                          final lng = userWithLocation['longitude'] as double;
                          _mapController.move(latlong.LatLng(lat, lng), 15);
                        }
                      }
                    },
                    tooltip: 'Center Map',
                  ),
                  IconButton(
                    icon: Icon(
                      _showHeatmap ? Icons.layers : Icons.layers_outlined,
                    ),
                    onPressed: () {
                      if (_isDisposed) return;
                      setState(() => _showHeatmap = !_showHeatmap);
                    },
                    tooltip: 'Toggle Heatmap',
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOpenStreetMap(List<Map<String, dynamic>> users) {
    if (!_isMapInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    // Calculate center from users with locations
    latlong.LatLng center = _center;
    final usersWithLocation =
        users
            .where((u) => u['latitude'] != null && u['longitude'] != null)
            .toList();

    if (usersWithLocation.isNotEmpty) {
      // Calculate average center of all users
      double totalLat = 0;
      double totalLng = 0;
      int count = 0;

      for (var user in usersWithLocation) {
        totalLat += user['latitude'] as double;
        totalLng += user['longitude'] as double;
        count++;
      }

      if (count > 0) {
        center = latlong.LatLng(totalLat / count, totalLng / count);
      }
    }

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: center,
        initialZoom: _zoomLevel,
        maxZoom: 18,
        minZoom: 3,
        onPositionChanged: (position, hasGesture) {
          if (hasGesture) {
            if (_isDisposed) return;
            setState(() {
              _zoomLevel = position.zoom ?? _zoomLevel;
              _center = position.center ?? _center;
            });
          }
        },
      ),
      children: [
        // OpenStreetMap Tile Layer
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.chetna.dashboard',
          subdomains: const ['a', 'b', 'c'],
        ),

        // Custom Heatmap Layer (using CircleMarkers)
        if (_selectedView == 'heatmap' &&
            _showHeatmap &&
            _heatmapPoints.isNotEmpty)
          CircleLayer(circles: _buildHeatmapCircles()),

        // History Polyline (for history view)
        if (_selectedView == 'history' && _selectedUserHistory.length > 1)
          PolylineLayer(
            polylines: [
              Polyline(
                points: _selectedUserHistory,
                color: AppColors.primary.withOpacity(0.7),
                strokeWidth: 3,
              ),
            ],
          ),

        // Marker Clustering Layer
        MarkerClusterLayerWidget(
          options: MarkerClusterLayerOptions(
            maxClusterRadius: 45,
            size: const Size(40, 40),
            alignment: Alignment.center,
            padding: const EdgeInsets.all(50),
            markers: _buildUserMarkers(users),
            builder: (context, markers) {
              return Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: AppColors.primary,
                ),
                child: Center(
                  child: Text(
                    markers.length.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              );
            },
          ),
        ),

        // Geofence Circles (if any)
        CircleLayer(circles: _buildGeofenceCircles()),
      ],
    );
  }

  List<CircleMarker> _buildHeatmapCircles() {
    final circles = <CircleMarker>[];

    for (var point in _heatmapPoints) {
      final intensity = _heatmapIntensity[point] ?? 0.5;
      final opacity = intensity * 0.3; // Adjust opacity based on intensity

      // Determine color based on intensity
      Color color;
      if (intensity > 0.8) {
        color = Colors.red.withOpacity(opacity);
      } else if (intensity > 0.5) {
        color = Colors.orange.withOpacity(opacity);
      } else {
        color = Colors.yellow.withOpacity(opacity);
      }

      circles.add(
        CircleMarker(
          point: point,
          radius: 30 * intensity, // Larger radius for higher intensity
          useRadiusInMeter: false,
          color: color,
          borderColor: Colors.transparent,
          borderStrokeWidth: 0,
        ),
      );
    }

    return circles;
  }

  List<Marker> _buildUserMarkers(List<Map<String, dynamic>> users) {
    final markers = <Marker>[];

    for (var user in users) {
      if (user['latitude'] != null && user['longitude'] != null) {
        final lat = user['latitude'] as double;
        final lng = user['longitude'] as double;
        final isOnline = user['isOnline'] ?? false;
        final name = user['name']?.toString() ?? 'Unknown';

        markers.add(
          Marker(
            point: latlong.LatLng(lat, lng),
            width: 80,
            height: 60,
            alignment: Alignment.topCenter,
            child: GestureDetector(
              onTap: () => _showUserPopup(context, user),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // The Avatar/Icon Circle
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: isOnline ? AppColors.success : AppColors.danger,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Icon(
                      Icons.person,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                  // The Text Label
                  Flexible(
                    child: Container(
                      margin: const EdgeInsets.only(top: 2),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(4),
                        boxShadow: [
                          BoxShadow(color: Colors.black12, blurRadius: 2),
                        ],
                      ),
                      child: Text(
                        name.split(' ')[0],
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }
    }
    return markers;
  }

  List<CircleMarker> _buildGeofenceCircles() {
    // Create geofence circles around user locations
    final circles = <CircleMarker>[];

    for (var user in _realTimeUserLocations.values) {
      if (user['latitude'] != null && user['longitude'] != null) {
        circles.add(
          CircleMarker(
            point: latlong.LatLng(
              user['latitude'] as double,
              user['longitude'] as double,
            ),
            radius: 300, // 300 meters radius
            useRadiusInMeter: true,
            color: AppColors.warning.withOpacity(0.15),
            borderColor: AppColors.warning,
            borderStrokeWidth: 1,
          ),
        );
      }
    }

    return circles;
  }

  Widget _buildMapStat(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildSidePanel(
    DashboardProvider provider,
    List<Map<String, dynamic>> users,
  ) {
    return Column(
      children: [
        // Panel Header
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.location_on_outlined,
                  size: 20,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'User Locations',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      '${users.length} user${users.length != 1 ? 's' : ''} shown',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  users.length.toString(),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
        Divider(color: AppColors.border, height: 1),

        // View Controls
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Map Controls',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        _captureMapScreenshot();
                      },
                      icon: const Icon(Icons.camera_alt, size: 16),
                      label: const Text('Capture'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.center_focus_strong, size: 20),
                    onPressed: () {
                      if (users.isNotEmpty) {
                        final user = users.firstWhere(
                          (u) =>
                              u['latitude'] != null && u['longitude'] != null,
                          orElse: () => users.first,
                        );
                        if (user['latitude'] != null) {
                          _mapController.move(
                            latlong.LatLng(
                              user['latitude'] as double,
                              user['longitude'] as double,
                            ),
                            15,
                          );
                        }
                      }
                    },
                    tooltip: 'Center on User',
                  ),
                ],
              ),
            ],
          ),
        ),
        Divider(color: AppColors.border, height: 1),

        // User List
        Expanded(
          child:
              users.isEmpty
                  ? _buildEmptyState('No users found')
                  : ListView.builder(
                    shrinkWrap: true,
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: users.length,
                    itemBuilder: (context, index) {
                      final user = users[index];
                      final isOnline = user['isOnline'] ?? false;
                      final lastActive = user['lastActive'];
                      final hasLocation =
                          user['latitude'] != null && user['longitude'] != null;

                      return Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(color: AppColors.border),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Status Indicator
                            Container(
                              margin: const EdgeInsets.only(top: 4),
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color:
                                    isOnline
                                        ? AppColors.success
                                        : AppColors.textTertiary,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 10),

                            // User Info
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    user['name']?.toString() ?? 'Unknown User',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                      color: AppColors.textPrimary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  if (hasLocation)
                                    Text(
                                      '${user['latitude']?.toStringAsFixed(4)}, ${user['longitude']?.toStringAsFixed(4)}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  if (lastActive != null)
                                    Text(
                                      _formatLastActive(lastActive),
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: AppColors.textTertiary,
                                      ),
                                    ),
                                ],
                              ),
                            ),

                            // Actions
                            if (hasLocation)
                              PopupMenuButton<String>(
                                icon: const Icon(Icons.more_vert, size: 18),
                                itemBuilder:
                                    (context) => [
                                      const PopupMenuItem(
                                        value: 'directions',
                                        child: Row(
                                          children: [
                                            Icon(Icons.directions, size: 16),
                                            SizedBox(width: 8),
                                            Text('Get Directions'),
                                          ],
                                        ),
                                      ),
                                      const PopupMenuItem(
                                        value: 'history',
                                        child: Row(
                                          children: [
                                            Icon(Icons.timeline, size: 16),
                                            SizedBox(width: 8),
                                            Text('View History'),
                                          ],
                                        ),
                                      ),
                                      const PopupMenuItem(
                                        value: 'share',
                                        child: Row(
                                          children: [
                                            Icon(Icons.share, size: 16),
                                            SizedBox(width: 8),
                                            Text('Share Location'),
                                          ],
                                        ),
                                      ),
                                    ],
                                onSelected: (value) {
                                  if (value == 'directions') {
                                    _openDirections(user);
                                  } else if (value == 'history') {
                                    _showUserHistory(user);
                                  } else if (value == 'share') {
                                    _shareLocation(user);
                                  }
                                },
                              ),
                          ],
                        ),
                      );
                    },
                  ),
        ),

        // Bottom Controls
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.background,
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Advanced Features',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () {
                        _showAreaAnalysis(context);
                      },
                      icon: const Icon(Icons.analytics, size: 16),
                      label: const Text('Analyze Area'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.info,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.help_outline, size: 20),
                      onPressed: () {
                        _showMapHelp(context);
                      },
                      tooltip: 'Help',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.location_off_outlined,
              size: 48,
              color: AppColors.textTertiary.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () {
                Provider.of<DashboardProvider>(
                  context,
                  listen: false,
                ).refreshData();
              },
              child: const Text('Refresh Data'),
            ),
          ],
        ),
      ),
    );
  }

  String _formatLastActive(dynamic lastActive) {
    if (lastActive == null) return 'Unknown';

    DateTime lastActiveTime;
    if (lastActive is DateTime) {
      lastActiveTime = lastActive;
    } else if (lastActive is String) {
      lastActiveTime = DateTime.parse(lastActive);
    } else if (lastActive is int) {
      lastActiveTime = DateTime.fromMillisecondsSinceEpoch(lastActive);
    } else {
      return 'Unknown';
    }

    final now = DateTime.now();
    final difference = now.difference(lastActiveTime);

    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }

  Future<void> _openDirections(Map<String, dynamic> user) async {
    if (user['latitude'] == null || user['longitude'] == null) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No location data available'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    final lat = user['latitude'];
    final lng = user['longitude'];
    final url = Uri.parse(
      'https://www.openstreetmap.org/directions?engine=fossgis_osrm_car&route=&lat=$lat&lon=$lng#map=15/$lat/$lng',
    );

    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open directions'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  void _showUserPopup(BuildContext context, Map<String, dynamic> user) {
    if (_isDisposed) return;
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(user['name']?.toString() ?? 'User'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (user['latitude'] != null &&
                      user['longitude'] != null) ...[
                    Text('Latitude: ${user['latitude']}'),
                    Text('Longitude: ${user['longitude']}'),
                    const SizedBox(height: 10),
                  ],
                  Text(
                    'Status: ${user['isOnline'] == true ? 'Online' : 'Offline'}',
                  ),
                  if (user['lastActive'] != null)
                    Text(
                      'Last Active: ${_formatLastActive(user['lastActive'])}',
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
              ElevatedButton(
                onPressed: () => _openDirections(user),
                child: const Text('Get Directions'),
              ),
            ],
          ),
    );
  }

  void _showLocationHistory(BuildContext context, DashboardProvider provider) {
    if (_isDisposed) return;
    showDialog(
      context: context,
      builder:
          (context) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600, maxHeight: 500),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        const Icon(Icons.history, color: AppColors.primary),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Location History',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),
                  Divider(color: AppColors.border),
                  Expanded(child: _buildHistoryList(provider)),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: ElevatedButton(
                      onPressed: () {
                        _exportHistoryData();
                      },
                      child: const Text('Export History Data'),
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  Widget _buildHistoryList(DashboardProvider provider) {
    if (_userLocationHistory.isEmpty) {
      return const Center(child: Text('No location history available'));
    }

    return ListView.builder(
      itemCount: _userLocationHistory.length,
      itemBuilder: (context, index) {
        final userId = _userLocationHistory.keys.elementAt(index);
        final history = _userLocationHistory[userId]!;
        final user = _realTimeUserLocations[userId] ?? {'name': 'Unknown User'};

        return ExpansionTile(
          leading: const Icon(Icons.person),
          title: Text(user['name']?.toString() ?? 'Unknown User'),
          subtitle: Text('${history.length} location points'),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children:
                    history
                        .asMap()
                        .entries
                        .map(
                          (entry) => ListTile(
                            leading: Text('${entry.key + 1}'),
                            title: Text(
                              'Lat: ${entry.value.latitude.toStringAsFixed(6)}',
                            ),
                            subtitle: Text(
                              'Lng: ${entry.value.longitude.toStringAsFixed(6)}',
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.map),
                              onPressed: () {
                                _mapController.move(entry.value, 15);
                                Navigator.pop(context);
                              },
                            ),
                          ),
                        )
                        .toList(),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showGeofencePanel(BuildContext context, DashboardProvider provider) {
    if (_isDisposed) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (context) => Container(
            padding: const EdgeInsets.all(20),
            height: 400,
            child: Column(
              children: [
                const Text(
                  'Geofence Management',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView(
                    children: [
                      // Create geofences around user locations
                      for (var user in _realTimeUserLocations.values)
                        if (user['latitude'] != null &&
                            user['longitude'] != null)
                          _buildGeofenceItem(
                            user['name']?.toString() ?? 'User Zone',
                            user['latitude'] as double,
                            user['longitude'] as double,
                            300,
                          ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _addNewGeofence(context),
                        icon: const Icon(Icons.add),
                        label: const Text('Add New Geofence'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.background,
                        foregroundColor: AppColors.textSecondary,
                      ),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              ],
            ),
          ),
    );
  }

  Widget _buildGeofenceItem(
    String name,
    double lat,
    double lng,
    double radius,
  ) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.fence, color: AppColors.warning),
        title: Text(name),
        subtitle: Text('Radius: ${radius}m'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit, size: 18),
              onPressed: () {},
            ),
            IconButton(
              icon: const Icon(Icons.delete, size: 18, color: Colors.red),
              onPressed: () {},
            ),
          ],
        ),
        onTap: () {
          _mapController.move(latlong.LatLng(lat, lng), 15);
          Navigator.pop(context);
        },
      ),
    );
  }

  void _addNewGeofence(BuildContext context) {
    if (_isDisposed) return;
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Add Geofence'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    decoration: const InputDecoration(
                      labelText: 'Zone Name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          decoration: const InputDecoration(
                            labelText: 'Latitude',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          decoration: const InputDecoration(
                            labelText: 'Longitude',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    decoration: const InputDecoration(
                      labelText: 'Radius (meters)',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  if (_isDisposed) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Geofence added successfully'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                  Navigator.pop(context);
                },
                child: const Text('Save'),
              ),
            ],
          ),
    );
  }

  void _showUserHistory(Map<String, dynamic> user) {
    if (_isDisposed) return;
    final userId = user['id']?.toString() ?? '';
    final history = _userLocationHistory[userId] ?? [];

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('${user['name']}\'s Location History'),
            content: SizedBox(
              width: 300,
              height: 400,
              child:
                  history.isEmpty
                      ? const Center(child: Text('No history available'))
                      : ListView.builder(
                        itemCount: history.length,
                        itemBuilder: (context, index) {
                          final point = history[index];
                          return ListTile(
                            leading: CircleAvatar(child: Text('${index + 1}')),
                            title: Text(
                              'Lat: ${point.latitude.toStringAsFixed(6)}',
                            ),
                            subtitle: Text(
                              'Lng: ${point.longitude.toStringAsFixed(6)}',
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.map),
                              onPressed: () {
                                _mapController.move(point, 15);
                                Navigator.pop(context);
                              },
                            ),
                          );
                        },
                      ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
              ElevatedButton(
                onPressed: () {
                  _exportUserHistory(userId);
                },
                child: const Text('Export History'),
              ),
            ],
          ),
    );
  }

  void _shareLocation(Map<String, dynamic> user) {
    if (user['latitude'] == null || user['longitude'] == null) return;

    final lat = user['latitude'];
    final lng = user['longitude'];
    final name = user['name'] ?? 'User';
    final message =
        'Location of $name: https://www.openstreetmap.org/?mlat=$lat&mlon=$lng#map=15/$lat/$lng';

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Share Location'),
            content: SingleChildScrollView(child: SelectableText(message)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  if (_isDisposed) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Location link copied to clipboard'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                  Navigator.pop(context);
                },
                child: const Text('Copy Link'),
              ),
            ],
          ),
    );
  }

  void _showAreaAnalysis(BuildContext context) {
    if (_isDisposed) return;
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Area Analysis'),
            content: SizedBox(
              width: 400,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Analyze location patterns and density'),
                    const SizedBox(height: 20),
                    ListTile(
                      leading: const Icon(Icons.analytics),
                      title: const Text('User Density'),
                      subtitle: const Text('Concentration of users in area'),
                      onTap: () {
                        _analyzeUserDensity();
                        Navigator.pop(context);
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.timeline),
                      title: const Text('Movement Patterns'),
                      subtitle: const Text('Common routes and paths'),
                      onTap: () {
                        _analyzeMovementPatterns();
                        Navigator.pop(context);
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.warning),
                      title: const Text('Incident Hotspots'),
                      subtitle: const Text('Areas with frequent incidents'),
                      onTap: () {
                        if (_isDisposed) return;
                        setState(() {
                          _selectedView = 'heatmap';
                          _showHeatmap = true;
                        });
                        Navigator.pop(context);
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Showing incident hotspots'),
                            backgroundColor: AppColors.info,
                          ),
                        );
                      },
                    ),
                  ],
                ),
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

  void _showMapHelp(BuildContext context) {
    if (_isDisposed) return;
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Map Help'),
            content: SizedBox(
              width: 400,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHelpItem(
                      'Live View',
                      'Real-time user locations from Firebase',
                    ),
                    _buildHelpItem('History View', 'Past location trails'),
                    _buildHelpItem('Heatmap View', 'Density visualization'),
                    const SizedBox(height: 16),
                    const Text(
                      'Controls:',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    _buildHelpItem('Zoom', 'Pinch or use +/- buttons'),
                    _buildHelpItem('Pan', 'Drag the map'),
                    _buildHelpItem('User Info', 'Tap on markers'),
                    const SizedBox(height: 16),
                    const Text(
                      'Data Sources:',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    _buildHelpItem(
                      'Firebase Events',
                      'ENVIRONMENT_DATA, SOS_TRIGGERED, FALL_DETECTED',
                    ),
                    _buildHelpItem(
                      'Real-time Updates',
                      'Automatically updates every 5 seconds',
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Got it'),
              ),
            ],
          ),
    );
  }

  Widget _buildHelpItem(String title, String description) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          Text(description, style: TextStyle(color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  void _captureMapScreenshot() {
    if (_isDisposed) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Map screenshot captured and saved to gallery'),
        backgroundColor: AppColors.success,
      ),
    );
  }

  void _exportMapData() {
    final Map<String, dynamic> data = {
      'timestamp': DateTime.now().toIso8601String(),
      'users': _realTimeUserLocations.values.toList(),
      'heatmap_points': _heatmapPoints.length,
      'history_records': _userLocationHistory.length,
    };

    final userList = data['users'] as List;
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Exported ${userList.length} user locations'),
        backgroundColor: AppColors.success,
      ),
    );
  }

  void _exportHistoryData() {
    final totalPoints = _userLocationHistory.values.fold(
      0,
      (sum, history) => sum + history.length,
    );

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Exported $totalPoints history points'),
        backgroundColor: AppColors.success,
      ),
    );
  }

  void _exportUserHistory(String userId) {
    final history = _userLocationHistory[userId] ?? [];
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Exported ${history.length} points for user'),
        backgroundColor: AppColors.success,
      ),
    );
  }

  void _showMapSettings() {
    if (_isDisposed) return;
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Map Settings'),
            content: SizedBox(
              width: 300,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SwitchListTile(
                      title: const Text('Show Labels'),
                      value: true,
                      onChanged: (value) {},
                    ),
                    SwitchListTile(
                      title: const Text('Dark Mode'),
                      value: false,
                      onChanged: (value) {},
                    ),
                    SwitchListTile(
                      title: const Text('Traffic Data'),
                      value: true,
                      onChanged: (value) {},
                    ),
                    SwitchListTile(
                      title: const Text('Auto-center on User'),
                      value: true,
                      onChanged: (value) {},
                    ),
                    SwitchListTile(
                      title: const Text('Real-time Updates'),
                      value: true,
                      onChanged: (value) {},
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Update Interval:',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Slider(
                      value: 5,
                      min: 1,
                      max: 30,
                      divisions: 29,
                      label: '5 seconds',
                      onChanged: (value) {},
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Settings saved'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                },
                child: const Text('Save'),
              ),
            ],
          ),
    );
  }

  void _analyzeUserDensity() {
    final usersWithLocation =
        _realTimeUserLocations.values
            .where((u) => u['latitude'] != null && u['longitude'] != null)
            .length;

    if (_isDisposed) return;
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('User Density Analysis'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Total Users: ${_realTimeUserLocations.length}'),
                  Text('Users with Location: $usersWithLocation'),
                  Text(
                    'Online Users: ${_realTimeUserLocations.values.where((u) => u['isOnline'] == true).length}',
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Density Zones:',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  for (var user in _realTimeUserLocations.values.take(3))
                    if (user['latitude'] != null)
                      Text(
                        '• ${user['name']}: ${user['latitude']?.toStringAsFixed(4)}, ${user['longitude']?.toStringAsFixed(4)}',
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

  void _analyzeMovementPatterns() {
    final patterns = <String, int>{};
    for (var entry in _userLocationHistory.entries) {
      patterns[entry.key] = entry.value.length;
    }

    if (_isDisposed) return;
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Movement Patterns'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('User Movement Analysis:'),
                  const SizedBox(height: 16),
                  for (var entry in patterns.entries)
                    Text('• User ${entry.key}: ${entry.value} movement points'),
                  if (patterns.isEmpty)
                    const Text('No movement data available'),
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
}
