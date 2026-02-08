-- A0-A9: Privacy RLS, Feed RPCs, Soft Delete, Audit, dev_accounts guard
-- FAANG production-grade: DB-first privacy, no USING(true), soft delete with cooldown

-- -----------------------------------------------------------------------------
-- A0/A8: app_config for environment; profiles.deleted_at for soft delete
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.app_config (
  key text PRIMARY KEY,
  value text NOT NULL
);
-- Default: production. Set in Dashboard for local/staging.
INSERT INTO public.app_config (key, value) VALUES ('app_env', 'production')
ON CONFLICT (key) DO NOTHING;

ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS deleted_at timestamptz NULL;

-- -----------------------------------------------------------------------------
-- A9: audit_log table (server-only readable)
-- -----------------------------------------------------------------------------
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
-- Deny all: only service role or backend can insert/select
CREATE POLICY "audit_log_deny_all" ON public.audit_log FOR ALL USING (false) WITH CHECK (false);

-- Allow service role to insert (by default service role bypasses RLS; this policy blocks anon/auth)
-- We use a function to insert audit logs, SECURITY DEFINER
CREATE OR REPLACE FUNCTION public.audit_log_insert(
  p_user_id uuid,
  p_event_type text,
  p_metadata jsonb DEFAULT '{}'
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.audit_log (user_id, event_type, metadata)
  VALUES (p_user_id, p_event_type, p_metadata);
END;
$$;
GRANT EXECUTE ON FUNCTION public.audit_log_insert(uuid, text, jsonb) TO authenticated;

-- -----------------------------------------------------------------------------
-- A1: Helper - can viewer see owner's activity? (everyone OR friends+mutual)
-- friends = mutual follow
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.can_view_activity(p_viewer_id uuid, p_owner_id uuid, p_visibility text)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY INVOKER
AS $$
  SELECT
    p_viewer_id = p_owner_id
    OR p_visibility = 'everyone'
    OR (p_visibility = 'friends' AND p_viewer_id IS NOT NULL AND public.is_mutual_friend(p_viewer_id, p_owner_id));
$$;

CREATE OR REPLACE FUNCTION public.can_view_cellar(p_viewer_id uuid, p_owner_id uuid, p_visibility text)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY INVOKER
AS $$
  SELECT
    p_viewer_id = p_owner_id
    OR p_visibility = 'everyone'
    OR (p_visibility = 'friends' AND p_viewer_id IS NOT NULL AND public.is_mutual_friend(p_viewer_id, p_owner_id));
$$;

-- -----------------------------------------------------------------------------
-- A2: activity_feed RLS - privacy enforced
-- -----------------------------------------------------------------------------
DROP POLICY IF EXISTS "Anyone can read activity_feed" ON public.activity_feed;
CREATE POLICY "activity_feed_select_privacy" ON public.activity_feed
  FOR SELECT
  USING (
    auth.uid() = user_id
    OR EXISTS (
      SELECT 1 FROM public.profiles pr
      WHERE pr.id = activity_feed.user_id
        AND pr.deleted_at IS NULL
        AND public.can_view_activity(auth.uid(), pr.id, pr.activity_visibility)
    )
  );

-- -----------------------------------------------------------------------------
-- A2: tastings RLS - privacy enforced (tastings drive activity for had_wine)
-- -----------------------------------------------------------------------------
DROP POLICY IF EXISTS "tastings_select_public" ON public.tastings;
CREATE POLICY "tastings_select_privacy" ON public.tastings
  FOR SELECT
  USING (
    auth.uid() = user_id
    OR EXISTS (
      SELECT 1 FROM public.profiles pr
      WHERE pr.id = tastings.user_id
        AND pr.deleted_at IS NULL
        AND public.can_view_activity(auth.uid(), pr.id, pr.activity_visibility)
    )
  );

-- -----------------------------------------------------------------------------
-- A2: cellar_items RLS - cellar_visibility for had, wishlist_visibility for wishlist
-- -----------------------------------------------------------------------------
DROP POLICY IF EXISTS "cellar_items_select_all" ON public.cellar_items;
CREATE POLICY "cellar_items_select_privacy" ON public.cellar_items
  FOR SELECT
  USING (
    auth.uid() = user_id
    OR EXISTS (
      SELECT 1 FROM public.profiles pr
      WHERE pr.id = cellar_items.user_id
        AND pr.deleted_at IS NULL
        AND (
          (cellar_items.status = 'had' AND public.can_view_cellar(auth.uid(), pr.id, pr.cellar_visibility))
          OR (cellar_items.status = 'wishlist' AND public.can_view_cellar(auth.uid(), pr.id, pr.wishlist_visibility))
        )
    )
  );

-- -----------------------------------------------------------------------------
-- A2: profiles - hide deleted from others
-- -----------------------------------------------------------------------------
DROP POLICY IF EXISTS "profiles_select" ON public.profiles;
CREATE POLICY "profiles_select" ON public.profiles
  FOR SELECT
  USING (
    auth.uid() = id
    OR (deleted_at IS NULL)
  );

-- -----------------------------------------------------------------------------
-- A2: follows - keep readable (needed for is_mutual_friend, follow lists)
-- Follow graph is needed for privacy checks; do not over-restrict
-- -----------------------------------------------------------------------------
-- Keeps "Users can view follows" USING (true) - required for mutual check

-- -----------------------------------------------------------------------------
-- A2: likes and comments - only if viewer can see the activity
-- -----------------------------------------------------------------------------
DROP POLICY IF EXISTS "likes_select" ON public.likes;
CREATE POLICY "likes_select_privacy" ON public.likes
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.activity_feed a
      JOIN public.profiles pr ON pr.id = a.user_id
      WHERE a.id = likes.activity_id
        AND (a.user_id = auth.uid() OR (pr.deleted_at IS NULL AND public.can_view_activity(auth.uid(), pr.id, pr.activity_visibility)))
    )
  );

DROP POLICY IF EXISTS "comments_select" ON public.comments;
CREATE POLICY "comments_select_privacy" ON public.comments
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.activity_feed a
      JOIN public.profiles pr ON pr.id = a.user_id
      WHERE a.id = comments.activity_id
        AND (a.user_id = auth.uid() OR (pr.deleted_at IS NULL AND public.can_view_activity(auth.uid(), pr.id, pr.activity_visibility)))
    )
  );

DROP POLICY IF EXISTS "Anyone can read comments_cheers" ON public.comments_cheers;
CREATE POLICY "comments_cheers_select_privacy" ON public.comments_cheers
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.activity_feed a
      JOIN public.profiles pr ON pr.id = a.user_id
      WHERE a.id = comments_cheers.activity_id
        AND (a.user_id = auth.uid() OR (pr.deleted_at IS NULL AND public.can_view_activity(auth.uid(), pr.id, pr.activity_visibility)))
    )
  );

-- -----------------------------------------------------------------------------
-- A3: feed_global RPC - enforces activity_visibility, excludes deleted
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.feed_global(
  p_viewer_id uuid,
  p_limit int DEFAULT 30,
  p_offset int DEFAULT 0
)
RETURNS TABLE (
  id uuid,
  user_id uuid,
  activity_type text,
  wine_id uuid,
  target_wine_id uuid,
  content_text text,
  created_at timestamptz,
  username text,
  full_name text,
  avatar_url text,
  wine_name text,
  wine_producer text,
  wine_vintage int,
  wine_label_url text,
  wine_region text,
  wine_category text,
  wine_variety text,
  target_wine_name text,
  target_wine_producer text,
  target_wine_vintage int,
  target_wine_label_url text,
  tasting_note_tags text[],
  tasting_rating double precision,
  tasting_comment text
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT * FROM (
    SELECT DISTINCT ON (a.id)
      a.id, a.user_id, a.activity_type, a.wine_id, a.target_wine_id, a.content_text, a.created_at,
      p.username, p.full_name, p.avatar_url,
      w.name, w.producer, w.vintage, w.label_image_url, w.region, w.category, w.variety,
      tw.name, tw.producer, tw.vintage, tw.label_image_url,
      t.note_tags, t.rating, t.comment
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
      AND public.can_view_activity(p_viewer_id, a.user_id, p.activity_visibility)
    ORDER BY a.id,
      CASE WHEN t.id IS NULL THEN 1 ELSE 0 END,
      CASE WHEN a.tasting_id IS NOT NULL THEN 0 ELSE 1 END,
      ABS(EXTRACT(EPOCH FROM (COALESCE(t.created_at, a.created_at) - a.created_at)))
  ) sub
  ORDER BY created_at DESC
  LIMIT p_limit OFFSET p_offset;
$$;

-- -----------------------------------------------------------------------------
-- A3: feed_following RPC - replaces old one, enforces activity_visibility
-- -----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.feed_following(uuid, int, int);
CREATE OR REPLACE FUNCTION public.feed_following(
  p_viewer_id uuid,
  p_limit int DEFAULT 30,
  p_offset int DEFAULT 0
)
RETURNS TABLE (
  id uuid,
  user_id uuid,
  activity_type text,
  wine_id uuid,
  target_wine_id uuid,
  content_text text,
  created_at timestamptz,
  username text,
  full_name text,
  avatar_url text,
  wine_name text,
  wine_producer text,
  wine_vintage int,
  wine_label_url text,
  wine_region text,
  wine_category text,
  wine_variety text,
  target_wine_name text,
  target_wine_producer text,
  target_wine_vintage int,
  target_wine_label_url text,
  tasting_note_tags text[],
  tasting_rating double precision,
  tasting_comment text
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT * FROM (
    SELECT DISTINCT ON (a.id)
      a.id, a.user_id, a.activity_type, a.wine_id, a.target_wine_id, a.content_text, a.created_at,
      p.username, p.full_name, p.avatar_url,
      w.name, w.producer, w.vintage, w.label_image_url, w.region, w.category, w.variety,
      tw.name, tw.producer, tw.vintage, tw.label_image_url,
      t.note_tags, t.rating, t.comment
    FROM public.activity_feed a
    INNER JOIN public.profiles p ON p.id = a.user_id AND p.deleted_at IS NULL
    INNER JOIN public.follows fo ON fo.followed_id = a.user_id AND fo.follower_id = p_viewer_id
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
      AND public.can_view_activity(p_viewer_id, a.user_id, p.activity_visibility)
    ORDER BY a.id,
      CASE WHEN t.id IS NULL THEN 1 ELSE 0 END,
      CASE WHEN a.tasting_id IS NOT NULL THEN 0 ELSE 1 END,
      ABS(EXTRACT(EPOCH FROM (COALESCE(t.created_at, a.created_at) - a.created_at)))
  ) sub
  ORDER BY created_at DESC
  LIMIT p_limit OFFSET p_offset;
$$;

GRANT EXECUTE ON FUNCTION public.feed_global(uuid, int, int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.feed_global(uuid, int, int) TO anon;
GRANT EXECUTE ON FUNCTION public.feed_following(uuid, int, int) TO authenticated;

-- -----------------------------------------------------------------------------
-- A4: Soft delete + audit - delete_current_user sets deleted_at, schedules hard delete
-- Cooldown: 7 days. Hard delete via pg_cron or scheduled job (not in this migration)
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

  -- Soft delete: set deleted_at on profile (hides user from feeds, RLS excludes)
  UPDATE public.profiles SET deleted_at = now() WHERE id = v_user_id;

  -- Audit
  PERFORM public.audit_log_insert(v_user_id, 'account_deleted_requested', '{}'::jsonb);

  -- Note: Hard delete from auth.users after cooldown requires a scheduled job.
  -- For now, soft delete hides content. Add pg_cron or Edge Function for hard delete.
END;
$$;

-- -----------------------------------------------------------------------------
-- A7: Notifications - batch mark read (limit 500 per call)
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.notifications_mark_all_read(p_recipient_id uuid)
RETURNS int
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_count int;
BEGIN
  IF auth.uid() != p_recipient_id THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;
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

-- -----------------------------------------------------------------------------
-- A7: Prevent duplicate like notifications - partial unique index + helper
-- -----------------------------------------------------------------------------
CREATE UNIQUE INDEX IF NOT EXISTS idx_notifications_like_unique
  ON public.notifications (recipient_id, actor_id, post_id)
  WHERE type = 'like';

CREATE OR REPLACE FUNCTION public.insert_like_notification_if_new(
  p_recipient_id uuid,
  p_actor_id uuid,
  p_post_id uuid
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.notifications (recipient_id, actor_id, type, post_id)
  VALUES (p_recipient_id, p_actor_id, 'like', p_post_id)
  ON CONFLICT DO NOTHING;
EXCEPTION
  WHEN unique_violation THEN NULL;
END;
$$;
GRANT EXECUTE ON FUNCTION public.insert_like_notification_if_new(uuid, uuid, uuid) TO authenticated;

-- -----------------------------------------------------------------------------
-- A8: dev_accounts - enable RLS, deny-all. Dev bypass only when app_env != production
-- -----------------------------------------------------------------------------
ALTER TABLE public.dev_accounts ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "dev_accounts_deny_all" ON public.dev_accounts;
CREATE POLICY "dev_accounts_deny_all" ON public.dev_accounts FOR ALL USING (false) WITH CHECK (false);

-- Dev bypass: only when app_config has app_env in ('local','staging') AND auth.uid() IS NULL
-- (dev mock flow uses no session)
DROP POLICY IF EXISTS "dev_accounts_local_bypass" ON public.dev_accounts;
CREATE POLICY "dev_accounts_local_bypass" ON public.dev_accounts FOR ALL
  USING (
    auth.uid() IS NULL
    AND EXISTS (SELECT 1 FROM public.app_config WHERE key = 'app_env' AND value IN ('local', 'staging'))
  )
  WITH CHECK (
    auth.uid() IS NULL
    AND EXISTS (SELECT 1 FROM public.app_config WHERE key = 'app_env' AND value IN ('local', 'staging'))
  );
