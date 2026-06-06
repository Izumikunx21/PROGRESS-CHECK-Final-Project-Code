import 'package:flutter/material.dart';
import 'support_screen.dart';

class HelpCenterScreen extends StatefulWidget {
  final String role; // 'customer' or 'driver'
  const HelpCenterScreen({super.key, this.role = 'customer'});

  @override
  State<HelpCenterScreen> createState() => _HelpCenterScreenState();
}

class _HelpCenterScreenState extends State<HelpCenterScreen> {
  static const _green = Color(0xFF16A34A);
  static const _textPrimary = Color(0xFF0F172A);
  static const _textSecondary = Color(0xFF64748B);
  static const _surface = Color(0xFFF8FAFC);
  static const _border = Color(0xFFE2E8F0);

  String _searchQuery = '';
  int? _expandedFaqIndex;
  int? _expandedGuideIndex;

  // ── CUSTOMER FAQs ──
  final List<Map<String, String>> _customerFaqs = [
    {
      'q': 'How do I book a truck?',
      'a':
          'Tap "Book Truck" on your dashboard, enter your pickup and destination address, choose a vehicle type, then confirm your booking. You\'ll receive a confirmation once a driver is assigned.',
    },
    {
      'q': 'How is the estimated cost calculated?',
      'a':
          'Cost is based on the truck\'s base price plus a per-kilometer rate multiplied by the distance between your pickup and destination. You can see the breakdown on the vehicle selection screen.',
    },
    {
      'q': 'Can I cancel a booking?',
      'a':
          'Yes, you can cancel a booking while it is still in "Pending" status. Note that 3 consecutive cancellations will temporarily suspend your booking privileges.',
    },
    {
      'q': 'What happens if a driver rejects my booking?',
      'a':
          'If a driver rejects your trip, your booking status changes to "Approved" and a new driver will be automatically assigned. You\'ll see a notice on your dashboard.',
    },
    {
      'q': 'How do I track my shipment?',
      'a':
          'Go to the "Track Shipment" tab on your dashboard. You can see the live location of your driver and the estimated time of arrival.',
    },
    {
      'q': 'Why is my account suspended?',
      'a':
          'Accounts are suspended after 3 consecutive booking cancellations, or manually by an admin. You can see the reason and suspension end date on your dashboard or profile.',
    },
    {
      'q': 'How do I contact my driver?',
      'a':
          'Once a driver is assigned, a "Call" button appears on your active trip card in the dashboard. Tap it to call your driver directly.',
    },
    {
      'q': 'What truck types are available?',
      'a':
          'Available truck types and their capacities are shown on the vehicle selection screen during booking. Capacity is listed in tons.',
    },
  ];

  // ── DRIVER FAQs ──
  final List<Map<String, String>> _driverFaqs = [
    {
      'q': 'How do I accept a trip?',
      'a':
          'When a trip is assigned to you, you\'ll receive a notification. Open the Jobs tab to view the trip details and tap "Accept Trip" to confirm. You can also tap "Reject Trip" if you\'re unable to take it.',
    },
    {
      'q': 'What happens if I reject a trip?',
      'a':
          'If you reject a trip, it goes back to the admin for reassignment. The booking status changes to "Approved" and needs_reassignment is flagged. Frequent rejections may affect your standing.',
    },
    {
      'q': 'How do I mark a delivery as complete?',
      'a':
          'On the map screen, follow the status flow: Start Trip → Arrived at Pickup → Start Delivery → Mark as Delivered. Each step updates your booking status in real time.',
    },
    {
      'q': 'How is my rating calculated?',
      'a':
          'Your rating is the average of all ratings submitted by customers after completed deliveries. Customers rate from 1 to 5 stars and can leave an optional comment.',
    },
    {
      'q': 'What do I do if the customer is unreachable?',
      'a':
          'Try calling the customer using the Call button on your active trip card. If still unreachable, contact admin support through the Contact Support screen for guidance.',
    },
    {
      'q': 'How do I go online to receive jobs?',
      'a':
          'On the Dashboard, tap the "Offline" toggle in the top right to switch to "Online". You\'ll only receive job assignments when you\'re marked as online.',
    },
    {
      'q': 'Why is my account suspended?',
      'a':
          'Accounts can be suspended by an admin for policy violations or other reasons. The suspension reason and end date will be shown on your profile screen. Contact support if you believe it\'s a mistake.',
    },
    {
      'q': 'How do I update my availability?',
      'a':
          'Your availability updates automatically based on your trip status. When you\'re on a trip it shows "On Trip", and returns to "Available" once the delivery is marked complete.',
    },
  ];

  // ── CUSTOMER GUIDES ──
  final List<Map<String, dynamic>> _customerGuides = [
    {
      'icon': Icons.local_shipping_rounded,
      'iconBg': const Color(0xFFDCFCE7),
      'iconColor': _green,
      'title': 'How to Book a Truck',
      'steps': [
        'Tap "Book Truck" on your dashboard.',
        'Enter your pickup address and destination.',
        'Select a vehicle type that fits your load.',
        'Review the estimated cost and confirm.',
        'Wait for a driver to be assigned.',
      ],
    },
    {
      'icon': Icons.location_on_rounded,
      'iconBg': const Color(0xFFEFF6FF),
      'iconColor': const Color(0xFF3B82F6),
      'title': 'How to Track Your Shipment',
      'steps': [
        'Go to the "Track Shipment" tab.',
        'Your active booking will show on the map.',
        'The driver\'s live location updates in real time.',
        'ETA is shown on your active trip card.',
      ],
    },
    {
      'icon': Icons.cancel_rounded,
      'iconBg': const Color(0xFFFEF2F2),
      'iconColor': const Color(0xFFDC2626),
      'title': 'How to Cancel a Booking',
      'steps': [
        'Go to "My Bookings" tab.',
        'Find the booking you want to cancel.',
        'Tap the booking to open its details.',
        'Tap "Cancel Booking" (only available while Pending).',
        'Confirm the cancellation in the dialog.',
      ],
    },
    {
      'icon': Icons.person_rounded,
      'iconBg': const Color(0xFFFFF7ED),
      'iconColor': const Color(0xFFF97316),
      'title': 'How to Update Your Profile',
      'steps': [
        'Go to the "Profile" tab.',
        'Tap "Edit Profile".',
        'Update your name, phone, or address.',
        'Tap "Save" to apply changes.',
      ],
    },
  ];

  // ── DRIVER GUIDES ──
  final List<Map<String, dynamic>> _driverGuides = [
    {
      'icon': Icons.check_circle_rounded,
      'iconBg': const Color(0xFFDCFCE7),
      'iconColor': _green,
      'title': 'How to Accept a Trip',
      'steps': [
        'Go to the Jobs tab when a trip is assigned.',
        'Tap the trip card to view full details.',
        'Review the route, customer info, and estimated cost.',
        'Tap "Accept Trip" to confirm.',
        'You\'ll be navigated to the map screen automatically.',
      ],
    },
    {
      'icon': Icons.navigation_rounded,
      'iconBg': const Color(0xFFEFF6FF),
      'iconColor': const Color(0xFF3B82F6),
      'title': 'How to Complete a Delivery',
      'steps': [
        'After accepting, tap "Start Trip" on the map screen.',
        'Navigate to the pickup location.',
        'Tap "Arrived at Pickup" when you reach the customer.',
        'Load the cargo and tap "Start Delivery".',
        'Navigate to the destination.',
        'Tap "Mark as Delivered" to complete the trip.',
      ],
    },
    {
      'icon': Icons.wifi_rounded,
      'iconBg': const Color(0xFFFFF7ED),
      'iconColor': const Color(0xFFF97316),
      'title': 'How to Go Online',
      'steps': [
        'Open the Dashboard tab.',
        'Tap the "Offline" badge in the top right corner.',
        'It will switch to "Online" — you\'re now visible to admin.',
        'Toggle back to "Offline" when you\'re done for the day.',
      ],
    },
    {
      'icon': Icons.star_rounded,
      'iconBg': const Color(0xFFFEF9C3),
      'iconColor': const Color(0xFFF59E0B),
      'title': 'How to Improve Your Rating',
      'steps': [
        'Always arrive on time for pickups.',
        'Handle cargo with care — especially fragile items.',
        'Communicate proactively with customers.',
        'Complete deliveries without cancellations.',
        'Be polite and professional at all times.',
      ],
    },
  ];

  bool get _isDriver => widget.role == 'driver';

  List<Map<String, String>> get _faqs =>
      _isDriver ? _driverFaqs : _customerFaqs;

  List<Map<String, dynamic>> get _guides =>
      _isDriver ? _driverGuides : _customerGuides;

  List<Map<String, String>> get _filteredFaqs {
    if (_searchQuery.trim().isEmpty) return _faqs;
    final q = _searchQuery.toLowerCase();
    return _faqs
        .where(
          (f) =>
              f['q']!.toLowerCase().contains(q) ||
              f['a']!.toLowerCase().contains(q),
        )
        .toList();
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
          'Help Center',
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: _green.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.help_rounded,
                      color: Color(0xFF4ADE80),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'How can we help?',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _isDriver
                              ? 'Driver guides, FAQs and support.'
                              : 'Browse guides and FAQs or contact support.',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── Search bar ──
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _border),
              ),
              child: TextField(
                onChanged: (v) => setState(() {
                  _searchQuery = v;
                  _expandedFaqIndex = null;
                }),
                style: const TextStyle(fontSize: 14, color: _textPrimary),
                decoration: const InputDecoration(
                  hintText: 'Search FAQs…',
                  hintStyle: TextStyle(fontSize: 14, color: _textSecondary),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    color: _textSecondary,
                    size: 20,
                  ),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // ── Quick link to Support ──
            GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SupportScreen()),
              ),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _green.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _green.withOpacity(0.25)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: _green.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.headset_mic_rounded,
                        color: _green,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Still need help?',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: _textPrimary,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Contact our support team directly.',
                            style: TextStyle(
                              fontSize: 12,
                              color: _textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 14,
                      color: _green,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 28),

            // ── How-to Guides ──
            if (_searchQuery.trim().isEmpty) ...[
              _sectionLabel('HOW-TO GUIDES'),
              const SizedBox(height: 12),
              ...List.generate(_guides.length, (i) {
                final guide = _guides[i];
                final isOpen = _expandedGuideIndex == i;
                final steps = guide['steps'] as List<String>;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isOpen ? _green.withOpacity(0.4) : _border,
                      ),
                    ),
                    child: Column(
                      children: [
                        GestureDetector(
                          onTap: () => setState(
                            () => _expandedGuideIndex = isOpen ? null : i,
                          ),
                          child: Container(
                            color: Colors.transparent,
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              children: [
                                Container(
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    color: guide['iconBg'] as Color,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    guide['icon'] as IconData,
                                    color: guide['iconColor'] as Color,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    guide['title'] as String,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: _textPrimary,
                                    ),
                                  ),
                                ),
                                Icon(
                                  isOpen
                                      ? Icons.keyboard_arrow_up_rounded
                                      : Icons.keyboard_arrow_down_rounded,
                                  color: _textSecondary,
                                  size: 20,
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (isOpen)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                            child: Column(
                              children: [
                                Container(height: 1, color: _border),
                                const SizedBox(height: 12),
                                ...List.generate(steps.length, (si) {
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          width: 22,
                                          height: 22,
                                          decoration: BoxDecoration(
                                            color: _green.withOpacity(0.1),
                                            shape: BoxShape.circle,
                                          ),
                                          alignment: Alignment.center,
                                          child: Text(
                                            '${si + 1}',
                                            style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              color: _green,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            steps[si],
                                            style: const TextStyle(
                                              fontSize: 13,
                                              color: _textPrimary,
                                              height: 1.5,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              }),
              const SizedBox(height: 28),
            ],

            // ── FAQ ──
            _sectionLabel('FREQUENTLY ASKED QUESTIONS'),
            const SizedBox(height: 12),

            if (_filteredFaqs.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: const Column(
                  children: [
                    Icon(
                      Icons.search_off_rounded,
                      size: 36,
                      color: _textSecondary,
                    ),
                    SizedBox(height: 10),
                    Text(
                      'No results found',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _textPrimary,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Try a different keyword.',
                      style: TextStyle(fontSize: 12, color: _textSecondary),
                    ),
                  ],
                ),
              )
            else
              ...List.generate(_filteredFaqs.length, (i) {
                final faq = _filteredFaqs[i];
                final isOpen = _expandedFaqIndex == i;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isOpen ? _green.withOpacity(0.4) : _border,
                      ),
                    ),
                    child: Column(
                      children: [
                        GestureDetector(
                          onTap: () => setState(
                            () => _expandedFaqIndex = isOpen ? null : i,
                          ),
                          child: Container(
                            color: Colors.transparent,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 14,
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  margin: const EdgeInsets.only(top: 1),
                                  width: 22,
                                  height: 22,
                                  decoration: BoxDecoration(
                                    color: isOpen
                                        ? _green
                                        : _green.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    'Q',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: isOpen ? Colors.white : _green,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    faq['q']!,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: isOpen ? _green : _textPrimary,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Icon(
                                  isOpen
                                      ? Icons.keyboard_arrow_up_rounded
                                      : Icons.keyboard_arrow_down_rounded,
                                  color: _textSecondary,
                                  size: 20,
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (isOpen)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(height: 1, color: _border),
                                const SizedBox(height: 10),
                                Text(
                                  faq['a']!,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: _textSecondary,
                                    height: 1.6,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: _textSecondary,
        letterSpacing: 0.8,
      ),
    );
  }
}
