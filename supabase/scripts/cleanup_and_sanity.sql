-- Cleanup and sanity checks. Run manually in Supabase SQL Editor when needed.
-- Dev reset: truncate user-scoped tables (order matters for FKs).

-- -----------------------------------------------------------------------------
-- Dev reset: truncate (removes all rows). Run only when you need a clean slate.
-- Order: dependents first (likes, comments, comments_cheers -> activity_feed),
-- then follows, rankings, comparisons, profiles, user_private. Keep wines.
-- -----------------------------------------------------------------------------
/*
TRUNCATE public.likes, public.comments, public.comments_cheers CASCADE;
TRUNCATE public.activity_feed CASCADE;
TRUNCATE public.follows CASCADE;
TRUNCATE public.rankings CASCADE;
TRUNCATE public.comparisons CASCADE;
TRUNCATE public.profiles CASCADE;
TRUNCATE public.user_private CASCADE;
*/

-- -----------------------------------------------------------------------------
-- Sanity checks (run as plain queries)
-- -----------------------------------------------------------------------------

-- Counts: auth vs profiles vs activity
SELECT
  (SELECT count(*) FROM auth.users) AS auth_users,
  (SELECT count(*) FROM public.profiles) AS profiles,
  (SELECT count(*) FROM public.activity_feed) AS activity_feed;

-- Orphan activity_feed (user_id not in auth.users) – should be 0 after CASCADE
SELECT a.id, a.user_id, a.created_at
FROM public.activity_feed a
LEFT JOIN auth.users u ON u.id = a.user_id
WHERE u.id IS NULL;

-- Orphan profiles (id not in auth.users) – should be 0
SELECT p.id, p.username
FROM public.profiles p
LEFT JOIN auth.users u ON u.id = p.id
WHERE u.id IS NULL;

-- Any profile with username Guest (should be 0; we never persist Guest)
SELECT id, username, full_name
FROM public.profiles
WHERE lower(trim(username)) = 'guest';
