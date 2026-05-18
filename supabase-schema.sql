-- ================================================================
-- SPARK — Micro-Mentorship Marketplace
-- Supabase Postgres 16 Schema
-- ================================================================

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS pg_trgm; -- For full-text search

-- ── USERS (extends Supabase auth.users) ─────────────────────────
CREATE TABLE IF NOT EXISTS public.profiles (
  id          UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  role        TEXT NOT NULL CHECK (role IN ('learner', 'expert')) DEFAULT 'learner',
  name        TEXT NOT NULL,
  avatar_url  TEXT,
  created_at  TIMESTAMPTZ DEFAULT NOW(),
  updated_at  TIMESTAMPTZ DEFAULT NOW()
);

-- ── EXPERTS ─────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.experts (
  id                    UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id               UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  bio                   TEXT NOT NULL,
  title                 TEXT NOT NULL,
  company               TEXT,
  domains               TEXT[] NOT NULL DEFAULT '{}',
  session_price         INTEGER NOT NULL, -- in paise (100 = ₹1)
  rating                NUMERIC(3,2) DEFAULT 0,
  total_reviews         INTEGER DEFAULT 0,
  total_sessions        INTEGER DEFAULT 0,
  is_verified           BOOLEAN DEFAULT FALSE,
  is_available          BOOLEAN DEFAULT TRUE,
  status                TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected', 'suspended')),
  linkedin_url          TEXT,
  calendly_url          TEXT,
  stripe_account_id     TEXT, -- Stripe Connect account ID
  profile_views         INTEGER DEFAULT 0,
  created_at            TIMESTAMPTZ DEFAULT NOW(),
  updated_at            TIMESTAMPTZ DEFAULT NOW()
);

-- Full text search index on experts
CREATE INDEX IF NOT EXISTS idx_experts_search ON public.experts
  USING gin(to_tsvector('english', bio || ' ' || title || ' ' || COALESCE(company, '') || ' ' || array_to_string(domains, ' ')));

CREATE INDEX IF NOT EXISTS idx_experts_domains ON public.experts USING gin(domains);
CREATE INDEX IF NOT EXISTS idx_experts_rating ON public.experts(rating DESC);
CREATE INDEX IF NOT EXISTS idx_experts_price ON public.experts(session_price);

-- ── SESSIONS ─────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.sessions (
  id                          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  expert_id                   UUID NOT NULL REFERENCES public.experts(id),
  learner_id                  UUID NOT NULL REFERENCES public.profiles(id),
  scheduled_at                TIMESTAMPTZ NOT NULL,
  duration_minutes            INTEGER DEFAULT 20,
  status                      TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'confirmed', 'completed', 'cancelled', 'no_show')),
  learner_question            TEXT NOT NULL,
  ai_prep_agenda              TEXT,
  ai_summary                  TEXT,
  stripe_payment_intent_id    TEXT,
  stripe_charge_id            TEXT,
  amount_paid                 INTEGER, -- in paise
  platform_fee                INTEGER, -- 20% in paise
  expert_payout               INTEGER, -- 80% in paise
  zoom_link                   TEXT,
  recall_transcript           TEXT,
  created_at                  TIMESTAMPTZ DEFAULT NOW(),
  updated_at                  TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_sessions_expert ON public.sessions(expert_id);
CREATE INDEX IF NOT EXISTS idx_sessions_learner ON public.sessions(learner_id);
CREATE INDEX IF NOT EXISTS idx_sessions_scheduled ON public.sessions(scheduled_at);
CREATE INDEX IF NOT EXISTS idx_sessions_status ON public.sessions(status);

-- ── REVIEWS ──────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.reviews (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  session_id  UUID NOT NULL UNIQUE REFERENCES public.sessions(id),
  expert_id   UUID NOT NULL REFERENCES public.experts(id),
  learner_id  UUID NOT NULL REFERENCES public.profiles(id),
  rating      INTEGER NOT NULL CHECK (rating BETWEEN 1 AND 5),
  comment     TEXT,
  created_at  TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_reviews_expert ON public.reviews(expert_id);

-- ── TRIGGER: Update expert rating on new review ──────────────────
CREATE OR REPLACE FUNCTION update_expert_rating()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE public.experts
  SET
    rating = (
      SELECT ROUND(AVG(rating)::NUMERIC, 2)
      FROM public.reviews
      WHERE expert_id = NEW.expert_id
    ),
    total_reviews = (
      SELECT COUNT(*)
      FROM public.reviews
      WHERE expert_id = NEW.expert_id
    ),
    updated_at = NOW()
  WHERE id = NEW.expert_id;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_update_expert_rating
  AFTER INSERT OR UPDATE ON public.reviews
  FOR EACH ROW EXECUTE FUNCTION update_expert_rating();

-- ── TRIGGER: Increment session count on completion ───────────────
CREATE OR REPLACE FUNCTION increment_session_count()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.status = 'completed' AND OLD.status != 'completed' THEN
    UPDATE public.experts
    SET total_sessions = total_sessions + 1
    WHERE id = NEW.expert_id;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_increment_session_count
  AFTER UPDATE ON public.sessions
  FOR EACH ROW EXECUTE FUNCTION increment_session_count();

-- ── ROW LEVEL SECURITY ───────────────────────────────────────────
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.experts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reviews ENABLE ROW LEVEL SECURITY;

-- Profiles: users can read all, update own
CREATE POLICY "Profiles are publicly readable"
  ON public.profiles FOR SELECT USING (true);

CREATE POLICY "Users can update their own profile"
  ON public.profiles FOR UPDATE USING (auth.uid() = id);

-- Experts: publicly readable, owners can update
CREATE POLICY "Approved experts are publicly readable"
  ON public.experts FOR SELECT USING (status = 'approved');

CREATE POLICY "Experts can update their own record"
  ON public.experts FOR UPDATE USING (user_id = auth.uid());

-- Sessions: only participants can see
CREATE POLICY "Session participants can view"
  ON public.sessions FOR SELECT
  USING (
    learner_id = auth.uid()
    OR expert_id IN (SELECT id FROM public.experts WHERE user_id = auth.uid())
  );

CREATE POLICY "Learners can create sessions"
  ON public.sessions FOR INSERT WITH CHECK (learner_id = auth.uid());

-- Reviews: publicly readable, only session participants can write
CREATE POLICY "Reviews are publicly readable"
  ON public.reviews FOR SELECT USING (true);

CREATE POLICY "Learners can create reviews for their sessions"
  ON public.reviews FOR INSERT
  WITH CHECK (learner_id = auth.uid());
