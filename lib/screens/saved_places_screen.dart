import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../controllers/itinerary_controller.dart';
import '../controllers/spot_controller.dart';
import '../controllers/localeats_controller.dart';
import '../controllers/auth_controller.dart';
import 'itinerary_screen.dart';
import 'spot_detail_screen.dart';
import 'restaurant_detail_screen.dart';

class SavedPlacesScreen extends StatefulWidget {
  const SavedPlacesScreen({super.key});
  @override
  State<SavedPlacesScreen> createState() => _SavedPlacesScreenState();
}

class _SavedPlacesScreenState extends State<SavedPlacesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user =
          Provider.of<AuthController>(context, listen: false).currentUser;
      if (user != null) {
        Provider.of<ItineraryController>(context, listen: false)
            .loadSavedPlaces(user.id);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final itineraryCtrl = Provider.of<ItineraryController>(context);
    final spotCtrl = Provider.of<SpotController>(context);
    final foodCtrl = Provider.of<LocalEatsController>(context);
    final authCtrl = Provider.of<AuthController>(context);
    final user = authCtrl.currentUser;
    final savedItems = itineraryCtrl.savedPlaces;
    final spots = savedItems.where((i) => i.spotId != null).toList();
    final eateries = savedItems.where((i) => i.restaurantId != null).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9F8),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 200.0,
            floating: false,
            pinned: true,
            backgroundColor: const Color(0xFF2D6A4F),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF1B4332), Color(0xFF2D6A4F)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.only(
                        left: 20.0, right: 20.0, top: 12.0, bottom: 56.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        const Text(
                          'My Saved Places',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFD700).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color:
                                    const Color(0xFFFFD700).withOpacity(0.5)),
                          ),
                          child: Text(
                            '${savedItems.length} items saved',
                            style: const TextStyle(
                              color: Color(0xFFFFD700),
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            bottom: TabBar(
              controller: _tabController,
              indicatorColor: const Color(0xFFFFD700),
              indicatorWeight: 3,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              labelStyle:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              tabs: const [
                Tab(text: 'Spots'),
                Tab(text: 'Eateries'),
              ],
            ),
          ),
          SliverFillRemaining(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildList(
                    spots, true, spotCtrl, foodCtrl, itineraryCtrl, user?.id),
                _buildList(eateries, false, spotCtrl, foodCtrl, itineraryCtrl,
                    user?.id),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: savedItems.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const ItineraryScreen()),
                    );
                  },
                  child: Container(
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF2D6A4F), Color(0xFF1B4332)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF2D6A4F).withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.auto_awesome, color: Color(0xFFFFD700)),
                        SizedBox(width: 8),
                        Text(
                          'Generate Day Plan',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildList(
      List<dynamic> items,
      bool isSpots,
      SpotController spotCtrl,
      LocalEatsController foodCtrl,
      ItineraryController itineraryCtrl,
      String? userId) {
    if (items.isEmpty) {
      return Center(
        child: TweenAnimationBuilder<double>(
          duration: const Duration(milliseconds: 800),
          tween: Tween<double>(begin: 0, end: 1),
          builder: (context, val, child) {
            return Transform.scale(
              scale: val,
              child: Opacity(
                opacity: val,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: const Color(0xFFB7E4C7).withOpacity(0.3),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isSpots
                            ? Icons.landscape_outlined
                            : Icons.restaurant_outlined,
                        size: 64,
                        color: const Color(0xFF2D6A4F),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No saved ${isSpots ? 'spots' : 'eateries'} yet',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1B4332),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Explore and save places you love!',
                      style:
                          TextStyle(fontSize: 14, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 110),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        dynamic data;
        if (isSpots) {
          final s = spotCtrl.spots.where((s) => s.id == item.spotId).toList();
          if (s.isNotEmpty) data = s.first;
        } else {
          final r = foodCtrl.restaurants
              .where((r) => r.id == item.restaurantId)
              .toList();
          if (r.isNotEmpty) data = r.first;
        }
        if (data == null) return const SizedBox();

        return TweenAnimationBuilder<double>(
          duration: Duration(milliseconds: 400 + (index * 100)),
          tween: Tween<double>(begin: 0, end: 1),
          curve: Curves.easeOutCubic,
          builder: (context, val, child) {
            return Transform.translate(
              offset: Offset(0, 50 * (1 - val)),
              child: Opacity(opacity: val, child: child),
            );
          },
          child: Dismissible(
            key: Key(isSpots ? item.spotId! : item.restaurantId!),
            direction: DismissDirection.endToStart,
            background: Container(
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.red.shade400,
                borderRadius: BorderRadius.circular(16),
              ),
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 20),
              child:
                  const Icon(Icons.delete_sweep, color: Colors.white, size: 32),
            ),
            onDismissed: (_) {
              if (userId != null) {
                if (isSpots) {
                  itineraryCtrl.toggleSave(userId, spotId: data.id);
                } else {
                  itineraryCtrl.toggleSave(userId, restaurantId: data.id);
                }
                HapticFeedback.lightImpact();
              }
            },
            child: Container(
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () {
                    HapticFeedback.selectionClick();
                    if (isSpots) {
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => SpotDetailScreen(spot: data)));
                    } else {
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) =>
                                  RestaurantDetailScreen(restaurant: data)));
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Row(
                      children: [
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF74C69D), Color(0xFF2D6A4F)],
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            isSpots ? Icons.place : Icons.restaurant,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                data.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Color(0xFF1B4332),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${isSpots ? data.category : data.cuisineType} • ${data.city}',
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right, color: Colors.grey),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
