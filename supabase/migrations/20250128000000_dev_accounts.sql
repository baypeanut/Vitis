-- Dev-only table for storing onboarding form data without Supabase Auth.
-- No sign-up, no email/SMS. Used when authRequired = false.
--
-- RLS disabled for simplicity during test phase.
-- MUST enable RLS and add policies before production.

CREATE TABLE IF NOT EXISTS public.dev_accounts (
  id uuid PRIMARY KEY,
  email text,
  phone_e164 text,
  full_name text,
  username text,
  created_at timestamptz DEFAULT now()
);

ALTER TABLE public.dev_accounts DISABLE ROW LEVEL SECURITY;

-- Before production:
--   ALTER TABLE public.dev_accounts ENABLE ROW LEVEL SECURITY;
--   (add policies as needed)
