import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'customer_dashboard.dart';
import 'my_bookings_screen.dart';
import 'tracking_screen.dart';
import 'profile_screen.dart';

class MainScreen extends StatefulWidget {
  final int initialIndex;
  const MainScreen({
    super.key,
    this.initialIndex = 0, // ← defaults to Home tab
  });

  @override
  State<MainScreen> createState() => _MainScreenState();
}

// ── Tracking tab — finds active booking automatically ──
// ── Tracking tab — finds active booking automatically ──
class TrackingTabScreen extends StatelessWidget {
  const TrackingTabScreen({super.key});

  static const _green = Color(0xFF16A34A);
  static const _textPrimary = Color(0xFF0F172A);
  static const _textSecondary = Color(0xFF64748B);
  static const _surface = Color(0xFFF8FAFC);
  static const _border = Color(0xFFE2E8F0);

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: _surface,
      body: CustomScrollView(
        slivers: [
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
              'Track Shipment',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: _textPrimary,
              ),
            ),
          ),
          SliverFillRemaining(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('bookings')
                  .where('userId', isEqualTo: user?.uid)
                  .where(
                    'status',
                    whereIn: [
                      'assigned',
                      'accepted', // ← ADD
                      'en_route_to_pickup', // ← ADD
                      'arrived_at_pickup', // ← ADD
                      'in_transit',
                    ],
                  )
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: _green),
                  );
                }

                final docs = snapshot.data?.docs ?? [];

                if (docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            color: _surface,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: _border),
                          ),
                          child: const Icon(
                            Icons.location_off_rounded,
                            size: 36,
                            color: _textSecondary,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'No active shipments',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: _textPrimary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Tracking is available once a driver\nhas been assigned to your booking.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            color: _textSecondary,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(20),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final status = data['status'] ?? '';

                    // ── status display config ──
                    Color iconBg;
                    Color iconColor;
                    Color pillBg;
                    Color pillColor;
                    IconData statusIcon;
                    String statusLabel;

                    switch (status) {
                      case 'accepted':
                        iconBg = const Color(0xFFCFFAFE);
                        iconColor = const Color(0xFF0891B2);
                        pillBg = const Color(0xFFCFFAFE);
                        pillColor = const Color(0xFF0891B2);
                        statusIcon = Icons.check_rounded;
                        statusLabel = 'Driver Accepted';
                        break;
                      case 'en_route_to_pickup':
                        iconBg = const Color(0xFFFEF3C7);
                        iconColor = const Color(0xFFF59E0B);
                        pillBg = const Color(0xFFFEF3C7);
                        pillColor = const Color(0xFF92400E);
                        statusIcon = Icons.navigation_rounded;
                        statusLabel = 'En Route to Pickup';
                        break;
                      case 'arrived_at_pickup':
                        iconBg = const Color(0xFFFFF7ED);
                        iconColor = const Color(0xFFF97316);
                        pillBg = const Color(0xFFFFF7ED);
                        pillColor = const Color(0xFFF97316);
                        statusIcon = Icons.location_on_rounded;
                        statusLabel = 'Arrived at Pickup';
                        break;
                      case 'in_transit':
                        iconBg = const Color(0xFFEDE9FE);
                        iconColor = const Color(0xFF7C3AED);
                        pillBg = const Color(0xFFEDE9FE);
                        pillColor = const Color(0xFF7C3AED);
                        statusIcon = Icons.local_shipping_rounded;
                        statusLabel = 'In Transit';
                        break;
                      default: // 'assigned'
                        iconBg = const Color(0xFFDCFCE7);
                        iconColor = _green;
                        pillBg = const Color(0xFFDCFCE7);
                        pillColor = _green;
                        statusIcon = Icons.assignment_ind_rounded;
                        statusLabel = 'Driver Assigned';
                    }

                    return GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => TrackingScreen(bookingId: doc.id),
                        ),
                      ),
                      child: Container(
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
                                color: iconBg,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                statusIcon,
                                color: iconColor,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${data['pickupLocation'] ?? '?'} → ${data['destination'] ?? '?'}',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: _textPrimary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: pillBg,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      statusLabel,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: pillColor,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.chevron_right_rounded,
                              color: _textSecondary,
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _MainScreenState extends State<MainScreen> {
  // ── color tokens (matches dashboard) ──
  static const _green = Color(0xFF16A34A);
  static const _textSecondary = Color(0xFF64748B);
  static const _border = Color(0xFFE2E8F0);

  int currentIndex = 0;

  late final List<Widget> screens;

  @override
  void initState() {
    super.initState();
    currentIndex = widget.initialIndex; // ← use it here
    screens = [
      CustomerDashboard(
        onTabChange: (index) => setState(() => currentIndex = index),
      ),
      const MyBookingsScreen(),
      const TrackingTabScreen(), // ← replace TrackingScreen() with this
      const ProfileScreen(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        // ← CHANGE THIS
        index: currentIndex, // ← from: screens[currentIndex]
        children: screens,
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBottomNav() {
    const items = [
      _NavItem(icon: Icons.home_rounded, label: "Home"),
      _NavItem(icon: Icons.list_alt_rounded, label: "Bookings"),
      _NavItem(icon: Icons.location_on_rounded, label: "Track"),
      _NavItem(icon: Icons.person_rounded, label: "Profile"),
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: _border, width: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          child: Row(
            children: List.generate(items.length, (index) {
              final isActive = currentIndex == index;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => currentIndex = index),
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    decoration: BoxDecoration(
                      color: isActive
                          ? _green.withOpacity(0.08)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isActive)
                          Container(
                            width: 4,
                            height: 4,
                            margin: const EdgeInsets.only(bottom: 2),
                            decoration: const BoxDecoration(
                              color: _green,
                              shape: BoxShape.circle,
                            ),
                          )
                        else
                          const SizedBox(height: 6),
                        Icon(
                          items[index].icon,
                          size: 20,
                          color: isActive ? _green : _textSecondary,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          items[index].label,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: isActive
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: isActive ? _green : _textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

// ── simple data class for nav items ──
class _NavItem {
  final IconData icon;
  final String label;
  const _NavItem({required this.icon, required this.label});
}
