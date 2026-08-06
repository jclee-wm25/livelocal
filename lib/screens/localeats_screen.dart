import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../constants/app_colors.dart';
import '../controllers/auth_controller.dart';
import '../controllers/localeats_controller.dart';
import '../models/restaurant_model.dart';
import 'add_restaurant_screen.dart';
import 'manage_discount_screen.dart';
import 'restaurant_detail_screen.dart';

class LocalEatsScreen extends StatefulWidget {
  const LocalEatsScreen({super.key});

  @override
  State<LocalEatsScreen> createState() => _LocalEatsScreenState();
}

class _LocalEatsScreenState extends State<LocalEatsScreen> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<LocalEatsController>();
    final isInfluencer =
        context.watch<AuthController>().currentUser?.role == 'influencer';
    final restaurants = controller.filteredRestaurants;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F5F0),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7F5F0),
        title: const Text('LocalEats'),
      ),
      body: RefreshIndicator(
        onRefresh: controller.loadData,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Creator-recommended places to eat',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Browse approved public listings. Location access is not required.',
                    ),
                    const SizedBox(height: 16),
                    SearchBar(
                      controller: _search,
                      hintText: 'Search restaurants, cuisines or areas',
                      leading: const Icon(Icons.search),
                      trailing: [
                        if (_search.text.isNotEmpty)
                          IconButton(
                            tooltip: 'Clear search',
                            onPressed: () {
                              _search.clear();
                              controller.setSearchQuery('');
                              setState(() {});
                            },
                            icon: const Icon(Icons.close),
                          ),
                      ],
                      onChanged: (value) {
                        controller.setSearchQuery(value);
                        setState(() {});
                      },
                    ),
                    const SizedBox(height: 12),
                    _Filters(controller: controller),
                  ],
                ),
              ),
            ),
            if (controller.isLoading && controller.restaurants.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator()),
              )
            else if (controller.errorMessage != null &&
                controller.restaurants.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _MessageState(
                  icon: Icons.wifi_off_outlined,
                  title: 'Restaurants could not be loaded',
                  message: controller.errorMessage!,
                  actionLabel: 'Try again',
                  onAction: controller.loadData,
                ),
              )
            else if (restaurants.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _MessageState(
                  icon: Icons.search_off_outlined,
                  title: 'No restaurants found',
                  message: 'Try a broader search or reset the filters.',
                  actionLabel: 'Reset filters',
                  onAction: () {
                    _search.clear();
                    controller.resetFilters();
                    setState(() {});
                  },
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 112),
                sliver: SliverList.separated(
                  itemCount: restaurants.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final restaurant = restaurants[index];
                    final hasDiscount = controller
                        .getActiveDiscountsForRestaurant(restaurant.id)
                        .isNotEmpty;
                    return _RestaurantCard(
                      restaurant: restaurant,
                      hasDiscount: hasDiscount,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => RestaurantDetailScreen(
                            restaurant: restaurant,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: isInfluencer
          ? FloatingActionButton.extended(
              onPressed: _showCreatorActions,
              icon: const Icon(Icons.add),
              label: const Text('Creator tools'),
            )
          : null,
    );
  }

  Future<void> _showCreatorActions() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Creator tools',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              ListTile(
                minTileHeight: 56,
                leading: const Icon(Icons.add_business_outlined),
                title: const Text('Submit a restaurant'),
                subtitle: const Text('Create a listing for moderation.'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => const AddRestaurantScreen(),
                    ),
                  );
                },
              ),
              ListTile(
                minTileHeight: 56,
                leading: const Icon(Icons.local_offer_outlined),
                title: const Text('Create a discount'),
                subtitle: const Text('For one of your approved listings.'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => const ManageDiscountScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Filters extends StatelessWidget {
  const _Filters({required this.controller});

  final LocalEatsController controller;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _Filter(
            label: 'State',
            value: controller.selectedState,
            values: const [
              'All',
              'Johor',
              'Kuala Lumpur',
              'Penang',
              'Perak',
              'Sabah',
              'Sarawak',
              'Selangor',
            ],
            onChanged: (value) => controller.setFilter(state: value),
          ),
          const SizedBox(width: 8),
          _Filter(
            label: 'Cuisine',
            value: controller.selectedCuisine,
            values: const [
              'All',
              'Malay',
              'Chinese',
              'Indian',
              'Western',
              'Fusion',
              'Kopitiam',
            ],
            onChanged: (value) => controller.setFilter(cuisine: value),
          ),
          const SizedBox(width: 8),
          _Filter(
            label: 'Price',
            value: controller.selectedBudget,
            values: const ['All', r'$', r'$$', r'$$$', r'$$$$'],
            onChanged: (value) => controller.setFilter(budget: value),
          ),
        ],
      ),
    );
  }
}

class _Filter extends StatelessWidget {
  const _Filter({
    required this.label,
    required this.value,
    required this.values,
    required this.onChanged,
  });

  final String label;
  final String value;
  final List<String> values;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownMenu<String>(
      label: Text(label),
      initialSelection: value,
      width: 152,
      dropdownMenuEntries: values
          .map((item) => DropdownMenuEntry(value: item, label: item))
          .toList(),
      onSelected: onChanged,
    );
  }
}

class _RestaurantCard extends StatelessWidget {
  const _RestaurantCard({
    required this.restaurant,
    required this.hasDiscount,
    required this.onTap,
  });

  final RestaurantModel restaurant;
  final bool hasDiscount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 112,
              height: 128,
              child: CachedNetworkImage(
                imageUrl: restaurant.coverPhotoUrl,
                fit: BoxFit.cover,
                placeholder: (_, __) => const ColoredBox(
                  color: Color(0xFFE5E1D8),
                  child: Center(child: CircularProgressIndicator()),
                ),
                errorWidget: (_, __, ___) => const ColoredBox(
                  color: Color(0xFFE5E1D8),
                  child: Icon(Icons.restaurant_outlined, size: 40),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            restaurant.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        const Icon(Icons.chevron_right),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${restaurant.cuisineType} · ${restaurant.city}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.star, size: 18, color: Colors.amber),
                        const SizedBox(width: 4),
                        Text(
                          restaurant.reviewCount == 0
                              ? 'No ratings yet'
                              : '${restaurant.rating.toStringAsFixed(1)} (${restaurant.reviewCount})',
                        ),
                      ],
                    ),
                    if (hasDiscount) ...[
                      const SizedBox(height: 6),
                      const Row(
                        children: [
                          Icon(
                            Icons.local_offer_outlined,
                            size: 18,
                            color: AppColors.primary,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Active offer',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageState extends StatelessWidget {
  const _MessageState({
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48),
            const SizedBox(height: 16),
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: onAction, child: Text(actionLabel)),
          ],
        ),
      ),
    );
  }
}
