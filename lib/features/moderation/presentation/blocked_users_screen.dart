import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../shared/presentation/app_state_view.dart';
import 'moderation_controller.dart';

class BlockedUsersScreen extends StatefulWidget {
  const BlockedUsersScreen({super.key});

  @override
  State<BlockedUsersScreen> createState() => _BlockedUsersScreenState();
}

class _BlockedUsersScreenState extends State<BlockedUsersScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<ModerationController>().loadBlockedUsers();
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ModerationController>();
    return Scaffold(
      appBar: AppBar(title: const Text('Blocked accounts')),
      body: Builder(
        builder: (context) {
          if (!controller.supportsUserBlocking) {
            return const AppStateView(
              icon: Icons.block_outlined,
              title: 'Unavailable in demo',
              message: 'Account blocking requires the secure Supabase backend.',
            );
          }
          if (controller.isLoading && controller.blockedUsers.isEmpty) {
            return const AppLoadingList();
          }
          if (controller.errorMessage != null &&
              controller.blockedUsers.isEmpty) {
            return AppStateView(
              icon: Icons.cloud_off_outlined,
              title: 'Blocked accounts unavailable',
              message: controller.errorMessage!,
              actionLabel: 'Try again',
              onAction: controller.loadBlockedUsers,
            );
          }
          if (controller.blockedUsers.isEmpty) {
            return const AppStateView(
              icon: Icons.person_off_outlined,
              title: 'No blocked accounts',
              message: 'Accounts you block from public content appear here.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: controller.blockedUsers.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final blocked = controller.blockedUsers[index];
              return Card(
                child: ListTile(
                  minTileHeight: 64,
                  leading: const CircleAvatar(
                    child: Icon(Icons.person_off_outlined),
                  ),
                  title: Text(blocked.displayName),
                  subtitle: const Text('Their public content is hidden'),
                  trailing: TextButton(
                    onPressed: controller.isLoading
                        ? null
                        : () => _unblock(controller, blocked.userId),
                    child: const Text('Unblock'),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _unblock(
    ModerationController controller,
    String userId,
  ) async {
    final restored = await controller.unblockUser(userId);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          restored
              ? 'Account unblocked. Refresh discovery to see their content.'
              : controller.errorMessage ??
                  'The account could not be unblocked.',
        ),
      ),
    );
  }
}
