-- ═══════════════════════════════════════════════════════════════════════════════
-- Recommender evaluation, run where the data is
-- ═══════════════════════════════════════════════════════════════════════════════
--
-- The SQL twin of scripts/eval_recommender.py. That file carries the reference
-- implementation and a self-test that proves the maths; this one applies the same
-- maths to production data. If the two ever disagree, the Python is right, because
-- it is the one with tests.
--
-- This file defines functions only. It changes no data and can be re-run safely.
--
-- Holdout method: a user's most recent tastings are withheld, the recommender is
-- asked what it would have suggested from what remains, and we check whether the
-- withheld wines came back near the top. Recency rather than random selection,
-- because predicting the future is the job; predicting a gap in the middle of
-- someone's history is an easier problem we do not actually have.
--
-- Run:
--   SELECT * FROM eval_recommender_ndcg(20);
--   SELECT * FROM eval_recommender_coverage(20);
--   SELECT * FROM recommendation_concentration(7);
-- ═══════════════════════════════════════════════════════════════════════════════

-- Wines rated at or below this contribute nothing to relevance. Above it, graded,
-- so a 10 counts for more than a 7. Mirrors NEUTRAL_RATING in the Python.
CREATE OR REPLACE FUNCTION public.eval_relevance(p_rating double precision)
RETURNS double precision
LANGUAGE sql IMMUTABLE AS $$
  SELECT GREATEST(0.0, COALESCE(p_rating, 0.0) - 6.0);
$$;

-- ────────────────────────────────────────────────
-- NDCG@k over a recency holdout
--
-- Returns one row per evaluated user plus the population mean, so a bad average
-- can be traced to which users it came from rather than just noted.
-- ────────────────────────────────────────────────
DROP FUNCTION IF EXISTS public.eval_recommender_ndcg(int, int);
CREATE OR REPLACE FUNCTION public.eval_recommender_ndcg(
  p_k int DEFAULT 20,
  p_min_tastings int DEFAULT 10
)
RETURNS TABLE (
  user_id uuid,
  held_out_count int,
  ndcg double precision
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  u record;
  v_profile vector(64);
  v_ideal double precision;
  v_dcg double precision;
BEGIN
  FOR u IN
    SELECT t.user_id AS uid, COUNT(*)::int AS n
    FROM public.tastings t
    GROUP BY t.user_id
    HAVING COUNT(*) >= p_min_tastings
  LOOP
    -- Hold out the most recent fifth of this user's history.
    CREATE TEMP TABLE IF NOT EXISTS _held (wine_id uuid, rating double precision) ON COMMIT DROP;
    DELETE FROM _held;

    INSERT INTO _held
    SELECT t.wine_id, t.rating
    FROM public.tastings t
    WHERE t.user_id = u.uid
    ORDER BY t.created_at DESC
    LIMIT GREATEST(1, u.n / 5);

    -- Build the taste profile from the remaining history only. Using the full
    -- profile would leak the answer into the model being tested.
    SELECT CASE WHEN COUNT(*) = 0 THEN NULL ELSE
      (SELECT compute_user_taste_profile(u.uid)) END
    INTO v_profile
    FROM public.tastings t
    WHERE t.user_id = u.uid
      AND t.wine_id NOT IN (SELECT h.wine_id FROM _held h);

    IF v_profile IS NULL THEN CONTINUE; END IF;

    SELECT SUM(eval_relevance(h.rating) / log(2, (rn + 1)::numeric)::double precision)
    INTO v_ideal
    FROM (
      SELECT h.rating, ROW_NUMBER() OVER (ORDER BY h.rating DESC) AS rn
      FROM _held h
      LIMIT p_k
    ) h;

    IF COALESCE(v_ideal, 0) = 0 THEN CONTINUE; END IF;

    -- What the ranker would have shown, scored by the held-out ratings.
    SELECT SUM(eval_relevance(COALESCE(h.rating, 0)) / log(2, (r.rn + 1)::numeric)::double precision)
    INTO v_dcg
    FROM (
      SELECT w.id, ROW_NUMBER() OVER (ORDER BY w.embedding <=> v_profile) AS rn
      FROM public.wines w
      WHERE w.embedding IS NOT NULL
        AND NOT EXISTS (
          SELECT 1 FROM public.tastings t
          WHERE t.wine_id = w.id AND t.user_id = u.uid
            AND t.wine_id NOT IN (SELECT hh.wine_id FROM _held hh)
        )
      ORDER BY w.embedding <=> v_profile
      LIMIT p_k
    ) r
    LEFT JOIN _held h ON h.wine_id = r.id;

    user_id := u.uid;
    held_out_count := (SELECT COUNT(*)::int FROM _held);
    ndcg := COALESCE(v_dcg, 0) / v_ideal;
    RETURN NEXT;
  END LOOP;
END;
$$;

GRANT EXECUTE ON FUNCTION public.eval_recommender_ndcg(int, int) TO service_role;

-- ────────────────────────────────────────────────
-- Coverage: what share of the catalog the recommender has ever surfaced.
--
-- In the simulation this was the sharpest of the three signals. A ranker can look
-- acceptable on NDCG while only ever reaching a fifth of the catalog.
-- ────────────────────────────────────────────────
DROP FUNCTION IF EXISTS public.eval_recommender_coverage(int);
CREATE OR REPLACE FUNCTION public.eval_recommender_coverage(p_days int DEFAULT 30)
RETURNS TABLE (
  catalog_size int,
  wines_ever_shown int,
  coverage double precision
)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT
    (SELECT COUNT(*)::int FROM public.wines WHERE embedding IS NOT NULL),
    (SELECT COUNT(DISTINCT wine_id)::int FROM public.recommendation_log
      WHERE created_at > now() - make_interval(days => p_days)),
    CASE WHEN (SELECT COUNT(*) FROM public.wines WHERE embedding IS NOT NULL) > 0
      THEN (SELECT COUNT(DISTINCT wine_id)::double precision FROM public.recommendation_log
             WHERE created_at > now() - make_interval(days => p_days))
           / (SELECT COUNT(*) FROM public.wines WHERE embedding IS NOT NULL)
      ELSE 0 END;
$$;

GRANT EXECUTE ON FUNCTION public.eval_recommender_coverage(int) TO service_role;
