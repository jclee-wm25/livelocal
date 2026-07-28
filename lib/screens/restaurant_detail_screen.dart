import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/restaurant_model.dart';
import '../controllers/localeats_controller.dart';
import '../controllers/auth_controller.dart';
import '../controllers/itinerary_controller.dart';
import '../controllers/review_controller.dart';

class RestaurantDetailScreen extends StatelessWidget {
  final RestaurantModel restaurant;

  const RestaurantDetailScreen({super.key, required this.restaurant});

  Future<void> _launchSocialMediaUrl(BuildContext context, String urlString) async {
    final Uri uri = Uri.parse(urlString);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Opening review link: $urlString')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final foodCtrl = Provider.of<LocalEatsController>(context);
    final authCtrl = Provider.of<AuthController>(context);
    final itineraryCtrl = Provider.of<ItineraryController>(context);
    final reviewCtrl = Provider.of<ReviewController>(context);

    final user = authCtrl.currentUser;
    final activeDiscounts = foodCtrl.getActiveDiscountsForRestaurant(restaurant.id);
    final isSaved = user != null && itineraryCtrl.isSaved(user.id, restaurantId: restaurant.id);
    final reviews = reviewCtrl.getReviewsForRestaurant(restaurant.id);

    return Scaffold(
      appBar: AppBar(
        title: Text(restaurant.name, style: const TextStyle(color: Color(0xFF2D6A4F), fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0.5,
        actions: [
          if (user != null)
            IconButton(
              icon: Icon(
                isSaved ? Icons.bookmark : Icons.bookmark_border,
                color: const Color(0xFF2D6A4F),
              ),
              onPressed: () async {
                await itineraryCtrl.toggleSave(user.id, restaurantId: restaurant.id);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(isSaved ? 'Removed from saved' : 'Saved to your food list!')),
                  );
                }
              },
            ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Image.network(
              restaurant.coverPhotoUrl,
              height: 220,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                height: 220,
                color: Colors.grey.shade200,
                child: const Icon(Icons.fastfood, size: 64, color: Colors.grey),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(restaurant.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Text('${restaurant.cuisineType} • ${restaurant.priceRange} • ${restaurant.city}, ${restaurant.state}'),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.person, size: 16, color: Color(0xFF2D6A4F)),
                      const SizedBox(width: 4),
                      Text('Reviewed by ${restaurant.influencerName}', style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // TikTok/Instagram Video Link Button (FR35)
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black87,
                      minimumSize: const Size(double.infinity, 48),
                    ),
                    icon: const Icon(Icons.play_circle_fill, color: Colors.white),
                    label: const Text('Watch Original Video Review (TikTok/Instagram)', style: TextStyle(color: Colors.white)),
                    onPressed: () => _launchSocialMediaUrl(context, restaurant.socialMediaUrl),
                  ),
                  const SizedBox(height: 20),
                  const Divider(),
                  const SizedBox(height: 10),
                  const Text('Reviewed Dishes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Text(restaurant.reviewedDishes, style: const TextStyle(fontSize: 14)),
                  const SizedBox(height: 20),
                  // Exclusive Discount Code Section (FR36, FR37, FR38)
                  const Text('Exclusive LiveLocal Discount Codes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  if (activeDiscounts.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text('No active discount code at this moment.', style: TextStyle(color: Colors.grey)),
                    )
                  else
                    Column(
                      children: activeDiscounts.map((disc) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade50,
                            border: Border.all(color: Colors.amber.shade400),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.local_offer, color: Colors.amber, size: 28),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      disc.code,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87),
                                    ),
                                    Text(disc.description, style: const TextStyle(fontSize: 12)),
                                    Text(
                                      'Expires: ${disc.expiryDate.day}/${disc.expiryDate.month}/${disc.expiryDate.year}',
                                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.copy, color: Color(0xFF2D6A4F)),
                                onPressed: () {
                                  Clipboard.setData(ClipboardData(text: disc.code));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Discount code ${disc.code} copied!')),
                                  );
                                },
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  const SizedBox(height: 24),
                  const Text('Customer Reviews', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  if (reviews.isEmpty)
                    const Text('No customer reviews yet.')
                  else
                    Column(
                      children: reviews.map((r) {
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            title: Text(r.userName, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text(r.comment),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.star, color: Colors.amber, size: 16),
                                Text(r.rating.toStringAsFixed(1)),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
