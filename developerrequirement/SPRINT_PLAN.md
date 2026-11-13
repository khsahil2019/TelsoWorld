# 🏃 Telso World — Sprint Plan
**Total Sprints:** 5  
**Sprint Duration:** 2 weeks each  
**Team:** Flutter Dev + Node.js Dev + UI/UX

---

## Sprint Overview

| Sprint | Focus | Duration |
|---|---|---|
| Sprint 1 | Auth + Registration + Profile | Week 1–2 |
| Sprint 2 | Reel Feed + Upload + Outro Watermark | Week 3–4 |
| Sprint 3 | Earnings, Wallet, Payout Engine | Week 5–6 |
| Sprint 4 | Real-time, Follow System, Notifications | Week 7–8 |
| Sprint 5 | Admin Panel, KYC, Polish, Production | Week 9–10 |

---

## 🏃 Sprint 1 — Auth & Registration (Week 1–2)

### Goal
Complete both registration paths (Gmail + Manual 5-step), login, session handling, and basic profile screen.

### Backend Tasks
- [ ] `POST /reporter/register` — accept 5-step form data (username, mobile, WhatsApp, DOB, state, district, school, user_type, password, referral_code, terms_accepted)
- [ ] `POST /reporter/login` — username/password → JWT
- [ ] `POST /reporter/register/gmail` — Google OAuth token verify → create/find user
- [ ] `POST /reporter/login/gmail` — Google OAuth login
- [ ] `POST /reporter/logout` — invalidate session
- [ ] DB: add `auth_provider`, `google_id`, `terms_accepted`, `whatsapp` to users table
- [ ] Ban check middleware — blocked users get 403 immediately
- [ ] `GET /reporter/profile/:username` — public profile endpoint

### Flutter Tasks
- [ ] `ThemeController` (GetX) — light / dark / system mode
- [ ] `lib/core/theme/app_theme.dart` — `ThemeData` for both light and dark
- [ ] Bind `MaterialApp` to `ThemeController.themeMode`
- [ ] Persist theme in `shared_preferences`
- [ ] Splash screen (always dark regardless of mode)
- [ ] Login screen with "Continue with Gmail" button
- [ ] Manual registration — 5-step stepper UI:
  - Step 1: Username, Mobile No., WhatsApp No.
  - Step 2: Full Name, DOB picker (🎂), State, District, School
  - Step 3: User type selector (Musician / Student / Creator / Other)
  - Step 4: Password + Confirm Password
  - Step 5: Referral code input + T&C checkbox
- [ ] Google Sign-In integration (`google_sign_in` package)
- [ ] JWT storage via `shared_preferences`
- [ ] Registration success screen
- [ ] Profile screen (read-only view + edit mode)

### Acceptance Criteria
- ✅ User can register with 5-step form
- ✅ User can register with Gmail (skips to Step 5)
- ✅ T&C checkbox required to proceed
- ✅ Login works with username+password and Gmail
- ✅ Banned user sees error message and cannot login
- ✅ Referral code validated on register

---

## 🏃 Sprint 2 — Reels Feed + Upload + Outro (Week 3–4)

### Goal
Working video feed (normal + ads reels), upload flow with FFmpeg outro watermark, double-tap like.

### Backend Tasks
- [ ] `GET /reporter/dashboard` — paginated feed (mix normal + ads)
- [ ] `GET /reporter/ads-all-videos` — ads-only feed
- [ ] `POST /reporter/upload-video` — video + thumbnail upload (250 MB max)
- [ ] FFmpeg pipeline on upload: ensure audio + append Telso outro (logo + jingle, last 2–3 sec)
- [ ] `has_outro: true` flag set after processing
- [ ] `POST /reporter/normal-video/view` — record view, `viewed_by` check
- [ ] `POST /reporter/normal-video/like` — toggle like, `liked_by` update
- [ ] Rate limiting on upload endpoint (max 5 uploads/hour per user)
- [ ] Video status workflow: Pending → Approved/Rejected

### Flutter Tasks
- [ ] Feed screen — full-screen vertical PageView (reel swipe)
- [ ] Video player with auto-play + sound (`video_player`)
- [ ] **Double-tap → ❤️ Like animation** (Instagram-style heart burst)
- [ ] Single tap → pause/resume
- [ ] Mute toggle button
- [ ] Like, Comment, Share action buttons (right rail)
- [ ] "AD" badge on ads reels
- [ ] Upload flow:
  - Pick from gallery (`file_picker`)
  - Trim (`video_trimmer`)
  - Edit (`video_editor`)
  - Upload form (title, category, subject, thumbnail)
  - Upload progress bar (`dio`)
- [ ] Uploaded videos list screen
- [ ] Feed label: show "Earning: ₹X" badge on ads reels

### Acceptance Criteria
- ✅ Feed loads and plays reels with sound
- ✅ Double-tap likes with animation
- ✅ Ads reels show "AD" badge
- ✅ Upload completes with Telso outro appended
- ✅ All uploaded videos end with Telso logo + jingle
- ✅ Rate limit prevents spam uploads

---

## 🏃 Sprint 3 — Earnings, Wallet & Payout Engine (Week 5–6)

### Goal
Payout engine for ads reels, admin per-video payout config, wallet with earnings breakdown, KYC, withdrawals.

### Backend Tasks
- [ ] DB: add `view_payout`, `like_payout`, `comment_payout` columns to `videos`
- [ ] DB: add `default_view_payout`, `default_like_payout`, `default_comment_payout` to `settings`
- [ ] DB: add `total_view_earned`, `total_like_earned`, `total_comment_earned`, `total_referral_earned` to wallets
- [ ] DB: create `kyc` table (user_id, doc_type, doc_number, doc_image_url, status)
- [ ] Payout logic on `adsvideo/view` — check `viewed_by`, credit `view_payout`, update wallet
- [ ] Payout logic on `adsvideo/like` — check `earned_like_users`, credit `like_payout`, update wallet
- [ ] Payout logic on `comments/add` (for ads videos) — check `earned_comment_users`, credit `comment_payout`
- [ ] Transaction record created for every payout (source_type: view/like/comment/referral)
- [ ] `GET /reporter/wallet` — balance, pending, transactions, earnings breakdown
- [ ] `POST /reporter/kyc` — submit KYC docs
- [ ] Admin: set per-video payout on ads videos
- [ ] Admin: set global default payouts in settings
- [ ] Referral: credit referral reward on new user registration (dynamic amount from settings)

### Flutter Tasks
- [ ] Wallet screen: balance card + pending card
- [ ] Earnings breakdown widget (view/like/comment/referral)
- [ ] Transaction history list (paginated)
- [ ] KYC verification flow (upload Aadhaar/PAN)
- [ ] KYC status badge on profile (Pending / Verified)
- [ ] Withdrawal request form (UPI ID, amount)
- [ ] Withdrawal history

### Admin Panel Tasks
- [ ] Settings page: global default payouts (view/like/comment)
- [ ] Per-video payout editor (in video detail)
- [ ] KYC approvals list
- [ ] Withdrawal approvals list

### Acceptance Criteria
- ✅ Watching ads reel credits view payout (once only per user)
- ✅ Liking ads reel credits like payout (once only)
- ✅ Commenting on ads reel credits comment payout (once only)
- ✅ Admin can change global default payouts — takes effect immediately
- ✅ Admin can override per-video payouts
- ✅ Referral reward is dynamic (admin can change anytime)
- ✅ Wallet shows correct breakdown of earnings
- ✅ Only verified (KYC) users can withdraw

---

## 🏃 Sprint 4 — Real-time, Follow System & Notifications (Week 7–8)

### Goal
Socket.IO real-time updates, full follow/unfollow system, live notifications, search.

### Backend Tasks
- [ ] DB: create `follows` table (follower_id, following_id, created_at)
- [ ] `POST /reporter/follow` — follow a user + notify target
- [ ] `DELETE /reporter/follow` — unfollow
- [ ] `GET /reporter/followers/:userId` — paginated followers list
- [ ] `GET /reporter/following/:userId` — paginated following list
- [ ] Socket.IO server setup:
  - Emit `like_update` when video liked (all viewers of that reel)
  - Emit `comment_new` when comment posted (comment thread subscribers)
  - Emit `follower_new` when someone follows you
  - Emit `wallet_credit` when payout credited
  - Emit `notification_new` to target user
- [ ] Notification records for: new like, new comment, new follower, payout, withdrawal status

### Flutter Tasks
- [ ] Socket.IO client (`socket_io_client` package)
- [ ] Real-time like count update on reel cards
- [ ] Real-time comment count + live comment stream in comment sheet
- [ ] Follower/following count on profile updates live
- [ ] Wallet balance badge updates live on payout
- [ ] Notification bell badge updates live
- [ ] Inbox screen: notification list with mark-as-read
- [ ] Follow/Unfollow button on creator profile + reel card
- [ ] Followers list screen
- [ ] Following list screen
- [ ] Search screen: search users + videos by keyword

### Acceptance Criteria
- ✅ Like count updates live across all users viewing same reel
- ✅ New comments appear live in comment sheet
- ✅ Follower count updates instantly on follow
- ✅ Wallet balance updates live when payout credited
- ✅ Notification badge increments live
- ✅ Follow/Unfollow works with correct state
- ✅ Search returns users and videos

---

## 🏃 Sprint 5 — Admin Panel, Polish & Production (Week 9–10)

### Goal
Complete admin panel, UI polish, performance, security hardening, production readiness.

### Admin Panel Tasks
- [ ] Dashboard: total users, videos, payouts, withdrawals stats
- [ ] User management: list, search, activate, deactivate, **ban**
- [ ] Video management: list, approve, reject, delete, set payouts
- [ ] Withdrawal management: approve, reject, mark paid
- [ ] KYC management: approve, reject
- [ ] Settings: all payout defaults, referral reward, min withdrawal, SMS/SMTP/Firebase config
- [ ] Notifications panel: send push to all / specific user
- [ ] Referral campaign manager (set reward for time period)

### Flutter Polish Tasks
- [ ] Shimmer/skeleton loaders on feed and profile
- [ ] Smooth profile grid scroll (lazy load, 3-column)
- [ ] Profile tabs: Reels · Liked · Saved
- [ ] Verification badge (✅) on verified profiles and reel cards
- [ ] Offline error state (no internet banner)
- [ ] Pull-to-refresh on feed
- [ ] Video loop (auto-repeat when reel ends)
- [ ] Share to WhatsApp with reel deep link
- [ ] Dark mode full polish — all screens verified in both modes
- [ ] Light mode polish — white backgrounds, correct contrast
- [ ] Settings screen → Appearance section (Light / Dark / System toggle)
- [ ] Sun ☀️ / Moon 🌙 icon toggle in profile header
- [ ] Animated theme transition
- [ ] Admin Panel (web) CSS dark mode via `prefers-color-scheme`

### Production / Security Tasks
- [ ] nginx reverse proxy + SSL (HTTPS)
- [ ] Rate limiting (express-rate-limit) on all write endpoints
- [ ] Helmet.js security headers
- [ ] Environment variables via `.env` (no hardcoded secrets)
- [ ] Database connection pooling tuned
- [ ] CDN integration for video/image assets
- [ ] CI/CD pipeline (GitHub Actions)
- [ ] APK release build + Play Store submission prep

### Acceptance Criteria
- ✅ Admin can ban a user (immediate effect)
- ✅ All payouts configurable from admin panel
- ✅ Referral reward dynamic and changeable live
- ✅ App runs over HTTPS in production
- ✅ No hardcoded IPs or secrets in code
- ✅ All reels end with Telso World logo + tune ✅
- ✅ Profile scrolls smoothly with lazy loading
- ✅ Double-tap like works with animation everywhere

---

*Sprint plan aligned with PRD_v2.0.md*

