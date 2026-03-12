-- Minimal seed data for local smoke testing.
-- Safe to re-run due to WHERE NOT EXISTS guards.

INSERT INTO public.users (email, password_hash)
SELECT 'demo@example.com', '$2b$10$REPLACE_WITH_REAL_HASH_IF_NEEDED'
WHERE NOT EXISTS (
  SELECT 1 FROM public.users WHERE lower(email) = lower('demo@example.com')
);

-- Create a demo review + result only if none exist for demo user.
WITH demo_user AS (
  SELECT id FROM public.users WHERE lower(email) = lower('demo@example.com') LIMIT 1
),
existing AS (
  SELECT r.id
  FROM public.reviews r
  JOIN demo_user u ON u.id = r.user_id
  LIMIT 1
),
ins_review AS (
  INSERT INTO public.reviews (user_id, language, code, status, title)
  SELECT u.id, 'javascript', 'function add(a,b){return a+b}', 'completed', 'Demo review'
  FROM demo_user u
  WHERE NOT EXISTS (SELECT 1 FROM existing)
  RETURNING id
)
INSERT INTO public.review_results (review_id, summary, raw_result, model)
SELECT ir.id,
       'Demo result seed',
       jsonb_build_object('note','Replace seed with real AI output'),
       'seed'
FROM ins_review ir;
