-- ============================================================
-- 004 — Events Table v2: date ranges, sessions, scheduled publish
-- Run in Supabase: SQL Editor → New query → paste → Run
-- ============================================================

-- ── New columns ─────────────────────────────────────────────

ALTER TABLE public.events
  -- For date-range events (revival May 1–31, conference June 2–4)
  ADD COLUMN IF NOT EXISTS date_end         DATE,

  -- 'single' = one day, 'range' = span of days
  ADD COLUMN IF NOT EXISTS event_type       TEXT NOT NULL DEFAULT 'single'
                                            CHECK (event_type IN ('single', 'range')),

  -- Which days of the week the event recurs within the range
  -- e.g. ["mon","wed","fri"] — empty array = every day in range
  ADD COLUMN IF NOT EXISTS recurrence_days  JSONB NOT NULL DEFAULT '[]',

  -- Ordered list of service times within each occurrence
  -- e.g. [{"label":"Morning Service","time":"10:00"},{"label":"Evening Service","time":"19:00"}]
  ADD COLUMN IF NOT EXISTS sessions         JSONB NOT NULL DEFAULT '[]',

  -- Scheduled publish: null = use is_published only
  -- Set to future datetime to auto-reveal on the website at that time
  ADD COLUMN IF NOT EXISTS publish_at       TIMESTAMPTZ,

  -- Extra media (images, flyers) beyond the primary image_url
  ADD COLUMN IF NOT EXISTS media_urls       JSONB NOT NULL DEFAULT '[]';

-- ── Expand category list ─────────────────────────────────────
-- Drop old constraint and replace with extended list
ALTER TABLE public.events
  DROP CONSTRAINT IF EXISTS events_category_check;

ALTER TABLE public.events
  ADD CONSTRAINT events_category_check
  CHECK (category IN (
    'general', 'youth', 'women', 'men', 'kids',
    'special', 'vbs', 'holiday', 'revival', 'conference'
  ));

-- ── Indexes ──────────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_events_publish_at ON public.events(publish_at);
CREATE INDEX IF NOT EXISTS idx_events_type       ON public.events(event_type);

-- ── RLS: public read filter includes scheduled events ─────────
-- Visitors see events where:
--   is_published = true
--   AND (publish_at IS NULL OR publish_at <= NOW())
-- The website JS already filters on is_published; it will also
-- filter on publish_at client-side. No RLS change needed since
-- the existing policy already gates on is_published.

-- ── Quick verify ──────────────────────────────────────────────
-- SELECT column_name, data_type FROM information_schema.columns
-- WHERE table_name = 'events' ORDER BY ordinal_position;
