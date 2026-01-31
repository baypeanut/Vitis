-- Add wine_variety to feed_with_details for better color resolution

CREATE OR REPLACE VIEW public.feed_with_details AS
SELECT DISTINCT ON (a.id)
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
  w.variety AS wine_variety,
  tw.name AS target_wine_name,
  tw.producer AS target_wine_producer,
  tw.vintage AS target_wine_vintage,
  tw.label_image_url AS target_wine_label_url,
  t.note_tags AS tasting_note_tags,
  t.rating AS tasting_rating
FROM public.activity_feed a
INNER JOIN public.profiles p ON p.id = a.user_id
LEFT JOIN public.wines w ON w.id = a.wine_id
LEFT JOIN public.wines tw ON tw.id = a.target_wine_id
LEFT JOIN public.tastings t ON t.user_id = a.user_id
  AND t.wine_id = a.wine_id
  AND a.activity_type = 'had_wine'
  AND t.created_at BETWEEN a.created_at - INTERVAL '10 seconds' AND a.created_at + INTERVAL '10 seconds'
ORDER BY a.id,
  CASE WHEN t.id IS NULL THEN 1 ELSE 0 END,
  ABS(EXTRACT(EPOCH FROM (t.created_at - a.created_at)));
