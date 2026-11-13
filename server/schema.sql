-- Telso World PostgreSQL Relational Schema

CREATE TABLE IF NOT EXISTS admin (
  id INTEGER PRIMARY KEY DEFAULT 1,
  username TEXT NOT NULL UNIQUE,
  password TEXT NOT NULL,
  name TEXT NOT NULL DEFAULT 'System Admin',
  email TEXT NOT NULL DEFAULT 'admin@telsoworld.com'
);

CREATE TABLE IF NOT EXISTS settings (
  id INTEGER PRIMARY KEY DEFAULT 1,
  name TEXT NOT NULL DEFAULT 'dashboard_config',
  file_uploaded TEXT DEFAULT '1',
  value TEXT,
  app_name TEXT DEFAULT 'Telso World',
  referral_reward NUMERIC(12, 2) NOT NULL DEFAULT 50.00,
  min_withdrawal NUMERIC(12, 2) NOT NULL DEFAULT 100.00,
  sms JSONB NOT NULL DEFAULT '{}'::jsonb,
  smtp JSONB NOT NULL DEFAULT '{}'::jsonb,
  firebase JSONB NOT NULL DEFAULT '{}'::jsonb,
  platform JSONB NOT NULL DEFAULT '{}'::jsonb,
  notifications_log JSONB NOT NULL DEFAULT '[]'::jsonb,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS users (
  id SERIAL PRIMARY KEY,
  name TEXT NOT NULL DEFAULT '',
  username TEXT NOT NULL UNIQUE,
  email TEXT DEFAULT '',
  mobile_no TEXT DEFAULT '',
  whatsapp TEXT DEFAULT '',
  school_name TEXT DEFAULT '',
  dob TEXT,
  state TEXT DEFAULT '',
  district TEXT DEFAULT '',
  password TEXT NOT NULL,
  referral_code TEXT UNIQUE,
  referred_by TEXT,
  user_type TEXT DEFAULT 'musician',
  role TEXT DEFAULT 'creator',
  status TEXT DEFAULT 'active',
  profile_image TEXT DEFAULT '',
  bio TEXT DEFAULT '',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS videos (
  id SERIAL PRIMARY KEY,
  user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
  name TEXT DEFAULT 'Creator',
  username TEXT DEFAULT 'creator',
  title TEXT DEFAULT 'New Reel',
  subject TEXT DEFAULT '',
  category TEXT DEFAULT 'General',
  video_url TEXT DEFAULT '',
  video_path TEXT DEFAULT '',
  thumbnail_url TEXT DEFAULT '',
  image TEXT DEFAULT '',
  target_url TEXT DEFAULT '',
  budget NUMERIC(12, 2) DEFAULT 0.00,
  duration TEXT DEFAULT '',
  audio_title TEXT DEFAULT '',
  audio_artist TEXT DEFAULT '',
  has_audio BOOLEAN NOT NULL DEFAULT TRUE,
  video_type TEXT NOT NULL DEFAULT 'normal',
  status TEXT NOT NULL DEFAULT 'Pending',
  view_count INTEGER NOT NULL DEFAULT 0,
  likes_count INTEGER NOT NULL DEFAULT 0,
  shares_count INTEGER NOT NULL DEFAULT 0,
  comments_count INTEGER NOT NULL DEFAULT 0,
  liked_by JSONB NOT NULL DEFAULT '[]'::jsonb,
  viewed_by JSONB NOT NULL DEFAULT '[]'::jsonb,
  earned_like_users JSONB NOT NULL DEFAULT '[]'::jsonb,
  earned_comment_users JSONB NOT NULL DEFAULT '[]'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS comments (
  id SERIAL PRIMARY KEY,
  video_id INTEGER NOT NULL REFERENCES videos(id) ON DELETE CASCADE,
  user_id INTEGER REFERENCES users(id) ON DELETE SET NULL,
  user_name TEXT DEFAULT 'User',
  username TEXT DEFAULT 'user',
  comment TEXT NOT NULL,
  profile_image TEXT DEFAULT '',
  likes INTEGER NOT NULL DEFAULT 0,
  liked_by JSONB NOT NULL DEFAULT '[]'::jsonb,
  reply_count INTEGER NOT NULL DEFAULT 0,
  parent_id INTEGER REFERENCES comments(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS wallets (
  user_id INTEGER PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  balance NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
  pending_amount NUMERIC(12, 2) NOT NULL DEFAULT 0.00
);

CREATE TABLE IF NOT EXISTS transactions (
  id TEXT PRIMARY KEY,
  user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  title TEXT NOT NULL DEFAULT '',
  description TEXT DEFAULT '',
  amount NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
  type TEXT NOT NULL DEFAULT 'credit',
  status TEXT NOT NULL DEFAULT 'completed',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS withdrawals (
  id TEXT PRIMARY KEY,
  user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  user_name TEXT DEFAULT '',
  amount NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
  upi_id TEXT DEFAULT '',
  account_holder TEXT DEFAULT '',
  status TEXT NOT NULL DEFAULT 'pending',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS web_links (
  id SERIAL PRIMARY KEY,
  user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
  subject TEXT DEFAULT '',
  name TEXT DEFAULT '',
  like_limit TEXT DEFAULT '1,000',
  state TEXT DEFAULT '',
  district TEXT DEFAULT '',
  web_link TEXT DEFAULT '',
  utr TEXT DEFAULT '—',
  status TEXT NOT NULL DEFAULT 'Pending',
  current_likes INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS notifications (
  id TEXT PRIMARY KEY,
  user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
  title TEXT NOT NULL DEFAULT 'Notification',
  message TEXT DEFAULT '',
  body TEXT DEFAULT '',
  type TEXT DEFAULT 'info',
  icon TEXT DEFAULT 'bell',
  color TEXT DEFAULT 'blue',
  avatar TEXT DEFAULT '',
  action_url TEXT DEFAULT '',
  action_text TEXT DEFAULT '',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  is_read BOOLEAN NOT NULL DEFAULT FALSE,
  read BOOLEAN NOT NULL DEFAULT FALSE
);

CREATE INDEX IF NOT EXISTS idx_users_mobile ON users(mobile_no);
CREATE INDEX IF NOT EXISTS idx_videos_user_id ON videos(user_id);
CREATE INDEX IF NOT EXISTS idx_videos_status_type ON videos(status, video_type);
CREATE INDEX IF NOT EXISTS idx_comments_video_id ON comments(video_id);
CREATE INDEX IF NOT EXISTS idx_transactions_user_id ON transactions(user_id);
CREATE INDEX IF NOT EXISTS idx_notifications_user_id ON notifications(user_id);
CREATE INDEX IF NOT EXISTS idx_web_links_user_id ON web_links(user_id);

