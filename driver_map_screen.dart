import 'dart:async';
import 'package:flutter/material.dart';
import '../../chat/trip_person_card.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import '../../services/route_service.dart';
import 'driver_delivery_success_screen.dart'; // ← add

class DriverMapScreen extends StatefulWidget {
  const DriverMapScreen({super.key});

  @override
  State<DriverMapScreen> createState() => _DriverMapScreenState();
}

class _DriverMapScreenState extends State<DriverMapScreen>
    with TickerProviderStateMixin {
  // ── color tokens (matches app UI) ──
  static const _green = Color(0xFF16A34A);
  static const _red = Color(0xFFDC2626);
  static const _textPrimary = Color(0xFF0F172A);
  static const _textSecondary = Color(0xFF64748B);
  static const _surface = Color(0xFFF8FAFC);
  static const _border = Color(0xFFE2E8F0);

  final MapController _mapController = MapController();

  // ── state ──
  LatLng? _myLocation;
  LatLng? _pickupLocation;
  LatLng? _destinationLocation;
  List<LatLng> _routePoints = [];

  Map<String, dynamic>? _bookingData;
  String? _bookingId;
  bool _isLoading = true;
  bool _isSatellite = false;
  String? _eta;
  double? _remainingDistance;
  bool _isUpdatingStatus = false;

  // ── pulse animation for own marker ──
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  StreamSubscription? _bookingSub;
  StreamSubscription<Position>? _gpsSub;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.85, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _initLocation();
  }

  @override
  void dispose() {
    _bookingSub?.cancel();
    _gpsSub?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  // ── start GPS and write to Firestore ──
  Future<void> _initLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    final pos = await Geolocator.getCurrentPosition();
    final initial = LatLng(pos.latitude, pos.longitude);
    if (mounted) setState(() => _myLocation = initial);

    _gpsSub =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 10,
          ),
        ).listen((Position pos) async {
          final user = FirebaseAuth.instance.currentUser;
          if (user == null) return;

          final newLocation = LatLng(pos.latitude, pos.longitude);
          if (mounted) setState(() => _myLocation = newLocation);

          // ✅ write camelCase — matches what customer TrackingScreen reads
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .update({
                'currentLocation': {'lat': pos.latitude, 'lng': pos.longitude},
              });

          // recalculate route to current waypoint
          await _recalculateRoute();

          try {
            _mapController.move(newLocation, _mapController.camera.zoom);
          } catch (_) {}
        });

    _listenToActiveBooking();
  }

  // ── listen to the driver's active booking ──
  void _listenToActiveBooking() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _bookingSub = FirebaseFirestore.instance
        .collection('bookings')
        .where('assigned_driver_id', isEqualTo: user.uid)
        .where(
          'status',
          whereIn: [
            'accepted', // ← starts here now
            'en_route_to_pickup',
            'arrived_at_pickup',
            'in_transit',
          ],
        )
        .limit(1)
        .snapshots()
        .listen((snap) async {
          if (!mounted) return;

          if (snap.docs.isEmpty) {
            setState(() {
              _bookingData = null;
              _bookingId = null;
              _routePoints = [];
              _pickupLocation = null;
              _destinationLocation = null;
              _isLoading = false;
            });
            return;
          }

          final doc = snap.docs.first;
          final data = doc.data();

          final pickupCoords = data['pickupCoords'];
          final destCoords = data['destinationCoords'];

          LatLng? pickup;
          LatLng? dest;

          if (pickupCoords != null) {
            pickup = LatLng(
              (pickupCoords['lat'] as num).toDouble(),
              (pickupCoords['lng'] as num).toDouble(),
            );
          }

          if (destCoords != null) {
            dest = LatLng(
              (destCoords['lat'] as num).toDouble(),
              (destCoords['lng'] as num).toDouble(),
            );
          }

          setState(() {
            _bookingData = data;
            _bookingId = doc.id;
            _pickupLocation = pickup;
            _destinationLocation = dest;
            _isLoading = false;
          });

          await _recalculateRoute();
        });
  }

  // ── route to next waypoint based on status ──
  Future<void> _recalculateRoute() async {
    if (_myLocation == null || _bookingData == null) return;
    final status = _bookingData!['status'];

    LatLng? target;
    if (status == 'accepted' ||
        status == 'en_route_to_pickup' ||
        status == 'arrived_at_pickup') {
      target = _pickupLocation;
    } else if (status == 'in_transit') {
      target = _destinationLocation;
    }

    if (target != null) await _fetchRoute(_myLocation!, target);
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
        _eta = _formatEta(route.duration);
        _remainingDistance = route.distanceKm;
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

  void _zoomIn() {
    final z = _mapController.camera.zoom;
    if (z < 18) _mapController.move(_mapController.camera.center, z + 1);
  }

  void _zoomOut() {
    final z = _mapController.camera.zoom;
    if (z > 3) _mapController.move(_mapController.camera.center, z - 1);
  }

  void _centerOnMe() {
    if (_myLocation != null) {
      _mapController.move(_myLocation!, _mapController.camera.zoom);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
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
            'Live Map',
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
                        _myLocation ?? const LatLng(8.4542, 124.6319),
                    initialZoom: 15,
                  ),
                  children: [
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
                          Polyline(
                            points: _routePoints,
                            strokeWidth: 7,
                            color: Colors.black.withOpacity(0.15),
                          ),
                          Polyline(
                            points: _routePoints,
                            strokeWidth: 4,
                            color: _isSatellite ? Colors.white : _green,
                          ),
                        ],
                      ),

                    MarkerLayer(
                      markers: [
                        // ── pickup marker ──
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

                        // ── destination marker ──
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

                        // ── driver's own position ──
                        if (_myLocation != null)
                          Marker(
                            point: _myLocation!,
                            width: 56,
                            height: 56,
                            child: AnimatedBuilder(
                              animation: _pulseAnimation,
                              builder: (context, child) => Transform.scale(
                                scale: _pulseAnimation.value,
                                child: child,
                              ),
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
                if (_eta != null && _bookingData != null)
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

                // ── map controls ──
                Positioned(
                  right: 16,
                  bottom: 260,
                  child: Column(
                    children: [
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
                      _mapButton(
                        icon: Icons.add_rounded,
                        tooltip: 'Zoom in',
                        onTap: _zoomIn,
                      ),
                      const SizedBox(height: 4),
                      _mapButton(
                        icon: Icons.remove_rounded,
                        tooltip: 'Zoom out',
                        onTap: _zoomOut,
                      ),
                      const SizedBox(height: 8),
                      _mapButton(
                        icon: Icons.my_location_rounded,
                        tooltip: 'Center on me',
                        onTap: _centerOnMe,
                        color: _green,
                      ),
                    ],
                  ),
                ),

                // ── BOTTOM SHEET ──
                DraggableScrollableSheet(
                  initialChildSize: 0.32,
                  minChildSize: 0.18,
                  maxChildSize: 0.55,
                  snap: true,
                  snapSizes: const [0.18, 0.32, 0.55],
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
                          // ── drag handle ──
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

                          // ── no active trip ──
                          if (_bookingData == null) ...[
                            const SizedBox(height: 20),
                            Center(
                              child: Column(
                                children: [
                                  Container(
                                    width: 56,
                                    height: 56,
                                    decoration: BoxDecoration(
                                      color: _surface,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: _border),
                                    ),
                                    child: const Icon(
                                      Icons.local_shipping_outlined,
                                      size: 28,
                                      color: _textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  const Text(
                                    'No active trip',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: _textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    'Accept a job to start navigation',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: _textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          // ── active trip ──
                          if (_bookingData != null) ...[
                            // status row
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

                            const SizedBox(height: 14),

                            TripPersonCard(
                              bookingId: _bookingId!,
                            ), // ← add comma here
                            const SizedBox(height: 12),

                            // ── route summary ──
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

                            // ── action buttons ──
                            _buildActionButtons(),
                          ],
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
    );
  }

  // ── action buttons ──
  Widget _buildActionButtons() {
    final status = _bookingData?['status'] ?? '';

    return Column(
      children: [
        if (status == 'accepted')
          _actionButton(
            label: 'Start Trip',
            icon: Icons.navigation_rounded,
            color: const Color(0xFF3B82F6),
            onTap: () => _updateStatus('en_route_to_pickup'),
          ),

        if (status == 'en_route_to_pickup')
          _actionButton(
            label: 'Arrived at Pickup',
            icon: Icons.location_on_rounded,
            color: Colors.orange,
            onTap: () => _updateStatus('arrived_at_pickup'),
          ),

        if (status == 'arrived_at_pickup')
          _actionButton(
            label: 'Start Delivery',
            icon: Icons.play_arrow_rounded,
            color: const Color(0xFF16A34A),
            onTap: () => _updateStatus('in_transit'),
          ),

        if (status == 'in_transit')
          _actionButton(
            label: 'Mark as Delivered',
            icon: Icons.check_circle_rounded,
            color: const Color(0xFF16A34A),
            onTap: () => _confirmComplete(),
          ),
      ],
    );
  }

  // ── update booking status ──
  Future<void> _updateStatus(String newStatus) async {
    if (_bookingId == null) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isUpdatingStatus = true);

    try {
      final bookingRef = FirebaseFirestore.instance
          .collection('bookings')
          .doc(_bookingId);
      final driverRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid);

      if (newStatus == 'en_route_to_pickup') {
        await bookingRef.update({
          'status': 'en_route_to_pickup',
          'enRouteAt': FieldValue.serverTimestamp(),
        });
      } else if (newStatus == 'arrived_at_pickup') {
        await bookingRef.update({
          'status': 'arrived_at_pickup',
          'arrivedAtPickupAt': FieldValue.serverTimestamp(),
        });
      } else if (newStatus == 'in_transit') {
        await bookingRef.update({
          'status': 'in_transit',
          'inTransitAt': FieldValue.serverTimestamp(),
        });
        await driverRef.update({'availability': 'on_trip'});
      } else if (newStatus == 'delivered') {
        final bookingSnap = await bookingRef.get();
        final bookingSnapData = bookingSnap.data()!;
        final assignedTruckId = bookingSnapData['assigned_truck_id'];
        final deliveredBookingId = _bookingId!;

        // ── grab earnings + delivery time ──
        final estimatedCost =
            (bookingSnapData['estimatedCost'] as num?)?.toDouble() ?? 0.0;
        final deliveredAt = DateTime.now();
        final startOfDay = DateTime(
          deliveredAt.year,
          deliveredAt.month,
          deliveredAt.day,
        );
        final startOfWeek = deliveredAt.subtract(
          Duration(days: deliveredAt.weekday - 1),
        );
        final startOfMonth = DateTime(deliveredAt.year, deliveredAt.month, 1);

        final batch = FirebaseFirestore.instance.batch();

        batch.update(bookingRef, {
          'status': 'delivered',
          'deliveredAt': FieldValue.serverTimestamp(),
        });

        batch.update(driverRef, {
          'status': 'active', // ← add this
          'availability': 'available', // ← keep for backward compat
          'current_booking_id': FieldValue.delete(),
          'completedJobs': FieldValue.increment(1),
          'lastEarningDate': FieldValue.serverTimestamp(),
          if (deliveredAt.isAfter(startOfDay))
            'earningsToday': FieldValue.increment(estimatedCost),
          if (deliveredAt.isAfter(startOfWeek))
            'earningsWeek': FieldValue.increment(estimatedCost),
          if (deliveredAt.isAfter(startOfMonth))
            'earningsMonth': FieldValue.increment(estimatedCost),
        });

        if (assignedTruckId != null) {
          final truckRef = FirebaseFirestore.instance
              .collection('trucks')
              .doc(assignedTruckId);
          batch.update(truckRef, {
            'status': 'available',
            'assigned_booking_id': FieldValue.delete(),
            'current_booking_id': FieldValue.delete(),
          });
        }

        await batch.commit();

        // ── cancel streams before navigating ──
        await _bookingSub?.cancel();
        await _gpsSub?.cancel();

        if (!mounted) return;

        WidgetsBinding.instance.addPostFrameCallback((_) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (_) =>
                  DriverDeliverySuccessScreen(bookingId: deliveredBookingId),
            ),
            (route) => false,
          );
        });

        return; // ← skip finally setState
      }

      if (mounted) setState(() => _isUpdatingStatus = false);
    } catch (e) {
      debugPrint('Status update error: $e');
      if (mounted) setState(() => _isUpdatingStatus = false);
    }
  }

  // ── status label ──
  String _getStatusLabel() {
    switch (_bookingData?['status']) {
      case 'accepted':
        return 'Trip accepted — tap Start Trip to begin';
      case 'en_route_to_pickup':
        return 'Heading to pickup location';
      case 'arrived_at_pickup':
        return 'Arrived — ready to load';
      case 'in_transit':
        return 'Delivering to destination';
      default:
        return 'No active trip';
    }
  }

  // ── confirm delivery dialog ──
  void _confirmComplete() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Confirm Delivery?',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
        content: const Text(
          'Mark this booking as delivered? This cannot be undone.',
          style: TextStyle(fontSize: 13, color: _textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: _textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _updateStatus('delivered');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _green,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Confirm Delivered'),
          ),
        ],
      ),
    );
  }

  Widget _actionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _isUpdatingStatus ? null : onTap,
        icon: _isUpdatingStatus
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Icon(icon, size: 18),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(vertical: 14),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

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
