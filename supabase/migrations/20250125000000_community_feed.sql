-- Vitis Community & Social Feed
-- Tables: follows, activity_feed, comments_cheers
-- Prerequisites: public.profiles (id -> auth.users), public.wines (id).
-- Run in Supabase SQL Editor or via CLI: supabase db push

-- -----------------------------------------------------------------------------
-- follows
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

CREATE POLICY "Users can view follows"
  ON public.follows FOR SELECT
  USING (true);

CREATE POLICY "Users can manage own follows"
  ON public.follows FOR ALL
  USING (auth.uid() = follower_id);

-- -----------------------------------------------------------------------------
-- activity_feed
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.activity_feed (
  id uuid NOT NULL PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  activity_type text NOT NULL CHECK (activity_type IN ('rank_update', 'new_entry', 'duel_win')),
  wine_id uuid NOT NULL REFERENCES public.wines(id) ON DELETE CASCADE,
  target_wine_id uuid REFERENCES public.wines(id) ON DELETE SET NULL,
  content_text text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_activity_feed_user ON public.activity_feed (user_id);
CREATE INDEX IF NOT EXISTS idx_activity_feed_created ON public.activity_feed (created_at DESC);

ALTER TABLE public.activity_feed ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can read activity_feed"
  ON public.activity_feed FOR SELECT
  USING (true);

CREATE POLICY "Users can insert own activity"
  ON public.activity_feed FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- Realtime: add to publication (run if using Supabase hosted)
-- ALTER PUBLICATION supabase_realtime ADD TABLE public.activity_feed;

-- Optional: add label_image_url to wines if not present (Storage URLs).
ALTER TABLE public.wines ADD COLUMN IF NOT EXISTS label_image_url text;

-- View for feed with profile + wine details (single query).
-- Assumes profiles.id = auth.users.id.
CREATE OR REPLACE VIEW public.feed_with_details AS
SELECT
  a.id,
  a.user_id,
  a.activity_type,
  a.wine_id,
  a.target_wine_id,
  a.content_text,
  a.created_at,
  p.username,
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
LEFT JOIN public.profiles p ON p.id = a.user_id
LEFT JOIN public.wines w ON w.id = a.wine_id
LEFT JOIN public.wines tw ON tw.id = a.target_wine_id;

-- RPC for Following feed: activities from users that p_follower_id follows.
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

-- -----------------------------------------------------------------------------
-- comments_cheers
-- comment_body IS NULL => Cheer (like); non-null => Comment
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

CREATE POLICY "Anyone can read comments_cheers"
  ON public.comments_cheers FOR SELECT
  USING (true);

CREATE POLICY "Users can insert own comments/cheers"
  ON public.comments_cheers FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete own comments/cheers"
  ON public.comments_cheers FOR DELETE
  USING (auth.uid() = user_id);
