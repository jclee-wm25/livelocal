import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/admin_controller.dart';
import '../controllers/spot_controller.dart';
import '../controllers/guide_controller.dart';
import '../controllers/review_controller.dart';

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final adminCtrl = Provider.of<AdminController>(context);
    final spotCtrl = Provider.of<SpotController>(context);
    final guideCtrl = Provider.of<GuideController>(context);
    final reviewCtrl = Provider.of<ReviewController>(context);

    final pendingSpots = spotCtrl.pendingSpots;
    final pendingGuides = guideCtrl.pendingGuides;
    final flaggedReviews = reviewCtrl.flaggedReviews;
    final users = adminCtrl.allUsers;

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF2D6A4F),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Row(
                children: [
                  Icon(Icons.admin_panel_settings, color: Colors.white, size: 36),
                  SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Admin Moderation Hub', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                      Text('System Stats & Verification Portal', style: TextStyle(color: Color(0xFF74C69D), fontSize: 12)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // Platform Statistics Grid (FR58)
            const Text('Platform Overview Statistics', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildStatCard('Total Users', adminCtrl.totalUsers.toString(), Icons.people, Colors.blue),
                const SizedBox(width: 12),
                _buildStatCard('Pending Spots', pendingSpots.length.toString(), Icons.place, Colors.orange),
                const SizedBox(width: 12),
                _buildStatCard('Flagged Reviews', flaggedReviews.length.toString(), Icons.flag, Colors.red),
              ],
            ),
            const SizedBox(height: 24),
            // Pending Spot Approvals (FR22, FR23)
            Text('Pending Spot Approvals (${pendingSpots.length})', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (pendingSpots.isEmpty)
              const Text('No pending spots for approval.', style: TextStyle(color: Colors.grey))
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: pendingSpots.length,
                itemBuilder: (context, idx) {
                  final s = pendingSpots[idx];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      title: Text(s.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('${s.category} • ${s.city}, ${s.state}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.check_circle, color: Colors.green),
                            onPressed: () async {
                              await spotCtrl.approveSpot(s.id);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Spot "${s.name}" approved!')));
                              }
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.cancel, color: Colors.red),
                            onPressed: () {
                              _showRejectDialog(context, 'Spot', (reason) async {
                                await spotCtrl.rejectSpot(s.id, reason);
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            const SizedBox(height: 24),
            // Flagged Review Moderation Queue (FR59, FR60)
            Text('Flagged Reviews Queue (${flaggedReviews.length})', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (flaggedReviews.isEmpty)
              const Text('No flagged reviews pending moderation.', style: TextStyle(color: Colors.grey))
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: flaggedReviews.length,
                itemBuilder: (context, idx) {
                  final r = flaggedReviews[idx];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      title: Text('Review by ${r.userName}', style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Comment: "${r.comment}"'),
                          Text('Reason Flagged: ${r.flagReason ?? 'Inappropriate'}', style: const TextStyle(color: Colors.red, fontSize: 12)),
                        ],
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_forever, color: Colors.red),
                        onPressed: () async {
                          await reviewCtrl.removeReview(r.id);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Inappropriate review removed.')));
                          }
                        },
                      ),
                    ),
                  );
                },
              ),
            const SizedBox(height: 24),
            // User Suspension Management (FR11)
            const Text('User Account Moderation & Suspension', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: users.length,
              itemBuilder: (context, idx) {
                final u = users[idx];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: u.isSuspended ? Colors.red : const Color(0xFF2D6A4F),
                      child: Icon(u.isSuspended ? Icons.block : Icons.person, color: Colors.white, size: 18),
                    ),
                    title: Text(u.fullName, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('${u.email} • Role: ${u.role.toUpperCase()}'),
                    trailing: Switch(
                      value: u.isSuspended,
                      activeColor: Colors.red,
                      onChanged: (val) async {
                        await adminCtrl.toggleUserSuspension(u.id);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(val ? 'User account suspended.' : 'User account restored.')),
                          );
                        }
                      },
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 6),
            Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
            Text(title, style: const TextStyle(fontSize: 11, color: Colors.black87), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  void _showRejectDialog(BuildContext context, String targetType, Function(String) onReject) {
    final reasonCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Reject $targetType'),
        content: TextField(
          controller: reasonCtrl,
          decoration: const InputDecoration(
            labelText: 'Mandatory Rejection Reason *',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              if (reasonCtrl.text.trim().isNotEmpty) {
                onReject(reasonCtrl.text.trim());
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$targetType rejected.')));
              }
            },
            child: const Text('Confirm Rejection', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
