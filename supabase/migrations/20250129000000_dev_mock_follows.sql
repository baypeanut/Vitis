-- Dev mock RLS for follows (auth.uid() IS NULL, follower_id = debugMockUserId).
-- Run if you already applied setup_schema and need follow/unfollow in dev mode.

DROP POLICY IF EXISTS "dev_mock_follows" ON public.follows;
CREATE POLICY "dev_mock_follows" ON public.follows
  FOR ALL
  USING (auth.uid() IS NULL AND follower_id = 'cbdc2158-6c97-4ab2-bfce-7facc315dd6f'::uuid)
  WITH CHECK (auth.uid() IS NULL AND follower_id = 'cbdc2158-6c97-4ab2-bfce-7facc315dd6f'::uuid);
