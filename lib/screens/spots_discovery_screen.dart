import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/spot_controller.dart';
import '../controllers/auth_controller.dart';
import 'spot_detail_screen.dart';
import 'submit_spot_screen.dart';

class SpotsDiscoveryScreen extends StatefulWidget {
  const SpotsDiscoveryScreen({super.key});

  @override
  State<SpotsDiscoveryScreen> createState() => _SpotsDiscoveryScreenState();
}

class _SpotsDiscoveryScreenState extends State<SpotsDiscoveryScreen> {
  final TextEditingController _searchCtrl = TextEditingController();

  final List<String> _states = ['All', 'Penang', 'Kuala Lumpur', 'Perak', 'Johor', 'Selangor', 'Melaka', 'Sabah', 'Sarawak'];
  final List<String> _categories = ['All', 'Kopitiam', 'Pasar Malam', 'Indie Cafe', 'Park / Walkway', 'Hawker Food', 'Heritage Spot'];

  @override
  Widget build(BuildContext context) {
    final spotCtrl = Provider.of<SpotController>(context);
    final approvedSpots = spotCtrl.approvedSpots;

    return Scaffold(
      body: Column(
        children: [
          // Search & Filter Header Bar
          Container(
            padding: const EdgeInsets.all(16),
            color: const Color(0xFF2D6A4F).withOpacity(0.05),
            child: Column(
              children: [
                TextField(
                  controller: _searchCtrl,
                  onChanged: (val) => spotCtrl.filter(query: val),
                  decoration: InputDecoration(
                    hintText: 'Search local spots in Malaysia...',
                    prefixIcon: const Icon(Icons.search, color: Color(0xFF2D6A4F)),
                    suffixIcon: _searchCtrl.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchCtrl.clear();
                              spotCtrl.filter(query: '');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      DropdownButton<String>(
                        value: spotCtrl.selectedState,
                        underline: const SizedBox(),
                        icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF2D6A4F)),
                        items: _states.map((s) => DropdownMenuItem(value: s, child: Text('State: $s'))).toList(),
                        onChanged: (val) {
                          if (val != null) spotCtrl.filter(state: val);
                        },
                      ),
                      const SizedBox(width: 16),
                      DropdownButton<String>(
                        value: spotCtrl.selectedCategory,
                        underline: const SizedBox(),
                        icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF2D6A4F)),
                        items: _categories.map((c) => DropdownMenuItem(value: c, child: Text('Category: $c'))).toList(),
                        onChanged: (val) {
                          if (val != null) spotCtrl.filter(category: val);
                        },
                      ),
                      const SizedBox(width: 16),
                      TextButton.icon(
                        icon: const Icon(Icons.refresh, size: 16, color: Color(0xFF2D6A4F)),
                        label: const Text('Reset', style: TextStyle(color: Color(0xFF2D6A4F))),
                        onPressed: () {
                          _searchCtrl.clear();
                          spotCtrl.resetFilters();
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Spots Listing Grid/List View
          Expanded(
            child: spotCtrl.isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF2D6A4F)))
                : approvedSpots.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.location_off, size: 64, color: Colors.grey.shade400),
                            const SizedBox(height: 12),
                            const Text('No local spots match your filter.', style: TextStyle(fontSize: 16, color: Colors.grey)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: approvedSpots.length,
                        itemBuilder: (context, index) {
                          final spot = approvedSpots[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            elevation: 2,
                            clipBehavior: Clip.antiAlias,
                            child: InkWell(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => SpotDetailScreen(spot: spot)),
                                );
                              },
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Stack(
                                    children: [
                                      Image.network(
                                        spot.imageUrl,
                                        height: 180,
                                        width: double.infinity,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => Container(
                                          height: 180,
                                          color: Colors.grey.shade200,
                                          child: const Icon(Icons.store, size: 48, color: Colors.grey),
                                        ),
                                      ),
                                      Positioned(
                                        top: 12,
                                        left: 12,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF2D6A4F),
                                            borderRadius: BorderRadius.circular(20),
                                          ),
                                          child: Text(
                                            spot.category,
                                            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      ),
                                      Positioned(
                                        top: 12,
                                        right: 12,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: Colors.black.withOpacity(0.7),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Row(
                                            children: [
                                              const Icon(Icons.star, color: Colors.amber, size: 14),
                                              const SizedBox(width: 4),
                                              Text(
                                                spot.rating.toStringAsFixed(1),
                                                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          spot.name,
                                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            const Icon(Icons.location_on_outlined, size: 16, color: Color(0xFF2D6A4F)),
                                            const SizedBox(width: 4),
                                            Text(
                                              '${spot.city}, ${spot.state}',
                                              style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                                            ),
                                            const Spacer(),
                                            Text(
                                              spot.priceRange,
                                              style: const TextStyle(color: Color(0xFF2D6A4F), fontWeight: FontWeight.bold),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          spot.description,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                                        ),
                                        const SizedBox(height: 12),
                                        Row(
                                          children: [
                                            const Icon(Icons.access_time, size: 14, color: Colors.grey),
                                            const SizedBox(width: 4),
                                            Text(
                                              'Best time: ${spot.bestTime}',
                                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF2D6A4F),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SubmitSpotScreen()),
          );
        },
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Submit Spot', style: TextStyle(color: Colors.white)),
      ),
    );
  }
}
