import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_styles.dart';

/// 纯 UI 版本的行程页面 - 无功能实现
class ItineraryScreen extends StatefulWidget {
  const ItineraryScreen({super.key});

  @override
  State<ItineraryScreen> createState() => _ItineraryScreenState();
}

class _ItineraryScreenState extends State<ItineraryScreen> {
  // 模拟行程数据 - 仅用于 UI 展示
  final List<Map<String, dynamic>> _mockItinerarySteps = [
    {
      'step': 'Stop 1',
      'type': 'Spot',
      'title': 'Central Park',
      'location': 'New York, NY',
      'tip': 'Best visited in the morning for fewer crowds',
      'day_label': 'Day 1',
    },
    {
      'step': 'Stop 2',
      'type': 'Eatery',
      'title': 'Joe\'s Pizza',
      'location': 'Broadway, New York',
      'tip': 'Try their classic cheese slice',
    },
    {
      'step': 'Stop 3',
      'type': 'Spot',
      'title': 'Brooklyn Bridge',
      'location': 'Brooklyn, NY',
      'tip': 'Sunset views are spectacular from here',
    },
    {
      'step': 'Stop 4',
      'type': 'Eatery',
      'title': 'Katz\'s Delicatessen',
      'location': 'Lower East Side, New York',
      'tip': 'Don\'t miss their famous pastrami sandwich',
      'day_label': 'Day 2',
    },
    {
      'step': 'Stop 5',
      'type': 'Spot',
      'title': 'Statue of Liberty',
      'location': 'Liberty Island, NY',
      'tip': 'Book ferry tickets in advance',
    },
  ];

  @override
  Widget build(BuildContext context) {
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
      body: SingleChildScrollView(
        padding: AppStyles.defaultScreenPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildRouteSummaryCard(),
            const SizedBox(height: AppStyles.padXl),
            ..._buildTimelineSteps(),
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

  Widget _buildRouteSummaryCard() {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 600),
      tween: Tween<double>(begin: 0, end: 1),
      builder: (context, val, child) {
        return Opacity(
          opacity: val,
          child: Transform.translate(offset: Offset(0, 20 * (1 - val)), child: child),
        );
      },
      child: Container(
        padding: AppStyles.defaultPadding,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.primary, AppColors.primaryDark],
          ),
          borderRadius: AppStyles.defaultRadius,
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.3),
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
                color: AppColors.gold.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.auto_awesome, color: AppColors.gold),
            ),
            const SizedBox(width: AppStyles.padMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Optimised Travel Route',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: AppStyles.padXs),
                  Text(
                    '${_mockItinerarySteps.length} stops • grouped by proximity',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildTimelineSteps() {
    String? currentDay;
    final List<Widget> widgets = [];

    for (int i = 0; i < _mockItinerarySteps.length; i++) {
      final step = _mockItinerarySteps[i];
      final dayLabel = step['day_label'] as String?;
      final isLast = i == _mockItinerarySteps.length - 1;

      if (dayLabel != null && dayLabel != currentDay) {
        currentDay = dayLabel;
        widgets.add(const SizedBox(height: AppStyles.padSm));
        widgets.add(Text(
          dayLabel,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.primaryDark,
          ),
        ));
        widgets.add(const SizedBox(height: AppStyles.padMd));
      }

      widgets.add(_buildTimelineStepCard(step, i, isLast));
    }

    return widgets;
  }

  Widget _buildTimelineStepCard(Map<String, dynamic> step, int index, bool isLast) {
    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 500 + (index * 150)),
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
                    gradient: const LinearGradient(colors: [AppColors.accent, AppColors.primary]),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.4),
                          blurRadius: 6,
                          offset: const Offset(0, 2))
                    ],
                  ),
                  child: Center(
                    child: Text('${index + 1}',
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: AppColors.accentLight,
                      margin: const EdgeInsets.symmetric(vertical: AppStyles.padXs),
                    ),
                  ),
                if (isLast) const SizedBox(height: AppStyles.padLg),
              ],
            ),
            const SizedBox(width: AppStyles.padMd),
            // Step card
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: AppStyles.padLg),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: AppStyles.defaultRadius,
                    boxShadow: AppStyles.defaultShadow,
                  ),
                  child: Padding(
                    padding: AppStyles.defaultPadding,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.mintBg,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                step['step'] as String,
                                style: const TextStyle(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11),
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                step['type'] as String,
                                style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          step['title'] as String,
                          style: AppStyles.cardTitle,
                        ),
                        const SizedBox(height: AppStyles.padSm),
                        Row(
                          children: [
                            const Icon(Icons.place, size: 14, color: AppColors.accent),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                  step['location'] as String,
                                  style: AppStyles.cardSubtitle),
                            ),
                          ],
                        ),
                        if (step['tip'] != null) ...[
                          const SizedBox(height: AppStyles.padSm),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.tipBg,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.lightbulb_outline,
                                    size: 16, color: Colors.amber.shade800),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    step['tip'] as String,
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.amber.shade800,
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
          ],
        ),
      ),
    );
  }
}
