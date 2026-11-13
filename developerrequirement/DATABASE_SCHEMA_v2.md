# 🗄️ Telso World — Database Schema v2.0
**DB:** PostgreSQL  
**Version:** 2.0 (updated from v1.0)

---

## Migration: v1.0 → v2.0

```sql
-- Add auth fields to users
ALTER TABLE users
  ADD COLUMN IF NOT EXISTS auth_provider TEXT DEFAULT 'manual',
  ADD COLUMN IF NOT EXISTS google_id TEXT,
  ADD COLUMN IF NOT EXISTS whatsapp TEXT DEFAULT '',
  ADD COLUMN IF NOT EXISTS terms_accepted BOOLEAN NOT NULL DEFAULT FALSE;

-- Add payout fields to videos
ALTER TABLE videos
  ADD COLUMN IF NOT EXISTS view_payout NUMERIC(10,4) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS like_payout NUMERIC(10,4) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS comment_payout NUMERIC(10,4) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS has_outro BOOLEAN NOT NULL DEFAULT FALSE;

-- Add payout defaults to settings
ALTER TABLE settings
  ADD COLUMN IF NOT EXISTS default_view_payout NUMERIC(10,4) NOT NULL DEFAULT 0.50,
  ADD COLUMN IF NOT EXISTS default_like_payout NUMERIC(10,4) NOT NULL DEFAULT 1.00,
  ADD COLUMN IF NOT EXISTS default_comment_payout NUMERIC(10,4) NOT NULL DEFAULT 2.00;

-- Add earnings breakdown to wallets
ALTER TABLE wallets
  ADD COLUMN IF NOT EXISTS total_view_earned NUMERIC(12,2) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS total_like_earned NUMERIC(12,2) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS total_comment_earned NUMERIC(12,2) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS total_referral_earned NUMERIC(12,2) NOT NULL DEFAULT 0;

-- Add source_type to transactions
ALTER TABLE transactions
  ADD COLUMN IF NOT EXISTS source_type TEXT DEFAULT 'manual';
```

---

## New Tables

```sql
-- Follow system
CREATE TABLE IF NOT EXISTS follows (
  id SERIAL PRIMARY KEY,
  follower_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  following_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(follower_id, following_id)
);
CREATE INDEX IF NOT EXISTS idx_follows_follower ON follows(follower_id);
CREATE INDEX IF NOT EXISTS idx_follows_following ON follows(following_id);

-- KYC verification
CREATE TABLE IF NOT EXISTS kyc (
  id SERIAL PRIMARY KEY,
  user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  doc_type TEXT NOT NULL DEFAULT 'aadhaar',  -- aadhaar | pan | passport
  doc_number TEXT DEFAULT '',
  doc_front_url TEXT DEFAULT '',
  doc_back_url TEXT DEFAULT '',
  selfie_url TEXT DEFAULT '',
  status TEXT NOT NULL DEFAULT 'pending',    -- pending | verified | rejected
  reviewer_note TEXT DEFAULT '',
  submitted_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  reviewed_at TIMESTAMPTZ
);
CREATE INDEX IF NOT EXISTS idx_kyc_user_id ON kyc(user_id);
```

---

## Full Schema (v2.0)

```sql
-- See schema.sql for base tables
-- This file documents v2.0 additions above
```

---

## Key Business Rules (DB Level)

| Rule | Enforcement |
|---|---|
| One wallet per user | `wallets.user_id` PRIMARY KEY |
| One follow per pair | `UNIQUE(follower_id, following_id)` |
| Video delete cascades comments | `ON DELETE CASCADE` |
| User delete cascades wallet, videos, comments | `ON DELETE CASCADE` |
| Payout tracked per user per video | `earned_like_users`, `earned_comment_users` JSONB (future: normalize to table) |

