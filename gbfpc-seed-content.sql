-- ============================================================
-- GBFPC Content Seed — Pre-populate all fields with current
-- site content so the admin shows real data on day 1.
-- Run in Supabase: SQL Editor → New query → paste → Run
-- ============================================================

UPDATE public.content_blocks SET live_value = val, draft_value = val
FROM (VALUES

  -- ── HOME PAGE ────────────────────────────────────────────
  ('home', 'hero',              'title',       'We Are So Glad You Are Here.'),
  ('home', 'hero',              'subtitle',    'A church rooted in truth and alive in the Spirit. Join us every Sunday and Tuesday.'),
  ('home', 'service-times',     'sunday',      'Sunday School — 10:00 AM | Morning Worship — 11:00 AM'),
  ('home', 'service-times',     'wednesday',   'Bible Study — 7:00 PM (Tuesday)'),
  ('home', 'service-times',     'address',     '1418 W Columbus St, Bakersfield, CA 93301'),
  ('home', 'about-preview',     'title',       'Our Pastor & Ministries.'),
  ('home', 'about-preview',     'body',        'Hear from Pastor Kevin Bradford and explore the ministries that make GBFPC a home for every person, every age, and every season of life.'),
  ('home', 'leadership-pastor', 'name',        'Pastor Kevin Bradford'),
  ('home', 'leadership-pastor', 'title',       'Pastor'),
  ('home', 'leadership-pastor', 'bio',         'Kevin Bradford and his family have served Greater Bakersfield''s First Pentecostal Church full-time since 1992, and as senior pastor since October 2010. He holds a degree in Business Administration from CSUB and a master''s in Biblical Studies from Fuller Theological Seminary.'),
  ('home', 'leadership-bishop', 'name',        'Bishop Leon Frost'),
  ('home', 'leadership-bishop', 'title',       'Bishop'),
  ('home', 'leadership-bishop', 'bio',         'Bishop Leon Frost has served First Pentecostal Church for most of his life. Known for his anointed teaching, preaching, stature, and leadership, he guided GBFPC through over 30 years of growth and ministry. His legacy continues to shape the church today.'),
  ('home', 'ministry-youth',    'title',       'Amplified Youth'),
  ('home', 'ministry-youth',    'description', 'High-energy, Spirit-filled youth ministry for teens in middle and high school. Wednesday nights are where faith gets real — worship, the Word, and a community that genuinely does life together.'),
  ('home', 'ministry-kids',     'title',       'K.I.C.K.'),
  ('home', 'ministry-kids',     'description', 'Kids In Christ''s Kingdom. A vibrant Sunday morning experience designed just for children — interactive worship, age-appropriate teaching, and activities that make faith come alive at every stage of childhood.'),
  ('home', 'ministry-women',    'title',       'Thrive'),
  ('home', 'ministry-women',    'description', 'Helping women, families, and marriages thrive through prayer, fellowship, and authentic community.'),
  ('home', 'ministry-men',      'title',       'Men of GBFPC'),
  ('home', 'ministry-men',      'description', 'Brotherhood, accountability, and Spirit-filled growth. Monthly gatherings, service projects, and discipleship opportunities designed to help men become the husbands, fathers, and leaders God has called them to be.'),

  -- ── ABOUT PAGE ───────────────────────────────────────────
  ('about', 'hero',    'title',    'About Us.'),
  ('about', 'hero',    'subtitle', 'Rooted in Bakersfield since 1943 — a church that has followed, proclaimed, and celebrated truth for over 80 years.'),
  ('about', 'history', 'intro',   '80+ Years of Following, Proclaiming, and Celebrating Truth.'),
  ('about', 'beliefs', 'body',    'Repentance is a change of heart, mind, and life — a turning from sin and a turning toward God. Water baptism by immersion in the name of Jesus Christ for the remission of sins — following the pattern of the early church in Acts 2:38. The baptism of the Holy Ghost, evidenced by speaking in other tongues as the Spirit gives utterance — the same experience recorded in Acts 2:4.'),

  -- ── VISIT PAGE ───────────────────────────────────────────
  ('visit', 'hero',     'title',    'We''d Love to Meet You.'),
  ('visit', 'hero',     'subtitle', 'Whether you''ve been thinking about visiting for weeks or just decided today — you are welcome here exactly as you are.'),
  ('visit', 'welcome',  'body',     'GBFPC is a warm, welcoming family that takes faith seriously without taking itself too seriously. Come comfortable, come curious, and come ready to encounter God in a genuine way. Our services blend powerful worship with practical, Scripture-based teaching — and you''ll always find friendly faces ready to help you feel at home.'),
  ('visit', 'location', 'address',  '1418 W Columbus St, Bakersfield, CA 93301'),
  ('visit', 'location', 'parking',  'Ample parking is available on-site. Our team will greet you at the door and point you in the right direction.'),

  -- ── GIVE PAGE ────────────────────────────────────────────
  ('give', 'hero',  'title',    'Give.'),
  ('give', 'hero',  'subtitle', 'Your generosity is more than a transaction — it''s an act of worship that fuels the mission of GBFPC in Bakersfield and around the world.'),
  ('give', 'intro', 'body',     'At GBFPC, we believe generosity is one of the most powerful expressions of faith. When you give, you partner directly with what God is doing through this church — in our congregation, in Bakersfield, and in communities around the world. Your tithe and offering support everything from ministry programs and community outreach to the operations that keep the doors open. Every dollar given is stewarded with integrity and purpose.'),

  -- ── CONNECT PAGE ─────────────────────────────────────────
  ('connect', 'hero',    'title',    'Connect.'),
  ('connect', 'hero',    'subtitle', 'Have a question, prayer request, or just want to know more about GBFPC? We''d love to hear from you — our team is here and ready.'),
  ('connect', 'contact', 'phone',   '(661) 323-2851'),
  ('connect', 'contact', 'email',   'info@gbfpc.org'),
  ('connect', 'contact', 'address', '1418 W Columbus St, Bakersfield, CA 93301'),

  -- ── MINISTRIES PAGE ──────────────────────────────────────
  ('ministries', 'hero', 'title',    'Ministries.'),
  ('ministries', 'hero', 'subtitle', 'There is a place for everyone here. From youth to adults, worship to outreach — find your community and step into something greater.'),

  -- ── EVENTS PAGE ──────────────────────────────────────────
  ('events', 'hero', 'title',    'Events.'),
  ('events', 'hero', 'subtitle', 'From Sunday worship to youth nights and special services — there''s always something happening at GBFPC. All are welcome.'),

  -- ── ACADEMY PAGE ─────────────────────────────────────────
  ('academy', 'hero',  'title',    'Bethel Academy & Kiddie Korral.'),
  ('academy', 'hero',  'subtitle', 'Two programs, one mission — faith-rooted education and childcare for every age, from infants through 12th grade, right here at GBFPC.'),
  ('academy', 'intro', 'body',     'BAA provides a complete Christian education — from Kindergarten through high school. With a strong academic curriculum, dedicated teachers, and a faith-centered environment, students are prepared for college, career, and life. BKK is GBFPC''s daycare and Pre-K program — providing a warm, safe, and faith-filled environment for infants through Pre-Kindergarten.'),

  -- ── LIVESTREAM PAGE ──────────────────────────────────────
  ('livestream', 'hero',    'title',      'Watch Live.'),
  ('livestream', 'hero',    'subtitle',   'Join us live every Sunday and Tuesday as we worship together.'),
  ('livestream', 'channel', 'youtube_id', 'UCO1PnTTAT_uOS4ZkMjdBzGg')

) AS seed(page_slug, section, key, val)
WHERE content_blocks.page_slug = seed.page_slug
  AND content_blocks.section   = seed.section
  AND content_blocks.key       = seed.key;
