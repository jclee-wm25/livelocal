import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../controllers/localeats_controller.dart';
import '../controllers/auth_controller.dart';
import 'restaurant_detail_screen.dart';
import 'add_restaurant_screen.dart';
import '../constants/app_colors.dart';

class LocalEatsScreen extends StatefulWidget {
  const LocalEatsScreen({super.key});
  @override
  State<LocalEatsScreen> createState() => _LocalEatsScreenState();
}

class _LocalEatsScreenState extends State<LocalEatsScreen> with SingleTickerProviderStateMixin {
  final PageController _pageController = PageController(viewportFraction: 0.9);
  int _currentPage = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startAutoScroll();
  }

  void _startAutoScroll() {
    _timer = Timer.periodic(const Duration(seconds: 3), (Timer timer) {
      if (_pageController.hasClients) {
        final localEats = context.read<LocalEatsController>();
        final count = localEats.trendingRestaurants.length;
        if (count > 0) {
          _currentPage = (_currentPage + 1) % count;
          _pageController.animateToPage(
            _currentPage,
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeInOutCubic,
          );
        }
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final localEats = context.watch<LocalEatsController>();
    final auth = context.watch<AuthController>();
    final isInfluencer = auth.currentUser?.role == 'influencer';
    final trending = localEats.trendingRestaurants;
    final filtered = localEats.filteredRestaurants;

    return Scaffold(
      backgroundColor: AppColors.backgroundGrey,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 120,
            floating: false,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: const Text('LocalEats 🍜',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.primaryDark, AppColors.primary],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
            ),
          ),
          if (localEats.isLoading)
            const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator(color: AppColors.primary)))
          else
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  if (trending.isNotEmpty) ...[
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16.0),
                      child: Text('Trending Now ✨',
                          style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primaryDark)),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 200,
                      child: PageView.builder(
                        controller: _pageController,
                        onPageChanged: (idx) => setState(() => _currentPage = idx),
                        itemCount: trending.length,
                        itemBuilder: (context, index) {
                          final restaurant = trending[index];
                          return AnimatedBuilder(
                            animation: _pageController,
                            builder: (context, child) {
                              double value = 1.0;
                              if (_pageController.position.haveDimensions) {
                                value = _pageController.page! - index;
                                value = (1 - (value.abs() * 0.2)).clamp(0.8, 1.0);
                              }
                              return Center(
                                child: SizedBox(
                                  height: Curves.easeOut.transform(value) * 200,
                                  width: Curves.easeOut.transform(value) *
                                      MediaQuery.of(context).size.width,
                                  child: child,
                                ),
                              );
                            },
                            child: GestureDetector(
                              onTap: () {
                                Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) =>
                                            RestaurantDetailScreen(restaurant: restaurant)));
                              },
                              child: Container(
                                margin: const EdgeInsets.symmetric(horizontal: 8),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: const [
                                    BoxShadow(
                                        color: Colors.black26,
                                        blurRadius: 10,
                                        offset: Offset(0, 5))
                                  ],
                                  image: DecorationImage(
                                    image: CachedNetworkImageProvider(restaurant.coverPhotoUrl),
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(20),
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.black.withValues(alpha: 0.1),
                                        Colors.black.withValues(alpha: 0.7)
                                      ],
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                    ),
                                  ),
                                  padding: const EdgeInsets.all(16),
                                  alignment: Alignment.bottomLeft,
                                  child: Text(
                                    restaurant.name,
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(trending.length, (index) {
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: _currentPage == index ? 24 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: _currentPage == index
                                ? AppColors.primary
                                : Colors.grey.shade400,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 24),
                  ],
                  _buildFilters(localEats),
                  const SizedBox(height: 16),
                  ListView.builder(
                    padding: const EdgeInsets.only(left: 16, right: 16, top: 8, bottom: 110),
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final restaurant = filtered[index];
                      final hasDiscount =
                          localEats.getActiveDiscountsForRestaurant(restaurant.id).isNotEmpty;
                      return _FadeInUpItem(
                        delay: index * 100,
                        child: GestureDetector(
                          onTap: () {
                            Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) =>
                                        RestaurantDetailScreen(restaurant: restaurant)));
                          },
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: const [
                                BoxShadow(
                                    color: Colors.black12,
                                    blurRadius: 8,
                                    offset: Offset(0, 2))
                              ],
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Row(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: CachedNetworkImage(
                                      imageUrl: restaurant.coverPhotoUrl,
                                      width: 70,
                                      height: 70,
                                      fit: BoxFit.cover,
                                      placeholder: (context, url) => Container(
                                          width: 70,
                                          height: 70,
                                          color: Colors.grey.shade200,
                                          child: const Center(child: CircularProgressIndicator())),
                                      errorWidget: (context, url, error) => Container(
                                          width: 70,
                                          height: 70,
                                          color: Colors.grey.shade200,
                                          child: const Icon(Icons.restaurant,
                                              color: AppColors.primary)),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(restaurant.name,
                                            style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                                color: AppColors.primaryDark)),
                                        const SizedBox(height: 4),
                                        Text(
                                            '${restaurant.cuisineType} • ${restaurant.city}',
                                            style: TextStyle(
                                                color: Colors.grey.shade600, fontSize: 13)),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Text(restaurant.priceRange,
                                                style: const TextStyle(
                                                    color: AppColors.accent,
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 13)),
                                            const SizedBox(width: 8),
                                            Text('by ${restaurant.influencerName}',
                                                style: TextStyle(
                                                    color: Colors.grey.shade500,
                                                    fontSize: 12,
                                                    fontStyle: FontStyle.italic)),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (hasDiscount) const _PulsingDiscountBadge(),
                                  const SizedBox(width: 8),
                                  Icon(Icons.chevron_right, color: Colors.grey.shade400),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 80),
                ],
              ),
            ),
        ],
      ),
      floatingActionButton: isInfluencer ? const _ExpandableFab() : null,
    );
  }

  Widget _buildFilters(LocalEatsController localEats) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _buildDropdownFilter(
            icon: Icons.map,
            value: localEats.selectedState,
            items: ['All', 'Selangor', 'Penang', 'Perak', 'Johor', 'Sabah'],
            onChanged: (val) => localEats.setFilter(state: val),
          ),
          const SizedBox(width: 8),
          _buildDropdownFilter(
            icon: Icons.restaurant,
            value: localEats.selectedCuisine,
            items: ['All', 'Malay', 'Chinese', 'Indian', 'Western', 'Fusion', 'Kopitiam'],
            onChanged: (val) => localEats.setFilter(cuisine: val),
          ),
          const SizedBox(width: 8),
          _buildDropdownFilter(
            icon: Icons.attach_money,
            value: localEats.selectedBudget,
            items: ['All', '\$', '\$\$', '\$\$\$', '\$\$\$\$'],
            onChanged: (val) => localEats.setFilter(budget: val),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownFilter({
    required IconData icon,
    required String value,
    required List<String> items,
    required Function(String?) onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.accentLight),
        boxShadow: [
          BoxShadow(
              color: AppColors.accentLight.withValues(alpha: 0.3),
              blurRadius: 4,
              offset: const Offset(0, 2))
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.primary),
          const SizedBox(width: 8),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isDense: true,
              icon: const Icon(Icons.arrow_drop_down, color: AppColors.primary),
              style: const TextStyle(color: AppColors.primaryDark, fontWeight: FontWeight.w600),
              items: items
                  .map((i) => DropdownMenuItem(value: i, child: Text(i)))
                  .toList(),
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}

class _PulsingDiscountBadge extends StatefulWidget {
  const _PulsingDiscountBadge();
  @override
  State<_PulsingDiscountBadge> createState() => _PulsingDiscountBadgeState();
}

class _PulsingDiscountBadgeState extends State<_PulsingDiscountBadge>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800))
      ..repeat(reverse: true);
    _scale = Tween<double>(begin: 1.0, end: 1.2)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
            color: AppColors.gold.withValues(alpha: 0.2),
            shape: BoxShape.circle),
        child: const Text('🏷️', style: TextStyle(fontSize: 16)),
      ),
    );
  }
}

class _FadeInUpItem extends StatelessWidget {
  final Widget child;
  final int delay;
  const _FadeInUpItem({required this.child, required this.delay});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - value)),
          child: Opacity(opacity: value, child: child),
        );
      },
      child: child,
    );
  }
}

class _ExpandableFab extends StatefulWidget {
  const _ExpandableFab();
  @override
  State<_ExpandableFab> createState() => _ExpandableFabState();
}

class _ExpandableFabState extends State<_ExpandableFab>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(vsync: this, duration: const Duration(milliseconds: 250));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (_expanded)
          FadeTransition(
            opacity: _controller,
            child: ScaleTransition(
              scale: _controller,
              child: FloatingActionButton.extended(
                heroTag: 'add_rest',
                backgroundColor: AppColors.primary,
                icon: const Icon(Icons.add_business),
                label: const Text('Add Restaurant'),
                onPressed: () {
                  setState(() {
                    _expanded = false;
                    _controller.reverse();
                  });
                  Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const AddRestaurantScreen()));
                },
              ),
            ),
          ),
        const SizedBox(height: 16),
        FloatingActionButton(
          heroTag: 'main_fab',
          backgroundColor: AppColors.primary,
          onPressed: () {
            setState(() {
              _expanded = !_expanded;
              if (_expanded) {
                _controller.forward();
              } else {
                _controller.reverse();
              }
            });
          },
          child: AnimatedIcon(icon: AnimatedIcons.menu_close, progress: _controller),
        ),
      ],
    );
  }
}
