-- Vitis Community Feed – Seed Script
-- Run in Supabase SQL Editor.
--
-- Order:
-- 1. Run Sections 1–2 below (creates wines, profiles if needed; inserts 6 premium wines).
-- 2. Run migrations/20250125000000_community_feed.sql (creates activity_feed, view, etc.).
-- 3. Run Sections 3–4 below (seed user, profile, activity_feed rows).
-- Or run this entire script after the migration if wines/profiles already exist.

-- -----------------------------------------------------------------------------
-- 1. Extensions & base tables (if not already created)
-- -----------------------------------------------------------------------------
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

CREATE TABLE IF NOT EXISTS public.wines (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  producer text NOT NULL,
  vintage int,
  variety text,
  region text,
  label_image_url text
);

CREATE TABLE IF NOT EXISTS public.profiles (
  id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  username text NOT NULL,
  avatar_url text,
  bio text
);

ALTER TABLE public.wines ADD COLUMN IF NOT EXISTS label_image_url text;

-- -----------------------------------------------------------------------------
-- 2. Premium wines (fixed UUIDs for deterministic activity_feed refs)
-- -----------------------------------------------------------------------------
INSERT INTO public.wines (id, name, producer, vintage, variety, region) VALUES
  ('a1000001-0000-0000-0000-000000000001', 'Sassicaia', 'Tenuta San Guido', 2019, 'Cabernet Sauvignon', 'Tuscany'),
  ('a1000002-0000-0000-0000-000000000002', 'Château Margaux', 'Château Margaux', 2015, 'Cabernet Sauvignon', 'Bordeaux'),
  ('a1000003-0000-0000-0000-000000000003', 'Barolo', 'Giacomo Conterno', 2017, 'Nebbiolo', 'Piedmont'),
  ('a1000004-0000-0000-0000-000000000004', 'Côte Rôtie', 'Domaine Jean-Michel Gerin', 2019, 'Syrah', 'Rhône Valley'),
  ('a1000005-0000-0000-0000-000000000005', 'Opus One', 'Opus One Winery', 2018, 'Cabernet Sauvignon', 'Napa Valley'),
  ('a1000006-0000-0000-0000-000000000006', 'Dom Pérignon', 'Moët & Chandon', 2012, 'Chardonnay', 'Champagne')
ON CONFLICT (id) DO NOTHING;

-- -----------------------------------------------------------------------------
-- 3. Seed user (auth.users + auth.identities) and profile
-- Password: SeedPassword1!
-- -----------------------------------------------------------------------------
DO $$
DECLARE
  v_user_id uuid := 'b2000001-0000-0000-0000-000000000001';
  v_encrypted_pw text := crypt('SeedPassword1!', gen_salt('bf'));
BEGIN
  INSERT INTO auth.users (
    id, instance_id, aud, role, email, encrypted_password,
    email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at
  ) VALUES (
    v_user_id,
    '00000000-0000-0000-0000-000000000000',
    'authenticated',
    'authenticated',
    'seed@vitis.app',
    v_encrypted_pw,
    NOW(),
    '{"provider":"email","providers":["email"]}',
    '{"name":"Vitis Curator"}',
    NOW(),
    NOW()
  ) ON CONFLICT (id) DO NOTHING;

  IF NOT EXISTS (SELECT 1 FROM auth.identities WHERE user_id = v_user_id AND provider = 'email') THEN
    INSERT INTO auth.identities (
      id, user_id, identity_data, provider, provider_id, last_sign_in_at, created_at, updated_at
    ) VALUES (
      v_user_id,
      v_user_id,
      format('{"sub":"%s","email":"seed@vitis.app"}', v_user_id)::jsonb,
      'email',
      v_user_id,
      NOW(),
      NOW(),
      NOW()
    );
  END IF;

  INSERT INTO public.profiles (id, username, bio) VALUES
    (v_user_id, 'Vitis Curator', 'Curated by the house.')
  ON CONFLICT (id) DO UPDATE SET username = EXCLUDED.username, bio = EXCLUDED.bio;
END $$;

-- -----------------------------------------------------------------------------
-- 4. Activity feed – Ranked / Discovered (seed user)
-- Run only after migration has created activity_feed. Safe to re-run: deletes
-- seed activities first to avoid duplicates.
-- -----------------------------------------------------------------------------
DELETE FROM public.activity_feed
WHERE user_id = 'b2000001-0000-0000-0000-000000000001';

INSERT INTO public.activity_feed (user_id, activity_type, wine_id, target_wine_id, content_text) VALUES
  ('b2000001-0000-0000-0000-000000000001', 'rank_update', 'a1000001-0000-0000-0000-000000000001', NULL, 'Tuscany list'),
  ('b2000001-0000-0000-0000-000000000001', 'new_entry',  'a1000002-0000-0000-0000-000000000002', NULL, NULL),
  ('b2000001-0000-0000-0000-000000000001', 'duel_win',   'a1000001-0000-0000-0000-000000000001', 'a1000003-0000-0000-0000-000000000003', NULL),
  ('b2000001-0000-0000-0000-000000000001', 'rank_update', 'a1000004-0000-0000-0000-000000000004', NULL, 'Rhône list'),
  ('b2000001-0000-0000-0000-000000000001', 'new_entry',  'a1000005-0000-0000-0000-000000000005', NULL, NULL),
  ('b2000001-0000-0000-0000-000000000001', 'duel_win',   'a1000002-0000-0000-0000-000000000002', 'a1000006-0000-0000-0000-000000000006', NULL);

-- -----------------------------------------------------------------------------
-- 5. Realtime (optional): enable activity_feed for live updates
-- Uncomment and run if you use Supabase Realtime for the feed.
-- -----------------------------------------------------------------------------
-- ALTER PUBLICATION supabase_realtime ADD TABLE public.activity_feed;
