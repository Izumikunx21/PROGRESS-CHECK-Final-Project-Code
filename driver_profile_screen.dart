import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

import '../../services/auth_service.dart';
import '../auth/login_screen.dart';
import '../customer/edit_profile_screen.dart';
import 'driver_jobs_screen.dart';
import 'driver_trip_history_screen.dart';
import 'driver_reviews_screen.dart';
import '../customer/support_screen.dart';
import '../customer/help_center_screen.dart';

class DriverProfileScreen extends StatefulWidget {
  const DriverProfileScreen({super.key});

  @override
  State<DriverProfileScreen> createState() => _DriverProfileScreenState();
}

// ── FIX 1: add AutomaticKeepAliveClientMixin ──
class _DriverProfileScreenState extends State<DriverProfileScreen>
    with AutomaticKeepAliveClientMixin {
  static const _green = Color(0xFF16A34A);
  static const _textPrimary = Color(0xFF0F172A);
  static const _textSecondary = Color(0xFF64748B);
  static const _surface = Color(0xFFF8FAFC);
  static const _border = Color(0xFFE2E8F0);
  static const _red = Color(0xFFDC2626);
  static const _amber = Color(0xFFF59E0B);

  // ── FIX 1: required by AutomaticKeepAliveClientMixin ──
  @override
  bool get wantKeepAlive => true;

  // ── FIX 2: static flag so reset only runs once per day ──
  static DateTime? _lastEarningsReset;

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      if (_lastEarningsReset == null || _lastEarningsReset!.isBefore(today)) {
        _lastEarningsReset = now;
        _resetStaleEarnings(user.uid);
      }
    }
  }

  Future<void> _resetStaleEarnings(String driverId) async {
    final driverRef = FirebaseFirestore.instance
        .collection('users')
        .doc(driverId);
    final snap = await driverRef.get();
    final data = snap.data() ?? {};

    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final startOfMonth = DateTime(now.year, now.month, 1);

    final lastEarningRaw = data['lastEarningDate'] as Timestamp?;
    final lastEarning = lastEarningRaw?.toDate();

    final Map<String, dynamic> updates = {};

    if (lastEarning == null || lastEarning.isBefore(startOfDay)) {
      updates['earningsToday'] = 0;
    }
    if (lastEarning == null || lastEarning.isBefore(startOfWeek)) {
      updates['earningsWeek'] = 0;
    }
    if (lastEarning == null || lastEarning.isBefore(startOfMonth)) {
      updates['earningsMonth'] = 0;
    }

    if (updates.isNotEmpty) {
      await driverRef.update(updates);
    }
  }

  @override
  Widget build(BuildContext context) {
    // ── FIX 1: required call for AutomaticKeepAliveClientMixin ──
    super.build(context);

    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: _surface,
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user!.uid)
            .snapshots(),
        builder: (context, snapshot) {
          // ── FIX 3: guard empty snapshot to avoid initial flash ──
          if (!snapshot.hasData || snapshot.data?.data() == null) {
            return const Center(
              child: CircularProgressIndicator(color: _green),
            );
          }

          final userData =
              (snapshot.data?.data() as Map<String, dynamic>?) ?? {};

          final name = userData['fullName'] ?? userData['name'] ?? 'Driver';
          final email = userData['email']?.toString().isNotEmpty == true
              ? userData['email'].toString()
              : user.email ?? '';
          final phone = userData['phone'] ?? '';
          final profileImage = userData['profileImage'];
          final availability = userData['availability'] ?? 'available';
          final ratingAvg = (userData['rating_average'] ?? 0.0).toDouble();
          final truckId = userData['assigned_truck_id'];
          final status = userData['status'] ?? 'active';

          final totalJobs = (userData['totalJobs'] ?? 0) as int;
          final completedJobs = (userData['completedJobs'] ?? 0) as int;

          // ── earnings ──
          final earningsToday = (userData['earningsToday'] ?? 0.0) as num;
          final earningsWeek = (userData['earningsWeek'] ?? 0.0) as num;
          final earningsMonth = (userData['earningsMonth'] ?? 0.0) as num;

          // ── acceptance rate ──
          final acceptanceRate = totalJobs > 0
              ? ((completedJobs / totalJobs) * 100).round()
              : 0;

          // ── performance badge ──
          String performanceBadge = '';
          Color badgeColor = _textSecondary;
          if (ratingAvg >= 4.8 && completedJobs >= 50) {
            performanceBadge = '🏆 Top Driver';
            badgeColor = const Color(0xFFF59E0B);
          } else if (ratingAvg >= 4.5) {
            performanceBadge = '⭐ 5-Star Driver';
            badgeColor = _green;
          } else if (completedJobs < 5) {
            performanceBadge = '🆕 New Driver';
            badgeColor = const Color(0xFF3B82F6);
          }

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
                title: const Text(
                  'Profile',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: _textPrimary,
                  ),
                ),
              ),

              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    // ── SUSPENSION BANNER ──
                    if (status == 'blocked') ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEE2E2),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFFCA5A5)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.block_rounded,
                              color: _red,
                              size: 18,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Account Suspended',
                                    style: TextStyle(
                                      color: _red,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    userData['blockReason'] != null
                                        ? 'Reason: ${userData['blockReason']}'
                                        : 'Your account has been suspended by admin.',
                                    style: const TextStyle(
                                      color: _red,
                                      fontSize: 12,
                                    ),
                                  ),
                                  if (userData['blockedUntil'] != null) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      'Until: ${DateFormat('MMM d, yyyy').format((userData['blockedUntil'] as Timestamp).toDate())}',
                                      style: const TextStyle(
                                        color: _red,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 4),
                                  const Text(
                                    'Contact support if you think this is a mistake.',
                                    style: TextStyle(
                                      color: _red,
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

                    // ── PROFILE HEADER CARD ──
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: _textPrimary,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 64,
                                height: 64,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.2),
                                    width: 2,
                                  ),
                                ),
                                child: ClipOval(
                                  child:
                                      profileImage != null &&
                                          profileImage.toString().isNotEmpty
                                      ? Image.network(
                                          profileImage.toString(),
                                          fit: BoxFit.cover,
                                        )
                                      : Container(
                                          color: _green.withOpacity(0.2),
                                          child: Center(
                                            child: Text(
                                              _initials(name),
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 22,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                        ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      name,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      email,
                                      style: const TextStyle(
                                        color: Color(0xFF94A3B8),
                                        fontSize: 12,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (phone.isNotEmpty) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        phone,
                                        style: const TextStyle(
                                          color: Color(0xFF94A3B8),
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: _availabilityColor(
                                              availability,
                                            ).withOpacity(0.15),
                                            borderRadius: BorderRadius.circular(
                                              20,
                                            ),
                                            border: Border.all(
                                              color: _availabilityColor(
                                                availability,
                                              ).withOpacity(0.4),
                                            ),
                                          ),
                                          child: Text(
                                            _availabilityLabel(availability),
                                            style: TextStyle(
                                              color: _availabilityColor(
                                                availability,
                                              ),
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                        if (performanceBadge.isNotEmpty) ...[
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: badgeColor.withOpacity(
                                                0.15,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                              border: Border.all(
                                                color: badgeColor.withOpacity(
                                                  0.4,
                                                ),
                                              ),
                                            ),
                                            child: Text(
                                              performanceBadge,
                                              style: TextStyle(
                                                color: badgeColor,
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ── DRIVER STATS ──
                    Row(
                      children: [
                        Expanded(
                          child: _statCard(
                            icon: Icons.local_shipping_outlined,
                            label: 'Total Jobs',
                            value: '$totalJobs',
                            color: _textSecondary,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _statCard(
                            icon: Icons.check_circle_outline_rounded,
                            label: 'Completed',
                            value: '$completedJobs',
                            color: _green,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _statCard(
                            icon: Icons.star_outline_rounded,
                            label: 'Rating',
                            value: ratingAvg > 0
                                ? ratingAvg.toStringAsFixed(1)
                                : '—',
                            color: _amber,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _statCard(
                            icon: Icons.thumb_up_alt_outlined,
                            label: 'Acceptance',
                            value: '$acceptanceRate%',
                            color: const Color(0xFF3B82F6),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // ── EARNINGS CARD ──
                    _sectionLabel('EARNINGS'),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'EARNINGS SUMMARY',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Color(0xFF94A3B8),
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.8,
                                ),
                              ),
                              Text(
                                DateFormat('MMMM yyyy').format(DateTime.now()),
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Color(0xFF64748B),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              _earningCell(
                                label: 'Today',
                                amount: earningsToday.toDouble(),
                                color: const Color(0xFF4ADE80),
                              ),
                              _verticalDivider(),
                              _earningCell(
                                label: 'This Week',
                                amount: earningsWeek.toDouble(),
                                color: const Color(0xFF60A5FA),
                              ),
                              _verticalDivider(),
                              _earningCell(
                                label: 'This Month',
                                amount: earningsMonth.toDouble(),
                                color: const Color(0xFFA78BFA),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ── ASSIGNED TRUCK ──
                    if (truckId != null && truckId.toString().isNotEmpty) ...[
                      StreamBuilder<DocumentSnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('trucks')
                            .doc(truckId)
                            .snapshots(),
                        builder: (context, truckSnap) {
                          if (!truckSnap.hasData || !truckSnap.data!.exists) {
                            return const SizedBox();
                          }
                          final truck =
                              truckSnap.data!.data() as Map<String, dynamic>?;
                          if (truck == null) return const SizedBox();

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _sectionLabel('ASSIGNED TRUCK'),
                              const SizedBox(height: 10),
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: _border),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.03),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        color: _surface,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: _border),
                                      ),
                                      child: const Icon(
                                        Icons.local_shipping_rounded,
                                        size: 22,
                                        color: _textSecondary,
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            truck['plate_number'] ?? 'N/A',
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w700,
                                              color: _textPrimary,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            [
                                                  truck['truck_type'],
                                                  truck['model'],
                                                ]
                                                .where(
                                                  (v) =>
                                                      v != null &&
                                                      v.toString().isNotEmpty,
                                                )
                                                .join(' · '),
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: _textSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _green.withOpacity(0.08),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: _green.withOpacity(0.3),
                                        ),
                                      ),
                                      child: Text(
                                        truck['status'] ?? 'Active',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: _green,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 20),
                            ],
                          );
                        },
                      ),
                    ] else ...[
                      _sectionLabel('ASSIGNED TRUCK'),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFFBEB),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFFCD34D)),
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              Icons.warning_amber_rounded,
                              color: Color(0xFFF59E0B),
                              size: 20,
                            ),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'No truck assigned yet. Contact your admin.',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF92400E),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // ── ACTIVITY ──
                    _sectionLabel('ACTIVITY'),
                    const SizedBox(height: 10),
                    _menuCard(
                      children: [
                        _menuTile(
                          icon: Icons.local_shipping_outlined,
                          label: 'My Jobs',
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const DriverJobsScreen(),
                            ),
                          ),
                        ),
                        _divider(),
                        _menuTile(
                          icon: Icons.history_rounded,
                          label: 'Trip History',
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const DriverTripHistoryScreen(),
                            ),
                          ),
                        ),
                        _divider(),
                        _menuTile(
                          icon: Icons.star_outline_rounded,
                          label: 'My Reviews',
                          trailing: ratingAvg > 0
                              ? _ratingChip(ratingAvg)
                              : null,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const DriverReviewsScreen(),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // ── ACCOUNT ──
                    _sectionLabel('ACCOUNT'),
                    const SizedBox(height: 10),
                    _menuCard(
                      children: [
                        _menuTile(
                          icon: Icons.person_outline_rounded,
                          label: 'Edit Profile',
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const EditProfileScreen(),
                            ),
                          ),
                        ),
                        _divider(),
                        _menuTile(
                          icon: Icons.lock_outline_rounded,
                          label: 'Change Password',
                          onTap: () {},
                        ),
                        _divider(),
                        _menuTile(
                          icon: Icons.notifications_outlined,
                          label: 'Notification Settings',
                          onTap: () {},
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // ── SUPPORT ──
                    _sectionLabel('SUPPORT'),
                    const SizedBox(height: 10),
                    _menuCard(
                      children: [
                        _menuTile(
                          icon: Icons.help_outline_rounded,
                          label: 'Help Center',
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  const HelpCenterScreen(role: 'driver'),
                            ),
                          ),
                        ),
                        _divider(),
                        _menuTile(
                          icon: Icons.headset_mic_rounded,
                          label: 'Contact Support',
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const SupportScreen(),
                            ),
                          ),
                        ),
                        _divider(),
                        _menuTile(
                          icon: Icons.info_outline_rounded,
                          label: 'App Version',
                          trailing: const Text(
                            'v1.0.0',
                            style: TextStyle(
                              fontSize: 12,
                              color: _textSecondary,
                            ),
                          ),
                          onTap: () {},
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // ── LOGOUT ──
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: () => _showLogoutDialog(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFEE2E2),
                          foregroundColor: _red,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: const BorderSide(color: Color(0xFFFCA5A5)),
                          ),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.logout_rounded, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Logout',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ]),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ── earning cell ──
  Widget _earningCell({
    required String label,
    required double amount,
    required Color color,
  }) {
    return Expanded(
      child: Column(
        children: [
          Text(
            '₱${NumberFormat('#,##0').format(amount)}',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              color: Color(0xFF94A3B8),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _verticalDivider() =>
      Container(width: 1, height: 36, color: Colors.white.withOpacity(0.08));

  Widget _ratingChip(double rating) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: _amber.withOpacity(0.1),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.star_rounded, size: 12, color: _amber),
        const SizedBox(width: 3),
        Text(
          rating.toStringAsFixed(1),
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: _amber,
          ),
        ),
      ],
    ),
  );

  Color _availabilityColor(String availability) {
    switch (availability) {
      case 'on_trip':
        return _amber;
      case 'available':
        return _green;
      default:
        return _textSecondary;
    }
  }

  String _availabilityLabel(String availability) {
    switch (availability) {
      case 'on_trip':
        return 'On Trip';
      case 'available':
        return 'Available';
      default:
        return 'Offline';
    }
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Logout',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Cancel',
              style: TextStyle(color: _textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await AuthService().logout();
              if (context.mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name.isNotEmpty ? name[0].toUpperCase() : 'D';
  }

  Widget _sectionLabel(String text) => Text(
    text,
    style: const TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w700,
      color: _textSecondary,
      letterSpacing: 0.6,
    ),
  );

  Widget _menuCard({required List<Widget> children}) => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: _border),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.03),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: Column(children: children),
  );

  Widget _menuTile({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Widget? trailing,
  }) => ListTile(
    onTap: onTap,
    leading: Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _border),
      ),
      child: Icon(icon, size: 18, color: _textSecondary),
    ),
    title: Text(
      label,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: _textPrimary,
      ),
    ),
    trailing:
        trailing ??
        const Icon(
          Icons.chevron_right_rounded,
          color: _textSecondary,
          size: 20,
        ),
  );

  Widget _divider() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: Container(height: 1, color: _border),
  );

  Widget _statCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: _border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: color,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            fontSize: 9,
            color: _textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    ),
  );
}
