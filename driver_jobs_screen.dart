import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'widgets/job_card_widget.dart';

class DriverJobsScreen extends StatelessWidget {
  final Function(int)? onTabChange; // ← ADD

  const DriverJobsScreen({super.key, this.onTabChange});

  // ── color tokens ──
  static const _green = Color(0xFF16A34A);
  static const _textPrimary = Color(0xFF0F172A);
  static const _textSecondary = Color(0xFF64748B);
  static const _surface = Color(0xFFF8FAFC);
  static const _border = Color(0xFFE2E8F0);

  Stream<QuerySnapshot> getJobs() {
    final driverId = FirebaseAuth.instance.currentUser?.uid;
    if (driverId == null) return const Stream.empty();
    return FirebaseFirestore.instance
        .collection('bookings')
        .where('assigned_driver_id', isEqualTo: driverId)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: _surface,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          automaticallyImplyLeading: false,
          title: const Text(
            'My Jobs',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: _textPrimary,
            ),
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(49),
            child: Column(
              children: [
                Container(height: 1, color: _border),
                const TabBar(
                  indicatorColor: _green,
                  indicatorWeight: 2.5,
                  labelColor: _green,
                  unselectedLabelColor: _textSecondary,
                  labelStyle: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                  unselectedLabelStyle: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                  tabs: [
                    Tab(text: 'Assigned'),
                    Tab(text: 'Completed'),
                  ],
                ),
              ],
            ),
          ),
        ),
        body: StreamBuilder<QuerySnapshot>(
          stream: getJobs(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const Center(child: Text('Something went wrong.'));
            }
            if (!snapshot.hasData) {
              return const Center(
                child: CircularProgressIndicator(color: _green),
              );
            }

            final jobs = snapshot.data!.docs;
            final assignedJobs = jobs.where((j) {
              final d = j.data() as Map<String, dynamic>;
              return [
                'assigned', // ← ADD THIS
                'accepted',
                'en_route_to_pickup',
                'arrived_at_pickup',
                'in_transit',
              ].contains(d['status']);
            }).toList();

            final completedJobs = jobs.where((j) {
              final d = j.data() as Map<String, dynamic>;
              return [
                'completed',
                'delivered',
              ].contains(d['status']); // ← cover both
            }).toList();

            return TabBarView(
              children: [
                _buildList(assignedJobs, isCompleted: false),
                _buildList(completedJobs, isCompleted: true),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildList(
    List<QueryDocumentSnapshot> jobs, {
    bool isCompleted = false,
  }) {
    if (jobs.isEmpty) {
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
              child: Icon(
                isCompleted
                    ? Icons.check_circle_outline_rounded
                    : Icons.local_shipping_outlined,
                size: 30,
                color: _textSecondary,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              isCompleted ? 'No completed jobs yet' : 'No assigned jobs',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: _textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              isCompleted
                  ? 'Completed deliveries will appear here'
                  : 'Jobs assigned to you will appear here',
              style: const TextStyle(fontSize: 13, color: _textSecondary),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      itemCount: jobs.length,
      itemBuilder: (context, index) {
        return JobCardWidget(
          doc: jobs[index],
          isCompleted: isCompleted,
          onNavigateToMap: () => onTabChange?.call(2), // ← ADD
        );
      },
    );
  }
}
