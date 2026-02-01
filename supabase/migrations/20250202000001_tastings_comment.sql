-- Add optional comment field to tastings table
ALTER TABLE public.tastings ADD COLUMN comment text NULL;

-- Add index for searching comments (optional, for future features)
CREATE INDEX IF NOT EXISTS idx_tastings_comment ON public.tastings 
  USING gin(to_tsvector('english', comment)) 
  WHERE comment IS NOT NULL;

-- Update feed_with_details view to include comment
DROP VIEW IF EXISTS public.feed_with_details CASCADE;
CREATE VIEW public.feed_with_details AS
SELECT
  a.id,
  a.user_id,
  a.activity_type,
  a.wine_id,
  a.target_wine_id,
  a.content_text,
  a.created_at,
  p.username,
  p.full_name,
  p.avatar_url,
  w.name AS wine_name,
  w.producer AS wine_producer,
  w.vintage AS wine_vintage,
  w.label_image_url AS wine_label_url,
  w.region AS wine_region,
  w.category AS wine_category,
  tw.name AS target_wine_name,
  tw.producer AS target_wine_producer,
  tw.vintage AS target_wine_vintage,
  tw.label_image_url AS target_wine_label_url,
  t.note_tags AS tasting_note_tags,
  t.rating AS tasting_rating,
  t.comment AS tasting_comment
FROM public.activity_feed a
INNER JOIN public.profiles p ON p.id = a.user_id
LEFT JOIN public.wines w ON w.id = a.wine_id
LEFT JOIN public.wines tw ON tw.id = a.target_wine_id
LEFT JOIN public.tastings t ON t.user_id = a.user_id AND t.wine_id = a.wine_id AND t.created_at = a.created_at;
