import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class DriverTripHistoryScreen extends StatefulWidget {
  const DriverTripHistoryScreen({super.key});

  @override
  State<DriverTripHistoryScreen> createState() =>
      _DriverTripHistoryScreenState();
}

class _DriverTripHistoryScreenState extends State<DriverTripHistoryScreen> {
  static const _green = Color(0xFF16A34A);
  static const _textPrimary = Color(0xFF0F172A);
  static const _textSecondary = Color(0xFF64748B);
  static const _surface = Color(0xFFF8FAFC);
  static const _border = Color(0xFFE2E8F0);
  static const _amber = Color(0xFFF59E0B);

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: _surface,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 18,
            color: _textPrimary,
          ),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Text(
          'Trip History',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: _textPrimary,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: _border),
        ),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user!.uid)
            .snapshots(),
        builder: (context, userSnap) {
          final userData =
              (userSnap.data?.data() as Map<String, dynamic>?) ?? {};
          final ratingAvg = (userData['rating_average'] ?? 0.0).toDouble();

          return Column(
            children: [
              // ── Trip list ──
              Expanded(
                child: FutureBuilder<List<QueryDocumentSnapshot>>(
                  future: FirebaseFirestore.instance
                      .collection('bookings')
                      .where('assigned_driver_id', isEqualTo: user.uid)
                      .get()
                      .then((result) => result.docs),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.error_outline_rounded,
                                size: 36,
                                color: Color(0xFFDC2626),
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'Failed to load trips',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                snapshot.error.toString(),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    if (!snapshot.hasData) {
                      return const Center(
                        child: CircularProgressIndicator(color: _green),
                      );
                    }

                    final allDocs = snapshot.data!.toList()
                      ..sort((a, b) {
                        final aTime =
                            (a.data() as Map<String, dynamic>)['createdAt']
                                as Timestamp?;
                        final bTime =
                            (b.data() as Map<String, dynamic>)['createdAt']
                                as Timestamp?;
                        return (bTime?.millisecondsSinceEpoch ?? 0).compareTo(
                          aTime?.millisecondsSinceEpoch ?? 0,
                        );
                      });

                    final docs = allDocs.where((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final status = data['status'] ?? '';
                      return status == 'completed' || status == 'delivered';
                    }).toList();

                    // ── summary totals ──
                    double totalEarnings = 0;
                    int totalCompleted = 0;

                    for (final doc in allDocs) {
                      final data = doc.data() as Map<String, dynamic>;
                      final status = data['status'] ?? '';
                      if (status == 'completed' || status == 'delivered') {
                        totalCompleted++;
                        final cost = data['estimatedCost'] ?? 0;
                        totalEarnings += (cost is int
                            ? cost.toDouble()
                            : (cost as num).toDouble());
                      }
                    }

                    if (docs.isEmpty) return _emptyState();

                    // ── ListView ──
                    return ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
                      itemCount: docs.length + 1,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          return Column(
                            children: [
                              _summaryCard(
                                totalCompleted: totalCompleted,
                                totalEarnings: totalEarnings,
                                ratingAvg: ratingAvg,
                              ),
                              const SizedBox(height: 16),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  '${docs.length} ${docs.length == 1 ? 'trip' : 'trips'} found',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: _textSecondary,
                                    letterSpacing: 0.4,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                            ],
                          );
                        }
                        final doc = docs[index - 1];
                        final data = doc.data() as Map<String, dynamic>;
                        return _tripCard(data);
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ── Summary card ──
  Widget _summaryCard({
    required int totalCompleted,
    required double totalEarnings,
    required double ratingAvg,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          const Row(
            children: [
              Text(
                'OVERALL SUMMARY',
                style: TextStyle(
                  fontSize: 10,
                  color: Color(0xFF94A3B8),
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _summaryCell(
                label: 'Completed',
                value: '$totalCompleted',
                color: const Color(0xFF4ADE80),
              ),
              _summaryDivider(),
              _summaryCell(
                label: 'Total Earned',
                value: '₱${NumberFormat('#,##0').format(totalEarnings)}',
                color: const Color(0xFF60A5FA),
              ),
              _summaryDivider(),
              _summaryCell(
                label: 'Avg Rating',
                value: ratingAvg > 0
                    ? '⭐ ${ratingAvg.toStringAsFixed(1)}'
                    : '—',
                color: const Color(0xFFFBBF24),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryCell({
    required String label,
    required String value,
    required Color color,
  }) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
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

  Widget _summaryDivider() =>
      Container(width: 1, height: 36, color: Colors.white.withOpacity(0.08));

  // ── Trip card ──
  Widget _tripCard(Map<String, dynamic> data) {
    final status = data['status'] ?? '';
    final isCompleted = status == 'completed' || status == 'delivered';

    final pickup = data['pickupLocation'] ?? '—';
    final destination = data['destination'] ?? '—';
    final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
    final cost = data['estimatedCost'];
    final driverRating = data['driverRating'];
    final customerMap = data['customer'] as Map<String, dynamic>?;
    final customerName =
        customerMap?['fullName'] ?? data['userName'] ?? 'Customer';
    final truckType =
        (data['truckType']?['type'] ?? data['assigned_truck_type'] ?? '')
            .toString()
            .replaceAll('_', ' ')
            .split(' ')
            .map((w) => w.isEmpty ? '' : w[0].toUpperCase() + w.substring(1))
            .join(' ');

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCompleted ? const Color(0xFFBBF7D0) : _border,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // ── Header ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: const BoxDecoration(
              color: Color(0xFFF0FDF4),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Row(
                    children: [
                      const Icon(
                        Icons.check_circle_outline_rounded,
                        size: 14,
                        color: _green,
                      ),
                      const SizedBox(width: 5),
                      const Flexible(
                        child: Text(
                          'Completed',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF166534),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                if (createdAt != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    DateFormat('MMM d, yyyy · h:mm a').format(createdAt),
                    style: const TextStyle(fontSize: 11, color: _textSecondary),
                  ),
                ],
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Route ──
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 10, top: 2),
                      child: Column(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: _green,
                              shape: BoxShape.circle,
                            ),
                          ),
                          Container(width: 1.5, height: 28, color: _border),
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Color(0xFFDC2626),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            pickup,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: _textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            destination,
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
                ),

                const SizedBox(height: 12),
                Container(height: 1, color: _border),
                const SizedBox(height: 12),

                // ── Meta row ──
                Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: _surface,
                              shape: BoxShape.circle,
                              border: Border.all(color: _border),
                            ),
                            child: const Icon(
                              Icons.person_rounded,
                              size: 15,
                              color: _textSecondary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'CUSTOMER',
                                  style: TextStyle(
                                    fontSize: 9,
                                    color: _textSecondary,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.4,
                                  ),
                                ),
                                Text(
                                  customerName,
                                  style: const TextStyle(
                                    fontSize: 12,
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
                      ),
                    ),
                    if (truckType.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _surface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: _border),
                        ),
                        child: Text(
                          truckType,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: _textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),

                const SizedBox(height: 12),
                Container(height: 1, color: _border),
                const SizedBox(height: 12),

                // ── Earnings + Rating row ──
                Row(
                  children: [
                    if (cost != null && isCompleted) ...[
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0FDF4),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.account_balance_wallet_outlined,
                                size: 14,
                                color: _green,
                              ),
                              const SizedBox(width: 6),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'EARNINGS',
                                    style: TextStyle(
                                      fontSize: 9,
                                      color: Color(0xFF166534),
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.4,
                                    ),
                                  ),
                                  Text(
                                    '₱${NumberFormat('#,##0.00').format(cost is int ? cost.toDouble() : (cost as num).toDouble())}',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: _green,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: driverRating != null
                              ? const Color(0xFFFFFBEB)
                              : _surface,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: driverRating != null
                                ? _amber.withOpacity(0.3)
                                : _border,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              driverRating != null
                                  ? Icons.star_rounded
                                  : Icons.star_outline_rounded,
                              size: 14,
                              color: driverRating != null
                                  ? _amber
                                  : _textSecondary,
                            ),
                            const SizedBox(width: 6),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'RATING',
                                  style: TextStyle(
                                    fontSize: 9,
                                    color: _textSecondary,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.4,
                                  ),
                                ),
                                driverRating != null
                                    ? Row(
                                        children: List.generate(
                                          5,
                                          (i) => Icon(
                                            i < (driverRating as num).round()
                                                ? Icons.star_rounded
                                                : Icons.star_outline_rounded,
                                            size: 13,
                                            color: _amber,
                                          ),
                                        ),
                                      )
                                    : const Text(
                                        'Not yet rated',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: _textSecondary,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Empty state ──
  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
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
              Icons.history_rounded,
              size: 32,
              color: _textSecondary,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'No trips found',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: _textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Your completed trips will appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: _textSecondary),
          ),
        ],
      ),
    );
  }
}
