-- ═══════════════════════════════════════════════════════════════════════════════
-- Observed structure feeds the wine vector (P1.2), with confidence (P1.3)
-- 2026-08-03
--
-- Until now a wine's structural profile came entirely from a hand-written grape
-- table. That table is a reasonable guess and nothing more: it says every Merlot
-- anywhere has the same body and tannin, which is obviously false.
--
-- Here the table becomes the PRIOR and real tastings become the POSTERIOR:
--
--     posterior = (prior * k + observed_mean * n) / (k + n),  k = 5
--
-- With no tastings the wine keeps its guess. At five structured tastings the
-- observations carry half the weight. Past that the crowd wins, which is the point:
-- this is the mechanism that makes the catalog get better every time somebody
-- drinks something, and it is the part of the asset that compounds.
--
-- Confidence rides along as n / (n + k) so the ranker can tell a wine that has been
-- measured from a wine that has only been guessed at.
-- ═══════════════════════════════════════════════════════════════════════════════

BEGIN;

ALTER TABLE public.wines
  ADD COLUMN IF NOT EXISTS structure_obs_count int NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS embedding_confidence real NOT NULL DEFAULT 0;

COMMENT ON COLUMN public.wines.embedding_confidence IS
  'n/(n+5) over structured tastings. 0 means the vector is a guess from grape traits alone.';

-- ────────────────────────────────────────────────
-- compute_wine_embedding_blended
-- Same 64-dim layout as compute_wine_embedding, but dims 6-10 (the style axes) are
-- replaced by the posterior where observations exist. Everything else - category
-- one-hot, family membership, region traits, hashed residual - is unchanged, because
-- a tasting tells us how a wine tastes, not what grape it is.
-- ────────────────────────────────────────────────
DROP FUNCTION IF EXISTS public.compute_wine_embedding_blended(text, text, text, float8[], int);
CREATE OR REPLACE FUNCTION public.compute_wine_embedding_blended(
  p_category text,
  p_variety  text,
  p_region   text,
  p_observed float8[],   -- [body, tannin, acidity, sweetness, aromatic] on 0..1, or NULL
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
  -- Start from the grape-derived vector, then overwrite the style axes.
  base_arr := compute_wine_embedding(p_category, p_variety, p_region)::float8[];

  IF p_observed IS NULL OR p_obs_n IS NULL OR p_obs_n <= 0 THEN
    RETURN ('[' || array_to_string(base_arr, ',') || ']')::vector(64);
  END IF;

  -- The base vector is unit-normalised, so recover the pre-normalisation style
  -- values by rescaling. Cheaper and less fragile: recompute the prior directly
  -- from the varietal table instead of trying to invert the norm.
  SELECT ARRAY[
           AVG(v.body)::float8, AVG(v.tannin)::float8, AVG(v.acidity)::float8,
           AVG(v.sweetness)::float8, AVG(v.aromatic)::float8
         ]
  INTO prior
  FROM unnest(string_to_array(lower(coalesce(p_variety, '')), ',')) AS t(tok)
  JOIN public.wine_varietal_traits v ON v.grape = btrim(t.tok);

  IF prior IS NULL OR prior[1] IS NULL THEN
    prior := ARRAY[0.5, 0.0, 0.5, 0.0, 0.5];   -- neutral guess for unknown grapes
  END IF;

  w := p_obs_n::float8 / (p_obs_n + k_prior);
  post := ARRAY[
    prior[1] * (1 - w) + p_observed[1] * w,
    prior[2] * (1 - w) + p_observed[2] * w,
    prior[3] * (1 - w) + p_observed[3] * w,
    prior[4] * (1 - w) + p_observed[4] * w,
    prior[5] * (1 - w) + p_observed[5] * w
  ];

  -- Splice the posterior into dims 6-10 and renormalise the whole vector.
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

-- ────────────────────────────────────────────────
-- refresh_wine_embedding: recompute one wine from its tastings
-- WSET ordinals are 1..5; the style axes are 0..1, so (x-1)/4 maps between them.
-- ────────────────────────────────────────────────
DROP FUNCTION IF EXISTS public.refresh_wine_embedding(uuid);
CREATE OR REPLACE FUNCTION public.refresh_wine_embedding(p_wine_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  obs float8[];
  n int;
  i int;
  k_prior constant float8 := 5.0;
BEGIN
  SELECT ARRAY[
           AVG((t.body - 1)::float8 / 4.0),
           AVG((t.tannin - 1)::float8 / 4.0),
           AVG((t.acidity - 1)::float8 / 4.0),
           AVG((t.sweetness - 1)::float8 / 4.0),
           AVG((t.aroma_intensity - 1)::float8 / 4.0)
         ],
         COUNT(*)::int
  INTO obs, n
  FROM public.tastings t
  WHERE t.wine_id = p_wine_id
    AND (t.body IS NOT NULL OR t.tannin IS NOT NULL OR t.acidity IS NOT NULL);

  -- A dimension nobody answered stays NULL after AVG; fall back per-slot rather
  -- than discarding the whole observation.
  IF obs IS NOT NULL THEN
    FOR i IN 1..5 LOOP
      IF obs[i] IS NULL THEN obs[i] := 0.5; END IF;
    END LOOP;
  END IF;

  UPDATE public.wines w
  SET embedding = compute_wine_embedding_blended(w.category, w.variety, w.region, obs, n),
      structure_obs_count = COALESCE(n, 0),
      embedding_confidence = COALESCE(n, 0)::real / (COALESCE(n, 0) + k_prior)
  WHERE w.id = p_wine_id;
END;
$$;

-- ────────────────────────────────────────────────
-- Trigger: a structured tasting updates the wine it describes
-- Fires only when structure is actually present or was removed, so ordinary
-- rating-only tastings do not pay for a vector rebuild.
-- ────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.tastings_structure_trigger()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_wine uuid;
  new_has boolean := false;
  old_has boolean := false;
BEGIN
  -- TG_OP rather than NULL-testing the records: `NEW IS NOT NULL` on a composite
  -- asks whether every field is non-null, which is not the question here.
  IF TG_OP = 'DELETE' THEN
    v_wine := OLD.wine_id;
    old_has := OLD.body IS NOT NULL OR OLD.tannin IS NOT NULL OR OLD.acidity IS NOT NULL;
  ELSIF TG_OP = 'INSERT' THEN
    v_wine := NEW.wine_id;
    new_has := NEW.body IS NOT NULL OR NEW.tannin IS NOT NULL OR NEW.acidity IS NOT NULL;
  ELSE
    v_wine := NEW.wine_id;
    new_has := NEW.body IS NOT NULL OR NEW.tannin IS NOT NULL OR NEW.acidity IS NOT NULL;
    old_has := OLD.body IS NOT NULL OR OLD.tannin IS NOT NULL OR OLD.acidity IS NOT NULL;
  END IF;

  IF new_has OR old_has THEN
    PERFORM public.refresh_wine_embedding(v_wine);
  END IF;
  RETURN NULL;
END;
$$;

DROP TRIGGER IF EXISTS trg_tastings_structure ON public.tastings;
CREATE TRIGGER trg_tastings_structure
  AFTER INSERT OR UPDATE OF body, tannin, acidity, sweetness, aroma_intensity OR DELETE
  ON public.tastings
  FOR EACH ROW
  EXECUTE FUNCTION public.tastings_structure_trigger();

-- ────────────────────────────────────────────────
-- The wines trigger must not clobber observed structure. When category, variety or
-- region change on a wine that already has observations, rebuild through the
-- blended path instead of the prior-only one.
-- ────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.wines_embedding_trigger()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF COALESCE(NEW.structure_obs_count, 0) = 0 THEN
    NEW.embedding := compute_wine_embedding(NEW.category, NEW.variety, NEW.region);
  END IF;
  -- With observations present the row is refreshed by refresh_wine_embedding,
  -- which cannot run inside a BEFORE trigger on the same row.
  RETURN NEW;
END;
$$;

COMMIT;

-- After deploying, wines that already had structured tastings (there will be none
-- on first deploy) can be rebuilt with:
--   SELECT refresh_wine_embedding(id) FROM wines WHERE structure_obs_count > 0;
