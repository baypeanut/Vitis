-- Upgrade duel_next_pair to advanced version (Elo, cooldown, no repeats).
-- All comparisons refs use alias "comp"; return via RETURN QUERY only.

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
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
  v_a_id uuid;
  v_a_name text;
  v_a_producer text;
  v_a_vintage int;
  v_a_region text;
  v_a_label text;
  v_a_cat text;
  v_a_elo double precision;
  v_a_n int;
  v_b_id uuid;
  v_b_name text;
  v_b_producer text;
  v_b_vintage int;
  v_b_region text;
  v_b_label text;
  v_is_new boolean := false;
  v_tau double precision;
  v_cooldown int := 20;
BEGIN
  WITH
  uws AS (
    SELECT w.id AS wid, COALESCE(r.elo_score, 1500.0) AS elo, COALESCE(cnt.n, 0) AS n
    FROM public.wines w
    LEFT JOIN public.rankings r ON r.wine_id = w.id AND r.user_id = p_user_id
    LEFT JOIN (
      SELECT vid AS wine_id, COUNT(*) AS n
      FROM (SELECT comp.wine_a_id AS vid FROM public.comparisons comp WHERE comp.user_id = p_user_id UNION ALL SELECT comp.wine_b_id AS vid FROM public.comparisons comp WHERE comp.user_id = p_user_id) u
      GROUP BY vid
    ) cnt ON cnt.wine_id = w.id
  ),
  rw AS (
    SELECT DISTINCT sub.wine_id
    FROM (
      SELECT t.wine_id, t.created_at
      FROM (SELECT comp.wine_a_id AS wine_id, comp.created_at FROM public.comparisons comp WHERE comp.user_id = p_user_id UNION ALL SELECT comp.wine_b_id AS wine_id, comp.created_at FROM public.comparisons comp WHERE comp.user_id = p_user_id) t
      ORDER BY t.created_at DESC
      LIMIT v_cooldown
    ) sub
  ),
  ac AS (
    SELECT DISTINCT LEAST(comp.wine_a_id, comp.wine_b_id) AS lo, GREATEST(comp.wine_a_id, comp.wine_b_id) AS hi
    FROM public.comparisons comp WHERE comp.user_id = p_user_id
  ),
  can_new AS (
    SELECT w.id, w.name, w.producer, w.vintage, w.region, w.label_image_url, w.category, u.elo, u.n, true AS is_new
    FROM public.wines w JOIN uws u ON u.wid = w.id WHERE u.n = 0
    ORDER BY w.created_at DESC NULLS LAST LIMIT 1
  ),
  can_unc AS (
    SELECT w.id, w.name, w.producer, w.vintage, w.region, w.label_image_url, w.category, u.elo, u.n, false AS is_new
    FROM public.wines w JOIN uws u ON u.wid = w.id WHERE u.n > 0
    ORDER BY u.n ASC, random() LIMIT 1
  ),
  sel_a AS (SELECT * FROM can_new UNION ALL SELECT * FROM can_unc LIMIT 1)
  SELECT s.id, s.name, s.producer, s.vintage, s.region, s.label_image_url, s.category, s.elo, s.n, s.is_new
  INTO v_a_id, v_a_name, v_a_producer, v_a_vintage, v_a_region, v_a_label, v_a_cat, v_a_elo, v_a_n, v_is_new
  FROM sel_a s;

  IF v_a_id IS NULL THEN
    WITH fa AS (
      SELECT w.id, w.name, w.producer, w.vintage, w.region, w.label_image_url, w.category, COALESCE(r.elo_score, 1500.0) AS elo, 0 AS n
      FROM public.wines w LEFT JOIN public.rankings r ON r.wine_id = w.id AND r.user_id = p_user_id
      ORDER BY random() LIMIT 1
    )
    SELECT f.id, f.name, f.producer, f.vintage, f.region, f.label_image_url, f.category, f.elo, f.n
    INTO v_a_id, v_a_name, v_a_producer, v_a_vintage, v_a_region, v_a_label, v_a_cat, v_a_elo, v_a_n
    FROM fa f;
    v_is_new := false;
  END IF;

  IF v_a_n = 0 THEN v_tau := 200.0; ELSIF v_a_n > 10 THEN v_tau := 100.0; ELSE v_tau := 120.0; END IF;

  WITH
  uws2 AS (
    SELECT w.id AS wid, COALESCE(r.elo_score, 1500.0) AS elo, COALESCE(cnt.n, 0) AS n
    FROM public.wines w LEFT JOIN public.rankings r ON r.wine_id = w.id AND r.user_id = p_user_id
    LEFT JOIN (SELECT vid AS wine_id, COUNT(*) AS n FROM (SELECT comp.wine_a_id AS vid FROM public.comparisons comp WHERE comp.user_id = p_user_id UNION ALL SELECT comp.wine_b_id AS vid FROM public.comparisons comp WHERE comp.user_id = p_user_id) u GROUP BY vid) cnt ON cnt.wine_id = w.id
  ),
  rw2 AS (
    SELECT DISTINCT sub.wine_id
    FROM (SELECT t.wine_id, t.created_at FROM (SELECT comp.wine_a_id AS wine_id, comp.created_at FROM public.comparisons comp WHERE comp.user_id = p_user_id UNION ALL SELECT comp.wine_b_id AS wine_id, comp.created_at FROM public.comparisons comp WHERE comp.user_id = p_user_id) t ORDER BY t.created_at DESC LIMIT v_cooldown) sub
  ),
  ac2 AS (SELECT DISTINCT LEAST(comp.wine_a_id, comp.wine_b_id) AS lo, GREATEST(comp.wine_a_id, comp.wine_b_id) AS hi FROM public.comparisons comp WHERE comp.user_id = p_user_id),
  cb AS (
    SELECT w.id AS wbid, w.name AS wbname, w.producer AS wbprod, w.vintage AS wbvin, w.region AS wbreg, w.label_image_url AS wblab,
           u.elo AS elob, u.n AS nb, EXP(-ABS(v_a_elo - u.elo) / v_tau) AS elo_close, (1.0 / SQRT(1.0 + u.n)) AS infogain,
           CASE WHEN rw2.wine_id IS NOT NULL THEN 1.0 ELSE 0.0 END AS cooldown
    FROM public.wines w JOIN uws2 u ON u.wid = w.id
    LEFT JOIN rw2 ON rw2.wine_id = w.id
    LEFT JOIN ac2 ON ac2.lo = LEAST(v_a_id, w.id) AND ac2.hi = GREATEST(v_a_id, w.id)
    WHERE w.id <> v_a_id AND (w.category IS NOT DISTINCT FROM v_a_cat) AND ac2.lo IS NULL AND ABS(v_a_elo - u.elo) <= 400.0
  ),
  sb AS (SELECT wbid, wbname, wbprod, wbvin, wbreg, wblab, (0.70 * elo_close + 0.30 * infogain - 1.00 * cooldown) AS sc FROM cb)
  SELECT sb.wbid, sb.wbname, sb.wbprod, sb.wbvin, sb.wbreg, sb.wblab INTO v_b_id, v_b_name, v_b_producer, v_b_vintage, v_b_region, v_b_label
  FROM sb ORDER BY sb.sc DESC LIMIT 1;

  IF v_b_id IS NULL THEN
    WITH
    uws3 AS (SELECT w.id AS wid, COALESCE(r.elo_score, 1500.0) AS elo, COALESCE(cnt.n, 0) AS n FROM public.wines w LEFT JOIN public.rankings r ON r.wine_id = w.id AND r.user_id = p_user_id LEFT JOIN (SELECT vid AS wine_id, COUNT(*) AS n FROM (SELECT comp.wine_a_id AS vid FROM public.comparisons comp WHERE comp.user_id = p_user_id UNION ALL SELECT comp.wine_b_id AS vid FROM public.comparisons comp WHERE comp.user_id = p_user_id) u GROUP BY vid) cnt ON cnt.wine_id = w.id),
    rw3 AS (SELECT DISTINCT sub.wine_id FROM (SELECT t.wine_id, t.created_at FROM (SELECT comp.wine_a_id AS wine_id, comp.created_at FROM public.comparisons comp WHERE comp.user_id = p_user_id UNION ALL SELECT comp.wine_b_id AS wine_id, comp.created_at FROM public.comparisons comp WHERE comp.user_id = p_user_id) t ORDER BY t.created_at DESC LIMIT v_cooldown) sub),
    ac3 AS (SELECT DISTINCT LEAST(comp.wine_a_id, comp.wine_b_id) AS lo, GREATEST(comp.wine_a_id, comp.wine_b_id) AS hi FROM public.comparisons comp WHERE comp.user_id = p_user_id),
    cb3 AS (
      SELECT w.id AS wbid, w.name AS wbname, w.producer AS wbprod, w.vintage AS wbvin, w.region AS wbreg, w.label_image_url AS wblab, u.elo AS elob, u.n AS nb,
             EXP(-ABS(v_a_elo - u.elo) / v_tau) AS elo_close, (1.0 / SQRT(1.0 + u.n)) AS infogain, CASE WHEN rw3.wine_id IS NOT NULL THEN 0.5 ELSE 0.0 END AS cooldown
      FROM public.wines w JOIN uws3 u ON u.wid = w.id LEFT JOIN rw3 ON rw3.wine_id = w.id LEFT JOIN ac3 ON ac3.lo = LEAST(v_a_id, w.id) AND ac3.hi = GREATEST(v_a_id, w.id)
      WHERE w.id <> v_a_id AND (w.category IS NOT DISTINCT FROM v_a_cat) AND ac3.lo IS NULL AND ABS(v_a_elo - u.elo) <= 400.0
    ),
    sb3 AS (SELECT wbid, wbname, wbprod, wbvin, wbreg, wblab, (0.70 * elo_close + 0.30 * infogain - 0.50 * cooldown) AS sc FROM cb3)
    SELECT sb3.wbid, sb3.wbname, sb3.wbprod, sb3.wbvin, sb3.wbreg, sb3.wblab INTO v_b_id, v_b_name, v_b_producer, v_b_vintage, v_b_region, v_b_label FROM sb3 ORDER BY sb3.sc DESC LIMIT 1;
  END IF;

  IF v_b_id IS NULL THEN
    WITH
    ac30 AS (SELECT DISTINCT LEAST(comp.wine_a_id, comp.wine_b_id) AS lo, GREATEST(comp.wine_a_id, comp.wine_b_id) AS hi FROM public.comparisons comp WHERE comp.user_id = p_user_id AND comp.created_at >= NOW() - INTERVAL '30 days'),
    uws4 AS (SELECT w.id AS wid, COALESCE(r.elo_score, 1500.0) AS elo, COALESCE(cnt.n, 0) AS n FROM public.wines w LEFT JOIN public.rankings r ON r.wine_id = w.id AND r.user_id = p_user_id LEFT JOIN (SELECT vid AS wine_id, COUNT(*) AS n FROM (SELECT comp.wine_a_id AS vid FROM public.comparisons comp WHERE comp.user_id = p_user_id UNION ALL SELECT comp.wine_b_id AS vid FROM public.comparisons comp WHERE comp.user_id = p_user_id) u GROUP BY vid) cnt ON cnt.wine_id = w.id),
    rw4 AS (SELECT DISTINCT sub.wine_id FROM (SELECT t.wine_id, t.created_at FROM (SELECT comp.wine_a_id AS wine_id, comp.created_at FROM public.comparisons comp WHERE comp.user_id = p_user_id UNION ALL SELECT comp.wine_b_id AS wine_id, comp.created_at FROM public.comparisons comp WHERE comp.user_id = p_user_id) t ORDER BY t.created_at DESC LIMIT v_cooldown) sub),
    cb4 AS (
      SELECT w.id AS wbid, w.name AS wbname, w.producer AS wbprod, w.vintage AS wbvin, w.region AS wbreg, w.label_image_url AS wblab, u.elo AS elob, u.n AS nb,
             EXP(-ABS(v_a_elo - u.elo) / v_tau) AS elo_close, (1.0 / SQRT(1.0 + u.n)) AS infogain, CASE WHEN rw4.wine_id IS NOT NULL THEN 0.5 ELSE 0.0 END AS cooldown
      FROM public.wines w JOIN uws4 u ON u.wid = w.id LEFT JOIN rw4 ON rw4.wine_id = w.id LEFT JOIN ac30 ON ac30.lo = LEAST(v_a_id, w.id) AND ac30.hi = GREATEST(v_a_id, w.id)
      WHERE w.id <> v_a_id AND (w.category IS NOT DISTINCT FROM v_a_cat) AND ac30.lo IS NULL AND ABS(v_a_elo - u.elo) <= 400.0
    ),
    sb4 AS (SELECT wbid, wbname, wbprod, wbvin, wbreg, wblab, (0.70 * elo_close + 0.30 * infogain - 0.50 * cooldown) AS sc FROM cb4)
    SELECT sb4.wbid, sb4.wbname, sb4.wbprod, sb4.wbvin, sb4.wbreg, sb4.wblab INTO v_b_id, v_b_name, v_b_producer, v_b_vintage, v_b_region, v_b_label FROM sb4 ORDER BY sb4.sc DESC LIMIT 1;
  END IF;

  IF v_b_id IS NULL THEN
    SELECT w.id, w.name, w.producer, w.vintage, w.region, w.label_image_url INTO v_b_id, v_b_name, v_b_producer, v_b_vintage, v_b_region, v_b_label
    FROM public.wines w WHERE w.id <> v_a_id AND (w.category IS NOT DISTINCT FROM v_a_cat) ORDER BY random() LIMIT 1;
  END IF;

  IF v_a_id IS NULL OR v_b_id IS NULL THEN RETURN; END IF;

  RETURN QUERY SELECT v_a_id, v_a_name, v_a_producer, v_a_vintage, v_a_region, v_a_label, v_is_new, v_b_id, v_b_name, v_b_producer, v_b_vintage, v_b_region, v_b_label;
END;
$$;
