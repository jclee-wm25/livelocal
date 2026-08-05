import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/auth_controller.dart';
import 'login_screen.dart';
import '../constants/app_colors.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isEditing = false;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _avatarController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = Provider.of<AuthController>(context, listen: false);
      _nameController.text = auth.currentUser?.fullName ?? '';
      _avatarController.text =
          auth.currentUser?.avatarUrl ?? ''; // avatarUrl is String?
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _avatarController.dispose();
    super.dispose();
  }

  Color _getRoleColor(String role) {
    switch (role.toLowerCase()) {
      case 'influencer':
        return Colors.purple;
      case 'admin':
        return Colors.red;
      default:
        return AppColors.accent;
    }
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Account deletion unavailable',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text(
          'No account or data has been deleted. The approved 14-day deletion '
          'and recovery workflow will be implemented in a later phase.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final user = auth.currentUser;
    final role = user?.role ?? 'Tourist';

    return Scaffold(
      backgroundColor: AppColors.backgroundSoft,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 320,
            pinned: true,
            backgroundColor: AppColors.primaryDark,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.primaryDark, AppColors.primary],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: SafeArea(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 20),
                      GestureDetector(
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Profile photo upload is unavailable in this baseline.',
                              ),
                            ),
                          );
                        },
                        child: Stack(
                          alignment: Alignment.bottomRight,
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color:
                                        AppColors.accent.withValues(alpha: 0.5),
                                    blurRadius: 20,
                                    spreadRadius: 5,
                                  )
                                ],
                              ),
                              child: CircleAvatar(
                                radius: 55,
                                backgroundColor: AppColors.primaryDark,
                                backgroundImage: (user?.avatarUrl != null &&
                                        user!.avatarUrl!.isNotEmpty)
                                    ? NetworkImage(user.avatarUrl!)
                                    : null,
                                child: (user?.avatarUrl == null ||
                                        user!.avatarUrl!.isEmpty)
                                    ? Text(
                                        (user?.fullName.isNotEmpty == true
                                                ? user!.fullName[0]
                                                : 'U')
                                            .toUpperCase(),
                                        style: const TextStyle(
                                            fontSize: 36,
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold))
                                    : null,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.gold,
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: AppColors.primaryDark, width: 3),
                              ),
                              child: const Icon(Icons.camera_alt,
                                  color: AppColors.primaryDark, size: 18),
                            )
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        user?.fullName ?? 'Guest User',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user?.email ?? 'guest@livelocal.com',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 16),
                      ),
                      const SizedBox(height: 12),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 6),
                        decoration: BoxDecoration(
                          color: _getRoleColor(role).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: _getRoleColor(role), width: 1.5),
                        ),
                        child: Text(
                          role,
                          style: TextStyle(
                              color: _getRoleColor(role),
                              fontWeight: FontWeight.bold),
                        ),
                      )
                    ],
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildStatItem(Icons.bookmark, '—', 'Saved'),
                      _buildStatItem(Icons.rate_review, '—', 'Reviews'),
                      _buildStatItem(Icons.card_travel, role, 'Role'),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Card(
                    elevation: 4,
                    shadowColor: Colors.black12,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Profile Settings',
                                  style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primaryDark)),
                              IconButton(
                                icon: Icon(
                                    _isEditing ? Icons.close : Icons.edit,
                                    color: AppColors.primary),
                                onPressed: () {
                                  setState(() {
                                    _isEditing = !_isEditing;
                                    if (_isEditing) {
                                      _nameController.text =
                                          user?.fullName ?? '';
                                      _avatarController.text =
                                          user?.avatarUrl ?? '';
                                    }
                                  });
                                },
                              )
                            ],
                          ),
                          AnimatedSize(
                            duration: const Duration(milliseconds: 400),
                            curve: Curves.easeInOut,
                            child: _isEditing
                                ? Column(
                                    children: [
                                      const SizedBox(height: 16),
                                      TextField(
                                        controller: _nameController,
                                        decoration: InputDecoration(
                                          labelText: 'Name',
                                          prefixIcon: const Icon(Icons.person,
                                              color: AppColors.primary),
                                          border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12)),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            borderSide: const BorderSide(
                                                color: AppColors.primary,
                                                width: 2),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      TextField(
                                        controller: _avatarController,
                                        decoration: InputDecoration(
                                          labelText: 'Avatar URL',
                                          prefixIcon: const Icon(
                                              Icons.image_outlined,
                                              color: AppColors.primary),
                                          border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12)),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            borderSide: const BorderSide(
                                                color: AppColors.primary,
                                                width: 2),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 24),
                                      Container(
                                        decoration: BoxDecoration(
                                          gradient: const LinearGradient(
                                            colors: [
                                              AppColors.primary,
                                              AppColors.accent
                                            ],
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          boxShadow: [
                                            BoxShadow(
                                              color: AppColors.accent
                                                  .withValues(alpha: 0.4),
                                              blurRadius: 8,
                                              offset: const Offset(0, 4),
                                            )
                                          ],
                                        ),
                                        child: ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.transparent,
                                            shadowColor: Colors.transparent,
                                            minimumSize:
                                                const Size(double.infinity, 50),
                                            shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(12)),
                                          ),
                                          onPressed: () async {
                                            if (_nameController.text
                                                .trim()
                                                .isEmpty) {
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(const SnackBar(
                                                      content: Text(
                                                          'Name cannot be empty.')));
                                              return;
                                            }
                                            final authCtrl =
                                                context.read<AuthController>();
                                            try {
                                              await authCtrl.updateProfile(
                                                fullName:
                                                    _nameController.text.trim(),
                                                avatarUrl: _avatarController
                                                        .text
                                                        .trim()
                                                        .isEmpty
                                                    ? null
                                                    : _avatarController.text
                                                        .trim(),
                                              );
                                              if (!context.mounted) return;
                                              setState(
                                                  () => _isEditing = false);
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(const SnackBar(
                                                      content: Text(
                                                          'Profile updated!')));
                                            } catch (_) {
                                              if (!context.mounted) return;
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(const SnackBar(
                                                      content: Text(
                                                          'Failed to update profile. Please try again.')));
                                            }
                                          },
                                          child: const Text('Save Changes',
                                              style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold)),
                                        ),
                                      ),
                                    ],
                                  )
                                : const SizedBox.shrink(),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red, width: 1.5),
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.logout),
                    label: const Text('Logout',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                    onPressed: () async {
                      await auth.logout();
                      if (!context.mounted) return;
                      Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const LoginScreen()));
                    },
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    style: TextButton.styleFrom(foregroundColor: Colors.grey),
                    onPressed: _confirmDelete,
                    child: const Text('Delete Account',
                        style: TextStyle(fontSize: 16)),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String value, String label) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.accentLight.withValues(alpha: 0.5),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: AppColors.primary, size: 28),
        ),
        const SizedBox(height: 8),
        Text(value,
            style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryDark)),
        Text(label,
            style: const TextStyle(
                color: Colors.grey, fontSize: 13, fontWeight: FontWeight.w500)),
      ],
    );
  }
}
