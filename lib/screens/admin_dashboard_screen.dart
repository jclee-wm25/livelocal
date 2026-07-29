import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/admin_controller.dart';
import '../controllers/spot_controller.dart';
import '../controllers/guide_controller.dart';
import '../controllers/review_controller.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen>
    with TickerProviderStateMixin {
  late AnimationController _shakeController;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  void _showSnackbar(String message, {bool success = false}) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: success ? const Color(0xFF2D6A4F) : const Color(0xFFC62828),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _showRejectDialog() {
    final TextEditingController reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(builder: (context, setStateDialog) {
          return AnimatedBuilder(
            animation: _shakeController,
            builder: (context, child) {
              final dx = sin(_shakeController.value * 2 * pi * 3) * 10;
              return Transform.translate(
                offset: Offset(dx, 0),
                child: AlertDialog(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  title: const Text('Reject Reason',
                      style: TextStyle(
                          color: Color(0xFFC62828), fontWeight: FontWeight.bold)),
                  content: TextField(
                    controller: reasonController,
                    decoration: InputDecoration(
                      hintText: 'Enter reason for rejection',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(
                            color: Color(0xFFC62828), width: 2),
                      ),
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel',
                          style: TextStyle(color: Colors.grey)),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFC62828),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () {
                        if (reasonController.text.isEmpty) {
                          _shakeController.forward(from: 0.0);
                        } else {
                          Navigator.pop(context);
                          _showSnackbar('Item rejected');
                        }
                      },
                      child: const Text('Reject',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              );
            },
          );
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final spotCtrl = context.watch<SpotController>();
    final reviewCtrl = context.watch<ReviewController>();
    final pendingSpots = spotCtrl.pendingSpots;
    final flaggedReviews = reviewCtrl.flaggedReviews;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            backgroundColor: const Color(0xFF800000),
            flexibleSpace: FlexibleSpaceBar(
              title: const Text('Admin Hub',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18)),
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF800000), Color(0xFFC62828)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: const Center(
                  child: Padding(
                    padding: EdgeInsets.only(bottom: 20.0),
                    child: Icon(Icons.admin_panel_settings,
                        size: 80, color: Colors.white24),
                  ),
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(16.0),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 1.3,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              delegate: SliverChildListDelegate([
                _buildStatCard('Pending Spots', '${pendingSpots.length}',
                    Icons.pending_actions, Colors.orange),
                _buildStatCard('Flagged Reviews', '${flaggedReviews.length}',
                    Icons.flag, const Color(0xFFC62828)),
                _buildStatCard('Total Spots', '${spotCtrl.spots.length}',
                    Icons.place, Colors.blue),
                _buildStatCard('Total Reviews', '${reviewCtrl.reviews.length}',
                    Icons.rate_review, Colors.green),
              ]),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                children: [
                  _buildExpansionSection(
                    'Pending Spot Approvals',
                    Icons.pending_actions,
                    pendingSpots.isEmpty
                        ? [
                            const ListTile(
                              title: Text('No pending spots',
                                  style: TextStyle(color: Colors.grey)),
                            )
                          ]
                        : pendingSpots
                            .take(5)
                            .map((spot) => _buildApprovalTile(
                                  spot.name,
                                  spot.category,
                                  onApprove: () {
                                    context
                                        .read<SpotController>()
                                        .approveSpot(spot.id);
                                    _showSnackbar('${spot.name} approved!',
                                        success: true);
                                  },
                                  onReject: _showRejectDialog,
                                ))
                            .toList(),
                  ),
                  const SizedBox(height: 16),
                  _buildExpansionSection(
                    'Flagged Reviews Queue',
                    Icons.report_problem,
                    flaggedReviews.isEmpty
                        ? [
                            const ListTile(
                              title: Text('No flagged reviews',
                                  style: TextStyle(color: Colors.grey)),
                            )
                          ]
                        : flaggedReviews
                            .take(5)
                            .map((r) => _buildReviewTile(
                                r.comment,
                                onDelete: () {
                                  context.read<ReviewController>().removeReview(r.id);
                                  _showSnackbar('Review removed');
                                }))
                            .toList(),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
      String title, String value, IconData icon, Color color) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.9, end: 1.0),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutBack,
      builder: (context, val, child) {
        return Transform.scale(scale: val, child: child);
      },
      child: Card(
        elevation: 6,
        shadowColor: color.withOpacity(0.3),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 32),
              const SizedBox(height: 12),
              Text(value,
                  style: const TextStyle(
                      fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 11,
                      color: Colors.grey,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExpansionSection(
      String title, IconData icon, List<Widget> children) {
    return Card(
      elevation: 2,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        leading: Icon(icon, color: const Color(0xFFC62828)),
        title: Text(title,
            style: const TextStyle(
                fontWeight: FontWeight.bold, fontSize: 16)),
        backgroundColor: Colors.white,
        collapsedBackgroundColor: Colors.white,
        childrenPadding: const EdgeInsets.only(bottom: 8),
        children: children,
      ),
    );
  }

  Widget _buildApprovalTile(String title, String subtitle,
      {required VoidCallback onApprove, required VoidCallback onReject}) {
    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            icon: const Icon(Icons.check_circle, color: Colors.green, size: 28),
            onPressed: onApprove,
          ),
          IconButton(
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            icon: const Icon(Icons.cancel,
                color: Color(0xFFC62828), size: 28),
            onPressed: () {
              _confirmAction(
                title: 'Reject Submission',
                content: 'Are you sure you want to reject "$title"?',
                onConfirm: onReject,
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildReviewTile(String title, {required VoidCallback onDelete}) {
    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      title: Text(title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w500)),
      trailing: IconButton(
        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
        icon: const Icon(Icons.delete, color: Color(0xFFC62828)),
        onPressed: () {
          _confirmAction(
            title: 'Delete Flagged Review',
            content: 'Are you sure you want to delete this review?',
            onConfirm: onDelete,
          );
        },
      ),
    );
  }

  void _confirmAction({
    required String title,
    required String content,
    required VoidCallback onConfirm,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFC62828)),
            onPressed: () {
              Navigator.pop(ctx);
              onConfirm();
            },
            child: const Text('Confirm', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
