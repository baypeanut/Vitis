-- Username unique (case-insensitive). Required for sign-up profile upsert.
-- Run in Supabase SQL Editor or: supabase db push
-- Base schema has username NOT NULL already.

CREATE UNIQUE INDEX IF NOT EXISTS profiles_username_lower_key
  ON public.profiles (lower(trim(username)));

COMMENT ON COLUMN public.profiles.username IS 'App-level username; unique case-insensitive. Stored on sign-up.';
