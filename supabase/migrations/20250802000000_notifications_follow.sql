-- Follow notifications: when user B follows user A, A receives "B started following you"

-- Allow 'follow' type; follow has no post, so post_id must be nullable
ALTER TABLE public.notifications
  ALTER COLUMN post_id DROP NOT NULL;

ALTER TABLE public.notifications
  DROP CONSTRAINT IF EXISTS notifications_type_check;

ALTER TABLE public.notifications
  ADD CONSTRAINT notifications_type_check CHECK (type IN ('like', 'comment', 'follow'));
