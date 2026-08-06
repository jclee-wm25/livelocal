import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_styles.dart';

class HeroGuideSliver extends StatelessWidget {
  final Animation<double> opacityAnim;
  final Animation<Offset> slideAnim;
  final List<String> states;
  final String selectedState;
  final Function(String) onStateSelected;

  const HeroGuideSliver({
    super.key,
    required this.opacityAnim,
    required this.slideAnim,
    required this.states,
    required this.selectedState,
    required this.onStateSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 200.0,
      floating: false,
      pinned: true,
      backgroundColor: AppColors.primaryDark,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.primaryDark,
                AppColors.primary,
                AppColors.accentMid
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: AppStyles.defaultScreenPadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  FadeTransition(
                    opacity: opacityAnim,
                    child: const Text('🗺️ Explore Like a Local',
                        style: AppStyles.headerWhite),
                  ),
                  const SizedBox(height: AppStyles.padSm),
                  SlideTransition(
                    position: slideAnim,
                    child: const Text(
                      'Curated walking guides for Malaysia\'s hidden gems',
                      style: AppStyles.subtitleWhite,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(56),
        child: Container(
          color: AppColors.primaryDark,
          child: SizedBox(
            height: 56,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                  horizontal: AppStyles.padMd, vertical: 10),
              itemCount: states.length,
              itemBuilder: (context, i) {
                final s = states[i];
                final isSelected = s == selectedState;
                return Padding(
                  padding: const EdgeInsets.only(right: AppStyles.padSm),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeInOut,
                    child: GestureDetector(
                      onTap: () => onStateSelected(s),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: AppStyles.padMd, vertical: 6),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.gold
                              : Colors.white.withValues(alpha: 0.15),
                          borderRadius: AppStyles.pillRadius,
                          border: Border.all(
                              color:
                                  isSelected ? AppColors.gold : Colors.white38),
                        ),
                        child: Text(
                          s,
                          style: TextStyle(
                            color: isSelected
                                ? AppColors.primaryDark
                                : Colors.white,
                            fontWeight:
                                isSelected ? FontWeight.bold : FontWeight.w500,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
