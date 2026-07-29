import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
    final itinerarySteps = itineraryCtrl.generateProximityItinerary(
        spotCtrl.spots, foodCtrl.restaurants);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9F8),
      appBar: AppBar(
        title: const Text('Your Day Plan',
            style: TextStyle(
                color: Color(0xFF1B4332), fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Color(0xFF1B4332)),
        systemOverlayStyle: SystemUiOverlayStyle.dark,
      ),
      body: itinerarySteps.isEmpty
          ? Center(
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
                            child: const Icon(Icons.route,
                                size: 64, color: Color(0xFF2D6A4F)),
                          ),
                          const SizedBox(height: 16),
                          const Text('Not enough saved places',
                              style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1B4332))),
                          const SizedBox(height: 8),
                          Text(
                            'Save at least 1 spot or eatery to generate your day plan.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Route summary card
                  TweenAnimationBuilder<double>(
                    duration: const Duration(milliseconds: 600),
                    tween: Tween<double>(begin: 0, end: 1),
                    builder: (context, val, child) {
                      return Opacity(
                        opacity: val,
                        child: Transform.translate(
                            offset: Offset(0, 20 * (1 - val)), child: child),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(16),
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
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFD700).withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.auto_awesome,
                                color: Color(0xFFFFD700)),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Optimised Travel Route',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16)),
                                const SizedBox(height: 4),
                                Text(
                                  '${itinerarySteps.length} stops • grouped by proximity',
                                  style: const TextStyle(
                                      color: Colors.white70, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Timeline steps
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: itinerarySteps.length,
                    itemBuilder: (context, idx) {
                      final step = itinerarySteps[idx];
                      final isLast = idx == itinerarySteps.length - 1;

                      return TweenAnimationBuilder<double>(
                        duration: Duration(milliseconds: 500 + (idx * 150)),
                        tween: Tween<double>(begin: 0, end: 1),
                        curve: Curves.easeOutCubic,
                        builder: (context, val, child) {
                          return Transform.translate(
                            offset: Offset(50 * (1 - val), 0),
                            child: Opacity(opacity: val, child: child),
                          );
                        },
                        child: IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Timeline indicator column
                              Column(
                                children: [
                                  Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(colors: [
                                        Color(0xFF74C69D),
                                        Color(0xFF2D6A4F)
                                      ]),
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                            color: const Color(0xFF2D6A4F)
                                                .withOpacity(0.4),
                                            blurRadius: 6,
                                            offset: const Offset(0, 2))
                                      ],
                                    ),
                                    child: Center(
                                      child: Text('${idx + 1}',
                                          style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14)),
                                    ),
                                  ),
                                  if (!isLast)
                                    Expanded(
                                      child: Container(
                                        width: 2,
                                        color: const Color(0xFFB7E4C7),
                                        margin: const EdgeInsets.symmetric(
                                            vertical: 4),
                                      ),
                                    ),
                                  if (isLast) const SizedBox(height: 24),
                                ],
                              ),
                              const SizedBox(width: 16),

                              // Step card
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.only(bottom: 24),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(16),
                                      boxShadow: [
                                        BoxShadow(
                                          color:
                                              Colors.black.withOpacity(0.04),
                                          blurRadius: 10,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        borderRadius:
                                            BorderRadius.circular(16),
                                        onTap: () =>
                                            HapticFeedback.selectionClick(),
                                        child: Padding(
                                          padding: const EdgeInsets.all(16),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Container(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                        horizontal: 8,
                                                        vertical: 4),
                                                    decoration: BoxDecoration(
                                                      color: const Color(
                                                          0xFFF0FBF5),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              8),
                                                    ),
                                                    child: Text(
                                                      step['step'] ?? '',
                                                      style: const TextStyle(
                                                          color: Color(
                                                              0xFF2D6A4F),
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          fontSize: 11),
                                                    ),
                                                  ),
                                                  const Spacer(),
                                                  Container(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                        horizontal: 8,
                                                        vertical: 4),
                                                    decoration: BoxDecoration(
                                                      color:
                                                          Colors.grey.shade100,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              8),
                                                    ),
                                                    child: Text(
                                                      step['type'] ?? '',
                                                      style: TextStyle(
                                                          color: Colors
                                                              .grey.shade600,
                                                          fontSize: 11,
                                                          fontWeight:
                                                              FontWeight.w600),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 10),
                                              Text(
                                                step['title'] ?? '',
                                                style: const TextStyle(
                                                    fontSize: 18,
                                                    fontWeight: FontWeight.bold,
                                                    color: Color(0xFF1B4332)),
                                              ),
                                              const SizedBox(height: 8),
                                              Row(
                                                children: [
                                                  const Icon(Icons.place,
                                                      size: 14,
                                                      color: Color(0xFF74C69D)),
                                                  const SizedBox(width: 4),
                                                  Expanded(
                                                    child: Text(
                                                        step['location'] ?? '',
                                                        style: TextStyle(
                                                            color: Colors
                                                                .grey.shade700,
                                                            fontSize: 13)),
                                                  ),
                                                ],
                                              ),
                                              if (step['tip'] != null) ...[
                                                const SizedBox(height: 8),
                                                Container(
                                                  padding:
                                                      const EdgeInsets.all(10),
                                                  decoration: BoxDecoration(
                                                    color: const Color(
                                                        0xFFFFF8E1),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            8),
                                                  ),
                                                  child: Row(
                                                    children: [
                                                      Icon(Icons.lightbulb_outline,
                                                          size: 16,
                                                          color: Colors.amber.shade800),
                                                      const SizedBox(width: 6),
                                                      Expanded(
                                                        child: Text(
                                                          step['tip']!,
                                                          style: TextStyle(
                                                              fontSize: 12,
                                                              color: Colors
                                                                  .amber
                                                                  .shade800,
                                                              height: 1.3),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),

                  // Summary footer
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFB7E4C7)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.directions_walk,
                            color: Color(0xFF2D6A4F)),
                        const SizedBox(width: 8),
                        Text(
                          'Estimated journey: ${itinerarySteps.length * 45} – ${itinerarySteps.length * 90} mins',
                          style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1B4332)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 110),
                ],
              ),
            ),
    );
  }
}
