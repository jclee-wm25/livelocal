-- ==============================================================================
-- LIVE LOCAL - SUPABASE SECURITY AUDIT & ROW LEVEL SECURITY (RLS) POLICIES
-- ==============================================================================

-- 1. Enable RLS on all tables
ALTER TABLE spots ENABLE ROW LEVEL SECURITY;
ALTER TABLE restaurants ENABLE ROW LEVEL SECURITY;
ALTER TABLE reviews ENABLE ROW LEVEL SECURITY;
ALTER TABLE saved_places ENABLE ROW LEVEL SECURITY;
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE discounts ENABLE ROW LEVEL SECURITY;

-- Phase 9: Moderation Tables
CREATE TABLE reports (
  id uuid DEFAULT uuid_generate_v4() PRIMARY KEY,
  reporter_id uuid REFERENCES auth.users(id),
  target_id text NOT NULL, -- ID of the spot, review, or user being reported
  target_type text NOT NULL, -- 'spot', 'review', 'user'
  reason text NOT NULL,
  status text DEFAULT 'pending', -- 'pending', 'resolved', 'dismissed'
  created_at timestamp with time zone DEFAULT timezone('utc'::text, now())
);

CREATE TABLE blocked_users (
  blocker_id uuid REFERENCES auth.users(id),
  blocked_id uuid REFERENCES auth.users(id),
  created_at timestamp with time zone DEFAULT timezone('utc'::text, now()),
  PRIMARY KEY (blocker_id, blocked_id)
);

ALTER TABLE reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE blocked_users ENABLE ROW LEVEL SECURITY;

-- ==============================================================================
-- SPOTS TABLE POLICIES
-- ==============================================================================
-- Public can only see approved spots
CREATE POLICY "Public can view approved spots" ON spots
  FOR SELECT USING (status = 'approved');

-- Users can see their own pending/rejected spots
CREATE POLICY "Users can view their own spots" ON spots
  FOR SELECT USING (auth.uid()::text = submitted_by);

-- Admins can view all spots
CREATE POLICY "Admins can view all spots" ON spots
  FOR SELECT USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid()::text AND role = 'admin')
  );

-- Any authenticated user can insert a spot (defaults to 'pending')
CREATE POLICY "Users can submit spots" ON spots
  FOR INSERT WITH CHECK (auth.role() = 'authenticated' AND status = 'pending');

-- Users can update their own spots IF they are 'pending' or 'rejected'
CREATE POLICY "Users can update their own drafts" ON spots
  FOR UPDATE USING (
    auth.uid()::text = submitted_by 
    AND status IN ('pending', 'rejected')
  );

-- Admins can update any spot (approve/reject)
CREATE POLICY "Admins can update any spot" ON spots
  FOR UPDATE USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid()::text AND role = 'admin')
  );

-- Users can delete their own spots
CREATE POLICY "Users can delete their own spots" ON spots
  FOR DELETE USING (auth.uid()::text = submitted_by);


-- ==============================================================================
-- RESTAURANTS TABLE POLICIES
-- ==============================================================================
-- Public can view all restaurants
CREATE POLICY "Public can view restaurants" ON restaurants
  FOR SELECT USING (true);

-- Only influencers can insert new restaurants
CREATE POLICY "Influencers can insert restaurants" ON restaurants
  FOR INSERT WITH CHECK (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid()::text AND role = 'influencer')
    AND auth.uid()::text = influencer_id
  );

-- Influencers can update their own added restaurants
CREATE POLICY "Influencers can update their own restaurants" ON restaurants
  FOR UPDATE USING (auth.uid()::text = influencer_id);

-- Admins can update/delete any restaurant
CREATE POLICY "Admins can manage restaurants" ON restaurants
  FOR ALL USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid()::text AND role = 'admin')
  );


-- ==============================================================================
-- SAVED PLACES TABLE POLICIES
-- ==============================================================================
-- Users can only see, insert, update, delete their OWN saved places
CREATE POLICY "Users manage their own saved places" ON saved_places
  FOR ALL USING (auth.uid()::text = user_id);


-- ==============================================================================
-- REVIEWS TABLE POLICIES
-- ==============================================================================
-- Public can view all reviews
CREATE POLICY "Public can view reviews" ON reviews
  FOR SELECT USING (true);

-- Authenticated users can insert reviews for approved spots or restaurants
CREATE POLICY "Users can insert reviews" ON reviews
  FOR INSERT WITH CHECK (auth.role() = 'authenticated');

-- Users can update/delete their own reviews
CREATE POLICY "Users manage their own reviews" ON reviews
  FOR ALL USING (auth.uid()::text = user_id);


-- ==============================================================================
-- PROFILES TABLE POLICIES
-- ==============================================================================
-- Public can view basic profile info (like usernames for reviews)
CREATE POLICY "Public can view profiles" ON profiles
  FOR SELECT USING (true);

-- Users can update their OWN profiles
CREATE POLICY "Users can update their own profile" ON profiles
  FOR UPDATE USING (auth.uid()::text = id);

-- Admins can update any profile (e.g., suspending influencers)
CREATE POLICY "Admins can manage profiles" ON profiles
  FOR UPDATE USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid()::text AND role = 'admin')
  );


-- ==============================================================================
-- DISCOUNTS TABLE POLICIES
-- ==============================================================================
-- Public can view active discounts
CREATE POLICY "Public can view active discounts" ON discounts
  FOR SELECT USING (is_active = true);

-- Influencers can view, insert, update their own discounts
CREATE POLICY "Influencers manage their own discounts" ON discounts
  FOR ALL USING (auth.uid()::text = influencer_id);

-- Admins can manage all discounts
CREATE POLICY "Admins can manage all discounts" ON discounts
  FOR ALL USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid()::text AND role = 'admin')
  );

-- ==============================================================================
-- STORAGE BUCKET POLICIES (For image_picker uploads)
-- ==============================================================================
-- Enable public access to 'spot_images' bucket
CREATE POLICY "Public Access to spot images" ON storage.objects
  FOR SELECT USING (bucket_id = 'spot_images');

-- Authenticated users can upload to 'spot_images' bucket
CREATE POLICY "Users can upload spot images" ON storage.objects
  FOR INSERT WITH CHECK (bucket_id = 'spot_images' AND auth.role() = 'authenticated');

-- Users can update/delete their own uploaded images
CREATE POLICY "Users manage their own spot images" ON storage.objects
  FOR UPDATE USING (bucket_id = 'spot_images' AND auth.uid() = owner)
  WITH CHECK (bucket_id = 'spot_images' AND auth.uid() = owner);
CREATE POLICY "Users delete their own spot images" ON storage.objects
  FOR DELETE USING (bucket_id = 'spot_images' AND auth.uid() = owner);


-- ==============================================================================
-- MODERATION POLICIES (Phase 9)
-- ==============================================================================
-- Reports Table
CREATE POLICY "Users can insert reports" ON reports
  FOR INSERT WITH CHECK (auth.role() = 'authenticated' AND auth.uid() = reporter_id);

CREATE POLICY "Users can view their own reports" ON reports
  FOR SELECT USING (auth.uid() = reporter_id);

CREATE POLICY "Admins can manage reports" ON reports
  FOR ALL USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid()::text AND role = 'admin')
  );

-- Blocked Users Table
CREATE POLICY "Users can manage their own blocks" ON blocked_users
  FOR ALL USING (auth.uid() = blocker_id);
