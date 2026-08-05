import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/auth_controller.dart';
import '../repositories/supabase_repository.dart';
import '../models/notification_model.dart';
import '../constants/app_colors.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _bellController;

  @override
  void initState() {
    super.initState();
    _bellController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _bellController.repeat(reverse: true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) _bellController.stop();
    });
  }

  @override
  void dispose() {
    _bellController.dispose();
    super.dispose();
  }

  Color _getTypeColor(String type) {
    final t = type.toLowerCase();
    if (t.contains('approved')) return Colors.green;
    if (t.contains('discount')) return Colors.amber;
    if (t.contains('flag')) return Colors.red;
    return AppColors.primary;
  }

  IconData _getTypeIcon(String type) {
    final t = type.toLowerCase();
    if (t.contains('approved')) return Icons.check_circle;
    if (t.contains('discount')) return Icons.local_offer;
    if (t.contains('flag')) return Icons.flag;
    return Icons.notifications;
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final user = auth.currentUser;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Notifications')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Sign in to view personalized notifications.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.backgroundSoft,
      appBar: AppBar(
        backgroundColor: AppColors.primaryDark,
        elevation: 0,
        title: const Text('Notifications',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          AnimatedBuilder(
            animation: _bellController,
            builder: (context, child) {
              final angle = sin(_bellController.value * pi * 6) * 0.15;
              return Transform.rotate(
                angle: angle,
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.0),
                  child:
                      Icon(Icons.notifications_active, color: AppColors.gold),
                ),
              );
            },
          ),
        ],
      ),
      body: FutureBuilder<List<NotificationModel>>(
        future: SupabaseRepository().fetchNotifications(user.id),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: AppColors.primary));
          }
          if (snapshot.hasError) {
            return Center(
                child: Text('Error loading notifications',
                    style: TextStyle(color: Colors.red.shade400)));
          }

          final notifications = snapshot.data ?? [];
          if (notifications.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppColors.accentLight.withValues(alpha: 0.3),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.notifications_off,
                        size: 64, color: Colors.grey.shade400),
                  ),
                  const SizedBox(height: 16),
                  Text('No notifications yet',
                      style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500)),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 16),
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final notif = notifications[index];
              return TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration:
                    Duration(milliseconds: 400 + (index * 100).clamp(0, 600)),
                curve: Curves.easeOutCubic,
                builder: (context, value, child) {
                  return Transform.translate(
                    offset: Offset(0, 50 * (1 - value)),
                    child: Opacity(opacity: value, child: child),
                  );
                },
                child: _buildNotificationCard(notif),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildNotificationCard(NotificationModel notif) {
    final Color color = _getTypeColor(notif.type);
    final bool isRead = notif.isRead;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 6, color: color),
            Expanded(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {},
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(_getTypeIcon(notif.type),
                              color: color, size: 22),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                notif.title,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    color: AppColors.primaryDark),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                notif.message,
                                style: TextStyle(
                                    color: Colors.grey.shade700, fontSize: 13),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _timeAgo(notif.createdAt),
                                style: TextStyle(
                                    color: Colors.grey.shade500,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                        if (!isRead)
                          Container(
                            width: 10,
                            height: 10,
                            decoration: const BoxDecoration(
                              color: AppColors.accent,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'Just now';
  }
}
