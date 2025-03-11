import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class Navigation extends StatefulWidget {
  const Navigation({Key? key}) : super(key: key);

  @override
  State<Navigation> createState() => _NavigationState();
}

class _NavigationState extends State<Navigation> with SingleTickerProviderStateMixin {
  final Completer<GoogleMapController> _controller = Completer();
  late AnimationController _animationController;

  Position? _currentPosition;
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  final List<PlaceDetails> _nearbyPlaces = [];

  String _selectedMode = 'standard';
  String _selectedPurpose = 'police';
  bool _isLoading = false;
  bool _isExpanded = true;

  final String _apiKey = 'AIzaSyCy2prNMuxDYGaMukEJazjbf2IUdEyxwq8';

  final Map<String, String> _purposeToPlaceType = {
    'police': 'police',
    'hospital': 'hospital',
    'pharmacy': 'pharmacy',
    'mall': 'local_mall',
    'transit': 'transit_station'
  };

  final Map<String, Map<String, dynamic>> _modeInfo = {
    'standard': {
      'color': Colors.blue,
      'icon': Icons.navigation,
      'label': 'Standard Navigation'
    },
    'emergency': {
      'color': Colors.red,
      'icon': Icons.emergency,
      'label': 'Emergency Mode'
    },
    'stealth': {
      'color': Colors.grey,
      'icon': Icons.visibility_off,
      'label': 'Stealth Mode'
    },
  };

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _initializeLocation();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _initializeLocation() async {
    try {
      final position = await _getCurrentPosition();
      if (!mounted) return;
      await _updateStateAndFetch({'_currentPosition': position, '_isLoading': false});
    } catch (e) {
      if (!mounted) return;
      _showError('Location initialization failed');
    }
  }

  Future<Position> _getCurrentPosition() async {
    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      final newPermission = await Geolocator.requestPermission();
      if (newPermission == LocationPermission.denied) {
        throw 'Location permission required';
      }
    }
    return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high
    );
  }

  Future<void> _updateStateAndFetch(Map<String, dynamic> updates) async {
    setState(() {
      updates.forEach((key, value) {
        switch (key) {
          case '_currentPosition':
            _currentPosition = value;
            break;
          case '_isLoading':
            _isLoading = value;
            break;
        }
      });
    });

    if (_currentPosition != null) {
      await _fetchNearbyPlaces();
    }
  }

  Future<void> _fetchNearbyPlaces() async {
    if (_currentPosition == null) return;

    setState(() => _isLoading = true);
    _markers.clear();
    _addCurrentLocationMarker();

    try {
      final placeType = _purposeToPlaceType[_selectedPurpose] ?? 'police';
      final places = await _fetchPlacesFromApi(placeType);

      if (!mounted) return;

      _nearbyPlaces.clear();
      _markers.clear();
      _addCurrentLocationMarker();

      for (final place in places) {
        _nearbyPlaces.add(place);
        _addPlaceMarker(place);
      }

      if (_nearbyPlaces.isNotEmpty) {
        await _showRouteToNearestPlace();
      }
    } catch (e) {
      _showError('Failed to fetch nearby places');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<List<PlaceDetails>> _fetchPlacesFromApi(String placeType) async {
    final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/nearbysearch/json'
            '?location=${_currentPosition!.latitude},${_currentPosition!.longitude}'
            '&radius=5000'
            '&type=$placeType'
            '&key=$_apiKey'
    );

    final response = await http.get(url);
    if (response.statusCode != 200) throw 'API request failed';

    final data = json.decode(response.body);
    if (data['status'] != 'OK') throw data['status'];

    return (data['results'] as List).map((place) {
      final location = place['geometry']['location'];
      return PlaceDetails(
        id: place['place_id'],
        name: place['name'],
        latitude: location['lat'],
        longitude: location['lng'],
        vicinity: place['vicinity'] ?? '',
        rating: place['rating']?.toString() ?? 'N/A',
      );
    }).toList();
  }

  void _addCurrentLocationMarker() {
    if (_currentPosition == null) return;

    _markers.add(Marker(
      markerId: const MarkerId('current'),
      position: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
      icon: BitmapDescriptor.defaultMarkerWithHue(_getModeHue()),
    ));
  }

  double _getModeHue() {
    switch (_selectedMode) {
      case 'emergency': return BitmapDescriptor.hueRed;
      case 'stealth': return BitmapDescriptor.hueViolet;
      default: return BitmapDescriptor.hueAzure;
    }
  }

  void _addPlaceMarker(PlaceDetails place) {
    _markers.add(Marker(
      markerId: MarkerId(place.id),
      position: LatLng(place.latitude, place.longitude),
      infoWindow: InfoWindow(
        title: place.name,
        snippet: '${place.vicinity}\nRating: ${place.rating}',
      ),
    ));
  }

  Future<void> _showRouteToNearestPlace() async {
    if (_nearbyPlaces.isEmpty || _currentPosition == null) return;

    final nearestPlace = _findNearestPlace();

    try {
      final String url = 'https://maps.googleapis.com/maps/api/directions/json'
          '?origin=${_currentPosition!.latitude},${_currentPosition!.longitude}'
          '&destination=${nearestPlace.latitude},${nearestPlace.longitude}'
          '&mode=driving'
          '&key=$_apiKey';

      final response = await http.get(Uri.parse(url));

      if (response.statusCode != 200) {
        throw 'Failed to fetch directions';
      }

      final data = json.decode(response.body);

      if (data['status'] != 'OK') {
        throw data['status'];
      }

      // Extract route information
      final route = data['routes'][0];
      final leg = route['legs'][0];
      final steps = leg['steps'] as List;

      // Decode polyline points
      final String encodedPoints = route['overview_polyline']['points'];
      final List<LatLng> polylineCoordinates = [];

      // Decode Google's polyline encoding
      int index = 0;
      int lat = 0;
      int lng = 0;

      while (index < encodedPoints.length) {
        int shift = 0;
        int result = 0;

        // Decode latitude
        do {
          result |= (encodedPoints.codeUnitAt(index) - 63 & 0x1F) << shift;
          shift += 5;
        } while (encodedPoints.codeUnitAt(index++) >= 0x20);

        final dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
        lat += dlat;

        shift = 0;
        result = 0;

        // Decode longitude
        do {
          result |= (encodedPoints.codeUnitAt(index) - 63 & 0x1F) << shift;
          shift += 5;
        } while (encodedPoints.codeUnitAt(index++) >= 0x20);

        final dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
        lng += dlng;

        final position = LatLng(
          lat / 1E5,
          lng / 1E5,
        );

        polylineCoordinates.add(position);
      }

      if (!mounted) return;

      setState(() {
        _polylines.clear();
        _polylines.add(Polyline(
          polylineId: const PolylineId('route'),
          color: _modeInfo[_selectedMode]!['color'],
          points: polylineCoordinates,
          width: _selectedMode == 'emergency' ? 6 : 4,
          patterns: _selectedMode == 'stealth'
              ? [PatternItem.dash(20), PatternItem.gap(10)]
              : [],
        ));
      });

      await _animateToRoute(polylineCoordinates);

    } catch (e) {
      _showError('Failed to fetch route');
    }
  }

  PlaceDetails _findNearestPlace() {
    return _nearbyPlaces.reduce((curr, next) {
      final currDist = Geolocator.distanceBetween(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
        curr.latitude,
        curr.longitude,
      );

      final nextDist = Geolocator.distanceBetween(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
        next.latitude,
        next.longitude,
      );

      return currDist < nextDist ? curr : next;
    });
  }

  Future<void> _animateToRoute(List<LatLng> points) async {
    final bounds = LatLngBounds(
      southwest: LatLng(
        points.map((e) => e.latitude).reduce(min),
        points.map((e) => e.longitude).reduce(min),
      ),
      northeast: LatLng(
        points.map((e) => e.latitude).reduce(max),
        points.map((e) => e.longitude).reduce(max),
      ),
    );

    final controller = await _controller.future;
    await controller.animateCamera(CameraUpdate.newLatLngBounds(bounds, 100));
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          backgroundColor: Colors.red.shade800,
        )
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          _buildMap(),
          _buildTopBar(),
          if (_selectedMode == 'emergency') _buildEmergencyIndicator(),
          _buildDistanceIndicator(),
        ],
      ),
      floatingActionButton: _buildActionButtons(),
    );
  }

  Widget _buildMap() {
    if (_currentPosition == null || _isLoading) {
      return Container(
        color: Colors.white,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                _isLoading ? 'Fetching nearby places...' : 'Getting your location...',
                style: const TextStyle(fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }

    return GoogleMap(
      mapType: _selectedMode == 'stealth' ? MapType.hybrid : MapType.normal,
      initialCameraPosition: CameraPosition(
        target: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
        zoom: 14,
      ),
      onMapCreated: _controller.complete,
      markers: _markers,
      polylines: _polylines,
      myLocationEnabled: true,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      compassEnabled: true,
    );
  }

  Widget _buildTopBar() {
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      top: _isExpanded ? MediaQuery.of(context).padding.top + 10 : -140,
      left: 10,
      right: 10,
      child: GestureDetector(
        onVerticalDragEnd: (details) {
          if (details.primaryVelocity! > 0) {
            setState(() => _isExpanded = true);
          } else if (details.primaryVelocity! < 0) {
            setState(() => _isExpanded = false);
          }
        },
        child: Card(
          elevation: 8,
          shadowColor: Colors.black26,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 4,
                width: 40,
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(15),
                child: Column(
                  children: [
                    _buildModeDropdown(),
                    const SizedBox(height: 15),
                    _buildPurposeDropdown(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModeDropdown() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: Colors.grey.shade100,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          Icon(_modeInfo[_selectedMode]!['icon'],
              color: _modeInfo[_selectedMode]!['color']),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedMode,
                isExpanded: true,
                items: _modeInfo.entries.map((entry) {
                  return DropdownMenuItem(
                    value: entry.key,
                    child: Text(
                      entry.value['label'],
                      style: TextStyle(color: entry.value['color']),
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() => _selectedMode = value!);
                  _showRouteToNearestPlace();
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPurposeDropdown() {
    final purposeIcons = {
      'police': Icons.local_police,
      'hospital': Icons.local_hospital,
      'pharmacy': Icons.local_pharmacy,
      'mall': Icons.local_mall,
      'transit': Icons.directions_transit,
    };

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: Colors.grey.shade100,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          Icon(purposeIcons[_selectedPurpose], color: Theme.of(context).primaryColor),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedPurpose,
                isExpanded: true,
                items: const [
                  DropdownMenuItem(value: 'police', child: Text('Police Stations')),
                  DropdownMenuItem(value: 'hospital', child: Text('Hospitals')),
                  DropdownMenuItem(value: 'pharmacy', child: Text('Pharmacies')),
                  DropdownMenuItem(value: 'mall', child: Text('Shopping Malls')),
                  DropdownMenuItem(value: 'transit', child: Text('Transit Stations')),
                ],
                onChanged: (value) {
                  setState(() => _selectedPurpose = value!);
                  _fetchNearbyPlaces();
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmergencyIndicator() {
    return AnimatedBuilder(
      animation: _animationController..repeat(reverse: true),
      builder: (context, child) {
        return Positioned(
          bottom: 100,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.8 + 0.2 * _animationController.value),
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: Colors.red.withOpacity(0.3),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.emergency, color: Colors.white),
                  SizedBox(width: 8),
                  Text(
                    'EMERGENCY MODE ACTIVE',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDistanceIndicator() {
    if (_nearbyPlaces.isEmpty || _currentPosition == null) return const SizedBox.shrink();

    final nearestPlace = _findNearestPlace();
    final distance = Geolocator.distanceBetween(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
      nearestPlace.latitude,
      nearestPlace.longitude,
    );

    return Positioned(
      bottom: _selectedMode == 'emergency' ? 160 : 100,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                nearestPlace.name,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${(distance / 1000).toStringAsFixed(1)} km away',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: 'toggleTopBar',
            onPressed: () => setState(() => _isExpanded = !_isExpanded),
            backgroundColor: Colors.white,
            child: Icon(
              _isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
              color: Theme.of(context).primaryColor,
            ),
          ),
          const SizedBox(height: 16),
          FloatingActionButton(
            heroTag: 'refresh',
            onPressed: _fetchNearbyPlaces,
            backgroundColor: _modeInfo[_selectedMode]!['color'],
            child: const Icon(Icons.refresh),
          ),
          const SizedBox(height: 16),
          FloatingActionButton(
            heroTag: 'location',
            onPressed: () async {
              if (_currentPosition == null) return;
              final controller = await _controller.future;
              controller.animateCamera(
                CameraUpdate.newCameraPosition(
                  CameraPosition(
                    target: LatLng(
                      _currentPosition!.latitude,
                      _currentPosition!.longitude,
                    ),
                    zoom: 15,
                  ),
                ),
              );
            },
            backgroundColor: _modeInfo[_selectedMode]!['color'],
            child: const Icon(Icons.my_location),
          ),
        ],
      ),
    );
  }
}

class PlaceDetails {
  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final String vicinity;
  final String rating;

  const PlaceDetails({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.vicinity,
    required this.rating,
  });
}