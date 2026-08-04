import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/itinerary_controller.dart';
import '../controllers/spot_controller.dart';
import '../controllers/localeats_controller.dart';
import '../constants/app_colors.dart';
import '../constants/app_styles.dart';
import '../widgets/route_summary_card.dart';
import '../widgets/timeline_step_card.dart';

class ItineraryScreen extends StatefulWidget {
  const ItineraryScreen({super.key});

  @override
  State<ItineraryScreen> createState() => _ItineraryScreenState();
}

class _ItineraryScreenState extends State<ItineraryScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final itineraryCtrl = Provider.of<ItineraryController>(context, listen: false);
      final spotCtrl = Provider.of<SpotController>(context, listen: false);
      final foodCtrl = Provider.of<LocalEatsController>(context, listen: false);
      
      itineraryCtrl.generateProximityItinerary(spotCtrl.spots, foodCtrl.restaurants);
    });
  }

  @override
  Widget build(BuildContext context) {
    final itineraryCtrl = Provider.of<ItineraryController>(context);
    final itinerarySteps = itineraryCtrl.itinerarySteps;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Your Day Plan',
            style: TextStyle(
                color: AppColors.primaryDark, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: AppColors.primaryDark),
      ),
      body: itineraryCtrl.isGeneratingItinerary
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : itinerarySteps.isEmpty
              ? _buildEmptyState()
              : SingleChildScrollView(
                  padding: AppStyles.defaultScreenPadding,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      RouteSummaryCard(stepCount: itinerarySteps.length),
                      const SizedBox(height: AppStyles.padXl),
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: itinerarySteps.length,
                        itemBuilder: (context, idx) {
                          final step = itinerarySteps[idx];
                          final isLast = idx == itinerarySteps.length - 1;
                          final dayLabel = step['day_label'] as String?;

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (dayLabel != null) ...[
                                const SizedBox(height: AppStyles.padSm),
                                Text(
                                  dayLabel,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primaryDark,
                                  ),
                                ),
                                const SizedBox(height: AppStyles.padMd),
                              ],
                              TimelineStepCard(
                                step: step,
                                index: idx,
                                isLast: isLast,
                              ),
                            ],
                          );
                        },
                      ),
                      Container(
                        padding: AppStyles.defaultPadding,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: AppStyles.defaultRadius,
                          border: Border.all(color: AppColors.accentLight),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.directions_walk, color: AppColors.primary),
                            const SizedBox(width: AppStyles.padSm),
                            Text(
                              'Optimized by Nearest Neighbor Routing',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primaryDark),
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

  Widget _buildEmptyState() {
    return Center(
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
                      color: AppColors.accentLight.withValues(alpha: 0.3),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.route,
                        size: 64, color: AppColors.primary),
                  ),
                  const SizedBox(height: AppStyles.padMd),
                  const Text('Not enough saved places',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryDark)),
                  const SizedBox(height: AppStyles.padSm),
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
    );
  }
}
