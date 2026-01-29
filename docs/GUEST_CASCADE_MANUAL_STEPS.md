# Guest / cascade fix – manual steps

## 1. Run in Supabase SQL Editor

1. **Migration (required)**  
   Open `supabase/migrations/20250202000000_cascade_auth_and_guest_cleanup.sql`, copy full contents, run in SQL Editor.  
   This:
   - Recreates all FKs to `auth.users` with `ON DELETE CASCADE`
   - Deletes any `profiles` row with `username` = `guest`
   - Recreates `feed_with_details` with `INNER JOIN profiles` (no orphan activities)

2. **Optional – dev reset**  
   To wipe user-scoped data: open `supabase/scripts/cleanup_and_sanity.sql`, uncomment the `TRUNCATE` block, run it.  
   Then re-run `setup_schema.sql` if you want seed wines again.

3. **Sanity checks**  
   In `cleanup_and_sanity.sql`, run the `SELECT` queries:
   - Counts: `auth.users`, `profiles`, `activity_feed`
   - Orphan `activity_feed` (should be 0)
   - Orphan `profiles` (should be 0)
   - Rows with `username` = `guest` (should be 0)

## 2. Test in the app

1. **Create user + activity**  
   Sign up, do a few duels so you have feed items.

2. **Delete user in Auth**  
   Supabase Dashboard → Authentication → Users → delete that user.

3. **Verify**  
   - Feed no longer shows those activities (they’re removed by CASCADE; view uses `INNER JOIN profiles`).  
   - No “Guest ranked …” items.  
   - Run sanity-check queries again: no orphans, no `guest` profiles.

4. **No followable Guest**  
   - We never create “Guest” profiles.  
   - If you open a profile by `userId` and fetch fails, you see “User not found” / “This account may have been deleted.” and no Follow button.  
   - Feed filters out any “Guest” items; no Guest profile sheet.

5. **Optional**  
   Log out, sign up again, create activity, delete user, confirm feed clears as above.
