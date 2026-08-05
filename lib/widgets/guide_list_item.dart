import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/guide_model.dart';
import '../constants/app_colors.dart';
import '../constants/app_styles.dart';

class GuideListItem extends StatelessWidget {
  final GuideModel guide;
  final VoidCallback onTap;

  const GuideListItem({
    super.key,
    required this.guide,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: AppStyles.padLg),
        height: 220,
        decoration: BoxDecoration(
          borderRadius: AppStyles.cardRadius,
          boxShadow: AppStyles.heavyShadow,
        ),
        child: ClipRRect(
          borderRadius: AppStyles.cardRadius,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primaryDark,
                      AppColors.accentMid,
                      Colors.teal.shade600,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
              Positioned(
                top: -30,
                right: -30,
                child: Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.06),
                  ),
                ),
              ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: 140,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.7),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(AppStyles.padLg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: AppStyles.pillRadius,
                            border: Border.all(color: Colors.white38),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.place,
                                  color: Colors.white, size: 12),
                              const SizedBox(width: AppStyles.padXs),
                              Text(
                                guide.locationName,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: AppColors.gold.withValues(alpha: 0.2),
                            borderRadius: AppStyles.pillRadius,
                            border: Border.all(
                                color: AppColors.gold.withValues(alpha: 0.5)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.access_time,
                                  color: AppColors.gold, size: 12),
                              const SizedBox(width: AppStyles.padXs),
                              Text(
                                guide.estimatedDuration,
                                style: const TextStyle(
                                    color: AppColors.gold,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Text(guide.title,
                        style: AppStyles.headerWhite.copyWith(fontSize: 20)),
                    const SizedBox(height: AppStyles.padSm),
                    Text(
                      guide.routeOverview,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppStyles.subtitleWhite.copyWith(fontSize: 12),
                    ),
                    const SizedBox(height: AppStyles.padMd),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: guide.stops
                          .take(3)
                          .map((stop) => Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.15),
                                  borderRadius: AppStyles.defaultRadius,
                                ),
                                child: Text(stop,
                                    style: const TextStyle(
                                        color: Colors.white, fontSize: 10)),
                              ))
                          .toList(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
