import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

class DriverDashboard extends StatefulWidget {
  final Function(int)? onTabChange;

  const DriverDashboard({super.key, this.onTabChange});

  @override
  State<DriverDashboard> createState() => _DriverDashboardState();
}

class _DriverDashboardState extends State<DriverDashboard>
    with WidgetsBindingObserver {
  // ── color tokens ──
  static const _green = Color(0xFF16A34A);
  static const _textPrimary = Color(0xFF0F172A);
  static const _textSecondary = Color(0xFF64748B);
  static const _surface = Color(0xFFF8FAFC);
  static const _border = Color(0xFFE2E8F0);
  static const _red = Color(0xFFDC2626);

  final user = FirebaseAuth.instance.currentUser;

  bool _isOnline = false;
  bool _initialSyncDone = false;
  bool _isUpdatingStatus = false; // ← ADD THIS BACK
  StreamSubscription<Position>? _locationSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this); // ← ADD
    _startLocationUpdates();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _locationSub?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _forceOffline();
    }

    // ✅ Just restore isOnline flag — location stream handles the coords
    if (state == AppLifecycleState.resumed && _isOnline) {
      FirebaseFirestore.instance.collection('users').doc(user!.uid).update({
        'isOnline': true,
      });
    }
  }

  // ── continuous GPS write to Firestore ──
  Future<void> _startLocationUpdates() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }
      if (permission == LocationPermission.deniedForever) return;

      _locationSub =
          Geolocator.getPositionStream(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              distanceFilter: 10,
            ),
          ).listen((position) {
            if (!mounted) return;
            if (!_isOnline) return; // ✅ skip when offline

            FirebaseFirestore.instance
                .collection('users')
                .doc(user!.uid)
                .update({
                  'current_location': {
                    // ✅ snake_case matches admin
                    'lat': position.latitude,
                    'lng': position.longitude,
                  },
                  'last_location_update': FieldValue.serverTimestamp(),
                });
          });
    } catch (e) {
      debugPrint('Location error: $e');
    }
  }

  // ── toggle online/offline (manual, driver-controlled) ──
  Future<void> _toggleOnline(bool val) async {
    if (_isUpdatingStatus) return;
    setState(() => _isUpdatingStatus = true);

    try {
      Map<String, dynamic> updates = {'isOnline': val};

      // ✅ Grab fresh location when going online
      if (val) {
        try {
          final position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high,
          );
          updates['current_location'] = {
            'lat': position.latitude,
            'lng': position.longitude,
          };
          updates['last_location_update'] = FieldValue.serverTimestamp();
        } catch (e) {
          debugPrint('Could not get location on toggle: $e');
        }
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .update(updates);

      if (mounted) {
        setState(() {
          _isOnline = val;
          _isUpdatingStatus = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isUpdatingStatus = false);
    }
  }

  Future<void> _forceOffline() async {
    if (user == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .update({'isOnline': false});
      if (mounted) setState(() => _isOnline = false);
    } catch (e) {
      debugPrint('Failed to force offline: $e');
    }
  }

  // ── tap to call ──
  Future<void> _callPhone(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('Could not launch $phone: $e');
    }
  }

  // ── greeting ──
  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name.isNotEmpty ? name[0].toUpperCase() : 'D';
  }

  String _formatSchedule(Timestamp? ts) {
    if (ts == null) return '—';
    final dt = ts.toDate();
    final hour = dt.hour > 12
        ? dt.hour - 12
        : dt.hour == 0
        ? 12
        : dt.hour;
    final min = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[dt.month - 1]} ${dt.day}, $hour:$min $ampm';
  }

  Stream<DocumentSnapshot> _driverStream() =>
      FirebaseFirestore.instance.collection('users').doc(user!.uid).snapshots();

  Stream<QuerySnapshot> _bookingsStream() => FirebaseFirestore.instance
      .collection('bookings')
      .where('assigned_driver_id', isEqualTo: user!.uid)
      .snapshots();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surface,
      body: StreamBuilder<DocumentSnapshot>(
        stream: _driverStream(),
        builder: (context, userSnap) {
          if (!userSnap.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: _green),
            );
          }

          final userData = userSnap.data!.data() as Map<String, dynamic>? ?? {};
          final name = userData['fullName'] ?? userData['name'] ?? 'Driver';
          final isOnline = userData['isOnline'] ?? false;
          final ratingAvg = (userData['rating_average'] ?? 0.0).toDouble();
          final driverStatus = userData['status'] ?? 'active';
          final isRestricted =
              driverStatus == 'on_leave' ||
              driverStatus == 'inactive' ||
              driverStatus == 'blocked';

          // This runs on EVERY stream update and resets _isOnline from Firestore
          // ✅ Only sync from Firestore ONCE on first load
          if (!_initialSyncDone) {
            _initialSyncDone = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) setState(() => _isOnline = isOnline);
            });
          }

          return StreamBuilder<QuerySnapshot>(
            stream: _bookingsStream(),
            builder: (context, bookingSnap) {
              if (!bookingSnap.hasData) {
                return const Center(
                  child: CircularProgressIndicator(color: _green),
                );
              }

              final bookings = bookingSnap.data!.docs;

              // ── tally stats ──
              int todayTrips = 0;
              int completed = 0;
              int inTransit = 0;
              double cashToRemit = 0;
              Map<String, dynamic>? currentJob;
              String? currentJobId;
              Map<String, dynamic>? currentJobTruck;

              final today = DateTime.now();

              for (var doc in bookings) {
                final data = doc.data() as Map<String, dynamic>;
                final status = data['status'] ?? '';
                final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
                final isToday =
                    createdAt != null &&
                    createdAt.year == today.year &&
                    createdAt.month == today.month &&
                    createdAt.day == today.day;

                if (isToday) todayTrips++;

                if (status == 'assigned' ||
                    status == 'accepted' ||
                    status == 'en_route_to_pickup' ||
                    status == 'arrived_at_pickup' ||
                    status == 'in_transit') {
                  inTransit++;
                  currentJob ??= data;
                  currentJobId ??= doc.id;
                  currentJobTruck ??=
                      data['truckType'] as Map<String, dynamic>?;
                }

                if (status == 'delivered' || status == 'completed') {
                  completed++;
                  if (isToday) {
                    cashToRemit += (data['estimatedCost'] ?? 0).toDouble();
                  }
                }
              }

              // ── extract customer info from current job ──
              final customerMap =
                  currentJob?['customer'] as Map<String, dynamic>?;
              final customerName = customerMap?['fullName'] ?? '—';
              final customerPhone = customerMap?['phone'] ?? '';
              final schedule = currentJob?['schedule'] as Timestamp?;

              return CustomScrollView(
                slivers: [
                  // ── AppBar ──
                  SliverAppBar(
                    pinned: true,
                    backgroundColor: Colors.white,
                    elevation: 0,
                    automaticallyImplyLeading: false,
                    bottom: PreferredSize(
                      preferredSize: const Size.fromHeight(1),
                      child: Container(height: 1, color: _border),
                    ),
                    title: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: _green,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            _initials(name),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _greeting(),
                              style: const TextStyle(
                                fontSize: 11,
                                color: _textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              name,
                              style: const TextStyle(
                                fontSize: 14,
                                color: _textPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    actions: [
                      Padding(
                        padding: const EdgeInsets.only(right: 16),
                        child: GestureDetector(
                          onTap: isRestricted
                              ? null
                              : () => _toggleOnline(!_isOnline),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: _isOnline
                                  ? _green.withOpacity(0.1)
                                  : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: _isOnline ? _green : _border,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 7,
                                  height: 7,
                                  decoration: BoxDecoration(
                                    color: _isOnline ? _green : _textSecondary,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  _isOnline ? 'Online' : 'Offline',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: _isOnline ? _green : _textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        // ── HERO STATS CARD ──
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E293B),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'DRIVER SUMMARY',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Color(0xFF94A3B8),
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: 0.8,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          const Icon(
                                            Icons.star_rounded,
                                            color: Color(0xFFFBBF24),
                                            size: 16,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            ratingAvg > 0
                                                ? ratingAvg.toStringAsFixed(1)
                                                : 'No rating yet',
                                            style: const TextStyle(
                                              fontSize: 18,
                                              color: Colors.white,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  if (inTransit > 0)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 5,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _green.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: _green.withOpacity(0.3),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 6,
                                            height: 6,
                                            decoration: const BoxDecoration(
                                              color: Color(0xFF4ADE80),
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                          const SizedBox(width: 5),
                                          Text(
                                            '$inTransit Active',
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: Color(0xFF4ADE80),
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  _heroStat(
                                    '$todayTrips',
                                    "Today's Trips",
                                    const Color(0xFF60A5FA),
                                  ),
                                  const SizedBox(width: 8),
                                  _heroStat(
                                    '$inTransit',
                                    'In Transit',
                                    const Color(0xFFA78BFA),
                                  ),
                                  const SizedBox(width: 8),
                                  _heroStat(
                                    '$completed',
                                    'Completed',
                                    const Color(0xFF4ADE80),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),

                        // ── CASH TO REMIT CARD ──
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: cashToRemit > 0
                                ? const Color(0xFFF0FDF4)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: cashToRemit > 0
                                  ? _green.withOpacity(0.3)
                                  : _border,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: _green.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.payments_rounded,
                                  color: _green,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'CASH TO REMIT TODAY',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: _textSecondary,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 0.6,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      '₱${NumberFormat('#,##0.00').format(cashToRemit)}',
                                      style: TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w800,
                                        color: cashToRemit > 0
                                            ? _green
                                            : _textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (completed > 0)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _green.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    '$completed ${completed == 1 ? 'trip' : 'trips'}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: _green,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),

                        // ── CURRENT JOB CARD ──
                        if (currentJob != null) ...[
                          _sectionLabel('Current Job'),
                          const SizedBox(height: 10),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: const Color(0xFFBBF7D0),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // ── Header bar ──
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 10,
                                  ),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFF0FDF4),
                                    borderRadius: BorderRadius.only(
                                      topLeft: Radius.circular(16),
                                      topRight: Radius.circular(16),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            width: 6,
                                            height: 6,
                                            decoration: const BoxDecoration(
                                              color: _green,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          const Text(
                                            'Active Delivery',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                              color: Color(0xFF166534),
                                            ),
                                          ),
                                        ],
                                      ),
                                      _statusPill(currentJob['status'] ?? ''),
                                    ],
                                  ),
                                ),

                                Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // ── Route ──
                                      Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              right: 12,
                                              top: 2,
                                            ),
                                            child: Column(
                                              children: [
                                                Container(
                                                  width: 8,
                                                  height: 8,
                                                  decoration:
                                                      const BoxDecoration(
                                                        color: _green,
                                                        shape: BoxShape.circle,
                                                      ),
                                                ),
                                                Container(
                                                  width: 1.5,
                                                  height: 30,
                                                  color: _border,
                                                ),
                                                Container(
                                                  width: 8,
                                                  height: 8,
                                                  decoration:
                                                      const BoxDecoration(
                                                        color: _red,
                                                        shape: BoxShape.circle,
                                                      ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                const Text(
                                                  'PICKUP',
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    color: _textSecondary,
                                                    letterSpacing: 0.5,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  currentJob['pickupLocation'] ??
                                                      '—',
                                                  style: const TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w600,
                                                    color: _textPrimary,
                                                  ),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                                const SizedBox(height: 12),
                                                const Text(
                                                  'DESTINATION',
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    color: _textSecondary,
                                                    letterSpacing: 0.5,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  currentJob['destination'] ??
                                                      '—',
                                                  style: const TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w600,
                                                    color: _textPrimary,
                                                  ),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),

                                      const SizedBox(height: 12),
                                      Container(height: 1, color: _border),
                                      const SizedBox(height: 12),

                                      // ── Schedule pill ──
                                      if (schedule != null) ...[
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 8,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFFFF7ED),
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              const Icon(
                                                Icons.schedule_rounded,
                                                size: 14,
                                                color: Color(0xFFC2410C),
                                              ),
                                              const SizedBox(width: 6),
                                              Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  const Text(
                                                    'PICKUP SCHEDULE',
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      color: Color(0xFF9A3412),
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      letterSpacing: 0.4,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 1),
                                                  Text(
                                                    _formatSchedule(schedule),
                                                    style: const TextStyle(
                                                      fontSize: 13,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      color: Color(0xFFC2410C),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        Container(height: 1, color: _border),
                                        const SizedBox(height: 12),
                                      ],

                                      // ── Customer row ──
                                      Row(
                                        children: [
                                          Container(
                                            width: 38,
                                            height: 38,
                                            decoration: const BoxDecoration(
                                              color: Color(0xFFDCFCE7),
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(
                                              Icons.person_rounded,
                                              size: 20,
                                              color: _green,
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                const Text(
                                                  'CUSTOMER',
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    color: _textSecondary,
                                                    letterSpacing: 0.5,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  customerName,
                                                  style: const TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w600,
                                                    color: _textPrimary,
                                                  ),
                                                ),
                                                if (customerPhone.isNotEmpty)
                                                  Text(
                                                    customerPhone,
                                                    style: const TextStyle(
                                                      fontSize: 11,
                                                      color: _textSecondary,
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                          if (customerPhone.isNotEmpty)
                                            GestureDetector(
                                              onTap: () =>
                                                  _callPhone(customerPhone),
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 14,
                                                      vertical: 8,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: _green,
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                ),
                                                child: const Row(
                                                  children: [
                                                    Icon(
                                                      Icons.call_rounded,
                                                      size: 14,
                                                      color: Colors.white,
                                                    ),
                                                    SizedBox(width: 5),
                                                    Text(
                                                      'Call',
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color: Colors.white,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),

                                      const SizedBox(height: 14),

                                      // ── View full job button ──
                                      SizedBox(
                                        width: double.infinity,
                                        child: ElevatedButton.icon(
                                          onPressed: () =>
                                              widget.onTabChange?.call(1),
                                          icon: const Icon(
                                            Icons.arrow_forward_rounded,
                                            size: 16,
                                          ),
                                          label: const Text(
                                            'View Full Job Details',
                                          ),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: _green,
                                            foregroundColor: Colors.white,
                                            elevation: 0,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 12,
                                            ),
                                            textStyle: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],

                        // ── QUICK ACTIONS ──
                        _sectionLabel('Quick Actions'),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: _actionCard(
                                icon: Icons.assignment_rounded,
                                label: 'My Jobs',
                                sub: 'Assigned deliveries',
                                iconBg: _green,
                                iconColor: Colors.white,
                                cardBg: _green,
                                titleColor: Colors.white,
                                subColor: Colors.white.withOpacity(0.7),
                                borderColor: _green,
                                onTap: () => widget.onTabChange?.call(1),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _actionCard(
                                icon: Icons.navigation_rounded,
                                label: 'Navigation',
                                sub: 'Open route map',
                                iconBg: const Color(0xFFEFF6FF),
                                iconColor: const Color(0xFF3B82F6),
                                onTap: () => widget.onTabChange?.call(2),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: _actionCard(
                                icon: Icons.checklist_rounded,
                                label: 'Delivery Logs',
                                sub: 'Completed trips',
                                iconBg: const Color(0xFFF0FDF4),
                                iconColor: _green,
                                onTap: () => widget.onTabChange?.call(3),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _actionCard(
                                icon: Icons.headset_mic_rounded,
                                label: 'Support',
                                sub: 'Contact admin',
                                iconBg: const Color(0xFFFFF7ED),
                                iconColor: const Color(0xFFF97316),
                                onTap: () => widget.onTabChange?.call(4),
                              ),
                            ),
                          ],
                        ),

                        // ── NO JOB EMPTY STATE ──
                        if (currentJob == null && inTransit == 0) ...[
                          const SizedBox(height: 24),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 40),
                            child: Column(
                              children: [
                                Container(
                                  width: 64,
                                  height: 64,
                                  decoration: BoxDecoration(
                                    color: _surface,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: _border),
                                  ),
                                  child: const Icon(
                                    Icons.local_shipping_outlined,
                                    size: 32,
                                    color: _textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 14),
                                const Text(
                                  'No active jobs',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: _textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  _isOnline
                                      ? 'You\'re online — waiting for a job'
                                      : 'Go online to receive job assignments',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: _textSecondary,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                if (!_isOnline) ...[
                                  const SizedBox(height: 16),
                                  ElevatedButton(
                                    onPressed: () => _toggleOnline(true),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: _green,
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 24,
                                        vertical: 12,
                                      ),
                                    ),
                                    child: const Text(
                                      'Go Online',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ]),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _heroStat(String value, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.07),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                color: Color(0xFF94A3B8),
                letterSpacing: 0.4,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: _textSecondary,
        letterSpacing: 0.6,
      ),
    );
  }

  Widget _actionCard({
    required IconData icon,
    required String label,
    required String sub,
    required Color iconBg,
    required Color iconColor,
    Color cardBg = Colors.white,
    Color titleColor = _textPrimary,
    Color subColor = _textSecondary,
    Color borderColor = _border,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 18),
            ),
            const SizedBox(height: 12),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: titleColor,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              sub,
              style: TextStyle(fontSize: 11, color: subColor),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusPill(String status) {
    Color bg;
    Color text;
    String label;

    switch (status) {
      case 'assigned':
        bg = const Color(0xFFDBEAFE);
        text = const Color(0xFF1E40AF);
        label = 'Assigned';
        break;
      case 'accepted':
        bg = const Color(0xFFCFFAFE);
        text = const Color(0xFF0891B2);
        label = 'Accepted';
        break;
      case 'en_route_to_pickup':
        bg = const Color(0xFFFEF3C7);
        text = const Color(0xFF92400E);
        label = 'En Route';
        break;
      case 'arrived_at_pickup':
        bg = const Color(0xFFFFF7ED);
        text = const Color(0xFFF97316);
        label = 'At Pickup';
        break;
      case 'in_transit':
        bg = const Color(0xFFEDE9FE);
        text = const Color(0xFF5B21B6);
        label = 'In Transit';
        break;
      case 'delivered':
        bg = const Color(0xFFDCFCE7);
        text = const Color(0xFF166534);
        label = 'Delivered';
        break;
      case 'completed':
        bg = const Color(0xFFDCFCE7);
        text = const Color(0xFF166534);
        label = 'Completed';
        break;
      default:
        bg = const Color(0xFFF1F5F9);
        text = _textSecondary;
        label = status.replaceAll('_', ' ');
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: text,
        ),
      ),
    );
  }
}
