import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../customer/location_search_screen.dart';
import '../../widgets/booking_map.dart';
import '../customer/truck_selection_screen.dart';
import 'success_screen.dart';

class BookTruckScreen extends StatefulWidget {
  const BookTruckScreen({super.key});

  @override
  State<BookTruckScreen> createState() => _BookTruckScreenState();
}

class _BookTruckScreenState extends State<BookTruckScreen> {
  // ── color tokens ──
  static const _green = Color(0xFF16A34A);
  static const _red = Color(0xFFDC2626);
  static const _surface = Color(0xFFF8FAFC);
  static const _textPrimary = Color(0xFF0F172A);
  static const _textSecondary = Color(0xFF64748B);
  static const _border = Color(0xFFE2E8F0);

  // ── controllers ──
  final _pickupController = TextEditingController();
  final _destinationController = TextEditingController();
  final _notesController = TextEditingController();
  final _alternateContactController = TextEditingController();

  // ── location state ──
  double? _pickupLat, _pickupLng;
  double? _destLat, _destLng;
  double _distance = 0.0;

  // ── booking state ──
  DateTime? _schedule;
  String? _selectedTruckId;
  Map<String, dynamic>? _selectedTruck;
  bool _isLoading = false;

  // ── computed price (single source of truth) ──
  double get _price {
    if (_selectedTruck == null) return 0;
    if (_distance == 0.0) return 0; // ← no distance yet
    final base = (_selectedTruck!['base_price'] ?? 0) as num;
    final perKm = (_selectedTruck!['per_km'] ?? 0) as num;
    return base.toDouble() + (_distance * perKm.toDouble());
  }

  @override
  void dispose() {
    _pickupController.dispose();
    _destinationController.dispose();
    _notesController.dispose();
    _alternateContactController.dispose();
    super.dispose();
  }

  // ── pick date/time ──
  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime(2030),
      initialDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(
          ctx,
        ).copyWith(colorScheme: const ColorScheme.light(primary: _green)),
        child: child!,
      ),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(
          ctx,
        ).copyWith(colorScheme: const ColorScheme.light(primary: _green)),
        child: child!,
      ),
    );
    if (time == null || !mounted) return;

    setState(() {
      _schedule = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  // ── select vehicle ──
  Future<void> _selectVehicle() async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => TruckSelectionScreen(
          distance: _distance, // ← pass real distance
        ),
      ),
    );
    if (result != null && mounted) {
      setState(() {
        _selectedTruckId = result['id'];
        _selectedTruck = result['data'];
      });
    }
  }

  // ── open pickup search ──
  Future<void> _openPickupSearch() async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => const LocationSearchScreen(type: 'pickup'),
      ),
    );
    if (result != null && mounted) {
      setState(() {
        _pickupController.text = result['description'];
        _pickupLat = result['lat'];
        _pickupLng = result['lng'];
        // reset truck selection if route changes
        _selectedTruck = null;
        _selectedTruckId = null;
      });
    }
  }

  // ── open destination search ──
  Future<void> _openDestinationSearch() async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => const LocationSearchScreen(type: 'destination'),
      ),
    );
    if (result != null && mounted) {
      setState(() {
        _destinationController.text = result['description'];
        _destLat = result['lat'];
        _destLng = result['lng'];
        // reset truck selection if route changes
        _selectedTruck = null;
        _selectedTruckId = null;
      });
    }
  }

  // ── submit ──
  Future<void> _submit() async {
    if (_pickupController.text.isEmpty ||
        _destinationController.text.isEmpty ||
        _schedule == null ||
        _selectedTruck == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please complete all fields'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isLoading = true);

    try {
      // ── fetch customer profile ──
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final userData = userDoc.data()!;

      final ref = FirebaseFirestore.instance.collection('bookings').doc();
      await ref.set({
        'userId': user.uid,
        'customer': {
          'fullName': userData['fullName'],
          'phone': userData['phone'],
          'email': userData['email'],
          'address': userData['address'],
        },
        'alternateContact': _alternateContactController.text.isEmpty
            ? null
            : _alternateContactController.text,
        'pickupLocation': _pickupController.text,
        'destination': _destinationController.text,
        'pickupCoords': _pickupLat != null
            ? {'lat': _pickupLat, 'lng': _pickupLng}
            : null,
        'destinationCoords': _destLat != null
            ? {'lat': _destLat, 'lng': _destLng}
            : null,
        'truckType': {
          'id': _selectedTruckId,
          'type': _selectedTruck!['type'],
          'base_price': _selectedTruck!['base_price'],
          'per_km': _selectedTruck!['per_km'],
          'capacity_tons': _selectedTruck!['capacity_tons'],
        },
        'schedule': _schedule,
        'notes': _notesController.text,
        'estimatedDistance': _distance,
        'estimatedCost': _price,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => SuccessScreen(
            bookingId: ref.id,
            pickup: _pickupController.text,
            dropoff: _destinationController.text,
            truckType: _selectedTruck!['type'],
            schedule: DateFormat('EEE, MMM d – hh:mm a').format(_schedule!),
            notes: _notesController.text,
            basePrice: (_selectedTruck!['base_price'] ?? 0).toDouble(),
            estimatedCost: _price,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      setState(() => _isLoading = false);
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
            'Book a Truck',
            style: TextStyle(
              color: _textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          // ── MAP LAYER (isolated — never rebuilds from form changes) ──
          Positioned.fill(
            // ← key optimization
            child: BookingMap(
              pickupLat: _pickupLat,
              pickupLng: _pickupLng,
              destinationLat: _destLat,
              destinationLng: _destLng,
              onDistanceUpdated: (d) {
                // update distance without rebuilding map
                if (mounted) setState(() => _distance = d);
              },
            ),
          ),

          // ── BOTTOM SHEET ──
          DraggableScrollableSheet(
            initialChildSize: 0.42,
            minChildSize: 0.18,
            maxChildSize: 0.88,
            snap: true,
            snapSizes: const [0.18, 0.42, 0.88],
            builder: (context, scrollController) {
              return Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
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

                    // ── summary row ──
                    Row(
                      children: [
                        const Icon(
                          Icons.route_rounded,
                          color: _green,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _pickupController.text.isEmpty &&
                                    _destinationController.text.isEmpty
                                ? 'Set your pickup & destination'
                                : '${_pickupController.text.split(',').first}'
                                      ' → '
                                      '${_destinationController.text.split(',').first}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (_selectedTruck != null) ...[
                          const SizedBox(width: 8),
                          Text(
                            '₱${NumberFormat('#,##0.00').format(_price)}',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: _green,
                            ),
                          ),
                        ],
                      ],
                    ),

                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Divider(height: 1),
                    ),

                    // ── PICKUP ──
                    _label('PICKUP LOCATION'),
                    _tappableField(
                      onTap: _openPickupSearch,
                      icon: Icons.my_location_rounded,
                      text: _pickupController.text.isEmpty
                          ? 'Search pickup location'
                          : _pickupController.text,
                      isSet: _pickupLat != null,
                    ),

                    const SizedBox(height: 14),

                    // ── DESTINATION ──
                    _label('DESTINATION'),
                    _tappableField(
                      onTap: _openDestinationSearch,
                      icon: Icons.flag_rounded,
                      iconColor:
                          _red, // ← add iconColor param to _tappableField
                      text: _destinationController.text.isEmpty
                          ? 'Search destination'
                          : _destinationController.text,
                      isSet: _destLat != null,
                    ),

                    const SizedBox(height: 14),

                    // ── SCHEDULE ──
                    _label('SCHEDULE'),
                    _tappableField(
                      onTap: _pickDateTime,
                      icon: Icons.calendar_month_rounded,
                      text: _schedule == null
                          ? 'Select date & time'
                          : DateFormat(
                              'EEE, MMM d – hh:mm a',
                            ).format(_schedule!),
                      isSet: _schedule != null,
                    ),

                    const SizedBox(height: 14),

                    // ── SELECT VEHICLE ──
                    // ── SELECT VEHICLE ──
                    _label('VEHICLE'),
                    _tappableField(
                      onTap: (_pickupLat == null || _destLat == null)
                          ? () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Set pickup & destination first',
                                  ),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          : _selectVehicle,
                      icon: Icons.local_shipping_rounded,
                      text: _selectedTruck != null
                          ? _selectedTruck!['type'] ?? 'Selected'
                          : (_pickupLat == null || _destLat == null)
                          ? 'Set locations first' // ← hint when locked
                          : 'Select a vehicle',
                      isSet: _selectedTruck != null,
                      trailing: _selectedTruck != null
                          ? Text(
                              '₱${NumberFormat('#,##0.00').format(_price)}',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: _green,
                              ),
                            )
                          : null,
                    ),

                    const SizedBox(height: 14),

                    // ── ALTERNATE CONTACT ──
                    _label('ALTERNATE CONTACT (OPTIONAL)'),
                    TextField(
                      controller: _alternateContactController,
                      keyboardType: TextInputType.phone,
                      style: const TextStyle(fontSize: 14),
                      decoration: _inputDeco(
                        'Name & number if booking for someone else',
                        Icons.person_outline_rounded,
                      ),
                    ),

                    const SizedBox(height: 14),

                    // ── NOTES ──
                    _label('ADDITIONAL NOTES'),
                    TextField(
                      controller: _notesController,
                      maxLines: 3,
                      style: const TextStyle(fontSize: 14),
                      decoration: _inputDeco(
                        'Special instructions (optional)',
                        Icons.notes_rounded,
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ── distance + fare chips ──
                    Row(
                      children: [
                        Expanded(
                          child: _chip(
                            icon: Icons.route_rounded,
                            label: 'Distance',
                            value: _distance == 0.0
                                ? '—'
                                : '${_distance.toStringAsFixed(1)} km',
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _chip(
                            icon: Icons.payments_rounded,
                            label: 'Est. Fare',
                            value: _selectedTruck != null
                                ? '₱${NumberFormat('#,##0.00').format(_price)}'
                                : '—',
                            highlight: _selectedTruck != null,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // ── CONFIRM BUTTON ──
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _green,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.local_shipping_rounded, size: 20),
                                  SizedBox(width: 10),
                                  Text(
                                    'Confirm Booking',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // ── helpers ──

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: _textSecondary,
        letterSpacing: 0.6,
      ),
    ),
  );

  Widget _tappableField({
    required VoidCallback onTap,
    required IconData icon,
    Color? iconColor, // ← add this
    required String text,
    required bool isSet,
    Widget? trailing,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSet ? _green : _border,
            width: isSet ? 1.8 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSet
                  ? _green
                  : iconColor ?? _textSecondary, // ← use iconColor
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 14,
                  color: isSet ? _textPrimary : _textSecondary,
                  fontWeight: isSet ? FontWeight.w600 : FontWeight.normal,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (trailing != null) trailing,
            const SizedBox(width: 4),
            const Icon(
              Icons.chevron_right_rounded,
              color: _textSecondary,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDeco(String hint, IconData icon, {Color? iconColor}) =>
      InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: _textSecondary, fontSize: 14),
        prefixIcon: Icon(icon, color: iconColor ?? _green, size: 20),
        filled: true,
        fillColor: _surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _green, width: 1.8),
        ),
      );

  Widget _chip({
    required IconData icon,
    required String label,
    required String value,
    bool highlight = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: highlight ? _green.withOpacity(0.4) : _border,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: highlight ? _green : _textSecondary, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 10,
                    color: _textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: highlight ? _green : _textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
