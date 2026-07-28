# LiveLocal — System Design & Technical Specification

## Project Overview
- **Project Name**: LiveLocal
- **Course**: BMSE3004 Collaborative Development / BMSE2073 Software Design & Architecture
- **Theme**: Visit Malaysia 2026 (VM2026) & UN Sustainable Development Goal 8 (Decent Work & Economic Growth)
- **Tech Stack**: Flutter (Dart) + Supabase (`supabase_flutter`) + Provider State Management

---

## 1. System Architecture (3-Tier Model)

The application adheres strictly to the 3-Tier Architecture constraint required by the course specification:

```
+-------------------------------------------------------------------+
|                        1. GUI LAYER (UI)                          |
|  - WelcomeScreen, LoginScreen, RegisterScreen                     |
|  - DiscoverSpotsScreen, SpotDetailScreen, SubmitSpotScreen       |
|  - LocalEatsScreen, RestaurantDetailScreen, AddListingScreen     |
|  - SavedPlacesScreen, SmartItineraryScreen                        |
|  - NeighbourhoodExplorerScreen, GuideDetailScreen                 |
|  - CommunityReviewsWidget, AdminDashboardScreen                   |
+-------------------------------------------------------------------+
                                 |
                                 v
+-------------------------------------------------------------------+
|               2. BUSINESS PROCESSING LAYER (Logic)                |
|  - AuthController: Registration, Login, Profile, Role Switcher    |
|  - SpotController: Spots CRUD, Filter Logic, Approval Workflows   |
|  - LocalEatsController: Restaurants, Influencer Links, Discounts  |
|  - ItineraryController: Saving, Proximity Grouping, Day Routing   |
|  - GuideController: Neighbourhood Walking Guides & Approvals     |
|  - ReviewController: Ratings, Reviews, Flagging & Moderation      |
|  - AdminController: Stats Dashboard, Account & Review Moderation  |
+-------------------------------------------------------------------+
                                 |
                                 v
+-------------------------------------------------------------------+
|                   3. DATA PROCESSING LAYER                        |
|  - SupabaseService: Supabase Client & PostgreSQL Data Operations  |
|  - Repositories: AuthRepository, SpotRepository, FoodRepository,  |
|                  GuideRepository, ReviewRepository                |
|  - SeedDataService: Authentic Malaysian Pre-seeded Fallback Data   |
+-------------------------------------------------------------------+
```

---

## 2. Database Schema (Supabase PostgreSQL Tables)

### `profiles`
- `id` (uuid, primary key)
- `email` (text, required)
- `full_name` (text, required)
- `avatar_url` (text, optional)
- `role` (text: `'tourist'`, `'influencer'`, `'admin'`)
- `is_suspended` (boolean, default false)
- `created_at` (timestamp with time zone)

### `spots`
- `id` (uuid, primary key)
- `name` (text, required)
- `category` (text: `'kopitiam'`, `'pasar_malam'`, `'indie_cafe'`, `'park'`, `'street_food'`)
- `description` (text)
- `state` (text, required)
- `city` (text, required)
- `address` (text)
- `price_range` (text: `'$'`, `'$$'`, `'$$$'`)
- `best_time` (text)
- `things_to_do` (text)
- `image_url` (text)
- `rating` (double precision, default 0.0)
- `review_count` (integer, default 0)
- `submitted_by` (uuid, references `profiles.id`)
- `status` (text: `'pending'`, `'approved'`, `'rejected'`)
- `rejection_reason` (text, optional)
- `created_at` (timestamp with time zone)

### `restaurants` (LocalEats)
- `id` (uuid, primary key)
- `name` (text, required)
- `address` (text)
- `state` (text)
- `city` (text)
- `cuisine_type` (text)
- `price_range` (text)
- `reviewed_dishes` (text)
- `influencer_id` (uuid, references `profiles.id`)
- `influencer_name` (text)
- `social_media_url` (text)
- `cover_photo_url` (text)
- `created_at` (timestamp with time zone)

### `discount_codes`
- `id` (uuid, primary key)
- `restaurant_id` (uuid, references `restaurants.id`)
- `code` (text, required)
- `description` (text)
- `expiry_date` (timestamp with time zone)
- `created_by` (uuid, references `profiles.id`)
- `created_at` (timestamp with time zone)

### `saved_places`
- `id` (uuid, primary key)
- `user_id` (uuid, references `profiles.id`)
- `spot_id` (uuid, references `spots.id`, nullable)
- `restaurant_id` (uuid, references `restaurants.id`, nullable)
- `saved_at` (timestamp with time zone)

### `neighbourhood_guides`
- `id` (uuid, primary key)
- `title` (text)
- `location_name` (text)
- `state` (text)
- `route_overview` (text)
- `stops` (jsonb array)
- `walking_sequence` (jsonb array)
- `estimated_duration` (text)
- `status` (text: `'pending'`, `'approved'`, `'rejected'`)
- `rejection_reason` (text, optional)
- `created_at` (timestamp with time zone)

### `reviews`
- `id` (uuid, primary key)
- `spot_id` (uuid, references `spots.id`, nullable)
- `restaurant_id` (uuid, references `restaurants.id`, nullable)
- `user_id` (uuid, references `profiles.id`)
- `user_name` (text)
- `rating` (double precision)
- `comment` (text)
- `photo_url` (text, optional)
- `is_flagged` (boolean, default false)
- `flag_reason` (text, optional)
- `created_at` (timestamp with time zone)

### `notifications`
- `id` (uuid, primary key)
- `user_id` (uuid, references `profiles.id`)
- `title` (text)
- `message` (text)
- `type` (text: `'spot_approved'`, `'trending_food'`, `'discount_alert'`, `'review_report'`)
- `is_read` (boolean, default false)
- `created_at` (timestamp with time zone)

---

## 3. Detailed Functional Modules & FR Traceability

| Module | Requirements Covered | Description |
| :--- | :--- | :--- |
| **Module 1: User & Admin Auth** | FR01 - FR12 | Registration, Login, Profile View/Edit/Photo, Account Deletion, Role Management (Tourist, Influencer, Admin), Admin User Account Suspension, Influencer Application Approval. |
| **Module 2: Local Spots Discovery** | FR13 - FR23 | Display authentic local spots, Multi-attribute Filtering (State, City, Category, Price Range), Spot Card & Detail view, Community Spot Submission with photo, Admin Approval/Rejection with mandatory reason. |
| **Module 3: LocalEats & Influencer Hub** | FR24 - FR38 | Influencer Restaurant Reviews, Filtering (State, Cuisine, Budget), Trending Restaurants list, TikTok/Instagram external link launcher, Influencer Listing & Discount Code creation, Active Discount rendering with copy-to-clipboard and expired code auto-hiding. |
| **Module 4: Saved Places & Smart Itinerary** | FR39 - FR44 | Bookmark spots & eateries, Consolidated saved list, Proximity-based grouping algorithm, Auto-generated Day Travel Itinerary. |
| **Module 5: Neighbourhood Explorer** | FR45 - FR49 | Curated neighbourhood walking day guides, Categorised by location, Displays route overview, walking sequence, duration, insider tips, Admin Approval/Rejection with reason. |
| **Module 6: Reviews, Moderation & Alerts** | FR50 - FR64 | 1-5 Star Ratings, Photo Upload, Upvoting, Flag/Report inappropriate reviews, Admin moderation queue & deletion, Admin Platform Statistics Dashboard, Real-time In-App Notifications & history. |

---

## 4. UI/UX Design System & Theme
- **Primary Color**: `#2D6A4F` (Malaysian Nature & Kopitiam Green)
- **Secondary Color**: `#74C69D` (Fresh Mint Accent)
- **Surface & Background**: Clean white (`#FFFFFF`) and light warm grey (`#F8F9FA`)
- **Typography**: Clean hierarchy with Material 3 standard sans-serif text styles.

---

## 5. Execution & Demo Strategy
- Integrated `SupabaseService` connects to Supabase database.
- Features `SeedDataService` providing full offline/mock data fallback so the application runs completely out-of-the-box (`flutter run`) without external configuration blockers.
