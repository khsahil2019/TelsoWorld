# 📋 Telso World — Developer Requirements Index
**Folder:** `/developerrequirement/`  
**Last Updated:** November 2026

---

## Files in This Folder

| File | Description |
|---|---|
| [PRD_v2.0.md](./PRD_v2.0.md) | Full Product Requirements Document — features, tech stack, architecture, API, DB schema |
| [SPRINT_PLAN.md](./SPRINT_PLAN.md) | 5-sprint development plan with tasks, acceptance criteria |
| [FEATURE_REQUIREMENTS.md](./FEATURE_REQUIREMENTS.md) | Detailed feature-by-feature specifications (FR-01 to FR-12) |
| [DATABASE_SCHEMA_v2.md](./DATABASE_SCHEMA_v2.md) | PostgreSQL v2.0 schema — migration SQL + new tables |

---

## Quick Reference

### New in v2.0 (this update)
- ✅ Light mode ☀️ + Dark mode 🌙 + System default ⚙️ (theme toggle in profile + settings)
- ✅ Gmail + Manual registration (5-step)
- ✅ T&C checkbox required
- ✅ WhatsApp field + DOB (Happy Birthday 🎂)
- ✅ Ads reels: viewer earns on view + like + comment
- ✅ Per-video payout amounts (admin configures)
- ✅ Global default payouts in settings
- ✅ Dynamic referral amount (admin changes live)
- ✅ All reels end with Telso World logo + tune (FFmpeg)
- ✅ Double-tap to like (Instagram-style)
- ✅ Real-time likes, comments, followers (Socket.IO)
- ✅ Follow / Following system
- ✅ Wallet with KYC verification
- ✅ Admin ban system
- ✅ Smooth profile grid with lazy scroll

### Tech Stack Summary
```
Frontend   →  Flutter (GetX) — Android, iOS, Web
Backend    →  Node.js + Express.js (port 5050)
Database   →  PostgreSQL
Real-time  →  Socket.IO
Video      →  FFmpeg (outro watermark + audio fix)
Auth       →  JWT + Google OAuth 2.0
```

### Sprint Timeline
```
Sprint 1  (Wk 1–2)  →  Auth + Registration
Sprint 2  (Wk 3–4)  →  Feed + Upload + Outro
Sprint 3  (Wk 5–6)  →  Earnings + Wallet + KYC
Sprint 4  (Wk 7–8)  →  Real-time + Follow + Notifications
Sprint 5  (Wk 9–10) →  Admin Panel + Polish + Production
```

