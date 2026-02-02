-- Migration: Add foreign key relationship between tastings and profiles
-- This allows Supabase PostgREST to automatically join tastings with profiles

-- Drop the existing foreign key constraint to auth.users
ALTER TABLE public.tastings 
  DROP CONSTRAINT IF EXISTS tastings_user_id_fkey;

-- Add a new foreign key constraint to public.profiles
-- This enables the tastings->profiles relationship for PostgREST queries
ALTER TABLE public.tastings 
  ADD CONSTRAINT tastings_user_id_fkey 
  FOREIGN KEY (user_id) 
  REFERENCES public.profiles(id) 
  ON DELETE CASCADE;

-- Note: This works because profiles.id is the same as auth.users.id
-- The profiles table is created with a trigger that ensures every auth.users
-- record has a corresponding profiles record
