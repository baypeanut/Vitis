-- Tastings table: wine logging with rating and optional notes
-- Replaces duel/comparison flow. Source of truth for "had wine" activity.

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

-- RLS: users can manage own tastings
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

-- Add had_wine to activity_type check constraint
ALTER TABLE public.activity_feed DROP CONSTRAINT IF EXISTS activity_feed_activity_type_check;
ALTER TABLE public.activity_feed ADD CONSTRAINT activity_feed_activity_type_check
  CHECK (activity_type IN ('rank_update', 'new_entry', 'duel_win', 'had_wine'));

-- Add FK constraint for tastings
ALTER TABLE public.tastings DROP CONSTRAINT IF EXISTS tastings_user_id_fkey;
ALTER TABLE public.tastings ADD CONSTRAINT tastings_user_id_fkey
  FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;

-- Update feed_with_details view to include note_tags from tastings (via join)
-- IMPORTANT: This must run AFTER tastings table is created.
DROP VIEW IF EXISTS public.feed_with_details;

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
LEFT JOIN public.tastings t ON t.user_id = a.user_id AND t.wine_id = a.wine_id AND t.created_at = a.created_at;

-- Update feed_following function to filter only had_wine
DROP FUNCTION IF EXISTS public.feed_following(uuid, int, int);

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
