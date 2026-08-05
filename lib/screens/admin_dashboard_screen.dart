import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../constants/app_colors.dart';
import '../controllers/admin_controller.dart';
import '../controllers/auth_controller.dart';
import '../controllers/spot_controller.dart';
import '../controllers/localeats_controller.dart';
import '../features/admin/domain/admin_repository.dart';
import '../features/influencer_applications/domain/influencer_application_repository.dart';
import '../features/influencer_applications/presentation/influencer_application_controller.dart';
import '../models/spot_model.dart';
import '../models/restaurant_model.dart';
import '../controllers/guide_controller.dart';
import '../features/guides/presentation/admin_guide_editor_screen.dart';
import '../models/guide_model.dart';

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
      context.read<InfluencerApplicationController>().loadPending(),
      context.read<LocalEatsController>().loadPendingRestaurants(),
      context.read<GuideController>().loadAdminDrafts(),
      context.read<GuideController>().loadGuides(),
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
    final applications = context.watch<InfluencerApplicationController>();
    final localEats = context.watch<LocalEatsController>();
    final guides = context.watch<GuideController>();
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
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => const AdminGuideEditorScreen(),
                ),
              ),
              icon: const Icon(Icons.add_road_outlined),
              label: const Text('Create guide draft'),
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
            if (admin.statistics != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _MetricCard(
                      label: 'Published spots',
                      value: admin.statistics!.spotsPublished,
                      icon: Icons.place_outlined,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _MetricCard(
                      label: 'Published eats',
                      value: admin.statistics!.restaurantsPublished,
                      icon: Icons.restaurant_outlined,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _MetricCard(
                    label: 'Creator queue',
                    value: applications.pending.length,
                    icon: Icons.verified_user_outlined,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _MetricCard(
                    label: 'Restaurant queue',
                    value: localEats.pendingRestaurants.length,
                    icon: Icons.restaurant_outlined,
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
                    label: 'Appeals',
                    value: admin.appeals.length,
                    icon: Icons.support_agent_outlined,
                  ),
                ),
              ],
            ),
            if (admin.errorMessage != null ||
                spots.errorMessage != null ||
                applications.errorMessage != null ||
                localEats.errorMessage != null ||
                guides.errorMessage != null) ...[
              const SizedBox(height: 16),
              _ErrorPanel(
                message: admin.errorMessage ??
                    spots.errorMessage ??
                    applications.errorMessage ??
                    localEats.errorMessage ??
                    guides.errorMessage!,
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
              title: 'Guide drafts',
              count: guides.adminDrafts.length,
              emptyText: 'No guide drafts are awaiting publication.',
              children: guides.adminDrafts
                  .map(
                    (guide) => ListTile(
                      minTileHeight: 72,
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.route_outlined),
                      title: Text(guide.title),
                      subtitle: Text(
                        '${guide.locationName}, ${guide.state} · ${guide.stops.length} stops',
                      ),
                      trailing: FilledButton.tonal(
                        onPressed: () => _publishGuide(guide),
                        child: const Text('Publish'),
                      ),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 16),
            _Section(
              title: 'Published guides',
              count: guides.guides.length,
              emptyText: 'No neighbourhood guides are currently published.',
              children: guides.guides
                  .map(
                    (guide) => ListTile(
                      minTileHeight: 72,
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.map_outlined),
                      title: Text(guide.title),
                      subtitle: Text('${guide.locationName}, ${guide.state}'),
                      trailing: PopupMenuButton<String>(
                        tooltip: 'Manage guide',
                        onSelected: (action) {
                          if (action == 'revise') {
                            Navigator.push(
                              context,
                              MaterialPageRoute<void>(
                                builder: (_) => AdminGuideEditorScreen(
                                  guide: guide,
                                ),
                              ),
                            );
                          } else {
                            _archiveGuide(guide);
                          }
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(
                            value: 'revise',
                            child: Text('Create revision'),
                          ),
                          PopupMenuItem(
                            value: 'archive',
                            child: Text('Archive guide'),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 16),
            _Section(
              title: 'Creator applications',
              count: applications.pending.length,
              emptyText: 'No creator applications are awaiting review.',
              children: applications.pending
                  .map(
                    (application) => ListTile(
                      minTileHeight: 72,
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.person_search_outlined),
                      title:
                          Text(application.displayName ?? 'Unnamed applicant'),
                      subtitle: Text(
                        '${application.socialPlatform ?? 'No platform'} · ${application.followerCount ?? 0} followers\n${application.contentCategory ?? 'No category'}',
                      ),
                      isThreeLine: true,
                      trailing: PopupMenuButton<String>(
                        tooltip: 'Decide creator application',
                        onSelected: (decision) =>
                            _showCreatorDecision(application, decision),
                        itemBuilder: (_) => const [
                          PopupMenuItem(
                            value: 'approved',
                            child: Text('Approve creator'),
                          ),
                          PopupMenuItem(
                            value: 'needs_information',
                            child: Text('Request information'),
                          ),
                          PopupMenuItem(
                            value: 'rejected',
                            child: Text('Reject application'),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 16),
            _Section(
              title: 'Restaurant submissions',
              count: localEats.pendingRestaurants.length,
              emptyText: 'No restaurant submissions are awaiting review.',
              children: localEats.pendingRestaurants
                  .map(
                    (restaurant) => ListTile(
                      minTileHeight: 72,
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.add_business_outlined),
                      title: Text(restaurant.name),
                      subtitle: Text(
                        '${restaurant.cuisineType} · ${restaurant.city}, ${restaurant.state}\n${restaurant.address}',
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: PopupMenuButton<String>(
                        tooltip: 'Moderate restaurant',
                        onSelected: (decision) =>
                            _showRestaurantDecision(restaurant, decision),
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
                      trailing: PopupMenuButton<String>(
                        tooltip: 'Decide report',
                        onSelected: (decision) =>
                            _showReportDecision(moderationCase, decision),
                        itemBuilder: (_) => [
                          PopupMenuItem(
                            value: 'upheld',
                            child: Text(
                              moderationCase.reason == 'broken_link'
                                  ? 'Uphold and remove link'
                                  : 'Uphold and remove content',
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'dismissed',
                            child: Text('Dismiss report'),
                          ),
                          const PopupMenuItem(
                            value: 'escalated',
                            child: Text('Escalate'),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 16),
            _Section(
              title: 'Account appeals',
              count: admin.appeals.length,
              emptyText: 'No account appeals are awaiting review.',
              children: admin.appeals
                  .map(
                    (appeal) => ListTile(
                      minTileHeight: 80,
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.support_agent_outlined),
                      title: Text(appeal.displayName),
                      subtitle: Text(
                        '${appeal.email}\n${appeal.accessStatus} · ${appeal.reason}'
                        '${appeal.explanation == null ? '' : '\n${appeal.explanation}'}',
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                      ),
                      isThreeLine: true,
                      trailing: PopupMenuButton<String>(
                        tooltip: 'Decide appeal',
                        onSelected: (decision) =>
                            _showAppealDecision(appeal, decision),
                        itemBuilder: (_) => const [
                          PopupMenuItem(
                            value: 'upheld',
                            child: Text('Accept and restore access'),
                          ),
                          PopupMenuItem(
                            value: 'dismissed',
                            child: Text('Do not accept'),
                          ),
                        ],
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
            const SizedBox(height: 16),
            _Section(
              title: 'Recent audit history',
              count: admin.auditEvents.length,
              emptyText: 'No audit events are available.',
              children: admin.auditEvents
                  .map(
                    (event) => ListTile(
                      minTileHeight: 72,
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.history_outlined),
                      title: Text(event.action.replaceAll('.', ' · ')),
                      subtitle: Text(
                        '${event.actorName} · ${event.targetType}${event.reason == null ? '' : '\n${event.reason}'}',
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      isThreeLine: event.reason != null,
                    ),
                  )
                  .toList(),
            ),
            if (admin.isLoading ||
                spots.isLoading ||
                applications.isLoading ||
                localEats.isLoading ||
                guides.isLoading) ...[
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

  Future<void> _showCreatorDecision(
    InfluencerApplication application,
    String decision,
  ) async {
    final reason = await _reasonDialog(
      title: switch (decision) {
        'approved' => 'Approve creator application?',
        'needs_information' => 'Request more information?',
        _ => 'Reject creator application?',
      },
      prompt: decision == 'approved'
          ? 'Record why the creator account meets the current rules.'
          : 'Explain the decision clearly enough for the applicant to act on it.',
      destructive: decision == 'rejected',
    );
    if (reason == null || !mounted) return;
    final saved = await context
        .read<InfluencerApplicationController>()
        .decide(application, decision, reason);
    if (!mounted) return;
    _message(
      saved
          ? 'Creator application decision recorded.'
          : context.read<InfluencerApplicationController>().errorMessage ??
              'The application decision could not be saved.',
    );
  }

  Future<void> _publishGuide(GuideModel guide) async {
    final reason = await _reasonDialog(
      title: 'Publish this guide?',
      prompt:
          'Confirm that the route, public locations, and walking instructions have been checked.',
      destructive: false,
    );
    if (reason == null || !mounted) return;
    final saved =
        await context.read<GuideController>().publishDraft(guide, reason);
    if (!mounted) return;
    _message(
      saved
          ? 'Guide published.'
          : context.read<GuideController>().errorMessage ??
              'The guide could not be published.',
    );
  }

  Future<void> _archiveGuide(GuideModel guide) async {
    final reason = await _reasonDialog(
      title: 'Archive this guide?',
      prompt:
          'The guide will stop appearing publicly. Record why the route is no longer suitable.',
      destructive: true,
    );
    if (reason == null || !mounted) return;
    final saved =
        await context.read<GuideController>().archiveGuide(guide, reason);
    if (!mounted) return;
    _message(
      saved
          ? 'Guide archived.'
          : context.read<GuideController>().errorMessage ??
              'The guide could not be archived.',
    );
  }

  Future<void> _showRestaurantDecision(
    RestaurantModel restaurant,
    String decision,
  ) async {
    final reason = await _reasonDialog(
      title: decision == 'approved'
          ? 'Approve restaurant listing?'
          : 'Reject restaurant listing?',
      prompt: decision == 'approved'
          ? 'Record why the business details and supporting post are suitable.'
          : 'Explain what must be corrected before resubmission.',
      destructive: decision == 'rejected',
    );
    if (reason == null || !mounted) return;
    final saved = await context
        .read<LocalEatsController>()
        .moderateRestaurant(restaurant, decision, reason);
    if (!mounted) return;
    _message(
      saved
          ? 'Restaurant moderation decision recorded.'
          : context.read<LocalEatsController>().errorMessage ??
              'The restaurant decision could not be saved.',
    );
  }

  Future<void> _showReportDecision(
    AdminModerationCase moderationCase,
    String decision,
  ) async {
    final reason = await _reasonDialog(
      title: switch (decision) {
        'upheld' => moderationCase.reason == 'broken_link'
            ? 'Remove the reported external link?'
            : 'Remove the reported content?',
        'dismissed' => 'Dismiss this report?',
        _ => 'Escalate this report?',
      },
      prompt: 'Record the evidence-based reason for this decision.',
      destructive: decision == 'upheld',
    );
    if (reason == null || !mounted) return;
    final saved = await context.read<AdminController>().decideModerationCase(
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

  Future<void> _showAppealDecision(
    AdminAppealCase appeal,
    String decision,
  ) async {
    final reason = await _reasonDialog(
      title: decision == 'upheld'
          ? 'Accept this appeal and restore access?'
          : 'Do not accept this appeal?',
      prompt:
          'Record the evidence-based outcome. This will be shown in the appeal history.',
      destructive: decision == 'dismissed',
    );
    if (reason == null || !mounted) return;
    final saved = await context.read<AdminController>().decideAppeal(
          appeal: appeal,
          decision: decision,
          reason: reason,
        );
    if (!mounted) return;
    _message(
      saved
          ? 'Appeal decision recorded.'
          : context.read<AdminController>().errorMessage ??
              'The appeal decision could not be saved.',
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
