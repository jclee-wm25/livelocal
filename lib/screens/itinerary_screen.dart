import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/itinerary_controller.dart';
import '../controllers/spot_controller.dart';
import '../controllers/localeats_controller.dart';

class ItineraryScreen extends StatelessWidget {
  const ItineraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final itineraryCtrl = Provider.of<ItineraryController>(context);
    final spotCtrl = Provider.of<SpotController>(context);
    final foodCtrl = Provider.of<LocalEatsController>(context);

    final itinerarySteps = itineraryCtrl.generateProximityItinerary(spotCtrl.spots, foodCtrl.restaurants);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Auto-Generated Day Itinerary', style: TextStyle(color: Color(0xFF2D6A4F), fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0.5,
      ),
      body: itinerarySteps.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.route, size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 12),
                  const Text('Save at least 1 spot or eatery to generate your day plan.', style: TextStyle(color: Colors.grey)),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2D6A4F).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF2D6A4F)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.auto_awesome, color: Color(0xFF2D6A4F)),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Optimized Travel Route: Grouped automatically by geographic proximity to minimize travel time.',
                            style: TextStyle(color: Color(0xFF2D6A4F), fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: itinerarySteps.length,
                    itemBuilder: (context, idx) {
                      final step = itinerarySteps[idx];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 20),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Column(
                              children: [
                                CircleAvatar(
                                  radius: 16,
                                  backgroundColor: const Color(0xFF2D6A4F),
                                  child: Text('${idx + 1}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                ),
                                if (idx < itinerarySteps.length - 1)
                                  Container(
                                    width: 2,
                                    height: 60,
                                    color: const Color(0xFF74C69D),
                                  ),
                              ],
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Card(
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                elevation: 1.5,
                                child: Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            step['step'] ?? '',
                                            style: const TextStyle(color: Color(0xFF2D6A4F), fontWeight: FontWeight.bold, fontSize: 12),
                                          ),
                                          const Spacer(),
                                          Text(
                                            step['type'] ?? '',
                                            style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        step['title'] ?? '',
                                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(height: 4),
                                      Text('📍 ${step['location']}', style: TextStyle(color: Colors.grey.shade700, fontSize: 12)),
                                      const SizedBox(height: 4),
                                      Text('⏰ ${step['best_time']}', style: const TextStyle(fontSize: 12, color: Colors.black87)),
                                      const SizedBox(height: 6),
                                      Text('💡 ${step['activity']}', style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
    );
  }
}
