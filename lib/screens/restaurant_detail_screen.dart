import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../constants/app_colors.dart';
import '../controllers/auth_controller.dart';
import '../controllers/localeats_controller.dart';
import '../controllers/review_controller.dart';
import '../controllers/itinerary_controller.dart';
import '../core/routing/protected_navigation.dart';
import '../core/validation/social_url_validator.dart';
import '../models/discount_code_model.dart';
import '../models/restaurant_model.dart';
import '../models/review_model.dart';
import '../features/moderation/presentation/content_report_dialog.dart';
import '../features/moderation/presentation/block_content_author_dialog.dart';
import '../features/moderation/presentation/moderation_controller.dart';

class RestaurantDetailArguments {
  const RestaurantDetailArguments({
    required this.restaurant,
    this.pendingAction,
  });

  final RestaurantModel restaurant;
  final RestaurantPendingAction? pendingAction;
}

class RestaurantPendingAction {
  const RestaurantPendingAction.save()
      : kind = 'save',
        reviewId = null;
  const RestaurantPendingAction.review()
      : kind = 'review',
        reviewId = null;

  const RestaurantPendingAction.report(this.reviewId) : kind = 'report';
  const RestaurantPendingAction.reportListing()
      : kind = 'report_listing',
        reviewId = null;
  const RestaurantPendingAction.reportLink()
      : kind = 'report_link',
        reviewId = null;
  const RestaurantPendingAction.blockReview(this.reviewId)
      : kind = 'block_review';
  const RestaurantPendingAction.blockListingAuthor()
      : kind = 'block_listing_author',
        reviewId = null;

  final String kind;
  final String? reviewId;
}

class RestaurantDetailScreen extends StatefulWidget {
  const RestaurantDetailScreen({
    super.key,
    required this.restaurant,
    this.pendingAction,
  });

  final RestaurantModel restaurant;
  final RestaurantPendingAction? pendingAction;

  @override
  State<RestaurantDetailScreen> createState() => _RestaurantDetailScreenState();
}

class _RestaurantDetailScreenState extends State<RestaurantDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await context.read<ReviewController>().loadReviews(
            restaurantId: widget.restaurant.id,
          );
      if (!mounted || widget.pendingAction == null) return;
      if (widget.pendingAction!.kind == 'save') {
        await _requestSave();
      } else if (widget.pendingAction!.kind == 'review') {
        await _requestReview();
      } else if (widget.pendingAction!.kind == 'report_listing') {
        await _requestContentReport();
      } else if (widget.pendingAction!.kind == 'report_link') {
        await _requestContentReport(brokenLink: true);
      } else if (widget.pendingAction!.kind == 'block_listing_author') {
        await _requestBlockAuthor('restaurant', widget.restaurant.id);
      } else if (widget.pendingAction!.kind == 'block_review' &&
          widget.pendingAction!.reviewId != null) {
        await _requestBlockAuthor(
          'review',
          widget.pendingAction!.reviewId!,
        );
      } else if (widget.pendingAction!.kind == 'report' &&
          widget.pendingAction!.reviewId != null) {
        await _requestReport(widget.pendingAction!.reviewId!);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final localEats = context.watch<LocalEatsController>();
    final reviewController = context.watch<ReviewController>();
    final itineraryController = context.watch<ItineraryController>();
    final supportsUserBlocking =
        context.watch<ModerationController>().supportsUserBlocking;
    final isSaved = itineraryController.isSaved(
      restaurantId: widget.restaurant.id,
    );
    final discounts = localEats.getActiveDiscountsForRestaurant(
      widget.restaurant.id,
    );
    final reviews = reviewController.getReviewsForRestaurant(
      widget.restaurant.id,
    );
    final creatorName = widget.restaurant.influencerName.trim().isEmpty
        ? 'LiveLocal'
        : widget.restaurant.influencerName.trim();

    return Scaffold(
      backgroundColor: const Color(0xFFF7F5F0),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7F5F0),
        title: const Text('Restaurant'),
        actions: [
          IconButton(
            tooltip: isSaved ? 'Remove from saved' : 'Save place',
            onPressed: _requestSave,
            icon: Icon(
              isSaved ? Icons.bookmark : Icons.bookmark_border,
            ),
          ),
          PopupMenuButton<String>(
            tooltip: 'Restaurant options',
            onSelected: (value) {
              if (value == 'report') _requestContentReport();
              if (value == 'block') {
                _requestBlockAuthor('restaurant', widget.restaurant.id);
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'report',
                child: Text('Report this listing'),
              ),
              if (supportsUserBlocking &&
                  !widget.restaurant.isOwnedByCurrentUser)
                const PopupMenuItem(
                  value: 'block',
                  child: Text('Block creator'),
                ),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await Future.wait([
            localEats.loadData(),
            reviewController.loadReviews(restaurantId: widget.restaurant.id),
          ]);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 48),
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: CachedNetworkImage(
                imageUrl: widget.restaurant.coverPhotoUrl,
                fit: BoxFit.cover,
                placeholder: (_, __) => const ColoredBox(
                  color: Color(0xFFE5E1D8),
                  child: Center(child: CircularProgressIndicator()),
                ),
                errorWidget: (_, __, ___) => const ColoredBox(
                  color: Color(0xFFE5E1D8),
                  child: Icon(Icons.restaurant_outlined, size: 64),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.restaurant.name,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${widget.restaurant.cuisineType} · ${widget.restaurant.priceRange} · ${widget.restaurant.city}',
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.star, color: Colors.amber, size: 20),
                      const SizedBox(width: 6),
                      Text(
                        widget.restaurant.reviewCount == 0
                            ? 'No community ratings yet'
                            : '${widget.restaurant.rating.toStringAsFixed(1)} from ${widget.restaurant.reviewCount} reviews',
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _InfoCard(
                    icon: Icons.location_on_outlined,
                    title: 'Address',
                    body: widget.restaurant.address,
                  ),
                  const SizedBox(height: 12),
                  _InfoCard(
                    icon: Icons.person_outline,
                    title: widget.restaurant.ownershipStatus == 'unclaimed'
                        ? 'Unclaimed public listing'
                        : 'Recommended by $creatorName',
                    body: widget.restaurant.ownershipStatus == 'unclaimed'
                        ? 'LiveLocal maintains the public business information without creator ownership.'
                        : 'The linked creator post supports this recommendation.',
                  ),
                  const SizedBox(height: 12),
                  if (widget.restaurant.socialLinkStatus == 'active') ...[
                    OutlinedButton.icon(
                      onPressed: _openSocialPost,
                      icon: const Icon(Icons.open_in_new),
                      label: const Text('Open creator post'),
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () =>
                            _requestContentReport(brokenLink: true),
                        icon: const Icon(Icons.link_off_outlined),
                        label: const Text('Report broken creator link'),
                      ),
                    ),
                  ] else
                    const _InfoCard(
                      icon: Icons.link_off_outlined,
                      title: 'Creator link unavailable',
                      body:
                          'The external link was removed after moderation. The public restaurant information remains available.',
                    ),
                  const SizedBox(height: 28),
                  Text(
                    'Recommended dishes',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(widget.restaurant.reviewedDishes),
                  if (discounts.isNotEmpty) ...[
                    const SizedBox(height: 28),
                    Text(
                      'Active offers',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    ...discounts.map(
                      (discount) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _DiscountCard(
                          discount: discount,
                          onCopy: () => _copyDiscount(discount),
                        ),
                      ),
                    ),
                    const Text(
                      'Offers are promotional information. Redemption is subject to the participating business. LiveLocal does not process payment or guarantee acceptance.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                  const SizedBox(height: 28),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Community reviews',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _requestReview,
                        icon: const Icon(Icons.rate_review_outlined),
                        label: const Text('Write or edit'),
                      ),
                    ],
                  ),
                  if (reviewController.isLoading && reviews.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (reviewController.errorMessage != null &&
                      reviews.isEmpty)
                    _InlineError(
                      message: reviewController.errorMessage!,
                      onRetry: () => reviewController.loadReviews(
                        restaurantId: widget.restaurant.id,
                      ),
                    )
                  else if (reviews.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Text('No reviews yet. Share the first review.'),
                    )
                  else
                    ...reviews.map(
                      (review) => _ReviewCard(
                        review: review,
                        onEdit:
                            review.isOwnedByCurrentUser ? _requestReview : null,
                        onDelete: review.isOwnedByCurrentUser
                            ? () => _confirmDelete(review)
                            : null,
                        onReport: review.isOwnedByCurrentUser
                            ? null
                            : () => _requestReport(review.id),
                        onBlock: review.isOwnedByCurrentUser ||
                                !supportsUserBlocking
                            ? null
                            : () => _requestBlockAuthor('review', review.id),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openSocialPost() async {
    final value = widget.restaurant.socialMediaUrl;
    if (!SocialUrlValidator.isSupported(value)) {
      _message('This creator link is invalid and cannot be opened.');
      return;
    }
    final opened = await launchUrl(
      Uri.parse(value),
      mode: LaunchMode.externalApplication,
    );
    if (!mounted || opened) return;
    _message('The creator link could not be opened on this device.');
  }

  Future<void> _requestContentReport({bool brokenLink = false}) async {
    final auth = context.read<AuthController>();
    if (!auth.canWrite) {
      context.read<ProtectedNavigation>().open(
            context,
            '/restaurant-detail',
            arguments: RestaurantDetailArguments(
              restaurant: widget.restaurant,
              pendingAction: brokenLink
                  ? const RestaurantPendingAction.reportLink()
                  : const RestaurantPendingAction.reportListing(),
            ),
          );
      return;
    }
    await showContentReportDialog(
      context,
      targetType: 'restaurant',
      targetId: widget.restaurant.id,
      brokenLinkOnly: brokenLink,
    );
  }

  Future<void> _requestSave() async {
    final auth = context.read<AuthController>();
    if (!auth.canWrite) {
      context.read<ProtectedNavigation>().open(
            context,
            '/restaurant-detail',
            arguments: RestaurantDetailArguments(
              restaurant: widget.restaurant,
              pendingAction: const RestaurantPendingAction.save(),
            ),
          );
      return;
    }
    final controller = context.read<ItineraryController>();
    final wasSaved = controller.isSaved(restaurantId: widget.restaurant.id);
    final changed = await controller.toggleSave(
      restaurantId: widget.restaurant.id,
    );
    if (!mounted) return;
    _message(
      changed
          ? (wasSaved ? 'Removed from saved.' : 'Saved to your places.')
          : controller.errorMessage ?? 'The place could not be updated.',
    );
  }

  Future<void> _copyDiscount(DiscountCodeModel discount) async {
    if (!discount.isCurrentlyActive) {
      _message('This offer is no longer active. Refreshing offers…');
      await context.read<LocalEatsController>().loadData();
      return;
    }
    await Clipboard.setData(ClipboardData(text: discount.code));
    if (mounted) _message('Discount code copied.');
  }

  Future<void> _requestReview() async {
    final auth = context.read<AuthController>();
    if (!auth.canWrite) {
      context.read<ProtectedNavigation>().open(
            context,
            '/restaurant-detail',
            arguments: RestaurantDetailArguments(
              restaurant: widget.restaurant,
              pendingAction: const RestaurantPendingAction.review(),
            ),
          );
      return;
    }
    final controller = context.read<ReviewController>();
    final matches = controller
        .getReviewsForRestaurant(widget.restaurant.id)
        .where((review) => review.isOwnedByCurrentUser);
    final existing = matches.isEmpty ? null : matches.single;
    var rating = existing?.rating ?? 5;
    final body = TextEditingController(text: existing?.comment);
    final save = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            0,
            16,
            MediaQuery.viewInsetsOf(context).bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                existing == null ? 'Write a review' : 'Edit your review',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              Semantics(
                label: 'Rating ${rating.round()} out of 5',
                child: Row(
                  children: List.generate(
                    5,
                    (index) => IconButton(
                      tooltip: '${index + 1} stars',
                      onPressed: () => setSheetState(() => rating = index + 1),
                      icon: Icon(
                        index < rating ? Icons.star : Icons.star_border,
                        color: Colors.amber,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: body,
                minLines: 3,
                maxLines: 6,
                maxLength: 2000,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Your experience',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () {
                  if (body.text.trim().length < 3) return;
                  Navigator.pop(sheetContext, true);
                },
                child: const Text('Save review'),
              ),
            ],
          ),
        ),
      ),
    );
    final comment = body.text.trim();
    body.dispose();
    if (save != true || !mounted) return;
    final saved = await controller.addReview(
      restaurantId: widget.restaurant.id,
      rating: rating,
      comment: comment,
    );
    if (!mounted) return;
    _message(
      saved
          ? 'Review saved.'
          : controller.errorMessage ?? 'The review could not be saved.',
    );
  }

  Future<void> _requestReport(String reviewId) async {
    final auth = context.read<AuthController>();
    if (!auth.canWrite) {
      context.read<ProtectedNavigation>().open(
            context,
            '/restaurant-detail',
            arguments: RestaurantDetailArguments(
              restaurant: widget.restaurant,
              pendingAction: RestaurantPendingAction.report(reviewId),
            ),
          );
      return;
    }
    var reason = 'spam';
    var hideForMe = true;
    final explanation = TextEditingController();
    final submit = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Report this review'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: reason,
                  decoration: const InputDecoration(
                    labelText: 'Reason',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'spam', child: Text('Spam')),
                    DropdownMenuItem(
                      value: 'harassment',
                      child: Text('Harassment'),
                    ),
                    DropdownMenuItem(
                      value: 'hate',
                      child: Text('Hateful content'),
                    ),
                    DropdownMenuItem(
                      value: 'dangerous',
                      child: Text('Dangerous content'),
                    ),
                    DropdownMenuItem(
                      value: 'misleading',
                      child: Text('Misleading'),
                    ),
                    DropdownMenuItem(
                      value: 'privacy',
                      child: Text('Privacy concern'),
                    ),
                    DropdownMenuItem(value: 'other', child: Text('Other')),
                  ],
                  onChanged: (value) =>
                      setDialogState(() => reason = value ?? reason),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: explanation,
                  maxLength: 2000,
                  minLines: 2,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    labelText: 'Optional details',
                    border: OutlineInputBorder(),
                  ),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: hideForMe,
                  title: const Text('Hide this review for me'),
                  subtitle: const Text(
                    'One report does not hide it from everyone.',
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
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Submit report'),
            ),
          ],
        ),
      ),
    );
    final details = explanation.text.trim();
    explanation.dispose();
    if (submit != true || !mounted) return;
    final controller = context.read<ReviewController>();
    final saved = await controller.reportReview(
      reviewId: reviewId,
      reason: reason,
      explanation: details.isEmpty ? null : details,
      hideForReporter: hideForMe,
    );
    if (!mounted) return;
    _message(
      saved
          ? 'Report submitted for moderation.'
          : controller.errorMessage ?? 'The report could not be submitted.',
    );
  }

  Future<void> _requestBlockAuthor(
    String targetType,
    String targetId,
  ) async {
    final auth = context.read<AuthController>();
    if (!auth.canWrite) {
      context.read<ProtectedNavigation>().open(
            context,
            '/restaurant-detail',
            arguments: RestaurantDetailArguments(
              restaurant: widget.restaurant,
              pendingAction: targetType == 'review'
                  ? RestaurantPendingAction.blockReview(targetId)
                  : const RestaurantPendingAction.blockListingAuthor(),
            ),
          );
      return;
    }
    final blocked = await showBlockContentAuthorDialog(
      context,
      targetType: targetType,
      targetId: targetId,
    );
    if (!mounted || !blocked) return;
    if (targetType == 'review') {
      await context.read<ReviewController>().loadReviews(
            restaurantId: widget.restaurant.id,
          );
    } else {
      await context.read<LocalEatsController>().loadData();
      if (!mounted) return;
      Navigator.pop(context);
    }
  }

  Future<void> _confirmDelete(ReviewModel review) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete your review?'),
        content: const Text(
          'This cannot be undone. The public rating will be recalculated.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final controller = context.read<ReviewController>();
    final removed = await controller.removeReview(review.id);
    if (!mounted) return;
    _message(
      removed
          ? 'Review deleted.'
          : controller.errorMessage ?? 'The review could not be deleted.',
    );
  }

  void _message(String value) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: AppColors.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(body),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DiscountCard extends StatelessWidget {
  const _DiscountCard({required this.discount, required this.onCopy});

  final DiscountCodeModel discount;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final localizations = MaterialLocalizations.of(context);
    return Card(
      margin: EdgeInsets.zero,
      color: const Color(0xFFE8F1EC),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(discount.description,
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: SelectableText(
                    discount.code,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
                IconButton(
                  tooltip: 'Copy ${discount.code}',
                  onPressed: onCopy,
                  icon: const Icon(Icons.copy_outlined),
                ),
              ],
            ),
            if (discount.redemptionTerms.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Terms: ${discount.redemptionTerms}'),
            ],
            const SizedBox(height: 8),
            Text(
              'Expires ${localizations.formatMediumDate(discount.expiryDate.toLocal())}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({
    required this.review,
    this.onEdit,
    this.onDelete,
    this.onReport,
    this.onBlock,
  });

  final ReviewModel review;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onReport;
  final VoidCallback? onBlock;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(top: 8),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    review.userName,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                Semantics(
                  label: '${review.rating.round()} out of 5 stars',
                  child: Row(
                    children: List.generate(
                      5,
                      (index) => Icon(
                        index < review.rating ? Icons.star : Icons.star_border,
                        color: Colors.amber,
                        size: 16,
                      ),
                    ),
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: 'Review actions',
                  onSelected: (value) {
                    if (value == 'edit') onEdit?.call();
                    if (value == 'delete') onDelete?.call();
                    if (value == 'report') onReport?.call();
                    if (value == 'block') onBlock?.call();
                  },
                  itemBuilder: (_) => [
                    if (onEdit != null)
                      const PopupMenuItem(value: 'edit', child: Text('Edit')),
                    if (onDelete != null)
                      const PopupMenuItem(
                          value: 'delete', child: Text('Delete')),
                    if (onReport != null)
                      const PopupMenuItem(
                          value: 'report', child: Text('Report')),
                    if (onBlock != null)
                      const PopupMenuItem(
                        value: 'block',
                        child: Text('Block reviewer'),
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(review.comment),
            if (review.updatedAt != null) ...[
              const SizedBox(height: 8),
              Text('Edited', style: Theme.of(context).textTheme.bodySmall),
            ],
          ],
        ),
      ),
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.errorContainer,
      child: ListTile(
        leading: const Icon(Icons.error_outline),
        title: Text(message),
        trailing: TextButton(onPressed: onRetry, child: const Text('Retry')),
      ),
    );
  }
}
