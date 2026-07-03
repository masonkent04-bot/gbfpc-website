-- ============================================================
-- GBFPC — Submissions Schema Migration
-- Run in Supabase: SQL Editor → New query → paste → Run
-- ============================================================

-- ────────────────────────────────────────────────────────────
-- 0. ADD submissions_viewer ROLE TO PROFILES
-- ────────────────────────────────────────────────────────────
-- Widen the role check to include the new submissions_viewer role
ALTER TABLE public.profiles
  DROP CONSTRAINT IF EXISTS profiles_role_check;

ALTER TABLE public.profiles
  ADD CONSTRAINT profiles_role_check
  CHECK (role IN ('admin', 'editor', 'submissions_viewer'));

-- ────────────────────────────────────────────────────────────
-- 1. CONTACT SUBMISSIONS
-- Stores every "Send Us a Message" form submission.
-- ────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.contact_submissions (
  id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  first_name  TEXT        NOT NULL,
  last_name   TEXT        NOT NULL,
  email       TEXT        NOT NULL,
  phone       TEXT,
  topic       TEXT,
  message     TEXT        NOT NULL,
  -- workflow status: new → contacted → completed
  status      TEXT        NOT NULL DEFAULT 'new'
              CHECK (status IN ('new', 'contacted', 'completed')),
  -- internal staff note (optional)
  staff_note  TEXT,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_contact_submissions_status
  ON public.contact_submissions(status, created_at DESC);

-- ────────────────────────────────────────────────────────────
-- 2. PLAN YOUR VISIT SUBMISSIONS
-- Fields reflect the church's existing Google Form questions.
-- Update column names once exact questions are confirmed.
-- ────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.visit_submissions (
  id                UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  -- Q1: Full name
  full_name         TEXT        NOT NULL,
  -- Q2: Which service(s) — comma-separated e.g. "Sunday 10AM,Sunday 6PM"
  services          TEXT,
  -- Q3: Needs a ride?
  needs_ride        BOOLEAN     DEFAULT FALSE,
  -- Q4-5: Adults
  adult_count       INT         DEFAULT 1,
  adult_names       TEXT,
  -- Q6-8: Children
  has_children      BOOLEAN     DEFAULT FALSE,
  children_count    INT,
  children_names    TEXT,
  -- Q9-14: Contact info
  email             TEXT,
  phone             TEXT        NOT NULL,
  address           TEXT        NOT NULL,
  unit_number       TEXT,
  city              TEXT        NOT NULL,
  zip_code          TEXT        NOT NULL,
  -- Q15: Bible study interest
  wants_bible_study BOOLEAN     DEFAULT FALSE,
  -- Q16-17: Prayer request
  has_prayer_request BOOLEAN    DEFAULT FALSE,
  prayer_request    TEXT,
  -- Workflow
  status            TEXT        NOT NULL DEFAULT 'new'
                    CHECK (status IN ('new', 'contacted', 'completed')),
  staff_note        TEXT,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_visit_submissions_status
  ON public.visit_submissions(status, created_at DESC);

-- ────────────────────────────────────────────────────────────
-- 3. AUTO-UPDATE updated_at ON BOTH TABLES
-- ────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.touch_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS touch_contact_updated_at ON public.contact_submissions;
CREATE TRIGGER touch_contact_updated_at
  BEFORE UPDATE ON public.contact_submissions
  FOR EACH ROW EXECUTE FUNCTION public.touch_updated_at();

DROP TRIGGER IF EXISTS touch_visit_updated_at ON public.visit_submissions;
CREATE TRIGGER touch_visit_updated_at
  BEFORE UPDATE ON public.visit_submissions
  FOR EACH ROW EXECUTE FUNCTION public.touch_updated_at();

-- ────────────────────────────────────────────────────────────
-- 4. ROW LEVEL SECURITY
-- ────────────────────────────────────────────────────────────

-- contact_submissions ----------------------------------------
ALTER TABLE public.contact_submissions ENABLE ROW LEVEL SECURITY;

-- Anyone (including anonymous website visitors) can insert
CREATE POLICY "Public can submit contact forms"
  ON public.contact_submissions FOR INSERT
  TO anon, authenticated
  WITH CHECK (true);

-- Authenticated users (all roles including submissions_viewer) can read
CREATE POLICY "Authenticated can read contact submissions"
  ON public.contact_submissions FOR SELECT
  TO authenticated
  USING (true);

-- Only admin or submissions_viewer can update status/staff_note
CREATE POLICY "Staff can update contact submissions"
  ON public.contact_submissions FOR UPDATE
  TO authenticated
  USING (
    (SELECT role FROM public.profiles WHERE id = (SELECT auth.uid()))
      IN ('admin', 'submissions_viewer')
  )
  WITH CHECK (
    (SELECT role FROM public.profiles WHERE id = (SELECT auth.uid()))
      IN ('admin', 'submissions_viewer')
  );

-- Only admins can hard-delete (usually leave in place)
CREATE POLICY "Admins can delete contact submissions"
  ON public.contact_submissions FOR DELETE
  TO authenticated
  USING (
    (SELECT role FROM public.profiles WHERE id = (SELECT auth.uid())) = 'admin'
  );

-- visit_submissions ------------------------------------------
ALTER TABLE public.visit_submissions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Public can submit visit forms"
  ON public.visit_submissions FOR INSERT
  TO anon, authenticated
  WITH CHECK (true);

CREATE POLICY "Authenticated can read visit submissions"
  ON public.visit_submissions FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Staff can update visit submissions"
  ON public.visit_submissions FOR UPDATE
  TO authenticated
  USING (
    (SELECT role FROM public.profiles WHERE id = (SELECT auth.uid()))
      IN ('admin', 'submissions_viewer')
  )
  WITH CHECK (
    (SELECT role FROM public.profiles WHERE id = (SELECT auth.uid()))
      IN ('admin', 'submissions_viewer')
  );

CREATE POLICY "Admins can delete visit submissions"
  ON public.visit_submissions FOR DELETE
  TO authenticated
  USING (
    (SELECT role FROM public.profiles WHERE id = (SELECT auth.uid())) = 'admin'
  );

-- ────────────────────────────────────────────────────────────
-- DONE — Next steps:
-- 1. Paste this in Supabase SQL Editor and Run
-- 2. To create a submissions_viewer account, use Supabase Auth
--    dashboard → Add user → then set role in profiles table:
--    UPDATE profiles SET role = 'submissions_viewer' WHERE email = '...';
-- ────────────────────────────────────────────────────────────
