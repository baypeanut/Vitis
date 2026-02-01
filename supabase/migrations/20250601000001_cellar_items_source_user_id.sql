-- Trust hint: record which feed user the wishlist item came from.
-- Populated when adding from Feed; used for "You often save wines from X".

ALTER TABLE public.cellar_items
ADD COLUMN IF NOT EXISTS source_user_id uuid REFERENCES auth.users(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_cellar_items_source_user
ON public.cellar_items (user_id, source_user_id, created_at DESC)
WHERE source_user_id IS NOT NULL;
