import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/spot_model.dart';
import '../controllers/auth_controller.dart';
import '../controllers/itinerary_controller.dart';
import '../controllers/review_controller.dart';

class SpotDetailScreen extends StatefulWidget {
  final SpotModel spot;

  const SpotDetailScreen({super.key, required this.spot});

  @override
  State<SpotDetailScreen> createState() => _SpotDetailScreenState();
}

class _SpotDetailScreenState extends State<SpotDetailScreen> {
  final _commentCtrl = TextEditingController();
  double _userRating = 5.0;

  @override
  Widget build(BuildContext context) {
    final authCtrl = Provider.of<AuthController>(context);
    final itineraryCtrl = Provider.of<ItineraryController>(context);
    final reviewCtrl = Provider.of<ReviewController>(context);

    final user = authCtrl.currentUser;
    final isSaved = user != null && itineraryCtrl.isSaved(user.id, spotId: widget.spot.id);
    final spotReviews = reviewCtrl.getReviewsForSpot(widget.spot.id);

    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            expandedHeight: 260,
            pinned: true,
            backgroundColor: const Color(0xFF1B4332),
            leading: Padding(
              padding: const EdgeInsets.all(8.0),
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)],
                  ),
                  child: const Icon(Icons.arrow_back, color: Color(0xFF1B4332), size: 20),
                ),
              ),
            ),
            actions: [
              if (user != null)
                Padding(
                  padding: const EdgeInsets.only(right: 16.0),
                  child: GestureDetector(
                    onTap: () async {
                      await itineraryCtrl.toggleSave(user.id, spotId: widget.spot.id);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(isSaved ? 'Removed from saved places' : 'Saved to your places!'),
                            backgroundColor: const Color(0xFF2D6A4F),
                          ),
                        );
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)],
                      ),
                      child: Icon(
                        isSaved ? Icons.bookmark : Icons.bookmark_border,
                        color: const Color(0xFF1B4332),
                        size: 20,
                      ),
                    ),
                  ),
                ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Image.network(
                widget.spot.imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: Colors.grey.shade200,
                  child: const Icon(Icons.image, size: 64, color: Colors.grey),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Transform.translate(
              offset: const Offset(0, -24),
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 10,
                      offset: Offset(0, -4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2D6A4F).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            widget.spot.category,
                            style: const TextStyle(color: Color(0xFF2D6A4F), fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ),
                        const Spacer(),
                        const Icon(Icons.star, color: Colors.amber, size: 18),
                        const SizedBox(width: 4),
                        Text(
                          reviewCtrl.getAverageRating(widget.spot.id, null).toStringAsFixed(1),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      widget.spot.name,
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1B4332)),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.location_on, size: 18, color: Color(0xFF2D6A4F)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            widget.spot.address,
                            style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 12),
                    const Text('About this Local Spot', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(
                    widget.spot.description,
                    style: TextStyle(color: Colors.grey.shade800, height: 1.5, fontSize: 14),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF74C69D).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF74C69D)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.access_time, color: Color(0xFF2D6A4F), size: 18),
                            const SizedBox(width: 8),
                            const Text('Best Visiting Time: ', style: TextStyle(fontWeight: FontWeight.bold)),
                            Text(widget.spot.bestTime),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.check_circle_outline, color: Color(0xFF2D6A4F), size: 18),
                            const SizedBox(width: 8),
                            const Text('Things to do / Order: ', style: TextStyle(fontWeight: FontWeight.bold)),
                            Expanded(child: Text(widget.spot.thingsToDo)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Community Reviews', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      if (user != null)
                        OutlinedButton.icon(
                          onPressed: () => _showWriteReviewSheet(context, user, reviewCtrl),
                          icon: const Icon(Icons.rate_review_outlined, size: 16),
                          label: const Text('Write Review'),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(120, 36),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Reviews List
                  if (spotReviews.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Text('No reviews yet. Be the first local visitor to share your review!'),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: spotReviews.length,
                      itemBuilder: (context, idx) {
                        final r = spotReviews[idx];
                        return Card(
                          elevation: 0,
                          color: const Color(0xFFF8F9FA),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: Colors.grey.shade200),
                          ),
                          margin: const EdgeInsets.only(bottom: 10),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const CircleAvatar(
                                      radius: 14,
                                      backgroundColor: Color(0xFF2D6A4F),
                                      child: Icon(Icons.person, size: 16, color: Colors.white),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(r.userName, style: const TextStyle(fontWeight: FontWeight.bold)),
                                    const Spacer(),
                                    Row(
                                      children: List.generate(
                                        5,
                                        (i) => Icon(
                                          i < r.rating ? Icons.star : Icons.star_border,
                                          color: Colors.amber,
                                          size: 14,
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                                      icon: const Icon(Icons.flag_outlined, size: 16, color: Colors.grey),
                                      onPressed: () {
                                        _showFlagReviewDialog(context, r.id, reviewCtrl);
                                      },
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(r.comment, style: const TextStyle(fontSize: 13, height: 1.4)),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ],
    ),
  );
  }

  void _showWriteReviewSheet(BuildContext context, dynamic user, ReviewController reviewCtrl) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                left: 20,
                right: 20,
                top: 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Write a Review', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Text('Your Rating: ', style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(width: 12),
                      Row(
                        children: List.generate(5, (index) {
                          final ratingVal = index + 1.0;
                          return IconButton(
                            onPressed: () {
                              setModalState(() {
                                _userRating = ratingVal;
                              });
                            },
                            icon: Icon(
                              index < _userRating ? Icons.star : Icons.star_border,
                              color: Colors.amber,
                              size: 28,
                            ),
                          );
                        }),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _commentCtrl,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: 'Share your experience at this spot...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2D6A4F)),
                      onPressed: () async {
                        if (_commentCtrl.text.trim().isEmpty) return;
                        await reviewCtrl.addReview(
                          spotId: widget.spot.id,
                          userId: user.id,
                          userName: user.fullName,
                          rating: _userRating,
                          comment: _commentCtrl.text.trim(),
                        );
                        _commentCtrl.clear();
                        if (context.mounted) {
                          Navigator.pop(ctx);
                          setState(() {});
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Review submitted! Thank you.')),
                          );
                        }
                      },
                      child: const Text('Submit Review', style: TextStyle(color: Colors.white, fontSize: 16)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showFlagReviewDialog(BuildContext context, String reviewId, ReviewController reviewCtrl) {
    final reasonCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Report Inappropriate Review'),
        content: TextField(
          controller: reasonCtrl,
          decoration: const InputDecoration(hintText: 'Enter reason for reporting...'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              if (reasonCtrl.text.trim().isNotEmpty) {
                await reviewCtrl.flagReview(reviewId, reasonCtrl.text.trim());
                if (context.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Review flagged for admin moderation.')),
                  );
                }
              }
            },
            child: const Text('Report', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
