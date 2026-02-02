-- Cellar items RLS: enforce owner-only mutation. Security hardening.
-- Rule: another user must never be able to mutate my data.
-- SELECT: authenticated users can read (wishlists visible by default).
-- INSERT/UPDATE/DELETE: only owner (user_id = auth.uid()).

ALTER TABLE public.cellar_items ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "cellar_items_select_all" ON public.cellar_items;
CREATE POLICY "cellar_items_select_all" ON public.cellar_items
  FOR SELECT USING (auth.uid() IS NOT NULL);

DROP POLICY IF EXISTS "cellar_items_insert_own" ON public.cellar_items;
CREATE POLICY "cellar_items_insert_own" ON public.cellar_items
  FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "cellar_items_update_own" ON public.cellar_items;
CREATE POLICY "cellar_items_update_own" ON public.cellar_items
  FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "cellar_items_delete_own" ON public.cellar_items;
CREATE POLICY "cellar_items_delete_own" ON public.cellar_items
  FOR DELETE USING (auth.uid() = user_id);
