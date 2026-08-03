-- ═══════════════════════════════════════════════════════════════════════════════
-- Rate limit backing store for the claude-vision edge function
-- 2026-08-03
--
-- The function proxies to the Anthropic API using a server-side key. Without a per-user
-- quota, anyone holding the anon key (which ships inside the app binary and is trivially
-- extractable) can issue unlimited vision calls billed to us.
--
-- Fixed-window counter, one row per user. Called by the edge function with the service
-- role key; not reachable by clients.
-- ═══════════════════════════════════════════════════════════════════════════════

BEGIN;

CREATE TABLE IF NOT EXISTS public.label_scan_usage (
  user_id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  window_start timestamptz NOT NULL DEFAULT now(),
  count int NOT NULL DEFAULT 0
);

-- No policies: RLS on with zero policies means only the service role gets through.
ALTER TABLE public.label_scan_usage ENABLE ROW LEVEL SECURITY;

DROP FUNCTION IF EXISTS public.consume_label_scan_quota(uuid, int, interval);
CREATE OR REPLACE FUNCTION public.consume_label_scan_quota(
  p_user_id uuid,
  p_limit int DEFAULT 30,
  p_window interval DEFAULT interval '1 hour'
)
RETURNS TABLE (allowed boolean, remaining int, resets_at timestamptz)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_start timestamptz;
  v_count int;
BEGIN
  INSERT INTO public.label_scan_usage (user_id, window_start, count)
  VALUES (p_user_id, now(), 0)
  ON CONFLICT (user_id) DO NOTHING;

  -- FOR UPDATE serialises concurrent scans from the same account.
  SELECT u.window_start, u.count
  INTO v_start, v_count
  FROM public.label_scan_usage u
  WHERE u.user_id = p_user_id
  FOR UPDATE;

  -- Roll the window once it has expired.
  IF v_start < now() - p_window THEN
    v_start := now();
    v_count := 0;
  END IF;

  IF v_count >= p_limit THEN
    UPDATE public.label_scan_usage u
    SET window_start = v_start, count = v_count
    WHERE u.user_id = p_user_id;
    RETURN QUERY SELECT false, 0, v_start + p_window;
    RETURN;
  END IF;

  v_count := v_count + 1;
  UPDATE public.label_scan_usage u
  SET window_start = v_start, count = v_count
  WHERE u.user_id = p_user_id;

  RETURN QUERY SELECT true, p_limit - v_count, v_start + p_window;
END;
$$;

REVOKE ALL ON FUNCTION public.consume_label_scan_quota(uuid, int, interval) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.consume_label_scan_quota(uuid, int, interval) FROM anon, authenticated;
GRANT EXECUTE ON FUNCTION public.consume_label_scan_quota(uuid, int, interval) TO service_role;

COMMIT;
