import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../auth/login_screen.dart';
import 'edit_profile_screen.dart';
import 'help_center_screen.dart';
import 'support_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

// ── FIX 1: add AutomaticKeepAliveClientMixin ──
class _ProfileScreenState extends State<ProfileScreen>
    with AutomaticKeepAliveClientMixin {
  static const _green = Color(0xFF16A34A);
  static const _textPrimary = Color(0xFF0F172A);
  static const _textSecondary = Color(0xFF64748B);
  static const _surface = Color(0xFFF8FAFC);
  static const _border = Color(0xFFE2E8F0);
  static const _red = Color(0xFFDC2626);

  // ── FIX 1: required by AutomaticKeepAliveClientMixin ──
  @override
  bool get wantKeepAlive => true;

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
          // ── FIX 2: guard empty snapshot to avoid initial flash ──
          if (!snapshot.hasData || snapshot.data?.data() == null) {
            return const Center(
              child: CircularProgressIndicator(color: _green),
            );
          }

          final userData = snapshot.data!.data() as Map<String, dynamic>? ?? {};

          final name =
              userData['fullName'] ??
              userData['name'] ??
              userData['firstName'] ??
              'User';
          final email = userData['email']?.toString().isNotEmpty == true
              ? userData['email'].toString()
              : user.email ?? '';
          final phone = userData['phone'] ?? '';
          final address = userData['address'] ?? '';
          final profileImage = userData['profileImage'];
          final isBlocked = userData['status'] == 'blocked';
          final blockedUntil = userData['blockedUntil'] as Timestamp?;
          final blockReason = userData['blockReason'];
          final cancellationCount = (userData['cancellationCount'] ?? 0) as int;

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
                    // ── PROFILE HEADER CARD ──
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: _textPrimary,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
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
                                const SizedBox(height: 4),
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
                                if (address.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    address,
                                    style: const TextStyle(
                                      color: Color(0xFF94A3B8),
                                      fontSize: 12,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ── SUSPENSION BANNER ──
                    if (isBlocked) ...[
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
                                    blockReason != null
                                        ? 'Reason: $blockReason'
                                        : 'You have 3 consecutive cancellations.',
                                    style: const TextStyle(
                                      color: _red,
                                      fontSize: 12,
                                    ),
                                  ),
                                  if (blockedUntil != null) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      'Suspended until: ${DateFormat('MMM d, yyyy').format(blockedUntil.toDate())}',
                                      style: const TextStyle(
                                        color: _red,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 4),
                                  GestureDetector(
                                    onTap: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => const SupportScreen(),
                                      ),
                                    ),
                                    child: Text(
                                      'Contact support if you think this is a mistake.',
                                      style: TextStyle(
                                        color: _red,
                                        fontSize: 11,
                                        fontStyle: FontStyle.italic,
                                        decoration: TextDecoration.underline,
                                        decorationColor: _red,
                                      ),
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

                    // ── ACCOUNT STATS ──
                    Row(
                      children: [
                        Expanded(
                          child: _statCard(
                            icon: Icons.cancel_outlined,
                            label: 'Cancellations',
                            value: '$cancellationCount / 3',
                            color: cancellationCount >= 3
                                ? _red
                                : _textSecondary,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _statCard(
                            icon: Icons.verified_user_outlined,
                            label: 'Account Status',
                            value: isBlocked ? 'Suspended' : 'Active',
                            color: isBlocked ? _red : _green,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // ── ACCOUNT SECTION ──
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
                          icon: Icons.location_on_outlined,
                          label: 'Saved Locations',
                          onTap: () {},
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // ── SUPPORT SECTION ──
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
                              builder: (_) => const HelpCenterScreen(),
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
                      ],
                    ),

                    const SizedBox(height: 24),

                    // ── LOGOUT BUTTON ──
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
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : 'U';
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
    trailing: const Icon(
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
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: _border),
    ),
    child: Row(
      children: [
        Icon(icon, size: 18, color: color),
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
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
