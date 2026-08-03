-- ═══════════════════════════════════════════════════════════════════════════════
-- recommend_wines v2: confidence-aware ranking (P1.3) + anti-concentration (P2.2)
-- 2026-08-03
--
-- Two changes, both to the same function, so they land together.
--
-- P1.3 CONFIDENCE
-- v1 treated a wine measured by forty tasters and a wine nobody has ever described
-- as equally certain. They are not. Rather than adding confidence as another term
-- in the sum, it scales the affinity term, because that is what confidence is
-- actually about: if we do not trust a wine's vector, its cosine similarity to your
-- palate is not a number worth ranking on. A pure guess keeps 60% of its affinity
-- weight; a well-measured wine keeps all of it.
--
-- P2.2 ANTI-CONCENTRATION
-- Recommender feedback loops drive exposure toward whatever is already popular, and
-- wine is the category that has already shown where that ends: under the 100-point
-- regime, producers began making wine to score rather than to express a place. A
-- recommender that quietly converges on the same 200 bottles is doing a small
-- version of the same thing.
--
-- So a fixed share of every result set is reserved for wines that fit the user's
-- palate but have had little exposure. This costs a little precision on purpose. It
-- is a product value, not a tuning parameter, and it is measurable: see
-- recommendation_concentration().
-- ═══════════════════════════════════════════════════════════════════════════════

BEGIN;

-- ────────────────────────────────────────────────
-- Exposure log. Without it we cannot tell whether we are homogenising.
-- ────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.recommendation_log (
  id bigserial PRIMARY KEY,
  user_id uuid NOT NULL,
  wine_id uuid NOT NULL,
  position int NOT NULL,
  score double precision,
  reason text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_rec_log_wine_time ON public.recommendation_log (wine_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_rec_log_time ON public.recommendation_log (created_at DESC);

-- Users have no reason to read this and every reason not to be able to write it.
ALTER TABLE public.recommendation_log ENABLE ROW LEVEL SECURITY;

-- ────────────────────────────────────────────────
-- recommend_wines v2
-- No longer STABLE: it records what it showed.
-- ────────────────────────────────────────────────
DROP FUNCTION IF EXISTS public.recommend_wines(uuid, int, int);
CREATE OR REPLACE FUNCTION public.recommend_wines(
  p_user_id uuid,
  p_limit int DEFAULT 20,
  p_candidate_pool int DEFAULT 400
)
RETURNS TABLE (
  id uuid,
  name text,
  producer text,
  vintage int,
  variety text,
  region text,
  label_image_url text,
  category text,
  affinity double precision,
  twin_avg double precision,
  twin_count int,
  community_avg double precision,
  community_count int,
  score double precision,
  reason text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_profile vector(64);
  v_global_mean double precision;
  v_explore int;
  k_prior constant double precision := 5.0;
  -- One in five slots is held for under-exposed wines. Low enough that the list
  -- still reads as personal, high enough to keep the tail alive.
  explore_fraction constant double precision := 0.2;
BEGIN
  IF auth.uid() IS NULL OR auth.uid() <> p_user_id THEN
    RAISE EXCEPTION 'Not allowed' USING ERRCODE = '42501';
  END IF;

  SELECT AVG(t.rating) INTO v_global_mean FROM public.tastings t;
  v_global_mean := COALESCE(v_global_mean, 7.0);

  v_profile := compute_user_taste_profile(p_user_id);
  v_explore := GREATEST(1, FLOOR(p_limit * explore_fraction)::int);

  -- ── Cold start: nothing to project from yet ──
  IF v_profile IS NULL THEN
    RETURN QUERY
    WITH comm AS (
      SELECT t.wine_id, AVG(t.rating) AS avg_rating, COUNT(*)::int AS n
      FROM public.tastings t
      GROUP BY t.wine_id
    )
    SELECT w.id, w.name, w.producer, w.vintage, w.variety, w.region,
           w.label_image_url, w.category,
           NULL::double precision, NULL::double precision, 0,
           c.avg_rating, c.n,
           (c.avg_rating * c.n + v_global_mean * k_prior) / (c.n + k_prior),
           'popular'::text
    FROM comm c
    JOIN public.wines w ON w.id = c.wine_id
    ORDER BY (c.avg_rating * c.n + v_global_mean * k_prior) / (c.n + k_prior) DESC, c.n DESC
    LIMIT p_limit;
    RETURN;
  END IF;

  RETURN QUERY
  WITH cand AS (
    -- ANN retrieval. The bare column in ORDER BY is what lets the planner reach
    -- idx_wines_embedding_hnsw; wrapping it in an expression loses the index.
    SELECT w.id, w.name, w.producer, w.vintage, w.variety, w.region,
           w.label_image_url, w.category,
           GREATEST(0.0, 1.0 - (w.embedding <=> v_profile)) AS affinity,
           w.embedding_confidence
    FROM public.wines w
    WHERE w.embedding IS NOT NULL
      AND NOT EXISTS (
        SELECT 1 FROM public.tastings t WHERE t.wine_id = w.id AND t.user_id = p_user_id
      )
    ORDER BY w.embedding <=> v_profile
    LIMIT p_candidate_pool
  ),
  twin AS (
    SELECT t.wine_id,
           SUM(t.rating * ts.score) / NULLIF(SUM(ts.score), 0) AS avg_rating,
           COUNT(*)::int AS n
    FROM public.tastings t
    JOIN public.taste_similarity ts ON (
      (ts.user_a = p_user_id AND ts.user_b = t.user_id) OR
      (ts.user_b = p_user_id AND ts.user_a = t.user_id)
    )
    WHERE t.wine_id IN (SELECT c.id FROM cand c)
      AND t.user_id <> p_user_id
      AND ts.score >= 0.30
    GROUP BY t.wine_id
  ),
  comm AS (
    SELECT t.wine_id, AVG(t.rating) AS avg_rating, COUNT(*)::int AS n
    FROM public.tastings t
    WHERE t.wine_id IN (SELECT c.id FROM cand c)
    GROUP BY t.wine_id
  ),
  exposure AS (
    SELECT r.wine_id, COUNT(*)::int AS impressions
    FROM public.recommendation_log r
    WHERE r.created_at > now() - interval '30 days'
      AND r.wine_id IN (SELECT c.id FROM cand c)
    GROUP BY r.wine_id
  ),
  scored AS (
    SELECT c.*,
           tw.avg_rating AS twin_rating,
           COALESCE(tw.n, 0) AS twin_n,
           cm.avg_rating AS comm_rating,
           COALESCE(cm.n, 0) AS comm_n,
           COALESCE(tw.avg_rating, cm.avg_rating) AS raw_rating,
           COALESCE(tw.n, cm.n, 0) AS raw_n,
           COALESCE(ex.impressions, 0) AS impressions,
           -- Confidence scales affinity rather than adding to the score.
           c.affinity * (0.6 + 0.4 * COALESCE(c.embedding_confidence, 0)) AS eff_affinity
    FROM cand c
    LEFT JOIN twin tw ON tw.wine_id = c.id
    LEFT JOIN comm cm ON cm.wine_id = c.id
    LEFT JOIN exposure ex ON ex.wine_id = c.id
  ),
  ranked AS (
    SELECT s.*,
           ( 0.55 * s.eff_affinity
           + 0.35 * (
               ((COALESCE(s.raw_rating, v_global_mean) * s.raw_n + v_global_mean * k_prior)
                / (s.raw_n + k_prior) - 1.0) / 9.0
             )
           + 0.10 * (s.raw_n::double precision / (s.raw_n + 10.0))
           ) AS final_score
    FROM scored s
  ),
  exploit AS (
    SELECT r.*, 'exploit'::text AS slot
    FROM ranked r
    ORDER BY r.final_score DESC
    LIMIT GREATEST(0, p_limit - v_explore)
  ),
  explore AS (
    -- Still has to fit the palate. This is under-exposed, not random.
    SELECT r.*, 'explore'::text AS slot
    FROM ranked r
    WHERE r.id NOT IN (SELECT e.id FROM exploit e)
      AND r.eff_affinity > 0.35
    ORDER BY r.impressions ASC, r.final_score DESC
    LIMIT v_explore
  ),
  final AS (
    SELECT * FROM exploit
    UNION ALL
    SELECT * FROM explore
  ),
  logged AS (
    INSERT INTO public.recommendation_log (user_id, wine_id, position, score, reason)
    SELECT p_user_id, f.id,
           ROW_NUMBER() OVER (ORDER BY f.final_score DESC),
           f.final_score,
           CASE WHEN f.slot = 'explore' THEN 'discovery'
                WHEN f.twin_n > 0 THEN 'twins'
                WHEN f.comm_n > 0 THEN 'community'
                ELSE 'taste_match' END
    FROM final f
    RETURNING 1
  )
  SELECT f.id, f.name, f.producer, f.vintage, f.variety, f.region,
         f.label_image_url, f.category,
         f.affinity, f.twin_rating, f.twin_n, f.comm_rating, f.comm_n,
         f.final_score,
         (CASE WHEN f.slot = 'explore' THEN 'discovery'
               WHEN f.twin_n > 0 THEN 'twins'
               WHEN f.comm_n > 0 THEN 'community'
               ELSE 'taste_match' END)::text
  FROM final f
  WHERE (SELECT COUNT(*) FROM logged) >= 0   -- forces the logging CTE to run
  ORDER BY f.final_score DESC;
END;
$$;

GRANT EXECUTE ON FUNCTION public.recommend_wines(uuid, int, int) TO authenticated;

-- ────────────────────────────────────────────────
-- recommendation_concentration: the guardrail metric
-- If top1pct_share climbs, we are becoming the thing we criticised.
-- ────────────────────────────────────────────────
DROP FUNCTION IF EXISTS public.recommendation_concentration(int);
CREATE OR REPLACE FUNCTION public.recommendation_concentration(p_days int DEFAULT 7)
RETURNS TABLE (
  total_impressions bigint,
  distinct_wines int,
  top1pct_share double precision,
  gini double precision
)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  WITH imp AS (
    SELECT wine_id, COUNT(*)::bigint AS n
    FROM public.recommendation_log
    WHERE created_at > now() - make_interval(days => p_days)
    GROUP BY wine_id
  ),
  ord AS (
    SELECT n, ROW_NUMBER() OVER (ORDER BY n ASC) AS rk, COUNT(*) OVER () AS total_wines
    FROM imp
  ),
  top AS (
    SELECT SUM(n) AS top_n
    FROM (
      SELECT n FROM imp ORDER BY n DESC
      LIMIT GREATEST(1, (SELECT CEIL(COUNT(*) * 0.01)::int FROM imp))
    ) t
  )
  SELECT
    COALESCE((SELECT SUM(n) FROM imp), 0)::bigint,
    COALESCE((SELECT COUNT(*)::int FROM imp), 0),
    CASE WHEN (SELECT SUM(n) FROM imp) > 0
         THEN (SELECT top_n FROM top)::double precision / (SELECT SUM(n) FROM imp)
         ELSE 0 END,
    CASE WHEN (SELECT COUNT(*) FROM ord) > 1
         THEN (2.0 * (SELECT SUM(rk * n) FROM ord))
              / ((SELECT MAX(total_wines) FROM ord) * (SELECT SUM(n) FROM ord))
              - ((SELECT MAX(total_wines) FROM ord) + 1.0) / (SELECT MAX(total_wines) FROM ord)
         ELSE 0 END;
$$;

GRANT EXECUTE ON FUNCTION public.recommendation_concentration(int) TO authenticated;

COMMIT;
