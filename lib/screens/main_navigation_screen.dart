import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/auth_controller.dart';
import '../controllers/itinerary_controller.dart';
import '../features/notifications/presentation/notification_controller.dart';
import 'admin_dashboard_screen.dart';
import 'localeats_screen.dart';
import 'neighbourhood_explorer_screen.dart';
import 'notifications_screen.dart';
import 'profile_screen.dart';
import 'saved_places_screen.dart';
import 'spots_discovery_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !context.read<AuthController>().canWrite) return;
      context.read<ItineraryController>().loadSavedPlaces();
      context.read<NotificationController>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final isAdmin = auth.currentUser?.role == 'admin';
    final pages = <Widget>[
      const SpotsDiscoveryScreen(),
      const LocalEatsScreen(),
      const SavedPlacesScreen(),
      const NeighbourhoodExplorerScreen(),
      isAdmin ? const AdminDashboardScreen() : const ProfileScreen(),
    ];
    return Scaffold(
      appBar: _currentIndex == 0
          ? AppBar(
              title: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.location_on_outlined, size: 24),
                  SizedBox(width: 8),
                  Text('LiveLocal'),
                ],
              ),
              actions: [
                _NotificationAction(
                  unreadCount:
                      context.watch<NotificationController>().unreadCount,
                ),
                const SizedBox(width: 8),
              ],
            )
          : null,
      body: IndexedStack(index: _currentIndex, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.explore_outlined),
            selectedIcon: Icon(Icons.explore),
            label: 'Spots',
          ),
          const NavigationDestination(
            icon: Icon(Icons.restaurant_outlined),
            selectedIcon: Icon(Icons.restaurant),
            label: 'Eats',
          ),
          const NavigationDestination(
            icon: Icon(Icons.bookmark_outline),
            selectedIcon: Icon(Icons.bookmark),
            label: 'Saved',
          ),
          const NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map),
            label: 'Guides',
          ),
          NavigationDestination(
            icon: Icon(
              isAdmin
                  ? Icons.admin_panel_settings_outlined
                  : Icons.person_outline,
            ),
            selectedIcon: Icon(
              isAdmin ? Icons.admin_panel_settings : Icons.person,
            ),
            label: isAdmin ? 'Admin' : 'Profile',
          ),
        ],
      ),
    );
  }
}

class _NotificationAction extends StatelessWidget {
  const _NotificationAction({required this.unreadCount});

  final int unreadCount;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Notifications',
      onPressed: () => Navigator.push(
        context,
        MaterialPageRoute<void>(builder: (_) => const NotificationsScreen()),
      ),
      icon: Badge(
        isLabelVisible: unreadCount > 0,
        label: Text(unreadCount > 99 ? '99+' : '$unreadCount'),
        child: const Icon(Icons.notifications_outlined),
      ),
    );
  }
}
