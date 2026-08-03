-- ═══════════════════════════════════════════════════════════════════════════════
-- Vintage belongs to the bottle a user drank, not to the shared catalog row.
-- 2026-08-03
--
-- Before this migration `wines.vintage` was the only place a vintage could live,
-- and upsert_wine_from_scan wrote it there with COALESCE(w.vintage, p_vintage).
-- Consequence: the first user to scan a 2019 bottle stamped 2019 onto the shared
-- catalog row, and every later user of that wine saw - and logged - a vintage they
-- never drank. The follow-up attempt to put vintage into the match key traded that
-- for a second failure mode: one duplicate catalog row per vintage.
--
-- Fix: `tastings.vintage` is the source of truth for what was in the glass.
-- Catalog rows stay vintage-agnostic and a scan never mutates them.
-- ═══════════════════════════════════════════════════════════════════════════════

BEGIN;

-- ────────────────────────────────────────────────
-- 1. Per-tasting vintage
-- ────────────────────────────────────────────────
ALTER TABLE public.tastings
  ADD COLUMN IF NOT EXISTS vintage int NULL;

ALTER TABLE public.tastings
  DROP CONSTRAINT IF EXISTS tastings_vintage_range;
ALTER TABLE public.tastings
  ADD CONSTRAINT tastings_vintage_range
  CHECK (vintage IS NULL OR vintage BETWEEN 1800 AND 2100);

-- Carry whatever vintage the catalog row currently holds onto existing tastings so
-- history keeps rendering the value it renders today. Runs once; later tastings
-- carry their own vintage from the start.
UPDATE public.tastings t
SET vintage = w.vintage
FROM public.wines w
WHERE w.id = t.wine_id
  AND t.vintage IS NULL
  AND w.vintage IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_tastings_wine_vintage
  ON public.tastings (wine_id, vintage)
  WHERE vintage IS NOT NULL;

-- ────────────────────────────────────────────────
-- 2. upsert_wine_from_scan v3
--    Never writes vintage. Collapses to one catalog row per wine rather than one
--    per vintage, so ratings for a wine aggregate instead of fragmenting.
-- ────────────────────────────────────────────────
DROP FUNCTION IF EXISTS public.upsert_wine_from_scan(text, text, int, text, text, text);
CREATE OR REPLACE FUNCTION public.upsert_wine_from_scan(
  p_name text,
  p_producer text,
  p_vintage int DEFAULT NULL,   -- accepted for call compatibility; deliberately not persisted
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
  v_name_clean text := lower(trim(p_name));
  v_prod_clean text := lower(trim(p_producer));
BEGIN
  -- Exact match on name + producer. Vintage is not part of the key: one catalog
  -- row represents the wine across all of its vintages.
  -- Prefer the vintage-agnostic row when legacy per-vintage rows still exist.
  SELECT w.id INTO v_existing_id
  FROM public.wines w
  WHERE lower(trim(w.name)) = v_name_clean
    AND lower(trim(w.producer)) = v_prod_clean
  ORDER BY (w.vintage IS NULL) DESC, w.created_at ASC
  LIMIT 1;

  -- Fuzzy fallback for OCR noise in the scanned label.
  IF v_existing_id IS NULL THEN
    SELECT w.id INTO v_existing_id
    FROM public.wines w
    WHERE similarity(w.name, trim(p_name)) > 0.5
      AND similarity(w.producer, trim(p_producer)) > 0.4
    ORDER BY (w.vintage IS NULL) DESC,
             similarity(w.name, trim(p_name)) + similarity(w.producer, trim(p_producer)) DESC
    LIMIT 1;
  END IF;

  IF v_existing_id IS NOT NULL THEN
    -- Enrich wine-level attributes only. Vintage is bottle-level; it is never written here.
    UPDATE public.wines w SET
      variety  = COALESCE(w.variety,  NULLIF(trim(p_variety), '')),
      region   = COALESCE(w.region,   NULLIF(trim(p_region), '')),
      category = COALESCE(w.category, NULLIF(trim(p_category), ''))
    WHERE w.id = v_existing_id;
  ELSE
    -- New catalog entries are vintage-agnostic from the start.
    INSERT INTO public.wines (name, producer, vintage, variety, region, category)
    VALUES (trim(p_name), trim(p_producer), NULL,
            NULLIF(trim(p_variety), ''), NULLIF(trim(p_region), ''),
            NULLIF(trim(p_category), ''))
    RETURNING wines.id INTO v_existing_id;
  END IF;

  RETURN QUERY
  SELECT w.id, w.name, w.producer, w.vintage, w.variety,
         w.region, w.label_image_url, w.category
  FROM public.wines w
  WHERE w.id = v_existing_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.upsert_wine_from_scan(text, text, int, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.upsert_wine_from_scan(text, text, int, text, text, text) TO anon;

-- ────────────────────────────────────────────────
-- 3. Expose the tasting vintage to the feed
--    tasting_vintage is appended last in both RPCs so existing clients that decode
--    by key are unaffected.
-- ────────────────────────────────────────────────

-- feed_with_details: new column appended at the end, so CREATE OR REPLACE is legal.
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
  t.moment_image_url AS tasting_moment_image_url,
  t.vintage AS tasting_vintage
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

-- feed_global v3 — cursor-based, now carrying tasting_vintage
DROP FUNCTION IF EXISTS public.feed_global(uuid, int, timestamptz);
CREATE OR REPLACE FUNCTION public.feed_global(
  p_viewer_id uuid,
  p_limit int DEFAULT 30,
  p_cursor timestamptz DEFAULT NULL
)
RETURNS TABLE (
  id uuid, user_id uuid, activity_type text, wine_id uuid, target_wine_id uuid, content_text text, created_at timestamptz,
  username text, full_name text, avatar_url text,
  wine_name text, wine_producer text, wine_vintage int, wine_label_url text, wine_region text, wine_category text, wine_variety text,
  target_wine_name text, target_wine_producer text, target_wine_vintage int, target_wine_label_url text,
  tasting_note_tags text[], tasting_rating double precision, tasting_comment text, tasting_moment_image_url text,
  tasting_vintage int
)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT * FROM (
    SELECT DISTINCT ON (a.id)
      a.id, a.user_id, a.activity_type, a.wine_id, a.target_wine_id, a.content_text, a.created_at,
      p.username, p.full_name, p.avatar_url,
      w.name, w.producer, w.vintage, w.label_image_url, w.region, w.category, w.variety,
      tw.name, tw.producer, tw.vintage, tw.label_image_url,
      t.note_tags, t.rating, t.comment, t.moment_image_url, t.vintage
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
      AND (p_cursor IS NULL OR a.created_at < p_cursor)
    ORDER BY a.id, CASE WHEN t.id IS NULL THEN 1 ELSE 0 END, CASE WHEN a.tasting_id IS NOT NULL THEN 0 ELSE 1 END,
      ABS(EXTRACT(EPOCH FROM (COALESCE(t.created_at, a.created_at) - a.created_at)))
  ) sub
  ORDER BY created_at DESC
  LIMIT p_limit;
$$;
GRANT EXECUTE ON FUNCTION public.feed_global(uuid, int, timestamptz) TO authenticated;
GRANT EXECUTE ON FUNCTION public.feed_global(uuid, int, timestamptz) TO anon;

-- feed_following v3 — cursor-based, now carrying tasting_vintage
DROP FUNCTION IF EXISTS public.feed_following(uuid, int, timestamptz);
CREATE OR REPLACE FUNCTION public.feed_following(
  p_viewer_id uuid,
  p_limit int DEFAULT 30,
  p_cursor timestamptz DEFAULT NULL
)
RETURNS TABLE (
  id uuid, user_id uuid, activity_type text, wine_id uuid, target_wine_id uuid, content_text text, created_at timestamptz,
  username text, full_name text, avatar_url text,
  wine_name text, wine_producer text, wine_vintage int, wine_label_url text, wine_region text, wine_category text, wine_variety text,
  target_wine_name text, target_wine_producer text, target_wine_vintage int, target_wine_label_url text,
  tasting_note_tags text[], tasting_rating double precision, tasting_comment text, tasting_moment_image_url text,
  tasting_vintage int
)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT * FROM (
    SELECT DISTINCT ON (a.id)
      a.id, a.user_id, a.activity_type, a.wine_id, a.target_wine_id, a.content_text, a.created_at,
      p.username, p.full_name, p.avatar_url,
      w.name, w.producer, w.vintage, w.label_image_url, w.region, w.category, w.variety,
      tw.name, tw.producer, tw.vintage, tw.label_image_url,
      t.note_tags, t.rating, t.comment, t.moment_image_url, t.vintage
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
      AND (p_cursor IS NULL OR a.created_at < p_cursor)
    ORDER BY a.id, CASE WHEN t.id IS NULL THEN 1 ELSE 0 END, CASE WHEN a.tasting_id IS NOT NULL THEN 0 ELSE 1 END,
      ABS(EXTRACT(EPOCH FROM (COALESCE(t.created_at, a.created_at) - a.created_at)))
  ) sub
  ORDER BY created_at DESC
  LIMIT p_limit;
$$;
GRANT EXECUTE ON FUNCTION public.feed_following(uuid, int, timestamptz) TO authenticated;

COMMIT;

-- Not repaired here: catalog rows whose wines.vintage was stamped by an earlier scan.
-- A legitimately vintage-specific row (some OFF imports) is indistinguishable from a
-- poisoned one, so clearing them wholesale would destroy real data. Existing tastings
-- keep the value they already displayed via the backfill above; every tasting created
-- from here on carries its own vintage.
