import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'show_details_screen.dart';

class MyBookingsScreen extends StatelessWidget {
  const MyBookingsScreen({super.key});

  // ── color tokens (matches dashboard) ──
  static const _green = Color(0xFF16A34A);
  static const _textPrimary = Color(0xFF0F172A);
  static const _textSecondary = Color(0xFF64748B);
  static const _surface = Color(0xFFF8FAFC);
  static const _border = Color(0xFFE2E8F0);

  Stream<QuerySnapshot> getUserBookings() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Stream.empty();
    return FirebaseFirestore.instance
        .collection('bookings')
        .where('userId', isEqualTo: user.uid)
        .snapshots();
  }

  // ── status config ──
  // ── status config ──
  Map<String, dynamic> _statusConfig(String status) {
    switch (status) {
      case 'pending':
        return {
          'color': const Color(0xFFF59E0B),
          'bg': const Color(0xFFFEF3C7),
          'icon': Icons.schedule_rounded,
          'label': 'Pending',
        };
      case 'approved':
        return {
          'color': const Color(0xFF3B82F6),
          'bg': const Color(0xFFDBEAFE),
          'icon': Icons.verified_rounded,
          'label': 'Approved',
        };
      case 'assigned':
      case 'truck_assigned':
        return {
          'color': const Color(0xFF6366F1),
          'bg': const Color(0xFFE0E7FF),
          'icon': Icons.person_rounded,
          'label': 'Assigned',
        };
      case 'accepted':
        return {
          'color': const Color(0xFF0891B2),
          'bg': const Color(0xFFCFFAFE),
          'icon': Icons.check_rounded,
          'label': 'Accepted',
        };
      case 'en_route_to_pickup': // ← ADD
        return {
          'color': const Color(0xFFF59E0B),
          'bg': const Color(0xFFFEF3C7),
          'icon': Icons.navigation_rounded,
          'label': 'En Route',
        };
      case 'arrived_at_pickup': // ← ADD
        return {
          'color': const Color(0xFFF97316),
          'bg': const Color(0xFFFFF7ED),
          'icon': Icons.location_on_rounded,
          'label': 'At Pickup',
        };
      case 'in_transit':
        return {
          'color': const Color(0xFF7C3AED),
          'bg': const Color(0xFFEDE9FE),
          'icon': Icons.local_shipping_rounded,
          'label': 'In Transit',
        };
      case 'delivered': // ← ADD
        return {
          'color': _green,
          'bg': const Color(0xFFDCFCE7),
          'icon': Icons.check_circle_rounded,
          'label': 'Delivered',
        };
      case 'completed':
        return {
          'color': _green,
          'bg': const Color(0xFFDCFCE7),
          'icon': Icons.check_circle_rounded,
          'label': 'Completed',
        };
      case 'rejected':
        return {
          'color': const Color(0xFFDC2626),
          'bg': const Color(0xFFFEE2E2),
          'icon': Icons.block_rounded,
          'label': 'Rejected',
        };
      case 'cancelled':
        return {
          'color': const Color(0xFFDC2626),
          'bg': const Color(0xFFFEE2E2),
          'icon': Icons.cancel_rounded,
          'label': 'Cancelled',
        };
      default:
        return {
          'color': _textSecondary,
          'bg': _surface,
          'icon': Icons.help_outline_rounded,
          'label': 'Unknown',
        };
    }
  }

  String _statusMessage(
    String status,
    String cancelledReason,
    String rejectionReason,
  ) {
    switch (status) {
      case 'pending':
        return 'Swipe right to cancel • Tap for details';
      case 'approved':
        return 'Approved • Waiting for driver assignment';
      case 'assigned':
        return 'Driver assigned • Waiting for response';
      case 'accepted':
        return 'Driver accepted • Preparing for pickup';
      case 'en_route_to_pickup': // ← ADD
        return 'Driver is heading to your pickup location';
      case 'arrived_at_pickup': // ← ADD
        return 'Driver arrived at pickup • Loading cargo';
      case 'in_transit':
        return 'Your shipment is on the way';
      case 'delivered': // ← ADD
        return 'Your shipment has been delivered';
      case 'completed':
        return 'Shipment delivered successfully';
      case 'rejected':
        return rejectionReason.isNotEmpty
            ? 'Rejected • $rejectionReason'
            : 'Booking rejected by admin';
      case 'cancelled':
        return cancelledReason.isNotEmpty
            ? 'Cancelled • $cancelledReason'
            : 'Booking cancelled';
      default:
        return 'Tap for details';
    }
  }

  String _formatTruckType(String type) {
    if (type.isEmpty) return 'Standard Truck';
    return type
        .replaceAll('_', ' ')
        .split(' ')
        .map((w) => w[0].toUpperCase() + w.substring(1).toLowerCase())
        .join(' ');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surface,
      body: CustomScrollView(
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
              'My Bookings',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: _textPrimary,
              ),
            ),
          ),

          // ── List ──
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            sliver: StreamBuilder<QuerySnapshot>(
              stream: getUserBookings(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SliverFillRemaining(
                    child: Center(
                      child: CircularProgressIndicator(color: _green),
                    ),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return SliverFillRemaining(child: _emptyState());
                }

                final bookings = snapshot.data!.docs;
                bookings.sort((a, b) {
                  final aTime =
                      (a['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ??
                      0;
                  final bTime =
                      (b['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ??
                      0;
                  return bTime.compareTo(aTime);
                });

                return SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final doc = bookings[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final status = data['status'] ?? 'pending';
                    final cancelledReason = (data['cancelledReason'] ?? '')
                        .toString()
                        .trim();
                    final rejectionReason = (data['rejection_reason'] ?? '')
                        .toString()
                        .trim();

                    final card = _buildCard(
                      context: context,
                      doc: doc,
                      data: data,
                      status: status,
                      cancelledReason: cancelledReason,
                      rejectionReason: rejectionReason,
                    );

                    if (status == 'pending') {
                      return _swipeable(context, doc, card);
                    }
                    return card;
                  }, childCount: bookings.length),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ── Booking card ──
  Widget _buildCard({
    required BuildContext context,
    required DocumentSnapshot doc,
    required Map<String, dynamic> data,
    required String status,
    required String cancelledReason,
    required String rejectionReason,
  }) {
    final config = _statusConfig(status);
    final Color statusColor = config['color'];
    final Color statusBg = config['bg'];
    final IconData statusIcon = config['icon'];
    final String statusLabel = config['label'];
    final isNegative = status == 'rejected' || status == 'cancelled';

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => BookingDetailsScreen(bookingId: doc.id),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── top row: route + status pill ──
            Row(
              children: [
                Expanded(
                  child: Text(
                    "${data['pickupLocation'] ?? '?'} → ${data['destination'] ?? '?'}",
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: _textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                // ── status pill ──
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 12, color: statusColor),
                      const SizedBox(width: 4),
                      Text(
                        statusLabel,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // ── truck type row ──
            Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: _surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _border),
                  ),
                  child: const Icon(
                    Icons.local_shipping_rounded,
                    size: 14,
                    color: _textSecondary,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _formatTruckType(
                    (data['truckType']?['type'] ?? '').toString(),
                  ),
                  style: const TextStyle(
                    fontSize: 12,
                    color: _textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),
            Container(height: 1, color: _border),
            const SizedBox(height: 10),

            // ── status message ──
            Row(
              children: [
                Icon(
                  isNegative
                      ? Icons.info_outline_rounded
                      : Icons.info_outline_rounded,
                  size: 13,
                  color: isNegative ? const Color(0xFFDC2626) : _textSecondary,
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    _statusMessage(status, cancelledReason, rejectionReason),
                    style: TextStyle(
                      fontSize: 12,
                      color: isNegative
                          ? const Color(0xFFDC2626)
                          : _textSecondary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Swipeable wrapper for pending ──
  Widget _swipeable(BuildContext context, DocumentSnapshot doc, Widget card) {
    return Dismissible(
      key: Key(doc.id),
      direction: DismissDirection.startToEnd,
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(
          color: const Color(0xFFFEE2E2),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFFCA5A5)),
        ),
        child: Row(
          children: const [
            Icon(Icons.cancel_rounded, color: Color(0xFFDC2626), size: 22),
            SizedBox(width: 8),
            Text(
              'Cancel Booking',
              style: TextStyle(
                color: Color(0xFFDC2626),
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
      confirmDismiss: (direction) async {
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) return false;

        // ── check if customer is blocked ──
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        final userData = userDoc.data()!;
        final cancelCount = (userData['cancellationCount'] ?? 0) as int;
        final blockedUntil = userData['blockedUntil'] as Timestamp?;

        // ── show blocked dialog if still blocked ──
        if (blockedUntil != null &&
            DateTime.now().isBefore(blockedUntil.toDate())) {
          final unblockDate = blockedUntil.toDate();
          await showDialog(
            context: context,
            builder: (_) => AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Row(
                children: [
                  Icon(Icons.block_rounded, color: Color(0xFFDC2626)),
                  SizedBox(width: 8),
                  Text(
                    'Account Restricted',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: _textPrimary,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              content: Text(
                userData['blockReason'] != null
                    ? 'Your account has been suspended by admin.\n\nReason: ${userData['blockReason']}\n\nSuspended until ${unblockDate.day}/${unblockDate.month}/${unblockDate.year}.\n\nContact support if you think this is a mistake.'
                    : 'You have cancelled 3 bookings consecutively.\n\nYour booking privileges are suspended until ${unblockDate.day}/${unblockDate.month}/${unblockDate.year}.\n\nContact support if you think this is a mistake.',
                style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
              ),
              actions: [
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFDC2626),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text('Understood'),
                ),
              ],
            ),
          );
          return false;
        }

        // ── normal cancel dialog (your existing code) ──
        final reasonController = TextEditingController();
        final result = await showDialog<bool?>(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text(
              'Cancel Booking',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: _textPrimary,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Please provide a reason (optional):',
                  style: TextStyle(fontSize: 13, color: _textSecondary),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: reasonController,
                  decoration: InputDecoration(
                    hintText: 'Enter reason...',
                    hintStyle: const TextStyle(color: _textSecondary),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: _border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: _green),
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text(
                  'Keep Booking',
                  style: TextStyle(color: _textSecondary),
                ),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFDC2626),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text('Yes, Cancel'),
              ),
            ],
          ),
        );

        if (result == true) {
          final newCount = cancelCount + 1;

          await FirebaseFirestore.instance
              .collection('bookings')
              .doc(doc.id)
              .update({
                'status': 'cancelled',
                'cancelledAt': FieldValue.serverTimestamp(),
                'cancelledReason': reasonController.text.trim(),
              });

          // ── update count + block if hit 3 ──
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .update({
                'cancellationCount': newCount,
                if (newCount >= 3) ...{
                  'blockedUntil': Timestamp.fromDate(
                    DateTime.now().add(const Duration(days: 30)),
                  ),
                  'status': 'blocked', // ← add this
                },
              });
        }

        return result ?? false;
      },

      onDismissed: (_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Booking cancelled'),
            backgroundColor: const Color(0xFFDC2626),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      },
      child: card,
    );
  }

  // ── Empty state ──
  Widget _emptyState() {
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
              Icons.local_shipping_outlined,
              size: 36,
              color: _textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'No bookings yet',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: _textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Book your first truck to get started',
            style: TextStyle(fontSize: 13, color: _textSecondary),
          ),
        ],
      ),
    );
  }
}
