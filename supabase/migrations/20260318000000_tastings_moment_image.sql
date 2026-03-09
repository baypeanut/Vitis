-- Tasting "wine night" photo (feed only): column + storage + feed RPCs
ALTER TABLE public.tastings ADD COLUMN IF NOT EXISTS moment_image_url text NULL;

-- Moment images bucket
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'moment_images',
  'moment_images',
  true,
  5242880,
  ARRAY['image/jpeg', 'image/png', 'image/heic']::text[]
)
ON CONFLICT (id) DO UPDATE SET
  public = EXCLUDED.public,
  file_size_limit = EXCLUDED.file_size_limit,
  allowed_mime_types = EXCLUDED.allowed_mime_types;

DROP POLICY IF EXISTS "Moment images are publicly readable" ON storage.objects;
CREATE POLICY "Moment images are publicly readable"
  ON storage.objects FOR SELECT USING (bucket_id = 'moment_images');

DROP POLICY IF EXISTS "Users can upload own moment images" ON storage.objects;
CREATE POLICY "Users can upload own moment images"
  ON storage.objects FOR INSERT WITH CHECK (bucket_id = 'moment_images' AND auth.uid()::text = (storage.foldername(name))[1]);

-- Feed RPCs: include tasting_moment_image_url
DROP FUNCTION IF EXISTS public.feed_global(uuid, int, int);
CREATE OR REPLACE FUNCTION public.feed_global(
  p_viewer_id uuid, p_limit int DEFAULT 30, p_offset int DEFAULT 0
)
RETURNS TABLE (
  id uuid, user_id uuid, activity_type text, wine_id uuid, target_wine_id uuid, content_text text, created_at timestamptz,
  username text, full_name text, avatar_url text,
  wine_name text, wine_producer text, wine_vintage int, wine_label_url text, wine_region text, wine_category text, wine_variety text,
  target_wine_name text, target_wine_producer text, target_wine_vintage int, target_wine_label_url text,
  tasting_note_tags text[], tasting_rating double precision, tasting_comment text, tasting_moment_image_url text
)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT * FROM (
    SELECT DISTINCT ON (a.id)
      a.id, a.user_id, a.activity_type, a.wine_id, a.target_wine_id, a.content_text, a.created_at,
      p.username, p.full_name, p.avatar_url,
      w.name, w.producer, w.vintage, w.label_image_url, w.region, w.category, w.variety,
      tw.name, tw.producer, tw.vintage, tw.label_image_url,
      t.note_tags, t.rating, t.comment, t.moment_image_url
    FROM public.activity_feed a
    INNER JOIN public.profiles p ON p.id = a.user_id AND p.deleted_at IS NULL
    LEFT JOIN public.wines w ON w.id = a.wine_id
    LEFT JOIN public.wines tw ON tw.id = a.target_wine_id
    LEFT JOIN public.tastings t ON (
      a.activity_type = 'had_wine' AND (
        (a.tasting_id IS NOT NULL AND a.tasting_id = t.id)
        OR (a.tasting_id IS NULL AND t.user_id = a.user_id AND t.wine_id = a.wine_id
            AND t.created_at BETWEEN a.created_at - INTERVAL '10 seconds' AND a.created_at + INTERVAL '10 seconds')
      )
    )
    WHERE a.activity_type = 'had_wine'
      AND auth.uid() IS NOT NULL
      AND public.can_view_activity(auth.uid(), a.user_id, p.activity_visibility)
    ORDER BY a.id, CASE WHEN t.id IS NULL THEN 1 ELSE 0 END, CASE WHEN a.tasting_id IS NOT NULL THEN 0 ELSE 1 END,
      ABS(EXTRACT(EPOCH FROM (COALESCE(t.created_at, a.created_at) - a.created_at)))
  ) sub
  ORDER BY created_at DESC
  LIMIT p_limit OFFSET p_offset;
$$;
GRANT EXECUTE ON FUNCTION public.feed_global(uuid, int, int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.feed_global(uuid, int, int) TO anon;

DROP FUNCTION IF EXISTS public.feed_following(uuid, int, int);
CREATE OR REPLACE FUNCTION public.feed_following(
  p_viewer_id uuid, p_limit int DEFAULT 30, p_offset int DEFAULT 0
)
RETURNS TABLE (
  id uuid, user_id uuid, activity_type text, wine_id uuid, target_wine_id uuid, content_text text, created_at timestamptz,
  username text, full_name text, avatar_url text,
  wine_name text, wine_producer text, wine_vintage int, wine_label_url text, wine_region text, wine_category text, wine_variety text,
  target_wine_name text, target_wine_producer text, target_wine_vintage int, target_wine_label_url text,
  tasting_note_tags text[], tasting_rating double precision, tasting_comment text, tasting_moment_image_url text
)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT * FROM (
    SELECT DISTINCT ON (a.id)
      a.id, a.user_id, a.activity_type, a.wine_id, a.target_wine_id, a.content_text, a.created_at,
      p.username, p.full_name, p.avatar_url,
      w.name, w.producer, w.vintage, w.label_image_url, w.region, w.category, w.variety,
      tw.name, tw.producer, tw.vintage, tw.label_image_url,
      t.note_tags, t.rating, t.comment, t.moment_image_url
    FROM public.activity_feed a
    INNER JOIN public.profiles p ON p.id = a.user_id AND p.deleted_at IS NULL
    INNER JOIN public.follows fo ON fo.followed_id = a.user_id AND fo.follower_id = auth.uid()
    LEFT JOIN public.wines w ON w.id = a.wine_id
    LEFT JOIN public.wines tw ON tw.id = a.target_wine_id
    LEFT JOIN public.tastings t ON (
      a.activity_type = 'had_wine' AND (
        (a.tasting_id IS NOT NULL AND a.tasting_id = t.id)
        OR (a.tasting_id IS NULL AND t.user_id = a.user_id AND t.wine_id = a.wine_id
            AND t.created_at BETWEEN a.created_at - INTERVAL '10 seconds' AND a.created_at + INTERVAL '10 seconds')
      )
    )
    WHERE a.activity_type = 'had_wine'
      AND auth.uid() IS NOT NULL
      AND public.can_view_activity(auth.uid(), a.user_id, p.activity_visibility)
    ORDER BY a.id, CASE WHEN t.id IS NULL THEN 1 ELSE 0 END, CASE WHEN a.tasting_id IS NOT NULL THEN 0 ELSE 1 END,
      ABS(EXTRACT(EPOCH FROM (COALESCE(t.created_at, a.created_at) - a.created_at)))
  ) sub
  ORDER BY created_at DESC
  LIMIT p_limit OFFSET p_offset;
$$;
GRANT EXECUTE ON FUNCTION public.feed_following(uuid, int, int) TO authenticated;
