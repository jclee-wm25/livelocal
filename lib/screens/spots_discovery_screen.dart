import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app/theme/app_spacing.dart';
import '../controllers/spot_controller.dart';
import '../core/routing/protected_navigation.dart';
import '../models/spot_model.dart';
import '../shared/presentation/app_state_view.dart';
import 'spot_detail_screen.dart';

class SpotsDiscoveryScreen extends StatefulWidget {
  const SpotsDiscoveryScreen({super.key});

  @override
  State<SpotsDiscoveryScreen> createState() => _SpotsDiscoveryScreenState();
}

class _SpotsDiscoveryScreenState extends State<SpotsDiscoveryScreen> {
  static const _states = [
    'All',
    'Johor',
    'Kuala Lumpur',
    'Melaka',
    'Penang',
    'Perak',
    'Sabah',
    'Sarawak',
    'Selangor',
  ];

  static const _categories = [
    'All',
    'Kopitiam',
    'Pasar Malam',
    'Indie Cafe',
    'Park / Walkway',
    'Hawker Food',
    'Heritage Spot',
  ];

  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<SpotController>();
    final spots = controller.approvedSpots;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: controller.loadSpots,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.x2,
                  AppSpacing.x2,
                  AppSpacing.x2,
                  AppSpacing.x1,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Discover places locals value',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: AppSpacing.x1),
                    Text(
                      'Browse approved public spots without sharing your location.',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: AppSpacing.x2),
                    SearchBar(
                      controller: _search,
                      hintText: 'Search places, food, or neighbourhoods',
                      leading: const Icon(Icons.search),
                      trailing: [
                        if (_search.text.isNotEmpty)
                          IconButton(
                            tooltip: 'Clear search',
                            onPressed: () {
                              setState(_search.clear);
                              controller.filter(query: '');
                            },
                            icon: const Icon(Icons.close),
                          ),
                      ],
                      onChanged: (value) {
                        setState(() {});
                        controller.filter(query: value);
                      },
                    ),
                    const SizedBox(height: AppSpacing.x2),
                    DropdownButtonFormField<String>(
                      initialValue: controller.selectedState,
                      decoration: const InputDecoration(
                        labelText: 'State or territory',
                        prefixIcon: Icon(Icons.location_on_outlined),
                      ),
                      items: _states
                          .map(
                            (state) => DropdownMenuItem(
                          value: state,
                          child: Text(state),
                        ),
                      )
                          .toList(),
                      onChanged: (value) {
                        if (value != null) controller.filter(state: value);
                      },
                    ),
                    const SizedBox(height: AppSpacing.x2),
                    Semantics(
                      label: 'Filter spots by category',
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: _categories
                              .map(
                                (category) => Padding(
                              padding: const EdgeInsets.only(
                                  right: AppSpacing.x1),
                              child: FilterChip(
                                label: Text(category),
                                selected:
                                controller.selectedCategory == category,
                                onSelected: (_) =>
                                    controller.filter(category: category),
                              ),
                            ),
                          )
                              .toList(),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.x2),
                    Text(
                      '${spots.length} ${spots.length == 1 ? 'place' : 'places'}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    if (controller.errorMessage != null && spots.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.x1),
                        child: Text(
                          controller.errorMessage!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (controller.isLoading && spots.isEmpty)
              const SliverPadding(
                padding: EdgeInsets.all(AppSpacing.x2),
                sliver: _SpotLoadingSliver(),
              )
            else if (controller.errorMessage != null && spots.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: AppStateView(
                  icon: Icons.cloud_off_outlined,
                  title: 'Places could not be loaded',
                  message: controller.errorMessage!,
                  actionLabel: 'Try again',
                  onAction: controller.loadSpots,
                ),
              )
            else if (spots.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: AppStateView(
                    icon: Icons.travel_explore_outlined,
                    title: 'No matching places',
                    message: 'Try another search, category, or state.',
                    actionLabel: 'Clear filters',
                    onAction: () {
                      _search.clear();
                      controller.resetFilters();
                    },
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.x2,
                    AppSpacing.x1,
                    AppSpacing.x2,
                    112,
                  ),
                  sliver: SliverList.separated(
                    itemCount: spots.length + 1,
                    separatorBuilder: (_, __) =>
                    const SizedBox(height: AppSpacing.x2),
                    itemBuilder: (context, index) {
                      if (index == spots.length) {
                        return Center(
                          child: controller.isLoadingMore
                              ? const Padding(
                            padding: EdgeInsets.all(AppSpacing.x2),
                            child: CircularProgressIndicator(),
                          )
                              : OutlinedButton(
                            onPressed: controller.hasMore
                                ? controller.loadMore
                                : null,
                            child: Text(
                              controller.hasMore
                                  ? 'Load more places'
                                  : 'All places loaded',
                            ),
                          ),
                        );
                      }
                      return _SpotCard(spot: spots[index]);
                    },
                  ),
                ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () =>
            context.read<ProtectedNavigation>().open(context, '/submit-spot'),
        icon: const Icon(Icons.add_location_alt_outlined),
        label: const Text('Submit a place'),
      ),
    );
  }
}

class _SpotCard extends StatelessWidget {
  const _SpotCard({required this.spot});

  final SpotModel spot;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute<void>(builder: (_) => SpotDetailScreen(spot: spot)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 16 / 7,
              child: CachedNetworkImage(
                imageUrl: spot.imageUrl,
                fit: BoxFit.cover,
                placeholder: (_, __) => ColoredBox(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: const Center(child: CircularProgressIndicator()),
                ),
                errorWidget: (_, __, ___) => ColoredBox(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: const Center(
                    child: Icon(Icons.image_not_supported_outlined, size: 48),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.x2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: AppSpacing.x1,
                    runSpacing: AppSpacing.x1,
                    children: [
                      Chip(label: Text(spot.category)),
                      if (spot.reviewCount > 0)
                        Chip(
                          avatar: const Icon(Icons.star, size: 18),
                          label: Text(
                            '${spot.rating.toStringAsFixed(1)} · ${spot.reviewCount}',
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.x1),
                  Text(
                    spot.name,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: AppSpacing.x1),
                  Text('${spot.city}, ${spot.state} · ${spot.priceRange}'),
                  const SizedBox(height: AppSpacing.x1),
                  Text(
                    spot.description,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SpotLoadingSliver extends StatelessWidget {
  const _SpotLoadingSliver();

  @override
  Widget build(BuildContext context) {
    return SliverList.separated(
      itemCount: 3,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.x2),
      itemBuilder: (_, __) => Container(
        height: 260,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}