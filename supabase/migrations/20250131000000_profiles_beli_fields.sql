-- Beli-style profile: bio (140), social links, taste snapshot, weekly goal.
-- Run in Supabase SQL Editor or via supabase db push.

-- Bio: enforce 140 chars (if we add check). App also enforces.
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS bio text;
-- Optional: ADD CONSTRAINT profiles_bio_length CHECK (bio IS NULL OR char_length(bio) <= 140);

ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS instagram_url text;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS taste_snapshot_loves text;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS taste_snapshot_avoids text;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS taste_snapshot_mood text;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS weekly_goal text;

COMMENT ON COLUMN public.profiles.bio IS 'Max 140 chars; enforced in app.';
COMMENT ON COLUMN public.profiles.instagram_url IS 'Stores Instagram handle (no @); app treats as handle.';
COMMENT ON COLUMN public.profiles.taste_snapshot_loves IS 'Option id from predefined list (e.g. nebbiolo).';
COMMENT ON COLUMN public.profiles.taste_snapshot_avoids IS 'Option id from predefined list.';
COMMENT ON COLUMN public.profiles.taste_snapshot_mood IS 'Option id from predefined list.';
COMMENT ON COLUMN public.profiles.weekly_goal IS 'Option id (e.g. rank_5) or null.';

-- RLS: existing profiles_update_own covers UPDATE. No new policies needed.
