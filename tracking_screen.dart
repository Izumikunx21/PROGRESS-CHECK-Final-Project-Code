import 'dart:async';
import 'package:flutter/material.dart';
import '../../chat/trip_person_card.dart';
import 'delivery_success_screen.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/route_service.dart';

class TrackingScreen extends StatefulWidget {
  final String bookingId;

  const TrackingScreen({super.key, required this.bookingId});

  @override
  State<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingScreen>
    with TickerProviderStateMixin {
  // ── color tokens ──
  static const _green = Color(0xFF16A34A);
  static const _textPrimary = Color(0xFF0F172A);
  static const _textSecondary = Color(0xFF64748B);
  static const _surface = Color(0xFFF8FAFC);
  static const _border = Color(0xFFE2E8F0);
  static const _red = Color(0xFFDC2626);

  final MapController _mapController = MapController();

  // ── state ──
  LatLng? _driverLocation;
  LatLng? _pickupLocation;
  LatLng? _destinationLocation;
  List<LatLng> _routePoints = [];

  Map<String, dynamic>? _bookingData;
  Map<String, dynamic>? _truckData;

  bool _isLoading = true;
  String? _eta;
  double? _remainingDistance;
  String? _currentDriverId;
  bool _deliveredNavigated = false; // ✅ guard duplicate subscriptions

  // ── helper to determine correct route target ──
  bool _isHeadingToPickup(String? status) {
    return status == 'assigned' ||
        status == 'accepted' ||
        status == 'en_route_to_pickup' ||
        status == 'arrived_at_pickup';
  }

  // ── map style toggle ──
  bool _isSatellite = false; // ✅ satellite / streets toggle

  // ── animation for driver marker ──
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // ── streams ──
  StreamSubscription? _bookingSub;
  StreamSubscription? _driverSub;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _listenToBooking();
  }

  @override
  void dispose() {
    _bookingSub?.cancel();
    _driverSub?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  // ── listen to booking ──
  void _listenToBooking() {
    _bookingSub = FirebaseFirestore.instance
        .collection('bookings')
        .doc(widget.bookingId)
        .snapshots()
        .listen((snap) async {
          if (!snap.exists || !mounted) return;

          final data = snap.data() as Map<String, dynamic>;
          setState(() => _bookingData = data);

          // ← delivered check
          if (data['status'] == 'delivered' && !_deliveredNavigated) {
            _deliveredNavigated = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      DeliverySuccessScreen(bookingId: widget.bookingId),
                ),
              );
            });
            return; // ← closes the if-block AND stops the rest of the listener
          }

          final pickupCoords = data['pickupCoords'];
          final destCoords = data['destinationCoords'];

          if (pickupCoords != null) {
            _pickupLocation = LatLng(
              (pickupCoords['lat'] as num).toDouble(),
              (pickupCoords['lng'] as num).toDouble(),
            );
          }

          if (destCoords != null) {
            _destinationLocation = LatLng(
              (destCoords['lat'] as num).toDouble(),
              (destCoords['lng'] as num).toDouble(),
            );
          }

          final driverId = data['assigned_driver_id'];
          if (driverId != null && driverId != _currentDriverId) {
            _currentDriverId = driverId;
            _listenToDriver(driverId);
          }

          if (_driverLocation != null) {
            final target = _isHeadingToPickup(data['status'])
                ? _pickupLocation
                : _destinationLocation;
            if (target != null) {
              await _fetchRoute(_driverLocation!, target);
            }
          }

          final truckId = data['assigned_truck_id'];
          if (truckId != null) {
            final truckSnap = await FirebaseFirestore.instance
                .collection('trucks')
                .doc(truckId)
                .get();
            if (truckSnap.exists && mounted) {
              setState(
                () => _truckData = truckSnap.data() as Map<String, dynamic>,
              );
            }
          }

          if (mounted) setState(() => _isLoading = false);
        });
  }

  // ── listen to driver location ──
  void _listenToDriver(String driverId) {
    _driverSub?.cancel();
    _driverSub = FirebaseFirestore.instance
        .collection('users')
        .doc(driverId)
        .snapshots()
        .listen((snap) async {
          if (!snap.exists || !mounted) return;

          final data = snap.data() as Map<String, dynamic>;

          final loc = data['currentLocation'];
          if (loc == null) return;

          final newLocation = LatLng(
            (loc['lat'] as num).toDouble(),
            (loc['lng'] as num).toDouble(),
          );

          setState(() => _driverLocation = newLocation);

          // ✅ use live _bookingData status
          // ── in _listenToDriver() ──
          final status = _bookingData?['status'];
          final target = _isHeadingToPickup(status)
              ? _pickupLocation
              : _destinationLocation;

          if (target != null) {
            await _fetchRoute(newLocation, target);
          }

          try {
            _mapController.move(newLocation, _mapController.camera.zoom);
          } catch (_) {}
        });
  }

  // ── fetch OSRM route ──
  // ── fetch OSRM route ──
  Future<void> _fetchRoute(LatLng from, LatLng to) async {
    final route = await RouteService.getRoute(
      from.latitude,
      from.longitude,
      to.latitude,
      to.longitude,
    );

    if (route != null && mounted) {
      setState(() {
        _routePoints = route.points;
        _remainingDistance = route.distanceKm;
        _eta = _formatEta(route.duration);
      });
    }
  }

  String _formatEta(double seconds) {
    final mins = (seconds / 60).round();
    if (mins < 60) return '$mins min';
    final hrs = mins ~/ 60;
    final rem = mins % 60;
    return rem == 0 ? '${hrs}h' : '${hrs}h ${rem}m';
  }

  String _formatTruckType(String type) {
    if (type.trim().isEmpty) return 'Truck';
    return type
        .trim()
        .toLowerCase()
        .replaceAll('-', '_')
        .split('_')
        .where((w) => w.isNotEmpty)
        .map((w) => w[0].toUpperCase() + w.substring(1))
        .join(' ');
  }

  // ── updated _getStatusLabel() ──
  String _getStatusLabel() {
    final status = _bookingData?['status'] ?? '';
    switch (status) {
      case 'assigned':
        return 'Driver assigned — preparing for pickup';
      case 'accepted':
        return 'Driver accepted — preparing to depart';
      case 'en_route_to_pickup':
        return 'Driver heading to pickup location';
      case 'arrived_at_pickup':
        return 'Driver arrived at pickup';
      case 'in_transit':
        return 'On the way to your destination';
      case 'delivered':
        return 'Delivery completed';
      default:
        return 'Tracking...';
    }
  }

  // ── zoom helpers ──
  void _zoomIn() {
    final current = _mapController.camera.zoom;
    if (current < 18)
      _mapController.move(_mapController.camera.center, current + 1);
  }

  void _zoomOut() {
    final current = _mapController.camera.zoom;
    if (current > 3)
      _mapController.move(_mapController.camera.center, current - 1);
  }

  // ── center on driver ──
  void _centerOnDriver() {
    if (_driverLocation != null) {
      _mapController.move(_driverLocation!, _mapController.camera.zoom);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.all(8),
          child: Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            elevation: 2,
            shadowColor: Colors.black26,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => Navigator.maybePop(context),
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 18,
                color: _textPrimary,
              ),
            ),
          ),
        ),
        title: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: const Text(
            'Live Tracking',
            style: TextStyle(
              color: _textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _green))
          : Stack(
              children: [
                // ── MAP ──
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter:
                        _driverLocation ??
                        _pickupLocation ??
                        const LatLng(8.4542, 124.6319),
                    initialZoom: 15,
                  ),
                  children: [
                    // ── tile layer (streets or satellite) ──
                    TileLayer(
                      urlTemplate: _isSatellite
                          ? 'https://api.maptiler.com/maps/satellite/{z}/{x}/{y}.jpg?key=OVjUofYwRKNU7BYrwQzz'
                          : 'https://api.maptiler.com/maps/streets-v2/{z}/{x}/{y}.png?key=OVjUofYwRKNU7BYrwQzz',
                      userAgentPackageName: 'com.smarttruck.app',
                    ),

                    // ── route polyline ──
                    if (_routePoints.isNotEmpty)
                      PolylineLayer(
                        polylines: [
                          // shadow
                          Polyline(
                            points: _routePoints,
                            strokeWidth: 7,
                            color: Colors.black.withOpacity(0.15),
                          ),
                          // main line
                          Polyline(
                            points: _routePoints,
                            strokeWidth: 4,
                            color: _isSatellite ? Colors.white : _green,
                          ),
                        ],
                      ),

                    // ── markers ──
                    MarkerLayer(
                      markers: [
                        if (_pickupLocation != null)
                          Marker(
                            point: _pickupLocation!,
                            width: 40,
                            height: 40,
                            child: Container(
                              decoration: BoxDecoration(
                                color: _green,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: _green.withOpacity(0.4),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.my_location_rounded,
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                          ),

                        if (_destinationLocation != null)
                          Marker(
                            point: _destinationLocation!,
                            width: 40,
                            height: 40,
                            child: Container(
                              decoration: BoxDecoration(
                                color: _red,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: _red.withOpacity(0.4),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.flag_rounded,
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                          ),

                        if (_driverLocation != null)
                          Marker(
                            point: _driverLocation!,
                            width: 56,
                            height: 56,
                            child: AnimatedBuilder(
                              animation: _pulseAnimation,
                              builder: (context, child) {
                                return Transform.scale(
                                  scale: _pulseAnimation.value,
                                  child: child,
                                );
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: _green, width: 3),
                                  boxShadow: [
                                    BoxShadow(
                                      color: _green.withOpacity(0.3),
                                      blurRadius: 12,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.local_shipping_rounded,
                                  color: _green,
                                  size: 26,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),

                // ── ETA chip ──
                if (_eta != null)
                  Positioned(
                    top: 100,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.access_time_rounded,
                              size: 14,
                              color: _green,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'ETA $_eta',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: _textPrimary,
                              ),
                            ),
                            if (_remainingDistance != null) ...[
                              const SizedBox(width: 8),
                              Container(width: 1, height: 12, color: _border),
                              const SizedBox(width: 8),
                              Text(
                                '${_remainingDistance!.toStringAsFixed(1)} km',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: _textSecondary,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),

                // ── RIGHT SIDE CONTROLS (zoom + satellite + recenter) ──
                Positioned(
                  right: 16,
                  bottom: 220, // sits above bottom sheet
                  child: Column(
                    children: [
                      // ── satellite toggle ──
                      _mapButton(
                        icon: _isSatellite
                            ? Icons.map_rounded
                            : Icons.satellite_alt_rounded,
                        tooltip: _isSatellite ? 'Streets' : 'Satellite',
                        onTap: () =>
                            setState(() => _isSatellite = !_isSatellite),
                        active: _isSatellite,
                      ),
                      const SizedBox(height: 8),
                      // ── zoom in ──
                      _mapButton(
                        icon: Icons.add_rounded,
                        tooltip: 'Zoom in',
                        onTap: _zoomIn,
                      ),
                      const SizedBox(height: 4),
                      // ── zoom out ──
                      _mapButton(
                        icon: Icons.remove_rounded,
                        tooltip: 'Zoom out',
                        onTap: _zoomOut,
                      ),
                      const SizedBox(height: 8),
                      // ── center on driver ──
                      _mapButton(
                        icon: Icons.my_location_rounded,
                        tooltip: 'Center on driver',
                        onTap: _centerOnDriver,
                        color: _green,
                      ),
                    ],
                  ),
                ),

                // ── BOTTOM SHEET ──
                DraggableScrollableSheet(
                  initialChildSize: 0.28,
                  minChildSize: 0.18,
                  maxChildSize: 0.55,
                  snap: true,
                  snapSizes: const [0.18, 0.28, 0.55],
                  builder: (context, scrollController) {
                    return Container(
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(24),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Color(0x1A000000),
                            blurRadius: 24,
                            offset: Offset(0, -4),
                          ),
                        ],
                      ),
                      child: ListView(
                        controller: scrollController,
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                        children: [
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Container(
                                width: 40,
                                height: 4,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFCBD5E1),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ),
                          ),

                          // ── STATUS ROW ──
                          Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: _green,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _getStatusLabel(),
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: _textPrimary,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 16),

                          // ── DRIVER CARD ──
                          // ── DRIVER CARD ──
                          TripPersonCard(bookingId: widget.bookingId),

                          const SizedBox(height: 12),

                          // ── ROUTE SUMMARY ──
                          const SizedBox(height: 12),

                          // ── ROUTE SUMMARY ──
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: _surface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: _border),
                            ),
                            child: Column(
                              children: [
                                _routeRow(
                                  Icons.radio_button_checked,
                                  _green,
                                  'PICKUP',
                                  _bookingData?['pickupLocation'] ?? '—',
                                ),
                                Padding(
                                  padding: const EdgeInsets.only(left: 8),
                                  child: Container(
                                    width: 1.5,
                                    height: 16,
                                    color: _border,
                                  ),
                                ),
                                _routeRow(
                                  Icons.location_on_rounded,
                                  _red,
                                  'DESTINATION',
                                  _bookingData?['destination'] ?? '—',
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 12),

                          // ── TRUCK INFO ──
                          if (_truckData != null)
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: _surface,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: _border),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.local_shipping_rounded,
                                    size: 16,
                                    color: _textSecondary,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _formatTruckType(
                                      (_truckData!['truck_type'] ?? '')
                                          .toString(),
                                    ),
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: _textPrimary,
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    _truckData!['plate_number'] ?? '—',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: _textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                          // ← ADD THIS RIGHT HERE ↓
                          const SizedBox(height: 12),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
    );
  }

  // ── reusable map control button ──
  Widget _mapButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    Color? color,
    bool active = false,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: active ? _green : Colors.white,
        borderRadius: BorderRadius.circular(12),
        elevation: 3,
        shadowColor: Colors.black26,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            child: Icon(
              icon,
              size: 20,
              color: active ? Colors.white : (color ?? _textPrimary),
            ),
          ),
        ),
      ),
    );
  }

  Widget _routeRow(IconData icon, Color color, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 10,
                  color: _textSecondary,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
