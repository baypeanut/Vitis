-- Want to Try as first-class social object: source_context + public read for wishlist.
-- Assumption: Keep unique(user_id, wine_id, status) - Option B; had and wishlist can coexist.

-- Add source_context for attribution (feed, profile, wishlist, search)
ALTER TABLE public.cellar_items
ADD COLUMN IF NOT EXISTS source_context text NULL
CHECK (source_context IS NULL OR source_context IN ('feed', 'profile', 'wishlist', 'search'));

-- RLS: Allow all authenticated users to read cellar_items (so users can view others' Want to Try lists)
DROP POLICY IF EXISTS "cellar_items_select_own" ON public.cellar_items;
DROP POLICY IF EXISTS "cellar_items_select_all" ON public.cellar_items;
CREATE POLICY "cellar_items_select_all" ON public.cellar_items
  FOR SELECT USING (auth.uid() IS NOT NULL);
