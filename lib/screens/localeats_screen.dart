import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/localeats_controller.dart';
import '../controllers/auth_controller.dart';
import 'restaurant_detail_screen.dart';
import 'add_restaurant_screen.dart';

class LocalEatsScreen extends StatefulWidget {
  const LocalEatsScreen({super.key});

  @override
  State<LocalEatsScreen> createState() => _LocalEatsScreenState();
}

class _LocalEatsScreenState extends State<LocalEatsScreen> {
  final List<String> _states = ['All', 'Penang', 'Kuala Lumpur', 'Perak', 'Johor', 'Selangor'];
  final List<String> _cuisines = ['All', 'Hawker', 'Nasi Kandar', 'Kopitiam', 'Malay', 'Chinese', 'Indian'];
  final List<String> _budgets = ['All', '\$', '\$\$', '\$\$\$'];

  @override
  Widget build(BuildContext context) {
    final foodCtrl = Provider.of<LocalEatsController>(context);
    final authCtrl = Provider.of<AuthController>(context);

    final restaurants = foodCtrl.filteredRestaurants;
    final trending = foodCtrl.trendingRestaurants;
    final isInfluencer = authCtrl.currentUser?.role == 'influencer';

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Filter Bar Section
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.all(16),
              color: const Color(0xFF2D6A4F).withOpacity(0.05),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.star_outline, color: Color(0xFF2D6A4F)),
                      const SizedBox(width: 6),
                      const Text(
                        'LocalEats by Food Influencers',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF2D6A4F)),
                      ),
                      const Spacer(),
                      if (isInfluencer)
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2D6A4F)),
                          icon: const Icon(Icons.add_a_photo, size: 16, color: Colors.white),
                          label: const Text('Add Review', style: TextStyle(color: Colors.white, fontSize: 12)),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const AddRestaurantScreen()),
                            );
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        DropdownButton<String>(
                          value: foodCtrl.selectedState,
                          underline: const SizedBox(),
                          icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF2D6A4F)),
                          items: _states.map((s) => DropdownMenuItem(value: s, child: Text('State: $s'))).toList(),
                          onChanged: (val) {
                            if (val != null) foodCtrl.setFilter(state: val);
                          },
                        ),
                        const SizedBox(width: 12),
                        DropdownButton<String>(
                          value: foodCtrl.selectedCuisine,
                          underline: const SizedBox(),
                          icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF2D6A4F)),
                          items: _cuisines.map((c) => DropdownMenuItem(value: c, child: Text('Cuisine: $c'))).toList(),
                          onChanged: (val) {
                            if (val != null) foodCtrl.setFilter(cuisine: val);
                          },
                        ),
                        const SizedBox(width: 12),
                        DropdownButton<String>(
                          value: foodCtrl.selectedBudget,
                          underline: const SizedBox(),
                          icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF2D6A4F)),
                          items: _budgets.map((b) => DropdownMenuItem(value: b, child: Text('Budget: $b'))).toList(),
                          onChanged: (val) {
                            if (val != null) foodCtrl.setFilter(budget: val);
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Trending Section Header (FR31)
          if (trending.isNotEmpty) ...[
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  children: [
                    Icon(Icons.local_fire_department, color: Colors.deepOrange),
                    SizedBox(width: 6),
                    Text(
                      'Trending Eateries Reviewed Lately',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 160,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: trending.length,
                  itemBuilder: (context, index) {
                    final item = trending[index];
                    return GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => RestaurantDetailScreen(restaurant: item)),
                        );
                      },
                      child: Container(
                        width: 220,
                        margin: const EdgeInsets.only(right: 12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          image: DecorationImage(
                            image: NetworkImage(item.coverPhotoUrl),
                            fit: BoxFit.cover,
                          ),
                        ),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [Colors.black.withOpacity(0.8), Colors.transparent],
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.name,
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                'By ${item.influencerName}',
                                style: const TextStyle(color: Color(0xFF74C69D), fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
          // All Filtered Restaurant Listings
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, 20, 16, 8),
              child: Text(
                'All Influencer Recommendations',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final rest = restaurants[index];
                final activeDiscounts = foodCtrl.getActiveDiscountsForRestaurant(rest.id);

                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(12),
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        rest.coverPhotoUrl,
                        width: 70,
                        height: 70,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 70,
                          height: 70,
                          color: Colors.grey.shade200,
                          child: const Icon(Icons.fastfood, color: Colors.grey),
                        ),
                      ),
                    ),
                    title: Text(rest.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text('${rest.cuisineType} • ${rest.priceRange} • ${rest.city}'),
                        Text('Reviewed: ${rest.reviewedDishes}', style: TextStyle(color: Colors.grey.shade700, fontSize: 12)),
                        if (activeDiscounts.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.amber.shade100,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: Colors.amber.shade700),
                            ),
                            child: Text(
                              '🏷️ ${activeDiscounts.first.code} Available!',
                              style: TextStyle(color: Colors.amber.shade900, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ],
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => RestaurantDetailScreen(restaurant: rest)),
                      );
                    },
                  ),
                );
              },
              childCount: restaurants.length,
            ),
          ),
        ],
      ),
    );
  }
}
