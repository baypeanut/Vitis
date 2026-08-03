-- ═══════════════════════════════════════════════════════════════════════════════
-- Semantic wine embeddings (compute_wine_embedding v2)
-- 2026-08-03
--
-- v1 built the whole 64-dim vector by md5-hashing the variety and region strings.
-- Hashing is deterministic and cheap, but it carries no meaning: "Cabernet Sauvignon"
-- and "Cabernet Franc" hash to unrelated bit patterns, so their vectors are roughly
-- orthogonal. Two people who both love Bordeaux reds looked no more similar than two
-- people with nothing in common, which quietly capped the whole taste-twin and
-- recommendation stack - cosine content similarity was mostly noise.
--
-- v2 keeps the hashing trick only as a fallback for terms we do not recognise, and
-- otherwise derives the vector from grape and region traits:
--
--   dims  1- 5  category one-hot (Red, White, Sparkling, Rose, unknown)
--   dims  6-10  style axes averaged over the blend: body, tannin, acidity, sweetness, aromatic
--   dims 11-30  grape family membership (20 families), multi-hot over the blend
--   dims 31-38  region traits: old/new world, cool/moderate/warm climate, country hash
--   dims 39-63  hashed residual for unrecognised grape/region tokens, down-weighted
--   dim  64     flag: at least one grape was recognised
--
-- Blends are tokenised, so "Cabernet Sauvignon, Merlot" contributes both grapes rather
-- than hashing as one opaque string. This depends on the catalog import keeping the full
-- grape list (see scripts/import_xwines.py).
-- ═══════════════════════════════════════════════════════════════════════════════

BEGIN;

-- ────────────────────────────────────────────────
-- Varietal traits
-- family_index: 1-20, the grape family this variety belongs to
-- style axes are 0..1
-- ────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.wine_varietal_traits (
  grape        text PRIMARY KEY,   -- lowercase, trimmed
  family_index int  NOT NULL CHECK (family_index BETWEEN 1 AND 20),
  body         real NOT NULL DEFAULT 0.5,
  tannin       real NOT NULL DEFAULT 0.0,
  acidity      real NOT NULL DEFAULT 0.5,
  sweetness    real NOT NULL DEFAULT 0.0,
  aromatic     real NOT NULL DEFAULT 0.5
);

ALTER TABLE public.wine_varietal_traits ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "wine_varietal_traits_read" ON public.wine_varietal_traits;
CREATE POLICY "wine_varietal_traits_read" ON public.wine_varietal_traits FOR SELECT USING (true);

INSERT INTO public.wine_varietal_traits (grape, family_index, body, tannin, acidity, sweetness, aromatic) VALUES
  -- 1. Bordeaux reds
  ('cabernet sauvignon', 1, 0.90, 0.90, 0.60, 0.00, 0.55),
  ('cabernet franc',     1, 0.65, 0.65, 0.70, 0.00, 0.70),
  ('merlot',             1, 0.70, 0.55, 0.50, 0.00, 0.50),
  ('petit verdot',       1, 0.90, 0.85, 0.60, 0.00, 0.55),
  ('malbec',             1, 0.85, 0.70, 0.50, 0.00, 0.55),
  ('carmenere',          1, 0.75, 0.65, 0.55, 0.00, 0.60),
  ('carménère',          1, 0.75, 0.65, 0.55, 0.00, 0.60),
  -- 2. Pinot Noir and light reds
  ('pinot noir',         2, 0.45, 0.35, 0.75, 0.00, 0.70),
  ('gamay',              2, 0.35, 0.30, 0.80, 0.00, 0.65),
  ('blaufränkisch',      2, 0.55, 0.50, 0.70, 0.00, 0.60),
  ('zweigelt',           2, 0.45, 0.40, 0.65, 0.00, 0.55),
  -- 3. Rhône reds
  ('syrah',              3, 0.85, 0.75, 0.55, 0.00, 0.70),
  ('syrah/shiraz',       3, 0.85, 0.75, 0.55, 0.00, 0.70),
  ('shiraz',             3, 0.90, 0.75, 0.50, 0.00, 0.70),
  ('grenache',           3, 0.70, 0.45, 0.45, 0.00, 0.65),
  ('mourvèdre',          3, 0.85, 0.80, 0.50, 0.00, 0.60),
  ('mourvedre',          3, 0.85, 0.80, 0.50, 0.00, 0.60),
  ('carignan',           3, 0.70, 0.65, 0.65, 0.00, 0.50),
  ('cinsault',           3, 0.45, 0.35, 0.60, 0.00, 0.60),
  -- 4. Italian reds (central/south)
  ('sangiovese',         4, 0.65, 0.70, 0.85, 0.00, 0.60),
  ('montepulciano',      4, 0.70, 0.60, 0.60, 0.00, 0.50),
  ('nero d''avola',      4, 0.75, 0.60, 0.60, 0.00, 0.60),
  ('aglianico',          4, 0.85, 0.85, 0.75, 0.00, 0.55),
  ('primitivo',          4, 0.85, 0.55, 0.45, 0.05, 0.60),
  -- 5. Piedmont reds
  ('nebbiolo',           5, 0.75, 0.90, 0.85, 0.00, 0.75),
  ('barbera',            5, 0.55, 0.35, 0.85, 0.00, 0.55),
  ('dolcetto',           5, 0.55, 0.50, 0.55, 0.00, 0.50),
  -- 6. Iberian reds
  ('tempranillo',        6, 0.70, 0.60, 0.55, 0.00, 0.55),
  ('tinta roriz',        6, 0.70, 0.60, 0.55, 0.00, 0.55),
  ('garnacha',           6, 0.70, 0.45, 0.45, 0.00, 0.65),
  ('monastrell',         6, 0.85, 0.75, 0.50, 0.00, 0.60),
  ('touriga nacional',   6, 0.85, 0.75, 0.60, 0.00, 0.70),
  ('touriga franca',     6, 0.75, 0.65, 0.60, 0.00, 0.65),
  ('trincadeira',        6, 0.65, 0.55, 0.60, 0.00, 0.55),
  ('baga',               6, 0.70, 0.75, 0.75, 0.00, 0.50),
  -- 7. Zinfandel
  ('zinfandel',          7, 0.85, 0.50, 0.50, 0.05, 0.60),
  -- 8. New World reds, other
  ('pinotage',           8, 0.75, 0.65, 0.55, 0.00, 0.60),
  ('tannat',             8, 0.90, 0.95, 0.60, 0.00, 0.50),
  ('bonarda',            8, 0.65, 0.45, 0.55, 0.00, 0.55),
  -- 9. Chardonnay
  ('chardonnay',         9, 0.70, 0.00, 0.60, 0.00, 0.50),
  -- 10. Sauvignon Blanc family
  ('sauvignon blanc',   10, 0.40, 0.00, 0.85, 0.00, 0.85),
  ('sauvignon',         10, 0.40, 0.00, 0.85, 0.00, 0.85),
  ('verdejo',           10, 0.45, 0.00, 0.75, 0.00, 0.75),
  -- 11. Aromatic whites
  ('riesling',          11, 0.35, 0.00, 0.90, 0.25, 0.90),
  ('gewürztraminer',    11, 0.60, 0.00, 0.45, 0.25, 0.95),
  ('gewurztraminer',    11, 0.60, 0.00, 0.45, 0.25, 0.95),
  ('muscat/moscato',    11, 0.40, 0.00, 0.55, 0.55, 0.95),
  ('moscato',           11, 0.40, 0.00, 0.55, 0.55, 0.95),
  ('muscat',            11, 0.40, 0.00, 0.55, 0.45, 0.95),
  ('torrontés',         11, 0.45, 0.00, 0.60, 0.10, 0.90),
  ('viognier',          11, 0.70, 0.00, 0.45, 0.05, 0.85),
  -- 12. Pinot Gris
  ('pinot grigio',      12, 0.40, 0.00, 0.65, 0.00, 0.45),
  ('pinot gris',        12, 0.55, 0.00, 0.60, 0.10, 0.60),
  -- 13. Chenin / Semillon
  ('chenin blanc',      13, 0.55, 0.00, 0.80, 0.15, 0.65),
  ('sémillon',          13, 0.65, 0.00, 0.55, 0.10, 0.50),
  ('semillon',          13, 0.65, 0.00, 0.55, 0.10, 0.50),
  -- 14. Iberian whites
  ('albariño',          14, 0.45, 0.00, 0.85, 0.00, 0.70),
  ('alvarinho',         14, 0.45, 0.00, 0.85, 0.00, 0.70),
  ('arinto de bucelas', 14, 0.45, 0.00, 0.85, 0.00, 0.55),
  ('arinto',            14, 0.45, 0.00, 0.85, 0.00, 0.55),
  ('loureiro',          14, 0.40, 0.00, 0.80, 0.00, 0.70),
  ('trajadura',         14, 0.45, 0.00, 0.70, 0.00, 0.55),
  ('godello',           14, 0.55, 0.00, 0.70, 0.00, 0.60),
  ('verdelho',          14, 0.55, 0.00, 0.70, 0.00, 0.65),
  ('encruzado',         14, 0.60, 0.00, 0.70, 0.00, 0.60),
  -- 15. Italian whites
  ('vermentino',        15, 0.45, 0.00, 0.75, 0.00, 0.70),
  ('garganega',         15, 0.45, 0.00, 0.70, 0.00, 0.60),
  ('trebbiano',         15, 0.40, 0.00, 0.70, 0.00, 0.40),
  ('cortese',           15, 0.40, 0.00, 0.80, 0.00, 0.50),
  ('fiano',             15, 0.60, 0.00, 0.65, 0.00, 0.70),
  ('greco',             15, 0.55, 0.00, 0.75, 0.00, 0.65),
  -- 16. Alpine / Germanic whites
  ('grüner veltliner',  16, 0.50, 0.00, 0.80, 0.00, 0.65),
  ('gruner veltliner',  16, 0.50, 0.00, 0.80, 0.00, 0.65),
  ('silvaner',          16, 0.45, 0.00, 0.70, 0.00, 0.50),
  ('müller-thurgau',    16, 0.35, 0.00, 0.65, 0.10, 0.55),
  -- 17. Rosé-leaning
  ('rosé blend',        17, 0.35, 0.10, 0.70, 0.05, 0.65),
  -- 18. Sparkling base grapes
  ('glera',             18, 0.35, 0.00, 0.75, 0.15, 0.70),
  ('xarel-lo',          18, 0.45, 0.00, 0.75, 0.00, 0.55),
  ('macabeo',           18, 0.40, 0.00, 0.70, 0.00, 0.50),
  ('parellada',         18, 0.35, 0.00, 0.75, 0.00, 0.55),
  -- 19. Dessert / fortified
  ('pedro ximénez',     19, 0.85, 0.00, 0.40, 0.95, 0.75),
  ('furmint',           19, 0.60, 0.00, 0.85, 0.35, 0.70)
ON CONFLICT (grape) DO UPDATE SET
  family_index = EXCLUDED.family_index,
  body      = EXCLUDED.body,
  tannin    = EXCLUDED.tannin,
  acidity   = EXCLUDED.acidity,
  sweetness = EXCLUDED.sweetness,
  aromatic  = EXCLUDED.aromatic;

-- Second pass: the spellings and synonyms X-Wines actually uses. Many are regional
-- names for grapes already listed above (Spätburgunder = Pinot Noir, Aragonez =
-- Tempranillo, Viura = Macabeo), so they are filed into the same family on purpose -
-- that is exactly the similarity v1 could not express. Together with the first pass
-- these cover ~94% of catalog rows; the rest fall through to the hashed residual.
INSERT INTO public.wine_varietal_traits (grape, family_index, body, tannin, acidity, sweetness, aromatic) VALUES
  -- Pinot Noir synonyms and relatives
  ('spätburgunder',    2, 0.45, 0.35, 0.75, 0.00, 0.70),
  ('pinot nero',       2, 0.45, 0.35, 0.75, 0.00, 0.70),
  ('gamay noir',       2, 0.35, 0.30, 0.80, 0.00, 0.65),
  ('pinot meunier',    2, 0.45, 0.35, 0.75, 0.00, 0.65),
  ('st. laurent',      2, 0.55, 0.45, 0.65, 0.00, 0.60),
  -- Bordeaux reds: the accented spelling in the dataset
  ('carmenère',        1, 0.75, 0.65, 0.55, 0.00, 0.60),
  -- Rhône / southern reds
  ('carignan/cariñena', 3, 0.70, 0.65, 0.65, 0.00, 0.50),
  ('cariñena',         3, 0.70, 0.65, 0.65, 0.00, 0.50),
  ('petite sirah',     3, 0.90, 0.85, 0.55, 0.00, 0.60),
  ('alicante bouschet', 3, 0.85, 0.70, 0.55, 0.00, 0.55),
  -- Italian reds (Valpolicella group and south)
  ('corvina',          4, 0.55, 0.45, 0.75, 0.00, 0.60),
  ('corvinone',        4, 0.60, 0.50, 0.70, 0.00, 0.60),
  ('rondinella',       4, 0.50, 0.40, 0.70, 0.00, 0.50),
  ('molinara',         4, 0.40, 0.30, 0.75, 0.00, 0.50),
  ('negroamaro',       4, 0.75, 0.60, 0.60, 0.00, 0.55),
  ('lambrusco',        4, 0.55, 0.40, 0.70, 0.20, 0.60),
  ('refosco dal peduncolo rosso', 4, 0.70, 0.65, 0.75, 0.00, 0.55),
  ('lagrein',          4, 0.75, 0.70, 0.60, 0.00, 0.55),
  ('canaiolo nero',    4, 0.55, 0.50, 0.70, 0.00, 0.50),
  -- Iberian reds
  ('aragonez',         6, 0.70, 0.60, 0.55, 0.00, 0.55),
  ('tinta barroca',    6, 0.70, 0.55, 0.55, 0.00, 0.60),
  ('tinto cão',        6, 0.70, 0.65, 0.65, 0.00, 0.60),
  ('castelão',         6, 0.65, 0.55, 0.60, 0.00, 0.55),
  ('graciano',         6, 0.70, 0.70, 0.75, 0.00, 0.65),
  ('mencia',           6, 0.60, 0.50, 0.70, 0.00, 0.70),
  ('mencía',           6, 0.60, 0.50, 0.70, 0.00, 0.70),
  ('alfrocheiro preto', 6, 0.65, 0.55, 0.60, 0.00, 0.60),
  -- Rhône / aromatic whites
  ('roussanne',       11, 0.70, 0.00, 0.55, 0.05, 0.75),
  ('marsanne',        11, 0.70, 0.00, 0.45, 0.05, 0.70),
  ('grenache blanc',  11, 0.65, 0.00, 0.55, 0.00, 0.65),
  ('muscat blanc',    11, 0.40, 0.00, 0.55, 0.45, 0.95),
  ('traminer',        11, 0.60, 0.00, 0.50, 0.20, 0.90),
  -- Pinot Gris / Blanc group
  ('grauburgunder',   12, 0.55, 0.00, 0.60, 0.10, 0.60),
  ('pinot blanc',     12, 0.50, 0.00, 0.65, 0.00, 0.50),
  ('weissburgunder',  12, 0.50, 0.00, 0.65, 0.00, 0.50),
  -- Iberian whites
  ('rabigato',        14, 0.50, 0.00, 0.75, 0.00, 0.55),
  ('viosinho',        14, 0.60, 0.00, 0.65, 0.00, 0.60),
  ('antão vaz',       14, 0.60, 0.00, 0.60, 0.00, 0.55),
  -- Crisp / neutral whites
  ('malvasia',        15, 0.55, 0.00, 0.55, 0.10, 0.75),
  ('clairette',       15, 0.50, 0.00, 0.55, 0.00, 0.60),
  ('aligoté',         15, 0.40, 0.00, 0.85, 0.00, 0.45),
  -- Alpine / Germanic whites
  ('silvaner/sylvaner', 16, 0.45, 0.00, 0.70, 0.00, 0.50),
  ('sylvaner',        16, 0.45, 0.00, 0.70, 0.00, 0.50),
  ('chasselas',       16, 0.40, 0.00, 0.60, 0.00, 0.45),
  ('welschriesling',  16, 0.40, 0.00, 0.80, 0.10, 0.60),
  -- Sparkling base
  ('glera/prosecco',  18, 0.35, 0.00, 0.75, 0.15, 0.70),
  ('viura',           18, 0.40, 0.00, 0.70, 0.00, 0.50),
  -- Fortified base
  ('palomino',        19, 0.45, 0.00, 0.55, 0.00, 0.40)
ON CONFLICT (grape) DO UPDATE SET
  family_index = EXCLUDED.family_index,
  body      = EXCLUDED.body,
  tannin    = EXCLUDED.tannin,
  acidity   = EXCLUDED.acidity,
  sweetness = EXCLUDED.sweetness,
  aromatic  = EXCLUDED.aromatic;

-- ────────────────────────────────────────────────
-- Region traits, matched by country substring
-- ────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.wine_region_traits (
  country   text PRIMARY KEY,      -- lowercase
  old_world boolean NOT NULL,
  climate   text NOT NULL CHECK (climate IN ('cool', 'moderate', 'warm'))
);

ALTER TABLE public.wine_region_traits ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "wine_region_traits_read" ON public.wine_region_traits;
CREATE POLICY "wine_region_traits_read" ON public.wine_region_traits FOR SELECT USING (true);

INSERT INTO public.wine_region_traits (country, old_world, climate) VALUES
  ('france', true, 'moderate'),
  ('italy', true, 'warm'),
  ('spain', true, 'warm'),
  ('portugal', true, 'warm'),
  ('germany', true, 'cool'),
  ('austria', true, 'cool'),
  ('greece', true, 'warm'),
  ('hungary', true, 'cool'),
  ('romania', true, 'moderate'),
  ('georgia', true, 'moderate'),
  ('croatia', true, 'warm'),
  ('slovenia', true, 'cool'),
  ('switzerland', true, 'cool'),
  ('united states', false, 'warm'),
  ('usa', false, 'warm'),
  ('argentina', false, 'warm'),
  ('chile', false, 'moderate'),
  ('australia', false, 'warm'),
  ('new zealand', false, 'cool'),
  ('south africa', false, 'warm'),
  ('brazil', false, 'moderate'),
  ('uruguay', false, 'moderate'),
  ('canada', false, 'cool'),
  ('china', false, 'moderate'),
  ('israel', false, 'warm'),
  ('mexico', false, 'warm'),
  ('turkey', true, 'warm'),
  ('lebanon', true, 'warm'),
  ('moldova', true, 'moderate'),
  ('bulgaria', true, 'moderate')
ON CONFLICT (country) DO UPDATE SET
  old_world = EXCLUDED.old_world,
  climate   = EXCLUDED.climate;

-- ────────────────────────────────────────────────
-- compute_wine_embedding v2
-- ────────────────────────────────────────────────
DROP FUNCTION IF EXISTS public.compute_wine_embedding(text, text, text);
CREATE OR REPLACE FUNCTION public.compute_wine_embedding(
  p_category text,
  p_variety  text,
  p_region   text
)
RETURNS vector(64)
LANGUAGE plpgsql STABLE
AS $$
DECLARE
  dims float8[] := array_fill(0.0, ARRAY[64]);
  tok text;
  tokens text[];
  tr record;
  rr record;
  matched int := 0;
  unmatched text := '';
  sum_body float8 := 0; sum_tannin float8 := 0; sum_acid float8 := 0;
  sum_sweet float8 := 0; sum_arom float8 := 0;
  h bytea;
  i int;
  norm float8 := 0.0;
  region_lc text := lower(trim(coalesce(p_region, '')));
BEGIN
  -- ── dims 1-5: category one-hot ──
  CASE lower(trim(COALESCE(p_category, '')))
    WHEN 'red'       THEN dims[1] := 1.0;
    WHEN 'white'     THEN dims[2] := 1.0;
    WHEN 'sparkling' THEN dims[3] := 1.0;
    WHEN 'rose'      THEN dims[4] := 1.0;
    WHEN 'rosé'      THEN dims[4] := 1.0;
    ELSE                  dims[5] := 0.5;
  END CASE;

  -- ── tokenise the blend on commas (the import writes "Grape A, Grape B") ──
  tokens := ARRAY(
    SELECT btrim(t)
    FROM unnest(string_to_array(lower(coalesce(p_variety, '')), ',')) AS t
    WHERE btrim(t) <> ''
  );

  FOREACH tok IN ARRAY COALESCE(tokens, ARRAY[]::text[]) LOOP
    SELECT * INTO tr FROM public.wine_varietal_traits v WHERE v.grape = tok;

    IF FOUND THEN
      matched := matched + 1;
      sum_body   := sum_body   + tr.body;
      sum_tannin := sum_tannin + tr.tannin;
      sum_acid   := sum_acid   + tr.acidity;
      sum_sweet  := sum_sweet  + tr.sweetness;
      sum_arom   := sum_arom   + tr.aromatic;
      -- dims 11-30: family membership, accumulated across the blend
      dims[10 + tr.family_index] := dims[10 + tr.family_index] + 1.0;
    ELSE
      unmatched := unmatched || tok || '|';
    END IF;
  END LOOP;

  -- ── dims 6-10: style axes, averaged over the recognised grapes ──
  IF matched > 0 THEN
    dims[6]  := sum_body   / matched;
    dims[7]  := sum_tannin / matched;
    dims[8]  := sum_acid   / matched;
    dims[9]  := sum_sweet  / matched;
    dims[10] := sum_arom   / matched;
    -- Normalise family membership so a 4-grape blend does not outweigh a varietal wine
    FOR i IN 11..30 LOOP
      dims[i] := dims[i] / matched;
    END LOOP;
    dims[64] := 1.0;
  END IF;

  -- ── dims 31-38: region traits ──
  SELECT * INTO rr
  FROM public.wine_region_traits r
  WHERE region_lc LIKE '%' || r.country || '%'
  ORDER BY length(r.country) DESC   -- prefer the most specific country match
  LIMIT 1;

  IF FOUND THEN
    IF rr.old_world THEN dims[31] := 1.0; ELSE dims[32] := 1.0; END IF;
    CASE rr.climate
      WHEN 'cool'     THEN dims[33] := 1.0;
      WHEN 'moderate' THEN dims[34] := 1.0;
      WHEN 'warm'     THEN dims[35] := 1.0;
    END CASE;
    -- dims 36-38: signed hash of the country, so different countries in the same
    -- world/climate bucket stay distinguishable
    h := decode(md5(rr.country), 'hex');
    FOR i IN 0..2 LOOP
      dims[36 + i] := CASE WHEN (get_byte(h, i) & 1) = 1 THEN 0.5 ELSE -0.5 END;
    END LOOP;
  ELSIF region_lc <> '' THEN
    unmatched := unmatched || region_lc || '|';
  END IF;

  -- ── dims 39-63: hashed residual for anything unrecognised ──
  -- Down-weighted so it separates unknown wines without swamping the semantic dims.
  IF unmatched <> '' THEN
    h := decode(md5(unmatched), 'hex');
    FOR i IN 0..24 LOOP
      dims[39 + i] := CASE WHEN (get_byte(h, i % 16) >> (i % 8)) & 1 = 1 THEN 0.35 ELSE -0.35 END;
    END LOOP;
  END IF;

  -- ── L2 normalise for cosine ──
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

GRANT EXECUTE ON FUNCTION public.compute_wine_embedding(text, text, text) TO authenticated;

-- The trigger already calls compute_wine_embedding; recompute every row against v2.
UPDATE public.wines
SET embedding = compute_wine_embedding(category, variety, region);

-- HNSW graph was built over v1 vectors; rebuild it for the new distribution.
DROP INDEX IF EXISTS public.idx_wines_embedding_hnsw;
CREATE INDEX idx_wines_embedding_hnsw
  ON public.wines USING hnsw (embedding vector_cosine_ops);

-- Cached pairwise similarities were computed from v1 vectors; force recomputation.
TRUNCATE TABLE public.taste_similarity;

COMMIT;
