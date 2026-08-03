-- ═══════════════════════════════════════════════════════════════════════════════
-- A cellar that is actually a cellar
-- 2026-08-03
--
-- Today "cellar" in Pari means a had-and-wishlist list. It is named after a job it
-- does not do. The comparison worth studying is CellarTracker, which has held close
-- to nine million users for two decades on inventory and drinking windows alone,
-- sitting beside Vivino rather than under it. That is a different job and it is the
-- one with recurring reasons to open an app.
--
-- Two things this adds that the list cannot express:
--
--   BOTTLES YOU OWN. Quantity, vintage, what you paid, where it is. A wine you have
--   three of is a different object from a wine you once drank.
--
--   DRINKING WINDOWS. The cellar's real product. A bottle past its window is a loss
--   the app should have prevented, and nothing else in Pari can warn you.
--
-- The window is estimated from structure, not looked up: tannin and acidity are what
-- carry a wine through time, so a dense tannic red gets years and a light aromatic
-- white gets months. It is a rough model and it is labelled as an estimate wherever
-- it is shown. A confident wrong date on a bottle someone is saving would be worse
-- than no date at all.
-- ═══════════════════════════════════════════════════════════════════════════════

BEGIN;

CREATE TABLE IF NOT EXISTS public.cellar_bottles (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  wine_id uuid NOT NULL REFERENCES public.wines(id) ON DELETE CASCADE,
  -- Per-bottle, like tastings. The catalog row stays vintage-agnostic.
  vintage int NULL,
  quantity int NOT NULL DEFAULT 1 CHECK (quantity >= 0),
  purchase_price numeric(10,2) NULL,
  purchase_currency text NULL,
  purchase_date date NULL,
  -- "Kitchen rack", "cellar, bin 4". Free text on purpose; nobody's storage fits a taxonomy.
  location text NULL,
  notes text NULL,
  -- Set when the user overrides the estimate. A person who knows their wine beats the model.
  drink_from_override int NULL,
  drink_until_override int NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT cellar_bottles_vintage_range CHECK (vintage IS NULL OR vintage BETWEEN 1800 AND 2100)
);

CREATE INDEX IF NOT EXISTS idx_cellar_bottles_user ON public.cellar_bottles (user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_cellar_bottles_wine ON public.cellar_bottles (wine_id);
CREATE UNIQUE INDEX IF NOT EXISTS idx_cellar_bottles_user_wine_vintage
  ON public.cellar_bottles (user_id, wine_id, COALESCE(vintage, -1));

ALTER TABLE public.cellar_bottles ENABLE ROW LEVEL SECURITY;

-- A cellar is private. No public read: what someone owns and paid is not feed material.
DROP POLICY IF EXISTS "cellar_bottles_own" ON public.cellar_bottles;
CREATE POLICY "cellar_bottles_own" ON public.cellar_bottles
  FOR ALL USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());

-- ────────────────────────────────────────────────
-- estimate_drinking_window
--
-- Ageing potential is mostly structure. Tannin and acidity preserve; body correlates
-- with concentration. Whites and rosés without tannin lean on acidity alone and get
-- shorter windows. Sparkling is treated as a short-window white unless it is unusually
-- structured.
--
-- Returns years from the vintage, not absolute dates, so a bottle with no vintage
-- returns nothing rather than a guess anchored to today.
-- ────────────────────────────────────────────────
DROP FUNCTION IF EXISTS public.estimate_drinking_window(uuid);
CREATE OR REPLACE FUNCTION public.estimate_drinking_window(p_wine_id uuid)
RETURNS TABLE (years_from int, years_until int, is_estimate boolean)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
DECLARE
  w record;
  v_tannin float8;
  v_acid float8;
  v_body float8;
  v_from int;
  v_until int;
BEGIN
  SELECT wines.category, wines.variety, wines.embedding, wines.structure_obs_count
  INTO w FROM public.wines WHERE wines.id = p_wine_id;

  IF NOT FOUND THEN RETURN; END IF;

  -- Prefer what people actually tasted; fall back to the varietal prior.
  SELECT AVG((t.tannin - 1)::float8 / 4.0),
         AVG((t.acidity - 1)::float8 / 4.0),
         AVG((t.body - 1)::float8 / 4.0)
  INTO v_tannin, v_acid, v_body
  FROM public.tastings t
  WHERE t.wine_id = p_wine_id
    AND (t.tannin IS NOT NULL OR t.acidity IS NOT NULL OR t.body IS NOT NULL);

  IF v_tannin IS NULL AND v_acid IS NULL AND v_body IS NULL THEN
    SELECT AVG(v.tannin)::float8, AVG(v.acidity)::float8, AVG(v.body)::float8
    INTO v_tannin, v_acid, v_body
    FROM unnest(string_to_array(lower(coalesce(w.variety, '')), ',')) AS t(tok)
    JOIN public.wine_varietal_traits v ON v.grape = btrim(t.tok);
  END IF;

  v_tannin := COALESCE(v_tannin, 0.0);
  v_acid   := COALESCE(v_acid, 0.5);
  v_body   := COALESCE(v_body, 0.5);

  -- Most wine is made to drink now. The window opens early and closes according to
  -- how much structure there is to carry it.
  v_from  := GREATEST(0, FLOOR(v_tannin * 4)::int);
  v_until := 2 + FLOOR(v_tannin * 14 + v_acid * 6 + v_body * 4)::int;

  IF lower(COALESCE(w.category, '')) IN ('white', 'rose', 'rosé', 'sparkling') THEN
    -- No tannin to lean on, so acidity does the work and the window is shorter.
    v_from  := 0;
    v_until := 2 + FLOOR(v_acid * 8 + v_body * 3)::int;
  END IF;

  IF v_until <= v_from THEN v_until := v_from + 1; END IF;

  RETURN QUERY SELECT v_from, v_until, true;
END;
$$;

GRANT EXECUTE ON FUNCTION public.estimate_drinking_window(uuid) TO authenticated;

-- ────────────────────────────────────────────────
-- open_tonight
--
-- The one genuinely recurring question this app can answer: of what you already own,
-- what should you open now.
--
-- Ranked by urgency first, taste second. A bottle closing this year outranks a
-- slightly better match with five years left, because the better match will still be
-- there and this one will not.
-- ────────────────────────────────────────────────
DROP FUNCTION IF EXISTS public.open_tonight(uuid, int);
CREATE OR REPLACE FUNCTION public.open_tonight(p_user_id uuid, p_limit int DEFAULT 10)
RETURNS TABLE (
  bottle_id uuid,
  wine_id uuid,
  name text,
  producer text,
  vintage int,
  region text,
  category text,
  label_image_url text,
  quantity int,
  drink_from_year int,
  drink_until_year int,
  years_left int,
  affinity double precision,
  urgency text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_profile vector(64);
  v_this_year int := EXTRACT(YEAR FROM now())::int;
BEGIN
  IF auth.uid() IS NULL OR auth.uid() <> p_user_id THEN
    RAISE EXCEPTION 'Not allowed' USING ERRCODE = '42501';
  END IF;

  v_profile := compute_user_taste_profile(p_user_id);

  RETURN QUERY
  WITH bottles AS (
    SELECT b.id AS bottle_id, b.wine_id, b.vintage, b.quantity,
           b.drink_from_override, b.drink_until_override,
           w.name, w.producer, w.region, w.category, w.label_image_url, w.embedding
    FROM public.cellar_bottles b
    JOIN public.wines w ON w.id = b.wine_id
    WHERE b.user_id = p_user_id AND b.quantity > 0
  ),
  windowed AS (
    SELECT b.*,
           COALESCE(b.drink_from_override,  b.vintage + est.years_from)  AS from_year,
           COALESCE(b.drink_until_override, b.vintage + est.years_until) AS until_year
    FROM bottles b
    LEFT JOIN LATERAL public.estimate_drinking_window(b.wine_id) est ON true
  )
  SELECT
    x.bottle_id, x.wine_id, x.name, x.producer, x.vintage, x.region, x.category,
    x.label_image_url, x.quantity,
    x.from_year, x.until_year,
    (x.until_year - v_this_year),
    CASE WHEN v_profile IS NULL OR x.embedding IS NULL THEN NULL
         ELSE GREATEST(0.0, 1.0 - (x.embedding <=> v_profile)) END,
    CASE
      WHEN x.until_year IS NULL THEN 'unknown'
      WHEN x.until_year < v_this_year THEN 'past'
      WHEN x.until_year - v_this_year <= 1 THEN 'drink now'
      WHEN x.from_year IS NOT NULL AND x.from_year > v_this_year THEN 'still young'
      ELSE 'ready'
    END::text
  FROM windowed x
  ORDER BY
    -- Urgency first: something closing this year beats a better match with time left.
    CASE
      WHEN x.until_year IS NULL THEN 3
      WHEN x.until_year < v_this_year THEN 0
      WHEN x.until_year - v_this_year <= 1 THEN 1
      WHEN x.from_year IS NOT NULL AND x.from_year > v_this_year THEN 4
      ELSE 2
    END,
    CASE WHEN v_profile IS NULL OR x.embedding IS NULL THEN 0
         ELSE 1.0 - (x.embedding <=> v_profile) END DESC
  LIMIT p_limit;
END;
$$;

GRANT EXECUTE ON FUNCTION public.open_tonight(uuid, int) TO authenticated;

COMMIT;
