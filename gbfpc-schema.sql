-- ============================================================
-- GBFPC Platform — Database Schema
-- Run in Supabase: SQL Editor → New query → paste → Run
-- ============================================================

-- ────────────────────────────────────────────────────────────
-- 1. PROFILES  (extends auth.users)
-- ────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.profiles (
  id          UUID        PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email       TEXT        NOT NULL,
  full_name   TEXT,
  role        TEXT        NOT NULL DEFAULT 'editor'
                          CHECK (role IN ('admin', 'editor')),
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Auto-create a profile row whenever a new auth user is added
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  INSERT INTO public.profiles (id, email, full_name)
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'full_name', '')
  )
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- ────────────────────────────────────────────────────────────
-- 2. CONTENT BLOCKS  (all editable text + images per page)
-- ────────────────────────────────────────────────────────────
-- Each editable item is one row:
--   page_slug  → which page  ('home', 'about', 'events', ...)
--   section    → which group ('hero', 'leadership-pastor', ...)
--   key        → which field ('title', 'body', 'image_url', ...)
--   live_value → what visitors see right now
--   draft_value→ what the admin has saved but not yet published
--   label      → human-readable name shown in the admin UI
-- ────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.content_blocks (
  id            UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  page_slug     TEXT        NOT NULL,
  section       TEXT        NOT NULL,
  key           TEXT        NOT NULL,
  content_type  TEXT        NOT NULL DEFAULT 'text'
                            CHECK (content_type IN ('text', 'richtext', 'image_url', 'url')),
  label         TEXT        NOT NULL DEFAULT '',
  live_value    TEXT,
  draft_value   TEXT,
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_by    UUID        REFERENCES public.profiles(id),
  UNIQUE (page_slug, section, key)
);

CREATE INDEX IF NOT EXISTS idx_content_blocks_page ON public.content_blocks(page_slug);

-- ────────────────────────────────────────────────────────────
-- 3. EVENTS
-- ────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.events (
  id            UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  title         TEXT        NOT NULL,
  description   TEXT,
  event_date    DATE        NOT NULL,
  start_time    TIME,
  end_time      TIME,
  location      TEXT        DEFAULT 'GBFPC — 1418 W Columbus St, Bakersfield CA',
  category      TEXT        DEFAULT 'general'
                            CHECK (category IN ('general','youth','women','men','kids','special','vbs','holiday')),
  image_url     TEXT,
  is_featured   BOOLEAN     NOT NULL DEFAULT FALSE,
  is_published  BOOLEAN     NOT NULL DEFAULT FALSE,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_by    UUID        REFERENCES public.profiles(id)
);

CREATE INDEX IF NOT EXISTS idx_events_date ON public.events(event_date);
CREATE INDEX IF NOT EXISTS idx_events_published ON public.events(is_published, event_date);

-- ────────────────────────────────────────────────────────────
-- 4. ANNOUNCEMENTS  (feeds the future church app)
-- ────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.announcements (
  id            UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  title         TEXT        NOT NULL,
  body          TEXT        NOT NULL,
  is_published  BOOLEAN     NOT NULL DEFAULT FALSE,
  published_at  TIMESTAMPTZ,
  expires_at    TIMESTAMPTZ,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_by    UUID        REFERENCES public.profiles(id)
);

-- ────────────────────────────────────────────────────────────
-- 5. PUBLISH FUNCTION
-- Called when admin hits "Publish" — copies draft → live
-- ────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.publish_page(p_page_slug TEXT, p_user_id UUID)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  UPDATE public.content_blocks
  SET
    live_value  = draft_value,
    updated_at  = NOW(),
    updated_by  = p_user_id
  WHERE page_slug = p_page_slug
    AND draft_value IS NOT NULL;
END;
$$;

-- ────────────────────────────────────────────────────────────
-- 6. ROW LEVEL SECURITY
-- ────────────────────────────────────────────────────────────

-- profiles ---------------------------------------------------
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can read own profile"
  ON public.profiles FOR SELECT
  TO authenticated
  USING ((SELECT auth.uid()) = id);

CREATE POLICY "Admins can read all profiles"
  ON public.profiles FOR SELECT
  TO authenticated
  USING (
    (auth.jwt() -> 'app_metadata' ->> 'role') = 'admin'
  );

CREATE POLICY "Users can update own profile"
  ON public.profiles FOR UPDATE
  TO authenticated
  USING ((SELECT auth.uid()) = id)
  WITH CHECK ((SELECT auth.uid()) = id);

-- content_blocks ---------------------------------------------
ALTER TABLE public.content_blocks ENABLE ROW LEVEL SECURITY;

-- Public (including anon) can read published content
CREATE POLICY "Public can read live content"
  ON public.content_blocks FOR SELECT
  USING (live_value IS NOT NULL);

-- Authenticated editors can read ALL content (including drafts)
CREATE POLICY "Editors can read all content"
  ON public.content_blocks FOR SELECT
  TO authenticated
  USING (true);

-- Authenticated editors can insert and update
CREATE POLICY "Editors can insert content"
  ON public.content_blocks FOR INSERT
  TO authenticated
  WITH CHECK (true);

CREATE POLICY "Editors can update content"
  ON public.content_blocks FOR UPDATE
  TO authenticated
  USING (true)
  WITH CHECK (true);

-- Only admins can delete content blocks
CREATE POLICY "Admins can delete content"
  ON public.content_blocks FOR DELETE
  TO authenticated
  USING (
    (auth.jwt() -> 'app_metadata' ->> 'role') = 'admin'
  );

-- events -----------------------------------------------------
ALTER TABLE public.events ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Public can read published events"
  ON public.events FOR SELECT
  USING (is_published = true AND event_date >= CURRENT_DATE - INTERVAL '1 day');

CREATE POLICY "Editors can read all events"
  ON public.events FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Editors can insert events"
  ON public.events FOR INSERT
  TO authenticated
  WITH CHECK (true);

CREATE POLICY "Editors can update events"
  ON public.events FOR UPDATE
  TO authenticated
  USING (true)
  WITH CHECK (true);

CREATE POLICY "Editors can delete events"
  ON public.events FOR DELETE
  TO authenticated
  USING (true);

-- announcements ----------------------------------------------
ALTER TABLE public.announcements ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Public can read published announcements"
  ON public.announcements FOR SELECT
  USING (
    is_published = true
    AND (expires_at IS NULL OR expires_at > NOW())
  );

CREATE POLICY "Editors can read all announcements"
  ON public.announcements FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Editors can manage announcements"
  ON public.announcements FOR ALL
  TO authenticated
  USING (true)
  WITH CHECK (true);

-- ────────────────────────────────────────────────────────────
-- 7. STORAGE BUCKET  (run in Supabase: Storage → New bucket)
-- OR use the SQL below — requires the storage schema to exist
-- ────────────────────────────────────────────────────────────
-- NOTE: Supabase usually manages storage via the dashboard UI.
-- Go to: Storage → New bucket → name: "media" → Public bucket: ON
--
-- Then create this storage policy (also available in dashboard):
-- INSERT INTO storage.buckets (id, name, public) VALUES ('media', 'media', true)
-- ON CONFLICT (id) DO NOTHING;

-- Storage RLS (run after creating the bucket in dashboard)
-- Anyone can read from the public media bucket
-- CREATE POLICY "Public can view media"
--   ON storage.objects FOR SELECT
--   USING (bucket_id = 'media');
--
-- Only authenticated users can upload
-- CREATE POLICY "Editors can upload media"
--   ON storage.objects FOR INSERT
--   TO authenticated
--   WITH CHECK (bucket_id = 'media');
--
-- Only authenticated users can delete their uploads
-- CREATE POLICY "Editors can delete media"
--   ON storage.objects FOR DELETE
--   TO authenticated
--   USING (bucket_id = 'media');

-- ────────────────────────────────────────────────────────────
-- 8. SEED — Initial content block structure
-- Pre-defines every editable field so the admin UI is populated
-- on day 1. Values are empty; publish them from the admin.
-- ────────────────────────────────────────────────────────────
INSERT INTO public.content_blocks (page_slug, section, key, content_type, label) VALUES
  -- HOME PAGE
  ('home', 'hero', 'title',           'text',      'Hero Headline'),
  ('home', 'hero', 'subtitle',        'text',      'Hero Subheadline'),
  ('home', 'hero', 'bg_image_url',    'image_url', 'Hero Background Photo'),
  ('home', 'service-times', 'sunday', 'text',      'Sunday Service Time'),
  ('home', 'service-times', 'wednesday', 'text',   'Wednesday Service Time'),
  ('home', 'service-times', 'address', 'text',     'Church Address'),
  ('home', 'about-preview', 'title',  'text',      'About Section Title'),
  ('home', 'about-preview', 'body',   'richtext',  'About Section Text'),
  ('home', 'about-preview', 'image_url', 'image_url', 'About Section Photo'),
  ('home', 'leadership-pastor', 'name',     'text',      'Pastor Name'),
  ('home', 'leadership-pastor', 'title',    'text',      'Pastor Title'),
  ('home', 'leadership-pastor', 'bio',      'richtext',  'Pastor Bio'),
  ('home', 'leadership-pastor', 'image_url','image_url', 'Pastor Photo'),
  ('home', 'leadership-bishop', 'name',     'text',      'Bishop Name'),
  ('home', 'leadership-bishop', 'title',    'text',      'Bishop Title'),
  ('home', 'leadership-bishop', 'bio',      'richtext',  'Bishop Bio'),
  ('home', 'leadership-bishop', 'image_url','image_url', 'Bishop Photo'),
  ('home', 'ministry-youth',  'title',      'text',      'Youth Ministry Title'),
  ('home', 'ministry-youth',  'description','text',      'Youth Ministry Description'),
  ('home', 'ministry-youth',  'image_url',  'image_url', 'Youth Ministry Photo'),
  ('home', 'ministry-kids',   'title',      'text',      'Kids Ministry Title'),
  ('home', 'ministry-kids',   'description','text',      'Kids Ministry Description'),
  ('home', 'ministry-kids',   'image_url',  'image_url', 'Kids Ministry Photo'),
  ('home', 'ministry-women',  'title',      'text',      'Women Ministry Title'),
  ('home', 'ministry-women',  'description','text',      'Women Ministry Description'),
  ('home', 'ministry-men',    'title',      'text',      'Men Ministry Title'),
  ('home', 'ministry-men',    'description','text',      'Men Ministry Description'),
  -- ABOUT PAGE
  ('about', 'hero', 'title',          'text',      'About Hero Title'),
  ('about', 'hero', 'subtitle',       'text',      'About Hero Subtitle'),
  ('about', 'history', 'intro',       'richtext',  'History Intro Text'),
  ('about', 'beliefs', 'body',        'richtext',  'Beliefs / Doctrine Text'),
  -- VISIT PAGE
  ('visit', 'hero', 'title',          'text',      'Visit Hero Title'),
  ('visit', 'hero', 'subtitle',       'text',      'Visit Hero Subtitle'),
  ('visit', 'welcome', 'body',        'richtext',  'Welcome / What to Expect Text'),
  ('visit', 'location', 'address',    'text',      'Address'),
  ('visit', 'location', 'parking',    'text',      'Parking Instructions'),
  ('visit', 'location', 'image_url',  'image_url', 'Building Exterior Photo'),
  -- GIVE PAGE
  ('give', 'hero', 'title',           'text',      'Give Hero Title'),
  ('give', 'intro', 'body',           'richtext',  'Giving Introduction Text'),
  -- CONNECT PAGE
  ('connect', 'hero', 'title',        'text',      'Connect Hero Title'),
  ('connect', 'contact', 'phone',     'text',      'Church Phone Number'),
  ('connect', 'contact', 'email',     'text',      'Church Email Address'),
  ('connect', 'contact', 'address',   'text',      'Church Address'),
  -- MINISTRIES PAGE
  ('ministries', 'hero', 'title',     'text',      'Ministries Hero Title'),
  ('ministries', 'hero', 'subtitle',  'text',      'Ministries Hero Subtitle'),
  -- EVENTS PAGE
  ('events', 'hero', 'title',         'text',      'Events Hero Title'),
  ('events', 'hero', 'subtitle',      'text',      'Events Hero Subtitle'),
  -- ACADEMY PAGE
  ('academy', 'hero', 'title',        'text',      'Academy Hero Title'),
  ('academy', 'hero', 'subtitle',     'text',      'Academy Hero Subtitle'),
  ('academy', 'intro', 'body',        'richtext',  'Academy Introduction Text'),
  -- LIVESTREAM PAGE
  ('livestream', 'hero', 'title',     'text',      'Livestream Hero Title'),
  ('livestream', 'channel', 'youtube_id', 'text',  'YouTube Channel ID')
ON CONFLICT (page_slug, section, key) DO NOTHING;
