-- ═══════════════════════════════════════════════════════════════════════════════
-- Signed editorial collections
-- 2026-08-03
--
-- The recommender needs history to say anything. A user on their first evening has
-- no taste vector and no twins, and the honest answer for them is not a worse
-- algorithm, it is a person.
--
-- The controlled evidence says the same thing from the other direction: a hybrid of
-- algorithmic recommendation and human curation beats either alone, and pure
-- algorithms converge faster on over-familiar content.
--
-- WHY THE CURATOR HAS A NAME
-- "Staff picks" is the anonymous version and reads as filler, because nobody is
-- accountable for it and there is nothing to agree or disagree with. A collection
-- here carries a person, a position, and a sentence per wine explaining the choice.
-- If we cannot say who chose it and why, we have not curated anything, and the row
-- should not exist.
-- ═══════════════════════════════════════════════════════════════════════════════

BEGIN;

CREATE TABLE IF NOT EXISTS public.curated_collections (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  slug text NOT NULL UNIQUE,
  title text NOT NULL,
  subtitle text NULL,
  -- Not nullable on purpose. An unsigned collection is the thing this exists to avoid.
  curator_name text NOT NULL,
  curator_credential text NULL,
  curator_avatar_url text NULL,
  published_at timestamptz NULL,
  sort_order int NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.curated_collection_wines (
  collection_id uuid NOT NULL REFERENCES public.curated_collections(id) ON DELETE CASCADE,
  wine_id uuid NOT NULL REFERENCES public.wines(id) ON DELETE CASCADE,
  list_position int NOT NULL DEFAULT 0,
  -- The reason this bottle is here. Without it we have a list, not a point of view.
  note text NULL,
  PRIMARY KEY (collection_id, wine_id)
);

CREATE INDEX IF NOT EXISTS idx_collection_wines_position
  ON public.curated_collection_wines (collection_id, list_position);
CREATE INDEX IF NOT EXISTS idx_collections_published
  ON public.curated_collections (published_at DESC NULLS LAST, sort_order);

ALTER TABLE public.curated_collections ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.curated_collection_wines ENABLE ROW LEVEL SECURITY;

-- Readable once published. Writes are editorial and go through the service role,
-- so there is deliberately no insert or update policy for ordinary users.
DROP POLICY IF EXISTS "collections_select_published" ON public.curated_collections;
CREATE POLICY "collections_select_published" ON public.curated_collections
  FOR SELECT USING (published_at IS NOT NULL AND published_at <= now());

DROP POLICY IF EXISTS "collection_wines_select_published" ON public.curated_collection_wines;
CREATE POLICY "collection_wines_select_published" ON public.curated_collection_wines
  FOR SELECT USING (
    EXISTS (SELECT 1 FROM public.curated_collections c
            WHERE c.id = curated_collection_wines.collection_id
              AND c.published_at IS NOT NULL AND c.published_at <= now())
  );

-- ────────────────────────────────────────────────
-- get_curated_collections
-- ────────────────────────────────────────────────
DROP FUNCTION IF EXISTS public.get_curated_collections(int);
CREATE OR REPLACE FUNCTION public.get_curated_collections(p_limit int DEFAULT 10)
RETURNS TABLE (
  id uuid,
  slug text,
  title text,
  subtitle text,
  curator_name text,
  curator_credential text,
  curator_avatar_url text,
  wine_count int
)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT c.id, c.slug, c.title, c.subtitle,
         c.curator_name, c.curator_credential, c.curator_avatar_url,
         (SELECT COUNT(*)::int FROM public.curated_collection_wines cw WHERE cw.collection_id = c.id)
  FROM public.curated_collections c
  WHERE c.published_at IS NOT NULL AND c.published_at <= now()
  ORDER BY c.sort_order, c.published_at DESC
  LIMIT p_limit;
$$;

GRANT EXECUTE ON FUNCTION public.get_curated_collections(int) TO authenticated, anon;

-- ────────────────────────────────────────────────
-- get_collection_wines
-- ────────────────────────────────────────────────
DROP FUNCTION IF EXISTS public.get_collection_wines(uuid);
CREATE OR REPLACE FUNCTION public.get_collection_wines(p_collection_id uuid)
RETURNS TABLE (
  wine_id uuid,
  name text,
  producer text,
  vintage int,
  variety text,
  region text,
  label_image_url text,
  category text,
  note text,
  list_position int
)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT w.id, w.name, w.producer, w.vintage, w.variety, w.region,
         w.label_image_url, w.category, cw.note, cw.list_position
  FROM public.curated_collection_wines cw
  JOIN public.wines w ON w.id = cw.wine_id
  JOIN public.curated_collections c ON c.id = cw.collection_id
  WHERE cw.collection_id = p_collection_id
    AND c.published_at IS NOT NULL AND c.published_at <= now()
  ORDER BY cw.list_position;
$$;

GRANT EXECUTE ON FUNCTION public.get_collection_wines(uuid) TO authenticated, anon;

COMMIT;

-- No seed data. Collections are editorial: inventing a curator and putting words in
-- their mouth would be fabricating exactly the credibility this table exists to
-- carry. The first collection is written by a real person before it ships.
