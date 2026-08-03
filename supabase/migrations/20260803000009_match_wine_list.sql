-- ═══════════════════════════════════════════════════════════════════════════════
-- match_wine_list: batch catalog matching that is allowed to fail
-- 2026-08-03
--
-- A scanned list arrives as forty lines of imperfectly-read text. Two properties
-- matter and the existing search_wines has neither.
--
-- It must be batch. Forty round trips from a phone on restaurant wifi is not a
-- product, and the existing RPC answers one query at a time.
--
-- It must be able to say no. search_wines always returns its best guess, which is
-- correct for a search box where the person can see they got the wrong thing, and
-- wrong here, where a confidently mismatched wine becomes a bottle ordered at a
-- table. Below the confidence floor this returns a null match, and the UI shows the
-- line as unmatched. A gap is honest; a wrong wine is not.
-- ═══════════════════════════════════════════════════════════════════════════════

BEGIN;

CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- The `%` operator needs these to be indexable, otherwise every scanned line is a
-- sequential scan over the whole catalog.
CREATE INDEX IF NOT EXISTS idx_wines_name_trgm
  ON public.wines USING gin (name gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_wines_producer_trgm
  ON public.wines USING gin (producer gin_trgm_ops);

DROP FUNCTION IF EXISTS public.match_wine_list(text[], text[], real);
CREATE OR REPLACE FUNCTION public.match_wine_list(
  p_names text[],
  p_producers text[] DEFAULT NULL,
  p_min_confidence real DEFAULT 0.35
)
RETURNS TABLE (
  idx int,
  query_name text,
  wine_id uuid,
  name text,
  producer text,
  vintage int,
  variety text,
  region text,
  label_image_url text,
  category text,
  confidence real,
  -- Returned as real[] rather than vector so PostgREST emits a JSON array the client
  -- can use directly. Sent so a scanned list can be re-ranked on device without
  -- another round trip, which matters in the room this feature is used in.
  embedding real[]
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  WITH q AS (
    SELECT
      ord::int AS idx,
      btrim(nm) AS qname,
      btrim(COALESCE(p_producers[ord], '')) AS qproducer
    FROM unnest(p_names) WITH ORDINALITY AS t(nm, ord)
    WHERE btrim(COALESCE(nm, '')) <> ''
  )
  SELECT
    q.idx,
    q.qname,
    m.id,
    m.name,
    m.producer,
    m.vintage,
    m.variety,
    m.region,
    m.label_image_url,
    m.category,
    m.conf,
    m.embedding
  FROM q
  LEFT JOIN LATERAL (
    SELECT
      w.id, w.name, w.producer, w.vintage, w.variety, w.region,
      w.label_image_url, w.category,
      w.embedding::real[] AS embedding,
      -- Name carries most of the weight: a list prints the wine prominently and the
      -- producer inconsistently, and an absent producer should not sink a good match.
      (CASE WHEN q.qproducer = '' THEN similarity(w.name, q.qname)
            ELSE similarity(w.name, q.qname) * 0.7
               + similarity(w.producer, q.qproducer) * 0.3
       END)::real AS conf
    FROM public.wines w
    WHERE w.name % q.qname
       OR (q.qproducer <> '' AND w.producer % q.qproducer)
    ORDER BY conf DESC
    LIMIT 1
  ) m ON m.conf >= p_min_confidence
  ORDER BY q.idx;
$$;

GRANT EXECUTE ON FUNCTION public.match_wine_list(text[], text[], real) TO authenticated;

COMMENT ON FUNCTION public.match_wine_list(text[], text[], real) IS
  'Batch fuzzy match for scanned wine lists. Returns a null wine_id for lines that do not clear the confidence floor rather than guessing.';

-- ────────────────────────────────────────────────
-- get_my_taste_profile: the caller's own taste vector, as a plain array.
--
-- Cached on the device so a scanned list can be scored without the network. Only
-- ever your own: compute_user_taste_profile is SECURITY DEFINER and reads tastings
-- directly, so exposing it for arbitrary users would leak a palate.
-- ────────────────────────────────────────────────
DROP FUNCTION IF EXISTS public.get_my_taste_profile();
CREATE OR REPLACE FUNCTION public.get_my_taste_profile()
RETURNS real[]
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v vector(64);
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Not allowed' USING ERRCODE = '42501';
  END IF;
  v := compute_user_taste_profile(auth.uid());
  IF v IS NULL THEN
    RETURN NULL;   -- no tastings yet, so nothing to project from
  END IF;
  RETURN v::real[];
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_my_taste_profile() TO authenticated;

COMMIT;
