# ⚙️ Telso World — Feature Requirements Specification
**Version:** 1.0  
**Linked PRD:** PRD_v2.0.md

---

## FR-01: Registration System

### FR-01-A: Gmail Registration
- Integrate `google_sign_in` Flutter package
- Backend verifies Google ID token via Google API
- If new user → auto-create account with Google profile data (name, email, photo)
- If existing user → login directly
- After Gmail auth → redirect to Step 5 of registration (Referral + T&C)

### FR-01-B: Manual Registration (5 Steps)
```
Step 1: Username · Mobile No. · WhatsApp No.
Step 2: Full Name · Date of Birth · State · District · School/College
Step 3: User Type (Musician / Student / Creator / Other)
Step 4: Password · Confirm Password
Step 5: Referral Code (optional) · Accept T&C (required checkbox)
```
- Each step has validation before next is enabled
- T&C checkbox: required. Cannot proceed without acceptance
- Referral code: validated against existing codes on submit
- Duplicate username/mobile → inline error

---

## FR-02: Reel Types

### FR-02-A: Normal Reels
- `video_type = 'normal'`
- Creator uploads → goes to Pending → Admin approves
- Creator earns when others engage (admin sets rates)

### FR-02-B: Advertisement Reels
- `video_type = 'advertisement'`
- Advertiser uploads with: `budget`, `target_url`, `like_limit`
- Viewer earns money for view, like, comment
- Each video has individual payout fields:
  - `view_payout` (₹ per view)
  - `like_payout` (₹ per like)
  - `comment_payout` (₹ per comment)
- If not set per video → use admin global defaults from `settings` table
- Payout is one-time-per-user per action per video
- "AD" badge shown on feed

---

## FR-03: Payout Engine

### Rules
1. User watches ≥ 70% of ads reel → view payout credited (once per user per video)
2. User likes ads reel → like payout credited (once)
3. User comments on ads reel → comment payout credited (once)
4. Transaction record created for every credit
5. Wallet `balance` and `pending_amount` updated
6. `earned_like_users`, `earned_comment_users`, `viewed_by` JSON arrays updated

### Admin Configuration
- Global defaults in `settings`:
  - `default_view_payout` (₹)
  - `default_like_payout` (₹)
  - `default_comment_payout` (₹)
- Per-video override in `videos`:
  - `view_payout`, `like_payout`, `comment_payout`
- Admin changes take immediate effect

---

## FR-04: Telso World Outro Watermark

### Requirement
- **Every uploaded video** (normal + ads) must end with Telso World outro
- Outro: Telso World logo + tune/jingle (last 2–3 seconds)
- Applied automatically via FFmpeg during upload processing
- `has_outro` column set to `true` after processing
- Cannot be bypassed by creator

### FFmpeg Process
```
Input video → ensure audio → append outro clip → output final.mp4
```

---

## FR-05: Real-time Updates

### Implemented via Socket.IO

| Event | Trigger | Recipients |
|---|---|---|
| `like_update` | Video liked/unliked | All viewers of that video |
| `comment_new` | Comment posted | Subscribers of that video |
| `follower_new` | User followed | Target user |
| `wallet_credit` | Payout credited | Wallet owner |
| `notification_new` | Any notification | Target user |

---

## FR-06: Follow System

- `follows` table: `follower_id` + `following_id` + timestamp
- Mutual follow → "Friends" label
- Following feed: filter feed to show only followed creators' reels
- Follower/Following count on profile updates in real-time

---

## FR-07: Double-tap Like

- Tapping video once → pause/resume
- Double-tapping video → like (if not liked) with animated ❤️ burst
- If already liked → no action on double-tap (don't unlike on double-tap)
- Unlike = tap the ❤️ button in right rail

---

## FR-08: Profile Screen

### Layout (top to bottom)
1. Cover / banner area
2. Profile picture (circular, tappable to change)
3. Display name + @username + verification badge (✅ if KYC verified)
4. Bio text (tappable to edit)
5. Stats row: `X Reels · X Followers · X Following` (all tappable)
6. `[Edit Profile]` button
7. Tabs: Reels | Liked | Saved
8. 3-column scrollable grid of videos (lazy load)

---

## FR-09: Referral System

- Each user gets unique `referral_code` on registration
- Referred user enters code in Step 5
- On successful registration → referrer wallet credited with reward amount
- Reward amount = `settings.referral_reward` (admin changes anytime)
- Referral chain: `referred_by` column stores referrer's code
- Admin can run campaigns (adjust reward, track campaign period)

---

## FR-10: KYC & Wallet Verification

- User submits via app: Aadhaar / PAN + selfie
- Status: `unverified` → `pending` → `verified` / `rejected`
- Verified badge on profile
- **Withdrawals only allowed for verified users**
- Minimum withdrawal = `settings.min_withdrawal`

---

## FR-11: Admin Ban

- Admin can ban any user
- Ban effect:
  - `users.status = 'banned'`
  - All active JWTs rejected (middleware checks status on every request)
  - User sees "Account banned" message
  - User's videos hidden from feed

---

## FR-12: Dynamic Referral (Admin)

- Admin changes `settings.referral_reward` → takes effect on next referral registration
- No app update needed
- Admin can set time-limited campaigns (future: add `referral_campaign` table)

---

## FR-13: Light & Dark Mode

### Overview
- App supports **3 theme modes**: Light · Dark · System Default
- User can switch anytime from **Settings / Profile screen**
- Selected theme persisted via `shared_preferences`
- System Default → follows device OS setting (auto switch)

### Theme Color Tokens

| Token | Light Mode | Dark Mode |
|---|---|---|
| Background | `#FFFFFF` | `#09090E` |
| Surface / Card | `#F5F5F5` | `#1A1A24` |
| Primary accent | `#FF2D55` (Telso red) | `#FF2D55` |
| Text primary | `#0D0D0D` | `#F0F0F0` |
| Text secondary | `#6B6B80` | `#9999B0` |
| Icon | `#0D0D0D` | `#F0F0F0` |
| Bottom nav bar | `#FFFFFF` | `#111118` |
| Divider | `#E0E0E0` | `#2A2A38` |
| Input field bg | `#F0F0F5` | `#22222E` |
| Shimmer base | `#E8E8E8` | `#1E1E2A` |

### Flutter Implementation
- Use `ThemeData` with `ThemeMode.light` / `ThemeMode.dark` / `ThemeMode.system`
- Central theme defined in `lib/core/theme/app_theme.dart`
- GetX reactive: `ThemeController` exposed app-wide
- `MaterialApp` binds to `ThemeController.themeMode`
- All colors via `Theme.of(context).colorScheme.*` — no hardcoded colors in widgets

### Screens that need special handling
| Screen | Note |
|---|---|
| Feed (reel player) | Video overlay controls visible in both modes |
| Splash screen | Dark by default regardless of mode |
| Auth screens | Background adapts to mode |
| Admin Panel (web) | Separate CSS dark mode via `prefers-color-scheme` |

### Toggle UI
- Sun ☀️ / Moon 🌙 icon in profile screen header
- Also in **Settings** screen: `Appearance → Light / Dark / System`
- Animated transition using Flutter's built-in theme animation

### Acceptance Criteria
- ✅ Light mode renders all screens cleanly with white background
- ✅ Dark mode renders all screens with dark `#09090E` background
- ✅ System mode auto-switches when device theme changes
- ✅ Theme choice persisted across app restarts
- ✅ No hardcoded colors — all via ThemeData tokens
- ✅ Shimmer loaders match current mode
- ✅ Video player overlay visible in both modes

---

*All features referenced in SPRINT_PLAN.md with sprint assignment*

