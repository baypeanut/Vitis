-- Function to allow users to delete their own account
-- This function can be called by authenticated users to delete themselves
-- All related data will be cascade deleted due to ON DELETE CASCADE constraints

CREATE OR REPLACE FUNCTION public.delete_current_user()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  current_user_id uuid;
BEGIN
  -- Get the current user's ID from the JWT
  current_user_id := auth.uid();
  
  -- Ensure user is authenticated
  IF current_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;
  
  -- Delete the user from auth.users
  -- This will cascade delete all related data in:
  -- profiles, tastings, comparisons, rankings, follows, activity_feed,
  -- comments_cheers, likes, comments, user_private, cellar_items, notifications
  DELETE FROM auth.users WHERE id = current_user_id;
END;
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION public.delete_current_user() TO authenticated;

-- Add comment for documentation
COMMENT ON FUNCTION public.delete_current_user() IS 'Allows authenticated users to delete their own account and all associated data via CASCADE constraints';
