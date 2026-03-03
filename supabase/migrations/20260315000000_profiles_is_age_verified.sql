-- App Store compliance: age gate hardening — persist age verification in profiles.
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS is_age_verified boolean NOT NULL DEFAULT false;
