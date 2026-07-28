# LiveLocal Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the complete 3-tier Flutter application for LiveLocal based on `LiveLocal.md` and `202605 BMSE3004 Continous Assessment Description.md`, using Supabase for data management with automatic fallback seed data for offline/demo capabilities across all 6 functional modules.

**Architecture:** 3-tier architecture with Presentation (UI Widgets & Navigation), Business Logic (Provider Controllers & Repositories), and Data Storage Layer (Supabase Client SDK + Local Seed Data Service).

**Tech Stack:** Flutter 3, Dart, Supabase (`supabase_flutter`), Provider, URL Launcher, Flutter Rating Bar, Shared Preferences.

## Global Constraints

- Platform: Cross-platform Flutter (Android, iOS, Web, Linux/Desktop).
- Data Layer: Supabase (`supabase_flutter` 2.8+) + pre-loaded fallback seed store.
- Color Theme: Primary `#2D6A4F`, Secondary `#74C69D`, Surface `#FFFFFF`.
- Clean 3-tier Architecture separating UI, Business Processing, and Data Storage.

---

### Task 1: Project Setup & Package Configuration

**Files:**
- Modify: `pubspec.yaml`
- Modify: `lib/main.dart`

**Interfaces:**
- Consumes: Dependencies defined in `pubspec.yaml`
- Produces: Provider scope setup and initialized Supabase service wrapper.

- [ ] **Step 1: Update pubspec.yaml dependencies**

```yaml
name: live_local
publish_to: 'none'
version: 1.0.0+1
environment:
  sdk: '>=3.0.0 <4.0.0'
dependencies:
  flutter:
    sdk: flutter
  supabase_flutter: ^2.8.0
  provider: ^6.1.2
  shared_preferences: ^2.2.2
  url_launcher: ^6.2.5
  flutter_rating_bar: ^4.0.1
dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^3.0.0
flutter:
  uses-material-design: true
```

- [ ] **Step 2: Run flutter pub get to fetch packages**

Run: `flutter pub get`
Expected: Resolution of packages without errors.

- [ ] **Step 3: Commit**

```bash
git add pubspec.yaml pubspec.lock
git commit -m "chore: add supabase_flutter, provider, and UI packages to pubspec.yaml"
```

---

### Task 2: Data Models (Data Layer)

**Files:**
- Create: `lib/models/profile_model.dart`
- Create: `lib/models/spot_model.dart`
- Create: `lib/models/restaurant_model.dart`
- Create: `lib/models/discount_code_model.dart`
- Create: `lib/models/saved_place_model.dart`
- Create: `lib/models/guide_model.dart`
- Create: `lib/models/review_model.dart`
- Create: `lib/models/notification_model.dart`
- Test: `test/models_test.dart`

**Interfaces:**
- Consumes: None
- Produces: Strongly typed Dart data models with `toMap()` and `fromMap()` serializers.

- [ ] **Step 1: Write model classes with JSON serialization**

Create `lib/models/profile_model.dart`:
```dart
class ProfileModel {
  final String id;
  final String email;
  final String fullName;
  final String? avatarUrl;
  final String role; // 'tourist', 'influencer', 'admin'
  final bool isSuspended;

  ProfileModel({
    required this.id,
    required this.email,
    required this.fullName,
    this.avatarUrl,
    required this.role,
    this.isSuspended = false,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'email': email,
    'full_name': fullName,
    'avatar_url': avatarUrl,
    'role': role,
    'is_suspended': isSuspended,
  };

  factory ProfileModel.fromMap(Map<String, dynamic> map) => ProfileModel(
    id: map['id'] ?? '',
    email: map['email'] ?? '',
    fullName: map['full_name'] ?? '',
    avatarUrl: map['avatar_url'],
    role: map['role'] ?? 'tourist',
    isSuspended: map['is_suspended'] ?? false,
  );
}
```

Create `lib/models/spot_model.dart`:
```dart
class SpotModel {
  final String id;
  final String name;
  final String category;
  final String description;
  final String state;
  final String city;
  final String address;
  final String priceRange;
  final String bestTime;
  final String thingsToDo;
  final String imageUrl;
  final double rating;
  final int reviewCount;
  final String submittedBy;
  final String status; // 'pending', 'approved', 'rejected'
  final String? rejectionReason;

  SpotModel({
    required this.id,
    required this.name,
    required this.category,
    required this.description,
    required this.state,
    required this.city,
    required this.address,
    required this.priceRange,
    required this.bestTime,
    required this.thingsToDo,
    required this.imageUrl,
    this.rating = 0.0,
    this.reviewCount = 0,
    required this.submittedBy,
    this.status = 'pending',
    this.rejectionReason,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'category': category,
    'description': description,
    'state': state,
    'city': city,
    'address': address,
    'price_range': priceRange,
    'best_time': bestTime,
    'things_to_do': thingsToDo,
    'image_url': imageUrl,
    'rating': rating,
    'review_count': reviewCount,
    'submitted_by': submittedBy,
    'status': status,
    'rejection_reason': rejectionReason,
  };

  factory SpotModel.fromMap(Map<String, dynamic> map) => SpotModel(
    id: map['id'] ?? '',
    name: map['name'] ?? '',
    category: map['category'] ?? '',
    description: map['description'] ?? '',
    state: map['state'] ?? '',
    city: map['city'] ?? '',
    address: map['address'] ?? '',
    priceRange: map['price_range'] ?? '\$',
    bestTime: map['best_time'] ?? '',
    thingsToDo: map['things_to_do'] ?? '',
    imageUrl: map['image_url'] ?? '',
    rating: (map['rating'] as num?)?.toDouble() ?? 0.0,
    reviewCount: map['review_count'] ?? 0,
    submittedBy: map['submitted_by'] ?? '',
    status: map['status'] ?? 'pending',
    rejectionReason: map['rejection_reason'],
  );
}
```

Create `lib/models/restaurant_model.dart`:
```dart
class RestaurantModel {
  final String id;
  final String name;
  final String address;
  final String state;
  final String city;
  final String cuisineType;
  final String priceRange;
  final String reviewedDishes;
  final String influencerId;
  final String influencerName;
  final String socialMediaUrl;
  final String coverPhotoUrl;

  RestaurantModel({
    required this.id,
    required this.name,
    required this.address,
    required this.state,
    required this.city,
    required this.cuisineType,
    required this.priceRange,
    required this.reviewedDishes,
    required this.influencerId,
    required this.influencerName,
    required this.socialMediaUrl,
    required this.coverPhotoUrl,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'address': address,
    'state': state,
    'city': city,
    'cuisine_type': cuisineType,
    'price_range': priceRange,
    'reviewed_dishes': reviewedDishes,
    'influencer_id': influencerId,
    'influencer_name': influencerName,
    'social_media_url': socialMediaUrl,
    'cover_photo_url': coverPhotoUrl,
  };

  factory RestaurantModel.fromMap(Map<String, dynamic> map) => RestaurantModel(
    id: map['id'] ?? '',
    name: map['name'] ?? '',
    address: map['address'] ?? '',
    state: map['state'] ?? '',
    city: map['city'] ?? '',
    cuisineType: map['cuisine_type'] ?? '',
    priceRange: map['price_range'] ?? '\$',
    reviewedDishes: map['reviewed_dishes'] ?? '',
    influencerId: map['influencer_id'] ?? '',
    influencerName: map['influencer_name'] ?? '',
    socialMediaUrl: map['social_media_url'] ?? '',
    coverPhotoUrl: map['cover_photo_url'] ?? '',
  );
}
```

Create `lib/models/discount_code_model.dart`:
```dart
class DiscountCodeModel {
  final String id;
  final String restaurantId;
  final String code;
  final String description;
  final DateTime expiryDate;
  final String createdBy;

  DiscountCodeModel({
    required this.id,
    required this.restaurantId,
    required this.code,
    required this.description,
    required this.expiryDate,
    required this.createdBy,
  });

  bool get isExpired => DateTime.now().isAfter(expiryDate);

  Map<String, dynamic> toMap() => {
    'id': id,
    'restaurant_id': restaurantId,
    'code': code,
    'description': description,
    'expiry_date': expiryDate.toIso8601String(),
    'created_by': createdBy,
  };

  factory DiscountCodeModel.fromMap(Map<String, dynamic> map) => DiscountCodeModel(
    id: map['id'] ?? '',
    restaurantId: map['restaurant_id'] ?? '',
    code: map['code'] ?? '',
    description: map['description'] ?? '',
    expiryDate: DateTime.parse(map['expiry_date'] ?? DateTime.now().toIso8601String()),
    createdBy: map['created_by'] ?? '',
  );
}
```

Create `lib/models/saved_place_model.dart`:
```dart
class SavedPlaceModel {
  final String id;
  final String userId;
  final String? spotId;
  final String? restaurantId;
  final DateTime savedAt;

  SavedPlaceModel({
    required this.id,
    required this.userId,
    this.spotId,
    this.restaurantId,
    required this.savedAt,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'user_id': userId,
    'spot_id': spotId,
    'restaurant_id': restaurantId,
    'saved_at': savedAt.toIso8601String(),
  };

  factory SavedPlaceModel.fromMap(Map<String, dynamic> map) => SavedPlaceModel(
    id: map['id'] ?? '',
    userId: map['user_id'] ?? '',
    spotId: map['spot_id'],
    restaurantId: map['restaurant_id'],
    savedAt: DateTime.parse(map['saved_at'] ?? DateTime.now().toIso8601String()),
  );
}
```

Create `lib/models/guide_model.dart`:
```dart
class GuideModel {
  final String id;
  final String title;
  final String locationName;
  final String state;
  final String routeOverview;
  final List<String> stops;
  final List<String> walkingSequence;
  final String estimatedDuration;
  final String status; // 'pending', 'approved', 'rejected'
  final String? rejectionReason;

  GuideModel({
    required this.id,
    required this.title,
    required this.locationName,
    required this.state,
    required this.routeOverview,
    required this.stops,
    required this.walkingSequence,
    required this.estimatedDuration,
    this.status = 'approved',
    this.rejectionReason,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'location_name': locationName,
    'state': state,
    'route_overview': routeOverview,
    'stops': stops,
    'walking_sequence': walkingSequence,
    'estimated_duration': estimatedDuration,
    'status': status,
    'rejection_reason': rejectionReason,
  };

  factory GuideModel.fromMap(Map<String, dynamic> map) => GuideModel(
    id: map['id'] ?? '',
    title: map['title'] ?? '',
    locationName: map['location_name'] ?? '',
    state: map['state'] ?? '',
    routeOverview: map['route_overview'] ?? '',
    stops: List<String>.from(map['stops'] ?? []),
    walkingSequence: List<String>.from(map['walking_sequence'] ?? []),
    estimatedDuration: map['estimated_duration'] ?? '',
    status: map['status'] ?? 'approved',
    rejectionReason: map['rejection_reason'],
  );
}
```

Create `lib/models/review_model.dart`:
```dart
class ReviewModel {
  final String id;
  final String? spotId;
  final String? restaurantId;
  final String userId;
  final String userName;
  final double rating;
  final String comment;
  final String? photoUrl;
  final bool isFlagged;
  final String? flagReason;
  final DateTime createdAt;

  ReviewModel({
    required this.id,
    this.spotId,
    this.restaurantId,
    required this.userId,
    required this.userName,
    required this.rating,
    required this.comment,
    this.photoUrl,
    this.isFlagged = false,
    this.flagReason,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'spot_id': spotId,
    'restaurant_id': restaurantId,
    'user_id': userId,
    'user_name': userName,
    'rating': rating,
    'comment': comment,
    'photo_url': photoUrl,
    'is_flagged': isFlagged,
    'flag_reason': flagReason,
    'created_at': createdAt.toIso8601String(),
  };

  factory ReviewModel.fromMap(Map<String, dynamic> map) => ReviewModel(
    id: map['id'] ?? '',
    spotId: map['spot_id'],
    restaurantId: map['restaurant_id'],
    userId: map['user_id'] ?? '',
    userName: map['user_name'] ?? 'Anonymous',
    rating: (map['rating'] as num?)?.toDouble() ?? 0.0,
    comment: map['comment'] ?? '',
    photoUrl: map['photo_url'],
    isFlagged: map['is_flagged'] ?? false,
    flagReason: map['flag_reason'],
    createdAt: DateTime.parse(map['created_at'] ?? DateTime.now().toIso8601String()),
  );
}
```

Create `lib/models/notification_model.dart`:
```dart
class NotificationModel {
  final String id;
  final String userId;
  final String title;
  final String message;
  final String type;
  final bool isRead;
  final DateTime createdAt;

  NotificationModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.message,
    required this.type,
    this.isRead = false,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'user_id': userId,
    'title': title,
    'message': message,
    'type': type,
    'is_read': isRead,
    'created_at': createdAt.toIso8601String(),
  };

  factory NotificationModel.fromMap(Map<String, dynamic> map) => NotificationModel(
    id: map['id'] ?? '',
    userId: map['user_id'] ?? '',
    title: map['title'] ?? '',
    message: map['message'] ?? '',
    type: map['type'] ?? 'general',
    isRead: map['is_read'] ?? false,
    createdAt: DateTime.parse(map['created_at'] ?? DateTime.now().toIso8601String()),
  );
}
```

- [ ] **Step 2: Write tests for data models**

Create `test/models_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:live_local/models/spot_model.dart';

void main() {
  test('SpotModel map conversion', () {
    final spot = SpotModel(
      id: 'spot-1',
      name: 'Chop Seng Hin Kopitiam',
      category: 'Kopitiam',
      description: 'Historic coffee shop in Penang',
      state: 'Penang',
      city: 'George Town',
      address: '123 Carnarvon St',
      priceRange: '\$',
      bestTime: '7:00 AM - 11:00 AM',
      thingsToDo: 'Try Hainanese coffee and kaya toast',
      imageUrl: 'https://example.com/photo.jpg',
      submittedBy: 'user-1',
      status: 'approved',
    );

    final map = spot.toMap();
    expect(map['name'], 'Chop Seng Hin Kopitiam');
    expect(map['state'], 'Penang');

    final copy = SpotModel.fromMap(map);
    expect(copy.id, 'spot-1');
    expect(copy.name, spot.name);
  });
}
```

- [ ] **Step 3: Run unit tests**

Run: `flutter test test/models_test.dart`
Expected: PASS

- [ ] **Step 4: Commit**

```bash
git add lib/models/ test/models_test.dart
git commit -m "feat: implement data models for all 6 modules"
```

---

### Task 3: Supabase Service & Seed Data Datastore (Data Layer)

**Files:**
- Create: `lib/services/supabase_service.dart`
- Create: `lib/services/seed_data_service.dart`

**Interfaces:**
- Consumes: Models from Task 2
- Produces: Data persistence services providing both live Supabase client capabilities and complete offline fallback seed store.

- [ ] **Step 1: Implement SeedDataService with rich Malaysian data**

Create `lib/services/seed_data_service.dart`:
Contains realistic Malaysian local spots (Penang kopitiams, TTDI market, Ipoh white coffee, JB night market), influencer food video listings, discount codes, neighbourhood guides, and reviews.

- [ ] **Step 2: Implement SupabaseService wrapper**

Create `lib/services/supabase_service.dart`:
Wraps `SupabaseClient` with fallback to `SeedDataService` if live connection is unavailable.

- [ ] **Step 3: Commit**

```bash
git add lib/services/
git commit -m "feat: add Supabase service layer and offline seed datastore"
```

---

### Task 4: Business Logic Controllers (Provider Layer)

**Files:**
- Create: `lib/controllers/auth_controller.dart`
- Create: `lib/controllers/spot_controller.dart`
- Create: `lib/controllers/localeats_controller.dart`
- Create: `lib/controllers/itinerary_controller.dart`
- Create: `lib/controllers/guide_controller.dart`
- Create: `lib/controllers/review_controller.dart`
- Create: `lib/controllers/admin_controller.dart`

**Interfaces:**
- Consumes: `SupabaseService` and `SeedDataService`
- Produces: `ChangeNotifier` controllers managing state for each module (Auth, Spots, Food, Itinerary, Guides, Reviews, Admin).

- [ ] **Step 1: Write AuthController & SpotController**
- [ ] **Step 2: Write LocalEatsController & ItineraryController**
- [ ] **Step 3: Write GuideController, ReviewController, & AdminController**
- [ ] **Step 4: Commit**

```bash
git add lib/controllers/
git commit -m "feat: implement business logic layer controllers for all 6 modules"
```

---

### Task 5: Main App & Navigation Structure (GUI Layer)

**Files:**
- Modify: `lib/main.dart`
- Modify: `lib/welcome_screen.dart`
- Modify: `lib/screens/login_screen.dart`
- Modify: `lib/screens/register_screen.dart`
- Create: `lib/screens/main_navigation_screen.dart`

**Interfaces:**
- Consumes: Controllers from Task 4
- Produces: Root application widget with `MultiProvider` and main bottom navigation bar.

- [ ] **Step 1: Wire MultiProvider into main.dart**
- [ ] **Step 2: Create MainNavigationScreen with bottom tabs and top quick role switcher (Tourist/Influencer/Admin)**
- [ ] **Step 3: Commit**

```bash
git add lib/main.dart lib/welcome_screen.dart lib/screens/
git commit -m "feat: setup main navigation screen and multi-provider root"
```

---

### Task 6: Module 1 & Profile Screens (GUI Layer)

**Files:**
- Modify: `lib/screens/login_screen.dart`
- Modify: `lib/screens/register_screen.dart`
- Create: `lib/screens/profile_screen.dart`

**Interfaces:**
- Consumes: `AuthController`
- Produces: Complete auth and user profile management UI.

- [ ] **Step 1: Connect LoginScreen & RegisterScreen to AuthController**
- [ ] **Step 2: Build ProfileScreen with role switcher, profile details edit, photo upload simulation, and delete account**
- [ ] **Step 3: Commit**

```bash
git add lib/screens/
git commit -m "feat: complete Module 1 account management UI"
```

---

### Task 7: Module 2 — Local Spots Discovery UI (GUI Layer)

**Files:**
- Create: `lib/screens/spots_discovery_screen.dart`
- Create: `lib/screens/spot_detail_screen.dart`
- Create: `lib/screens/submit_spot_screen.dart`

**Interfaces:**
- Consumes: `SpotController`
- Produces: Interactive spot discovery grid/list, state/category filter bottom sheet, detail view, and spot submission form.

- [ ] **Step 1: Build SpotsDiscoveryScreen with real-time search & filters**
- [ ] **Step 2: Build SpotDetailScreen showing best time, activities, ratings, and save button**
- [ ] **Step 3: Build SubmitSpotScreen with photo upload simulation**
- [ ] **Step 4: Commit**

```bash
git add lib/screens/
git commit -m "feat: implement Module 2 Local Spots Discovery screens"
```

---

### Task 8: Module 3 — LocalEats & Influencer Hub UI (GUI Layer)

**Files:**
- Create: `lib/screens/localeats_screen.dart`
- Create: `lib/screens/restaurant_detail_screen.dart`
- Create: `lib/screens/add_restaurant_screen.dart`

**Interfaces:**
- Consumes: `LocalEatsController`
- Produces: LocalEats restaurant feed, trending carousel, discount codes section, TikTok/Instagram URL launcher button, and influencer listing creator.

- [ ] **Step 1: Build LocalEatsScreen with state/cuisine/budget filters and Trending section**
- [ ] **Step 2: Build RestaurantDetailScreen with influencer social media launcher & active copyable discount code card**
- [ ] **Step 3: Build AddRestaurantScreen for Influencer role**
- [ ] **Step 4: Commit**

```bash
git add lib/screens/
git commit -m "feat: implement Module 3 LocalEats & Influencer discount hub screens"
```

---

### Task 9: Module 4 & Module 5 — Saved Places, Itinerary & Explorer UI (GUI Layer)

**Files:**
- Create: `lib/screens/saved_places_screen.dart`
- Create: `lib/screens/itinerary_screen.dart`
- Create: `lib/screens/neighbourhood_explorer_screen.dart`
- Create: `lib/screens/guide_detail_screen.dart`

**Interfaces:**
- Consumes: `ItineraryController` & `GuideController`
- Produces: Saved items manager, proximity route auto-itinerary planner, and neighbourhood day guide reader.

- [ ] **Step 1: Build SavedPlacesScreen & ItineraryScreen with proximity routing**
- [ ] **Step 2: Build NeighbourhoodExplorerScreen & GuideDetailScreen**
- [ ] **Step 3: Commit**

```bash
git add lib/screens/
git commit -m "feat: implement Module 4 Saved Places/Itinerary and Module 5 Explorer screens"
```

---

### Task 10: Module 6 — Community Reviews, Admin Dashboard & Notifications UI (GUI Layer)

**Files:**
- Create: `lib/screens/admin_dashboard_screen.dart`
- Create: `lib/screens/notifications_screen.dart`

**Interfaces:**
- Consumes: `ReviewController`, `AdminController`, `NotificationModel`
- Produces: Star rating & photo review component, report review modal, admin statistics dashboard, pending spot/guide moderation list, user suspension toggle, and notifications view.

- [ ] **Step 1: Build Community review list, star rating widget, photo upload, upvote, and report modal**
- [ ] **Step 2: Build AdminDashboardScreen with platform stats, moderation queue (spot/guide approvals with mandatory rejection reasons, reported review removal), and user suspension toggle**
- [ ] **Step 3: Build NotificationsScreen with history**
- [ ] **Step 4: Commit**

```bash
git add lib/screens/
git commit -m "feat: implement Module 6 Community Review, Admin Dashboard & Notifications"
```

---

### Task 11: System Verification & Final Testing

**Files:**
- Create: `test/system_integration_test.dart`

**Interfaces:**
- Consumes: Full application codebase
- Produces: Complete test suite verifying all 6 modules and clean 3-tier architecture execution.

- [ ] **Step 1: Write integration tests verifying 6 modules and role permissions**
- [ ] **Step 2: Run flutter test to verify full test suite**

Run: `flutter test`
Expected: ALL TESTS PASSing.

- [ ] **Step 3: Commit**

```bash
git add test/
git commit -m "test: add system integration tests for all 6 modules"
```
