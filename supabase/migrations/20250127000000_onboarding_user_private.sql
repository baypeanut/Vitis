-- Onboarding: user_private (phone_e164), check_username_available RPC
-- Run in Supabase Dashboard → SQL Editor, or: supabase db push

-- -----------------------------------------------------------------------------
-- 1. user_private: phone_e164, owner-only RLS
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.user_private (
  user_id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  phone_e164 text NOT NULL,
  created_at timestamptz DEFAULT now()
);

ALTER TABLE public.user_private ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "user_private_select_own" ON public.user_private;
CREATE POLICY "user_private_select_own" ON public.user_private
  FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "user_private_insert_own" ON public.user_private;
CREATE POLICY "user_private_insert_own" ON public.user_private
  FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "user_private_update_own" ON public.user_private;
CREATE POLICY "user_private_update_own" ON public.user_private
  FOR UPDATE USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- Dev mock: allow insert/update for debug user when auth.uid() IS NULL
DROP POLICY IF EXISTS "dev_user_private_insert" ON public.user_private;
CREATE POLICY "dev_user_private_insert" ON public.user_private
  FOR INSERT WITH CHECK (
    auth.uid() IS NULL AND user_id = '1edd4da3-ecd2-4c30-9f2f-ac7573a8fcba'::uuid
  );

DROP POLICY IF EXISTS "dev_user_private_update" ON public.user_private;
CREATE POLICY "dev_user_private_update" ON public.user_private
  FOR UPDATE USING (
    auth.uid() IS NULL AND user_id = '1edd4da3-ecd2-4c30-9f2f-ac7573a8fcba'::uuid
  )
  WITH CHECK (
    auth.uid() IS NULL AND user_id = '1edd4da3-ecd2-4c30-9f2f-ac7573a8fcba'::uuid
  );

-- -----------------------------------------------------------------------------
-- 2. check_username_available(username) → true if available (case-insensitive)
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.check_username_available(p_username text)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT NOT EXISTS (
    SELECT 1 FROM public.profiles
    WHERE lower(trim(username)) = lower(trim(nullif(p_username, '')))
  );
$$;

COMMENT ON FUNCTION public.check_username_available(text) IS
  'Returns true if username is available (case-insensitive). Used by onboarding.';

GRANT EXECUTE ON FUNCTION public.check_username_available(text) TO anon;
GRANT EXECUTE ON FUNCTION public.check_username_available(text) TO authenticated;
