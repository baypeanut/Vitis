-- ═══════════════════════════════════════════════════════════════════════════════
-- recommend_wines: personalised wine discovery
-- 2026-08-03
--
-- The pieces for this already existed and were simply never wired together:
-- compute_user_taste_profile returns a 64-dim taste vector, wines.embedding is
-- populated, and idx_wines_embedding_hnsw was built - but nothing ever queried the
-- index. The app could only tell you what your twins thought of a wine you were
-- already looking at; it could not tell you which wine to look at next.
--
-- Two stages:
--   1. Retrieval - approximate nearest neighbours over the HNSW index, giving a
--      cheap candidate pool ordered by cosine distance to the user's taste vector.
--   2. Ranking - blend content affinity with what the user's taste twins and the
--      wider community actually scored, shrunk toward the global mean so a single
--      10/10 from one person cannot outrank a well-supported 8.5.
--
-- Cold start (no tastings yet, so no taste vector) falls back to well-supported
-- community favourites rather than returning nothing.
-- ═══════════════════════════════════════════════════════════════════════════════

BEGIN;

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
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_profile vector(64);
  v_global_mean double precision;
  -- Prior strength for the Bayesian shrink. 5 ratings before the wine's own average
  -- outweighs the global mean.
  k_prior constant double precision := 5.0;
BEGIN
  IF auth.uid() IS NULL OR auth.uid() <> p_user_id THEN
    RAISE EXCEPTION 'Not allowed' USING ERRCODE = '42501';
  END IF;

  SELECT AVG(t.rating) INTO v_global_mean FROM public.tastings t;
  v_global_mean := COALESCE(v_global_mean, 7.0);

  v_profile := compute_user_taste_profile(p_user_id);

  -- ── Cold start: no tastings yet, so nothing to project from ──
  IF v_profile IS NULL THEN
    RETURN QUERY
    WITH comm AS (
      SELECT t.wine_id,
             AVG(t.rating) AS avg_rating,
             COUNT(*)::int AS n
      FROM public.tastings t
      GROUP BY t.wine_id
      HAVING COUNT(*) >= 1
    )
    SELECT w.id, w.name, w.producer, w.vintage, w.variety, w.region,
           w.label_image_url, w.category,
           NULL::double precision,
           NULL::double precision,
           0,
           c.avg_rating,
           c.n,
           (c.avg_rating * c.n + v_global_mean * k_prior) / (c.n + k_prior),
           'popular'::text
    FROM comm c
    JOIN public.wines w ON w.id = c.wine_id
    ORDER BY (c.avg_rating * c.n + v_global_mean * k_prior) / (c.n + k_prior) DESC,
             c.n DESC
    LIMIT p_limit;
    RETURN;
  END IF;

  RETURN QUERY
  WITH cand AS (
    -- Stage 1: ANN retrieval. ORDER BY <=> on the plain column is what lets the
    -- planner use idx_wines_embedding_hnsw; do not wrap the operand in an expression.
    SELECT w.id, w.name, w.producer, w.vintage, w.variety, w.region,
           w.label_image_url, w.category,
           GREATEST(0.0, 1.0 - (w.embedding <=> v_profile)) AS affinity
    FROM public.wines w
    WHERE w.embedding IS NOT NULL
      AND NOT EXISTS (
        SELECT 1 FROM public.tastings t
        WHERE t.wine_id = w.id AND t.user_id = p_user_id
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
    SELECT t.wine_id,
           AVG(t.rating) AS avg_rating,
           COUNT(*)::int AS n
    FROM public.tastings t
    WHERE t.wine_id IN (SELECT c.id FROM cand c)
    GROUP BY t.wine_id
  ),
  scored AS (
    SELECT c.*,
           tw.avg_rating AS twin_rating,
           COALESCE(tw.n, 0) AS twin_n,
           cm.avg_rating AS comm_rating,
           COALESCE(cm.n, 0) AS comm_n,
           -- Prefer what the user's twins scored; fall back to the community.
           COALESCE(tw.avg_rating, cm.avg_rating) AS raw_rating,
           COALESCE(tw.n, cm.n, 0) AS raw_n
    FROM cand c
    LEFT JOIN twin tw ON tw.wine_id = c.id
    LEFT JOIN comm cm ON cm.wine_id = c.id
  )
  SELECT s.id, s.name, s.producer, s.vintage, s.variety, s.region,
         s.label_image_url, s.category,
         s.affinity,
         s.twin_rating,
         s.twin_n,
         s.comm_rating,
         s.comm_n,
         -- Content affinity carries the ranking; the rating signal adjusts it, and a
         -- confidence term keeps thinly-rated wines from jumping the queue.
         ( 0.55 * s.affinity
         + 0.35 * (
             ((COALESCE(s.raw_rating, v_global_mean) * s.raw_n + v_global_mean * k_prior)
              / (s.raw_n + k_prior) - 1.0) / 9.0
           )
         + 0.10 * (s.raw_n::double precision / (s.raw_n + 10.0))
         ) AS score,
         CASE
           WHEN s.twin_n > 0 THEN 'twins'
           WHEN s.comm_n > 0 THEN 'community'
           ELSE 'taste_match'
         END::text AS reason
  FROM scored s
  ORDER BY score DESC
  LIMIT p_limit;
END;
$$;

GRANT EXECUTE ON FUNCTION public.recommend_wines(uuid, int, int) TO authenticated;

COMMIT;
