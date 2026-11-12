# Telso World — Custom REST API Server & Admin Panel 🚀

A dedicated high-performance backend and web Admin Dashboard for the **Telso World** Flutter short-form video platform.

---

## ⚡ Quick Start

```bash
# 1. Navigate to the server folder
cd server

# 2. Run the server
npm start
# or with auto-restart on changes:
npm run dev
```

The server automatically starts on **Port 5050**:
- **Admin Panel URL:** [http://localhost:5050/admin](http://localhost:5050/admin)
- **API Base URL:** `http://localhost:5050/api`

---

## 🔐 Admin Panel Credentials

| Field | Default Value |
|---|---|
| **URL** | `http://localhost:5050/admin` |
| **Username** | `admin` |
| **Password** | `admin123` |

### Features in Admin Panel:
- 📊 **Dashboard Overview:** Real-time stats (Total Creators, Reels, Views, Likes, Comments).
- 🎬 **Reels & Videos Management:**
  - In-browser live video player modal to preview reels.
  - Approve, reject, or switch video between *Normal Feed* and *Ad / Promo*.
  - Upload MP4 video files directly or add by URL.
  - Edit metrics (views, likes) and delete videos.
- 👥 **Creator & User Management:**
  - View all registered musicians and reporters.
  - Inspect creator info (Academy, State, District, Referral Code).
  - **Wallet Controls:** Credit or debit creator wallet balances with custom transaction notes.
  - Ban or activate accounts.
- 💬 **Comments Moderation:**
  - View community discussions and delete abusive comments.
- ⚙️ **API Connection Hub:**
  - Instant copy buttons for Android Emulator (`10.0.2.2:5050`), iOS Simulator (`localhost:5050`), and Physical Device Wi-Fi IP (`192.168.x.x:5050`).

---

## 📱 Mobile App Connection Settings

In [`lib/core/constants/api_endpoints.dart`](../lib/core/constants/api_endpoints.dart), host resolution is automatic:
- **Android Studio Emulator:** Automatically uses `http://10.0.2.2:5050/api`
- **iOS Simulator / macOS / Web:** Automatically uses `http://localhost:5050/api`
- **Physical Phone over Wi-Fi:** Set `ApiEndpoints.customHost = '<Your-Mac-IP>:5050'` (shown on server launch and in Admin Panel).

---

## 📋 REST API Endpoints

### 1. Authentication (`/api/reporter`)
- `POST /register`: Registers creator (3-step wizard fields: name, email, phone, school, state, district, referral, password). Returns JWT token & creates ₹50 wallet welcome bonus.
- `POST /login`: Log in by email, mobile, or username + password.
- `POST /logout`: Invalidate session.
- `GET /profile`: Profile info and live wallet balance.

### 2. Video Feed & Interactions (`/api/reporter`)
- `GET /dashboard`: Feed reels list, liked states, referral code, and dashboard settings.
- `GET /ads-all-videos`: Sponsored & promotion reels.
- `POST /normal-video/view`: Increments reel view count.
- `POST /adsvideo/view`: Increments ad reel view count.
- `POST /normal-video/like`: Toggles like (liked / unliked with live count).
- `POST /adsvideo/like`: Toggles ad like.
- `POST /upload-video`: Multipart/form-data video and thumbnail upload.

### 3. Comments (`/api/comments`)
- `GET /?video_id=:id`: Video comments with author details and reply counts.
- `POST /add`: Add new comment or reply.
- `POST /like`: Toggle comment like.
- `DELETE /:id`: Delete comment.
- `GET /:id/replies`: Fetch nested comment replies.

### 4. Wallet & Referral (`/api/reporter`)
- `GET /wallet`: Wallet balance, pending amount, and transaction history.
- `GET /referral`: Referral code, dynamic invite link, and referral bonus stats.

