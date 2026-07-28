import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/auth_controller.dart';
import 'login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nameCtrl = TextEditingController();
  final _avatarCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    final user = Provider.of<AuthController>(context, listen: false).currentUser;
    if (user != null) {
      _nameCtrl.text = user.fullName;
      _avatarCtrl.text = user.avatarUrl ?? '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final authCtrl = Provider.of<AuthController>(context);
    final user = authCtrl.currentUser;

    if (user == null) {
      return Center(
        child: ElevatedButton(
          onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen())),
          child: const Text('Login'),
        ),
      );
    }

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 20),
            CircleAvatar(
              radius: 48,
              backgroundColor: const Color(0xFF2D6A4F),
              backgroundImage: user.avatarUrl != null ? NetworkImage(user.avatarUrl!) : null,
              child: user.avatarUrl == null ? const Icon(Icons.person, size: 48, color: Colors.white) : null,
            ),
            const SizedBox(height: 12),
            Text(user.fullName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            Text(user.email, style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 8),
            Chip(
              label: Text('Role: ${user.role.toUpperCase()}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              backgroundColor: const Color(0xFF2D6A4F),
            ),
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Edit Profile Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _nameCtrl,
                      decoration: const InputDecoration(labelText: 'Full Name', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _avatarCtrl,
                      decoration: const InputDecoration(labelText: 'Avatar Photo URL', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 14),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2D6A4F),
                        minimumSize: const Size(double.infinity, 44),
                      ),
                      onPressed: () async {
                        await authCtrl.updateProfile(
                          fullName: _nameCtrl.text.trim(),
                          avatarUrl: _avatarCtrl.text.trim().isNotEmpty ? _avatarCtrl.text.trim() : null,
                        );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Profile updated successfully!')),
                          );
                        }
                      },
                      child: const Text('Save Profile Changes', style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              icon: const Icon(Icons.logout, color: Colors.red),
              label: const Text('Logout Account', style: TextStyle(color: Colors.red)),
              style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red)),
              onPressed: () {
                authCtrl.logout();
                Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
              },
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () {
                _showDeleteAccountDialog(context, authCtrl);
              },
              child: const Text('Delete Account', style: TextStyle(color: Colors.grey)),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteAccountDialog(BuildContext context, AuthController authCtrl) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Account'),
        content: const Text('Are you sure you want to permanently delete your LiveLocal account?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              authCtrl.logout();
              Navigator.pop(ctx);
              Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
