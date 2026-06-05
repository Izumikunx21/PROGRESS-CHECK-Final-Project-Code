import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class TruckSelectionScreen extends StatefulWidget {
  final double distance;
  const TruckSelectionScreen({super.key, this.distance = 5.0});

  @override
  State<TruckSelectionScreen> createState() => _TruckSelectionScreenState();
}

class _TruckSelectionScreenState extends State<TruckSelectionScreen> {
  String? _selectedId;
  Map<String, dynamic>? _selectedData;
  final Map<String, int> _availabilityCache = {};

  static const _green = Color(0xFF16A34A);
  static const _textPrimary = Color(0xFF0F172A);
  static const _textSecondary = Color(0xFF64748B);
  static const _surface = Color(0xFFF8FAFC);
  static const _border = Color(0xFFE2E8F0);

  String _formatTruckType(String type) {
    if (type.trim().isEmpty) return 'Standard Truck';
    return type
        .trim()
        .toLowerCase()
        .replaceAll('-', '_')
        .split('_')
        .where((w) => w.isNotEmpty)
        .map((w) => w[0].toUpperCase() + w.substring(1))
        .join(' ');
  }

  Future<int> _getAvailableCount(String truckType) async {
    if (_availabilityCache.containsKey(truckType)) {
      return _availabilityCache[truckType]!;
    }
    final snapshot = await FirebaseFirestore.instance
        .collection('trucks')
        .where('truck_type', isEqualTo: truckType)
        .where('status', isEqualTo: 'available')
        .count()
        .get();
    final count = snapshot.count ?? 0;
    _availabilityCache[truckType] = count;
    return count;
  }

  // ── Availability badge (refined) ──
  Widget _buildAvailabilityBadge({
    required int count,
    required bool isSelected,
  }) {
    final isAvailable = count > 0;
    final bgColor = isSelected
        ? Colors.white.withOpacity(0.18)
        : isAvailable
        ? _green.withOpacity(0.08)
        : const Color(0xFFF1F5F9);
    final textColor = isSelected
        ? Colors.white
        : isAvailable
        ? _green
        : _textSecondary;
    final label = isAvailable
        ? '$count ${count == 1 ? 'unit' : 'units'} available'
        : 'No units available';
    final icon = isAvailable
        ? Icons.check_circle_rounded
        : Icons.remove_circle_outline_rounded;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: textColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  // ── Single truck card ──
  Widget _buildTruckCard({
    required String docId,
    required Map<String, dynamic> data,
    required int availableCount,
  }) {
    final isSelected = _selectedId == docId;
    final isAvailable = availableCount > 0;
    final canSelect = isAvailable;

    return GestureDetector(
      onTap: canSelect
          ? () => setState(() {
              _selectedId = docId;
              _selectedData = data;
            })
          : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: isSelected ? _green : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? _green : _border,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? _green.withOpacity(0.18)
                  : Colors.black.withOpacity(0.04),
              blurRadius: isSelected ? 14 : 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            // ── Truck image ──
            Container(
              width: 80,
              height: 64,
              decoration: BoxDecoration(
                color: isSelected ? Colors.white.withOpacity(0.12) : _surface,
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.all(8),
              child: Image.asset(
                'assets/wing_van.png',
                fit: BoxFit.contain,
                color: !isAvailable ? Colors.grey : null,
                colorBlendMode: !isAvailable ? BlendMode.saturation : null,
              ),
            ),

            const SizedBox(width: 14),

            // ── Info column ──
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name + check
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _formatTruckType((data['type'] ?? '').toString()),
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: isSelected ? Colors.white : _textPrimary,
                          ),
                        ),
                      ),
                      if (isSelected)
                        const Icon(
                          Icons.check_circle_rounded,
                          color: Colors.white,
                          size: 20,
                        )
                      else if (!isAvailable)
                        const Icon(
                          Icons.block_rounded,
                          color: Color(0xFFCBD5E1),
                          size: 18,
                        ),
                    ],
                  ),

                  const SizedBox(height: 5),

                  // Capacity row
                  Row(
                    children: [
                      Icon(
                        Icons.inventory_2_rounded,
                        size: 12,
                        color: isSelected ? Colors.white70 : _textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        "${data['capacity_tons']}T capacity",
                        style: TextStyle(
                          fontSize: 12,
                          color: isSelected ? Colors.white70 : _textSecondary,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 6),

                  // Availability badge
                  _buildAvailabilityBadge(
                    count: availableCount,
                    isSelected: isSelected,
                  ),

                  const SizedBox(height: 6),

                  // Price
                  Text(
                    "₱${NumberFormat('#,##0.00').format(((data['base_price'] ?? 0) + (widget.distance * (data['per_km'] ?? 0))))} est.  ·  ₱${NumberFormat('#,##0').format(data['per_km'] ?? 0)}/km",
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? Colors.white.withOpacity(0.85)
                          : _green,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Section divider label ──
  Widget _sectionLabel(String text, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 4, 0, 10),
      child: Row(
        children: [
          Text(
            text.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color ?? _textSecondary,
              letterSpacing: 0.7,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              height: 1,
              color: color?.withOpacity(0.2) ?? _border,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
          "Select a Vehicle",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: _textPrimary,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(28),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.only(bottom: 8),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.route_rounded,
                    size: 13,
                    color: _textSecondary,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    "${widget.distance.toStringAsFixed(1)} km estimated distance",
                    style: const TextStyle(
                      fontSize: 12,
                      color: _textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('truck_types')
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF16A34A),
                strokeWidth: 2,
              ),
            );
          }

          final docs = snapshot.data!.docs;

          // ── Build all futures first so we can split into
          //    available / unavailable once data arrives ──
          return FutureBuilder<List<int>>(
            future: Future.wait(
              docs.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return _getAvailableCount((data['type'] ?? '').toString());
              }),
            ),
            builder: (context, countsSnap) {
              // ← show spinner until all counts are ready
              if (!countsSnap.hasData) {
                return const Center(
                  child: CircularProgressIndicator(
                    color: Color(0xFF16A34A),
                    strokeWidth: 2,
                  ),
                );
              }

              final counts = countsSnap.data!;

              // Split into available / unavailable
              final List<_TruckEntry> available = [];
              final List<_TruckEntry> unavailable = [];

              for (int i = 0; i < docs.length; i++) {
                final doc = docs[i];
                final data = doc.data() as Map<String, dynamic>;
                final count = counts[i];
                final entry = _TruckEntry(
                  docId: doc.id,
                  data: data,
                  count: count,
                );
                if (count > 0) {
                  available.add(entry);
                } else {
                  unavailable.add(entry);
                }
              }

              return ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                children: [
                  // ── AVAILABLE SECTION ──
                  if (available.isNotEmpty) ...[
                    _sectionLabel(
                      '${available.length} available',
                      color: _green,
                    ),
                    ...available.map(
                      (e) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _buildTruckCard(
                          docId: e.docId,
                          data: e.data,
                          availableCount: e.count,
                        ),
                      ),
                    ),
                  ],

                  // ── UNAVAILABLE SECTION ──
                  if (unavailable.isNotEmpty) ...[
                    if (available.isNotEmpty) const SizedBox(height: 8),
                    _sectionLabel('Currently unavailable'),
                    ...unavailable.map(
                      (e) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Opacity(
                          opacity: 0.45,
                          child: _buildTruckCard(
                            docId: e.docId,
                            data: e.data,
                            availableCount: 0,
                          ),
                        ),
                      ),
                    ),
                  ],

                  // ── Empty state ──
                  if (available.isEmpty && unavailable.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 60),
                      child: Center(
                        child: Text(
                          'No truck types configured yet.',
                          style: TextStyle(
                            fontSize: 14,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          );
        },
      ),

      // ── Confirm button ──
      bottomNavigationBar: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          12,
          20,
          MediaQuery.of(context).padding.bottom + 16,
        ),
        child: SizedBox(
          height: 52,
          child: ElevatedButton(
            onPressed: _selectedId == null
                ? null
                : () => Navigator.pop(context, {
                    'id': _selectedId!,
                    'data': _selectedData!,
                  }),
            style: ElevatedButton.styleFrom(
              backgroundColor: _green,
              foregroundColor: Colors.white,
              disabledBackgroundColor: const Color(0xFFE2E8F0),
              disabledForegroundColor: _textSecondary,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Text(
              "Select This Vehicle",
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Simple data holder ──
class _TruckEntry {
  final String docId;
  final Map<String, dynamic> data;
  final int count;
  // remove: final bool isLoading;
  const _TruckEntry({
    required this.docId,
    required this.data,
    required this.count,
  });
}
