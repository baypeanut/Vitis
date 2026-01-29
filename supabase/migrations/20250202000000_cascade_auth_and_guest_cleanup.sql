-- Cascade on auth delete + Guest cleanup.
-- Run in Supabase SQL Editor. Ensures all user-scoped data is removed when auth user is deleted.
-- Keeps FKs to wines unchanged.

-- -----------------------------------------------------------------------------
-- 1. Drop dependent view and function
-- -----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.feed_following(uuid, int, int);
DROP VIEW IF EXISTS public.feed_with_details;

-- -----------------------------------------------------------------------------
-- 2. Drop FKs to auth.users (standard names). Use IF EXISTS.
-- -----------------------------------------------------------------------------
ALTER TABLE public.profiles       DROP CONSTRAINT IF EXISTS profiles_id_fkey;
ALTER TABLE public.comparisons    DROP CONSTRAINT IF EXISTS comparisons_user_id_fkey;
ALTER TABLE public.rankings       DROP CONSTRAINT IF EXISTS rankings_user_id_fkey;
ALTER TABLE public.follows        DROP CONSTRAINT IF EXISTS follows_follower_id_fkey;
ALTER TABLE public.follows        DROP CONSTRAINT IF EXISTS follows_followed_id_fkey;
ALTER TABLE public.activity_feed  DROP CONSTRAINT IF EXISTS activity_feed_user_id_fkey;
ALTER TABLE public.comments_cheers DROP CONSTRAINT IF EXISTS comments_cheers_user_id_fkey;
ALTER TABLE public.likes          DROP CONSTRAINT IF EXISTS likes_user_id_fkey;
ALTER TABLE public.comments       DROP CONSTRAINT IF EXISTS comments_user_id_fkey;
ALTER TABLE public.user_private   DROP CONSTRAINT IF EXISTS user_private_user_id_fkey;

-- -----------------------------------------------------------------------------
-- 3. Re-add FKs with ON DELETE CASCADE
-- -----------------------------------------------------------------------------
ALTER TABLE public.profiles
  ADD CONSTRAINT profiles_id_fkey
  FOREIGN KEY (id) REFERENCES auth.users(id) ON DELETE CASCADE;

ALTER TABLE public.comparisons
  ADD CONSTRAINT comparisons_user_id_fkey
  FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;

ALTER TABLE public.rankings
  ADD CONSTRAINT rankings_user_id_fkey
  FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;

ALTER TABLE public.follows
  ADD CONSTRAINT follows_follower_id_fkey
  FOREIGN KEY (follower_id) REFERENCES auth.users(id) ON DELETE CASCADE;

ALTER TABLE public.follows
  ADD CONSTRAINT follows_followed_id_fkey
  FOREIGN KEY (followed_id) REFERENCES auth.users(id) ON DELETE CASCADE;

ALTER TABLE public.activity_feed
  ADD CONSTRAINT activity_feed_user_id_fkey
  FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;

ALTER TABLE public.comments_cheers
  ADD CONSTRAINT comments_cheers_user_id_fkey
  FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;

ALTER TABLE public.likes
  ADD CONSTRAINT likes_user_id_fkey
  FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;

ALTER TABLE public.comments
  ADD CONSTRAINT comments_user_id_fkey
  FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;

ALTER TABLE public.user_private
  ADD CONSTRAINT user_private_user_id_fkey
  FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;

-- -----------------------------------------------------------------------------
-- 4. Delete any persisted "Guest" profiles (must run before view recreate)
-- -----------------------------------------------------------------------------
DELETE FROM public.profiles
WHERE lower(trim(username)) = 'guest';

-- -----------------------------------------------------------------------------
-- 5. Recreate feed view: INNER JOIN profiles so we never surface orphan activities
-- -----------------------------------------------------------------------------
CREATE VIEW public.feed_with_details AS
SELECT
  a.id,
  a.user_id,
  a.activity_type,
  a.wine_id,
  a.target_wine_id,
  a.content_text,
  a.created_at,
  p.username,
  p.full_name,
  p.avatar_url,
  w.name AS wine_name,
  w.producer AS wine_producer,
  w.vintage AS wine_vintage,
  w.label_image_url AS wine_label_url,
  tw.name AS target_wine_name,
  tw.producer AS target_wine_producer,
  tw.vintage AS target_wine_vintage,
  tw.label_image_url AS target_wine_label_url
FROM public.activity_feed a
INNER JOIN public.profiles p ON p.id = a.user_id
LEFT JOIN public.wines w ON w.id = a.wine_id
LEFT JOIN public.wines tw ON tw.id = a.target_wine_id;

-- -----------------------------------------------------------------------------
-- 6. Recreate feed_following function
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.feed_following(
  p_follower_id uuid,
  p_limit int DEFAULT 30,
  p_offset int DEFAULT 0
)
RETURNS SETOF public.feed_with_details
LANGUAGE sql
STABLE
AS $$
  SELECT f.*
  FROM public.feed_with_details f
  JOIN public.follows fo ON fo.followed_id = f.user_id AND fo.follower_id = p_follower_id
  ORDER BY f.created_at DESC
  LIMIT p_limit OFFSET p_offset;
$$;
