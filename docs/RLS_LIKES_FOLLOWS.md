# RLS for likes & follows (reference)

No schema or RLS changes were required. The existing policies work with **real Supabase Auth** sessions.

## Root cause of "new row violates row-level security policy for table 'likes'"

- Sign up used **dev bypass** (`dev_accounts` only, no `supabase.auth.signUp`).
- `auth.uid()` was **NULL** (no session). `likes_insert_own` requires `auth.uid() = user_id`.
- `dev_mock_likes` allows only `auth.uid() IS NULL` **and** `user_id = debugMockUserId` (Noah). New dev signups used a different UUID → RLS blocked.

**Fix:** Sign up now always uses **real** `supabase.auth.signUp`. User exists in Auth → Users, session is set, `auth.uid()` matches `user_id` on like insert.

---

## Likes – table & RLS

```sql
-- Table (user_id REFERENCES auth.users(id))
CREATE TABLE IF NOT EXISTS public.likes (
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  activity_id uuid NOT NULL REFERENCES public.activity_feed(id) ON DELETE CASCADE,
  created_at timestamptz DEFAULT now(),
  PRIMARY KEY (user_id, activity_id)
);

-- Policies
CREATE POLICY "likes_select" ON public.likes FOR SELECT USING (true);
CREATE POLICY "likes_insert_own" ON public.likes FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "likes_delete_own" ON public.likes FOR DELETE USING (auth.uid() = user_id);

-- Dev mock (auth.uid() IS NULL, user_id = Noah only). Remove in production.
CREATE POLICY "dev_mock_likes" ON public.likes FOR ALL
  USING (auth.uid() IS NULL AND user_id = '1edd4da3-ecd2-4c30-9f2f-ac7573a8fcba'::uuid)
  WITH CHECK (auth.uid() IS NULL AND user_id = '1edd4da3-ecd2-4c30-9f2f-ac7573a8fcba'::uuid);
```

---

## Follows – table & RLS

```sql
CREATE TABLE IF NOT EXISTS public.follows (
  follower_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  followed_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (follower_id, followed_id),
  CONSTRAINT follows_no_self CHECK (follower_id != followed_id)
);

CREATE POLICY "Users can view follows" ON public.follows FOR SELECT USING (true);
CREATE POLICY "Users can manage own follows" ON public.follows FOR ALL USING (auth.uid() = follower_id);

-- Dev mock
CREATE POLICY "dev_mock_follows" ON public.follows FOR ALL
  USING (auth.uid() IS NULL AND follower_id = '1edd4da3-ecd2-4c30-9f2f-ac7573a8fcba'::uuid)
  WITH CHECK (auth.uid() IS NULL AND follower_id = '1edd4da3-ecd2-4c30-9f2f-ac7573a8fcba'::uuid);
```

---

## Comments

Same pattern: `auth.uid() = user_id` for INSERT/DELETE. App uses `AuthService.currentUserId()` (session when available) for all writes.

---

**Source:** `supabase/setup_schema.sql`. Run that (or equivalent migrations) in Supabase; no extra migration needed for this fix.
