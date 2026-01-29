-- Dev mock RLS for follows (auth.uid() IS NULL, follower_id = debugMockUserId).
-- Run if you already applied setup_schema and need follow/unfollow in dev mode.

DROP POLICY IF EXISTS "dev_mock_follows" ON public.follows;
CREATE POLICY "dev_mock_follows" ON public.follows
  FOR ALL
  USING (auth.uid() IS NULL AND follower_id = '1edd4da3-ecd2-4c30-9f2f-ac7573a8fcba'::uuid)
  WITH CHECK (auth.uid() IS NULL AND follower_id = '1edd4da3-ecd2-4c30-9f2f-ac7573a8fcba'::uuid);
