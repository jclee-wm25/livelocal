import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../constants/app_colors.dart';
import '../controllers/admin_controller.dart';
import '../controllers/auth_controller.dart';
import '../controllers/spot_controller.dart';
import '../features/admin/domain/admin_repository.dart';
import '../models/spot_model.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    if (!mounted) return;
    final auth = context.read<AuthController>();
    if (auth.currentUser?.role != 'admin') return;
    await Future.wait([
      context.read<AdminController>().loadDashboard(),
      context.read<SpotController>().loadPendingSpots(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    if (auth.currentUser?.role != 'admin') {
      return const Scaffold(
        body: Center(child: Text('Administrator permission is required.')),
      );
    }
    final admin = context.watch<AdminController>();
    final spots = context.watch<SpotController>();
    return Scaffold(
      backgroundColor: const Color(0xFFF7F5F0),
      appBar: AppBar(
        title: const Text('Admin dashboard'),
        backgroundColor: const Color(0xFFF7F5F0),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
          children: [
            Text(
              'Platform operations',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            const Text(
              'Every decision requires a reason and is checked again by the backend.',
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _MetricCard(
                    label: 'Spot queue',
                    value: spots.pendingSpots.length,
                    icon: Icons.place_outlined,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _MetricCard(
                    label: 'Report queue',
                    value: admin.moderationCases.length,
                    icon: Icons.flag_outlined,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _MetricCard(
                    label: 'Accounts',
                    value: admin.totalUsers,
                    icon: Icons.people_outline,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _MetricCard(
                    label: 'Restricted',
                    value: admin.suspendedUsersCount,
                    icon: Icons.gpp_maybe_outlined,
                  ),
                ),
              ],
            ),
            if (admin.errorMessage != null || spots.errorMessage != null) ...[
              const SizedBox(height: 16),
              _ErrorPanel(
                message: admin.errorMessage ?? spots.errorMessage!,
                onRetry: _load,
              ),
            ],
            const SizedBox(height: 24),
            _Section(
              title: 'Spot submissions',
              count: spots.pendingSpots.length,
              emptyText: 'No spot submissions are awaiting review.',
              children: spots.pendingSpots
                  .map(
                    (spot) => ListTile(
                      minTileHeight: 64,
                      contentPadding: EdgeInsets.zero,
                      title: Text(spot.name),
                      subtitle: Text(
                          '${spot.category} · ${spot.city}, ${spot.state}'),
                      trailing: PopupMenuButton<String>(
                        tooltip: 'Moderate ${spot.name}',
                        onSelected: (decision) =>
                            _showSpotDecision(spot, decision),
                        itemBuilder: (_) => const [
                          PopupMenuItem(
                            value: 'approved',
                            child: Text('Approve'),
                          ),
                          PopupMenuItem(
                            value: 'rejected',
                            child: Text('Reject'),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 16),
            _Section(
              title: 'Content reports',
              count: admin.moderationCases.length,
              emptyText: 'No reports are awaiting moderation.',
              children: admin.moderationCases
                  .map(
                    (moderationCase) => ListTile(
                      minTileHeight: 72,
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.flag_outlined),
                      title: Text(
                        '${moderationCase.targetType}: ${moderationCase.targetPreview}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        '${moderationCase.reason}${moderationCase.explanation == null ? '' : ' · ${moderationCase.explanation}'}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: moderationCase.targetType == 'review'
                          ? PopupMenuButton<String>(
                              tooltip: 'Decide report',
                              onSelected: (decision) =>
                                  _showReportDecision(moderationCase, decision),
                              itemBuilder: (_) => const [
                                PopupMenuItem(
                                  value: 'upheld',
                                  child: Text('Uphold and remove review'),
                                ),
                                PopupMenuItem(
                                  value: 'dismissed',
                                  child: Text('Dismiss report'),
                                ),
                                PopupMenuItem(
                                  value: 'escalated',
                                  child: Text('Escalate'),
                                ),
                              ],
                            )
                          : const Tooltip(
                              message:
                                  'This report type requires its feature moderation workflow.',
                              child: Icon(Icons.pending_outlined),
                            ),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 16),
            _Section(
              title: 'Account access',
              count: admin.accounts.length,
              emptyText: 'No accounts are available.',
              children: admin.accounts
                  .map(
                    (account) => ListTile(
                      minTileHeight: 72,
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        child: Text(
                          account.displayName.isEmpty
                              ? '?'
                              : account.displayName[0].toUpperCase(),
                        ),
                      ),
                      title: Text(account.displayName),
                      subtitle: Text(
                        '${account.email}\n${account.role} · ${account.accessStatus}',
                      ),
                      isThreeLine: true,
                      trailing: account.id == auth.currentUser!.id
                          ? const Tooltip(
                              message: 'You cannot change your own access.',
                              child: Icon(Icons.lock_outline),
                            )
                          : PopupMenuButton<String>(
                              tooltip: 'Change account access',
                              onSelected: (status) =>
                                  _showAccountDecision(account, status),
                              itemBuilder: (_) => [
                                if (account.accessStatus != 'active')
                                  const PopupMenuItem(
                                    value: 'active',
                                    child: Text('Restore access'),
                                  ),
                                if (account.accessStatus == 'active') ...[
                                  const PopupMenuItem(
                                    value: 'restricted',
                                    child: Text('Temporarily restrict'),
                                  ),
                                  const PopupMenuItem(
                                    value: 'banned',
                                    child: Text('Permanently ban'),
                                  ),
                                ],
                              ],
                            ),
                    ),
                  )
                  .toList(),
            ),
            if (admin.isLoading || spots.isLoading) ...[
              const SizedBox(height: 24),
              const Center(child: CircularProgressIndicator()),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _showSpotDecision(SpotModel spot, String decision) async {
    final reason = await _reasonDialog(
      title: decision == 'approved' ? 'Approve spot?' : 'Reject spot?',
      prompt: decision == 'approved'
          ? 'Record why this submission meets publication guidelines.'
          : 'Explain what the owner must correct before resubmitting.',
      destructive: decision == 'rejected',
    );
    if (reason == null || !mounted) return;
    try {
      if (decision == 'approved') {
        await context
            .read<SpotController>()
            .approveSpotWithReason(spot, reason);
      } else {
        await context.read<SpotController>().rejectSpot(spot, reason);
      }
      if (mounted) _message('Spot decision recorded.');
    } catch (_) {
      if (mounted) {
        _message(context.read<SpotController>().errorMessage ??
            'The spot decision could not be saved.');
      }
    }
  }

  Future<void> _showReportDecision(
    AdminModerationCase moderationCase,
    String decision,
  ) async {
    final reason = await _reasonDialog(
      title: switch (decision) {
        'upheld' => 'Remove reported review?',
        'dismissed' => 'Dismiss this report?',
        _ => 'Escalate this report?',
      },
      prompt: 'Record the evidence-based reason for this decision.',
      destructive: decision == 'upheld',
    );
    if (reason == null || !mounted) return;
    final saved = await context.read<AdminController>().decideReviewCase(
          moderationCase: moderationCase,
          decision: decision,
          reason: reason,
        );
    if (!mounted) return;
    _message(
      saved
          ? 'Moderation decision recorded.'
          : context.read<AdminController>().errorMessage ??
              'The decision could not be saved.',
    );
  }

  Future<void> _showAccountDecision(
    AdminAccountSummary account,
    String status,
  ) async {
    final publicMessage = TextEditingController();
    final internalReason = TextEditingController();
    var restrictionDays = 7;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(
            switch (status) {
              'active' => 'Restore ${account.displayName}?',
              'restricted' => 'Temporarily restrict ${account.displayName}?',
              _ => 'Permanently ban ${account.displayName}?',
            },
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (status == 'restricted')
                  DropdownButtonFormField<int>(
                    initialValue: restrictionDays,
                    decoration: const InputDecoration(
                      labelText: 'Duration',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 1, child: Text('1 day')),
                      DropdownMenuItem(value: 7, child: Text('7 days')),
                      DropdownMenuItem(value: 30, child: Text('30 days')),
                    ],
                    onChanged: (value) => setDialogState(
                      () => restrictionDays = value ?? restrictionDays,
                    ),
                  ),
                if (status != 'active') ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: publicMessage,
                    maxLength: 500,
                    decoration: const InputDecoration(
                      labelText: 'Message shown to the user',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                TextField(
                  controller: internalReason,
                  maxLength: 1000,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Internal decision reason',
                    border: OutlineInputBorder(),
                  ),
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
              onPressed: () {
                if (internalReason.text.trim().length < 3 ||
                    (status != 'active' &&
                        publicMessage.text.trim().length < 3)) {
                  return;
                }
                Navigator.pop(dialogContext, true);
              },
              style: status == 'banned'
                  ? FilledButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.error,
                    )
                  : null,
              child: const Text('Confirm'),
            ),
          ],
        ),
      ),
    );
    final external = publicMessage.text.trim();
    final internal = internalReason.text.trim();
    publicMessage.dispose();
    internalReason.dispose();
    if (confirmed != true || !mounted) return;
    final saved = await context.read<AdminController>().setAccountAccess(
          account: account,
          status: status,
          publicMessage: external,
          internalReason: internal,
          endsAt: status == 'restricted'
              ? DateTime.now().toUtc().add(Duration(days: restrictionDays))
              : null,
        );
    if (!mounted) return;
    _message(
      saved
          ? 'Account access updated.'
          : context.read<AdminController>().errorMessage ??
              'The account action could not be saved.',
    );
  }

  Future<String?> _reasonDialog({
    required String title,
    required String prompt,
    required bool destructive,
  }) async {
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(prompt),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              maxLength: 1000,
              minLines: 2,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Decision reason',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (controller.text.trim().length < 3) return;
              Navigator.pop(dialogContext, true);
            },
            style: destructive
                ? FilledButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.error,
                  )
                : null,
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    final reason = controller.text.trim();
    controller.dispose();
    return confirmed == true ? reason : null;
  }

  void _message(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final int value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: AppColors.primary),
            const SizedBox(height: 12),
            Text('$value', style: Theme.of(context).textTheme.headlineSmall),
            Text(label),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.count,
    required this.emptyText,
    required this.children,
  });

  final String title;
  final int count;
  final String emptyText;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: ExpansionTile(
        initiallyExpanded: true,
        title: Text(title),
        subtitle: Text('$count awaiting attention'),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        children: children.isEmpty
            ? [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Text(emptyText),
                ),
              ]
            : children,
      ),
    );
  }
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.errorContainer,
      elevation: 0,
      child: ListTile(
        leading: const Icon(Icons.error_outline),
        title: Text(message),
        trailing: TextButton(onPressed: onRetry, child: const Text('Retry')),
      ),
    );
  }
}
