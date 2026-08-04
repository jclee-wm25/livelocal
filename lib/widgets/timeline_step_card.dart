import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/app_colors.dart';
import '../constants/app_styles.dart';

class TimelineStepCard extends StatelessWidget {
  final Map<String, Object> step;
  final int index;
  final bool isLast;
  
  const TimelineStepCard({
    super.key,
    required this.step,
    required this.index,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
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
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: AppStyles.defaultRadius,
                      onTap: () => HapticFeedback.selectionClick(),
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
                                    borderRadius: AppStyles.radiusSm == 8.0 
                                      ? BorderRadius.circular(8) 
                                      : BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    (step['step'] ?? '') as String,
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
                                    (step['type'] ?? '') as String,
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
                              (step['title'] ?? '') as String,
                              style: AppStyles.cardTitle,
                            ),
                            const SizedBox(height: AppStyles.padSm),
                            Row(
                              children: [
                                const Icon(Icons.place, size: 14, color: AppColors.accent),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                      (step['location'] ?? '') as String,
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
                                        (step['tip']! as String),
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
              ),
            ),
          ],
        ),
      ),
    );
  }
}
