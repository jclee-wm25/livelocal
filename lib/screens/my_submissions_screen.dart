import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/auth_controller.dart';
import '../controllers/localeats_controller.dart';
import '../controllers/spot_controller.dart';
import '../features/restaurants/domain/local_eats_repository.dart';
import '../features/spots/domain/spot_repository.dart';
import '../models/restaurant_model.dart';
import '../models/spot_model.dart';
import 'add_restaurant_screen.dart';
import 'submit_spot_screen.dart';

class MySubmissionsScreen extends StatefulWidget {
  const MySubmissionsScreen({super.key});

  @override
  State<MySubmissionsScreen> createState() => _MySubmissionsScreenState();
}

class _MySubmissionsScreenState extends State<MySubmissionsScreen> {
  bool _loading = true;

  bool get _isCreator =>
      context.read<AuthController>().currentUser?.role == 'influencer';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    final futures = <Future<void>>[
      context.read<SpotController>().loadOwnedSubmissions(),
    ];
    if (_isCreator) {
      futures.add(
        context.read<LocalEatsController>().loadOwnedRestaurantSubmissions(),
      );
    }
    await Future.wait(futures);
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final spots = context.watch<SpotController>();
    final restaurants = context.watch<LocalEatsController>();
    return Scaffold(
      appBar: AppBar(title: const Text('Your submissions')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
          children: [
            Text(
              'Manage reviewable content',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            const Text(
              'Edits to approved content create a new revision. The last approved version stays public until an administrator approves the change.',
            ),
            if (_loading) ...[
              const SizedBox(height: 32),
              const Center(child: CircularProgressIndicator()),
            ] else ...[
              const SizedBox(height: 24),
              _SectionHeader(
                title: 'Local spots',
                count: spots.ownedSubmissions.length,
              ),
              const SizedBox(height: 8),
              if (spots.ownedSubmissions.isEmpty)
                const _EmptyCard(
                  message: 'You have not submitted a local spot yet.',
                )
              else
                ...spots.ownedSubmissions.map(
                  (spot) => _SubmissionCard(
                    title: spot.name,
                    subtitle: '${spot.city}, ${spot.state}',
                    status: spot.status,
                    reason: spot.decisionReason,
                    onEdit: () => _editSpot(spot),
                    onWithdraw: _isAwaitingReview(spot.status)
                        ? () => _withdrawSpot(spot)
                        : null,
                    onDiscard: spot.status == 'draft'
                        ? () => _discardSpot(spot)
                        : null,
                  ),
                ),
              if (_isCreator) ...[
                const SizedBox(height: 24),
                _SectionHeader(
                  title: 'Restaurants',
                  count: restaurants.ownedRestaurantSubmissions.length,
                ),
                const SizedBox(height: 8),
                if (restaurants.ownedRestaurantSubmissions.isEmpty)
                  const _EmptyCard(
                    message: 'You have not submitted a restaurant yet.',
                  )
                else
                  ...restaurants.ownedRestaurantSubmissions.map(
                    (restaurant) => _SubmissionCard(
                      title: restaurant.name,
                      subtitle: '${restaurant.city}, ${restaurant.state}',
                      status: restaurant.status,
                      reason: restaurant.decisionReason,
                      onEdit: () => _editRestaurant(restaurant),
                      onWithdraw: _isAwaitingReview(restaurant.status)
                          ? () => _withdrawRestaurant(restaurant)
                          : null,
                      onDiscard: restaurant.status == 'draft'
                          ? () => _discardRestaurant(restaurant)
                          : null,
                    ),
                  ),
              ],
              if (spots.errorMessage != null ||
                  (_isCreator && restaurants.errorMessage != null)) ...[
                const SizedBox(height: 16),
                _ErrorCard(
                  message: spots.errorMessage ?? restaurants.errorMessage!,
                  onRetry: _load,
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  bool _isAwaitingReview(String status) =>
      status == 'submitted' || status == 'under_review';

  Future<void> _editSpot(SpotModel spot) async {
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => SubmitSpotScreen(source: spot),
      ),
    );
    await _load();
  }

  Future<void> _editRestaurant(RestaurantModel restaurant) async {
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => AddRestaurantScreen(source: restaurant),
      ),
    );
    await _load();
  }

  Future<void> _withdrawSpot(SpotModel spot) async {
    final confirmed = await _confirm(
      title: 'Withdraw this submission?',
      body: spot.hasApprovedRevision
          ? 'The approved version will remain public. This pending revision will stay in history.'
          : 'This submission will leave the review queue. You can revise and resubmit it later.',
      action: 'Withdraw',
    );
    if (!mounted || !confirmed) return;
    final saved = await context.read<SpotController>().withdrawSubmission(spot);
    if (!mounted) return;
    _message(saved ? 'Spot submission withdrawn.' : 'Withdrawal failed.');
    await _load();
  }

  Future<void> _withdrawRestaurant(RestaurantModel restaurant) async {
    final confirmed = await _confirm(
      title: 'Withdraw this restaurant revision?',
      body: restaurant.hasApprovedRevision
          ? 'The approved listing will remain public. This pending revision will stay in history.'
          : 'This submission will leave the review queue. You can revise and resubmit it later.',
      action: 'Withdraw',
    );
    if (!mounted || !confirmed) return;
    final saved = await context
        .read<LocalEatsController>()
        .withdrawRestaurantSubmission(restaurant);
    if (!mounted) return;
    _message(saved ? 'Restaurant submission withdrawn.' : 'Withdrawal failed.');
    await _load();
  }

  Future<void> _discardSpot(SpotModel spot) async {
    final confirmed = await _confirm(
      title: 'Discard this draft?',
      body: spot.hasApprovedRevision
          ? 'The draft and any unshared replacement photo will be removed. The approved version stays public.'
          : 'This private draft and its uploaded photo will be permanently removed.',
      action: 'Discard draft',
      destructive: true,
    );
    if (!mounted || !confirmed) return;
    final revisionId = spot.revisionId;
    if (revisionId == null) return;
    final saved = await context.read<SpotController>().discardDraft(
          SpotDraftResult(
            spotId: spot.id,
            revisionId: revisionId,
            probableDuplicates: const [],
            imagePath: spot.imagePath,
          ),
        );
    if (!mounted) return;
    _message(saved ? 'Spot draft discarded.' : 'The draft was not discarded.');
    await _load();
  }

  Future<void> _discardRestaurant(RestaurantModel restaurant) async {
    final confirmed = await _confirm(
      title: 'Discard this restaurant draft?',
      body: restaurant.hasApprovedRevision
          ? 'The draft and any unshared replacement photo will be removed. The approved listing stays public.'
          : 'This private draft and its uploaded photo will be permanently removed.',
      action: 'Discard draft',
      destructive: true,
    );
    if (!mounted || !confirmed) return;
    final revisionId = restaurant.revisionId;
    if (revisionId == null) return;
    final saved =
        await context.read<LocalEatsController>().resolveRestaurantDuplicate(
              RestaurantDraftResult(
                restaurantId: restaurant.id,
                revisionId: revisionId,
                probableDuplicates: const [],
                imagePath: restaurant.coverImagePath,
              ),
              discard: true,
            );
    if (!mounted) return;
    _message(
      saved ? 'Restaurant draft discarded.' : 'The draft was not discarded.',
    );
    await _load();
  }

  Future<bool> _confirm({
    required String title,
    required String body,
    required String action,
    bool destructive = false,
  }) async {
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(title),
            content: Text(body),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                style: destructive
                    ? FilledButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.error,
                      )
                    : null,
                onPressed: () => Navigator.pop(dialogContext, true),
                child: Text(action),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _message(String value) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.count});

  final String title;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.titleLarge),
        ),
        Semantics(
            label: '$count submissions', child: Chip(label: Text('$count'))),
      ],
    );
  }
}

class _SubmissionCard extends StatelessWidget {
  const _SubmissionCard({
    required this.title,
    required this.subtitle,
    required this.status,
    required this.onEdit,
    this.reason,
    this.onWithdraw,
    this.onDiscard,
  });

  final String title;
  final String subtitle;
  final String status;
  final String? reason;
  final VoidCallback onEdit;
  final VoidCallback? onWithdraw;
  final VoidCallback? onDiscard;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 4),
                      Text(subtitle),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Chip(label: Text(_statusLabel(status))),
              ],
            ),
            const SizedBox(height: 8),
            Text(_statusExplanation(status)),
            if (reason?.isNotEmpty == true) ...[
              const SizedBox(height: 8),
              Text('Decision reason: $reason'),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.tonal(
                  onPressed: onEdit,
                  child: Text(
                    _isAwaiting(status)
                        ? 'Withdraw and edit'
                        : status == 'draft'
                            ? 'Continue editing'
                            : 'Create revision',
                  ),
                ),
                if (onWithdraw != null)
                  TextButton(
                    onPressed: onWithdraw,
                    child: const Text('Withdraw'),
                  ),
                if (onDiscard != null)
                  TextButton(
                    onPressed: onDiscard,
                    child: const Text('Discard draft'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static bool _isAwaiting(String status) =>
      status == 'submitted' || status == 'under_review';

  static String _statusLabel(String status) => switch (status) {
        'draft' => 'Draft',
        'submitted' => 'Submitted',
        'under_review' => 'Under review',
        'approved' => 'Approved',
        'rejected' => 'Rejected',
        'withdrawn' => 'Withdrawn',
        _ => 'Archived',
      };

  static String _statusExplanation(String status) => switch (status) {
        'draft' => 'Private. Continue editing, submit, or discard it.',
        'submitted' => 'Waiting for an administrator to begin review.',
        'under_review' => 'An administrator is reviewing this revision.',
        'approved' => 'Published. Material changes require another review.',
        'rejected' => 'Not published. Revise the content before resubmitting.',
        'withdrawn' => 'Removed from the review queue by you.',
        _ => 'Read-only historical revision.',
      };
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            const Icon(Icons.inbox_outlined),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.errorContainer,
      child: ListTile(
        leading: const Icon(Icons.error_outline),
        title: const Text('Submissions could not be refreshed'),
        subtitle: Text(message),
        trailing: TextButton(onPressed: onRetry, child: const Text('Retry')),
      ),
    );
  }
}
