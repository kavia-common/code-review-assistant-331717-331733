-- Core schema for code-review assistant
-- Tables:
--  - users: authentication principals
--  - reviews: a user's submitted code review request
--  - review_results: the AI result (and any metadata) for a review
--
-- Notes:
-- - Uses BIGSERIAL for simplicity and performance.
-- - Uses TIMESTAMPTZ for all timestamps.
-- - Uses JSONB for flexible metadata and structured AI output.

CREATE TABLE IF NOT EXISTS public.users (
  id BIGSERIAL PRIMARY KEY,
  email TEXT NOT NULL,
  password_hash TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Unique, case-insensitive email.
-- (citext extension is not assumed; instead we index lower(email)).
CREATE UNIQUE INDEX IF NOT EXISTS idx_users_email_lower_unique ON public.users ((lower(email)));

CREATE TABLE IF NOT EXISTS public.reviews (
  id BIGSERIAL PRIMARY KEY,
  -- user_id is nullable to support anonymous reviews.
  -- For authenticated users, user_id references public.users(id).
  user_id BIGINT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  language TEXT NOT NULL,
  code TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'completed',
  title TEXT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Common access patterns:
-- - authenticated history: filter by user_id, newest-first
-- - global history (including anonymous): newest-first
CREATE INDEX IF NOT EXISTS idx_reviews_user_id_created_at ON public.reviews (user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_reviews_created_at ON public.reviews (created_at DESC);

CREATE TABLE IF NOT EXISTS public.review_results (
  id BIGSERIAL PRIMARY KEY,
  review_id BIGINT NOT NULL REFERENCES public.reviews(id) ON DELETE CASCADE,
  summary TEXT NULL,
  issues JSONB NULL,
  suggestions JSONB NULL,
  raw_result JSONB NULL,
  model TEXT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Enforce 1:1 relationship (one result per review) unless the product later needs multiple runs.
CREATE UNIQUE INDEX IF NOT EXISTS idx_review_results_review_id_unique ON public.review_results (review_id);
CREATE INDEX IF NOT EXISTS idx_review_results_created_at ON public.review_results (created_at DESC);
