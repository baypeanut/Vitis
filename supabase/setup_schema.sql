-- Vitis – Supabase schema setup (single file, includes all migrations)
-- Run this entire script in Supabase Dashboard → SQL Editor → New query.
-- Fresh setup: no need to run individual migrations. This file is the full schema.

-- -----------------------------------------------------------------------------
-- 1. Base tables: wines, profiles
-- -----------------------------------------------------------------------------
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

CREATE TABLE IF NOT EXISTS public.wines (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  producer text NOT NULL,
  vintage int,
  variety text,
  region text,
  label_image_url text,
  category text CHECK (category IS NULL OR category IN ('Red', 'White', 'Sparkling', 'Rose')),
  created_at timestamptz DEFAULT now()
);
ALTER TABLE public.wines ADD COLUMN IF NOT EXISTS category text;
ALTER TABLE public.wines ADD COLUMN IF NOT EXISTS created_at timestamptz DEFAULT now();

CREATE TABLE IF NOT EXISTS public.profiles (
  id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  username text NOT NULL,
  full_name text,
  avatar_url text,
  bio text,
  created_at timestamptz DEFAULT now()
);
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS created_at timestamptz DEFAULT now();
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS full_name text;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS password_updated_at timestamptz DEFAULT null;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS instagram_url text;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS taste_snapshot_loves text;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS taste_snapshot_avoids text;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS taste_snapshot_mood text;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS weekly_goal text;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS email text;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS cellar_visibility text NOT NULL DEFAULT 'everyone' CHECK (cellar_visibility IN ('everyone', 'friends'));
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS wishlist_visibility text NOT NULL DEFAULT 'everyone' CHECK (wishlist_visibility IN ('everyone', 'friends'));
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS activity_visibility text NOT NULL DEFAULT 'everyone' CHECK (activity_visibility IN ('everyone', 'friends'));
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS deleted_at timestamptz NULL;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS phone_hash text;
CREATE UNIQUE INDEX IF NOT EXISTS profiles_username_lower_key ON public.profiles (lower(trim(username)));
CREATE INDEX IF NOT EXISTS idx_profiles_phone_hash ON public.profiles (phone_hash);
CREATE INDEX IF NOT EXISTS idx_profiles_search ON public.profiles
  USING gin (to_tsvector('simple', coalesce(username, '') || ' ' || coalesce(full_name, '')));

-- Harden wines access: enable RLS and expose as read-only catalog to clients.
ALTER TABLE public.wines ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "wines_select_public" ON public.wines;
CREATE POLICY "wines_select_public" ON public.wines
  FOR SELECT USING (true);

-- Allow authenticated users to insert/update wines via OFF upsert flow.
DROP POLICY IF EXISTS "wines_write_auth" ON public.wines;
CREATE POLICY "wines_write_auth" ON public.wines
  FOR INSERT
  WITH CHECK (auth.uid() IS NOT NULL);

DROP POLICY IF EXISTS "wines_update_auth" ON public.wines;
CREATE POLICY "wines_update_auth" ON public.wines
  FOR UPDATE
  USING (auth.uid() IS NOT NULL)
  WITH CHECK (auth.uid() IS NOT NULL);

ALTER TABLE public.wines ADD COLUMN IF NOT EXISTS label_image_url text;
ALTER TABLE public.wines ADD COLUMN IF NOT EXISTS off_code text;
CREATE UNIQUE INDEX IF NOT EXISTS idx_wines_off_code ON public.wines (off_code) WHERE off_code IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_wines_category ON public.wines (category) WHERE category IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_wines_created_at ON public.wines (created_at DESC);

-- -----------------------------------------------------------------------------
-- 2. Seed 6 wines (so duel_next_pair returns pairs)
-- -----------------------------------------------------------------------------
INSERT INTO public.wines (id, name, producer, vintage, variety, region, category) VALUES
  ('a1000001-0000-0000-0000-000000000001', 'Sassicaia', 'Tenuta San Guido', 2019, 'Cabernet Sauvignon', 'Tuscany', 'Red'),
  ('a1000002-0000-0000-0000-000000000002', 'Château Margaux', 'Château Margaux', 2015, 'Cabernet Sauvignon', 'Bordeaux', 'Red'),
  ('a1000003-0000-0000-0000-000000000003', 'Barolo', 'Giacomo Conterno', 2017, 'Nebbiolo', 'Piedmont', 'Red'),
  ('a1000004-0000-0000-0000-000000000004', 'Côte Rôtie', 'Domaine Jean-Michel Gerin', 2019, 'Syrah', 'Rhône Valley', 'Red'),
  ('a1000005-0000-0000-0000-000000000005', 'Opus One', 'Opus One Winery', 2018, 'Cabernet Sauvignon', 'Napa Valley', 'Red'),
  ('a1000006-0000-0000-0000-000000000006', 'Dom Pérignon', 'Moët & Chandon', 2012, 'Chardonnay', 'Champagne', 'Sparkling')
ON CONFLICT (id) DO NOTHING;

-- A0: app_config for environment (local | staging | production)
CREATE TABLE IF NOT EXISTS public.app_config (key text PRIMARY KEY, value text NOT NULL);
INSERT INTO public.app_config (key, value) VALUES ('app_env', 'production') ON CONFLICT (key) DO NOTHING;

-- app_config: RLS on, but read-only for clients (service role writes).
ALTER TABLE public.app_config ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "app_config_read_all" ON public.app_config;
CREATE POLICY "app_config_read_all" ON public.app_config
  FOR SELECT USING (true);

-- A9: audit_log (server-only readable; insert via RPC)
CREATE TABLE IF NOT EXISTS public.audit_log (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  event_type text NOT NULL,
  metadata jsonb DEFAULT '{}',
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_audit_log_user ON public.audit_log (user_id);
CREATE INDEX IF NOT EXISTS idx_audit_log_created ON public.audit_log (created_at DESC);
ALTER TABLE public.audit_log ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "audit_log_deny_all" ON public.audit_log;
CREATE POLICY "audit_log_deny_all" ON public.audit_log FOR ALL USING (false) WITH CHECK (false);

CREATE OR REPLACE FUNCTION public.audit_log_insert(p_user_id uuid, p_event_type text, p_metadata jsonb DEFAULT '{}')
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  INSERT INTO public.audit_log (user_id, event_type, metadata) VALUES (p_user_id, p_event_type, p_metadata);
END;
$$;
GRANT EXECUTE ON FUNCTION public.audit_log_insert(uuid, text, jsonb) TO authenticated;

-- -----------------------------------------------------------------------------
-- 3. Profiles RLS (privacy: hide deleted from others)
-- -----------------------------------------------------------------------------
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "profiles_select" ON public.profiles;
CREATE POLICY "profiles_select" ON public.profiles FOR SELECT
  USING (auth.uid() = id OR deleted_at IS NULL);
DROP POLICY IF EXISTS "profiles_insert_own" ON public.profiles;
CREATE POLICY "profiles_insert_own" ON public.profiles FOR INSERT WITH CHECK (auth.uid() = id);
DROP POLICY IF EXISTS "profiles_update_own" ON public.profiles;
CREATE POLICY "profiles_update_own" ON public.profiles FOR UPDATE USING (auth.uid() = id);

DROP POLICY IF EXISTS "dev_mock_profiles_insert" ON public.profiles;
CREATE POLICY "dev_mock_profiles_insert" ON public.profiles FOR INSERT
  WITH CHECK (auth.uid() IS NULL AND id = '1edd4da3-ecd2-4c30-9f2f-ac7573a8fcba'::uuid);
DROP POLICY IF EXISTS "dev_mock_profiles_update" ON public.profiles;
CREATE POLICY "dev_mock_profiles_update" ON public.profiles FOR UPDATE
  USING (auth.uid() IS NULL)
  WITH CHECK (auth.uid() IS NULL);

-- -----------------------------------------------------------------------------
-- 4. comparisons, rankings
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.comparisons (
  id uuid NOT NULL PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  wine_a_id uuid NOT NULL REFERENCES public.wines(id) ON DELETE CASCADE,
  wine_b_id uuid NOT NULL REFERENCES public.wines(id) ON DELETE CASCADE,
  winner_id uuid NOT NULL REFERENCES public.wines(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT winner_is_a_or_b CHECK (winner_id = wine_a_id OR winner_id = wine_b_id)
);
CREATE INDEX IF NOT EXISTS idx_comparisons_user ON public.comparisons (user_id);
CREATE INDEX IF NOT EXISTS idx_comparisons_created ON public.comparisons (created_at DESC);
ALTER TABLE public.comparisons ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users can read own comparisons" ON public.comparisons;
CREATE POLICY "Users can read own comparisons" ON public.comparisons FOR SELECT USING (auth.uid() = user_id);
DROP POLICY IF EXISTS "Users can insert own comparisons" ON public.comparisons;
CREATE POLICY "Users can insert own comparisons" ON public.comparisons FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE TABLE IF NOT EXISTS public.rankings (
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  wine_id uuid NOT NULL REFERENCES public.wines(id) ON DELETE CASCADE,
  elo_score double precision NOT NULL DEFAULT 1500,
  position int NOT NULL DEFAULT 0,
  updated_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, wine_id)
);
CREATE INDEX IF NOT EXISTS idx_rankings_user_position ON public.rankings (user_id, position);
ALTER TABLE public.rankings ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users can read own rankings" ON public.rankings;
CREATE POLICY "Users can read own rankings" ON public.rankings FOR SELECT USING (auth.uid() = user_id);
DROP POLICY IF EXISTS "Users can insert own rankings" ON public.rankings;
CREATE POLICY "Users can insert own rankings" ON public.rankings FOR INSERT WITH CHECK (auth.uid() = user_id);
DROP POLICY IF EXISTS "Users can update own rankings" ON public.rankings;
CREATE POLICY "Users can update own rankings" ON public.rankings FOR UPDATE USING (auth.uid() = user_id);

-- -----------------------------------------------------------------------------
-- 5. Social feed: follows, activity_feed, feed_with_details view, feed_following RPC
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.follows (
  follower_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  followed_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (follower_id, followed_id),
  CONSTRAINT follows_no_self CHECK (follower_id != followed_id)
);
CREATE INDEX IF NOT EXISTS idx_follows_follower ON public.follows (follower_id);
CREATE INDEX IF NOT EXISTS idx_follows_followed ON public.follows (followed_id);
ALTER TABLE public.follows ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users can view follows" ON public.follows;
CREATE POLICY "Users can view follows" ON public.follows FOR SELECT USING (true);
DROP POLICY IF EXISTS "Users can manage own follows" ON public.follows;
CREATE POLICY "Users can manage own follows" ON public.follows FOR ALL USING (auth.uid() = follower_id);

CREATE OR REPLACE FUNCTION public.is_mutual_friend(p_viewer_id uuid, p_owner_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY INVOKER
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.follows a
    WHERE a.follower_id = p_viewer_id AND a.followed_id = p_owner_id
  ) AND EXISTS (
    SELECT 1 FROM public.follows b
    WHERE b.follower_id = p_owner_id AND b.followed_id = p_viewer_id
  );
$$;

CREATE OR REPLACE FUNCTION public.can_view_activity(p_viewer_id uuid, p_owner_id uuid, p_visibility text)
RETURNS boolean LANGUAGE sql STABLE SECURITY INVOKER AS $$
  SELECT p_viewer_id = p_owner_id OR p_visibility = 'everyone'
    OR (p_visibility = 'friends' AND p_viewer_id IS NOT NULL AND public.is_mutual_friend(p_viewer_id, p_owner_id));
$$;

CREATE OR REPLACE FUNCTION public.can_view_cellar(p_viewer_id uuid, p_owner_id uuid, p_visibility text)
RETURNS boolean LANGUAGE sql STABLE SECURITY INVOKER AS $$
  SELECT p_viewer_id = p_owner_id OR p_visibility = 'everyone'
    OR (p_visibility = 'friends' AND p_viewer_id IS NOT NULL AND public.is_mutual_friend(p_viewer_id, p_owner_id));
$$;

CREATE TABLE IF NOT EXISTS public.activity_feed (
  id uuid NOT NULL PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  activity_type text NOT NULL CHECK (activity_type IN ('rank_update', 'new_entry', 'duel_win', 'had_wine')),
  wine_id uuid NOT NULL REFERENCES public.wines(id) ON DELETE CASCADE,
  target_wine_id uuid REFERENCES public.wines(id) ON DELETE SET NULL,
  content_text text,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_activity_feed_user ON public.activity_feed (user_id);
CREATE INDEX IF NOT EXISTS idx_activity_feed_created ON public.activity_feed (created_at DESC);
CREATE INDEX IF NOT EXISTS idx_activity_feed_user_created ON public.activity_feed (user_id, created_at DESC);

-- Update activity_type constraint to include 'had_wine' (if table already exists)
ALTER TABLE public.activity_feed DROP CONSTRAINT IF EXISTS activity_feed_activity_type_check;
ALTER TABLE public.activity_feed ADD CONSTRAINT activity_feed_activity_type_check
  CHECK (activity_type IN ('rank_update', 'new_entry', 'duel_win', 'had_wine'));
ALTER TABLE public.activity_feed ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Anyone can read activity_feed" ON public.activity_feed;
DROP POLICY IF EXISTS "activity_feed_select_privacy" ON public.activity_feed;
CREATE POLICY "activity_feed_select_privacy" ON public.activity_feed FOR SELECT
  USING (
    auth.uid() = user_id
    OR EXISTS (
      SELECT 1 FROM public.profiles pr
      WHERE pr.id = activity_feed.user_id AND pr.deleted_at IS NULL
        AND public.can_view_activity(auth.uid(), pr.id, pr.activity_visibility)
    )
  );
DROP POLICY IF EXISTS "Users can insert own activity" ON public.activity_feed;
CREATE POLICY "Users can insert own activity" ON public.activity_feed FOR INSERT WITH CHECK (auth.uid() = user_id);
DROP POLICY IF EXISTS "Users can delete own activity" ON public.activity_feed;
CREATE POLICY "Users can delete own activity" ON public.activity_feed FOR DELETE USING (auth.uid() = user_id);

DROP FUNCTION IF EXISTS public.feed_following(uuid, int, int);
DROP VIEW IF EXISTS public.feed_with_details CASCADE;

-- -----------------------------------------------------------------------------
-- comments_cheers (comment_body NULL = Cheer; non-null = Comment)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.comments_cheers (
  id uuid NOT NULL PRIMARY KEY DEFAULT gen_random_uuid(),
  activity_id uuid NOT NULL REFERENCES public.activity_feed(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  comment_body text,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT one_interaction_per_user UNIQUE (activity_id, user_id)
);
CREATE INDEX IF NOT EXISTS idx_comments_cheers_activity ON public.comments_cheers (activity_id);
CREATE INDEX IF NOT EXISTS idx_comments_cheers_user ON public.comments_cheers (user_id);
ALTER TABLE public.comments_cheers ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Anyone can read comments_cheers" ON public.comments_cheers;
DROP POLICY IF EXISTS "comments_cheers_select_privacy" ON public.comments_cheers;
CREATE POLICY "comments_cheers_select_privacy" ON public.comments_cheers FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.activity_feed a
      JOIN public.profiles pr ON pr.id = a.user_id
      WHERE a.id = comments_cheers.activity_id
        AND (a.user_id = auth.uid() OR (pr.deleted_at IS NULL AND public.can_view_activity(auth.uid(), pr.id, pr.activity_visibility)))
    )
  );
DROP POLICY IF EXISTS "Users can insert own comments/cheers" ON public.comments_cheers;
CREATE POLICY "Users can insert own comments/cheers" ON public.comments_cheers FOR INSERT WITH CHECK (auth.uid() = user_id);
DROP POLICY IF EXISTS "Users can delete own comments/cheers" ON public.comments_cheers;
CREATE POLICY "Users can delete own comments/cheers" ON public.comments_cheers FOR DELETE USING (auth.uid() = user_id);
DROP POLICY IF EXISTS "Users can update own comments/cheers" ON public.comments_cheers;
CREATE POLICY "Users can update own comments/cheers" ON public.comments_cheers FOR UPDATE USING (auth.uid() = user_id);

-- -----------------------------------------------------------------------------
-- likes (Cheers) and comments — separate tables to fix persistence bugs
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.likes (
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  activity_id uuid NOT NULL REFERENCES public.activity_feed(id) ON DELETE CASCADE,
  created_at timestamptz DEFAULT now(),
  PRIMARY KEY (user_id, activity_id)
);
CREATE INDEX IF NOT EXISTS idx_likes_activity ON public.likes (activity_id);
CREATE INDEX IF NOT EXISTS idx_likes_user ON public.likes (user_id);

CREATE TABLE IF NOT EXISTS public.comments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  activity_id uuid NOT NULL REFERENCES public.activity_feed(id) ON DELETE CASCADE,
  body text NOT NULL,
  created_at timestamptz DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_comments_activity ON public.comments (activity_id);
CREATE INDEX IF NOT EXISTS idx_comments_user ON public.comments (user_id);

ALTER TABLE public.likes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.comments ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "likes_select" ON public.likes;
DROP POLICY IF EXISTS "likes_select_privacy" ON public.likes;
CREATE POLICY "likes_select_privacy" ON public.likes FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.activity_feed a
      JOIN public.profiles pr ON pr.id = a.user_id
      WHERE a.id = likes.activity_id
        AND (a.user_id = auth.uid() OR (pr.deleted_at IS NULL AND public.can_view_activity(auth.uid(), pr.id, pr.activity_visibility)))
    )
  );
DROP POLICY IF EXISTS "likes_insert_own" ON public.likes;
CREATE POLICY "likes_insert_own" ON public.likes FOR INSERT WITH CHECK (auth.uid() = user_id);
DROP POLICY IF EXISTS "likes_delete_own" ON public.likes;
CREATE POLICY "likes_delete_own" ON public.likes FOR DELETE USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "comments_select" ON public.comments;
DROP POLICY IF EXISTS "comments_select_privacy" ON public.comments;
CREATE POLICY "comments_select_privacy" ON public.comments FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.activity_feed a
      JOIN public.profiles pr ON pr.id = a.user_id
      WHERE a.id = comments.activity_id
        AND (a.user_id = auth.uid() OR (pr.deleted_at IS NULL AND public.can_view_activity(auth.uid(), pr.id, pr.activity_visibility)))
    )
  );
DROP POLICY IF EXISTS "comments_insert_own" ON public.comments;
CREATE POLICY "comments_insert_own" ON public.comments FOR INSERT WITH CHECK (auth.uid() = user_id);
DROP POLICY IF EXISTS "comments_delete_own" ON public.comments;
CREATE POLICY "comments_delete_own" ON public.comments FOR DELETE USING (auth.uid() = user_id);

-- -----------------------------------------------------------------------------
-- Notifications: like, comment, follow
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.notifications (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  recipient_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  actor_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  type text NOT NULL CHECK (type IN ('like', 'comment', 'follow')),
  post_id uuid REFERENCES public.activity_feed(id) ON DELETE CASCADE,
  comment_id uuid REFERENCES public.comments(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  is_read boolean NOT NULL DEFAULT false
);
CREATE INDEX IF NOT EXISTS idx_notifications_recipient_created ON public.notifications (recipient_id, created_at DESC);
-- Remove duplicate like notifications before creating unique index
DELETE FROM public.notifications n1
USING public.notifications n2
WHERE n1.type = 'like' AND n2.type = 'like'
  AND n1.recipient_id = n2.recipient_id AND n1.actor_id = n2.actor_id AND n1.post_id = n2.post_id
  AND n1.id > n2.id;
CREATE UNIQUE INDEX IF NOT EXISTS idx_notifications_like_unique
  ON public.notifications (recipient_id, actor_id, post_id) WHERE type = 'like';
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "notifications_select_own" ON public.notifications;
CREATE POLICY "notifications_select_own" ON public.notifications FOR SELECT USING (auth.uid() = recipient_id);
DROP POLICY IF EXISTS "notifications_insert" ON public.notifications;
CREATE POLICY "notifications_insert" ON public.notifications FOR INSERT WITH CHECK (auth.uid() = actor_id);
DROP POLICY IF EXISTS "notifications_update_own" ON public.notifications;
CREATE POLICY "notifications_update_own" ON public.notifications FOR UPDATE USING (auth.uid() = recipient_id) WITH CHECK (auth.uid() = recipient_id);

-- Mark all as read RPC (batch 500)
CREATE OR REPLACE FUNCTION public.notifications_mark_all_read(p_recipient_id uuid)
RETURNS int
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE v_count int;
BEGIN
  IF auth.uid() != p_recipient_id THEN RAISE EXCEPTION 'Unauthorized'; END IF;
  WITH to_update AS (
    SELECT id FROM public.notifications
    WHERE recipient_id = p_recipient_id AND is_read = false
    LIMIT 500
  ),
  updated AS (
    UPDATE public.notifications SET is_read = true
    WHERE id IN (SELECT id FROM to_update)
    RETURNING id
  )
  SELECT count(*) INTO v_count FROM updated;
  RETURN v_count;
END;
$$;
GRANT EXECUTE ON FUNCTION public.notifications_mark_all_read(uuid) TO authenticated;

CREATE OR REPLACE FUNCTION public.insert_like_notification_if_new(p_recipient_id uuid, p_actor_id uuid, p_post_id uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  INSERT INTO public.notifications (recipient_id, actor_id, type, post_id)
  VALUES (p_recipient_id, p_actor_id, 'like', p_post_id)
  ON CONFLICT DO NOTHING;
EXCEPTION WHEN unique_violation THEN NULL;
END;
$$;
GRANT EXECUTE ON FUNCTION public.insert_like_notification_if_new(uuid, uuid, uuid) TO authenticated;

-- -----------------------------------------------------------------------------
-- Tastings: wine logging with rating and optional notes (replaces duel/comparison)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.tastings (
  id uuid NOT NULL PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  wine_id uuid NOT NULL REFERENCES public.wines(id) ON DELETE CASCADE,
  rating double precision NOT NULL CHECK (rating >= 1.0 AND rating <= 10.0),
  note_tags text[] NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  source text NULL
);

-- Add comment column (2025-02-02)
ALTER TABLE public.tastings ADD COLUMN IF NOT EXISTS comment text NULL;
-- Per-tasting visibility (Public / Friends Only). App sends this on insert.
ALTER TABLE public.tastings ADD COLUMN IF NOT EXISTS visibility text NOT NULL DEFAULT 'everyone' CHECK (visibility IN ('everyone', 'friends'));
-- Optional "wine night" photo for feed only (not shown in cellar).
ALTER TABLE public.tastings ADD COLUMN IF NOT EXISTS moment_image_url text NULL;

CREATE INDEX IF NOT EXISTS idx_tastings_user_created ON public.tastings (user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_tastings_wine ON public.tastings (wine_id);
CREATE INDEX IF NOT EXISTS idx_tastings_comment ON public.tastings USING gin(to_tsvector('english', comment)) WHERE comment IS NOT NULL;

ALTER TABLE public.tastings ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "tastings_select_own" ON public.tastings;

DROP POLICY IF EXISTS "tastings_update_own" ON public.tastings;
CREATE POLICY "tastings_update_own" ON public.tastings FOR UPDATE USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "tastings_delete_own" ON public.tastings;
CREATE POLICY "tastings_delete_own" ON public.tastings FOR DELETE USING (auth.uid() = user_id);

-- Privacy: owner or can_view_activity for others
DROP POLICY IF EXISTS "tastings_select_public" ON public.tastings;
DROP POLICY IF EXISTS "tastings_select_privacy" ON public.tastings;
CREATE POLICY "tastings_select_privacy" ON public.tastings FOR SELECT
  USING (
    auth.uid() = user_id
    OR EXISTS (
      SELECT 1 FROM public.profiles pr
      WHERE pr.id = tastings.user_id AND pr.deleted_at IS NULL
        AND public.can_view_activity(auth.uid(), pr.id, pr.activity_visibility)
    )
  );

DROP POLICY IF EXISTS "tastings_insert_own" ON public.tastings;
CREATE POLICY "tastings_insert_own" ON public.tastings FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Dev mock: allow when auth.uid() IS NULL and user_id matches debugMockUserId
DROP POLICY IF EXISTS "dev_mock_tastings" ON public.tastings;
CREATE POLICY "dev_mock_tastings" ON public.tastings FOR ALL
  USING (
    auth.uid() IS NULL
    AND user_id = '1edd4da3-ecd2-4c30-9f2f-ac7573a8fcba'::uuid
    AND EXISTS (SELECT 1 FROM public.app_config WHERE key = 'app_env' AND value IN ('local', 'staging'))
  )
  WITH CHECK (
    auth.uid() IS NULL
    AND user_id = '1edd4da3-ecd2-4c30-9f2f-ac7573a8fcba'::uuid
    AND EXISTS (SELECT 1 FROM public.app_config WHERE key = 'app_env' AND value IN ('local', 'staging'))
  );

-- -----------------------------------------------------------------------------
-- activity_feed.tasting_id for deterministic feed-tasting join (after tastings exists)
-- -----------------------------------------------------------------------------
ALTER TABLE public.activity_feed ADD COLUMN IF NOT EXISTS tasting_id uuid REFERENCES public.tastings(id) ON DELETE CASCADE;
CREATE INDEX IF NOT EXISTS idx_activity_feed_tasting_id ON public.activity_feed (tasting_id) WHERE tasting_id IS NOT NULL;

-- -----------------------------------------------------------------------------
-- feed_with_details view (created AFTER tastings table exists)
-- -----------------------------------------------------------------------------
CREATE OR REPLACE VIEW public.feed_with_details AS
SELECT DISTINCT ON (a.id)
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
  w.region AS wine_region,
  w.category AS wine_category,
  w.variety AS wine_variety,
  tw.name AS target_wine_name,
  tw.producer AS target_wine_producer,
  tw.vintage AS target_wine_vintage,
  tw.label_image_url AS target_wine_label_url,
  t.note_tags AS tasting_note_tags,
  t.rating AS tasting_rating,
  t.comment AS tasting_comment,
  t.moment_image_url AS tasting_moment_image_url
FROM public.activity_feed a
INNER JOIN public.profiles p ON p.id = a.user_id
LEFT JOIN public.wines w ON w.id = a.wine_id
LEFT JOIN public.wines tw ON tw.id = a.target_wine_id
LEFT JOIN public.tastings t ON (
  a.activity_type = 'had_wine' AND (
    (a.tasting_id IS NOT NULL AND a.tasting_id = t.id)
    OR (a.tasting_id IS NULL AND t.user_id = a.user_id AND t.wine_id = a.wine_id
        AND t.created_at BETWEEN a.created_at - INTERVAL '10 seconds' AND a.created_at + INTERVAL '10 seconds')
  )
)
ORDER BY a.id,
  CASE WHEN t.id IS NULL THEN 1 ELSE 0 END,
  CASE WHEN a.tasting_id IS NOT NULL THEN 0 ELSE 1 END,
  ABS(EXTRACT(EPOCH FROM (COALESCE(t.created_at, a.created_at) - a.created_at)));

-- A3: feed_global - enforces activity_visibility, excludes deleted
DROP FUNCTION IF EXISTS public.feed_global(uuid, int, int);
CREATE OR REPLACE FUNCTION public.feed_global(
  p_viewer_id uuid, p_limit int DEFAULT 30, p_offset int DEFAULT 0
)
RETURNS TABLE (
  id uuid, user_id uuid, activity_type text, wine_id uuid, target_wine_id uuid, content_text text, created_at timestamptz,
  username text, full_name text, avatar_url text,
  wine_name text, wine_producer text, wine_vintage int, wine_label_url text, wine_region text, wine_category text, wine_variety text,
  target_wine_name text, target_wine_producer text, target_wine_vintage int, target_wine_label_url text,
  tasting_note_tags text[], tasting_rating double precision, tasting_comment text, tasting_moment_image_url text
)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT * FROM (
    SELECT DISTINCT ON (a.id)
      a.id, a.user_id, a.activity_type, a.wine_id, a.target_wine_id, a.content_text, a.created_at,
      p.username, p.full_name, p.avatar_url,
      w.name, w.producer, w.vintage, w.label_image_url, w.region, w.category, w.variety,
      tw.name, tw.producer, tw.vintage, tw.label_image_url,
      t.note_tags, t.rating, t.comment, t.moment_image_url
    FROM public.activity_feed a
    INNER JOIN public.profiles p ON p.id = a.user_id AND p.deleted_at IS NULL
    LEFT JOIN public.wines w ON w.id = a.wine_id
    LEFT JOIN public.wines tw ON tw.id = a.target_wine_id
    LEFT JOIN public.tastings t ON (
      a.activity_type = 'had_wine' AND (
        (a.tasting_id IS NOT NULL AND a.tasting_id = t.id)
        OR (a.tasting_id IS NULL AND t.user_id = a.user_id AND t.wine_id = a.wine_id
            AND t.created_at BETWEEN a.created_at - INTERVAL '10 seconds' AND a.created_at + INTERVAL '10 seconds')
      )
    )
    WHERE a.activity_type = 'had_wine'
      AND auth.uid() IS NOT NULL
      AND public.can_view_activity(auth.uid(), a.user_id, p.activity_visibility)
    ORDER BY a.id, CASE WHEN t.id IS NULL THEN 1 ELSE 0 END, CASE WHEN a.tasting_id IS NOT NULL THEN 0 ELSE 1 END,
      ABS(EXTRACT(EPOCH FROM (COALESCE(t.created_at, a.created_at) - a.created_at)))
  ) sub
  ORDER BY created_at DESC
  LIMIT p_limit OFFSET p_offset;
$$;
GRANT EXECUTE ON FUNCTION public.feed_global(uuid, int, int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.feed_global(uuid, int, int) TO anon;

DROP FUNCTION IF EXISTS public.feed_following(uuid, int, int);
CREATE OR REPLACE FUNCTION public.feed_following(
  p_viewer_id uuid, p_limit int DEFAULT 30, p_offset int DEFAULT 0
)
RETURNS TABLE (
  id uuid, user_id uuid, activity_type text, wine_id uuid, target_wine_id uuid, content_text text, created_at timestamptz,
  username text, full_name text, avatar_url text,
  wine_name text, wine_producer text, wine_vintage int, wine_label_url text, wine_region text, wine_category text, wine_variety text,
  target_wine_name text, target_wine_producer text, target_wine_vintage int, target_wine_label_url text,
  tasting_note_tags text[], tasting_rating double precision, tasting_comment text, tasting_moment_image_url text
)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT * FROM (
    SELECT DISTINCT ON (a.id)
      a.id, a.user_id, a.activity_type, a.wine_id, a.target_wine_id, a.content_text, a.created_at,
      p.username, p.full_name, p.avatar_url,
      w.name, w.producer, w.vintage, w.label_image_url, w.region, w.category, w.variety,
      tw.name, tw.producer, tw.vintage, tw.label_image_url,
      t.note_tags, t.rating, t.comment, t.moment_image_url
    FROM public.activity_feed a
    INNER JOIN public.profiles p ON p.id = a.user_id AND p.deleted_at IS NULL
    INNER JOIN public.follows fo ON fo.followed_id = a.user_id AND fo.follower_id = auth.uid()
    LEFT JOIN public.wines w ON w.id = a.wine_id
    LEFT JOIN public.wines tw ON tw.id = a.target_wine_id
    LEFT JOIN public.tastings t ON (
      a.activity_type = 'had_wine' AND (
        (a.tasting_id IS NOT NULL AND a.tasting_id = t.id)
        OR (a.tasting_id IS NULL AND t.user_id = a.user_id AND t.wine_id = a.wine_id
            AND t.created_at BETWEEN a.created_at - INTERVAL '10 seconds' AND a.created_at + INTERVAL '10 seconds')
      )
    )
    WHERE a.activity_type = 'had_wine'
      AND auth.uid() IS NOT NULL
      AND public.can_view_activity(auth.uid(), a.user_id, p.activity_visibility)
    ORDER BY a.id, CASE WHEN t.id IS NULL THEN 1 ELSE 0 END, CASE WHEN a.tasting_id IS NOT NULL THEN 0 ELSE 1 END,
      ABS(EXTRACT(EPOCH FROM (COALESCE(t.created_at, a.created_at) - a.created_at)))
  ) sub
  ORDER BY created_at DESC
  LIMIT p_limit OFFSET p_offset;
$$;
GRANT EXECUTE ON FUNCTION public.feed_following(uuid, int, int) TO authenticated;

-- Cellar items: Had | Wishlist (separate from rankings/activity_feed)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.cellar_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  wine_id uuid NOT NULL REFERENCES public.wines(id) ON DELETE CASCADE,
  status text NOT NULL CHECK (status IN ('had', 'wishlist')),
  created_at timestamptz NOT NULL DEFAULT now(),
  consumed_at timestamptz NULL
);
ALTER TABLE public.cellar_items ADD COLUMN IF NOT EXISTS source_user_id uuid REFERENCES auth.users(id) ON DELETE SET NULL;
ALTER TABLE public.cellar_items ADD COLUMN IF NOT EXISTS source_context text NULL
  CHECK (source_context IS NULL OR source_context IN ('feed', 'profile', 'wishlist', 'search'));
CREATE INDEX IF NOT EXISTS idx_cellar_items_source_user
  ON public.cellar_items (user_id, source_user_id, created_at DESC)
  WHERE source_user_id IS NOT NULL;
CREATE UNIQUE INDEX IF NOT EXISTS idx_cellar_items_user_wine_status
  ON public.cellar_items (user_id, wine_id, status);
CREATE INDEX IF NOT EXISTS idx_cellar_items_user_status_created
  ON public.cellar_items (user_id, status, created_at DESC);
ALTER TABLE public.cellar_items ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "cellar_items_select_own" ON public.cellar_items;
DROP POLICY IF EXISTS "cellar_items_select_all" ON public.cellar_items;
DROP POLICY IF EXISTS "cellar_items_select_privacy" ON public.cellar_items;
CREATE POLICY "cellar_items_select_privacy" ON public.cellar_items FOR SELECT
  USING (
    auth.uid() = user_id
    OR EXISTS (
      SELECT 1 FROM public.profiles pr
      WHERE pr.id = cellar_items.user_id AND pr.deleted_at IS NULL
        AND (
          (cellar_items.status = 'had' AND public.can_view_cellar(auth.uid(), pr.id, pr.cellar_visibility))
          OR (cellar_items.status = 'wishlist' AND public.can_view_cellar(auth.uid(), pr.id, pr.wishlist_visibility))
        )
    )
  );
DROP POLICY IF EXISTS "cellar_items_insert_own" ON public.cellar_items;
CREATE POLICY "cellar_items_insert_own" ON public.cellar_items FOR INSERT WITH CHECK (auth.uid() = user_id);
DROP POLICY IF EXISTS "cellar_items_update_own" ON public.cellar_items;
CREATE POLICY "cellar_items_update_own" ON public.cellar_items FOR UPDATE USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
DROP POLICY IF EXISTS "cellar_items_delete_own" ON public.cellar_items;
CREATE POLICY "cellar_items_delete_own" ON public.cellar_items FOR DELETE USING (auth.uid() = user_id);

-- -----------------------------------------------------------------------------
-- Dev mock user RLS (auth bypass: no session, user_id = below UUID)
-- IMPORTANT: Replace the UUID below with YOUR OWN Supabase user UUID.
-- Each developer should use their own UUID from Supabase Dashboard → Auth → Users.
-- Remove these policies in production.
-- -----------------------------------------------------------------------------
DROP POLICY IF EXISTS "dev_mock_comparisons" ON public.comparisons;
CREATE POLICY "dev_mock_comparisons" ON public.comparisons
  FOR ALL
  USING (auth.uid() IS NULL AND user_id = '1edd4da3-ecd2-4c30-9f2f-ac7573a8fcba'::uuid)
  WITH CHECK (auth.uid() IS NULL AND user_id = '1edd4da3-ecd2-4c30-9f2f-ac7573a8fcba'::uuid);

DROP POLICY IF EXISTS "dev_mock_rankings" ON public.rankings;
CREATE POLICY "dev_mock_rankings" ON public.rankings
  FOR ALL
  USING (
    auth.uid() IS NULL
    AND user_id = '1edd4da3-ecd2-4c30-9f2f-ac7573a8fcba'::uuid
    AND EXISTS (SELECT 1 FROM public.app_config WHERE key = 'app_env' AND value IN ('local', 'staging'))
  )
  WITH CHECK (
    auth.uid() IS NULL
    AND user_id = '1edd4da3-ecd2-4c30-9f2f-ac7573a8fcba'::uuid
    AND EXISTS (SELECT 1 FROM public.app_config WHERE key = 'app_env' AND value IN ('local', 'staging'))
  );

DROP POLICY IF EXISTS "dev_mock_activity_insert" ON public.activity_feed;
CREATE POLICY "dev_mock_activity_insert" ON public.activity_feed
  FOR INSERT
  WITH CHECK (
    auth.uid() IS NULL
    AND user_id = '1edd4da3-ecd2-4c30-9f2f-ac7573a8fcba'::uuid
    AND EXISTS (SELECT 1 FROM public.app_config WHERE key = 'app_env' AND value IN ('local', 'staging'))
  );

DROP POLICY IF EXISTS "dev_mock_comments_cheers" ON public.comments_cheers;
CREATE POLICY "dev_mock_comments_cheers" ON public.comments_cheers
  FOR ALL
  USING (
    auth.uid() IS NULL
    AND user_id = '1edd4da3-ecd2-4c30-9f2f-ac7573a8fcba'::uuid
    AND EXISTS (SELECT 1 FROM public.app_config WHERE key = 'app_env' AND value IN ('local', 'staging'))
  )
  WITH CHECK (
    auth.uid() IS NULL
    AND user_id = '1edd4da3-ecd2-4c30-9f2f-ac7573a8fcba'::uuid
    AND EXISTS (SELECT 1 FROM public.app_config WHERE key = 'app_env' AND value IN ('local', 'staging'))
  );

DROP POLICY IF EXISTS "dev_mock_likes" ON public.likes;
CREATE POLICY "dev_mock_likes" ON public.likes
  FOR ALL
  USING (
    auth.uid() IS NULL
    AND user_id = '1edd4da3-ecd2-4c30-9f2f-ac7573a8fcba'::uuid
    AND EXISTS (SELECT 1 FROM public.app_config WHERE key = 'app_env' AND value IN ('local', 'staging'))
  )
  WITH CHECK (
    auth.uid() IS NULL
    AND user_id = '1edd4da3-ecd2-4c30-9f2f-ac7573a8fcba'::uuid
    AND EXISTS (SELECT 1 FROM public.app_config WHERE key = 'app_env' AND value IN ('local', 'staging'))
  );

DROP POLICY IF EXISTS "dev_mock_comments" ON public.comments;
CREATE POLICY "dev_mock_comments" ON public.comments
  FOR ALL
  USING (
    auth.uid() IS NULL
    AND user_id = '1edd4da3-ecd2-4c30-9f2f-ac7573a8fcba'::uuid
    AND EXISTS (SELECT 1 FROM public.app_config WHERE key = 'app_env' AND value IN ('local', 'staging'))
  )
  WITH CHECK (
    auth.uid() IS NULL
    AND user_id = '1edd4da3-ecd2-4c30-9f2f-ac7573a8fcba'::uuid
    AND EXISTS (SELECT 1 FROM public.app_config WHERE key = 'app_env' AND value IN ('local', 'staging'))
  );

DROP POLICY IF EXISTS "dev_mock_cellar_items" ON public.cellar_items;
CREATE POLICY "dev_mock_cellar_items" ON public.cellar_items
  FOR ALL
  USING (
    auth.uid() IS NULL
    AND user_id = '1edd4da3-ecd2-4c30-9f2f-ac7573a8fcba'::uuid
    AND EXISTS (SELECT 1 FROM public.app_config WHERE key = 'app_env' AND value IN ('local', 'staging'))
  )
  WITH CHECK (
    auth.uid() IS NULL
    AND user_id = '1edd4da3-ecd2-4c30-9f2f-ac7573a8fcba'::uuid
    AND EXISTS (SELECT 1 FROM public.app_config WHERE key = 'app_env' AND value IN ('local', 'staging'))
  );

DROP POLICY IF EXISTS "dev_mock_follows" ON public.follows;
CREATE POLICY "dev_mock_follows" ON public.follows
  FOR ALL
  USING (
    auth.uid() IS NULL
    AND follower_id = '1edd4da3-ecd2-4c30-9f2f-ac7573a8fcba'::uuid
    AND EXISTS (SELECT 1 FROM public.app_config WHERE key = 'app_env' AND value IN ('local', 'staging'))
  )
  WITH CHECK (
    auth.uid() IS NULL
    AND follower_id = '1edd4da3-ecd2-4c30-9f2f-ac7573a8fcba'::uuid
    AND EXISTS (SELECT 1 FROM public.app_config WHERE key = 'app_env' AND value IN ('local', 'staging'))
  );

-- -----------------------------------------------------------------------------
-- 6. RPC: duel_next_pair (Elo proximity, info gain, cooldown, no repeats)
-- All comparisons refs use alias "comp"; return via RETURN QUERY only.
-- -----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.duel_next_pair(uuid);

CREATE OR REPLACE FUNCTION public.duel_next_pair(p_user_id uuid)
RETURNS TABLE (
  wine_a_id uuid,
  wine_a_name text,
  wine_a_producer text,
  wine_a_vintage int,
  wine_a_region text,
  wine_a_label_url text,
  wine_a_is_new boolean,
  wine_b_id uuid,
  wine_b_name text,
  wine_b_producer text,
  wine_b_vintage int,
  wine_b_region text,
  wine_b_label_url text
)
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
  v_a_id uuid;
  v_a_name text;
  v_a_producer text;
  v_a_vintage int;
  v_a_region text;
  v_a_label text;
  v_a_cat text;
  v_a_elo double precision;
  v_a_n int;
  v_b_id uuid;
  v_b_name text;
  v_b_producer text;
  v_b_vintage int;
  v_b_region text;
  v_b_label text;
  v_is_new boolean := false;
  v_tau double precision;
  v_cooldown int := 20;
BEGIN
  WITH
  uws AS (
    SELECT w.id AS wid, COALESCE(r.elo_score, 1500.0) AS elo, COALESCE(cnt.n, 0) AS n
    FROM public.wines w
    LEFT JOIN public.rankings r ON r.wine_id = w.id AND r.user_id = p_user_id
    LEFT JOIN (
      SELECT vid AS wine_id, COUNT(*) AS n
      FROM (
        SELECT comp.wine_a_id AS vid FROM public.comparisons comp WHERE comp.user_id = p_user_id
        UNION ALL
        SELECT comp.wine_b_id AS vid FROM public.comparisons comp WHERE comp.user_id = p_user_id
      ) u
      GROUP BY vid
    ) cnt ON cnt.wine_id = w.id
  ),
  rw AS (
    SELECT DISTINCT sub.wine_id
    FROM (
      SELECT t.wine_id, t.created_at
      FROM (
        SELECT comp.wine_a_id AS wine_id, comp.created_at FROM public.comparisons comp WHERE comp.user_id = p_user_id
        UNION ALL
        SELECT comp.wine_b_id AS wine_id, comp.created_at FROM public.comparisons comp WHERE comp.user_id = p_user_id
      ) t
      ORDER BY t.created_at DESC
      LIMIT v_cooldown
    ) sub
  ),
  ac AS (
    SELECT DISTINCT LEAST(comp.wine_a_id, comp.wine_b_id) AS lo, GREATEST(comp.wine_a_id, comp.wine_b_id) AS hi
    FROM public.comparisons comp
    WHERE comp.user_id = p_user_id
  ),
  can_new AS (
    SELECT w.id, w.name, w.producer, w.vintage, w.region, w.label_image_url, w.category, u.elo, u.n, true AS is_new
    FROM public.wines w
    JOIN uws u ON u.wid = w.id
    WHERE u.n = 0
    ORDER BY w.created_at DESC NULLS LAST
    LIMIT 1
  ),
  can_unc AS (
    SELECT w.id, w.name, w.producer, w.vintage, w.region, w.label_image_url, w.category, u.elo, u.n, false AS is_new
    FROM public.wines w
    JOIN uws u ON u.wid = w.id
    WHERE u.n > 0
    ORDER BY u.n ASC, random()
    LIMIT 1
  ),
  sel_a AS (SELECT * FROM can_new UNION ALL SELECT * FROM can_unc LIMIT 1)
  SELECT s.id, s.name, s.producer, s.vintage, s.region, s.label_image_url, s.category, s.elo, s.n, s.is_new
  INTO v_a_id, v_a_name, v_a_producer, v_a_vintage, v_a_region, v_a_label, v_a_cat, v_a_elo, v_a_n, v_is_new
  FROM sel_a s;

  IF v_a_id IS NULL THEN
    WITH fa AS (
      SELECT w.id, w.name, w.producer, w.vintage, w.region, w.label_image_url, w.category,
             COALESCE(r.elo_score, 1500.0) AS elo, 0 AS n
      FROM public.wines w
      LEFT JOIN public.rankings r ON r.wine_id = w.id AND r.user_id = p_user_id
      ORDER BY random()
      LIMIT 1
    )
    SELECT f.id, f.name, f.producer, f.vintage, f.region, f.label_image_url, f.category, f.elo, f.n
    INTO v_a_id, v_a_name, v_a_producer, v_a_vintage, v_a_region, v_a_label, v_a_cat, v_a_elo, v_a_n
    FROM fa f;
    v_is_new := false;
  END IF;

  IF v_a_n = 0 THEN v_tau := 200.0; ELSIF v_a_n > 10 THEN v_tau := 100.0; ELSE v_tau := 120.0; END IF;

  WITH
  uws2 AS (
    SELECT w.id AS wid, COALESCE(r.elo_score, 1500.0) AS elo, COALESCE(cnt.n, 0) AS n
    FROM public.wines w
    LEFT JOIN public.rankings r ON r.wine_id = w.id AND r.user_id = p_user_id
    LEFT JOIN (
      SELECT vid AS wine_id, COUNT(*) AS n
      FROM (SELECT comp.wine_a_id AS vid FROM public.comparisons comp WHERE comp.user_id = p_user_id UNION ALL SELECT comp.wine_b_id AS vid FROM public.comparisons comp WHERE comp.user_id = p_user_id) u
      GROUP BY vid
    ) cnt ON cnt.wine_id = w.id
  ),
  rw2 AS (
    SELECT DISTINCT sub.wine_id
    FROM (
      SELECT t.wine_id, t.created_at
      FROM (SELECT comp.wine_a_id AS wine_id, comp.created_at FROM public.comparisons comp WHERE comp.user_id = p_user_id UNION ALL SELECT comp.wine_b_id AS wine_id, comp.created_at FROM public.comparisons comp WHERE comp.user_id = p_user_id) t
      ORDER BY t.created_at DESC
      LIMIT v_cooldown
    ) sub
  ),
  ac2 AS (
    SELECT DISTINCT LEAST(comp.wine_a_id, comp.wine_b_id) AS lo, GREATEST(comp.wine_a_id, comp.wine_b_id) AS hi
    FROM public.comparisons comp WHERE comp.user_id = p_user_id
  ),
  cb AS (
    SELECT w.id AS wbid, w.name AS wbname, w.producer AS wbprod, w.vintage AS wbvin, w.region AS wbreg, w.label_image_url AS wblab,
           u.elo AS elob, u.n AS nb,
           EXP(-ABS(v_a_elo - u.elo) / v_tau) AS elo_close,
           (1.0 / SQRT(1.0 + u.n)) AS infogain,
           CASE WHEN rw2.wine_id IS NOT NULL THEN 1.0 ELSE 0.0 END AS cooldown
    FROM public.wines w
    JOIN uws2 u ON u.wid = w.id
    LEFT JOIN rw2 ON rw2.wine_id = w.id
    LEFT JOIN ac2 ON ac2.lo = LEAST(v_a_id, w.id) AND ac2.hi = GREATEST(v_a_id, w.id)
    WHERE w.id <> v_a_id AND (w.category IS NOT DISTINCT FROM v_a_cat) AND ac2.lo IS NULL AND ABS(v_a_elo - u.elo) <= 400.0
  ),
  sb AS (SELECT wbid, wbname, wbprod, wbvin, wbreg, wblab, (0.70 * elo_close + 0.30 * infogain - 1.00 * cooldown) AS sc FROM cb)
  SELECT sb.wbid, sb.wbname, sb.wbprod, sb.wbvin, sb.wbreg, sb.wblab
  INTO v_b_id, v_b_name, v_b_producer, v_b_vintage, v_b_region, v_b_label
  FROM sb ORDER BY sb.sc DESC LIMIT 1;

  IF v_b_id IS NULL THEN
    WITH
    uws3 AS (
      SELECT w.id AS wid, COALESCE(r.elo_score, 1500.0) AS elo, COALESCE(cnt.n, 0) AS n
      FROM public.wines w
      LEFT JOIN public.rankings r ON r.wine_id = w.id AND r.user_id = p_user_id
      LEFT JOIN (SELECT vid AS wine_id, COUNT(*) AS n FROM (SELECT comp.wine_a_id AS vid FROM public.comparisons comp WHERE comp.user_id = p_user_id UNION ALL SELECT comp.wine_b_id AS vid FROM public.comparisons comp WHERE comp.user_id = p_user_id) u GROUP BY vid) cnt ON cnt.wine_id = w.id
    ),
    rw3 AS (
      SELECT DISTINCT sub.wine_id FROM (SELECT t.wine_id, t.created_at FROM (SELECT comp.wine_a_id AS wine_id, comp.created_at FROM public.comparisons comp WHERE comp.user_id = p_user_id UNION ALL SELECT comp.wine_b_id AS wine_id, comp.created_at FROM public.comparisons comp WHERE comp.user_id = p_user_id) t ORDER BY t.created_at DESC LIMIT v_cooldown) sub
    ),
    ac3 AS (SELECT DISTINCT LEAST(comp.wine_a_id, comp.wine_b_id) AS lo, GREATEST(comp.wine_a_id, comp.wine_b_id) AS hi FROM public.comparisons comp WHERE comp.user_id = p_user_id),
    cb3 AS (
      SELECT w.id AS wbid, w.name AS wbname, w.producer AS wbprod, w.vintage AS wbvin, w.region AS wbreg, w.label_image_url AS wblab, u.elo AS elob, u.n AS nb,
             EXP(-ABS(v_a_elo - u.elo) / v_tau) AS elo_close, (1.0 / SQRT(1.0 + u.n)) AS infogain, CASE WHEN rw3.wine_id IS NOT NULL THEN 0.5 ELSE 0.0 END AS cooldown
      FROM public.wines w JOIN uws3 u ON u.wid = w.id
      LEFT JOIN rw3 ON rw3.wine_id = w.id
      LEFT JOIN ac3 ON ac3.lo = LEAST(v_a_id, w.id) AND ac3.hi = GREATEST(v_a_id, w.id)
      WHERE w.id <> v_a_id AND (w.category IS NOT DISTINCT FROM v_a_cat) AND ac3.lo IS NULL AND ABS(v_a_elo - u.elo) <= 400.0
    ),
    sb3 AS (SELECT wbid, wbname, wbprod, wbvin, wbreg, wblab, (0.70 * elo_close + 0.30 * infogain - 0.50 * cooldown) AS sc FROM cb3)
    SELECT sb3.wbid, sb3.wbname, sb3.wbprod, sb3.wbvin, sb3.wbreg, sb3.wblab INTO v_b_id, v_b_name, v_b_producer, v_b_vintage, v_b_region, v_b_label
    FROM sb3 ORDER BY sb3.sc DESC LIMIT 1;
  END IF;

  IF v_b_id IS NULL THEN
    WITH
    ac30 AS (SELECT DISTINCT LEAST(comp.wine_a_id, comp.wine_b_id) AS lo, GREATEST(comp.wine_a_id, comp.wine_b_id) AS hi FROM public.comparisons comp WHERE comp.user_id = p_user_id AND comp.created_at >= NOW() - INTERVAL '30 days'),
    uws4 AS (
      SELECT w.id AS wid, COALESCE(r.elo_score, 1500.0) AS elo, COALESCE(cnt.n, 0) AS n
      FROM public.wines w
      LEFT JOIN public.rankings r ON r.wine_id = w.id AND r.user_id = p_user_id
      LEFT JOIN (SELECT vid AS wine_id, COUNT(*) AS n FROM (SELECT comp.wine_a_id AS vid FROM public.comparisons comp WHERE comp.user_id = p_user_id UNION ALL SELECT comp.wine_b_id AS vid FROM public.comparisons comp WHERE comp.user_id = p_user_id) u GROUP BY vid) cnt ON cnt.wine_id = w.id
    ),
    rw4 AS (SELECT DISTINCT sub.wine_id FROM (SELECT t.wine_id, t.created_at FROM (SELECT comp.wine_a_id AS wine_id, comp.created_at FROM public.comparisons comp WHERE comp.user_id = p_user_id UNION ALL SELECT comp.wine_b_id AS wine_id, comp.created_at FROM public.comparisons comp WHERE comp.user_id = p_user_id) t ORDER BY t.created_at DESC LIMIT v_cooldown) sub),
    cb4 AS (
      SELECT w.id AS wbid, w.name AS wbname, w.producer AS wbprod, w.vintage AS wbvin, w.region AS wbreg, w.label_image_url AS wblab, u.elo AS elob, u.n AS nb,
             EXP(-ABS(v_a_elo - u.elo) / v_tau) AS elo_close, (1.0 / SQRT(1.0 + u.n)) AS infogain, CASE WHEN rw4.wine_id IS NOT NULL THEN 0.5 ELSE 0.0 END AS cooldown
      FROM public.wines w JOIN uws4 u ON u.wid = w.id
      LEFT JOIN rw4 ON rw4.wine_id = w.id
      LEFT JOIN ac30 ON ac30.lo = LEAST(v_a_id, w.id) AND ac30.hi = GREATEST(v_a_id, w.id)
      WHERE w.id <> v_a_id AND (w.category IS NOT DISTINCT FROM v_a_cat) AND ac30.lo IS NULL AND ABS(v_a_elo - u.elo) <= 400.0
    ),
    sb4 AS (SELECT wbid, wbname, wbprod, wbvin, wbreg, wblab, (0.70 * elo_close + 0.30 * infogain - 0.50 * cooldown) AS sc FROM cb4)
    SELECT sb4.wbid, sb4.wbname, sb4.wbprod, sb4.wbvin, sb4.wbreg, sb4.wblab INTO v_b_id, v_b_name, v_b_producer, v_b_vintage, v_b_region, v_b_label
    FROM sb4 ORDER BY sb4.sc DESC LIMIT 1;
  END IF;

  IF v_b_id IS NULL THEN
    SELECT w.id, w.name, w.producer, w.vintage, w.region, w.label_image_url
    INTO v_b_id, v_b_name, v_b_producer, v_b_vintage, v_b_region, v_b_label
    FROM public.wines w
    WHERE w.id <> v_a_id AND (w.category IS NOT DISTINCT FROM v_a_cat)
    ORDER BY random()
    LIMIT 1;
  END IF;

  IF v_a_id IS NULL OR v_b_id IS NULL THEN RETURN; END IF;

  RETURN QUERY SELECT
    v_a_id, v_a_name, v_a_producer, v_a_vintage, v_a_region, v_a_label, v_is_new,
    v_b_id, v_b_name, v_b_producer, v_b_vintage, v_b_region, v_b_label;
END;
$$;

-- -----------------------------------------------------------------------------
-- 7. RPC: upsert_wine_from_off (OFF add-wine flow)
-- -----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.upsert_wine_from_off(text, text, text, text, text);
DROP FUNCTION IF EXISTS public.upsert_wine_from_off(text, text, text, text, text, text);
CREATE OR REPLACE FUNCTION public.upsert_wine_from_off(
  p_off_code text,
  p_name text,
  p_producer text,
  p_region text DEFAULT NULL,
  p_label_url text DEFAULT NULL,
  p_category text DEFAULT NULL
)
RETURNS TABLE (id uuid, name text, producer text, vintage int, variety text, region text, label_image_url text, category text)
LANGUAGE plpgsql
AS $$
BEGIN
  INSERT INTO public.wines (off_code, name, producer, region, label_image_url, category)
  VALUES (p_off_code, p_name, p_producer, NULLIF(trim(p_region), ''), NULLIF(trim(p_label_url), ''), NULLIF(trim(p_category), ''))
  ON CONFLICT (off_code) WHERE (off_code IS NOT NULL)
  DO UPDATE SET
    name = EXCLUDED.name,
    producer = EXCLUDED.producer,
    region = COALESCE(NULLIF(trim(EXCLUDED.region), ''), wines.region),
    label_image_url = COALESCE(NULLIF(trim(EXCLUDED.label_image_url), ''), wines.label_image_url),
    category = COALESCE(NULLIF(trim(EXCLUDED.category), ''), wines.category);
  RETURN QUERY
  SELECT w.id, w.name, w.producer, w.vintage, w.variety, w.region, w.label_image_url, w.category
  FROM public.wines w
  WHERE w.off_code = p_off_code;
END;
$$;

-- -----------------------------------------------------------------------------
-- 8. Storage: avatars bucket (public, for profile pictures)
-- Create in Dashboard → Storage if not exists. Then add policies below.
-- -----------------------------------------------------------------------------
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'avatars',
  'avatars',
  true,
  2097152,
  ARRAY['image/jpeg', 'image/png', 'image/webp']::text[]
)
ON CONFLICT (id) DO UPDATE SET
  public = EXCLUDED.public,
  file_size_limit = EXCLUDED.file_size_limit,
  allowed_mime_types = EXCLUDED.allowed_mime_types;

-- Moment images bucket (wine night photos, feed only)
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'moment_images',
  'moment_images',
  true,
  5242880,
  ARRAY['image/jpeg', 'image/png', 'image/heic']::text[]
)
ON CONFLICT (id) DO UPDATE SET
  public = EXCLUDED.public,
  file_size_limit = EXCLUDED.file_size_limit,
  allowed_mime_types = EXCLUDED.allowed_mime_types;

DROP POLICY IF EXISTS "Moment images are publicly readable" ON storage.objects;
CREATE POLICY "Moment images are publicly readable"
  ON storage.objects FOR SELECT USING (bucket_id = 'moment_images');

DROP POLICY IF EXISTS "Users can upload own moment images" ON storage.objects;
CREATE POLICY "Users can upload own moment images"
  ON storage.objects FOR INSERT WITH CHECK (bucket_id = 'moment_images' AND auth.uid()::text = (storage.foldername(name))[1]);

DROP POLICY IF EXISTS "Avatar images are publicly accessible" ON storage.objects;
CREATE POLICY "Avatar images are publicly accessible"
  ON storage.objects FOR SELECT USING (bucket_id = 'avatars');

DROP POLICY IF EXISTS "Users can upload own avatar" ON storage.objects;
DROP POLICY IF EXISTS "Users can update own avatar" ON storage.objects;
DROP POLICY IF EXISTS "Users can delete own avatar" ON storage.objects;
DROP POLICY IF EXISTS "dev_mock_avatar_insert" ON storage.objects;
DROP POLICY IF EXISTS "dev_mock_avatar_update" ON storage.objects;
DROP POLICY IF EXISTS "dev_mock_avatar_delete" ON storage.objects;
DROP POLICY IF EXISTS "avatars_insert" ON storage.objects;
DROP POLICY IF EXISTS "avatars_update" ON storage.objects;
DROP POLICY IF EXISTS "avatars_delete" ON storage.objects;

-- Avatars: permissive INSERT/UPDATE/DELETE (bucket only). Fixes "new row violates RLS" on upload.
-- Upsert needs INSERT + UPDATE; overwrite flow may use DELETE. No folder/auth checks.
CREATE POLICY "avatars_insert" ON storage.objects FOR INSERT
  WITH CHECK (bucket_id = 'avatars');

CREATE POLICY "avatars_update" ON storage.objects FOR UPDATE
  USING (bucket_id = 'avatars');

CREATE POLICY "avatars_delete" ON storage.objects FOR DELETE
  USING (bucket_id = 'avatars');

-- -----------------------------------------------------------------------------
-- 9. Onboarding: user_private (phone_e164), check_username_available
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.user_private (
  user_id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  phone_e164 text NOT NULL,
  created_at timestamptz DEFAULT now()
);

ALTER TABLE public.user_private ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "user_private_select_own" ON public.user_private;
CREATE POLICY "user_private_select_own" ON public.user_private
  FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "user_private_insert_own" ON public.user_private;
CREATE POLICY "user_private_insert_own" ON public.user_private
  FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "user_private_update_own" ON public.user_private;
CREATE POLICY "user_private_update_own" ON public.user_private
  FOR UPDATE USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "dev_user_private_insert" ON public.user_private;
CREATE POLICY "dev_user_private_insert" ON public.user_private
  FOR INSERT WITH CHECK (
    auth.uid() IS NULL AND user_id = '1edd4da3-ecd2-4c30-9f2f-ac7573a8fcba'::uuid
  );

DROP POLICY IF EXISTS "dev_user_private_update" ON public.user_private;
CREATE POLICY "dev_user_private_update" ON public.user_private
  FOR UPDATE USING (
    auth.uid() IS NULL AND user_id = '1edd4da3-ecd2-4c30-9f2f-ac7573a8fcba'::uuid
  )
  WITH CHECK (
    auth.uid() IS NULL AND user_id = '1edd4da3-ecd2-4c30-9f2f-ac7573a8fcba'::uuid
  );

CREATE OR REPLACE FUNCTION public.check_username_available(p_username text)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT NOT EXISTS (
    SELECT 1 FROM public.profiles
    WHERE lower(trim(username)) = lower(trim(nullif(p_username, '')))
  );
$$;

COMMENT ON FUNCTION public.check_username_available(text) IS
  'Returns true if username is available (case-insensitive). Used by onboarding.';

GRANT EXECUTE ON FUNCTION public.check_username_available(text) TO anon;
GRANT EXECUTE ON FUNCTION public.check_username_available(text) TO authenticated;

-- -----------------------------------------------------------------------------
-- Ensure ON DELETE CASCADE on auth FKs + remove any persisted "Guest" profiles
-- (Re-running setup_schema fixes DBs that had FKs without CASCADE.)
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
ALTER TABLE public.cellar_items   DROP CONSTRAINT IF EXISTS cellar_items_user_id_fkey;
ALTER TABLE public.tastings       DROP CONSTRAINT IF EXISTS tastings_user_id_fkey;

-- Note: Many tables already have REFERENCES in CREATE TABLE, which auto-creates constraints.
-- These ALTER TABLE statements ensure named constraints exist (for consistency and explicit drops).
-- DROP IF EXISTS prevents "already exists" errors on re-runs.
ALTER TABLE public.profiles
  DROP CONSTRAINT IF EXISTS profiles_id_fkey;
ALTER TABLE public.profiles
  ADD CONSTRAINT profiles_id_fkey
  FOREIGN KEY (id) REFERENCES auth.users(id) ON DELETE CASCADE;

ALTER TABLE public.comparisons
  DROP CONSTRAINT IF EXISTS comparisons_user_id_fkey;
ALTER TABLE public.comparisons
  ADD CONSTRAINT comparisons_user_id_fkey
  FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;

ALTER TABLE public.rankings
  DROP CONSTRAINT IF EXISTS rankings_user_id_fkey;
ALTER TABLE public.rankings
  ADD CONSTRAINT rankings_user_id_fkey
  FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;

ALTER TABLE public.follows
  DROP CONSTRAINT IF EXISTS follows_follower_id_fkey;
ALTER TABLE public.follows
  ADD CONSTRAINT follows_follower_id_fkey
  FOREIGN KEY (follower_id) REFERENCES auth.users(id) ON DELETE CASCADE;

ALTER TABLE public.follows
  DROP CONSTRAINT IF EXISTS follows_followed_id_fkey;
ALTER TABLE public.follows
  ADD CONSTRAINT follows_followed_id_fkey
  FOREIGN KEY (followed_id) REFERENCES auth.users(id) ON DELETE CASCADE;

ALTER TABLE public.activity_feed
  DROP CONSTRAINT IF EXISTS activity_feed_user_id_fkey;
ALTER TABLE public.activity_feed
  ADD CONSTRAINT activity_feed_user_id_fkey
  FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;

ALTER TABLE public.comments_cheers
  DROP CONSTRAINT IF EXISTS comments_cheers_user_id_fkey;
ALTER TABLE public.comments_cheers
  ADD CONSTRAINT comments_cheers_user_id_fkey
  FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;

ALTER TABLE public.likes
  DROP CONSTRAINT IF EXISTS likes_user_id_fkey;
ALTER TABLE public.likes
  ADD CONSTRAINT likes_user_id_fkey
  FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;

ALTER TABLE public.comments
  DROP CONSTRAINT IF EXISTS comments_user_id_fkey;
ALTER TABLE public.comments
  ADD CONSTRAINT comments_user_id_fkey
  FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;

ALTER TABLE public.user_private
  DROP CONSTRAINT IF EXISTS user_private_user_id_fkey;
ALTER TABLE public.user_private
  ADD CONSTRAINT user_private_user_id_fkey
  FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;

ALTER TABLE public.cellar_items
  DROP CONSTRAINT IF EXISTS cellar_items_user_id_fkey;
ALTER TABLE public.cellar_items
  ADD CONSTRAINT cellar_items_user_id_fkey
  FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;

ALTER TABLE public.tastings
  DROP CONSTRAINT IF EXISTS tastings_user_id_fkey;
ALTER TABLE public.tastings
  ADD CONSTRAINT tastings_user_id_fkey
  FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;

DELETE FROM public.profiles WHERE lower(trim(username)) = 'guest';

-- -----------------------------------------------------------------------------
-- Dev mock user check: ensure debugMockUserId exists in auth.users
-- If this fails, manually create the user in Supabase Dashboard → Auth → Users
-- with UUID: 1edd4da3-ecd2-4c30-9f2f-ac7573a8fcba
-- -----------------------------------------------------------------------------
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM auth.users WHERE id = '1edd4da3-ecd2-4c30-9f2f-ac7573a8fcba'::uuid) THEN
        RAISE WARNING 'Dev mock user (1edd4da3-ecd2-4c30-9f2f-ac7573a8fcba) does not exist in auth.users. Create it manually in Supabase Dashboard → Auth → Users, or foreign key constraints will fail.';
    END IF;
END $$;

-- -----------------------------------------------------------------------------
-- 10. Dev signup: dev_accounts (no Supabase Auth, no email/SMS)
-- A8: RLS enabled, deny-all. Bypass only when app_env in ('local','staging').
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.dev_accounts (
  id uuid PRIMARY KEY,
  email text,
  phone_e164 text,
  full_name text,
  username text,
  created_at timestamptz DEFAULT now()
);

ALTER TABLE public.dev_accounts ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "dev_accounts_deny_all" ON public.dev_accounts;
CREATE POLICY "dev_accounts_deny_all" ON public.dev_accounts FOR ALL USING (false) WITH CHECK (false);
DROP POLICY IF EXISTS "dev_accounts_local_bypass" ON public.dev_accounts;
CREATE POLICY "dev_accounts_local_bypass" ON public.dev_accounts FOR ALL
  USING (auth.uid() IS NULL AND EXISTS (SELECT 1 FROM public.app_config WHERE key = 'app_env' AND value IN ('local', 'staging')))
  WITH CHECK (auth.uid() IS NULL AND EXISTS (SELECT 1 FROM public.app_config WHERE key = 'app_env' AND value IN ('local', 'staging')));

-- -----------------------------------------------------------------------------
-- 11. User account deletion (A4: soft delete + audit)
-- Sets deleted_at on profile (hides from feeds, RLS excludes). Hard delete later via scheduled job.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.delete_current_user()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  UPDATE public.profiles SET deleted_at = now() WHERE id = v_user_id;
  PERFORM public.audit_log_insert(v_user_id, 'account_deleted_requested', '{}'::jsonb);
END;
$$;

GRANT EXECUTE ON FUNCTION public.delete_current_user() TO authenticated;

COMMENT ON FUNCTION public.delete_current_user() IS 'Soft delete: sets profiles.deleted_at, logs audit. Hard delete from auth.users after cooldown via scheduled job.';

-- -----------------------------------------------------------------------------
-- 12. Taste Twin Engine: taste_similarity cache + RPCs
-- (pulled from claude/interesting-poitras branch)
-- -----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.taste_similarity (
  user_a uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  user_b uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  score  double precision NOT NULL DEFAULT 0,
  shared_count int NOT NULL DEFAULT 0,
  computed_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_a, user_b),
  CONSTRAINT taste_similarity_canonical CHECK (user_a < user_b)
);

CREATE INDEX IF NOT EXISTS idx_taste_similarity_user_a ON public.taste_similarity (user_a);
CREATE INDEX IF NOT EXISTS idx_taste_similarity_user_b ON public.taste_similarity (user_b);

ALTER TABLE public.taste_similarity ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "taste_similarity_select_auth" ON public.taste_similarity;
CREATE POLICY "taste_similarity_select_auth" ON public.taste_similarity
  FOR SELECT USING (auth.uid() = user_a OR auth.uid() = user_b);

DROP FUNCTION IF EXISTS public.compute_taste_similarity(uuid, uuid);
CREATE OR REPLACE FUNCTION public.compute_taste_similarity(
  p_user_a uuid,
  p_user_b uuid
)
RETURNS TABLE (
  user_a uuid,
  user_b uuid,
  score double precision,
  shared_count int,
  computed_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_a uuid;
  v_b uuid;
  v_score double precision;
  v_shared int;
  v_computed timestamptz;
BEGIN
  -- Hardening: only allow caller to compute similarities that involve themselves.
  IF auth.uid() IS NULL OR (auth.uid() <> p_user_a AND auth.uid() <> p_user_b) THEN
    RAISE EXCEPTION 'Not allowed';
  END IF;

  IF p_user_a < p_user_b THEN
    v_a := p_user_a; v_b := p_user_b;
  ELSE
    v_a := p_user_b; v_b := p_user_a;
  END IF;

  SELECT ts.score, ts.shared_count, ts.computed_at
  INTO v_score, v_shared, v_computed
  FROM public.taste_similarity ts
  WHERE ts.user_a = v_a AND ts.user_b = v_b
    AND ts.computed_at > now() - interval '7 days';

  IF FOUND THEN
    RETURN QUERY SELECT v_a, v_b, v_score, v_shared, v_computed;
    RETURN;
  END IF;

  SELECT
    CASE WHEN COUNT(*) < 5 THEN NULL
         WHEN STDDEV(ta_r) = 0 OR STDDEV(tb_r) = 0 THEN 0.0
         ELSE CORR(ta_r, tb_r) * (COUNT(*)::double precision / (COUNT(*) + 10.0))
    END,
    COUNT(*)::int
  INTO v_score, v_shared
  FROM (
    SELECT ta.rating AS ta_r, tb.rating AS tb_r
    FROM public.tastings ta
    JOIN public.tastings tb ON ta.wine_id = tb.wine_id
    WHERE ta.user_id = v_a AND tb.user_id = v_b
  ) shared;

  IF v_score IS NULL OR v_shared < 5 THEN
    DELETE FROM public.taste_similarity WHERE taste_similarity.user_a = v_a AND taste_similarity.user_b = v_b;
    RETURN;
  END IF;

  v_score := GREATEST(0.0, LEAST(1.0, v_score));
  v_computed := now();

  INSERT INTO public.taste_similarity (user_a, user_b, score, shared_count, computed_at)
  VALUES (v_a, v_b, v_score, v_shared, v_computed)
  ON CONFLICT (user_a, user_b) DO UPDATE SET
    score = EXCLUDED.score,
    shared_count = EXCLUDED.shared_count,
    computed_at = EXCLUDED.computed_at;

  RETURN QUERY SELECT v_a, v_b, v_score, v_shared, v_computed;
END;
$$;

GRANT EXECUTE ON FUNCTION public.compute_taste_similarity(uuid, uuid) TO authenticated;

DROP FUNCTION IF EXISTS public.get_taste_twins(uuid, int);
CREATE OR REPLACE FUNCTION public.get_taste_twins(
  p_user_id uuid,
  p_limit int DEFAULT 20
)
RETURNS TABLE (
  twin_id uuid,
  username text,
  full_name text,
  avatar_url text,
  score double precision,
  shared_count int,
  computed_at timestamptz
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT
    CASE WHEN ts.user_a = auth.uid() THEN ts.user_b ELSE ts.user_a END AS twin_id,
    p.username,
    p.full_name,
    p.avatar_url,
    ts.score,
    ts.shared_count,
    ts.computed_at
  FROM public.taste_similarity ts
  JOIN public.profiles p
    ON p.id = CASE WHEN ts.user_a = auth.uid() THEN ts.user_b ELSE ts.user_a END
  WHERE auth.uid() IS NOT NULL
    AND (ts.user_a = auth.uid() OR ts.user_b = auth.uid())
    AND ts.score >= 0.30
    AND p.deleted_at IS NULL
  ORDER BY ts.score DESC
  LIMIT p_limit;
$$;

GRANT EXECUTE ON FUNCTION public.get_taste_twins(uuid, int) TO authenticated;

-- -----------------------------------------------------------------------------
-- 13. Support tickets (Vitis Concierge — in-app contact, no third-party SDKs)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.support_tickets (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  email text NOT NULL,
  subject text NOT NULL,
  message text NOT NULL,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'in_progress', 'resolved')),
  created_at timestamptz NOT NULL DEFAULT timezone('utc'::text, now())
);
CREATE INDEX IF NOT EXISTS idx_support_tickets_user ON public.support_tickets (user_id);
CREATE INDEX IF NOT EXISTS idx_support_tickets_created ON public.support_tickets (created_at DESC);
ALTER TABLE public.support_tickets ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users can insert their own support tickets" ON public.support_tickets;
CREATE POLICY "Users can insert their own support tickets" ON public.support_tickets FOR INSERT WITH CHECK (auth.uid() = user_id);
DROP POLICY IF EXISTS "Users can read own support tickets" ON public.support_tickets;
CREATE POLICY "Users can read own support tickets" ON public.support_tickets FOR SELECT USING (auth.uid() = user_id);

-- -----------------------------------------------------------------------------
-- 12. Taste Twin Engine: taste_similarity cache + RPCs
-- Bayesian-shrunk Pearson correlation on shared wine ratings.
-- Formula: score = CORR(ra, rb) * (n / (n + 10.0))
-- Minimum 5 shared wines to compute. Cache TTL = 7 days.
-- -----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.taste_similarity (
  user_a uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  user_b uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  score  double precision NOT NULL DEFAULT 0,
  shared_count int NOT NULL DEFAULT 0,
  computed_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_a, user_b),
  CONSTRAINT taste_similarity_canonical CHECK (user_a < user_b)
);

CREATE INDEX IF NOT EXISTS idx_taste_similarity_user_a ON public.taste_similarity (user_a);
CREATE INDEX IF NOT EXISTS idx_taste_similarity_user_b ON public.taste_similarity (user_b);

ALTER TABLE public.taste_similarity ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "taste_similarity_select_auth" ON public.taste_similarity;
CREATE POLICY "taste_similarity_select_auth" ON public.taste_similarity
  FOR SELECT USING (auth.uid() = user_a OR auth.uid() = user_b);

-- RPC: compute_taste_similarity
-- Computes (or returns cached) Bayesian-shrunk Pearson correlation between two users.
-- Cache TTL: 7 days. Minimum 5 shared wines to produce a result.
-- Returns 0 rows if insufficient shared wines.
DROP FUNCTION IF EXISTS public.compute_taste_similarity(uuid, uuid);
CREATE OR REPLACE FUNCTION public.compute_taste_similarity(
  p_user_a uuid,
  p_user_b uuid
)
RETURNS TABLE (
  user_a uuid,
  user_b uuid,
  score double precision,
  shared_count int,
  computed_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_a uuid;
  v_b uuid;
  v_score double precision;
  v_shared int;
  v_computed timestamptz;
BEGIN
  -- Canonical ordering: smaller UUID first
  IF p_user_a < p_user_b THEN
    v_a := p_user_a; v_b := p_user_b;
  ELSE
    v_a := p_user_b; v_b := p_user_a;
  END IF;

  -- Check cache (7-day TTL)
  SELECT ts.score, ts.shared_count, ts.computed_at
  INTO v_score, v_shared, v_computed
  FROM public.taste_similarity ts
  WHERE ts.user_a = v_a AND ts.user_b = v_b
    AND ts.computed_at > now() - interval '7 days';

  IF FOUND THEN
    RETURN QUERY SELECT v_a, v_b, v_score, v_shared, v_computed;
    RETURN;
  END IF;

  -- Compute: Bayesian-shrunk Pearson on shared wine ratings
  SELECT
    CASE WHEN COUNT(*) < 5 THEN NULL
         WHEN STDDEV(ta_r) = 0 OR STDDEV(tb_r) = 0 THEN 0.0
         ELSE CORR(ta_r, tb_r) * (COUNT(*)::double precision / (COUNT(*) + 10.0))
    END,
    COUNT(*)::int
  INTO v_score, v_shared
  FROM (
    SELECT ta.rating AS ta_r, tb.rating AS tb_r
    FROM public.tastings ta
    JOIN public.tastings tb ON ta.wine_id = tb.wine_id
    WHERE ta.user_id = v_a AND tb.user_id = v_b
  ) shared;

  -- If fewer than 5 shared wines, return nothing
  IF v_score IS NULL OR v_shared < 5 THEN
    -- Delete stale cache entry if exists
    DELETE FROM public.taste_similarity WHERE taste_similarity.user_a = v_a AND taste_similarity.user_b = v_b;
    RETURN;
  END IF;

  -- Clamp to [0, 1]
  v_score := GREATEST(0.0, LEAST(1.0, v_score));
  v_computed := now();

  -- Upsert cache
  INSERT INTO public.taste_similarity (user_a, user_b, score, shared_count, computed_at)
  VALUES (v_a, v_b, v_score, v_shared, v_computed)
  ON CONFLICT (user_a, user_b) DO UPDATE SET
    score = EXCLUDED.score,
    shared_count = EXCLUDED.shared_count,
    computed_at = EXCLUDED.computed_at;

  RETURN QUERY SELECT v_a, v_b, v_score, v_shared, v_computed;
END;
$$;

GRANT EXECUTE ON FUNCTION public.compute_taste_similarity(uuid, uuid) TO authenticated;

-- RPC: get_taste_twins
-- Returns top N taste twins for a user (by score desc), joining profile data.
-- Only returns cached similarities with score >= 0.30.
DROP FUNCTION IF EXISTS public.get_taste_twins(uuid, int);
CREATE OR REPLACE FUNCTION public.get_taste_twins(
  p_user_id uuid,
  p_limit int DEFAULT 20
)
RETURNS TABLE (
  twin_id uuid,
  username text,
  full_name text,
  avatar_url text,
  score double precision,
  shared_count int,
  computed_at timestamptz
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT
    CASE WHEN ts.user_a = p_user_id THEN ts.user_b ELSE ts.user_a END AS twin_id,
    p.username,
    p.full_name,
    p.avatar_url,
    ts.score,
    ts.shared_count,
    ts.computed_at
  FROM public.taste_similarity ts
  JOIN public.profiles p
    ON p.id = CASE WHEN ts.user_a = p_user_id THEN ts.user_b ELSE ts.user_a END
  WHERE (ts.user_a = p_user_id OR ts.user_b = p_user_id)
    AND ts.score >= 0.30
    AND p.deleted_at IS NULL
  ORDER BY ts.score DESC
  LIMIT p_limit;
$$;

GRANT EXECUTE ON FUNCTION public.get_taste_twins(uuid, int) TO authenticated;

-- ────────────────────────────────────────────────
-- RPC: upsert_wine_from_scan (label scan add-wine flow)
-- Matches on case-insensitive name+producer. No off_code required.
-- If found: enriches null fields (vintage, variety, region, category) from scan.
-- If not found: inserts a new wine row.
-- ────────────────────────────────────────────────
DROP FUNCTION IF EXISTS public.upsert_wine_from_scan(text, text, int, text, text, text);
CREATE OR REPLACE FUNCTION public.upsert_wine_from_scan(
  p_name text,
  p_producer text,
  p_vintage int DEFAULT NULL,
  p_variety text DEFAULT NULL,
  p_region text DEFAULT NULL,
  p_category text DEFAULT NULL
)
RETURNS TABLE (id uuid, name text, producer text, vintage int, variety text,
               region text, label_image_url text, category text)
LANGUAGE plpgsql
AS $$
DECLARE
  v_existing_id uuid;
BEGIN
  SELECT w.id INTO v_existing_id
  FROM public.wines w
  WHERE lower(trim(w.name)) = lower(trim(p_name))
    AND lower(trim(w.producer)) = lower(trim(p_producer))
  LIMIT 1;

  IF v_existing_id IS NOT NULL THEN
    UPDATE public.wines w SET
      vintage  = COALESCE(w.vintage,  p_vintage),
      variety  = COALESCE(w.variety,  NULLIF(trim(p_variety), '')),
      region   = COALESCE(w.region,   NULLIF(trim(p_region), '')),
      category = COALESCE(w.category, NULLIF(trim(p_category), ''))
    WHERE w.id = v_existing_id;

    RETURN QUERY
    SELECT w.id, w.name, w.producer, w.vintage, w.variety,
           w.region, w.label_image_url, w.category
    FROM public.wines w WHERE w.id = v_existing_id;
  ELSE
    RETURN QUERY
    INSERT INTO public.wines (name, producer, vintage, variety, region, category)
    VALUES (trim(p_name), trim(p_producer), p_vintage,
            NULLIF(trim(p_variety), ''), NULLIF(trim(p_region), ''),
            NULLIF(trim(p_category), ''))
    RETURNING wines.id, wines.name, wines.producer, wines.vintage,
              wines.variety, wines.region, wines.label_image_url, wines.category;
  END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION public.upsert_wine_from_scan(text, text, int, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.upsert_wine_from_scan(text, text, int, text, text, text) TO anon;

-- ═══════════════════════════════════════════════════════════════════════════════
-- PHASE A: Predictive Palate Graph — pgvector Wine Embeddings + Hybrid Similarity
-- ═══════════════════════════════════════════════════════════════════════════════
--
-- Adds 64-dim feature-hashed embeddings to wines, computes per-user taste
-- profiles, and upgrades compute_taste_similarity to a hybrid blend:
--   hybrid = α × pearson_collaborative + (1 - α) × cosine_content
-- where α = shared_count / (shared_count + k), k = 10.
-- Cold-start solved: content similarity works with 0 shared wines.
-- ═══════════════════════════════════════════════════════════════════════════════

-- 1. Enable pgvector
CREATE EXTENSION IF NOT EXISTS vector;

-- 2. Add embedding column to wines
ALTER TABLE public.wines ADD COLUMN IF NOT EXISTS embedding vector(64);

-- ────────────────────────────────────────────────
-- compute_wine_embedding
-- Deterministic 64-dim feature vector from wine attributes using hashing trick.
--   Dims  1- 5: Category one-hot (Red, White, Sparkling, Rose, Unknown)
--   Dims  6-25: Variety signed random projection (md5 hash)
--   Dims 26-45: Region signed random projection (md5 hash)
--   Dims 46-64: Variety×Region cross-feature hash (interaction term)
-- Normalized to unit length for cosine similarity.
-- ────────────────────────────────────────────────
DROP FUNCTION IF EXISTS public.compute_wine_embedding(text, text, text);
CREATE OR REPLACE FUNCTION public.compute_wine_embedding(
  p_category text,
  p_variety  text,
  p_region   text
)
RETURNS vector(64)
LANGUAGE plpgsql IMMUTABLE
AS $$
DECLARE
  dims float8[] := array_fill(0.0, ARRAY[64]);
  h bytea;
  byte_val int;
  i int;
  norm float8 := 0.0;
BEGIN
  -- Dims 1-5: Category one-hot
  CASE lower(trim(COALESCE(p_category, '')))
    WHEN 'red'       THEN dims[1] := 1.0;
    WHEN 'white'     THEN dims[2] := 1.0;
    WHEN 'sparkling' THEN dims[3] := 1.0;
    WHEN 'rose'      THEN dims[4] := 1.0;
    WHEN 'rosé'      THEN dims[4] := 1.0;
    ELSE                   dims[5] := 0.5;
  END CASE;

  -- Dims 6-25: Variety signed random projection
  IF COALESCE(trim(p_variety), '') != '' THEN
    h := decode(md5(lower(trim(p_variety))), 'hex');
    FOR i IN 0..19 LOOP
      byte_val := get_byte(h, i % 16);
      dims[6 + i] := CASE WHEN (byte_val >> (i % 8)) & 1 = 1 THEN 1.0 ELSE -1.0 END;
    END LOOP;
  END IF;

  -- Dims 26-45: Region signed random projection
  IF COALESCE(trim(p_region), '') != '' THEN
    h := decode(md5(lower(trim(p_region))), 'hex');
    FOR i IN 0..19 LOOP
      byte_val := get_byte(h, i % 16);
      dims[26 + i] := CASE WHEN (byte_val >> (i % 8)) & 1 = 1 THEN 1.0 ELSE -1.0 END;
    END LOOP;
  END IF;

  -- Dims 46-64: Variety×Region interaction hash
  IF COALESCE(trim(p_variety), '') != '' AND COALESCE(trim(p_region), '') != '' THEN
    h := decode(md5(lower(trim(p_variety)) || '|' || lower(trim(p_region))), 'hex');
    FOR i IN 0..18 LOOP
      byte_val := get_byte(h, i % 16);
      dims[46 + i] := CASE WHEN (byte_val >> (i % 8)) & 1 = 1 THEN 0.7 ELSE -0.7 END;
    END LOOP;
  END IF;

  -- L2 normalize to unit vector
  FOR i IN 1..64 LOOP
    norm := norm + dims[i] * dims[i];
  END LOOP;
  norm := sqrt(norm);
  IF norm > 0 THEN
    FOR i IN 1..64 LOOP
      dims[i] := dims[i] / norm;
    END LOOP;
  END IF;

  RETURN ('[' || array_to_string(dims, ',') || ']')::vector(64);
END;
$$;

-- ────────────────────────────────────────────────
-- Trigger: auto-compute embedding on wine INSERT / UPDATE
-- ────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.wines_embedding_trigger()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.embedding := compute_wine_embedding(NEW.category, NEW.variety, NEW.region);
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_wines_embedding ON public.wines;
CREATE TRIGGER trg_wines_embedding
  BEFORE INSERT OR UPDATE OF category, variety, region
  ON public.wines
  FOR EACH ROW
  EXECUTE FUNCTION public.wines_embedding_trigger();

-- ────────────────────────────────────────────────
-- Backfill embeddings for existing wines
-- ────────────────────────────────────────────────
UPDATE public.wines
SET embedding = compute_wine_embedding(category, variety, region)
WHERE embedding IS NULL;

-- ────────────────────────────────────────────────
-- HNSW index for fast cosine similarity searches
-- ────────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_wines_embedding_hnsw
  ON public.wines USING hnsw (embedding vector_cosine_ops);

-- ────────────────────────────────────────────────
-- compute_user_taste_profile
-- Returns the user's 64-dim taste profile = rating-weighted average of wine embeddings.
-- Rating weight: (rating - 5.5) / 4.5  →  maps 1→-1.0, 5.5→0, 10→+1.0
-- Result normalized to unit vector. Returns NULL if user has no tastings with embeddings.
-- ────────────────────────────────────────────────
DROP FUNCTION IF EXISTS public.compute_user_taste_profile(uuid);
CREATE OR REPLACE FUNCTION public.compute_user_taste_profile(
  p_user_id uuid
)
RETURNS vector(64)
LANGUAGE plpgsql STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  profile float8[] := array_fill(0.0, ARRAY[64]);
  emb_arr float8[];
  v_weight float8;
  v_rating float8;
  v_count int := 0;
  i int;
  norm float8 := 0.0;
  rec record;
BEGIN
  FOR rec IN
    SELECT t.rating, w.embedding
    FROM public.tastings t
    JOIN public.wines w ON w.id = t.wine_id
    WHERE t.user_id = p_user_id
      AND w.embedding IS NOT NULL
  LOOP
    v_weight := (rec.rating - 5.5) / 4.5;
    -- Convert vector to float array for arithmetic
    emb_arr := rec.embedding::float8[];
    FOR i IN 1..64 LOOP
      profile[i] := profile[i] + v_weight * emb_arr[i];
    END LOOP;
    v_count := v_count + 1;
  END LOOP;

  IF v_count = 0 THEN
    RETURN NULL;
  END IF;

  -- Average
  FOR i IN 1..64 LOOP
    profile[i] := profile[i] / v_count;
  END LOOP;

  -- L2 normalize
  FOR i IN 1..64 LOOP
    norm := norm + profile[i] * profile[i];
  END LOOP;
  norm := sqrt(norm);
  IF norm > 0 THEN
    FOR i IN 1..64 LOOP
      profile[i] := profile[i] / norm;
    END LOOP;
  END IF;

  RETURN ('[' || array_to_string(profile, ',') || ']')::vector(64);
END;
$$;

GRANT EXECUTE ON FUNCTION public.compute_user_taste_profile(uuid) TO authenticated;

-- ════════════════════════════════════════════════════════════════
-- UPGRADED: compute_taste_similarity  (v2 — hybrid blend)
-- ════════════════════════════════════════════════════════════════
-- Hybrid formula:
--   α = shared_count / (shared_count + k),   k = 10
--   hybrid_score = α × pearson_score + (1 - α) × cosine_content_score
--
-- When shared_count = 0  → pure content-based  (cold-start solved)
-- When shared_count = 10 → 50/50 blend
-- When shared_count = 50 → 83% collaborative   (data-rich)
--
-- Falls back to pure Pearson if either user has no taste profile embedding.
-- Returns 0 rows only if both signals are unavailable.
-- ════════════════════════════════════════════════════════════════
DROP FUNCTION IF EXISTS public.compute_taste_similarity(uuid, uuid);
CREATE OR REPLACE FUNCTION public.compute_taste_similarity(
  p_user_a uuid,
  p_user_b uuid
)
RETURNS TABLE (
  user_a uuid,
  user_b uuid,
  score double precision,
  shared_count int,
  computed_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_a uuid;
  v_b uuid;
  v_score double precision;
  v_shared int;
  v_computed timestamptz;
  v_pearson double precision;
  v_cosine double precision;
  v_alpha double precision;
  v_profile_a vector(64);
  v_profile_b vector(64);
  k_shrinkage constant double precision := 10.0;
BEGIN
  -- Canonical ordering: smaller UUID first
  IF p_user_a < p_user_b THEN
    v_a := p_user_a; v_b := p_user_b;
  ELSE
    v_a := p_user_b; v_b := p_user_a;
  END IF;

  -- Check cache (7-day TTL)
  SELECT ts.score, ts.shared_count, ts.computed_at
  INTO v_score, v_shared, v_computed
  FROM public.taste_similarity ts
  WHERE ts.user_a = v_a AND ts.user_b = v_b
    AND ts.computed_at > now() - interval '7 days';

  IF FOUND THEN
    RETURN QUERY SELECT v_a, v_b, v_score, v_shared, v_computed;
    RETURN;
  END IF;

  -- ── Signal 1: Collaborative (Bayesian-shrunk Pearson) ──
  SELECT
    CASE WHEN COUNT(*) < 2 THEN NULL
         WHEN STDDEV(ta_r) = 0 OR STDDEV(tb_r) = 0 THEN 0.0
         ELSE CORR(ta_r, tb_r) * (COUNT(*)::double precision / (COUNT(*) + k_shrinkage))
    END,
    COUNT(*)::int
  INTO v_pearson, v_shared
  FROM (
    SELECT ta.rating AS ta_r, tb.rating AS tb_r
    FROM public.tastings ta
    JOIN public.tastings tb ON ta.wine_id = tb.wine_id
    WHERE ta.user_id = v_a AND tb.user_id = v_b
  ) shared;

  -- ── Signal 2: Content-based (cosine of taste profiles) ──
  v_profile_a := compute_user_taste_profile(v_a);
  v_profile_b := compute_user_taste_profile(v_b);

  IF v_profile_a IS NOT NULL AND v_profile_b IS NOT NULL THEN
    -- pgvector cosine distance = 1 - cosine_similarity, so invert
    v_cosine := 1.0 - (v_profile_a <=> v_profile_b);
    -- Clamp negative cosine to 0
    v_cosine := GREATEST(0.0, v_cosine);
  ELSE
    v_cosine := NULL;
  END IF;

  -- ── Blend ──
  IF v_pearson IS NOT NULL AND v_cosine IS NOT NULL THEN
    -- Both signals available: weighted blend
    v_alpha := v_shared::double precision / (v_shared + k_shrinkage);
    v_score := v_alpha * v_pearson + (1.0 - v_alpha) * v_cosine;
  ELSIF v_cosine IS NOT NULL THEN
    -- Content-only (cold-start): use cosine × dampening factor
    v_score := v_cosine * 0.85;
  ELSIF v_pearson IS NOT NULL THEN
    -- Pearson-only (no embeddings): original behavior
    v_score := v_pearson;
  ELSE
    -- Neither signal: clean up stale cache and return nothing
    DELETE FROM public.taste_similarity
    WHERE taste_similarity.user_a = v_a AND taste_similarity.user_b = v_b;
    RETURN;
  END IF;

  -- Clamp to [0, 1]
  v_score := GREATEST(0.0, LEAST(1.0, v_score));
  v_computed := now();

  -- Upsert cache
  INSERT INTO public.taste_similarity (user_a, user_b, score, shared_count, computed_at)
  VALUES (v_a, v_b, v_score, COALESCE(v_shared, 0), v_computed)
  ON CONFLICT (user_a, user_b) DO UPDATE SET
    score = EXCLUDED.score,
    shared_count = EXCLUDED.shared_count,
    computed_at = EXCLUDED.computed_at;

  RETURN QUERY SELECT v_a, v_b, v_score, COALESCE(v_shared, 0), v_computed;
END;
$$;

GRANT EXECUTE ON FUNCTION public.compute_taste_similarity(uuid, uuid) TO authenticated;

-- ═══════════════════════════════════════════════════════════════════════════════
-- TWIN-WEIGHTED RATINGS — The Vivino Kill Shot
-- ═══════════════════════════════════════════════════════════════════════════════
-- Instead of "4.2 average (12,847 ratings)", show:
--   "8.4 among your Taste Twins (3 ratings) · 7.1 community average"
-- Twin ratings weighted by similarity score for personalized relevance.
-- ═══════════════════════════════════════════════════════════════════════════════

-- ────────────────────────────────────────────────
-- get_twin_weighted_rating (single wine)
-- Returns twin-weighted avg + community avg for one wine.
-- Twin ratings weighted by taste_similarity score.
-- ────────────────────────────────────────────────
DROP FUNCTION IF EXISTS public.get_twin_weighted_rating(uuid, uuid);
CREATE OR REPLACE FUNCTION public.get_twin_weighted_rating(
  p_user_id uuid,
  p_wine_id uuid
)
RETURNS TABLE (
  twin_weighted_avg double precision,
  twin_count int,
  community_avg double precision,
  community_count int
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_twin_sum double precision := 0;
  v_weight_sum double precision := 0;
  v_twin_count int := 0;
  v_comm_avg double precision;
  v_comm_count int;
  rec record;
BEGIN
  FOR rec IN
    SELECT t.rating, ts.score
    FROM public.tastings t
    JOIN public.taste_similarity ts ON (
      (ts.user_a = p_user_id AND ts.user_b = t.user_id) OR
      (ts.user_b = p_user_id AND ts.user_a = t.user_id)
    )
    WHERE t.wine_id = p_wine_id
      AND t.user_id != p_user_id
      AND ts.score >= 0.30
  LOOP
    v_twin_sum := v_twin_sum + rec.rating * rec.score;
    v_weight_sum := v_weight_sum + rec.score;
    v_twin_count := v_twin_count + 1;
  END LOOP;

  SELECT AVG(t.rating), COUNT(*)::int
  INTO v_comm_avg, v_comm_count
  FROM public.tastings t
  WHERE t.wine_id = p_wine_id;

  RETURN QUERY SELECT
    CASE WHEN v_twin_count > 0 THEN v_twin_sum / v_weight_sum ELSE NULL END,
    v_twin_count,
    v_comm_avg,
    COALESCE(v_comm_count, 0);
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_twin_weighted_rating(uuid, uuid) TO authenticated;

-- ────────────────────────────────────────────────
-- get_twin_weighted_ratings_batch (multiple wines)
-- Efficient batch query for feed/search: returns twin + community scores per wine.
-- ────────────────────────────────────────────────
DROP FUNCTION IF EXISTS public.get_twin_weighted_ratings_batch(uuid, uuid[]);
CREATE OR REPLACE FUNCTION public.get_twin_weighted_ratings_batch(
  p_user_id uuid,
  p_wine_ids uuid[]
)
RETURNS TABLE (
  wine_id uuid,
  twin_weighted_avg double precision,
  twin_count int,
  community_avg double precision,
  community_count int
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  WITH twin_ratings AS (
    SELECT
      t.wine_id AS wid,
      t.rating,
      ts.score
    FROM public.tastings t
    JOIN public.taste_similarity ts ON (
      (ts.user_a = p_user_id AND ts.user_b = t.user_id) OR
      (ts.user_b = p_user_id AND ts.user_a = t.user_id)
    )
    WHERE t.wine_id = ANY(p_wine_ids)
      AND t.user_id != p_user_id
      AND ts.score >= 0.30
  ),
  twin_agg AS (
    SELECT
      tr.wid,
      SUM(tr.rating * tr.score) / SUM(tr.score) AS tw_avg,
      COUNT(*)::int AS tw_count
    FROM twin_ratings tr
    GROUP BY tr.wid
  ),
  community_agg AS (
    SELECT
      t.wine_id AS wid,
      AVG(t.rating) AS c_avg,
      COUNT(*)::int AS c_count
    FROM public.tastings t
    WHERE t.wine_id = ANY(p_wine_ids)
    GROUP BY t.wine_id
  )
  SELECT
    COALESCE(ta.wid, ca.wid),
    ta.tw_avg,
    COALESCE(ta.tw_count, 0),
    ca.c_avg,
    COALESCE(ca.c_count, 0)
  FROM community_agg ca
  FULL OUTER JOIN twin_agg ta ON ta.wid = ca.wid;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_twin_weighted_ratings_batch(uuid, uuid[]) TO authenticated;

-- ═══════════════════════════════════════════════════════════════════════════════
-- PHASE 2: DATA INTEGRITY — pg_trgm Wine Deduplication
-- ═══════════════════════════════════════════════════════════════════════════════
-- Problem: "Chateau Margaux" vs "Ch. Margaux" vs "Château Margaux" = 3 duplicates.
-- Uses trigram similarity to find and merge duplicate wines.
-- merge_duplicate_wines: re-points all FKs to canonical wine, deletes duplicate.
-- ═══════════════════════════════════════════════════════════════════════════════

CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- Trigram index on wine name + producer for fast similarity queries
CREATE INDEX IF NOT EXISTS idx_wines_name_trgm ON public.wines USING gin (name gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_wines_producer_trgm ON public.wines USING gin (producer gin_trgm_ops);

-- ────────────────────────────────────────────────
-- find_wine_duplicates
-- Returns potential duplicate pairs above similarity threshold.
-- Default: name_sim > 0.5 AND producer_sim > 0.4 (tuned for wine names).
-- Limited to top 100 pairs per call to avoid runaway scans.
-- ────────────────────────────────────────────────
DROP FUNCTION IF EXISTS public.find_wine_duplicates(double precision, double precision, int);
CREATE OR REPLACE FUNCTION public.find_wine_duplicates(
  p_name_threshold double precision DEFAULT 0.5,
  p_producer_threshold double precision DEFAULT 0.4,
  p_limit int DEFAULT 100
)
RETURNS TABLE (
  wine_a_id uuid,
  wine_a_name text,
  wine_a_producer text,
  wine_a_vintage int,
  wine_b_id uuid,
  wine_b_name text,
  wine_b_producer text,
  wine_b_vintage int,
  name_similarity double precision,
  producer_similarity double precision
)
LANGUAGE sql STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT
    a.id, a.name, a.producer, a.vintage,
    b.id, b.name, b.producer, b.vintage,
    similarity(a.name, b.name)::double precision,
    similarity(a.producer, b.producer)::double precision
  FROM public.wines a
  JOIN public.wines b ON a.id < b.id
  WHERE similarity(a.name, b.name) > p_name_threshold
    AND similarity(a.producer, b.producer) > p_producer_threshold
  ORDER BY similarity(a.name, b.name) + similarity(a.producer, b.producer) DESC
  LIMIT p_limit;
$$;

-- ────────────────────────────────────────────────
-- merge_duplicate_wines
-- Merges duplicate_id INTO canonical_id:
--   1. Re-point tastings, cellar_items, activity_feed FKs
--   2. Enrich canonical with any non-null fields from duplicate
--   3. Delete duplicate wine row
-- Returns the canonical wine row after merge.
-- ────────────────────────────────────────────────
DROP FUNCTION IF EXISTS public.merge_duplicate_wines(uuid, uuid);
CREATE OR REPLACE FUNCTION public.merge_duplicate_wines(
  p_canonical_id uuid,
  p_duplicate_id uuid
)
RETURNS TABLE (
  id uuid, name text, producer text, vintage int,
  variety text, region text, label_image_url text, category text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF p_canonical_id = p_duplicate_id THEN
    RAISE EXCEPTION 'Cannot merge a wine with itself';
  END IF;

  -- Verify both wines exist
  IF NOT EXISTS (SELECT 1 FROM public.wines WHERE wines.id = p_canonical_id) THEN
    RAISE EXCEPTION 'Canonical wine % not found', p_canonical_id;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.wines WHERE wines.id = p_duplicate_id) THEN
    RAISE EXCEPTION 'Duplicate wine % not found', p_duplicate_id;
  END IF;

  -- 1. Re-point tastings (handle unique constraint: same user may have tasted both)
  -- Delete tastings for duplicate wine where user already tasted canonical wine
  DELETE FROM public.tastings t1
  USING public.tastings t2
  WHERE t1.wine_id = p_duplicate_id
    AND t2.wine_id = p_canonical_id
    AND t1.user_id = t2.user_id;

  -- Move remaining tastings to canonical
  UPDATE public.tastings SET wine_id = p_canonical_id WHERE wine_id = p_duplicate_id;

  -- 2. Re-point cellar_items (same unique constraint handling)
  DELETE FROM public.cellar_items c1
  USING public.cellar_items c2
  WHERE c1.wine_id = p_duplicate_id
    AND c2.wine_id = p_canonical_id
    AND c1.user_id = c2.user_id;

  UPDATE public.cellar_items SET wine_id = p_canonical_id WHERE wine_id = p_duplicate_id;

  -- 3. Re-point activity_feed
  UPDATE public.activity_feed SET wine_id = p_canonical_id WHERE wine_id = p_duplicate_id;

  -- 4. Enrich canonical with non-null fields from duplicate
  UPDATE public.wines c SET
    vintage         = COALESCE(c.vintage,         d.vintage),
    variety         = COALESCE(c.variety,          d.variety),
    region          = COALESCE(c.region,           d.region),
    label_image_url = COALESCE(c.label_image_url,  d.label_image_url),
    category        = COALESCE(c.category,         d.category)
  FROM public.wines d
  WHERE c.id = p_canonical_id AND d.id = p_duplicate_id;

  -- 5. Delete duplicate
  DELETE FROM public.wines WHERE wines.id = p_duplicate_id;

  -- Return merged canonical
  RETURN QUERY
  SELECT w.id, w.name, w.producer, w.vintage, w.variety, w.region, w.label_image_url, w.category
  FROM public.wines w WHERE w.id = p_canonical_id;
END;
$$;
