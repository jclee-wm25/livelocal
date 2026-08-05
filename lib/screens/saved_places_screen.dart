import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/auth_controller.dart';
import '../controllers/itinerary_controller.dart';
import '../controllers/localeats_controller.dart';
import '../controllers/spot_controller.dart';
import '../core/routing/protected_navigation.dart';
import '../models/restaurant_model.dart';
import '../models/saved_place_model.dart';
import '../models/spot_model.dart';
import 'itinerary_screen.dart';
import 'restaurant_detail_screen.dart';
import 'spot_detail_screen.dart';
import '../shared/presentation/app_state_view.dart';

class SavedPlacesScreen extends StatefulWidget {
  const SavedPlacesScreen({super.key});

  @override
  State<SavedPlacesScreen> createState() => _SavedPlacesScreenState();
}

class _SavedPlacesScreenState extends State<SavedPlacesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    if (!mounted || !context.read<AuthController>().canWrite) return;
    await context.read<ItineraryController>().loadSavedPlaces();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    if (!auth.canWrite) {
      return Scaffold(
        backgroundColor: const Color(0xFFF7F5F0),
        appBar: AppBar(
          backgroundColor: const Color(0xFFF7F5F0),
          title: const Text('Saved'),
        ),
        body: _GuestState(
          onSignIn: () => context.read<ProtectedNavigation>().open(
                context,
                '/saved-places',
              ),
        ),
      );
    }

    final controller = context.watch<ItineraryController>();
    final spots = context.watch<SpotController>().spots;
    final restaurants = context.watch<LocalEatsController>().restaurants;
    final resolved = _resolve(controller.savedPlaces, spots, restaurants);
    return Scaffold(
      backgroundColor: const Color(0xFFF7F5F0),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7F5F0),
        title: const Text('Saved'),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: controller.isLoading && controller.savedPlaces.isEmpty
            ? const AppLoadingList()
            : controller.errorMessage != null && controller.savedPlaces.isEmpty
                ? AppStateView(
                    icon: Icons.wifi_off_outlined,
                    title: 'Saved places could not be loaded',
                    message: controller.errorMessage!,
                    actionLabel: 'Try again',
                    onAction: _load,
                    scrollable: true,
                  )
                : resolved.isEmpty
                    ? const AppStateView(
                        icon: Icons.bookmark_border,
                        title: 'Nothing saved yet',
                        message:
                            'Save approved spots and restaurants to plan a day out.',
                        scrollable: true,
                      )
                    : ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 112),
                        itemCount: resolved.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final place = resolved[index];
                          return Card(
                            margin: EdgeInsets.zero,
                            elevation: 0,
                            child: ListTile(
                              minTileHeight: 72,
                              leading: Icon(
                                place.spot == null
                                    ? Icons.restaurant_outlined
                                    : Icons.place_outlined,
                              ),
                              title: Text(place.name),
                              subtitle: Text(place.description),
                              onTap: () => _open(place),
                              trailing: IconButton(
                                tooltip: 'Remove ${place.name} from saved',
                                onPressed: () => _confirmRemove(place),
                                icon:
                                    const Icon(Icons.bookmark_remove_outlined),
                              ),
                            ),
                          );
                        },
                      ),
      ),
      floatingActionButton: resolved.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => const ItineraryScreen(),
                ),
              ),
              icon: const Icon(Icons.route_outlined),
              label: const Text('Plan a route'),
            ),
    );
  }

  List<_ResolvedPlace> _resolve(
    List<SavedPlaceModel> saves,
    List<SpotModel> spots,
    List<RestaurantModel> restaurants,
  ) {
    final result = <_ResolvedPlace>[];
    for (final save in saves) {
      final spotMatches = spots.where((spot) => spot.id == save.spotId);
      if (spotMatches.isNotEmpty) {
        result.add(_ResolvedPlace(save: save, spot: spotMatches.first));
        continue;
      }
      final restaurantMatches =
          restaurants.where((item) => item.id == save.restaurantId);
      if (restaurantMatches.isNotEmpty) {
        result.add(
          _ResolvedPlace(save: save, restaurant: restaurantMatches.first),
        );
      }
    }
    return result;
  }

  void _open(_ResolvedPlace place) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => place.spot != null
            ? SpotDetailScreen(spot: place.spot!)
            : RestaurantDetailScreen(restaurant: place.restaurant!),
      ),
    );
  }

  Future<void> _confirmRemove(_ResolvedPlace place) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Remove ${place.name}?'),
        content: const Text(
          'The place will also be unavailable for new itineraries. Existing saved itineraries are not changed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final controller = context.read<ItineraryController>();
    final saved = await controller.toggleSave(
      spotId: place.spot?.id,
      restaurantId: place.restaurant?.id,
    );
    if (!mounted || saved) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          controller.errorMessage ?? 'The place could not be removed.',
        ),
      ),
    );
  }
}

class _ResolvedPlace {
  const _ResolvedPlace({required this.save, this.spot, this.restaurant});

  final SavedPlaceModel save;
  final SpotModel? spot;
  final RestaurantModel? restaurant;

  String get name => spot?.name ?? restaurant!.name;
  String get description => spot == null
      ? '${restaurant!.cuisineType} · ${restaurant!.city}'
      : '${spot!.category} · ${spot!.city}';
}

class _GuestState extends StatelessWidget {
  const _GuestState({required this.onSignIn});

  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.bookmark_border, size: 56),
            const SizedBox(height: 16),
            Text(
              'Keep your places together',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Sign in to save places and create itineraries. Public browsing remains available without an account.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton(onPressed: onSignIn, child: const Text('Sign in')),
          ],
        ),
      ),
    );
  }
}
