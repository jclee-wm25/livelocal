import 'package:flutter/material.dart';
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

class _SavedPlacesScreenState extends State<SavedPlacesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = Provider.of<AuthController>(context, listen: false).currentUser;
      if (user != null) {
        Provider.of<ItineraryController>(context, listen: false).loadSavedPlaces(user.id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final itineraryCtrl = Provider.of<ItineraryController>(context);
    final spotCtrl = Provider.of<SpotController>(context);
    final foodCtrl = Provider.of<LocalEatsController>(context);
    final authCtrl = Provider.of<AuthController>(context);

    final user = authCtrl.currentUser;
    final savedItems = itineraryCtrl.savedPlaces;

    return Scaffold(
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: const Color(0xFF2D6A4F).withOpacity(0.05),
            child: Row(
              children: [
                const Icon(Icons.bookmark_outline, color: Color(0xFF2D6A4F)),
                const SizedBox(width: 8),
                Text(
                  'Saved Places (${savedItems.length})',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF2D6A4F)),
                ),
                const Spacer(),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2D6A4F)),
                  icon: const Icon(Icons.auto_awesome, size: 16, color: Colors.white),
                  label: const Text('Smart Itinerary', style: TextStyle(color: Colors.white, fontSize: 12)),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ItineraryScreen()),
                    );
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: savedItems.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.bookmark_border, size: 64, color: Colors.grey.shade400),
                        const SizedBox(height: 12),
                        const Text('No saved spots or eateries yet.', style: TextStyle(fontSize: 16, color: Colors.grey)),
                        const SizedBox(height: 6),
                        const Text('Tap the bookmark icon on any spot or restaurant to save it!', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: savedItems.length,
                    itemBuilder: (context, index) {
                      final item = savedItems[index];
                      if (item.spotId != null) {
                        final spots = spotCtrl.spots.where((s) => s.id == item.spotId).toList();
                        if (spots.isNotEmpty) {
                          final s = spots.first;
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: ListTile(
                              leading: const CircleAvatar(backgroundColor: Color(0xFF2D6A4F), child: Icon(Icons.place, color: Colors.white)),
                              title: Text(s.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text('${s.category} • ${s.city}, ${s.state}'),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.red),
                                onPressed: () async {
                                  if (user != null) {
                                    await itineraryCtrl.toggleSave(user.id, spotId: s.id);
                                  }
                                },
                              ),
                              onTap: () {
                                Navigator.push(context, MaterialPageRoute(builder: (_) => SpotDetailScreen(spot: s)));
                              },
                            ),
                          );
                        }
                      } else if (item.restaurantId != null) {
                        final rests = foodCtrl.restaurants.where((r) => r.id == item.restaurantId).toList();
                        if (rests.isNotEmpty) {
                          final r = rests.first;
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: ListTile(
                              leading: const CircleAvatar(backgroundColor: Color(0xFF74C69D), child: Icon(Icons.restaurant, color: Colors.white)),
                              title: Text(r.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text('${r.cuisineType} • ${r.city}, ${r.state}'),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.red),
                                onPressed: () async {
                                  if (user != null) {
                                    await itineraryCtrl.toggleSave(user.id, restaurantId: r.id);
                                  }
                                },
                              ),
                              onTap: () {
                                Navigator.push(context, MaterialPageRoute(builder: (_) => RestaurantDetailScreen(restaurant: r)));
                              },
                            ),
                          );
                        }
                      }
                      return const SizedBox();
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
