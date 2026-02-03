-- Add optional email column for phone-based auth profile setup
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS email text;
