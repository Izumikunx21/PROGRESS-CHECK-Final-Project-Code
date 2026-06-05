import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'tracking_screen.dart';

class BookingDetailsScreen extends StatelessWidget {
  final String bookingId;

  const BookingDetailsScreen({super.key, required this.bookingId});

  // ── color tokens ──
  static const _green = Color(0xFF16A34A);
  static const _textPrimary = Color(0xFF0F172A);
  static const _textSecondary = Color(0xFF64748B);
  static const _surface = Color(0xFFF8FAFC);
  static const _border = Color(0xFFE2E8F0);
  static const _red = Color(0xFFDC2626);

  Stream<DocumentSnapshot> getBookingStream() {
    return FirebaseFirestore.instance
        .collection('bookings')
        .doc(bookingId)
        .snapshots();
  }

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
          'label': 'Driver Assigned',
        };
      case 'accepted':
        return {
          'color': const Color(0xFF0891B2),
          'bg': const Color(0xFFCFFAFE),
          'icon': Icons.check_rounded,
          'label': 'Trip Accepted',
        };

      // ── add to _statusConfig() ──
      case 'en_route_to_pickup':
        return {
          'color': const Color(0xFFF59E0B),
          'bg': const Color(0xFFFEF3C7),
          'icon': Icons.navigation_rounded,
          'label': 'En Route to Pickup',
        };
      case 'arrived_at_pickup':
        return {
          'color': const Color(0xFFF97316),
          'bg': const Color(0xFFFFF7ED),
          'icon': Icons.location_on_rounded,
          'label': 'Arrived at Pickup',
        };
      case 'delivered':
        return {
          'color': _green,
          'bg': const Color(0xFFDCFCE7),
          'icon': Icons.check_circle_rounded,
          'label': 'Delivered',
        };

      case 'in_transit':
        return {
          'color': const Color(0xFF7C3AED),
          'bg': const Color(0xFFEDE9FE),
          'icon': Icons.local_shipping_rounded,
          'label': 'In Transit',
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
          'color': _red,
          'bg': const Color(0xFFFEE2E2),
          'icon': Icons.block_rounded,
          'label': 'Rejected',
        };
      case 'cancelled':
        return {
          'color': _red,
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

  String _formatTruckType(String type) {
    if (type.isEmpty) return 'Standard Truck';
    return type
        .replaceAll('_', ' ')
        .split(' ')
        .map((w) => w[0].toUpperCase() + w.substring(1).toLowerCase())
        .join(' ');
  }

  String _formatCost(Map<String, dynamic> data) {
    try {
      if (data['estimatedCost'] != null) {
        return '₱${NumberFormat('#,##0.00').format((data['estimatedCost'] as num).toDouble())}';
      }
      final t = data['truckType'] as Map<String, dynamic>?;
      if (t == null) return '₱0.00';
      final base = (t['base_price'] ?? 0) as num;
      final perKm = (t['per_km'] ?? 0) as num;
      final dist = (data['estimatedDistance'] ?? 5.0) as num;
      return '₱${NumberFormat('#,##0.00').format((base + dist * perKm).toDouble())}';
    } catch (_) {
      return '₱0.00';
    }
  }

  String _statusMessage(String status) {
    switch (status) {
      case 'pending':
        return 'Your booking is waiting for admin approval.';
      case 'approved':
        return 'Approved! A driver will be assigned shortly.';
      case 'assigned':
        return 'A driver has been assigned to your booking.';
      case 'accepted':
        return 'Driver accepted • Heading to pickup location.';
      case 'en_route_to_pickup': // ← ADD HERE
        return 'Driver is heading to your pickup location.';
      case 'arrived_at_pickup': // ← ADD HERE
        return 'Driver has arrived at the pickup location.';
      case 'in_transit':
        return 'Your shipment is currently on the way.';
      case 'delivered': // ← ADD HERE
        return 'Your shipment has been delivered.';
      case 'completed':
        return 'Shipment delivered successfully.';
      default:
        return 'Tap back to see all bookings.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surface,
      body: StreamBuilder<DocumentSnapshot>(
        stream: getBookingStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: _green),
            );
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('Booking not found'));
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final status = data['status'] ?? 'pending';
          final config = _statusConfig(status);
          final cancelledReason = (data['cancelledReason'] ?? '')
              .toString()
              .trim();
          final rejectionReason = (data['rejection_reason'] ?? '')
              .toString()
              .trim();
          final timestamp = data['createdAt'];
          final formattedDate = timestamp is Timestamp
              ? DateFormat('MMM d, yyyy • hh:mm a').format(timestamp.toDate())
              : 'N/A';
          final isTerminal =
              status == 'cancelled' ||
              status == 'rejected' ||
              status == 'completed' ||
              status == 'delivered'; // ← ADD THIS

          return CustomScrollView(
            slivers: [
              // ── AppBar ──
              SliverAppBar(
                pinned: true,
                backgroundColor: Colors.white,
                elevation: 0,
                foregroundColor: _textPrimary,
                bottom: PreferredSize(
                  preferredSize: const Size.fromHeight(1),
                  child: Container(height: 1, color: _border),
                ),
                title: const Text(
                  'Booking Details',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: _textPrimary,
                  ),
                ),
              ),

              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    // ── HERO CARD ──
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: _textPrimary,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'BOOKING REF',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Color(0xFF94A3B8),
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '#${bookingId.substring(0, 8).toUpperCase()}',
                                    style: const TextStyle(
                                      fontSize: 20,
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                ],
                              ),
                              // status pill
                              // ── status pill ──
                              Flexible(
                                // ← wrap with Flexible
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: (config['color'] as Color)
                                        .withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: (config['color'] as Color)
                                          .withOpacity(0.3),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        config['icon'] as IconData,
                                        size: 13,
                                        color: config['color'] as Color,
                                      ),
                                      const SizedBox(width: 5),
                                      Flexible(
                                        // ← also wrap Text
                                        child: Text(
                                          config['label'] as String,
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: config['color'] as Color,
                                          ),
                                          overflow: TextOverflow
                                              .ellipsis, // ← truncate if needed
                                          maxLines: 1,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Container(
                            height: 1,
                            color: Colors.white.withOpacity(0.1),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              _heroDetail(
                                Icons.local_shipping_rounded,
                                'Truck',
                                _formatTruckType(
                                  (data['truckType']?['type'] ?? '').toString(),
                                ),
                              ),
                              const SizedBox(width: 20),
                              _heroDetail(
                                Icons.calendar_today_rounded,
                                'Booked',
                                formattedDate.split('•').first.trim(),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ── CANCELLED / REJECTED BANNER ──
                    // ── TERMINAL BANNER ──
                    if (isTerminal) ...[
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color:
                              (status == 'completed' || status == 'delivered')
                              ? const Color(0xFFDCFCE7)
                              : const Color(0xFFFEE2E2),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color:
                                (status == 'completed' || status == 'delivered')
                                ? const Color(0xFF86EFAC)
                                : const Color(0xFFFCA5A5),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              (status == 'completed' || status == 'delivered')
                                  ? Icons.check_circle_rounded
                                  : Icons.info_rounded,
                              color:
                                  (status == 'completed' ||
                                      status == 'delivered')
                                  ? _green
                                  : _red,
                              size: 18,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    status == 'delivered'
                                        ? 'Your shipment has been delivered.' // ← ADD
                                        : status == 'completed'
                                        ? 'Shipment delivered successfully.'
                                        : status == 'cancelled'
                                        ? 'This booking has been cancelled.'
                                        : 'This booking request was rejected.',
                                    style: TextStyle(
                                      color:
                                          (status == 'completed' ||
                                              status == 'delivered')
                                          ? _green // ← FIX
                                          : _red,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                    ),
                                  ),
                                  if ((status == 'cancelled' ||
                                          status == 'rejected') &&
                                      (status == 'cancelled'
                                              ? cancelledReason
                                              : rejectionReason)
                                          .isNotEmpty) ...[
                                    // ← FIX condition
                                    const SizedBox(height: 4),
                                    Text(
                                      'Reason: ${status == 'cancelled' ? cancelledReason : rejectionReason}',
                                      style: const TextStyle(
                                        color: _red,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // ── STATUS UPDATE ──
                    if (!isTerminal) ...[
                      _card(
                        label: 'STATUS UPDATE',
                        icon: Icons.info_outline_rounded,
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: config['bg'] as Color,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                config['icon'] as IconData,
                                color: config['color'] as Color,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    config['label'] as String,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: _textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _statusMessage(status),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: _textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // ── ROUTE CARD ──
                    // ── ROUTE CARD ──
                    _card(
                      label: 'ROUTE',
                      icon: Icons.route_rounded,
                      child: Column(
                        children: [
                          _routeRow(
                            Icons.radio_button_checked,
                            _green,
                            'PICKUP',
                            data['pickupLocation'] ?? '—',
                          ),
                          const SizedBox(
                            height: 12,
                          ), // ← simple spacing, no line
                          _routeRow(
                            Icons.location_on_rounded,
                            _red,
                            'DESTINATION',
                            data['destination'] ?? '—',
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // ── DRIVER CARD ──
                    if (data['assigned_driver_id'] != null)
                      _driverCard(data)
                    else
                      _card(
                        label: 'DRIVER',
                        icon: Icons.person_rounded,
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: _surface,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: _border),
                              ),
                              child: const Icon(
                                Icons.person_outline_rounded,
                                color: _textSecondary,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              'No driver assigned yet',
                              style: TextStyle(
                                color: _textSecondary,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 12),

                    // ── BOOKING INFO ──
                    _card(
                      label: 'BOOKING INFORMATION',
                      icon: Icons.info_outline_rounded,
                      child: Column(
                        children: [
                          _infoRow(
                            'Reference',
                            '#${bookingId.substring(0, 8).toUpperCase()}',
                          ),
                          _divider(),
                          _infoRow(
                            'Truck Type',
                            _formatTruckType(
                              (data['truckType']?['type'] ?? '').toString(),
                            ),
                          ),
                          _divider(),
                          _infoRow(
                            'Capacity',
                            '${(data['truckType']?['capacity_tons'] ?? 'N/A')} tons',
                          ),
                          _divider(),
                          _infoRow('Est. Cost', _formatCost(data)),
                          _divider(),
                          _infoRow(
                            // ✅ ADD
                            'Distance',
                            '${(data['estimatedDistance'] ?? 0).toStringAsFixed(1)} km',
                          ),
                          _divider(),
                          _infoRow('Payment', 'Cash on Delivery (COD)'),
                          _divider(),
                          _infoRow(
                            'Schedule',
                            data['schedule'] is Timestamp
                                ? DateFormat('EEE, MMM d • hh:mm a').format(
                                    (data['schedule'] as Timestamp).toDate(),
                                  )
                                : '—',
                          ),
                        ],
                      ),
                    ),

                    // ── SPECIAL NOTES ──
                    if (data['notes'] != null &&
                        data['notes'].toString().isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _card(
                        label: 'SPECIAL INSTRUCTIONS',
                        icon: Icons.sticky_note_2_rounded,
                        child: Text(
                          data['notes'].toString(),
                          style: const TextStyle(
                            fontSize: 13,
                            color: _textPrimary,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 20),

                    // ── TRACK BUTTON ──
                    if (status == 'assigned' ||
                        status == 'accepted' ||
                        status == 'en_route_to_pickup' ||
                        status == 'arrived_at_pickup' ||
                        status == 'in_transit')
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton.icon(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  TrackingScreen(bookingId: bookingId),
                            ),
                          ),
                          icon: const Icon(Icons.location_on_rounded),
                          label: const Text(
                            'Track Delivery',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _green,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
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

  // ── Driver card ──
  Widget _driverCard(Map<String, dynamic> data) {
    return _card(
      label: 'DRIVER',
      icon: Icons.person_rounded,
      child: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance
            .collection('users')
            .doc(data['assigned_driver_id'])
            .get(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
              child: SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(strokeWidth: 2, color: _green),
              ),
            );
          }
          if (!snap.hasData || !snap.data!.exists) {
            return const Text(
              'Driver details unavailable',
              style: TextStyle(color: _textSecondary, fontSize: 13),
            );
          }

          final d = snap.data!.data() as Map<String, dynamic>;
          final name = d['name'] ?? d['fullName'] ?? 'N/A';
          final phone = d['phone'] ?? 'N/A';
          final assignedTruckId = data['assigned_truck_id'];

          return Column(
            children: [
              // driver avatar row
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: _green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.person_rounded,
                      color: _green,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: _textPrimary,
                          ),
                        ),
                        Text(
                          phone,
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
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDCFCE7),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Assigned',
                      style: TextStyle(
                        fontSize: 11,
                        color: _green,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),

              if (assignedTruckId != null) ...[
                const SizedBox(height: 12),
                Container(height: 1, color: _border),
                const SizedBox(height: 12),
                FutureBuilder<DocumentSnapshot>(
                  future: FirebaseFirestore.instance
                      .collection('trucks')
                      .doc(assignedTruckId)
                      .get(),
                  builder: (context, truckSnap) {
                    String plate = 'Unknown';
                    if (truckSnap.hasData && truckSnap.data!.exists) {
                      plate =
                          (truckSnap.data!.data()
                              as Map<String, dynamic>)['plate_number'] ??
                          'Unknown';
                    }
                    return Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: _surface,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: _border),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.local_shipping_rounded,
                                size: 14,
                                color: _textSecondary,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                plate,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: _textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  // ── Card wrapper ──
  Widget _card({
    required String label,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
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
          Row(
            children: [
              Icon(icon, size: 14, color: _textSecondary),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: _textSecondary,
                  letterSpacing: 0.6,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  // ── Route row ──
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
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Info row ──
  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: _textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                color: _textPrimary,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider() => Container(height: 1, color: _border);

  // ── Hero detail ──
  Widget _heroDetail(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 14, color: const Color(0xFF94A3B8)),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                color: Color(0xFF94A3B8),
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              value,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
