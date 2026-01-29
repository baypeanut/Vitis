-- Cellar items: Had | Wishlist. Separate from rankings/activity_feed.
-- Run via Supabase migrations or SQL Editor.

CREATE TABLE IF NOT EXISTS public.cellar_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  wine_id uuid NOT NULL REFERENCES public.wines(id) ON DELETE CASCADE,
  status text NOT NULL CHECK (status IN ('had', 'wishlist')),
  created_at timestamptz NOT NULL DEFAULT now(),
  consumed_at timestamptz NULL
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_cellar_items_user_wine_status
  ON public.cellar_items (user_id, wine_id, status);

CREATE INDEX IF NOT EXISTS idx_cellar_items_user_status_created
  ON public.cellar_items (user_id, status, created_at DESC);

ALTER TABLE public.cellar_items ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "cellar_items_select_own" ON public.cellar_items;
CREATE POLICY "cellar_items_select_own" ON public.cellar_items
  FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "cellar_items_insert_own" ON public.cellar_items;
CREATE POLICY "cellar_items_insert_own" ON public.cellar_items
  FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "cellar_items_update_own" ON public.cellar_items;
CREATE POLICY "cellar_items_update_own" ON public.cellar_items
  FOR UPDATE USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "cellar_items_delete_own" ON public.cellar_items;
CREATE POLICY "cellar_items_delete_own" ON public.cellar_items
  FOR DELETE USING (auth.uid() = user_id);

-- Dev mock: auth bypass for test user (match AppConstants.debugMockUserId)
DROP POLICY IF EXISTS "dev_mock_cellar_items" ON public.cellar_items;
CREATE POLICY "dev_mock_cellar_items" ON public.cellar_items
  FOR ALL
  USING (auth.uid() IS NULL AND user_id = 'cbdc2158-6c97-4ab2-bfce-7facc315dd6f'::uuid)
  WITH CHECK (auth.uid() IS NULL AND user_id = 'cbdc2158-6c97-4ab2-bfce-7facc315dd6f'::uuid);
