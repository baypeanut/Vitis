-- Profile loading performance: composite indexes for common query patterns.
-- Run: supabase db push (or apply via Supabase Dashboard SQL Editor)

-- activity_feed: feed queries filter by user_id and order by created_at
CREATE INDEX IF NOT EXISTS idx_activity_feed_user_created
  ON public.activity_feed (user_id, created_at DESC);
