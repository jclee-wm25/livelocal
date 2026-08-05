import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../constants/app_colors.dart';
import '../controllers/auth_controller.dart';
import '../features/profile/presentation/account_controller.dart';
import '../features/moderation/presentation/moderation_controller.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _displayNameController = TextEditingController();
  bool _editing = false;

  @override
  void dispose() {
    _displayNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final account = context.watch<AccountController>();
    final moderation = context.watch<ModerationController>();
    final user = auth.currentUser;
    if (user == null) return const _GuestAccountPrompt();

    return Scaffold(
      backgroundColor: const Color(0xFFF7F5F0),
      appBar: AppBar(
        title: const Text('Your account'),
        backgroundColor: const Color(0xFFF7F5F0),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
          children: [
            Card(
              elevation: 0,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Stack(
                      children: [
                        CircleAvatar(
                          radius: 48,
                          backgroundColor: AppColors.accentLight,
                          backgroundImage: user.avatarUrl == null
                              ? null
                              : NetworkImage(user.avatarUrl!),
                          child: user.avatarUrl == null
                              ? Text(
                                  user.fullName.isEmpty
                                      ? 'L'
                                      : user.fullName[0].toUpperCase(),
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineMedium
                                      ?.copyWith(color: AppColors.primaryDark),
                                )
                              : null,
                        ),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: IconButton.filled(
                            tooltip: 'Change profile photo',
                            onPressed: account.isLoading
                                ? null
                                : () => _chooseAvatar(account),
                            icon: const Icon(Icons.photo_camera_outlined),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      user.fullName,
                      style: Theme.of(context).textTheme.titleLarge,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user.email,
                      style: Theme.of(context).textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Chip(
                      avatar:
                          const Icon(Icons.verified_user_outlined, size: 18),
                      label: Text(_roleLabel(user.role)),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (user.role == 'tourist') ...[
              Card(
                elevation: 0,
                child: ListTile(
                  minTileHeight: 64,
                  leading: const Icon(Icons.campaign_outlined),
                  title: const Text('Become a local creator'),
                  subtitle: const Text(
                    'Apply to submit creator-led restaurant recommendations.',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () =>
                      Navigator.pushNamed(context, '/creator-application'),
                ),
              ),
              const SizedBox(height: 16),
            ],
            Card(
              elevation: 0,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Profile details',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        IconButton(
                          tooltip: _editing ? 'Cancel editing' : 'Edit profile',
                          onPressed: account.isLoading
                              ? null
                              : () {
                                  setState(() {
                                    _editing = !_editing;
                                    _displayNameController.text = user.fullName;
                                  });
                                },
                          icon: Icon(
                              _editing ? Icons.close : Icons.edit_outlined),
                        ),
                      ],
                    ),
                    if (_editing) ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: _displayNameController,
                        textInputAction: TextInputAction.done,
                        maxLength: 80,
                        decoration: const InputDecoration(
                          labelText: 'Display name',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 8),
                      FilledButton(
                        onPressed: account.isLoading
                            ? null
                            : () => _saveDisplayName(account),
                        child: const Text('Save changes'),
                      ),
                    ] else
                      const ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.email_outlined),
                        title: Text('Email address'),
                        subtitle: Text(
                          'Email changes require a separate verified flow.',
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (account.errorMessage != null) ...[
              const SizedBox(height: 12),
              _InlineError(message: account.errorMessage!),
            ],
            const SizedBox(height: 16),
            Card(
              elevation: 0,
              child: Column(
                children: [
                  ListTile(
                    minTileHeight: 56,
                    leading: const Icon(Icons.notifications_outlined),
                    title: const Text('Notifications'),
                    subtitle: const Text('View your in-app history'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.pushNamed(context, '/notifications'),
                  ),
                  if (moderation.supportsUserBlocking) ...[
                    const Divider(height: 1),
                    ListTile(
                      minTileHeight: 56,
                      leading: const Icon(Icons.person_off_outlined),
                      title: const Text('Blocked accounts'),
                      subtitle: const Text('Review or undo hidden accounts'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () =>
                          Navigator.pushNamed(context, '/blocked-users'),
                    ),
                  ],
                  const Divider(height: 1),
                  ListTile(
                    minTileHeight: 56,
                    leading: const Icon(Icons.logout),
                    title: const Text('Sign out'),
                    onTap: auth.isLoading ? null : auth.logout,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            TextButton.icon(
              onPressed:
                  account.isLoading ? null : () => _showDeletionDialog(account),
              icon: const Icon(Icons.delete_outline),
              label: const Text('Delete account'),
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
                minimumSize: const Size.fromHeight(48),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveDisplayName(AccountController controller) async {
    final name = _displayNameController.text.trim();
    if (name.length < 2 || name.length > 80) {
      _showMessage('Use a display name between 2 and 80 characters.');
      return;
    }
    final saved = await controller.updateDisplayName(name);
    if (!mounted || !saved) return;
    setState(() => _editing = false);
    _showMessage('Profile updated.');
  }

  Future<void> _chooseAvatar(AccountController controller) async {
    final image = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 88,
    );
    if (image == null || !mounted) return;
    final bytes = await image.readAsBytes();
    final mimeType = image.mimeType ?? _mimeFromName(image.name);
    final uploaded = await controller.uploadAvatar(bytes, mimeType);
    if (!mounted || !uploaded) return;
    _showMessage('Profile photo updated.');
  }

  String _mimeFromName(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }

  Future<void> _showDeletionDialog(AccountController controller) async {
    final password = TextEditingController();
    final confirmation = TextEditingController();
    var obscure = true;
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Schedule account deletion?'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Your account will be disabled now and permanently deleted after 14 days. You can recover it during the grace period by signing in and confirming recovery.',
                ),
                const SizedBox(height: 12),
                const Text(
                  'Private saves, preferences, drafts, notifications and your avatar will be deleted. Approved public content may be retained only after full anonymization.',
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: password,
                  obscureText: obscure,
                  autofillHints: const [AutofillHints.password],
                  decoration: InputDecoration(
                    labelText: 'Current password',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      onPressed: () => setDialogState(() => obscure = !obscure),
                      icon: Icon(
                        obscure ? Icons.visibility : Icons.visibility_off,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: confirmation,
                  decoration: const InputDecoration(
                    labelText: 'Type DELETE to confirm',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Keep account'),
            ),
            FilledButton(
              onPressed: () {
                if (password.text.isEmpty || confirmation.text != 'DELETE') {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(
                      content: Text('Enter your password and type DELETE.'),
                    ),
                  );
                  return;
                }
                Navigator.pop(dialogContext, true);
              },
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
              child: const Text('Schedule deletion'),
            ),
          ],
        ),
      ),
    );
    final enteredPassword = password.text;
    password.dispose();
    confirmation.dispose();
    if (shouldDelete != true || !mounted) return;
    final requested = await controller.requestDeletion(enteredPassword);
    if (!mounted || !requested) return;
    _showMessage('Account deletion scheduled.');
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  String _roleLabel(String role) {
    return switch (role) {
      'admin' => 'Administrator',
      'influencer' => 'Creator',
      _ => 'Tourist',
    };
  }
}

class _GuestAccountPrompt extends StatelessWidget {
  const _GuestAccountPrompt();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F5F0),
      appBar: AppBar(
        title: const Text('Your account'),
        backgroundColor: const Color(0xFFF7F5F0),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.person_outline,
                  size: 56,
                  color: AppColors.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  'Sign in for personal features',
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Browsing stays public. Sign in to save places, create itineraries, review, submit and manage your account.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () => Navigator.pushNamed(context, '/login'),
                  child: const Text('Sign in'),
                ),
                TextButton(
                  onPressed: () => Navigator.pushNamed(context, '/register'),
                  child: const Text('Create account'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
  }
}
