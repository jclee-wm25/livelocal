import 'package:flutter/material.dart';
import '../models/guide_model.dart';

class GuideDetailScreen extends StatelessWidget {
  final GuideModel guide;

  const GuideDetailScreen({super.key, required this.guide});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(guide.locationName, style: const TextStyle(color: Color(0xFF2D6A4F), fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0.5,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              guide.title,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.place, size: 16, color: Color(0xFF2D6A4F)),
                const SizedBox(width: 4),
                Text('${guide.locationName}, ${guide.state}', style: TextStyle(color: Colors.grey.shade700)),
                const Spacer(),
                const Icon(Icons.schedule, size: 16, color: Color(0xFF2D6A4F)),
                const SizedBox(width: 4),
                Text('Est. ${guide.estimatedDuration}', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2D6A4F))),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 12),
            const Text('Trail Overview', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              guide.routeOverview,
              style: TextStyle(color: Colors.grey.shade800, height: 1.5, fontSize: 14),
            ),
            const SizedBox(height: 20),
            const Text('Recommended Stops', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: guide.stops.map((stop) {
                return Chip(
                  avatar: const Icon(Icons.check_circle, size: 16, color: Color(0xFF2D6A4F)),
                  label: Text(stop),
                  backgroundColor: const Color(0xFF74C69D).withOpacity(0.2),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            const Text('Step-by-Step Walking Sequence', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 14),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: guide.walkingSequence.length,
              itemBuilder: (context, index) {
                final step = guide.walkingSequence[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const CircleAvatar(
                        radius: 12,
                        backgroundColor: Color(0xFF2D6A4F),
                        child: Icon(Icons.directions_walk, size: 14, color: Colors.white),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          step,
                          style: const TextStyle(fontSize: 14, height: 1.4),
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
