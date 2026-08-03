-- ═══════════════════════════════════════════════════════════════════════════════
-- pgvector wine embeddings + per-user taste profiles
-- 2026-08-01
--
-- This block previously existed only in setup_schema.sql, so a database that was
-- brought up from migrations alone never got the vector extension, the wines.embedding
-- column, the HNSW index, or compute_user_taste_profile - and the hybrid similarity
-- that depends on them could not be created. Captured here as a migration so both
-- paths converge.
--
-- Ordered before the taste-twin hardening migration, which declares vector(64) locals.
-- ═══════════════════════════════════════════════════════════════════════════════

-- PHASE A: Predictive Palate Graph — pgvector Wine Embeddings + Hybrid Similarity
-- ═══════════════════════════════════════════════════════════════════════════════
--
-- Adds 64-dim feature-hashed embeddings to wines, computes per-user taste
-- profiles, and upgrades compute_taste_similarity to a hybrid blend:
--   hybrid = α × pearson_collaborative + (1 - α) × cosine_content
-- where α = shared_count / (shared_count + k), k = 10.
-- Cold-start solved: content similarity works with 0 shared wines.
-- ═══════════════════════════════════════════════════════════════════════════════

-- 1. Enable pgvector
CREATE EXTENSION IF NOT EXISTS vector;

-- 2. Add embedding column to wines
ALTER TABLE public.wines ADD COLUMN IF NOT EXISTS embedding vector(64);

-- ────────────────────────────────────────────────
-- compute_wine_embedding
-- Deterministic 64-dim feature vector from wine attributes using hashing trick.
--   Dims  1- 5: Category one-hot (Red, White, Sparkling, Rose, Unknown)
--   Dims  6-25: Variety signed random projection (md5 hash)
--   Dims 26-45: Region signed random projection (md5 hash)
--   Dims 46-64: Variety×Region cross-feature hash (interaction term)
-- Normalized to unit length for cosine similarity.
-- ────────────────────────────────────────────────
DROP FUNCTION IF EXISTS public.compute_wine_embedding(text, text, text);
CREATE OR REPLACE FUNCTION public.compute_wine_embedding(
  p_category text,
  p_variety  text,
  p_region   text
)
RETURNS vector(64)
LANGUAGE plpgsql IMMUTABLE
AS $$
DECLARE
  dims float8[] := array_fill(0.0, ARRAY[64]);
  h bytea;
  byte_val int;
  i int;
  norm float8 := 0.0;
BEGIN
  -- Dims 1-5: Category one-hot
  CASE lower(trim(COALESCE(p_category, '')))
    WHEN 'red'       THEN dims[1] := 1.0;
    WHEN 'white'     THEN dims[2] := 1.0;
    WHEN 'sparkling' THEN dims[3] := 1.0;
    WHEN 'rose'      THEN dims[4] := 1.0;
    WHEN 'rosé'      THEN dims[4] := 1.0;
    ELSE                   dims[5] := 0.5;
  END CASE;

  -- Dims 6-25: Variety signed random projection
  IF COALESCE(trim(p_variety), '') != '' THEN
    h := decode(md5(lower(trim(p_variety))), 'hex');
    FOR i IN 0..19 LOOP
      byte_val := get_byte(h, i % 16);
      dims[6 + i] := CASE WHEN (byte_val >> (i % 8)) & 1 = 1 THEN 1.0 ELSE -1.0 END;
    END LOOP;
  END IF;

  -- Dims 26-45: Region signed random projection
  IF COALESCE(trim(p_region), '') != '' THEN
    h := decode(md5(lower(trim(p_region))), 'hex');
    FOR i IN 0..19 LOOP
      byte_val := get_byte(h, i % 16);
      dims[26 + i] := CASE WHEN (byte_val >> (i % 8)) & 1 = 1 THEN 1.0 ELSE -1.0 END;
    END LOOP;
  END IF;

  -- Dims 46-64: Variety×Region interaction hash
  IF COALESCE(trim(p_variety), '') != '' AND COALESCE(trim(p_region), '') != '' THEN
    h := decode(md5(lower(trim(p_variety)) || '|' || lower(trim(p_region))), 'hex');
    FOR i IN 0..18 LOOP
      byte_val := get_byte(h, i % 16);
      dims[46 + i] := CASE WHEN (byte_val >> (i % 8)) & 1 = 1 THEN 0.7 ELSE -0.7 END;
    END LOOP;
  END IF;

  -- L2 normalize to unit vector
  FOR i IN 1..64 LOOP
    norm := norm + dims[i] * dims[i];
  END LOOP;
  norm := sqrt(norm);
  IF norm > 0 THEN
    FOR i IN 1..64 LOOP
      dims[i] := dims[i] / norm;
    END LOOP;
  END IF;

  RETURN ('[' || array_to_string(dims, ',') || ']')::vector(64);
END;
$$;

-- ────────────────────────────────────────────────
-- Trigger: auto-compute embedding on wine INSERT / UPDATE
-- ────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.wines_embedding_trigger()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.embedding := compute_wine_embedding(NEW.category, NEW.variety, NEW.region);
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_wines_embedding ON public.wines;
CREATE TRIGGER trg_wines_embedding
  BEFORE INSERT OR UPDATE OF category, variety, region
  ON public.wines
  FOR EACH ROW
  EXECUTE FUNCTION public.wines_embedding_trigger();

-- ────────────────────────────────────────────────
-- Backfill embeddings for existing wines
-- ────────────────────────────────────────────────
UPDATE public.wines
SET embedding = compute_wine_embedding(category, variety, region)
WHERE embedding IS NULL;

-- ────────────────────────────────────────────────
-- HNSW index for fast cosine similarity searches
-- ────────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_wines_embedding_hnsw
  ON public.wines USING hnsw (embedding vector_cosine_ops);

-- ────────────────────────────────────────────────
-- compute_user_taste_profile
-- Returns the user's 64-dim taste profile = rating-weighted average of wine embeddings.
-- Rating weight: (rating - 5.5) / 4.5  →  maps 1→-1.0, 5.5→0, 10→+1.0
-- Result normalized to unit vector. Returns NULL if user has no tastings with embeddings.
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
  v_rating float8;
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
    v_weight := (rec.rating - 5.5) / 4.5;
    -- Convert vector to float array for arithmetic
    emb_arr := rec.embedding::float8[];
    FOR i IN 1..64 LOOP
      profile[i] := profile[i] + v_weight * emb_arr[i];
    END LOOP;
    v_count := v_count + 1;
  END LOOP;

  IF v_count = 0 THEN
    RETURN NULL;
  END IF;

  -- Average
  FOR i IN 1..64 LOOP
    profile[i] := profile[i] / v_count;
  END LOOP;

  -- L2 normalize
  FOR i IN 1..64 LOOP
    norm := norm + profile[i] * profile[i];
  END LOOP;
  norm := sqrt(norm);
  IF norm > 0 THEN
    FOR i IN 1..64 LOOP
      profile[i] := profile[i] / norm;
    END LOOP;
  END IF;

  RETURN ('[' || array_to_string(profile, ',') || ']')::vector(64);
END;
$$;

GRANT EXECUTE ON FUNCTION public.compute_user_taste_profile(uuid) TO authenticated;
