import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../models/station.dart';
import '../services/api_service.dart';
import '../services/station_service.dart';
import '../services/place_service.dart' show Place, PlaceService;

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with TickerProviderStateMixin {
  LatLng? _currentLocation;
  LatLng? _startLocation;
  LatLng? _endLocation;
  int _currentChargePercent = 100;
  List<Station> _suggestedStations = [];
  bool _loading = true;
  String? _error;
  bool _showBottomSheet = false;
  late MapController _mapController;

  // Polyline points for route
  List<LatLng> _routePoints = [];

  // Animation controllers
  late AnimationController _fabAnimationController;
  late Animation<double> _fabAnimation;

  final StationService _stationService = StationService(
    apiService: ApiService(),
  );

  final PlaceService _placeService = PlaceService();

  final TextEditingController _startController = TextEditingController();
  final TextEditingController _endController = TextEditingController();
  final TextEditingController _chargeController = TextEditingController(
    text: '100',
  );

  List<Place> _startPlaceSuggestions = [];
  List<Place> _endPlaceSuggestions = [];

  // Track focus state for search fields
  final FocusNode _startFocusNode = FocusNode();
  final FocusNode _endFocusNode = FocusNode();
  bool _isStartFocused = false;
  bool _isEndFocused = false;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _determinePosition();

    // Initialize animation controllers
    _fabAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fabAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _fabAnimationController, curve: Curves.easeInOut),
    );
    _fabAnimationController.forward();

    // Setup focus listeners
    _startFocusNode.addListener(() {
      setState(() {
        _isStartFocused = _startFocusNode.hasFocus;
        if (!_isStartFocused && _startPlaceSuggestions.isNotEmpty) {
          // Add a delay to allow tapping on suggestion
          Future.delayed(const Duration(milliseconds: 200), () {
            if (!_startFocusNode.hasFocus) {
              setState(() {
                _startPlaceSuggestions = [];
              });
            }
          });
        }
      });
    });

    _endFocusNode.addListener(() {
      setState(() {
        _isEndFocused = _endFocusNode.hasFocus;
        if (!_isEndFocused && _endPlaceSuggestions.isNotEmpty) {
          // Add a delay to allow tapping on suggestion
          Future.delayed(const Duration(milliseconds: 200), () {
            if (!_endFocusNode.hasFocus) {
              setState(() {
                _endPlaceSuggestions = [];
              });
            }
          });
        }
      });
    });
  }

  @override
  void dispose() {
    _fabAnimationController.dispose();
    _mapController.dispose();
    _startController.dispose();
    _endController.dispose();
    _chargeController.dispose();
    _startFocusNode.dispose();
    _endFocusNode.dispose();
    super.dispose();
  }

  Future<void> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    setState(() {
      _loading = true;
      _error = null;
    });

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() {
        _error = 'Location services are disabled.';
        _loading = false;
      });
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        setState(() {
          _error = 'Location permissions are denied';
          _loading = false;
        });
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      setState(() {
        _error =
            'Location permissions are permanently denied, we cannot request permissions.';
        _loading = false;
      });
      return;
    }

    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      _currentLocation = LatLng(position.latitude, position.longitude);
      _startLocation = _currentLocation;
      _startController.text = 'Current Location';
      setState(() {
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to get current location: $e';
        _loading = false;
      });
    }
  }

  Future<void> _fetchSuggestedStations() async {
    if (_startLocation == null || _endLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please provide both start and end locations'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      setState(() {
        _loading = false;
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // Call route optimization API
      final routeData = await _stationService.apiService.optimizeRoute(
        startLatitude: _startLocation!.latitude,
        startLongitude: _startLocation!.longitude,
        endLatitude: _endLocation!.latitude,
        endLongitude: _endLocation!.longitude,
      );

      // Extract polyline points from route segments
      List<LatLng> polylinePoints = [];
      if (routeData != null && routeData['route_segments'] != null) {
        for (var segment in routeData['route_segments']) {
          if (segment['route_geometry'] != null &&
              segment['route_geometry']['coordinates'] != null) {
            for (var coord in segment['route_geometry']['coordinates']) {
              // OSRM returns [longitude, latitude]
              polylinePoints.add(LatLng(coord[1], coord[0]));
            }
          }
        }
      }

      // Filter stations based on currentChargePercent (example logic)
      List<dynamic> filteredStations = [];
      if (routeData != null && routeData['charging_stations'] != null) {
        for (var stationJson in routeData['charging_stations']) {
          // Example: filter stations with some condition related to currentChargePercent
          // Here, just include all stations as placeholder
          filteredStations.add(stationJson);
        }
      }

      setState(() {
        _routePoints = polylinePoints;
        _suggestedStations =
            filteredStations.map((json) => Station.fromJson(json)).toList();
        _loading = false;
        _showBottomSheet = false;
      });

      // Fit the map to show all points including route
      _fitMapToBounds();
    } catch (e) {
      setState(() {
        _error = 'Failed to fetch route: $e';
        _loading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${_error}'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _fitMapToBounds() {
    if (_startLocation != null && _endLocation != null) {
      List<LatLng> points = [_startLocation!, _endLocation!];
      if (_suggestedStations.isNotEmpty) {
        points.addAll(
          _suggestedStations.map((s) => LatLng(s.latitude, s.longitude)),
        );
      }

      // Calculate bounds
      double minLat = points
          .map((p) => p.latitude)
          .reduce((a, b) => a < b ? a : b);
      double maxLat = points
          .map((p) => p.latitude)
          .reduce((a, b) => a > b ? a : b);
      double minLng = points
          .map((p) => p.longitude)
          .reduce((a, b) => a < b ? a : b);
      double maxLng = points
          .map((p) => p.longitude)
          .reduce((a, b) => a > b ? a : b);

      // Add padding
      double latPadding = (maxLat - minLat) * 0.2;
      double lngPadding = (maxLng - minLng) * 0.2;

      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: LatLngBounds(
            LatLng(minLat - latPadding, minLng - lngPadding),
            LatLng(maxLat + latPadding, maxLng + lngPadding),
          ),
          padding: const EdgeInsets.all(50),
        ),
      );
    }
  }

  void _onStartChanged(String value) {
    _searchPlaces(value, isStart: true);
  }

  void _onEndChanged(String value) {
    _searchPlaces(value, isStart: false);
  }

  void _onChargeChanged(String value) {
    final charge = int.tryParse(value);
    if (charge != null && charge >= 0 && charge <= 100) {
      setState(() {
        _currentChargePercent = charge;
      });
    }
  }

  void _searchPlaces(String query, {required bool isStart}) async {
    if (query.isEmpty) {
      setState(() {
        if (isStart) {
          _startPlaceSuggestions = [];
        } else {
          _endPlaceSuggestions = [];
        }
      });
      return;
    }

    try {
      if (query == "Current Location") return;

      final places = await _placeService.searchPlaces(query);
      if (mounted) {
        setState(() {
          if (isStart) {
            _startPlaceSuggestions = places;
          } else {
            _endPlaceSuggestions = places;
          }
        });
      }
    } catch (e) {
      // Log error but don't show to user
      debugPrint("Error searching places: $e");
    }
  }

  void _selectPlace(Place place, {required bool isStart}) {
    setState(() {
      if (isStart) {
        _startLocation = LatLng(place.latitude, place.longitude);
        _startController.text = place.displayName;
        _startPlaceSuggestions = [];
        _startFocusNode.unfocus();
      } else {
        _endLocation = LatLng(place.latitude, place.longitude);
        _endController.text = place.displayName;
        _endPlaceSuggestions = [];
        _endFocusNode.unfocus();
      }
    });

    // Center map on selected location
    _mapController.move(isStart ? _startLocation! : _endLocation!, 13.0);
  }

  void _toggleBottomSheet() {
    setState(() {
      _showBottomSheet = !_showBottomSheet;
      // Clear suggestions when toggling
      _startPlaceSuggestions = [];
      _endPlaceSuggestions = [];

      // Unfocus text fields when closing bottom sheet
      if (!_showBottomSheet) {
        _startFocusNode.unfocus();
        _endFocusNode.unfocus();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Get the safe area top padding to account for notches/status bars
    final topPadding = MediaQuery.of(context).padding.top;

    return Scaffold(
      body: Stack(
        children: [
          // Main Map View
          _buildMapView(),

          // Status Bar Safe Area
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: topPadding,
            child: Container(color: Colors.white.withOpacity(0.8)),
          ),

          // Loading Indicator
          if (_loading)
            Container(
              color: Colors.black26,
              child: const Center(
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text("Finding optimal charging stations..."),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // Bottom Sheet for Search
          if (_showBottomSheet) _buildSearchPanel(),
        ],
      ),
      floatingActionButton: _buildFloatingActionButtons(),
    );
  }

  Widget _buildMapView() {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _determinePosition,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_currentLocation == null) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Determining your location...'),
          ],
        ),
      );
    }

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(initialCenter: _currentLocation!, initialZoom: 13.0),
      children: [
        TileLayer(
          urlTemplate: "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
          subdomains: const ['a', 'b', 'c'],
        ),
        PolylineLayer(
          polylines: [
            if (_routePoints.isNotEmpty)
              Polyline(
                points: _routePoints,
                strokeWidth: 4.0,
                color: Colors.blueAccent,
              ),
          ],
        ),
        MarkerLayer(
          markers: [
            if (_startLocation != null)
              Marker(
                point: _startLocation!,
                width: 60,
                height: 60,
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade700,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.my_location,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade700,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        'Start',
                        style: TextStyle(color: Colors.white, fontSize: 10),
                      ),
                    ),
                  ],
                ),
              ),
            if (_endLocation != null)
              Marker(
                point: _endLocation!,
                width: 60,
                height: 60,
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.red.shade700,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.flag,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red.shade700,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        'End',
                        style: TextStyle(color: Colors.white, fontSize: 10),
                      ),
                    ),
                  ],
                ),
              ),
            ..._suggestedStations.map(
              (station) => Marker(
                point: LatLng(station.latitude, station.longitude),
                width: 60,
                height: 60,
                child: GestureDetector(
                  onTap: () => _showStationDetails(station),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.green.shade700,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 5,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.ev_station,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSearchPanel() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Main content
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'Trip Details',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: _toggleBottomSheet,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Start Location
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Starting Point',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8),
                            border:
                                _isStartFocused
                                    ? Border.all(
                                      color: Theme.of(context).primaryColor,
                                      width: 2,
                                    )
                                    : null,
                          ),
                          child: TextField(
                            controller: _startController,
                            focusNode: _startFocusNode,
                            decoration: InputDecoration(
                              border: InputBorder.none,
                              prefixIcon: Icon(
                                Icons.location_on,
                                color: Colors.blue.shade700,
                              ),
                              suffixIcon:
                                  _startController.text.isNotEmpty
                                      ? IconButton(
                                        icon: const Icon(Icons.clear),
                                        onPressed: () {
                                          setState(() {
                                            _startController.clear();
                                            _startPlaceSuggestions = [];
                                            _startLocation = null;
                                          });
                                        },
                                      )
                                      : null,
                              hintText: 'Enter start location',
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 12,
                                horizontal: 8,
                              ),
                            ),
                            onChanged: _onStartChanged,
                          ),
                        ),
                      ],
                    ),
                    // Start location suggestions - outside the above column
                    if (_startPlaceSuggestions.isNotEmpty)
                      Container(
                        constraints: const BoxConstraints(maxHeight: 150),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.3),
                              spreadRadius: 1,
                              blurRadius: 5,
                            ),
                          ],
                        ),
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: _startPlaceSuggestions.length,
                          itemBuilder: (context, index) {
                            final place = _startPlaceSuggestions[index];
                            return Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () {
                                  _selectPlace(place, isStart: true);
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8.0,
                                    horizontal: 16.0,
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.place,
                                        color: Colors.blue,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          place.displayName,
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 1,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    const SizedBox(height: 16),
                    // End Location
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Ending Point',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8),
                            border:
                                _isEndFocused
                                    ? Border.all(
                                      color: Theme.of(context).primaryColor,
                                      width: 2,
                                    )
                                    : null,
                          ),
                          child: TextField(
                            controller: _endController,
                            focusNode: _endFocusNode,
                            decoration: InputDecoration(
                              border: InputBorder.none,
                              prefixIcon: Icon(
                                Icons.flag,
                                color: Colors.red.shade700,
                              ),
                              suffixIcon:
                                  _endController.text.isNotEmpty
                                      ? IconButton(
                                        icon: const Icon(Icons.clear),
                                        onPressed: () {
                                          setState(() {
                                            _endController.clear();
                                            _endPlaceSuggestions = [];
                                            _endLocation = null;
                                          });
                                        },
                                      )
                                      : null,
                              hintText: 'Enter destination',
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 12,
                                horizontal: 8,
                              ),
                            ),
                            onChanged: _onEndChanged,
                          ),
                        ),
                      ],
                    ),
                    // End location suggestions - outside the above column
                    if (_endPlaceSuggestions.isNotEmpty)
                      Container(
                        constraints: const BoxConstraints(maxHeight: 150),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.3),
                              spreadRadius: 1,
                              blurRadius: 5,
                            ),
                          ],
                        ),
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: _endPlaceSuggestions.length,
                          itemBuilder: (context, index) {
                            final place = _endPlaceSuggestions[index];
                            return Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () {
                                  _selectPlace(place, isStart: false);
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8.0,
                                    horizontal: 16.0,
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.place,
                                        color: Colors.red,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          place.displayName,
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 1,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    const SizedBox(height: 16),
                    // Battery Level
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text(
                              'Current Battery Level',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '$_currentChargePercent%',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: _getBatteryColor(),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            activeTrackColor: _getBatteryColor(),
                            thumbColor: _getBatteryColor(),
                            inactiveTrackColor: Colors.grey.shade300,
                          ),
                          child: Slider(
                            min: 0,
                            max: 100,
                            divisions: 20,
                            value: _currentChargePercent.toDouble(),
                            onChanged: (value) {
                              setState(() {
                                _currentChargePercent = value.round();
                                _chargeController.text =
                                    _currentChargePercent.toString();
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: _fetchSuggestedStations,
                      child: const Text(
                        'Find Charging Stations',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Add extra padding at bottom for keyboard
              SizedBox(height: MediaQuery.of(context).viewInsets.bottom),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingActionButtons() {
    return FadeTransition(
      opacity: _fabAnimation,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: 'my_location',
            backgroundColor: Colors.white,
            foregroundColor: Theme.of(context).primaryColor,
            mini: true,
            onPressed: () {
              if (_currentLocation != null) {
                _mapController.move(_currentLocation!, 15);
              }
            },
            child: const Icon(Icons.my_location),
          ),
          const SizedBox(height: 16),
          FloatingActionButton.extended(
            heroTag: 'search_fab',
            backgroundColor: Theme.of(context).primaryColor,
            foregroundColor: Colors.white,
            onPressed: _toggleBottomSheet,
            icon: Icon(_showBottomSheet ? Icons.close : Icons.search),
            label: Text(_showBottomSheet ? 'Close' : 'Search Route'),
          ),
        ],
      ),
    );
  }

  void _showStationDetails(Station station) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green.shade100,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.ev_station,
                      color: Colors.green.shade700,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Charging Station',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        Text(
                          '${station.latitude.toStringAsFixed(4)}, ${station.longitude.toStringAsFixed(4)}',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: 32),
              // Here you would typically show more details about the station
              // like charging speed, available connectors, etc.
              // For now, let's add some placeholder info
              _buildInfoRow(Icons.bolt, 'Fast Charging', 'Available'),
              _buildInfoRow(
                Icons.access_time,
                'Estimated Charging Time',
                '30-45 minutes',
              ),
              _buildInfoRow(
                Icons.electric_car,
                'Compatible with your EV',
                'Yes',
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () {
                  Navigator.pop(context);
                  // Here you would typically navigate to a detailed view or
                  // add the station to the route
                },
                child: const Text('Add to Route'),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInfoRow(IconData icon, String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey.shade700),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.grey,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }

  Color _getBatteryColor() {
    if (_currentChargePercent > 70) {
      return Colors.green;
    } else if (_currentChargePercent > 30) {
      return Colors.orange;
    } else {
      return Colors.red;
    }
  }
}
