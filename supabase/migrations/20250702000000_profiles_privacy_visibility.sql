-- Privacy visibility: cellar, wishlist, activity. Everyone vs Friends (mutual follow).

ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS cellar_visibility text NOT NULL DEFAULT 'everyone'
  CHECK (cellar_visibility IN ('everyone', 'friends'));
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS wishlist_visibility text NOT NULL DEFAULT 'everyone'
  CHECK (wishlist_visibility IN ('everyone', 'friends'));
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS activity_visibility text NOT NULL DEFAULT 'everyone'
  CHECK (activity_visibility IN ('everyone', 'friends'));

-- Helper: true if viewer and owner are mutual followers.
CREATE OR REPLACE FUNCTION public.is_mutual_friend(p_viewer_id uuid, p_owner_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY INVOKER
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.follows a
    WHERE a.follower_id = p_viewer_id AND a.followed_id = p_owner_id
  ) AND EXISTS (
    SELECT 1 FROM public.follows b
    WHERE b.follower_id = p_owner_id AND b.followed_id = p_viewer_id
  );
$$;
