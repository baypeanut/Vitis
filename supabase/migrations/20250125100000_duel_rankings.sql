-- Vitis Duel & Rankings (Beli-style pairwise comparison + personal list)
-- comparisons: each duel; rankings: user's ordered list (Bradley–Terry / Elo).

-- Profiles RLS (if not already present). Required for app-created profiles on signup.
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "profiles_select" ON public.profiles;
CREATE POLICY "profiles_select" ON public.profiles FOR SELECT USING (true);
DROP POLICY IF EXISTS "profiles_insert_own" ON public.profiles;
CREATE POLICY "profiles_insert_own" ON public.profiles FOR INSERT WITH CHECK (auth.uid() = id);
DROP POLICY IF EXISTS "profiles_update_own" ON public.profiles;
CREATE POLICY "profiles_update_own" ON public.profiles FOR UPDATE USING (auth.uid() = id);

-- -----------------------------------------------------------------------------
-- comparisons
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.comparisons (
  id uuid NOT NULL PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  wine_a_id uuid NOT NULL REFERENCES public.wines(id) ON DELETE CASCADE,
  wine_b_id uuid NOT NULL REFERENCES public.wines(id) ON DELETE CASCADE,
  winner_id uuid NOT NULL REFERENCES public.wines(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT winner_is_a_or_b CHECK (winner_id = wine_a_id OR winner_id = wine_b_id)
);

CREATE INDEX IF NOT EXISTS idx_comparisons_user ON public.comparisons (user_id);
CREATE INDEX IF NOT EXISTS idx_comparisons_created ON public.comparisons (created_at DESC);

ALTER TABLE public.comparisons ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can read own comparisons"
  ON public.comparisons FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own comparisons"
  ON public.comparisons FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- -----------------------------------------------------------------------------
-- rankings (user_id, wine_id) unique; elo_score + position for "My Ranking"
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.rankings (
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  wine_id uuid NOT NULL REFERENCES public.wines(id) ON DELETE CASCADE,
  elo_score double precision NOT NULL DEFAULT 1500,
  position int NOT NULL DEFAULT 0,
  updated_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, wine_id)
);

CREATE INDEX IF NOT EXISTS idx_rankings_user_position ON public.rankings (user_id, position);

ALTER TABLE public.rankings ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can read own rankings"
  ON public.rankings FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own rankings"
  ON public.rankings FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own rankings"
  ON public.rankings FOR UPDATE
  USING (auth.uid() = user_id);

-- -----------------------------------------------------------------------------
-- RPC: duel_next_pair (simple random pair)
-- -----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.duel_next_pair(uuid);

CREATE OR REPLACE FUNCTION public.duel_next_pair(p_user_id uuid)
RETURNS TABLE (
  wine_a_id uuid,
  wine_a_name text,
  wine_a_producer text,
  wine_a_vintage int,
  wine_a_region text,
  wine_a_label_url text,
  wine_a_is_new boolean,
  wine_b_id uuid,
  wine_b_name text,
  wine_b_producer text,
  wine_b_vintage int,
  wine_b_region text,
  wine_b_label_url text
)
LANGUAGE sql
STABLE
AS $$
  WITH sample AS (
    SELECT id, name, producer, vintage, region, label_image_url,
           row_number() OVER () AS rn
    FROM (SELECT * FROM public.wines ORDER BY random() LIMIT 2) x
  )
  SELECT
    a.id AS wine_a_id, a.name AS wine_a_name, a.producer AS wine_a_producer,
    a.vintage AS wine_a_vintage, a.region AS wine_a_region, a.label_image_url AS wine_a_label_url,
    false AS wine_a_is_new,
    b.id AS wine_b_id, b.name AS wine_b_name, b.producer AS wine_b_producer,
    b.vintage AS wine_b_vintage, b.region AS wine_b_region, b.label_image_url AS wine_b_label_url
  FROM sample a
  JOIN sample b ON a.rn < b.rn AND a.id != b.id
  LIMIT 1;
$$;
