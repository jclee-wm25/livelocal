import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'moderation_controller.dart';

Future<bool> showContentReportDialog(
  BuildContext context, {
  required String targetType,
  required String targetId,
  bool brokenLinkOnly = false,
}) async {
  var reason = brokenLinkOnly ? 'broken_link' : 'misleading';
  var hideForMe = !brokenLinkOnly;
  final explanation = TextEditingController();
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: Text(brokenLinkOnly ? 'Report broken link' : 'Report content'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!brokenLinkOnly)
                DropdownButtonFormField<String>(
                  initialValue: reason,
                  decoration: const InputDecoration(
                    labelText: 'Reason',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                        value: 'misleading', child: Text('Misleading')),
                    DropdownMenuItem(
                        value: 'closed', child: Text('Place has closed')),
                    DropdownMenuItem(value: 'spam', child: Text('Spam')),
                    DropdownMenuItem(
                        value: 'dangerous', child: Text('Safety concern')),
                    DropdownMenuItem(
                        value: 'privacy', child: Text('Privacy concern')),
                    DropdownMenuItem(value: 'other', child: Text('Other')),
                  ],
                  onChanged: (value) {
                    if (value != null) setDialogState(() => reason = value);
                  },
                ),
              if (!brokenLinkOnly) const SizedBox(height: 12),
              TextField(
                controller: explanation,
                onChanged: brokenLinkOnly ? (_) => setDialogState(() {}) : null,
                maxLength: 2000,
                minLines: 3,
                maxLines: 6,
                decoration: InputDecoration(
                  labelText: brokenLinkOnly
                      ? 'What happens when you open it?'
                      : 'Additional context (optional)',
                  alignLabelWithHint: true,
                  border: const OutlineInputBorder(),
                ),
              ),
              if (!brokenLinkOnly)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: hideForMe,
                  title: const Text('Hide this content for me'),
                  subtitle: const Text(
                    'A report does not hide content for everyone before review.',
                  ),
                  onChanged: (value) =>
                      setDialogState(() => hideForMe = value ?? true),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: brokenLinkOnly && explanation.text.trim().length < 3
                ? null
                : () => Navigator.pop(dialogContext, true),
            child: const Text('Submit report'),
          ),
        ],
      ),
    ),
  );
  final enteredExplanation = explanation.text.trim();
  explanation.dispose();
  if (confirmed != true || !context.mounted) return false;
  final controller = context.read<ModerationController>();
  final saved = await controller.reportContent(
    targetType: targetType,
    targetId: targetId,
    reason: reason,
    explanation: enteredExplanation.isEmpty ? null : enteredExplanation,
    hideForReporter: hideForMe,
  );
  if (!context.mounted) return saved;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        saved
            ? 'Report submitted for moderation.'
            : controller.errorMessage ?? 'The report could not be submitted.',
      ),
    ),
  );
  return saved;
}
