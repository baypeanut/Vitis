-- ═══════════════════════════════════════════════════════════════════════════════
-- Structured palate capture on tastings
-- 2026-08-03
--
-- Until now a tasting recorded one number from 1 to 10 plus some optional aroma
-- chips, and the taste model, the twin matching and the recommender all rested on
-- that. Aroma is the less diagnostic half of a tasting note; structure (acidity,
-- tannin, body) is the more reliable guide to what a wine actually is.
--
-- The six dimensions below are the WSET Systematic Approach to Tasting, used
-- unchanged rather than reinvented, because that vocabulary is already taught in
-- 70+ countries and 15 languages. Five of the six feed the wine vector directly;
-- finish is captured because it is part of the standard and is useful on its own.
--
-- Ordinal 1-5 throughout, matching low / medium- / medium / medium+ / high.
-- Every column is nullable. Structure is always optional: if capturing it makes
-- logging feel like data entry, people stop logging and the signal dies at source.
--
-- These describe a wine. They are not a quality scale. Nothing downstream may
-- treat high tannin as better than low.
-- ═══════════════════════════════════════════════════════════════════════════════

BEGIN;

ALTER TABLE public.tastings
  ADD COLUMN IF NOT EXISTS acidity        smallint NULL,
  ADD COLUMN IF NOT EXISTS tannin         smallint NULL,
  ADD COLUMN IF NOT EXISTS body           smallint NULL,
  ADD COLUMN IF NOT EXISTS sweetness      smallint NULL,
  ADD COLUMN IF NOT EXISTS aroma_intensity smallint NULL,
  ADD COLUMN IF NOT EXISTS finish         smallint NULL;

DO $$
DECLARE c text;
BEGIN
  FOREACH c IN ARRAY ARRAY['acidity','tannin','body','sweetness','aroma_intensity','finish'] LOOP
    EXECUTE format(
      'ALTER TABLE public.tastings DROP CONSTRAINT IF EXISTS tastings_%s_range', c);
    EXECUTE format(
      'ALTER TABLE public.tastings ADD CONSTRAINT tastings_%s_range
         CHECK (%I IS NULL OR %I BETWEEN 1 AND 5)', c, c, c);
  END LOOP;
END $$;

-- Partial index: only tastings that actually carry structure are worth scanning
-- when rebuilding a wine's observed profile.
CREATE INDEX IF NOT EXISTS idx_tastings_structured
  ON public.tastings (wine_id)
  WHERE acidity IS NOT NULL OR tannin IS NOT NULL OR body IS NOT NULL;

COMMENT ON COLUMN public.tastings.acidity IS
  'WSET SAT ordinal 1-5 (low..high). Descriptive, not a quality score.';

COMMIT;
