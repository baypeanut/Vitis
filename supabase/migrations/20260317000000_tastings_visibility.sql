-- Per-tasting visibility (Public / Friends Only). App was sending this on insert; column was missing → "Something went wrong".
ALTER TABLE public.tastings ADD COLUMN IF NOT EXISTS visibility text NOT NULL DEFAULT 'everyone' CHECK (visibility IN ('everyone', 'friends'));
