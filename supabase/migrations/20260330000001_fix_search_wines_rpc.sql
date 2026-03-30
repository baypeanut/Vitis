-- Fix: ensure search_wines RPC exists & is robust to punctuation.
-- 2026-03-30

-- Needed for similarity()
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- FTS index for fast search
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
  v_query text := trim(coalesce(p_query, ''));
  v_terms text[];
  v_tsquery tsquery;
  v_found int;
BEGIN
  IF v_query = '' THEN
    RETURN;
  END IF;

  -- Normalize: keep only alnum per token to avoid tsquery syntax errors
  v_terms := array(
    SELECT t
    FROM unnest(regexp_split_to_array(lower(v_query), '\s+')) raw(token)
    CROSS JOIN LATERAL regexp_replace(raw.token, '[^[:alnum:]]+', '', 'g') AS t
    WHERE t <> ''
  );

  IF coalesce(array_length(v_terms, 1), 0) = 0 THEN
    RETURN;
  END IF;

  -- Prefix-matching: ["chateau","mar"] -> "chateau:* & mar:*"
  v_tsquery := to_tsquery('simple', array_to_string(ARRAY(SELECT t || ':*' FROM unnest(v_terms) t), ' & '));

  -- Try FTS first
  RETURN QUERY
  SELECT w.id, w.name, w.producer, w.vintage, w.variety, w.region, w.label_image_url, w.category,
         ts_rank(to_tsvector('simple', coalesce(w.name,'') || ' ' || coalesce(w.producer,'')), v_tsquery) AS rank
  FROM public.wines w
  WHERE to_tsvector('simple', coalesce(w.name,'') || ' ' || coalesce(w.producer,'')) @@ v_tsquery
  ORDER BY rank DESC
  LIMIT p_limit;

  GET DIAGNOSTICS v_found = ROW_COUNT;

  -- Fallback: trigram similarity if FTS returned nothing
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

