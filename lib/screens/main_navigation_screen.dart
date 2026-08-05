import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/auth_controller.dart';
import '../controllers/itinerary_controller.dart';
import '../features/notifications/presentation/notification_controller.dart';
import 'spots_discovery_screen.dart';
import 'localeats_screen.dart';
import 'saved_places_screen.dart';
import 'neighbourhood_explorer_screen.dart';
import 'profile_screen.dart';
import 'admin_dashboard_screen.dart';
import 'notifications_screen.dart';
import '../constants/app_colors.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen>
    with TickerProviderStateMixin {
  int _currentIndex = 0;
  late AnimationController _bellController;

  @override
  void initState() {
    super.initState();
    _bellController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !context.read<AuthController>().canWrite) return;
      context.read<ItineraryController>().loadSavedPlaces();
      context.read<NotificationController>().load();
    });
  }

  @override
  void dispose() {
    _bellController.dispose();
    super.dispose();
  }

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final authCtrl = Provider.of<AuthController>(context);
    final user = authCtrl.currentUser;
    final isAdmin = user?.role == 'admin';
    final unreadNotifications =
        context.watch<NotificationController>().unreadCount;

    final List<Widget> pages = [
      const SpotsDiscoveryScreen(),
      const LocalEatsScreen(),
      const SavedPlacesScreen(),
      const NeighbourhoodExplorerScreen(),
      isAdmin ? const AdminDashboardScreen() : const ProfileScreen(),
    ];

    return Scaffold(
      extendBody: true,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: Container(
          decoration: const BoxDecoration(
            color: AppColors.primaryDark,
            boxShadow: [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.location_on,
                        color: AppColors.accent, size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'LiveLocal',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const Spacer(),

                  // Clean Notification Action Button
                  InkWell(
                    onTap: () {
                      _bellController
                          .forward()
                          .then((_) => _bellController.reverse());
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const NotificationsScreen()),
                      );
                    },
                    borderRadius: BorderRadius.circular(24),
                    child: Container(
                      width: 48,
                      height: 48,
                      alignment: Alignment.center,
                      child: RotationTransition(
                        turns: Tween(begin: 0.0, end: 0.08)
                            .chain(CurveTween(curve: Curves.elasticIn))
                            .animate(_bellController),
                        child: Badge(
                          isLabelVisible: unreadNotifications > 0,
                          label: Text(
                            unreadNotifications > 99
                                ? '99+'
                                : '$unreadNotifications',
                          ),
                          child: const Icon(
                            Icons.notifications_outlined,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: pages,
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          margin: const EdgeInsets.only(left: 16, right: 16, bottom: 12),
          height: 64,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 16,
                offset: const Offset(0, 4),
              )
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(0, Icons.explore_outlined, Icons.explore, 'Spots'),
              _buildNavItem(
                  1, Icons.restaurant_outlined, Icons.restaurant, 'Eats'),
              _buildNavItem(2, Icons.bookmark_outline, Icons.bookmark, 'Saved'),
              _buildNavItem(3, Icons.map_outlined, Icons.map, 'Explorer'),
              _buildNavItem(
                  4,
                  isAdmin
                      ? Icons.admin_panel_settings_outlined
                      : Icons.person_outline,
                  isAdmin ? Icons.admin_panel_settings : Icons.person,
                  isAdmin ? 'Admin' : 'Profile'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(
      int index, IconData icon, IconData activeIcon, String label) {
    final isSelected = _currentIndex == index;
    return InkWell(
      onTap: () => _onTabTapped(index),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        constraints: const BoxConstraints(minWidth: 56, minHeight: 48),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isSelected ? activeIcon : icon,
              color: isSelected ? AppColors.primaryDark : Colors.grey.shade600,
              size: 22,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color:
                    isSelected ? AppColors.primaryDark : Colors.grey.shade600,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
