-- ═══════════════════════════════════════════════════════════════════════════════
-- SECURITY: restore caller authorization on the Taste Twin RPCs
-- 2026-08-03
--
-- setup_schema.sql contained section "12. Taste Twin Engine" twice. The first copy
-- guarded both RPCs against being called for other people; the second copy did not.
-- Because the later definition wins, the deployed functions are the unguarded ones,
-- and a security fix was silently reverted by a copy-paste.
--
-- Both are SECURITY DEFINER, so they bypass the RLS on taste_similarity that would
-- otherwise restrict rows to `auth.uid() = user_a OR auth.uid() = user_b`. As shipped:
--
--   * get_taste_twins(<any uuid>)  - returns that person's taste twins, similarity
--                                    scores and shared counts to any authenticated caller
--   * compute_taste_similarity(a,b) - computes and caches similarity for two arbitrary
--                                     users, so it is also an unmetered write path
--
-- Every client call site passes the current user's own id, so requiring that is not a
-- behaviour change for the app - only for a caller doing something it should not.
-- ═══════════════════════════════════════════════════════════════════════════════

BEGIN;

-- ────────────────────────────────────────────────
-- get_taste_twins: caller may only read their own twins.
-- Converted to plpgsql so the denial is explicit rather than a silent empty result.
-- ────────────────────────────────────────────────
DROP FUNCTION IF EXISTS public.get_taste_twins(uuid, int);
CREATE OR REPLACE FUNCTION public.get_taste_twins(
  p_user_id uuid,
  p_limit int DEFAULT 20
)
RETURNS TABLE (
  twin_id uuid,
  username text,
  full_name text,
  avatar_url text,
  score double precision,
  shared_count int,
  computed_at timestamptz
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
  SELECT
    CASE WHEN ts.user_a = p_user_id THEN ts.user_b ELSE ts.user_a END,
    p.username,
    p.full_name,
    p.avatar_url,
    ts.score,
    ts.shared_count,
    ts.computed_at
  FROM public.taste_similarity ts
  JOIN public.profiles p
    ON p.id = CASE WHEN ts.user_a = p_user_id THEN ts.user_b ELSE ts.user_a END
  WHERE (ts.user_a = p_user_id OR ts.user_b = p_user_id)
    AND ts.score >= 0.30
    AND p.deleted_at IS NULL
  ORDER BY ts.score DESC
  LIMIT p_limit;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_taste_twins(uuid, int) TO authenticated;

-- ────────────────────────────────────────────────
-- compute_taste_similarity: caller must be one of the two users.
-- Body is the Phase A hybrid (Pearson x cosine) with the guard restored.
-- ────────────────────────────────────────────────
DROP FUNCTION IF EXISTS public.compute_taste_similarity(uuid, uuid);
CREATE OR REPLACE FUNCTION public.compute_taste_similarity(
  p_user_a uuid,
  p_user_b uuid
)
RETURNS TABLE (
  user_a uuid,
  user_b uuid,
  score double precision,
  shared_count int,
  computed_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_a uuid;
  v_b uuid;
  v_score double precision;
  v_shared int;
  v_computed timestamptz;
  v_pearson double precision;
  v_cosine double precision;
  v_alpha double precision;
  v_profile_a vector(64);
  v_profile_b vector(64);
  k_shrinkage constant double precision := 10.0;
BEGIN
  -- Only allow the caller to compute similarities that involve themselves.
  IF auth.uid() IS NULL OR (auth.uid() <> p_user_a AND auth.uid() <> p_user_b) THEN
    RAISE EXCEPTION 'Not allowed' USING ERRCODE = '42501';
  END IF;

  -- Canonical ordering: smaller UUID first
  IF p_user_a < p_user_b THEN
    v_a := p_user_a; v_b := p_user_b;
  ELSE
    v_a := p_user_b; v_b := p_user_a;
  END IF;

  -- Check cache (7-day TTL)
  SELECT ts.score, ts.shared_count, ts.computed_at
  INTO v_score, v_shared, v_computed
  FROM public.taste_similarity ts
  WHERE ts.user_a = v_a AND ts.user_b = v_b
    AND ts.computed_at > now() - interval '7 days';

  IF FOUND THEN
    RETURN QUERY SELECT v_a, v_b, v_score, v_shared, v_computed;
    RETURN;
  END IF;

  -- ── Signal 1: Collaborative (Bayesian-shrunk Pearson) ──
  SELECT
    CASE WHEN COUNT(*) < 2 THEN NULL
         WHEN STDDEV(ta_r) = 0 OR STDDEV(tb_r) = 0 THEN 0.0
         ELSE CORR(ta_r, tb_r) * (COUNT(*)::double precision / (COUNT(*) + k_shrinkage))
    END,
    COUNT(*)::int
  INTO v_pearson, v_shared
  FROM (
    SELECT ta.rating AS ta_r, tb.rating AS tb_r
    FROM public.tastings ta
    JOIN public.tastings tb ON ta.wine_id = tb.wine_id
    WHERE ta.user_id = v_a AND tb.user_id = v_b
  ) shared;

  -- ── Signal 2: Content-based (cosine of taste profiles) ──
  v_profile_a := compute_user_taste_profile(v_a);
  v_profile_b := compute_user_taste_profile(v_b);

  IF v_profile_a IS NOT NULL AND v_profile_b IS NOT NULL THEN
    -- pgvector cosine distance = 1 - cosine_similarity, so invert
    v_cosine := 1.0 - (v_profile_a <=> v_profile_b);
    v_cosine := GREATEST(0.0, v_cosine);
  ELSE
    v_cosine := NULL;
  END IF;

  -- ── Blend ──
  IF v_pearson IS NOT NULL AND v_cosine IS NOT NULL THEN
    v_alpha := v_shared::double precision / (v_shared + k_shrinkage);
    v_score := v_alpha * v_pearson + (1.0 - v_alpha) * v_cosine;
  ELSIF v_cosine IS NOT NULL THEN
    -- Content-only (cold-start): cosine with a dampening factor
    v_score := v_cosine * 0.85;
  ELSIF v_pearson IS NOT NULL THEN
    v_score := v_pearson;
  ELSE
    DELETE FROM public.taste_similarity
    WHERE taste_similarity.user_a = v_a AND taste_similarity.user_b = v_b;
    RETURN;
  END IF;

  v_score := GREATEST(0.0, LEAST(1.0, v_score));
  v_computed := now();

  INSERT INTO public.taste_similarity (user_a, user_b, score, shared_count, computed_at)
  VALUES (v_a, v_b, v_score, COALESCE(v_shared, 0), v_computed)
  ON CONFLICT (user_a, user_b) DO UPDATE SET
    score = EXCLUDED.score,
    shared_count = EXCLUDED.shared_count,
    computed_at = EXCLUDED.computed_at;

  RETURN QUERY SELECT v_a, v_b, v_score, COALESCE(v_shared, 0), v_computed;
END;
$$;

GRANT EXECUTE ON FUNCTION public.compute_taste_similarity(uuid, uuid) TO authenticated;

COMMIT;
