-- CI RLS Safety Checks
-- Run against Supabase to verify no permissive policies in production.
-- Exit non-zero if any check fails.

DO $$
DECLARE
  r record;
  v_fail bool := false;
BEGIN
  -- Check 1: No table with RLS disabled
  FOR r IN
    SELECT c.relname
    FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = 'public' AND c.relkind = 'r'
      AND NOT EXISTS (SELECT 1 FROM pg_tables t WHERE t.tablename = c.relname AND t.schemaname = 'public')
    UNION
    SELECT tablename FROM pg_tables WHERE schemaname = 'public'
  LOOP
    IF EXISTS (
      SELECT 1 FROM pg_class c2
      JOIN pg_namespace n2 ON n2.oid = c2.relnamespace
      WHERE n2.nspname = 'public' AND c2.relname = r.relname
        AND c2.relrowsecurity = false
    ) THEN
      RAISE WARNING 'Table % has RLS disabled', r.relname;
      v_fail := true;
    END IF;
  END LOOP;

  -- Check 2: No USING (true) policies (except allowlisted: profiles for basic read, follows for graph)
  -- profiles_select: allows reading non-deleted profiles (we use deleted_at check, not true)
  -- follows: "Users can view follows" USING (true) - required for is_mutual_friend
  FOR r IN
    SELECT schemaname, tablename, policyname, qual::text
    FROM pg_policies
    WHERE schemaname = 'public'
      AND qual::text LIKE '%true%'
  LOOP
    -- Allowlist: follows needs public read for mutual check
    IF r.tablename = 'follows' AND r.policyname LIKE '%view%' THEN
      CONTINUE;
    END IF;
    RAISE WARNING 'Policy %.% has USING(true): %', r.tablename, r.policyname, r.qual;
    v_fail := true;
  END LOOP;

  IF v_fail THEN
    RAISE EXCEPTION 'RLS safety checks failed';
  END IF;

  RAISE NOTICE 'RLS safety checks passed';
END $$;
