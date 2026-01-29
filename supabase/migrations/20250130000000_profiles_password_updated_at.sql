-- Optional metadata for password reset flow. Password is NEVER stored in Postgres.
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS password_updated_at timestamptz DEFAULT null;
COMMENT ON COLUMN public.profiles.password_updated_at IS 'Set when user updates password via Auth (recovery flow). Password never stored.';
