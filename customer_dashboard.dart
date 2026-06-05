import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:smart_truck_app/screens/customer/booking_screen.dart';
import '../../services/route_service.dart';
import 'package:smart_truck_app/screens/customer/support_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';

class CustomerDashboard extends StatefulWidget {
  final Function(int)? onTabChange;

  const CustomerDashboard({super.key, this.onTabChange});

  @override
  State<CustomerDashboard> createState() => _CustomerDashboardState();
}

class _CustomerDashboardState extends State<CustomerDashboard>
    with WidgetsBindingObserver {
  // ── color tokens ──
  static const _green = Color(0xFF16A34A);
  static const _textPrimary = Color(0xFF0F172A);
  static const _textSecondary = Color(0xFF64748B);
  static const _surface = Color(0xFFF8FAFC);
  static const _border = Color(0xFFE2E8F0);

  final _user = FirebaseAuth.instance.currentUser;
  final Map<String, String> _driverPhoneCache = {};
  final Map<String, bool> _driverPhoneLoading = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _setOnline(true); // customer is active when screen loads
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _setOnline(false); // customer left the screen
    super.dispose();
  }

  // ── called whenever app lifecycle changes ──
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _setOnline(false);
    } else if (state == AppLifecycleState.resumed) {
      _setOnline(true);
    }
  }

  Future<void> _loadDriverPhone(String driverId) async {
    if (driverId.isEmpty) return;
    if (_driverPhoneCache.containsKey(driverId)) return;
    if (_driverPhoneLoading[driverId] == true) return;

    _driverPhoneLoading[driverId] = true;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(driverId)
          .get();

      if (mounted) {
        setState(() {
          _driverPhoneCache[driverId] = doc.data()?['phone']?.toString() ?? '';
          _driverPhoneLoading[driverId] = false;
        });
      }
    } catch (e) {
      debugPrint('Failed to load driver phone: $e');
      _driverPhoneLoading[driverId] = false;
    }
  }

  Future<void> _setOnline(bool value) async {
    if (_user == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_user.uid)
          .update({'isOnline': value});
    } catch (e) {
      debugPrint('Failed to update isOnline: $e');
    }
  }

  Future<void> _callPhone(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Stream<DocumentSnapshot> getUserStream() {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(_user!.uid)
        .snapshots();
  }

  Stream<QuerySnapshot> getBookingsStream() {
    return FirebaseFirestore.instance
        .collection('bookings')
        .where('userId', isEqualTo: _user!.uid)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // ── helper: initials from name ──
  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : 'U';
  }

  // ── helper: greeting by hour ──
  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  final Map<String, String?> _etaCache = {};
  final Map<String, bool> _etaLoading = {};

  Future<void> _loadEta(Map<String, dynamic> trip) async {
    final id = trip['assigned_driver_id'] ?? trip['pickupLocation'] ?? '';

    // ── stop if already cached or currently loading ──
    if (_etaCache.containsKey(id)) return; // ← this was missing
    if (_etaLoading[id] == true) return;

    final driverLocation = trip['currentLocation'] as Map<String, dynamic>?;
    final destMap = trip['destinationCoords'] as Map<String, dynamic>?;
    final originMap =
        driverLocation ?? (trip['pickupCoords'] as Map<String, dynamic>?);

    if (originMap == null || destMap == null) return;

    _etaLoading[id] = true;

    final route = await RouteService.getRoute(
      (originMap['lat'] as num).toDouble(),
      (originMap['lng'] as num).toDouble(),
      (destMap['lat'] as num).toDouble(),
      (destMap['lng'] as num).toDouble(),
    );

    if (mounted) {
      setState(() {
        _etaCache[id] = route != null ? _formatEta(route.duration) : null;
        _etaLoading[id] = false;
      });
    }
  }

  String _formatEta(double seconds) {
    final totalMinutes = (seconds / 60).round();
    if (totalMinutes < 60) return '$totalMinutes min';
    final hours = totalMinutes ~/ 60;
    final mins = totalMinutes % 60;
    return mins == 0 ? '${hours}h' : '${hours}h ${mins}m';
  }

  String _formatCost(dynamic raw) {
    final amount = raw is int ? raw.toDouble() : (raw as num).toDouble();
    return '₱${NumberFormat('#,##0.00').format(amount)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surface,
      body: StreamBuilder<DocumentSnapshot>(
        stream: getUserStream(),
        builder: (context, userSnapshot) {
          if (userSnapshot.hasError) {
            return const Center(child: Text("Something went wrong."));
          }
          if (!userSnapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: _green),
            );
          }

          final userData = userSnapshot.data!.data() as Map<String, dynamic>;
          final name =
              userData['fullName'] ??
              userData['name'] ??
              userData['firstName'] ??
              'User';

          return StreamBuilder<QuerySnapshot>(
            stream: getBookingsStream(),
            builder: (context, bookingSnapshot) {
              if (bookingSnapshot.hasError) {
                return const Center(child: Text("Something went wrong."));
              }
              if (!bookingSnapshot.hasData) {
                return const Center(
                  child: CircularProgressIndicator(color: _green),
                );
              }

              final bookings = bookingSnapshot.data!.docs;

              int total = 0;
              int assigned = 0;
              int inTransit = 0;
              int completed = 0;
              final List<Map<String, dynamic>> activeTrips = [];

              // ── loop 1: status counters ──
              for (var doc in bookings) {
                final data = doc.data() as Map<String, dynamic>;
                final status = data['status'];
                total++;

                if (status == 'pending') assigned++;
                if (status == 'approved' || // ← ADD THIS
                    status == 'assigned' ||
                    status == 'truck_assigned' ||
                    status == 'accepted' ||
                    status == 'en_route_to_pickup' ||
                    status == 'arrived_at_pickup' ||
                    status == 'in_transit') {
                  inTransit++;
                  activeTrips.add(data);
                }
                if (status == 'delivered' || status == 'completed') completed++;
              }

              // ── loop 2: monthly spend ──
              double totalSpentMonth = 0;
              int tripsThisMonth = 0;
              final now = DateTime.now();

              for (var doc in bookings) {
                final data = doc.data() as Map<String, dynamic>;
                final status = data['status'];
                final createdAt = (data['createdAt'] as Timestamp?)?.toDate();

                if ((status == 'delivered' || status == 'completed') &&
                    createdAt != null &&
                    createdAt.year == now.year &&
                    createdAt.month == now.month) {
                  final raw = data['estimatedCost'] ?? 0;
                  totalSpentMonth += (raw is int
                      ? raw.toDouble()
                      : (raw as num).toDouble());
                  tripsThisMonth++;
                }
              }

              // ── sort by createdAt and take only 3 ──
              final allBookings =
                  bookings
                      .map((doc) => doc.data() as Map<String, dynamic>)
                      .toList()
                    ..sort((a, b) {
                      final aTime =
                          (a['createdAt'] as Timestamp?)
                              ?.millisecondsSinceEpoch ??
                          0;
                      final bTime =
                          (b['createdAt'] as Timestamp?)
                              ?.millisecondsSinceEpoch ??
                          0;
                      return bTime.compareTo(aTime);
                    });

              final recentBookings = allBookings.take(3).toList();

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
                        // avatar
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
                      Container(
                        margin: const EdgeInsets.only(right: 16),
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: _surface,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: _border),
                        ),
                        child: const Icon(
                          Icons.notifications_outlined,
                          color: _textPrimary,
                          size: 18,
                        ),
                      ),
                    ],
                  ),

                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        // ── HERO CARD ──
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
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        "FLEET SUMMARY",
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Color(0xFF94A3B8),
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: 0.8,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        "$total Total Bookings",
                                        style: const TextStyle(
                                          fontSize: 18,
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700,
                                        ),
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
                                            "$inTransit Active",
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
                                    "$assigned",
                                    "Pending",
                                    const Color(0xFF60A5FA),
                                  ),
                                  const SizedBox(width: 8),
                                  _heroStat(
                                    "$inTransit",
                                    "Active",
                                    const Color(0xFFA78BFA),
                                  ),
                                  const SizedBox(width: 8),
                                  _heroStat(
                                    "$completed",
                                    "Completed",
                                    const Color(0xFF4ADE80),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),

                        // ── TOTAL SPENT THIS MONTH CARD ──
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: totalSpentMonth > 0
                                ? const Color(0xFFF0FDF4)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: totalSpentMonth > 0
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
                                  Icons.receipt_long_rounded,
                                  color: _green,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'TOTAL SPENT — ${DateFormat('MMMM yyyy').format(DateTime.now()).toUpperCase()}',
                                      style: const TextStyle(
                                        fontSize: 10,
                                        color: _textSecondary,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 0.6,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      totalSpentMonth > 0
                                          ? '₱${NumberFormat('#,##0.00').format(totalSpentMonth)}'
                                          : '₱0.00',
                                      style: TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w800,
                                        color: totalSpentMonth > 0
                                            ? _green
                                            : _textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (tripsThisMonth > 0)
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
                                    '$tripsThisMonth ${tripsThisMonth == 1 ? 'trip' : 'trips'}',
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
                        const SizedBox(height: 16),

                        // ── SUSPENSION BANNER ──
                        if (userData['status'] == 'blocked') ...[
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEE2E2),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: const Color(0xFFFCA5A5),
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(
                                  Icons.block_rounded,
                                  color: Color(0xFFDC2626),
                                  size: 18,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Account Suspended',
                                        style: TextStyle(
                                          color: Color(0xFFDC2626),
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        userData['blockReason'] != null
                                            ? 'Reason: ${userData['blockReason']}'
                                            : 'You have 3 consecutive cancellations.',
                                        style: const TextStyle(
                                          color: Color(0xFFDC2626),
                                          fontSize: 12,
                                        ),
                                      ),
                                      if (userData['blockedUntil'] != null) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          'Suspended until: ${DateFormat('MMM d, yyyy').format((userData['blockedUntil'] as Timestamp).toDate())}',
                                          style: const TextStyle(
                                            color: Color(0xFFDC2626),
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                      const SizedBox(height: 4),
                                      const Text(
                                        'Contact support if you think this is a mistake.',
                                        style: TextStyle(
                                          color: Color(0xFFDC2626),
                                          fontSize: 11,
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // ── ACTIVE TRIPS ──
                        if (activeTrips.isNotEmpty) ...[
                          _sectionLabel("Active Trip"),
                          const SizedBox(height: 10),
                          ...activeTrips.map((trip) {
                            final tripId =
                                trip['assigned_driver_id'] ??
                                trip['pickupLocation'] ??
                                '';
                            _loadEta(trip);

                            final eta = _etaCache[tripId];
                            final isLoadingEta = _etaLoading[tripId] == true;
                            final truckType =
                                (trip['truckType']?['type'] ??
                                        trip['assigned_truck_type'] ??
                                        '')
                                    .toString()
                                    .replaceAll('_', ' ')
                                    .split(' ')
                                    .map(
                                      (w) => w.isEmpty
                                          ? ''
                                          : w[0].toUpperCase() + w.substring(1),
                                    )
                                    .join(' ');
                            final estimatedCost = trip['estimatedCost'];
                            final driverId =
                                trip['assigned_driver_id']?.toString() ?? '';
                            _loadDriverPhone(driverId);

                            final driverPhone =
                                _driverPhoneCache[driverId] ?? '';
                            final driverName =
                                trip['assigned_driver_name']?.toString() ?? '—';
                            final plateNumber =
                                trip['assigned_truck_plate_number']
                                    ?.toString() ??
                                '';

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Container(
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
                                                'Ongoing Delivery',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w700,
                                                  color: Color(0xFF166534),
                                                ),
                                              ),
                                            ],
                                          ),
                                          _statusPill(
                                            trip['status'] ?? 'assigned',
                                          ),
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
                                                            shape:
                                                                BoxShape.circle,
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
                                                            color: Color(
                                                              0xFFDC2626,
                                                            ),
                                                            shape:
                                                                BoxShape.circle,
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
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 2),
                                                    Text(
                                                      trip['pickupLocation'] ??
                                                          '—',
                                                      style: const TextStyle(
                                                        fontSize: 13,
                                                        fontWeight:
                                                            FontWeight.w600,
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
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 2),
                                                    Text(
                                                      trip['destination'] ??
                                                          '—',
                                                      style: const TextStyle(
                                                        fontSize: 13,
                                                        fontWeight:
                                                            FontWeight.w600,
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

                                          // ── ETA + Cost row ──
                                          Row(
                                            children: [
                                              // ETA
                                              Expanded(
                                                child: Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 10,
                                                        vertical: 8,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: const Color(
                                                      0xFFFFF7ED,
                                                    ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          10,
                                                        ),
                                                  ),
                                                  child: Row(
                                                    children: [
                                                      const Icon(
                                                        Icons.schedule_rounded,
                                                        size: 14,
                                                        color: Color(
                                                          0xFFC2410C,
                                                        ),
                                                      ),
                                                      const SizedBox(width: 6),
                                                      Column(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        children: [
                                                          const Text(
                                                            'ETA',
                                                            style: TextStyle(
                                                              fontSize: 10,
                                                              color: Color(
                                                                0xFF9A3412,
                                                              ),
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600,
                                                              letterSpacing:
                                                                  0.4,
                                                            ),
                                                          ),
                                                          const SizedBox(
                                                            height: 1,
                                                          ),
                                                          if (isLoadingEta)
                                                            const SizedBox(
                                                              width: 12,
                                                              height: 12,
                                                              child:
                                                                  CircularProgressIndicator(
                                                                    strokeWidth:
                                                                        1.5,
                                                                    color: Color(
                                                                      0xFFF97316,
                                                                    ),
                                                                  ),
                                                            )
                                                          else
                                                            Text(
                                                              eta ?? '—',
                                                              style: const TextStyle(
                                                                fontSize: 13,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w700,
                                                                color: Color(
                                                                  0xFFC2410C,
                                                                ),
                                                              ),
                                                            ),
                                                        ],
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),

                                              // Cost
                                              if (estimatedCost != null) ...[
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: Container(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 10,
                                                          vertical: 8,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color: const Color(
                                                        0xFFF0FDF4,
                                                      ),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            10,
                                                          ),
                                                    ),
                                                    child: Row(
                                                      children: [
                                                        const Icon(
                                                          Icons
                                                              .receipt_long_rounded,
                                                          size: 14,
                                                          color: _green,
                                                        ),
                                                        const SizedBox(
                                                          width: 6,
                                                        ),
                                                        Column(
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment
                                                                  .start,
                                                          children: [
                                                            const Text(
                                                              'EST. COST',
                                                              style: TextStyle(
                                                                fontSize: 10,
                                                                color: Color(
                                                                  0xFF166534,
                                                                ),
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600,
                                                                letterSpacing:
                                                                    0.4,
                                                              ),
                                                            ),
                                                            const SizedBox(
                                                              height: 1,
                                                            ),
                                                            Text(
                                                              _formatCost(
                                                                estimatedCost,
                                                              ),
                                                              style: const TextStyle(
                                                                fontSize: 13,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w700,
                                                                color: _green,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),

                                          const SizedBox(height: 12),
                                          Container(height: 1, color: _border),
                                          const SizedBox(height: 12),

                                          // ── Driver row ──
                                          if (trip['status'] == 'approved' &&
                                              trip['needs_reassignment'] ==
                                                  true) ...[
                                            Container(
                                              padding: const EdgeInsets.all(12),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFFEF3C7),
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                                border: Border.all(
                                                  color: const Color(
                                                    0xFFFDE68A,
                                                  ),
                                                ),
                                              ),
                                              child: const Row(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Icon(
                                                    Icons.info_outline_rounded,
                                                    size: 15,
                                                    color: Color(0xFF92400E),
                                                  ),
                                                  SizedBox(width: 8),
                                                  Expanded(
                                                    child: Text(
                                                      'Your previous driver rejected the trip. A new driver is being assigned, please wait.',
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        color: Color(
                                                          0xFF92400E,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ] else if (trip['status'] ==
                                              'approved') ...[
                                            Container(
                                              padding: const EdgeInsets.all(12),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFEFF6FF),
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                                border: Border.all(
                                                  color: const Color(
                                                    0xFFBFDBFE,
                                                  ),
                                                ),
                                              ),
                                              child: const Row(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Icon(
                                                    Icons.hourglass_top_rounded,
                                                    size: 15,
                                                    color: Color(0xFF1E40AF),
                                                  ),
                                                  SizedBox(width: 8),
                                                  Expanded(
                                                    child: Text(
                                                      'Your booking is approved. A driver is being assigned, please wait.',
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        color: Color(
                                                          0xFF1E40AF,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ] else ...[
                                            Row(
                                              children: [
                                                Container(
                                                  width: 38,
                                                  height: 38,
                                                  decoration:
                                                      const BoxDecoration(
                                                        color: Color(
                                                          0xFFDCFCE7,
                                                        ),
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
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(
                                                        driverName,
                                                        style: const TextStyle(
                                                          fontSize: 13,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          color: _textPrimary,
                                                        ),
                                                      ),
                                                      if (truckType
                                                              .isNotEmpty ||
                                                          plateNumber
                                                              .isNotEmpty)
                                                        Text(
                                                          [
                                                                truckType,
                                                                plateNumber,
                                                              ]
                                                              .where(
                                                                (s) => s
                                                                    .isNotEmpty,
                                                              )
                                                              .join(' · '),
                                                          style: const TextStyle(
                                                            fontSize: 11,
                                                            color:
                                                                _textSecondary,
                                                          ),
                                                        ),
                                                    ],
                                                  ),
                                                ),
                                                if (driverPhone.isNotEmpty)
                                                  GestureDetector(
                                                    onTap: () =>
                                                        _callPhone(driverPhone),
                                                    child: Container(
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 14,
                                                            vertical: 8,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        color: _green,
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              10,
                                                            ),
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
                                                                  FontWeight
                                                                      .w600,
                                                              color:
                                                                  Colors.white,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                          const SizedBox(height: 8),
                        ],

                        // ── QUICK ACTIONS ──
                        _sectionLabel("Quick Actions"),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: _actionCard(
                                icon: Icons.local_shipping_rounded,
                                label: "Book Truck",
                                sub: "New booking",
                                iconBg: _green,
                                iconColor: Colors.white,
                                cardBg: _green,
                                titleColor: Colors.white,
                                subColor: Colors.white.withOpacity(0.7),
                                borderColor: _green,
                                onTap: () {
                                  final blockedUntil =
                                      userData['blockedUntil'] as Timestamp?;

                                  if (blockedUntil != null &&
                                      DateTime.now().isBefore(
                                        blockedUntil.toDate(),
                                      )) {
                                    final unblockDate = blockedUntil.toDate();
                                    showDialog(
                                      context: context,
                                      builder: (_) => AlertDialog(
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                        ),
                                        title: const Row(
                                          children: [
                                            Icon(
                                              Icons.block_rounded,
                                              color: Color(0xFFDC2626),
                                            ),
                                            SizedBox(width: 8),
                                            Text(
                                              'Account Restricted',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w700,
                                                fontSize: 16,
                                              ),
                                            ),
                                          ],
                                        ),
                                        content: Text(
                                          userData['blockReason'] != null
                                              ? 'Your account has been suspended by admin.\n\n'
                                                    'Reason: ${userData['blockReason']}\n\n'
                                                    'Suspended until ${unblockDate.day}/${unblockDate.month}/${unblockDate.year}.\n\n'
                                                    'Contact support if you think this is a mistake.'
                                              : 'You have cancelled 3 bookings consecutively.\n\n'
                                                    'Your booking privileges are suspended until '
                                                    '${unblockDate.day}/${unblockDate.month}/${unblockDate.year}.\n\n'
                                                    'Contact support if you think this is a mistake.',
                                          style: const TextStyle(
                                            fontSize: 13,
                                            color: Color(0xFF64748B),
                                          ),
                                        ),
                                        actions: [
                                          ElevatedButton(
                                            onPressed: () =>
                                                Navigator.pop(context),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: const Color(
                                                0xFFDC2626,
                                              ),
                                              foregroundColor: Colors.white,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                            ),
                                            child: const Text('Understood'),
                                          ),
                                        ],
                                      ),
                                    );
                                    return;
                                  }

                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const BookTruckScreen(),
                                    ),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _actionCard(
                                icon: Icons.list_alt_rounded,
                                label: "My Bookings",
                                sub: "View all",
                                iconBg: const Color(0xFFF0FDF4),
                                iconColor: _green,
                                onTap: () => widget.onTabChange?.call(1),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: _actionCard(
                                icon: Icons.location_on_rounded,
                                label: "Track Shipment",
                                sub: "Live location",
                                iconBg: const Color(0xFFEFF6FF),
                                iconColor: const Color(0xFF3B82F6),
                                onTap: () => widget.onTabChange?.call(2),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _actionCard(
                                icon: Icons.headset_mic_rounded,
                                label: "Support",
                                sub: "Get help",
                                iconBg: const Color(0xFFFFF7ED),
                                iconColor: const Color(0xFFF97316),
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const SupportScreen(),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // ── RECENT BOOKINGS ──
                        if (recentBookings.isNotEmpty) ...[
                          _sectionLabel("Recent Bookings"),
                          const SizedBox(height: 10),
                          ...recentBookings.map((booking) {
                            final status = booking['status'] ?? 'pending';
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: _border),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 36,
                                      height: 36,
                                      decoration: BoxDecoration(
                                        color: _surface,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: _border),
                                      ),
                                      child: const Icon(
                                        Icons.local_shipping_rounded,
                                        size: 18,
                                        color: _textSecondary,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            "${booking['pickupLocation'] ?? booking['pickup'] ?? '?'} → ${booking['destination'] ?? '?'}",
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: _textPrimary,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            booking['truckType']?['type'] ??
                                                'Truck',
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: _textSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    _statusPill(status),
                                  ],
                                ),
                              ),
                            );
                          }),
                        ],

                        // ── EMPTY STATE ──
                        if (total == 0)
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
                                  "No bookings yet",
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: _textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                  "Book your first truck to get started",
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: _textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
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

  // ── Hero stat cell ──
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
            ),
          ],
        ),
      ),
    );
  }

  // ── Section label ──
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

  // ── Status pill ──
  Widget _statusPill(String status) {
    Color bg;
    Color text;
    String label;

    switch (status) {
      case 'pending':
        bg = const Color(0xFFFEF3C7);
        text = const Color(0xFFF59E0B);
        label = 'Pending';
        break;
      case 'approved':
        bg = const Color(0xFFDBEAFE);
        text = const Color.fromARGB(255, 86, 92, 255);
        label = 'Approved';
        break;
      case 'assigned':
        bg = const Color(0xFFDBEAFE);
        text = const Color(0xFF1E40AF);
        label = 'Assigned';
        break;
      case 'accepted':
        bg = const Color(0xFFEFF6FF);
        text = const Color(0xFF3B82F6);
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
