-- ═══════════════════════════════════════════════════════════════════════════════
-- Baseline: the two tables the migration chain assumes and never creates
-- Timestamped at zero so it runs before everything else.
--
-- WHY THIS EXISTS
-- Running `supabase db reset` on this project failed at the very first migration
-- with `relation "public.wines" does not exist`, and 37 of the 48 migrations failed
-- in total. The cause is that `wines` and `profiles` were only ever created in
-- setup_schema.sql, which is not part of the migration chain. A database therefore
-- could not be built from migrations alone: contributors had to know to run a
-- separate file first, and the local stack could not start at all.
--
-- Every other table cascades from these two. `activity_feed`, `tastings`,
-- `cellar_items` and `notifications` all have migrations that create them; those
-- migrations were failing only because they referenced `wines` or `profiles` in a
-- foreign key. With this file in place the chain builds a database on its own.
--
-- SCOPE
-- Base shape only: the columns as originally defined, plus the extension they need.
-- Every later column, index, policy and constraint stays in the migration that
-- introduced it, so history is preserved rather than squashed. IF NOT EXISTS
-- throughout means this is a no-op against any already-deployed database, including
-- ones built from setup_schema.sql.
-- ═══════════════════════════════════════════════════════════════════════════════

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

CREATE TABLE IF NOT EXISTS public.profiles (
  id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  username text NOT NULL,
  full_name text,
  avatar_url text,
  bio text,
  created_at timestamptz DEFAULT now()
);

-- Definition copied verbatim from 20250125000000_community_feed.sql, including the
-- original narrow CHECK. Later migrations widen it to allow 'had_wine'. Creating it
-- here rather than there changes nothing for that migration, whose CREATE TABLE IF
-- NOT EXISTS becomes a no-op.
CREATE TABLE IF NOT EXISTS public.activity_feed (
  id uuid NOT NULL PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  activity_type text NOT NULL CHECK (activity_type IN ('rank_update', 'new_entry', 'duel_win')),
  wine_id uuid NOT NULL REFERENCES public.wines(id) ON DELETE CASCADE,
  target_wine_id uuid REFERENCES public.wines(id) ON DELETE SET NULL,
  content_text text,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- `tastings` is created by a migration dated 28 February, but migrations dated
-- 29 and 30 January already reference it. That ordering cannot be corrected without
-- rewriting timestamps, so the table starts here instead.
CREATE TABLE IF NOT EXISTS public.tastings (
  id uuid NOT NULL PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  wine_id uuid NOT NULL REFERENCES public.wines(id) ON DELETE CASCADE,
  rating double precision NOT NULL CHECK (rating >= 1.0 AND rating <= 10.0),
  note_tags text[] NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  source text NULL
);

-- Social interaction tables. No migration has ever created these.
CREATE TABLE IF NOT EXISTS public.likes (
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  activity_id uuid NOT NULL REFERENCES public.activity_feed(id) ON DELETE CASCADE,
  created_at timestamptz DEFAULT now(),
  PRIMARY KEY (user_id, activity_id)
);

CREATE TABLE IF NOT EXISTS public.comments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  activity_id uuid NOT NULL REFERENCES public.activity_feed(id) ON DELETE CASCADE,
  body text NOT NULL,
  created_at timestamptz DEFAULT now()
);

-- Cache for the taste twin engine. Also never created by a migration.
CREATE TABLE IF NOT EXISTS public.taste_similarity (
  user_a uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  user_b uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  score  double precision NOT NULL DEFAULT 0,
  shared_count int NOT NULL DEFAULT 0,
  computed_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_a, user_b),
  CONSTRAINT taste_similarity_canonical CHECK (user_a < user_b)
);

-- ═══════════════════════════════════════════════════════════════════════════════
-- Row level security for the tables created above.
--
-- Creating a table here without also turning RLS on would leave a database built
-- from migrations more open than one built from setup_schema.sql: likes and comments
-- in particular would be writable by any authenticated user for anyone's row. A
-- table added by this file has to arrive locked.
--
-- These are the conservative pre-privacy policies. The later privacy migration drops
-- and recreates the SELECT policies with the friends-only visibility rules, which is
-- why the ones here are deliberately simple rather than trying to anticipate it.
-- ═══════════════════════════════════════════════════════════════════════════════

ALTER TABLE public.wines ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "wines_select_public" ON public.wines;
CREATE POLICY "wines_select_public" ON public.wines FOR SELECT USING (true);
DROP POLICY IF EXISTS "wines_write_auth" ON public.wines;
CREATE POLICY "wines_write_auth" ON public.wines FOR INSERT TO authenticated WITH CHECK (true);
DROP POLICY IF EXISTS "wines_update_auth" ON public.wines;
CREATE POLICY "wines_update_auth" ON public.wines FOR UPDATE TO authenticated USING (true) WITH CHECK (true);

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.activity_feed ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tastings ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.likes ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "likes_select" ON public.likes;
CREATE POLICY "likes_select" ON public.likes FOR SELECT USING (true);
DROP POLICY IF EXISTS "likes_insert_own" ON public.likes;
CREATE POLICY "likes_insert_own" ON public.likes FOR INSERT WITH CHECK (auth.uid() = user_id);
DROP POLICY IF EXISTS "likes_delete_own" ON public.likes;
CREATE POLICY "likes_delete_own" ON public.likes FOR DELETE USING (auth.uid() = user_id);

ALTER TABLE public.comments ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "comments_select" ON public.comments;
CREATE POLICY "comments_select" ON public.comments FOR SELECT USING (true);
DROP POLICY IF EXISTS "comments_insert_own" ON public.comments;
CREATE POLICY "comments_insert_own" ON public.comments FOR INSERT WITH CHECK (auth.uid() = user_id);
DROP POLICY IF EXISTS "comments_delete_own" ON public.comments;
CREATE POLICY "comments_delete_own" ON public.comments FOR DELETE USING (auth.uid() = user_id);

-- Similarity rows are only ever the caller's own pairings. SECURITY DEFINER RPCs
-- bypass this, which is why those carry their own auth checks.
ALTER TABLE public.taste_similarity ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "taste_similarity_select_auth" ON public.taste_similarity;
CREATE POLICY "taste_similarity_select_auth" ON public.taste_similarity
  FOR SELECT USING (auth.uid() = user_a OR auth.uid() = user_b);
