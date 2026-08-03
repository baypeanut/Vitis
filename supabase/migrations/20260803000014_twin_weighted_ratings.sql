-- ═══════════════════════════════════════════════════════════════════════════════
-- Twin-weighted ratings: into the migration chain, and hardened
-- 2026-08-03
--
-- TWO PROBLEMS, ONE FILE.
--
-- 1. MISSING FROM THE CHAIN
-- get_twin_weighted_rating and get_twin_weighted_ratings_batch existed only in
-- setup_schema.sql. The app calls both on every wine card and across the feed, so a
-- database built from migrations alone was missing a core feature with no error at
-- build time - it would have failed at runtime, silently, the way the rest of this
-- stack fails.
--
-- 2. THE SAME AUTHORISATION HOLE AS THE TASTE TWIN RPCS
-- Both are SECURITY DEFINER and take p_user_id, with no check that the caller is
-- that user. Any authenticated caller could ask what another person's taste twins
-- scored a wine, which discloses both the existence of those twins and their
-- ratings. This is the same class of bug fixed in 20260803000001 for
-- get_taste_twins and compute_taste_similarity; these two were missed then because
-- that pass only examined the duplicated section of setup_schema.sql.
--
-- Every client call site already passes the current user's own id, so requiring it
-- changes nothing for the app.
-- ═══════════════════════════════════════════════════════════════════════════════

BEGIN;

DROP FUNCTION IF EXISTS public.get_twin_weighted_rating(uuid, uuid);
CREATE OR REPLACE FUNCTION public.get_twin_weighted_rating(
  p_user_id uuid,
  p_wine_id uuid
)
RETURNS TABLE (
  twin_weighted_avg double precision,
  twin_count int,
  community_avg double precision,
  community_count int
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_twin_sum double precision := 0;
  v_weight_sum double precision := 0;
  v_twin_count int := 0;
  v_comm_avg double precision;
  v_comm_count int;
  rec record;
BEGIN
  IF auth.uid() IS NULL OR auth.uid() <> p_user_id THEN
    RAISE EXCEPTION 'Not allowed' USING ERRCODE = '42501';
  END IF;

  FOR rec IN
    SELECT t.rating, ts.score
    FROM public.tastings t
    JOIN public.taste_similarity ts ON (
      (ts.user_a = p_user_id AND ts.user_b = t.user_id) OR
      (ts.user_b = p_user_id AND ts.user_a = t.user_id)
    )
    WHERE t.wine_id = p_wine_id
      AND t.user_id <> p_user_id
      AND ts.score >= 0.30
  LOOP
    v_twin_sum := v_twin_sum + rec.rating * rec.score;
    v_weight_sum := v_weight_sum + rec.score;
    v_twin_count := v_twin_count + 1;
  END LOOP;

  SELECT AVG(t.rating), COUNT(*)::int
  INTO v_comm_avg, v_comm_count
  FROM public.tastings t
  WHERE t.wine_id = p_wine_id;

  RETURN QUERY SELECT
    CASE WHEN v_twin_count > 0 AND v_weight_sum > 0 THEN v_twin_sum / v_weight_sum ELSE NULL END,
    v_twin_count,
    v_comm_avg,
    COALESCE(v_comm_count, 0);
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_twin_weighted_rating(uuid, uuid) TO authenticated;

DROP FUNCTION IF EXISTS public.get_twin_weighted_ratings_batch(uuid, uuid[]);
CREATE OR REPLACE FUNCTION public.get_twin_weighted_ratings_batch(
  p_user_id uuid,
  p_wine_ids uuid[]
)
RETURNS TABLE (
  wine_id uuid,
  twin_weighted_avg double precision,
  twin_count int,
  community_avg double precision,
  community_count int
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF auth.uid() IS NULL OR auth.uid() <> p_user_id THEN
    RAISE EXCEPTION 'Not allowed' USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  WITH twin_ratings AS (
    SELECT t.wine_id AS wid, t.rating, ts.score
    FROM public.tastings t
    JOIN public.taste_similarity ts ON (
      (ts.user_a = p_user_id AND ts.user_b = t.user_id) OR
      (ts.user_b = p_user_id AND ts.user_a = t.user_id)
    )
    WHERE t.wine_id = ANY(p_wine_ids)
      AND t.user_id <> p_user_id
      AND ts.score >= 0.30
  ),
  twin_agg AS (
    SELECT tr.wid,
           SUM(tr.rating * tr.score) / NULLIF(SUM(tr.score), 0) AS tw_avg,
           COUNT(*)::int AS tw_count
    FROM twin_ratings tr
    GROUP BY tr.wid
  ),
  community_agg AS (
    SELECT t.wine_id AS wid, AVG(t.rating) AS c_avg, COUNT(*)::int AS c_count
    FROM public.tastings t
    WHERE t.wine_id = ANY(p_wine_ids)
    GROUP BY t.wine_id
  )
  SELECT COALESCE(ta.wid, ca.wid),
         ta.tw_avg,
         COALESCE(ta.tw_count, 0),
         ca.c_avg,
         COALESCE(ca.c_count, 0)
  FROM community_agg ca
  FULL OUTER JOIN twin_agg ta ON ta.wid = ca.wid;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_twin_weighted_ratings_batch(uuid, uuid[]) TO authenticated;

COMMIT;
