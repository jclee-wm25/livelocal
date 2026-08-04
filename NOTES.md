# Audit Notes - LiveLocal

## 1. Discrepancy between Spec and Codebase (Supabase vs Firebase)
- **Spec states**: "built with Flutter and Firebase". "Firebase calls (Firestore, Storage, Auth) MUST be isolated in the Repository layer".
- **Codebase reality**: The `pubspec.yaml` imports `supabase_flutter`. All DB calls are made to Supabase in `supabase_service.dart`. There is no Firebase at all.
- **Assumption made**: I will treat Supabase as the database for the audit, but strongly flag this to the user because if they strictly need Firebase, the entire `supabase_service.dart` must be rewritten as a Firebase repository.

## 2. Security Vulnerability: Authentication is Faked
- The `AuthController` does not actually use Supabase Auth. It simply queries the `profiles` table for a matching email and logs the user in if found, entirely ignoring the password field (`if (password.isEmpty)` check only).

## 3. Architecture Violations
- There is no Repository layer. The `SupabaseService` acts as a mega-repository doing both local stubbing and direct Supabase API calls. 
- Controllers (like `SpotController`, `AdminController`, `ReviewController`) talk directly to `SupabaseService` without role checking. Anyone triggering a controller method can approve/reject spots or suspend users.

## 4. Logic Issues: DB Integrity & Cascading Updates
- When a review is added via `ReviewController`, it just inserts a review. It does not update the `rating` or `reviewCount` on the parent `Spot` or `Restaurant`. `getAverageRating()` calculates it in-memory only, so the database will become stale.

## 5. Ambiguity in Spec to clarify with User
- If a spot is rejected, should it be permanently deleted, or remain as a draft for the user to fix and resubmit? (Currently it just updates the status to 'rejected').
- Should Influencer discount codes expire if the Influencer is suspended? (AdminController only suspends the user, doesn't touch discounts).
- How strict should the geographic proximity algorithm be for generating itineraries? (Need to check `itinerary_controller.dart` first).
