import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/auth_controller.dart';
import 'spots_discovery_screen.dart';
import 'localeats_screen.dart';
import 'saved_places_screen.dart';
import 'neighbourhood_explorer_screen.dart';
import 'profile_screen.dart';
import 'admin_dashboard_screen.dart';
import 'notifications_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final authCtrl = Provider.of<AuthController>(context);
    final user = authCtrl.currentUser;

    final List<Widget> pages = [
      const SpotsDiscoveryScreen(),
      const LocalEatsScreen(),
      const SavedPlacesScreen(),
      const NeighbourhoodExplorerScreen(),
      user?.role == 'admin' ? const AdminDashboardScreen() : const ProfileScreen(),
    ];

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.location_on, color: Color(0xFF2D6A4F), size: 24),
            ),
            const SizedBox(width: 8),
            const Text(
              'LiveLocal',
              style: TextStyle(
                color: Color(0xFF2D6A4F),
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
            const Spacer(),
            // Quick Role Switcher Chip for Assessment Demo
            PopupMenuButton<String>(
              onSelected: (role) {
                authCtrl.setRole(role);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Switched to ${role.toUpperCase()} role for demo'),
                    backgroundColor: const Color(0xFF2D6A4F),
                    duration: const Duration(seconds: 1),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF74C69D).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF2D6A4F)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.swap_horiz, size: 16, color: Color(0xFF2D6A4F)),
                    const SizedBox(width: 4),
                    Text(
                      user?.role.toUpperCase() ?? 'TOURIST',
                      style: const TextStyle(
                        color: Color(0xFF2D6A4F),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              itemBuilder: (ctx) => [
                const PopupMenuItem(value: 'tourist', child: Text('Tourist View')),
                const PopupMenuItem(value: 'influencer', child: Text('Influencer View')),
                const PopupMenuItem(value: 'admin', child: Text('Admin View')),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined, color: Color(0xFF2D6A4F)),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const NotificationsScreen()),
              );
            },
          ),
        ],
      ),
      body: pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        selectedItemColor: const Color(0xFF2D6A4F),
        unselectedItemColor: Colors.grey.shade600,
        type: BottomNavigationBarType.fixed,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.explore_outlined),
            activeIcon: Icon(Icons.explore),
            label: 'Spots',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.restaurant_outlined),
            activeIcon: Icon(Icons.restaurant),
            label: 'LocalEats',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.bookmark_outline),
            activeIcon: Icon(Icons.bookmark),
            label: 'Saved',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.map_outlined),
            activeIcon: Icon(Icons.map),
            label: 'Explorer',
          ),
          BottomNavigationBarItem(
            icon: Icon(user?.role == 'admin' ? Icons.admin_panel_settings_outlined : Icons.person_outline),
            activeIcon: Icon(user?.role == 'admin' ? Icons.admin_panel_settings : Icons.person),
            label: user?.role == 'admin' ? 'Admin' : 'Profile',
          ),
        ],
      ),
    );
  }
}
