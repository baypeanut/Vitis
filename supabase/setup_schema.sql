-- Vitis – Supabase schema setup
-- Run this entire script in Supabase Dashboard → SQL Editor → New query.
-- Fixes: "table public.profiles" and "function duel_next_pair" not found.

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
CREATE UNIQUE INDEX IF NOT EXISTS profiles_username_lower_key ON public.profiles (lower(trim(username)));

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

-- -----------------------------------------------------------------------------
-- 3. Profiles RLS
-- -----------------------------------------------------------------------------
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "profiles_select" ON public.profiles;
CREATE POLICY "profiles_select" ON public.profiles FOR SELECT USING (true);
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

-- Update activity_type constraint to include 'had_wine' (if table already exists)
ALTER TABLE public.activity_feed DROP CONSTRAINT IF EXISTS activity_feed_activity_type_check;
ALTER TABLE public.activity_feed ADD CONSTRAINT activity_feed_activity_type_check
  CHECK (activity_type IN ('rank_update', 'new_entry', 'duel_win', 'had_wine'));
ALTER TABLE public.activity_feed ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Anyone can read activity_feed" ON public.activity_feed;
CREATE POLICY "Anyone can read activity_feed" ON public.activity_feed FOR SELECT USING (true);
DROP POLICY IF EXISTS "Users can insert own activity" ON public.activity_feed;
CREATE POLICY "Users can insert own activity" ON public.activity_feed FOR INSERT WITH CHECK (auth.uid() = user_id);
DROP POLICY IF EXISTS "Users can delete own activity" ON public.activity_feed;
CREATE POLICY "Users can delete own activity" ON public.activity_feed FOR DELETE USING (auth.uid() = user_id);

DROP FUNCTION IF EXISTS public.feed_following(uuid, int, int);
DROP VIEW IF EXISTS public.feed_with_details;

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
CREATE POLICY "Anyone can read comments_cheers" ON public.comments_cheers FOR SELECT USING (true);
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
CREATE POLICY "likes_select" ON public.likes FOR SELECT USING (true);
DROP POLICY IF EXISTS "likes_insert_own" ON public.likes;
CREATE POLICY "likes_insert_own" ON public.likes FOR INSERT WITH CHECK (auth.uid() = user_id);
DROP POLICY IF EXISTS "likes_delete_own" ON public.likes;
CREATE POLICY "likes_delete_own" ON public.likes FOR DELETE USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "comments_select" ON public.comments;
CREATE POLICY "comments_select" ON public.comments FOR SELECT USING (true);
DROP POLICY IF EXISTS "comments_insert_own" ON public.comments;
CREATE POLICY "comments_insert_own" ON public.comments FOR INSERT WITH CHECK (auth.uid() = user_id);
DROP POLICY IF EXISTS "comments_delete_own" ON public.comments;
CREATE POLICY "comments_delete_own" ON public.comments FOR DELETE USING (auth.uid() = user_id);

-- -----------------------------------------------------------------------------
-- Tastings: wine logging with rating and optional notes (replaces duel/comparison)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.tastings (
  id uuid NOT NULL PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  wine_id uuid NOT NULL REFERENCES public.wines(id) ON DELETE CASCADE,
  rating double precision NOT NULL CHECK (rating >= 1.0 AND rating <= 10.0),
  note_tags text[] NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  source text NULL
);

CREATE INDEX IF NOT EXISTS idx_tastings_user_created ON public.tastings (user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_tastings_wine ON public.tastings (wine_id);

ALTER TABLE public.tastings ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "tastings_select_own" ON public.tastings;
CREATE POLICY "tastings_select_own" ON public.tastings FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "tastings_insert_own" ON public.tastings;
CREATE POLICY "tastings_insert_own" ON public.tastings FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "tastings_update_own" ON public.tastings;
CREATE POLICY "tastings_update_own" ON public.tastings FOR UPDATE USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "tastings_delete_own" ON public.tastings;
CREATE POLICY "tastings_delete_own" ON public.tastings FOR DELETE USING (auth.uid() = user_id);

-- Public read for feed (anyone can read all tastings for social feed)
DROP POLICY IF EXISTS "tastings_select_public" ON public.tastings;
CREATE POLICY "tastings_select_public" ON public.tastings FOR SELECT USING (true);

-- Dev mock: allow when auth.uid() IS NULL and user_id matches debugMockUserId
DROP POLICY IF EXISTS "dev_mock_tastings" ON public.tastings;
CREATE POLICY "dev_mock_tastings" ON public.tastings FOR ALL
  USING (auth.uid() IS NULL AND user_id = '1edd4da3-ecd2-4c30-9f2f-ac7573a8fcba'::uuid)
  WITH CHECK (auth.uid() IS NULL AND user_id = '1edd4da3-ecd2-4c30-9f2f-ac7573a8fcba'::uuid);

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
  tw.name AS target_wine_name,
  tw.producer AS target_wine_producer,
  tw.vintage AS target_wine_vintage,
  tw.label_image_url AS target_wine_label_url,
  t.note_tags AS tasting_note_tags,
  t.rating AS tasting_rating
FROM public.activity_feed a
INNER JOIN public.profiles p ON p.id = a.user_id
LEFT JOIN public.wines w ON w.id = a.wine_id
LEFT JOIN public.wines tw ON tw.id = a.target_wine_id
LEFT JOIN public.tastings t ON t.user_id = a.user_id 
  AND t.wine_id = a.wine_id 
  AND a.activity_type = 'had_wine'
  AND t.created_at BETWEEN a.created_at - INTERVAL '10 seconds' AND a.created_at + INTERVAL '10 seconds'
ORDER BY a.id, 
  CASE WHEN t.id IS NULL THEN 1 ELSE 0 END,
  ABS(EXTRACT(EPOCH FROM (t.created_at - a.created_at)));

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
  WHERE f.activity_type = 'had_wine'
  ORDER BY f.created_at DESC
  LIMIT p_limit OFFSET p_offset;
$$;

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
CREATE UNIQUE INDEX IF NOT EXISTS idx_cellar_items_user_wine_status
  ON public.cellar_items (user_id, wine_id, status);
CREATE INDEX IF NOT EXISTS idx_cellar_items_user_status_created
  ON public.cellar_items (user_id, status, created_at DESC);
ALTER TABLE public.cellar_items ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "cellar_items_select_own" ON public.cellar_items;
CREATE POLICY "cellar_items_select_own" ON public.cellar_items FOR SELECT USING (auth.uid() = user_id);
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
  USING (auth.uid() IS NULL AND user_id = '1edd4da3-ecd2-4c30-9f2f-ac7573a8fcba'::uuid)
  WITH CHECK (auth.uid() IS NULL AND user_id = '1edd4da3-ecd2-4c30-9f2f-ac7573a8fcba'::uuid);

DROP POLICY IF EXISTS "dev_mock_activity_insert" ON public.activity_feed;
CREATE POLICY "dev_mock_activity_insert" ON public.activity_feed
  FOR INSERT
  WITH CHECK (auth.uid() IS NULL AND user_id = '1edd4da3-ecd2-4c30-9f2f-ac7573a8fcba'::uuid);

DROP POLICY IF EXISTS "dev_mock_comments_cheers" ON public.comments_cheers;
CREATE POLICY "dev_mock_comments_cheers" ON public.comments_cheers
  FOR ALL
  USING (auth.uid() IS NULL AND user_id = '1edd4da3-ecd2-4c30-9f2f-ac7573a8fcba'::uuid)
  WITH CHECK (auth.uid() IS NULL AND user_id = '1edd4da3-ecd2-4c30-9f2f-ac7573a8fcba'::uuid);

DROP POLICY IF EXISTS "dev_mock_likes" ON public.likes;
CREATE POLICY "dev_mock_likes" ON public.likes
  FOR ALL
  USING (auth.uid() IS NULL AND user_id = '1edd4da3-ecd2-4c30-9f2f-ac7573a8fcba'::uuid)
  WITH CHECK (auth.uid() IS NULL AND user_id = '1edd4da3-ecd2-4c30-9f2f-ac7573a8fcba'::uuid);

DROP POLICY IF EXISTS "dev_mock_comments" ON public.comments;
CREATE POLICY "dev_mock_comments" ON public.comments
  FOR ALL
  USING (auth.uid() IS NULL AND user_id = '1edd4da3-ecd2-4c30-9f2f-ac7573a8fcba'::uuid)
  WITH CHECK (auth.uid() IS NULL AND user_id = '1edd4da3-ecd2-4c30-9f2f-ac7573a8fcba'::uuid);

DROP POLICY IF EXISTS "dev_mock_cellar_items" ON public.cellar_items;
CREATE POLICY "dev_mock_cellar_items" ON public.cellar_items
  FOR ALL
  USING (auth.uid() IS NULL AND user_id = '1edd4da3-ecd2-4c30-9f2f-ac7573a8fcba'::uuid)
  WITH CHECK (auth.uid() IS NULL AND user_id = '1edd4da3-ecd2-4c30-9f2f-ac7573a8fcba'::uuid);

DROP POLICY IF EXISTS "dev_mock_follows" ON public.follows;
CREATE POLICY "dev_mock_follows" ON public.follows
  FOR ALL
  USING (auth.uid() IS NULL AND follower_id = '1edd4da3-ecd2-4c30-9f2f-ac7573a8fcba'::uuid)
  WITH CHECK (auth.uid() IS NULL AND follower_id = '1edd4da3-ecd2-4c30-9f2f-ac7573a8fcba'::uuid);

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
-- RLS disabled for test phase. Enable RLS and add policies before production.
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.dev_accounts (
  id uuid PRIMARY KEY,
  email text,
  phone_e164 text,
  full_name text,
  username text,
  created_at timestamptz DEFAULT now()
);

ALTER TABLE public.dev_accounts DISABLE ROW LEVEL SECURITY;
