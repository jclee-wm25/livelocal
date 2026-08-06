import '../models/profile_model.dart';
import '../models/spot_model.dart';
import '../models/restaurant_model.dart';
import '../models/discount_code_model.dart';
import '../models/guide_model.dart';
import '../models/review_model.dart';
import '../models/notification_model.dart';

class SeedDataService {
  /// Shared synthetic password for non-release demo fixtures only.
  ///
  /// Demo authentication is intentionally not a production security model.
  static const demoPassword = '123456';

  static List<ProfileModel> getInitialProfiles() => [
        ProfileModel(
          id: 'usr-tourist-1',
          email: 'tourist@livelocal.com',
          fullName: 'Alex Tan (Tourist)',
          avatarUrl:
              'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=150',
          role: 'tourist',
        ),
        ProfileModel(
          id: 'usr-influencer-1',
          email: 'foodie@livelocal.com',
          fullName: 'KL Foodie (Influencer)',
          avatarUrl:
              'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=150',
          role: 'influencer',
        ),
        ProfileModel(
          id: 'usr-admin-1',
          email: 'admin@livelocal.com',
          fullName: 'Admin User',
          avatarUrl:
              'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=150',
          role: 'admin',
        ),
      ];

  static List<SpotModel> getInitialSpots() => [
        SpotModel(
          id: 'spot-001',
          name: 'Chop Seng Hin Kopitiam',
          category: 'Kopitiam',
          description:
              'Authentic 70-year-old Hainanese kopitiam known only to locals in George Town. Famous for traditional charcoal-grilled kaya toast and thick kopi O.',
          state: 'Penang',
          city: 'George Town',
          address: '142 Lebuh Carnarvon, 10100 George Town, Pulau Pinang',
          priceRange: r'$',
          bestTime: '7:00 AM - 11:30 AM',
          thingsToDo: 'Order Kopi O Kau, Half-boiled Eggs & Charcoal Toast',
          imageUrl:
              'https://images.unsplash.com/photo-1554118811-1e0d58224f24?w=600',
          rating: 4.8,
          reviewCount: 42,
          submittedBy: 'usr-tourist-1',
          status: 'approved',
          latitude: 5.4147,
          longitude: 100.3334,
        ),
        SpotModel(
          id: 'spot-002',
          name: 'TTDI Sunday Pasar Malam',
          category: 'Pasar Malam',
          description:
              'Vibrant local night market frequented by neighborhood residents for authentic Apam Balik, Ramly burgers, and fresh local fruit juices.',
          state: 'Kuala Lumpur',
          city: 'Taman Tun Dr Ismail',
          address: 'Jalan Lorong Abang Haji Openg, TTDI, 60000 Kuala Lumpur',
          priceRange: r'$',
          bestTime: '5:00 PM - 9:30 PM',
          thingsToDo: 'Try Crispy Apam Balik and Coconut Shake',
          imageUrl:
              'https://images.unsplash.com/photo-1555396273-367ea4eb4db5?w=600',
          rating: 4.6,
          reviewCount: 29,
          submittedBy: 'usr-tourist-1',
          status: 'approved',
          latitude: 3.1422,
          longitude: 101.6307,
        ),
        SpotModel(
          id: 'spot-003',
          name: 'Ipoh Old Town White Coffee Nook',
          category: 'Indie Cafe',
          description:
              'Tucked away in a quiet alley, this heritage cafe brews authentic Ipoh White Coffee using traditional wood-roasted coffee beans.',
          state: 'Perak',
          city: 'Ipoh',
          address: '28 Jalan Sultan Yussuf, 30000 Ipoh, Perak',
          priceRange: r'$$',
          bestTime: '8:00 AM - 2:00 PM',
          thingsToDo: 'Sample Iced White Coffee and Kai Si Hor Fun',
          imageUrl:
              'https://images.unsplash.com/photo-1501339847302-ac426a4a7cbb?w=600',
          rating: 4.7,
          reviewCount: 35,
          submittedBy: 'usr-influencer-1',
          status: 'approved',
          latitude: 4.5967,
          longitude: 101.0777,
        ),
        SpotModel(
          id: 'spot-004',
          name: 'Jalan Dhoby Heritage Lane',
          category: 'Park / Walkway',
          description:
              'Historical street filled with local bakeries, independent coffee roastaries, and traditional laundry shops preserved since the 1930s.',
          state: 'Johor',
          city: 'Johor Bahru',
          address: 'Jalan Dhoby, 80000 Johor Bahru, Johor',
          priceRange: r'$$',
          bestTime: '9:00 AM - 5:00 PM',
          thingsToDo: 'Visit Hiap Joo Bakery for fresh Banana Cake',
          imageUrl:
              'https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?w=600',
          rating: 4.5,
          reviewCount: 18,
          submittedBy: 'usr-tourist-1',
          status: 'approved',
          latitude: 1.4563,
          longitude: 103.7633,
        ),
      ];

  static List<RestaurantModel> getInitialRestaurants() => [
        RestaurantModel(
          id: 'rest-001',
          name: 'Ah Hock Hawker Fried Kuey Teow',
          address: '34 Jalan Burmah, George Town, Penang',
          state: 'Penang',
          city: 'George Town',
          cuisineType: 'Hawker Street Food',
          priceRange: r'$',
          reviewedDishes: 'Duck Egg Char Kuey Teow, Fried Oyster Omelette',
          influencerId: 'usr-influencer-1',
          influencerName: 'KL Foodie',
          socialMediaUrl: 'https://www.tiktok.com/@klfoodie/video/123456789',
          coverPhotoUrl:
              'https://images.unsplash.com/photo-1569718212165-3a8278d5f624?w=600',
          latitude: 5.4194,
          longitude: 100.3265,
        ),
        RestaurantModel(
          id: 'rest-002',
          name: 'Restoran Nasi Kandar Line Clear (Local Secret Branch)',
          address: '17 Jalan Penang, George Town, Penang',
          state: 'Penang',
          city: 'George Town',
          cuisineType: 'Nasi Kandar',
          priceRange: r'$$',
          reviewedDishes: 'Ayam Goreng Spiced, Sotong Besar, Kuah Campur',
          influencerId: 'usr-influencer-1',
          influencerName: 'Penang Eats',
          socialMediaUrl: 'https://www.instagram.com/p/C123456789/',
          coverPhotoUrl:
              'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?w=600',
          latitude: 5.4177,
          longitude: 100.3310,
        ),
        RestaurantModel(
          id: 'rest-003',
          name: 'Kopitiam Sin Yoon Loong',
          address: '155 Jalan Dato Bandar Sugumaran, Ipoh, Perak',
          state: 'Perak',
          city: 'Ipoh',
          cuisineType: 'Traditional Malaysian Kopitiam',
          priceRange: r'$',
          reviewedDishes: 'Ipoh White Coffee, Chee Cheong Fun with Chili Paste',
          influencerId: 'usr-influencer-1',
          influencerName: 'Foodie Explorer MY',
          socialMediaUrl:
              'https://www.tiktok.com/@foodieexplorer/video/987654321',
          coverPhotoUrl:
              'https://images.unsplash.com/photo-1559925393-8be0ec4767c8?w=600',
          latitude: 4.5972,
          longitude: 101.0755,
        ),
      ];

  static List<DiscountCodeModel> getInitialDiscountCodes() => [
        DiscountCodeModel(
          id: 'disc-001',
          restaurantId: 'rest-001',
          code: 'LIVELOCAL10',
          description:
              'Get 10% OFF any Char Kuey Teow order when showing LiveLocal App',
          expiryDate: DateTime.now().add(const Duration(days: 60)),
          createdBy: 'usr-influencer-1',
        ),
        DiscountCodeModel(
          id: 'disc-002',
          restaurantId: 'rest-002',
          code: 'KLFOODIESPECIAL',
          description:
              'Free Sirap Bandung drink with any Nasi Kandar set purchase',
          expiryDate: DateTime.now().add(const Duration(days: 30)),
          createdBy: 'usr-influencer-1',
        ),
      ];

  static List<GuideModel> getInitialGuides() => [
        GuideModel(
          id: 'guide-001',
          title: 'Sunday Morning TTDI Local Neighborhood Trail',
          locationName: 'Taman Tun Dr Ismail',
          state: 'Kuala Lumpur',
          routeOverview:
              'Experience how KL locals spend a relaxing Sunday morning — from wet market rojak to quiet neighborhood park walks and indie artisanal coffee.',
          stops: [
            'TTDI Market Rojak Stall',
            'Lembah Kiara Recreation Park',
            'Kopitiam Kok Yuen',
            'Artisan Coffee Roasters TTDI'
          ],
          walkingSequence: [
            '1. Start at TTDI Market at 8:00 AM for fresh breakfast',
            '2. Walk 5 mins to Lembah Kiara Park for a refreshing shaded stroll',
            '3. Head to Kopitiam Kok Yuen at 10:30 AM for local coffee & toast',
            '4. Wrap up at Artisan Coffee Roasters for neighborhood vibe'
          ],
          estimatedDuration: '3.5 Hours',
          status: 'approved',
        ),
        GuideModel(
          id: 'guide-002',
          title: 'Ipoh Old Town Heritage & Coffee Crawl',
          locationName: 'Ipoh Old Town',
          state: 'Perak',
          routeOverview:
              'Walk through historic pre-war shoplots, mural alleys, and iconic white coffee spots favored by Ipoh residents.',
          stops: [
            'Concubine Lane Heritage Walk',
            'Sin Yoon Loong Kopitiam',
            'Ipoh Railway Station Gardens',
            'Nam Heong White Coffee'
          ],
          walkingSequence: [
            '1. Start at Concubine Lane at 9:00 AM before crowd arrives',
            '2. Enjoy authentic White Coffee at Sin Yoon Loong',
            '3. Walk through mural alleys toward Railway Gardens',
            '4. Enjoy famous Egg Tarts at Nam Heong'
          ],
          estimatedDuration: '4 Hours',
          status: 'approved',
        ),
      ];

  static List<ReviewModel> getInitialReviews() => [
        ReviewModel(
          id: 'rev-001',
          spotId: 'spot-001',
          userId: 'usr-tourist-1',
          userName: 'Alex Tan',
          rating: 5.0,
          comment:
              'Super authentic Hainanese coffee! The toast was perfectly crispy and charcoal grilled. A true hidden gem.',
          createdAt: DateTime.now().subtract(const Duration(days: 2)),
        ),
        ReviewModel(
          id: 'rev-002',
          restaurantId: 'rest-001',
          userId: 'usr-tourist-1',
          userName: 'Alex Tan',
          rating: 4.5,
          comment:
              'Used the LIVELOCAL10 discount code here and got 10% off! The duck egg char kuey teow had amazing wok hei.',
          createdAt: DateTime.now().subtract(const Duration(days: 1)),
        ),
      ];

  static List<NotificationModel> getInitialNotifications() => [
        NotificationModel(
          id: 'notif-001',
          userId: 'usr-tourist-1',
          title: 'New Local Spot Approved!',
          message: 'Chop Seng Hin Kopitiam in Penang is now live on LiveLocal.',
          type: 'spot_approved',
          createdAt: DateTime.now().subtract(const Duration(hours: 3)),
        ),
        NotificationModel(
          id: 'notif-002',
          userId: 'usr-tourist-1',
          title: 'Exclusive Discount Code Alert',
          message:
              'KL Foodie added a 10% discount code for Ah Hock Hawker CKT in Penang!',
          type: 'discount_alert',
          createdAt: DateTime.now().subtract(const Duration(hours: 1)),
        ),
      ];
}