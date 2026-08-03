-- ═══════════════════════════════════════════════════════════════════════════════
-- Anatolian indigenous varietals
-- 2026-08-03
--
-- The taxonomy shipped with 130 grapes and not one of them Turkish, so every
-- Turkish wine bypassed the semantic model and landed in the hashed residual.
-- Cheapest available unlock: the catalog already carries these wines, they were
-- simply invisible to the taste vector.
--
-- Family assignment follows style, not geography. The reds form a genuine cluster
-- (high acid, firm tannin, Anatolian plateau) and get family 20, the last free
-- slot. The whites do not belong with them: Narince, Emir and Sultaniye are crisp
-- neutral whites and are filed as such, because a Narince resembles a Vermentino
-- far more than it resembles a Boğazkere.
--
-- Within family 20 the style axes still separate the members. Kalecik Karası is
-- light and soft, Boğazkere is dense and tannic; they share an origin cluster
-- without being claimed to taste alike. That split between family and style is
-- the whole point of the layout.
--
-- Both spellings are registered for each grape. The X-Wines import writes ASCII
-- ("Bogazkere", "Kalecik Karasi") while scanned labels and Turkish producers write
-- proper Turkish, and a lookup miss silently costs the wine its vector.
-- ═══════════════════════════════════════════════════════════════════════════════

BEGIN;

INSERT INTO public.wine_varietal_traits (grape, family_index, body, tannin, acidity, sweetness, aromatic) VALUES
  -- Family 20: Anatolian reds
  ('öküzgözü',        20, 0.60, 0.45, 0.80, 0.00, 0.70),
  ('okuzgozu',        20, 0.60, 0.45, 0.80, 0.00, 0.70),
  ('boğazkere',       20, 0.85, 0.90, 0.70, 0.00, 0.60),
  ('bogazkere',       20, 0.85, 0.90, 0.70, 0.00, 0.60),
  ('kalecik karası',  20, 0.45, 0.35, 0.70, 0.00, 0.75),
  ('kalecik karasi',  20, 0.45, 0.35, 0.70, 0.00, 0.75),
  ('papazkarası',     20, 0.55, 0.50, 0.75, 0.00, 0.65),
  ('papazkarasi',     20, 0.55, 0.50, 0.75, 0.00, 0.65),
  ('çalkarası',       20, 0.35, 0.25, 0.78, 0.05, 0.70),
  ('calkarasi',       20, 0.35, 0.25, 0.78, 0.05, 0.70),
  ('karasakız',       20, 0.45, 0.35, 0.72, 0.00, 0.65),
  ('karasakiz',       20, 0.45, 0.35, 0.72, 0.00, 0.65),
  ('kuntra',          20, 0.45, 0.35, 0.72, 0.00, 0.65),   -- Karasakız under its Bozcaada name
  ('adakarası',       20, 0.50, 0.40, 0.75, 0.00, 0.65),
  ('adakarasi',       20, 0.50, 0.40, 0.75, 0.00, 0.65),
  ('kabarcık',        20, 0.55, 0.45, 0.75, 0.00, 0.60),
  ('kabarcik',        20, 0.55, 0.45, 0.75, 0.00, 0.60),
  ('sergikarası',     20, 0.60, 0.55, 0.72, 0.00, 0.60),
  ('sergikarasi',     20, 0.60, 0.55, 0.72, 0.00, 0.60),

  -- Crisp / neutral whites (family 15): filed on style, not origin
  ('narince',         15, 0.60, 0.00, 0.70, 0.00, 0.65),
  ('emir',            15, 0.45, 0.00, 0.82, 0.00, 0.55),
  ('sultaniye',       15, 0.40, 0.00, 0.55, 0.05, 0.45),
  ('sultaniye beyazı',15, 0.40, 0.00, 0.55, 0.05, 0.45),
  ('yapıncak',        15, 0.45, 0.00, 0.70, 0.00, 0.55),
  ('yapincak',        15, 0.45, 0.00, 0.70, 0.00, 0.55),
  ('vasilaki',        15, 0.45, 0.00, 0.75, 0.00, 0.55),
  ('bornova misketi', 11, 0.45, 0.00, 0.60, 0.35, 0.92),   -- Muscat family, aromatic
  ('misket',          11, 0.45, 0.00, 0.60, 0.30, 0.90)
ON CONFLICT (grape) DO UPDATE SET
  family_index = EXCLUDED.family_index,
  body      = EXCLUDED.body,
  tannin    = EXCLUDED.tannin,
  acidity   = EXCLUDED.acidity,
  sweetness = EXCLUDED.sweetness,
  aromatic  = EXCLUDED.aromatic;

-- Recompute every wine whose grapes just became recognisable.
UPDATE public.wines
SET embedding = compute_wine_embedding(category, variety, region)
WHERE variety IS NOT NULL;

COMMIT;
