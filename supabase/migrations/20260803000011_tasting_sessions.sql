-- ═══════════════════════════════════════════════════════════════════════════════
-- Group mode: tasting sessions and group recommendation
-- 2026-08-03
--
-- Four people at a table, one bottle. Vivino knows what everyone thinks and can
-- predict what you think. Nothing in this category models "us", because nothing
-- else has a reason to: a marketplace wants to sell the same bottle to everybody.
--
-- WHY SESSIONS EXIST AT ALL
-- Group ranking has to read other people's taste vectors, and a palate is personal
-- data. Joining a session is the consent: you put yourself at this table, for this
-- evening, and the ranking may use your vector while you are there. Membership is
-- therefore the authorisation check, not a convenience.
--
-- Individual vectors never leave the server. The client sends a session id and
-- receives wines. This costs the offline story that solo list ranking has, and that
-- is the right trade: a group is a live shared moment by definition.
-- ═══════════════════════════════════════════════════════════════════════════════

BEGIN;

CREATE TABLE IF NOT EXISTS public.tasting_sessions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  -- Short, typeable, said out loud across a table. Not a UUID.
  code text NOT NULL UNIQUE,
  host_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  label text NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  -- A dinner is not permanent and neither is consent to read a palate.
  expires_at timestamptz NOT NULL DEFAULT now() + interval '12 hours'
);

CREATE INDEX IF NOT EXISTS idx_tasting_sessions_code ON public.tasting_sessions (code);
CREATE INDEX IF NOT EXISTS idx_tasting_sessions_expiry ON public.tasting_sessions (expires_at);

CREATE TABLE IF NOT EXISTS public.tasting_session_members (
  session_id uuid NOT NULL REFERENCES public.tasting_sessions(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  joined_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (session_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_session_members_user ON public.tasting_session_members (user_id);

ALTER TABLE public.tasting_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tasting_session_members ENABLE ROW LEVEL SECURITY;

-- You can see a session you are in. Finding one by code goes through the join RPC,
-- so a code cannot be brute-forced by querying the table directly.
DROP POLICY IF EXISTS "sessions_select_member" ON public.tasting_sessions;
CREATE POLICY "sessions_select_member" ON public.tasting_sessions
  FOR SELECT USING (
    EXISTS (SELECT 1 FROM public.tasting_session_members m
            WHERE m.session_id = tasting_sessions.id AND m.user_id = auth.uid())
  );

DROP POLICY IF EXISTS "session_members_select_same_session" ON public.tasting_session_members;
CREATE POLICY "session_members_select_same_session" ON public.tasting_session_members
  FOR SELECT USING (
    EXISTS (SELECT 1 FROM public.tasting_session_members m2
            WHERE m2.session_id = tasting_session_members.session_id AND m2.user_id = auth.uid())
  );

-- Leaving is always allowed. Consent you cannot withdraw is not consent.
DROP POLICY IF EXISTS "session_members_delete_self" ON public.tasting_session_members;
CREATE POLICY "session_members_delete_self" ON public.tasting_session_members
  FOR DELETE USING (user_id = auth.uid());

-- ────────────────────────────────────────────────
-- create_tasting_session
-- ────────────────────────────────────────────────
DROP FUNCTION IF EXISTS public.create_tasting_session(text);
CREATE OR REPLACE FUNCTION public.create_tasting_session(p_label text DEFAULT NULL)
RETURNS TABLE (session_id uuid, code text, expires_at timestamptz)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_code text;
  v_id uuid;
  v_expires timestamptz;
  -- No I, O, 0 or 1: this gets read aloud in a dark room.
  alphabet constant text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  attempt int := 0;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Not allowed' USING ERRCODE = '42501';
  END IF;

  LOOP
    attempt := attempt + 1;
    v_code := '';
    FOR i IN 1..5 LOOP
      v_code := v_code || substr(alphabet, 1 + floor(random() * length(alphabet))::int, 1);
    END LOOP;

    BEGIN
      INSERT INTO public.tasting_sessions (code, host_id, label)
      VALUES (v_code, auth.uid(), NULLIF(btrim(p_label), ''))
      RETURNING tasting_sessions.id, tasting_sessions.expires_at INTO v_id, v_expires;
      EXIT;
    EXCEPTION WHEN unique_violation THEN
      IF attempt >= 10 THEN
        RAISE EXCEPTION 'Could not allocate a session code';
      END IF;
    END;
  END LOOP;

  INSERT INTO public.tasting_session_members (session_id, user_id)
  VALUES (v_id, auth.uid());

  RETURN QUERY SELECT v_id, v_code, v_expires;
END;
$$;

GRANT EXECUTE ON FUNCTION public.create_tasting_session(text) TO authenticated;

-- ────────────────────────────────────────────────
-- join_tasting_session
-- ────────────────────────────────────────────────
DROP FUNCTION IF EXISTS public.join_tasting_session(text);
CREATE OR REPLACE FUNCTION public.join_tasting_session(p_code text)
RETURNS TABLE (session_id uuid, label text, member_count int, expires_at timestamptz)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  s record;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Not allowed' USING ERRCODE = '42501';
  END IF;

  SELECT * INTO s
  FROM public.tasting_sessions ts
  WHERE ts.code = upper(btrim(p_code))
    AND ts.expires_at > now();

  IF NOT FOUND THEN
    RAISE EXCEPTION 'No open table with that code' USING ERRCODE = 'no_data_found';
  END IF;

  INSERT INTO public.tasting_session_members (session_id, user_id)
  VALUES (s.id, auth.uid())
  ON CONFLICT DO NOTHING;

  RETURN QUERY
  SELECT s.id, s.label,
         (SELECT COUNT(*)::int FROM public.tasting_session_members m WHERE m.session_id = s.id),
         s.expires_at;
END;
$$;

GRANT EXECUTE ON FUNCTION public.join_tasting_session(text) TO authenticated;

-- ────────────────────────────────────────────────
-- recommend_wines_group
--
-- AGGREGATION STRATEGY, stated rather than buried in a constant.
--
-- Social choice offers two honest answers and they disagree:
--   utilitarian  maximise the average. Can pick a wine one person actively dislikes.
--   egalitarian  maximise the worst-served member. Tends to the bland: the wine
--                nobody objects to is often the wine nobody wants.
--
-- This uses AVERAGE WITHOUT MISERY: rank by the mean, but hard-exclude any wine
-- where a member falls below a floor. It keeps the average's willingness to pick
-- something with character while making the failure mode that actually matters at a
-- table - one person stuck with a glass they dislike - impossible rather than
-- merely unlikely.
--
-- The floor is a parameter, not a magic number, so the trade is visible at the
-- call site.
-- ────────────────────────────────────────────────
DROP FUNCTION IF EXISTS public.recommend_wines_group(uuid, int, real, int);
CREATE OR REPLACE FUNCTION public.recommend_wines_group(
  p_session_id uuid,
  p_limit int DEFAULT 20,
  p_misery_floor real DEFAULT 0.25,
  p_candidate_pool int DEFAULT 400
)
RETURNS TABLE (
  id uuid,
  name text,
  producer text,
  variety text,
  region text,
  label_image_url text,
  category text,
  group_mean double precision,
  worst_member double precision,
  worst_member_id uuid,
  member_count int
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_centroid vector(64);
  v_members int;
BEGIN
  -- Membership is the authorisation. Being at the table is what permits reading
  -- the palates of everyone else at it.
  IF auth.uid() IS NULL OR NOT EXISTS (
    SELECT 1 FROM public.tasting_session_members m
    WHERE m.session_id = p_session_id AND m.user_id = auth.uid()
  ) THEN
    RAISE EXCEPTION 'Not allowed' USING ERRCODE = '42501';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM public.tasting_sessions s
                 WHERE s.id = p_session_id AND s.expires_at > now()) THEN
    RAISE EXCEPTION 'That table has closed' USING ERRCODE = 'no_data_found';
  END IF;

  -- Members with no tastings have no palate to honour. They stay at the table, they
  -- just do not enter the arithmetic.
  SELECT COUNT(*)::int INTO v_members
  FROM public.tasting_session_members m
  WHERE m.session_id = p_session_id
    AND compute_user_taste_profile(m.user_id) IS NOT NULL;

  IF v_members = 0 THEN
    RETURN;
  END IF;

  -- Retrieval runs on the centroid: one ANN pass for the whole table. Members are
  -- scored individually afterwards, so the centroid only decides which wines to
  -- consider, never which one wins.
  --
  -- Computed into a variable rather than left as a subquery so the planner sees a
  -- constant on the right of <=> and can still use the HNSW index.
  SELECT ('[' || string_agg(dim_avg::text, ',' ORDER BY ord) || ']')::vector(64)
  INTO v_centroid
  FROM (
    SELECT u.ord, AVG(u.val) AS dim_avg
    FROM public.tasting_session_members m
    CROSS JOIN LATERAL (SELECT compute_user_taste_profile(m.user_id) AS p) mp
    CROSS JOIN LATERAL unnest(mp.p::real[]::float8[]) WITH ORDINALITY AS u(val, ord)
    WHERE m.session_id = p_session_id AND mp.p IS NOT NULL
    GROUP BY u.ord
  ) dims;

  RETURN QUERY
  WITH members AS (
    SELECT m.user_id, compute_user_taste_profile(m.user_id) AS profile
    FROM public.tasting_session_members m
    WHERE m.session_id = p_session_id
  ),
  valid_members AS (
    SELECT * FROM members WHERE profile IS NOT NULL
  ),
  cand AS (
    SELECT w.id, w.name, w.producer, w.variety, w.region,
           w.label_image_url, w.category, w.embedding
    FROM public.wines w
    WHERE w.embedding IS NOT NULL
      -- Nobody at the table should be recommended something they have already had.
      AND NOT EXISTS (
        SELECT 1 FROM public.tastings t
        JOIN valid_members mm ON mm.user_id = t.user_id
        WHERE t.wine_id = w.id
      )
    ORDER BY w.embedding <=> v_centroid
    LIMIT p_candidate_pool
  ),
  per_member AS (
    SELECT c.id AS wine_id,
           mm.user_id,
           GREATEST(0.0, 1.0 - (c.embedding <=> mm.profile)) AS affinity
    FROM cand c
    CROSS JOIN valid_members mm
  ),
  agg AS (
    SELECT pm.wine_id,
           AVG(pm.affinity) AS mean_affinity,
           MIN(pm.affinity) AS min_affinity,
           (ARRAY_AGG(pm.user_id ORDER BY pm.affinity ASC))[1] AS worst_user
    FROM per_member pm
    GROUP BY pm.wine_id
  )
  SELECT c.id, c.name, c.producer, c.variety, c.region,
         c.label_image_url, c.category,
         a.mean_affinity, a.min_affinity, a.worst_user, v_members
  FROM agg a
  JOIN cand c ON c.id = a.wine_id
  WHERE a.min_affinity >= p_misery_floor        -- without misery
  ORDER BY a.mean_affinity DESC                 -- average
  LIMIT p_limit;
END;
$$;

GRANT EXECUTE ON FUNCTION public.recommend_wines_group(uuid, int, real, int) TO authenticated;

COMMIT;
