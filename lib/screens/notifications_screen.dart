import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/auth_controller.dart';
import '../services/supabase_service.dart';
import '../models/notification_model.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AuthController>(context).currentUser;
    final SupabaseService db = SupabaseService();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications History', style: TextStyle(color: Color(0xFF2D6A4F), fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0.5,
      ),
      body: FutureBuilder<List<NotificationModel>>(
        future: db.fetchNotifications(user?.id ?? 'guest'),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF2D6A4F)));
          }
          final list = snapshot.data ?? [];
          if (list.isEmpty) {
            return const Center(child: Text('No notifications in history.'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            itemBuilder: (context, idx) {
              final n = list[idx];
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFF2D6A4F),
                    child: Icon(Icons.notifications_active, color: Colors.white, size: 20),
                  ),
                  title: Text(n.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(n.message),
                  trailing: Text(
                    '${n.createdAt.hour}:${n.createdAt.minute.toString().padLeft(2, '0')}',
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
