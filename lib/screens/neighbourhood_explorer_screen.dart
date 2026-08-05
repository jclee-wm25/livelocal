import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/guide_controller.dart';
import 'guide_detail_screen.dart';
import '../constants/app_colors.dart';
import '../constants/app_styles.dart';
import '../widgets/hero_guide_sliver.dart';
import '../widgets/guide_list_item.dart';

class NeighbourhoodExplorerScreen extends StatefulWidget {
  const NeighbourhoodExplorerScreen({super.key});
  @override
  State<NeighbourhoodExplorerScreen> createState() =>
      _NeighbourhoodExplorerScreenState();
}

class _NeighbourhoodExplorerScreenState
    extends State<NeighbourhoodExplorerScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animCtrl;
  final List<String> _states = [
    'All',
    'Kuala Lumpur',
    'Penang',
    'Perak',
    'Johor',
    'Melaka',
    'Selangor'
  ];

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800))
      ..forward();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<GuideController>(context, listen: false).loadGuides();
    });
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final guideCtrl = Provider.of<GuideController>(context);
    final guides = guideCtrl.approvedGuides;
    final selectedState = guideCtrl.selectedState;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          HeroGuideSliver(
            opacityAnim: _animCtrl,
            slideAnim: Tween<Offset>(
                    begin: const Offset(0, 0.5), end: Offset.zero)
                .animate(
                    CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut)),
            states: _states,
            selectedState: selectedState,
            onStateSelected: guideCtrl.setStateFilter,
          ),
          guideCtrl.isLoading
              ? const SliverFillRemaining(
                  child: Center(
                      child:
                          CircularProgressIndicator(color: AppColors.primary)))
              : guides.isEmpty
                  ? SliverFillRemaining(
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.explore_off,
                                size: 64, color: Colors.grey.shade400),
                            const SizedBox(height: AppStyles.padMd),
                            Text('No guides for $selectedState yet',
                                style: TextStyle(
                                    color: Colors.grey.shade600, fontSize: 16)),
                          ],
                        ),
                      ),
                    )
                  : SliverPadding(
                      padding: const EdgeInsets.only(
                        left: AppStyles.padMd,
                        right: AppStyles.padMd,
                        top: AppStyles.padMd,
                        bottom: 110,
                      ),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final guide = guides[index];
                            return TweenAnimationBuilder<double>(
                              duration:
                                  Duration(milliseconds: 400 + (index * 120)),
                              tween: Tween<double>(begin: 0, end: 1),
                              curve: Curves.easeOutCubic,
                              builder: (context, val, child) {
                                return Transform.translate(
                                  offset: Offset(0, 40 * (1 - val)),
                                  child: Opacity(opacity: val, child: child),
                                );
                              },
                              child: GuideListItem(
                                guide: guide,
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) =>
                                          GuideDetailScreen(guide: guide)),
                                ),
                              ),
                            );
                          },
                          childCount: guides.length,
                        ),
                      ),
                    ),
        ],
      ),
    );
  }
}
