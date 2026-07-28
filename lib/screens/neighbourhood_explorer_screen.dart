import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/guide_controller.dart';
import 'guide_detail_screen.dart';

class NeighbourhoodExplorerScreen extends StatefulWidget {
  const NeighbourhoodExplorerScreen({super.key});

  @override
  State<NeighbourhoodExplorerScreen> createState() => _NeighbourhoodExplorerScreenState();
}

class _NeighbourhoodExplorerScreenState extends State<NeighbourhoodExplorerScreen> {
  final List<String> _states = ['All', 'Kuala Lumpur', 'Perak', 'Penang', 'Johor'];

  @override
  Widget build(BuildContext context) {
    final guideCtrl = Provider.of<GuideController>(context);
    final approvedGuides = guideCtrl.approvedGuides;

    return Scaffold(
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: const Color(0xFF2D6A4F).withOpacity(0.05),
            child: Row(
              children: [
                const Icon(Icons.map, color: Color(0xFF2D6A4F)),
                const SizedBox(width: 8),
                const Text(
                  'Neighbourhood Explorer Day Guides',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF2D6A4F)),
                ),
                const Spacer(),
                DropdownButton<String>(
                  value: guideCtrl.selectedState,
                  underline: const SizedBox(),
                  icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF2D6A4F)),
                  items: _states.map((s) => DropdownMenuItem(value: s, child: Text('State: $s'))).toList(),
                  onChanged: (val) {
                    if (val != null) guideCtrl.setStateFilter(val);
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: guideCtrl.isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF2D6A4F)))
                : approvedGuides.isEmpty
                    ? const Center(child: Text('No guides available for this state.'))
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: approvedGuides.length,
                        itemBuilder: (context, idx) {
                          final g = approvedGuides[idx];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            elevation: 2,
                            child: InkWell(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => GuideDetailScreen(guide: g)),
                                );
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(18),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF74C69D).withOpacity(0.2),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            g.locationName,
                                            style: const TextStyle(color: Color(0xFF2D6A4F), fontWeight: FontWeight.bold, fontSize: 12),
                                          ),
                                        ),
                                        const Spacer(),
                                        Row(
                                          children: [
                                            const Icon(Icons.timer, size: 14, color: Colors.grey),
                                            const SizedBox(width: 4),
                                            Text(g.estimatedDuration, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                          ],
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      g.title,
                                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      g.routeOverview,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                                    ),
                                    const SizedBox(height: 14),
                                    Wrap(
                                      spacing: 8,
                                      children: g.stops.map((stop) {
                                        return Chip(
                                          label: Text(stop, style: const TextStyle(fontSize: 11)),
                                          backgroundColor: Colors.grey.shade100,
                                          visualDensity: VisualDensity.compact,
                                        );
                                      }).toList(),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
