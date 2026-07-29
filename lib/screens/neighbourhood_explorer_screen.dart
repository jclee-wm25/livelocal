import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../controllers/guide_controller.dart';
import 'guide_detail_screen.dart';

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
  String _selectedState = 'All';
  final List<String> _states = [
    'All',
    'KL',
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
    final guides = _selectedState == 'All'
        ? guideCtrl.guides
        : guideCtrl.guides
            .where((g) =>
                g.locationName.contains(_selectedState) ||
                g.state == _selectedState)
            .toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9F8),
      body: CustomScrollView(
        slivers: [
          // Hero SliverAppBar
          SliverAppBar(
            expandedHeight: 200.0,
            floating: false,
            pinned: true,
            backgroundColor: const Color(0xFF1B4332),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF1B4332), Color(0xFF2D6A4F),
                        Color(0xFF40916C)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24.0, vertical: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        FadeTransition(
                          opacity: _animCtrl,
                          child: const Text(
                            '🗺️ Explore Like a Local',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              height: 1.2,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        SlideTransition(
                          position: Tween<Offset>(
                                  begin: const Offset(0, 0.5),
                                  end: Offset.zero)
                              .animate(CurvedAnimation(
                                  parent: _animCtrl,
                                  curve: Curves.easeOut)),
                          child: const Text(
                            'Curated walking guides for Malaysia\'s hidden gems',
                            style: TextStyle(
                                color: Colors.white70, fontSize: 14),
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
                color: const Color(0xFF1B4332),
                child: SizedBox(
                  height: 56,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    itemCount: _states.length,
                    itemBuilder: (context, i) {
                      final s = _states[i];
                      final isSelected = s == _selectedState;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeInOut,
                          child: GestureDetector(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              setState(() => _selectedState = s);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 6),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? const Color(0xFFFFD700)
                                    : Colors.white.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                    color: isSelected
                                        ? const Color(0xFFFFD700)
                                        : Colors.white38),
                              ),
                              child: Text(
                                s,
                                style: TextStyle(
                                  color: isSelected
                                      ? const Color(0xFF1B4332)
                                      : Colors.white,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.w500,
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
          ),

          // Guide list
          guideCtrl.isLoading
              ? const SliverFillRemaining(
                  child: Center(
                      child: CircularProgressIndicator(
                          color: Color(0xFF2D6A4F))))
              : guides.isEmpty
                  ? SliverFillRemaining(
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.explore_off,
                                size: 64, color: Colors.grey.shade400),
                            const SizedBox(height: 12),
                            Text('No guides for $_selectedState yet',
                                style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 16)),
                          ],
                        ),
                      ),
                    )
                  : SliverPadding(
                      padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 110),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final guide = guides[index];
                            return TweenAnimationBuilder<double>(
                              duration: Duration(
                                  milliseconds: 400 + (index * 120)),
                              tween: Tween<double>(begin: 0, end: 1),
                              curve: Curves.easeOutCubic,
                              builder: (context, val, child) {
                                return Transform.translate(
                                  offset: Offset(0, 40 * (1 - val)),
                                  child:
                                      Opacity(opacity: val, child: child),
                                );
                              },
                              child: GestureDetector(
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) =>
                                            GuideDetailScreen(guide: guide)),
                                  );
                                },
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 20),
                                  height: 220,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(20),
                                    boxShadow: [
                                      BoxShadow(
                                        color:
                                            Colors.black.withOpacity(0.12),
                                        blurRadius: 16,
                                        offset: const Offset(0, 6),
                                      ),
                                    ],
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(20),
                                    child: Stack(
                                      fit: StackFit.expand,
                                      children: [
                                        // Background gradient
                                        Container(
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: [
                                                const Color(0xFF1B4332),
                                                const Color(0xFF40916C),
                                                Colors.teal.shade600,
                                              ],
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                            ),
                                          ),
                                        ),
                                        // Decorative circles
                                        Positioned(
                                          top: -30,
                                          right: -30,
                                          child: Container(
                                            width: 140,
                                            height: 140,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: Colors.white
                                                  .withOpacity(0.06),
                                            ),
                                          ),
                                        ),
                                        // Gradient overlay bottom
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
                                                  Colors.black
                                                      .withOpacity(0.7),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                        // Content
                                        Padding(
                                          padding: const EdgeInsets.all(20),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Container(
                                                    padding:
                                                        const EdgeInsets
                                                            .symmetric(
                                                            horizontal: 10,
                                                            vertical: 5),
                                                    decoration:
                                                        BoxDecoration(
                                                      color: Colors.white
                                                          .withOpacity(0.2),
                                                      borderRadius:
                                                          BorderRadius
                                                              .circular(20),
                                                      border: Border.all(
                                                          color:
                                                              Colors.white38),
                                                    ),
                                                    child: Row(
                                                      children: [
                                                        const Icon(
                                                            Icons.place,
                                                            color:
                                                                Colors.white,
                                                            size: 12),
                                                        const SizedBox(
                                                            width: 4),
                                                        Text(
                                                          guide.locationName,
                                                          style: const TextStyle(
                                                              color: Colors
                                                                  .white,
                                                              fontSize: 11,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  const Spacer(),
                                                  Container(
                                                    padding:
                                                        const EdgeInsets
                                                            .symmetric(
                                                            horizontal: 10,
                                                            vertical: 5),
                                                    decoration:
                                                        BoxDecoration(
                                                      color: const Color(
                                                              0xFFFFD700)
                                                          .withOpacity(0.2),
                                                      borderRadius:
                                                          BorderRadius
                                                              .circular(20),
                                                      border: Border.all(
                                                          color: const Color(
                                                                  0xFFFFD700)
                                                              .withOpacity(
                                                                  0.5)),
                                                    ),
                                                    child: Row(
                                                      children: [
                                                        const Icon(
                                                            Icons
                                                                .access_time,
                                                            color: Color(
                                                                0xFFFFD700),
                                                            size: 12),
                                                        const SizedBox(
                                                            width: 4),
                                                        Text(
                                                          guide.estimatedDuration,
                                                          style: const TextStyle(
                                                              color: Color(
                                                                  0xFFFFD700),
                                                              fontSize: 11,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const Spacer(),
                                              Text(
                                                guide.title,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 20,
                                                  fontWeight:
                                                      FontWeight.bold,
                                                  height: 1.2,
                                                ),
                                              ),
                                              const SizedBox(height: 8),
                                              Text(
                                                guide.routeOverview,
                                                maxLines: 2,
                                                overflow:
                                                    TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                    color: Colors.white70,
                                                    fontSize: 12),
                                              ),
                                              const SizedBox(height: 12),
                                              Wrap(
                                                spacing: 6,
                                                runSpacing: 4,
                                                children: guide.stops
                                                    .take(3)
                                                    .map((stop) => Container(
                                                          padding:
                                                              const EdgeInsets
                                                                  .symmetric(
                                                                  horizontal:
                                                                      8,
                                                                  vertical:
                                                                      3),
                                                          decoration:
                                                              BoxDecoration(
                                                            color: Colors
                                                                .white
                                                                .withOpacity(
                                                                    0.15),
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        8),
                                                          ),
                                                          child: Text(
                                                            stop,
                                                            style: const TextStyle(
                                                                color: Colors
                                                                    .white,
                                                                fontSize:
                                                                    10),
                                                          ),
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
