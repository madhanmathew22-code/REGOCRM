-- ============================================================
-- Payment Collection CRM — Supabase Migration 001
-- Author: Madan Mathew / Rego Mobility
-- ============================================================

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================================
-- TABLE: profiles
-- One profile per authenticated user; created on first sign-in.
-- ============================================================
CREATE TABLE IF NOT EXISTS public.profiles (
  id           UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  org_name     TEXT,
  currency     TEXT NOT NULL DEFAULT 'INR',
  full_name    TEXT,
  avatar_url   TEXT,
  onboarded    BOOLEAN NOT NULL DEFAULT FALSE,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE public.profiles IS 'Extended user profile — org details and onboarding state.';

-- ============================================================
-- TABLE: customers
-- ============================================================
CREATE TABLE IF NOT EXISTS public.customers (
  id           UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id      UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  name         TEXT NOT NULL,
  email        TEXT,
  phone        TEXT,
  company      TEXT,
  status       TEXT NOT NULL DEFAULT 'active'
                 CHECK (status IN ('active', 'inactive', 'blocked')),
  tags         TEXT[],
  notes        TEXT,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS customers_user_id_idx ON public.customers(user_id);
CREATE INDEX IF NOT EXISTS customers_email_idx   ON public.customers(email);

COMMENT ON TABLE public.customers IS 'Corporate clients and debtors tracked by the CRM.';

-- ============================================================
-- TABLE: payments
-- ============================================================
CREATE TABLE IF NOT EXISTS public.payments (
  id                UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  customer_id       UUID NOT NULL REFERENCES public.customers(id) ON DELETE CASCADE,
  user_id           UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  invoice_number    TEXT,
  amount            NUMERIC(14, 2) NOT NULL CHECK (amount >= 0),
  amount_paid       NUMERIC(14, 2) NOT NULL DEFAULT 0 CHECK (amount_paid >= 0),
  due_date          DATE,
  paid_date         DATE,
  status            TEXT NOT NULL DEFAULT 'draft'
                      CHECK (status IN ('draft', 'sent', 'paid', 'overdue', 'partial')),
  payment_link_mock TEXT,
  description       TEXT,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS payments_user_id_idx     ON public.payments(user_id);
CREATE INDEX IF NOT EXISTS payments_customer_id_idx ON public.payments(customer_id);
CREATE INDEX IF NOT EXISTS payments_status_idx      ON public.payments(status);
CREATE INDEX IF NOT EXISTS payments_due_date_idx    ON public.payments(due_date);

COMMENT ON TABLE public.payments IS 'Invoice / payment records linked to customers.';

-- ============================================================
-- FUNCTION: handle_new_user
-- Auto-creates a profile stub on auth.users insert.
-- ============================================================
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.profiles (id, full_name, avatar_url, onboarded)
  VALUES (
    NEW.id,
    NEW.raw_user_meta_data ->> 'full_name',
    NEW.raw_user_meta_data ->> 'avatar_url',
    FALSE
  )
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$;

-- Trigger on new auth user
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- ============================================================
-- FUNCTION: updated_at auto-stamp
-- ============================================================
CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;

CREATE TRIGGER set_profiles_updated_at  BEFORE UPDATE ON public.profiles  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
CREATE TRIGGER set_customers_updated_at BEFORE UPDATE ON public.customers FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
CREATE TRIGGER set_payments_updated_at  BEFORE UPDATE ON public.payments  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- ============================================================
-- ROW LEVEL SECURITY
-- ============================================================
ALTER TABLE public.profiles  ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.customers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payments  ENABLE ROW LEVEL SECURITY;

-- profiles: owner only
CREATE POLICY "profiles: owner read"   ON public.profiles FOR SELECT USING (auth.uid() = id);
CREATE POLICY "profiles: owner insert" ON public.profiles FOR INSERT WITH CHECK (auth.uid() = id);
CREATE POLICY "profiles: owner update" ON public.profiles FOR UPDATE USING (auth.uid() = id) WITH CHECK (auth.uid() = id);

-- customers: owner only
CREATE POLICY "customers: owner read"   ON public.customers FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "customers: owner insert" ON public.customers FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "customers: owner update" ON public.customers FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "customers: owner delete" ON public.customers FOR DELETE USING (auth.uid() = user_id);

-- payments: owner only
CREATE POLICY "payments: owner read"   ON public.payments FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "payments: owner insert" ON public.payments FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "payments: owner update" ON public.payments FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "payments: owner delete" ON public.payments FOR DELETE USING (auth.uid() = user_id);

-- ============================================================
-- CONVENIENCE VIEW: payment_summary
-- ============================================================
CREATE OR REPLACE VIEW public.payment_summary AS
SELECT
  p.user_id,
  DATE_TRUNC('month', p.created_at) AS month,
  COUNT(*)                           AS invoice_count,
  SUM(p.amount)                      AS total_invoiced,
  SUM(p.amount_paid)                 AS total_collected,
  SUM(p.amount - p.amount_paid)      AS total_outstanding,
  SUM(CASE WHEN p.status = 'paid'    THEN p.amount ELSE 0 END) AS paid_amount,
  SUM(CASE WHEN p.status = 'overdue' THEN p.amount ELSE 0 END) AS overdue_amount,
  SUM(CASE WHEN p.status IN ('draft','sent','partial') THEN p.amount ELSE 0 END) AS pending_amount
FROM public.payments p
GROUP BY p.user_id, DATE_TRUNC('month', p.created_at);

COMMENT ON VIEW public.payment_summary IS 'Month-over-month collection aggregates per user.';
