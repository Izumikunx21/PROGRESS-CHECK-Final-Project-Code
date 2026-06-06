import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class SupportScreen extends StatelessWidget {
  const SupportScreen({super.key});

  static const _green = Color(0xFF16A34A);
  static const _textPrimary = Color(0xFF0F172A);
  static const _textSecondary = Color(0xFF64748B);
  static const _surface = Color(0xFFF8FAFC);
  static const _border = Color(0xFFE2E8F0);

  // ── replace these with your actual contact details ──
  static const _phoneNumber = '+639382901369';
  static const _whatsappNumber = '09382901369'; // no + for WhatsApp
  static const _emailAddress = 'SmartTruckSupport@gmail.com';

  Future<void> _launch(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
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
          'Support',
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
            // ── Header banner ──
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
                      Icons.headset_mic_rounded,
                      color: Color(0xFF4ADE80),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'We\'re here to help',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: 3),
                        Text(
                          'Reach us through any of the channels below.',
                          style: TextStyle(
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

            const SizedBox(height: 24),

            // ── Section label ──
            const Text(
              'CONTACT OPTIONS',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: _textSecondary,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 12),

            // ── Call ──
            _ContactCard(
              icon: Icons.call_rounded,
              iconBg: const Color(0xFFDCFCE7),
              iconColor: _green,
              title: 'Call Us',
              subtitle: _phoneNumber,
              badge: 'Fastest',
              badgeBg: const Color(0xFFDCFCE7),
              badgeText: _green,
              onTap: () => _launch('tel:$_phoneNumber'),
              actionLabel: 'Call Now',
              actionBg: _green,
            ),

            const SizedBox(height: 10),

            // ── WhatsApp ──
            _ContactCard(
              icon: Icons.chat_rounded,
              iconBg: const Color(0xFFDCFCE7),
              iconColor: const Color(0xFF15803D),
              title: 'WhatsApp',
              subtitle: '$_whatsappNumber',
              badge: 'Recommended',
              badgeBg: const Color(0xFFBBF7D0),
              badgeText: const Color(0xFF166534),
              onTap: () => _launch(
                'https://wa.me/$_whatsappNumber?text=Hi,%20I%20need%20help%20with%20my%20booking.',
              ),
              actionLabel: 'Open Chat',
              actionBg: const Color(0xFF15803D),
            ),

            const SizedBox(height: 10),

            // ── Email ──
            _ContactCard(
              icon: Icons.mail_rounded,
              iconBg: const Color(0xFFEFF6FF),
              iconColor: const Color(0xFF3B82F6),
              title: 'Email Us',
              subtitle: _emailAddress,
              onTap: () =>
                  _launch('mailto:$_emailAddress?subject=Support%20Request'),
              actionLabel: 'Send Email',
              actionBg: const Color(0xFF3B82F6),
            ),

            const SizedBox(height: 28),

            // ── Business hours ──
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF7ED),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.access_time_rounded,
                          color: Color(0xFFF97316),
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'Business Hours',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: _textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _HoursRow(day: 'Monday – Friday', hours: '8:00 AM – 6:00 PM'),
                  const SizedBox(height: 6),
                  _HoursRow(day: 'Saturday', hours: '9:00 AM – 3:00 PM'),
                  const SizedBox(height: 6),
                  _HoursRow(
                    day: 'Sunday & Holidays',
                    hours: 'Closed',
                    closed: true,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Contact card widget ──
class _ContactCard extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String? badge;
  final Color? badgeBg;
  final Color? badgeText;
  final VoidCallback onTap;
  final String actionLabel;
  final Color actionBg;

  const _ContactCard({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    this.badge,
    this.badgeBg,
    this.badgeText,
    required this.onTap,
    required this.actionLabel,
    required this.actionBg,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // icon
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 14),

          // text
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (badge != null) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: badgeBg,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          badge!,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: badgeText,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 10),

          // action button
          GestureDetector(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: actionBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                actionLabel,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Hours row ──
class _HoursRow extends StatelessWidget {
  final String day;
  final String hours;
  final bool closed;

  const _HoursRow({
    required this.day,
    required this.hours,
    this.closed = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          day,
          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
        ),
        Text(
          hours,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: closed ? const Color(0xFFDC2626) : const Color(0xFF0F172A),
          ),
        ),
      ],
    );
  }
}
