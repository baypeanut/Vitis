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

  -- Check 2: No USING (true) policies (except allowlisted)
  -- Allowlist: follows - "Users can view follows" required for is_mutual_friend
  -- dev_accounts must NEVER have plain USING(true); only deny or app_env-guarded bypass
  FOR r IN
    SELECT schemaname, tablename, policyname, qual::text
    FROM pg_policies
    WHERE schemaname = 'public'
      AND qual::text LIKE '%true%'
  LOOP
    IF r.tablename = 'follows' AND r.policyname LIKE '%view%' THEN
      CONTINUE;
    END IF;
    IF r.tablename = 'dev_accounts' THEN
      RAISE WARNING 'dev_accounts must not have USING(true); use deny or app_env guard only: %.%', r.tablename, r.policyname;
      v_fail := true;
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
