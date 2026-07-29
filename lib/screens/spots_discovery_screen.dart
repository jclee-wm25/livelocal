import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:ui';

import '../controllers/spot_controller.dart';
import '../controllers/auth_controller.dart';
import 'spot_detail_screen.dart';
import 'submit_spot_screen.dart';

class SpotsDiscoveryScreen extends StatefulWidget {
  const SpotsDiscoveryScreen({super.key});

  @override
  State<SpotsDiscoveryScreen> createState() => _SpotsDiscoveryScreenState();
}

class _SpotsDiscoveryScreenState extends State<SpotsDiscoveryScreen> with TickerProviderStateMixin {
  final TextEditingController _searchCtrl = TextEditingController();
  bool _isSearchExpanded = false;

  final List<String> _states = ['All', 'Penang', 'Kuala Lumpur', 'Perak', 'Johor', 'Selangor', 'Melaka', 'Sabah', 'Sarawak'];
  final List<String> _categories = ['All', 'Kopitiam', 'Pasar Malam', 'Indie Cafe', 'Park / Walkway', 'Hawker Food', 'Heritage Spot'];

  late AnimationController _heroTextController;
  late Animation<double> _heroTextOpacity;
  late Animation<Offset> _heroTextSlide;

  @override
  void initState() {
    super.initState();
    _heroTextController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _heroTextOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _heroTextController, curve: const Interval(0.2, 1.0, curve: Curves.easeOut)),
    );
    _heroTextSlide = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
      CurvedAnimation(parent: _heroTextController, curve: const Interval(0.2, 1.0, curve: Curves.easeOutCubic)),
    );
    _heroTextController.forward();
  }

  @override
  void dispose() {
    _heroTextController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _onRefresh() async {
    await Future.delayed(const Duration(seconds: 1));
  }

  @override
  Widget build(BuildContext context) {
    final spotCtrl = Provider.of<SpotController>(context);
    final approvedSpots = spotCtrl.approvedSpots;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        color: const Color(0xFF2D6A4F),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          slivers: [
            SliverToBoxAdapter(
              child: Container(
                padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 12),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF1B4332), Color(0xFF2D6A4F)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SlideTransition(
                      position: _heroTextSlide,
                      child: FadeTransition(
                        opacity: _heroTextOpacity,
                        child: const Text(
                          'Discover Local Spots',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      height: 50,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          )
                        ],
                      ),
                      child: Row(
                        children: [
                          const SizedBox(width: 16),
                          const Icon(Icons.search, color: Color(0xFF2D6A4F)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: _searchCtrl,
                              onChanged: (val) => spotCtrl.filter(query: val),
                              onTap: () => setState(() => _isSearchExpanded = true),
                              onEditingComplete: () => FocusScope.of(context).unfocus(),
                              decoration: InputDecoration(
                                hintText: 'Search kopitiam, cafes, spots...',
                                hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                                border: InputBorder.none,
                                isDense: true,
                              ),
                            ),
                          ),
                          if (_searchCtrl.text.isNotEmpty)
                            IconButton(
                              icon: const Icon(Icons.clear, color: Colors.grey, size: 20),
                              onPressed: () {
                                _searchCtrl.clear();
                                spotCtrl.filter(query: '');
                                FocusScope.of(context).unfocus();
                              },
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12),
                child: Column(
                  children: [
                      const SizedBox(height: 20),
                      SizedBox(
                        height: 40,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          itemCount: _categories.length,
                          itemBuilder: (context, index) {
                            final cat = _categories[index];
                            final isSelected = spotCtrl.selectedCategory == cat;
                            return Padding(
                              padding: const EdgeInsets.only(right: 10),
                              child: GestureDetector(
                                onTap: () => spotCtrl.filter(category: cat),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: isSelected ? const Color(0xFF2D6A4F) : Colors.white,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: isSelected ? const Color(0xFF2D6A4F) : Colors.grey.shade300,
                                    ),
                                    boxShadow: isSelected
                                        ? [BoxShadow(color: const Color(0xFF2D6A4F).withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))]
                                        : [],
                                  ),
                                  child: Center(
                                    child: Text(
                                      cat,
                                      style: TextStyle(
                                        color: isSelected ? Colors.white : Colors.black87,
                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Trending Spots',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    DropdownButton<String>(
                      value: spotCtrl.selectedState,
                      underline: const SizedBox(),
                      icon: const Icon(Icons.location_on, color: Color(0xFF2D6A4F), size: 18),
                      style: const TextStyle(color: Color(0xFF2D6A4F), fontWeight: FontWeight.bold, fontSize: 14),
                      items: _states.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                      onChanged: (val) {
                        if (val != null) spotCtrl.filter(state: val);
                      },
                    ),
                  ],
                ),
              ),
            ),
            spotCtrl.isLoading
                ? const SliverFillRemaining(
                    child: Center(child: CircularProgressIndicator(color: Color(0xFF2D6A4F))),
                  )
                : approvedSpots.isEmpty
                    ? SliverFillRemaining(
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.location_off, size: 64, color: Colors.grey.shade300),
                              const SizedBox(height: 16),
                              Text('No spots found.', style: TextStyle(fontSize: 16, color: Colors.grey.shade500)),
                            ],
                          ),
                        ),
                      )
                    : SliverPadding(
                        padding: const EdgeInsets.only(left: 16, right: 16, bottom: 110),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final spot = approvedSpots[index];
                              return TweenAnimationBuilder<double>(
                                duration: Duration(milliseconds: 400 + (index * 100).clamp(0, 600)),
                                tween: Tween(begin: 0.0, end: 1.0),
                                curve: Curves.easeOutQuint,
                                builder: (context, value, child) {
                                  return Transform.translate(
                                    offset: Offset(0, 50 * (1 - value)),
                                    child: Opacity(
                                      opacity: value,
                                      child: child,
                                    ),
                                  );
                                },
                                child: SpotCard(spot: spot),
                              );
                            },
                            childCount: approvedSpots.length,
                          ),
                        ),
                      ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF2D6A4F),
        elevation: 4,
        highlightElevation: 8,
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SubmitSpotScreen()),
          );
        },
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Submit Spot', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }
}

class SpotCard extends StatefulWidget {
  final dynamic spot;
  const SpotCard({super.key, required this.spot});

  @override
  State<SpotCard> createState() => _SpotCardState();
}

class _SpotCardState extends State<SpotCard> with SingleTickerProviderStateMixin {
  late AnimationController _scaleCtrl;

  @override
  void initState() {
    super.initState();
    _scaleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
      lowerBound: 0.0,
      upperBound: 0.03,
    );
  }

  @override
  void dispose() {
    _scaleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _scaleCtrl.forward(),
      onTapUp: (_) {
        _scaleCtrl.reverse();
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => SpotDetailScreen(spot: widget.spot)),
        );
      },
      onTapCancel: () => _scaleCtrl.reverse(),
      child: AnimatedBuilder(
        animation: _scaleCtrl,
        builder: (context, child) {
          return Transform.scale(
            scale: 1 - _scaleCtrl.value,
            child: child,
          );
        },
        child: Container(
          height: 220,
          margin: const EdgeInsets.only(bottom: 20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 15,
                offset: const Offset(0, 8),
              )
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Stack(
              children: [
                Positioned.fill(
                  child: Image.network(
                    widget.spot.imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: Colors.grey.shade300,
                      child: const Icon(Icons.image_not_supported, size: 50, color: Colors.grey),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.7),
                          Colors.black.withOpacity(0.9),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: const [0.4, 0.8, 1.0],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 16,
                  left: 16,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2D6A4F).withOpacity(0.8),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white.withOpacity(0.2)),
                        ),
                        child: Text(
                          widget.spot.category,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 16,
                  right: 16,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white.withOpacity(0.1)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.star_rounded, color: Color(0xFFFFD700), size: 16),
                            const SizedBox(width: 4),
                            Text(
                              widget.spot.rating.toStringAsFixed(1),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 16,
                  left: 16,
                  right: 16,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.spot.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.location_on, color: Color(0xFFB7E4C7), size: 16),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              '${widget.spot.city}, ${widget.spot.state}',
                              style: TextStyle(
                                color: Colors.grey.shade300,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              widget.spot.priceRange,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.access_time_filled, color: Colors.grey.shade400, size: 14),
                          const SizedBox(width: 6),
                          Text(
                            'Best time: ${widget.spot.bestTime}',
                            style: TextStyle(
                              color: Colors.grey.shade400,
                              fontSize: 12,
                            ),
                          ),
                        ],
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
  }
}
