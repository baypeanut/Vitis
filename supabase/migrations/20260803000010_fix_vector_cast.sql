-- ═══════════════════════════════════════════════════════════════════════════════
-- Fix: vector cannot be cast directly to double precision[]
-- 2026-08-03
--
-- pgvector supports `vector::real[]` but not `vector::float8[]`. Both
-- compute_user_taste_profile and compute_wine_embedding_blended used the latter,
-- so both raised at runtime on the first row they touched:
--
--   ERROR: cannot cast type vector to double precision[]
--
-- This was not a cosmetic problem. compute_user_taste_profile is the foundation of
-- the content-based half of the taste engine: the cold-start path in
-- compute_taste_similarity, all of recommend_wines, and get_my_taste_profile all
-- call it. It has never returned a profile for a user with any tasting.
--
-- It went unnoticed because every Swift caller catches and returns nil or an empty
-- array, so the failure surfaced as "no taste twins yet" rather than as an error.
-- A silent empty result is the most expensive kind of bug: it looks like a product
-- that has not warmed up.
--
-- Found by running the migrations against a real Postgres for the first time.
-- ═══════════════════════════════════════════════════════════════════════════════

BEGIN;

-- ────────────────────────────────────────────────
-- compute_user_taste_profile: rating-weighted average of the wines a user rated.
-- Body unchanged except the cast.
-- ────────────────────────────────────────────────
DROP FUNCTION IF EXISTS public.compute_user_taste_profile(uuid);
CREATE OR REPLACE FUNCTION public.compute_user_taste_profile(
  p_user_id uuid
)
RETURNS vector(64)
LANGUAGE plpgsql STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  profile float8[] := array_fill(0.0, ARRAY[64]);
  emb_arr float8[];
  v_weight float8;
  v_count int := 0;
  i int;
  norm float8 := 0.0;
  rec record;
BEGIN
  FOR rec IN
    SELECT t.rating, w.embedding
    FROM public.tastings t
    JOIN public.wines w ON w.id = t.wine_id
    WHERE t.user_id = p_user_id
      AND w.embedding IS NOT NULL
  LOOP
    -- Maps a 1-10 rating to -1..+1: a 10 pulls the profile toward the wine, a 1
    -- pushes away, and 5.5 is indifference.
    v_weight := (rec.rating - 5.5) / 4.5;
    -- vector -> real[] -> float8[]. The direct cast to float8[] does not exist.
    emb_arr := rec.embedding::real[]::float8[];
    FOR i IN 1..64 LOOP
      profile[i] := profile[i] + v_weight * emb_arr[i];
    END LOOP;
    v_count := v_count + 1;
  END LOOP;

  IF v_count = 0 THEN
    RETURN NULL;
  END IF;

  FOR i IN 1..64 LOOP
    profile[i] := profile[i] / v_count;
  END LOOP;

  FOR i IN 1..64 LOOP
    norm := norm + profile[i] * profile[i];
  END LOOP;
  norm := sqrt(norm);

  -- A user who rates everything at exactly 5.5 has no direction, and a zero vector
  -- is not a palate. Say so rather than returning something meaningless.
  IF norm = 0 THEN
    RETURN NULL;
  END IF;

  FOR i IN 1..64 LOOP
    profile[i] := profile[i] / norm;
  END LOOP;

  RETURN ('[' || array_to_string(profile, ',') || ']')::vector(64);
END;
$$;

GRANT EXECUTE ON FUNCTION public.compute_user_taste_profile(uuid) TO authenticated;

-- ────────────────────────────────────────────────
-- compute_wine_embedding_blended: same cast, same fix.
-- ────────────────────────────────────────────────
DROP FUNCTION IF EXISTS public.compute_wine_embedding_blended(text, text, text, float8[], int);
CREATE OR REPLACE FUNCTION public.compute_wine_embedding_blended(
  p_category text,
  p_variety  text,
  p_region   text,
  p_observed float8[],
  p_obs_n    int
)
RETURNS vector(64)
LANGUAGE plpgsql STABLE
AS $$
DECLARE
  base_arr float8[];
  prior float8[];
  post float8[];
  w float8;
  i int;
  norm float8 := 0.0;
  k_prior constant float8 := 5.0;
BEGIN
  base_arr := compute_wine_embedding(p_category, p_variety, p_region)::real[]::float8[];

  IF p_observed IS NULL OR p_obs_n IS NULL OR p_obs_n <= 0 THEN
    RETURN ('[' || array_to_string(base_arr, ',') || ']')::vector(64);
  END IF;

  SELECT ARRAY[
           AVG(v.body)::float8, AVG(v.tannin)::float8, AVG(v.acidity)::float8,
           AVG(v.sweetness)::float8, AVG(v.aromatic)::float8
         ]
  INTO prior
  FROM unnest(string_to_array(lower(coalesce(p_variety, '')), ',')) AS t(tok)
  JOIN public.wine_varietal_traits v ON v.grape = btrim(t.tok);

  IF prior IS NULL OR prior[1] IS NULL THEN
    prior := ARRAY[0.5, 0.0, 0.5, 0.0, 0.5];
  END IF;

  w := p_obs_n::float8 / (p_obs_n + k_prior);
  post := ARRAY[
    prior[1] * (1 - w) + p_observed[1] * w,
    prior[2] * (1 - w) + p_observed[2] * w,
    prior[3] * (1 - w) + p_observed[3] * w,
    prior[4] * (1 - w) + p_observed[4] * w,
    prior[5] * (1 - w) + p_observed[5] * w
  ];

  FOR i IN 1..5 LOOP
    base_arr[5 + i] := post[i];
  END LOOP;

  FOR i IN 1..64 LOOP
    norm := norm + base_arr[i] * base_arr[i];
  END LOOP;
  norm := sqrt(norm);
  IF norm > 0 THEN
    FOR i IN 1..64 LOOP
      base_arr[i] := base_arr[i] / norm;
    END LOOP;
  END IF;

  RETURN ('[' || array_to_string(base_arr, ',') || ']')::vector(64);
END;
$$;

COMMIT;
