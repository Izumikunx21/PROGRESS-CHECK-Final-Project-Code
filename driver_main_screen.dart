import 'package:flutter/material.dart';

import 'driver_dashboard.dart';
import 'driver_jobs_screen.dart';
import 'driver_map_screen.dart';
import 'driver_profile_screen.dart';

class DriverMainScreen extends StatefulWidget {
  final int initialIndex;

  const DriverMainScreen({super.key, this.initialIndex = 0});

  @override
  State<DriverMainScreen> createState() => _DriverMainScreenState();
}

class _DriverMainScreenState extends State<DriverMainScreen> {
  static const _green = Color(0xFF16A34A);
  static const _textSecondary = Color(0xFF64748B);
  static const _border = Color(0xFFE2E8F0);

  int currentIndex = 0;

  late final List<Widget> screens;

  @override
  void initState() {
    super.initState();
    currentIndex = widget.initialIndex;
    screens = [
      DriverDashboard(
        onTabChange: (index) => setState(() => currentIndex = index),
      ),
      DriverJobsScreen(
        onTabChange: (index) => setState(() => currentIndex = index), // ← ADD
      ),
      const DriverMapScreen(),
      const DriverProfileScreen(),
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
      _NavItem(icon: Icons.local_shipping_rounded, label: "Jobs"),
      _NavItem(icon: Icons.map_rounded, label: "Map"),
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
