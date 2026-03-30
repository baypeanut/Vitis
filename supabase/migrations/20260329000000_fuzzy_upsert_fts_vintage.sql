-- ═══════════════════════════════════════════════════════════════════════════════
-- Phase 1: Data Integrity & Search Performance
-- 2026-03-29
--
-- 1. Fuzzy-aware upsert_wine_from_scan (trigram matching, not just exact)
-- 2. Vintage included in scan upsert matching key
-- 3. OFF ↔ Scan reconciliation (cross-reference off_code)
-- 4. Full-text search RPC replacing ILIKE
-- ═══════════════════════════════════════════════════════════════════════════════

-- Ensure pg_trgm is available
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- ────────────────────────────────────────────────
-- 1. Upgraded upsert_wine_from_scan with fuzzy matching + vintage key
--    Now uses trigram similarity as fallback when exact match fails.
--    Vintage is part of the matching key (NULL vintage matches any).
-- ────────────────────────────────────────────────
DROP FUNCTION IF EXISTS public.upsert_wine_from_scan(text, text, int, text, text, text);
CREATE OR REPLACE FUNCTION public.upsert_wine_from_scan(
  p_name text,
  p_producer text,
  p_vintage int DEFAULT NULL,
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
  -- Step 1: Exact match on name + producer (case-insensitive) + vintage
  SELECT w.id INTO v_existing_id
  FROM public.wines w
  WHERE lower(trim(w.name)) = v_name_clean
    AND lower(trim(w.producer)) = v_prod_clean
    AND (p_vintage IS NULL OR w.vintage IS NULL OR w.vintage = p_vintage)
  LIMIT 1;

  -- Step 2: Fuzzy match fallback (trigram similarity > 0.5 for name, > 0.4 for producer)
  IF v_existing_id IS NULL THEN
    SELECT w.id INTO v_existing_id
    FROM public.wines w
    WHERE similarity(w.name, trim(p_name)) > 0.5
      AND similarity(w.producer, trim(p_producer)) > 0.4
      AND (p_vintage IS NULL OR w.vintage IS NULL OR w.vintage = p_vintage)
    ORDER BY similarity(w.name, trim(p_name)) + similarity(w.producer, trim(p_producer)) DESC
    LIMIT 1;
  END IF;

  IF v_existing_id IS NOT NULL THEN
    -- Enrich existing wine with any new fields
    UPDATE public.wines w SET
      vintage  = COALESCE(w.vintage,  p_vintage),
      variety  = COALESCE(w.variety,  NULLIF(trim(p_variety), '')),
      region   = COALESCE(w.region,   NULLIF(trim(p_region), '')),
      category = COALESCE(w.category, NULLIF(trim(p_category), ''))
    WHERE w.id = v_existing_id;

    RETURN QUERY
    SELECT w.id, w.name, w.producer, w.vintage, w.variety,
           w.region, w.label_image_url, w.category
    FROM public.wines w WHERE w.id = v_existing_id;
  ELSE
    RETURN QUERY
    INSERT INTO public.wines (name, producer, vintage, variety, region, category)
    VALUES (trim(p_name), trim(p_producer), p_vintage,
            NULLIF(trim(p_variety), ''), NULLIF(trim(p_region), ''),
            NULLIF(trim(p_category), ''))
    RETURNING wines.id, wines.name, wines.producer, wines.vintage,
              wines.variety, wines.region, wines.label_image_url, wines.category;
  END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION public.upsert_wine_from_scan(text, text, int, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.upsert_wine_from_scan(text, text, int, text, text, text) TO anon;

-- ────────────────────────────────────────────────
-- 2. Upgraded upsert_wine_from_off with fuzzy cross-reference
--    When off_code doesn't match, tries fuzzy name+producer match
--    to reconcile OFF imports with scan-created wines.
-- ────────────────────────────────────────────────
DROP FUNCTION IF EXISTS public.upsert_wine_from_off(text, text, text, text, text);
DROP FUNCTION IF EXISTS public.upsert_wine_from_off(text, text, text, text, text, text);
CREATE OR REPLACE FUNCTION public.upsert_wine_from_off(
  p_off_code text,
  p_name text,
  p_producer text,
  p_region text DEFAULT NULL,
  p_label_url text DEFAULT NULL,
  p_category text DEFAULT NULL
)
RETURNS TABLE (id uuid, name text, producer text, vintage int, variety text, region text, label_image_url text, category text)
LANGUAGE plpgsql
AS $$
DECLARE
  v_existing_id uuid;
BEGIN
  -- Step 1: Match by off_code (primary key for OFF products)
  SELECT w.id INTO v_existing_id
  FROM public.wines w
  WHERE w.off_code = p_off_code;

  IF v_existing_id IS NOT NULL THEN
    -- Update existing OFF wine
    UPDATE public.wines w SET
      name = p_name,
      producer = p_producer,
      region = COALESCE(NULLIF(trim(p_region), ''), w.region),
      label_image_url = COALESCE(NULLIF(trim(p_label_url), ''), w.label_image_url),
      category = COALESCE(NULLIF(trim(p_category), ''), w.category)
    WHERE w.id = v_existing_id;

    RETURN QUERY
    SELECT w.id, w.name, w.producer, w.vintage, w.variety, w.region, w.label_image_url, w.category
    FROM public.wines w WHERE w.id = v_existing_id;
    RETURN;
  END IF;

  -- Step 2: Cross-reference — maybe this wine was added via scan (no off_code)
  -- Try exact match first
  SELECT w.id INTO v_existing_id
  FROM public.wines w
  WHERE w.off_code IS NULL
    AND lower(trim(w.name)) = lower(trim(p_name))
    AND lower(trim(w.producer)) = lower(trim(p_producer))
  LIMIT 1;

  -- Step 3: Fuzzy match fallback for scan-created wines
  IF v_existing_id IS NULL THEN
    SELECT w.id INTO v_existing_id
    FROM public.wines w
    WHERE w.off_code IS NULL
      AND similarity(w.name, trim(p_name)) > 0.5
      AND similarity(w.producer, trim(p_producer)) > 0.4
    ORDER BY similarity(w.name, trim(p_name)) + similarity(w.producer, trim(p_producer)) DESC
    LIMIT 1;
  END IF;

  IF v_existing_id IS NOT NULL THEN
    -- Reconcile: attach off_code to existing scan-created wine + enrich
    UPDATE public.wines w SET
      off_code = p_off_code,
      region = COALESCE(NULLIF(trim(p_region), ''), w.region),
      label_image_url = COALESCE(NULLIF(trim(p_label_url), ''), w.label_image_url),
      category = COALESCE(NULLIF(trim(p_category), ''), w.category)
    WHERE w.id = v_existing_id;

    RETURN QUERY
    SELECT w.id, w.name, w.producer, w.vintage, w.variety, w.region, w.label_image_url, w.category
    FROM public.wines w WHERE w.id = v_existing_id;
  ELSE
    -- No match at all: insert new wine
    INSERT INTO public.wines (off_code, name, producer, region, label_image_url, category)
    VALUES (p_off_code, p_name, p_producer, NULLIF(trim(p_region), ''), NULLIF(trim(p_label_url), ''), NULLIF(trim(p_category), ''));

    RETURN QUERY
    SELECT w.id, w.name, w.producer, w.vintage, w.variety, w.region, w.label_image_url, w.category
    FROM public.wines w WHERE w.off_code = p_off_code;
  END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION public.upsert_wine_from_off(text, text, text, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.upsert_wine_from_off(text, text, text, text, text, text) TO anon;

-- ────────────────────────────────────────────────
-- 3. Full-text search RPC replacing ILIKE
--    Uses to_tsquery for prefix matching + trigram similarity ranking.
--    Falls back to trigram-only when FTS returns nothing.
-- ────────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_wines_fts ON public.wines
  USING gin (to_tsvector('simple', coalesce(name,'') || ' ' || coalesce(producer,'')));

DROP FUNCTION IF EXISTS public.search_wines(text, int);
CREATE OR REPLACE FUNCTION public.search_wines(
  p_query text,
  p_limit int DEFAULT 30
)
RETURNS TABLE (
  id uuid, name text, producer text, vintage int,
  variety text, region text, label_image_url text, category text,
  rank real
)
LANGUAGE plpgsql STABLE
AS $$
DECLARE
  v_query text := trim(p_query);
  v_tsquery tsquery;
  v_found int;
BEGIN
  -- Build prefix-matching tsquery: "chateau mar" → "chateau:* & mar:*"
  v_tsquery := to_tsquery('simple',
    array_to_string(
      array(SELECT lexeme || ':*' FROM unnest(string_to_array(v_query, ' ')) AS lexeme WHERE lexeme <> ''),
      ' & '
    )
  );

  -- Try FTS first (fast, uses GIN index)
  RETURN QUERY
  SELECT w.id, w.name, w.producer, w.vintage, w.variety, w.region, w.label_image_url, w.category,
         ts_rank(to_tsvector('simple', coalesce(w.name,'') || ' ' || coalesce(w.producer,'')), v_tsquery) AS rank
  FROM public.wines w
  WHERE to_tsvector('simple', coalesce(w.name,'') || ' ' || coalesce(w.producer,'')) @@ v_tsquery
  ORDER BY rank DESC
  LIMIT p_limit;

  GET DIAGNOSTICS v_found = ROW_COUNT;

  -- Fallback to trigram similarity if FTS returned nothing
  IF v_found = 0 THEN
    RETURN QUERY
    SELECT w.id, w.name, w.producer, w.vintage, w.variety, w.region, w.label_image_url, w.category,
           (similarity(w.name, v_query) + similarity(w.producer, v_query))::real AS rank
    FROM public.wines w
    WHERE similarity(w.name, v_query) > 0.15
       OR similarity(w.producer, v_query) > 0.15
    ORDER BY rank DESC
    LIMIT p_limit;
  END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION public.search_wines(text, int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.search_wines(text, int) TO anon;

-- ────────────────────────────────────────────────
-- 4. Seed wines for cold start (staff picks)
--    These ensure new users see some wines even with empty feed.
-- ────────────────────────────────────────────────
INSERT INTO public.wines (name, producer, vintage, variety, region, category)
VALUES
  ('Sassicaia', 'Tenuta San Guido', 2020, 'Cabernet Sauvignon', 'Tuscany', 'Red'),
  ('Opus One', 'Opus One Winery', 2019, 'Cabernet Sauvignon', 'Napa Valley', 'Red'),
  ('Cloudy Bay', 'Cloudy Bay Vineyards', 2023, 'Sauvignon Blanc', 'Marlborough', 'White'),
  ('Dom Pérignon', 'Moët & Chandon', 2015, 'Chardonnay', 'Champagne', 'Sparkling'),
  ('Whispering Angel', 'Caves d''Esclans', 2023, 'Grenache', 'Provence', 'Rose'),
  ('Penfolds Grange', 'Penfolds', 2018, 'Shiraz', 'South Australia', 'Red'),
  ('Antinori Tignanello', 'Marchesi Antinori', 2020, 'Sangiovese', 'Tuscany', 'Red'),
  ('Château Margaux', 'Château Margaux', 2018, 'Cabernet Sauvignon', 'Bordeaux', 'Red'),
  ('Barolo Monfortino', 'Giacomo Conterno', 2016, 'Nebbiolo', 'Piedmont', 'Red'),
  ('Puligny-Montrachet', 'Domaine Leflaive', 2021, 'Chardonnay', 'Burgundy', 'White'),
  ('Amarone della Valpolicella', 'Bertani', 2017, 'Corvina', 'Veneto', 'Red'),
  ('Caymus Special Selection', 'Caymus Vineyards', 2019, 'Cabernet Sauvignon', 'Napa Valley', 'Red')
ON CONFLICT DO NOTHING;
