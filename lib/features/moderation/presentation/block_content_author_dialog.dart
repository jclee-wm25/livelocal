import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'moderation_controller.dart';

Future<bool> showBlockContentAuthorDialog(
  BuildContext context, {
  required String targetType,
  required String targetId,
}) async {
  final controller = context.read<ModerationController>();
  if (!controller.supportsUserBlocking) return false;

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Block this account?'),
      content: const Text(
        'You will no longer see this account’s public reviews, spots, or '
        'restaurant listings. They will not be notified. You can undo this '
        'from your account settings.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('Block account'),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return false;

  final blocked = await controller.blockContentAuthor(
    targetType: targetType,
    targetId: targetId,
  );
  if (!context.mounted) return blocked;
  final displayName = controller.lastBlock?.displayName;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        blocked
            ? '${displayName ?? 'Account'} blocked. Their public content is hidden for you.'
            : controller.errorMessage ?? 'The account could not be blocked.',
      ),
    ),
  );
  return blocked;
}
