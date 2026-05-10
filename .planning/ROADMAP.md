# Oasis Project Roadmap

## Phase 15: Home Safe Check-in

**Goal:** Implement home safe check-in with local location storage, geofence auto-detection, partner notifications, verification overlay, and custom haptic patterns.

**Status:** 📋 Planned
**Plans:** 3 plans

### Plans:
- [ ] 15-01-PLAN.md — Local storage infrastructure & HomeLocation model (TDD)
- [ ] 15-02-PLAN.md — Geofence detection & Settings UI
- [ ] 15-03-PLAN.md — Notifications, verification & haptics

**Requirements:**
[HOMESAFE-01, HOMESAFE-02, HOMESAFE-03, HOMESAFE-04, HOMESAFE-05, HOMESAFE-06]

---

## Phase 1: Codebase Cleanup
**Goal:** Remove unused legacy .dart files after migrating active dependencies.
**Status:** ✅ Completed
**Plans:** 2 plans

### Plans:
- [x] 01-01-PLAN.md — Migrate active dependencies to new entities and audit remaining references.
- [x] 01-01-SUMMARY.md — Complete
- [ ] 01-02-PLAN.md — Remove unused legacy .dart files and perform final validation. (Ready - legacy files identified)

## Phase 2: Username-based Sign-in
**Goal:** Implement secure sign-in and password reset using unique usernames or emails.
**Status:** Completed
**Plans:** None (Single-task phase)

## Phase 3: Advanced Video/Voice Calling Experience
**Goal:** Implement robust, multi-participant video/voice calling with E2EE signaling, screen sharing, and themed UI.
**Status:** ✅ Completed
**Plans:**
- [x] 03-01-PLAN.md — Implement multi-participant Mesh calls, E2EE signaling, and screen sharing.
- [x] 03-02-PLAN.md — Implement themed calling UI, participant management, and overlay controls.
- [x] VERIFICATION.md — Complete

**Requirements:**
[CLEANUP-01, CLEANUP-02, CALL-01, CALL-02, CALL-03]

## Phase 4: Scalability Improvements
**Goal:** Implement scalability patterns including pagination, offline caching, lazy loading, and retry logic to support platform growth.
**Status:** ✅ Completed
**Plans:** 4 plans

### Plans:
- [x] 04-01-PLAN.md — Exponential backoff retry infrastructure (TDD)
- [x] 04-02-PLAN.md — Cursor-based pagination infrastructure (TDD)
- [x] 04-03-PLAN.md — Hive offline caching + lazy loading
- [x] 04-04-PLAN.md — Supabase CDN image optimization

## Phase 5: PIN Recovery Mechanism
**Goal:** Set New Pin mechanism for users who have Both Forgot their pin and lost their recovery codes as well. The previous texts can't be accessed anymore but set up a mechanism for setting new pin so that the new texts are not lost anymore.
**Status:** ✅ Completed
**Plans:** 1 plan

### Plans:
- [x] 05-01-PLAN.md — Implement PIN reset via email/password with warning and new PIN setup.
- [x] 05-01-SUMMARY.md — Complete

## Phase 6: Cross-platform Subscriptions
**Goal:** Support subscriptions across multiple platforms using in_app_purchase for mobile/macOS and Razorpay for Windows.
**Status:** ✅ Completed
**Plans:** 1 plan

### Plans:
- [x] 06-01-PLAN.md — Cross-platform IAP setup and subscription infrastructure.

## Phase 7: Desktop Modal Adaptations
**Goal:** Adapt modal sheets to context menus for desktop users (right-click instead of bottom sheets).
**Status:** ✅ Completed
**Plans:** 3 plans

### Plans:
- [x] 07-01-PLAN.md — Extend MessageOptionsMenu with reactions picker (desktop).
- [x] 07-02-PLAN.md — Create AttachmentOptionsMenu for desktop right-click on attachment button.
- [x] 07-03-PLAN.md — Assessment completed - no additional modal adaptations needed.

**Requirements:**
[DESKTOP-01, DESKTOP-02]

## Phase 8: Monetization and Privacy Infrastructure
**Goal:** Implement ethical monetization via House Ads and reinforce privacy through security auditing and transparency.
**Status:** Completed
**Plans:**
- [x] 08-01-PLAN.md — Security Audit, RLS reinforcement, and Privacy Heartbeat.
- [x] 08-02-PLAN.md — Curation Tracking Service and Privacy Transparency UI.
- [x] 08-03-PLAN.md — House Ads integration and Pro-member ad removal.

**Requirements:**
[PRIVACY-01, PRIVACY-02, MONETIZATION-01, MONETIZATION-02]

## Phase 9: Privacy Sync Toggle

**Goal:** Add optional server sync toggle to Privacy Transparency feature. Fix broken tracking, add toggle for users to optionally sync analytics to server, show warning when disabling, delete server data on disable.

**Status:** ✅ Completed

**Plans:** 2 plans

Plans:
- [x] 09-01-PLAN.md — Fix local tracking (wire to actual usage) + create Supabase schema for analytics
- [x] 09-02-PLAN.md — Add server sync toggle UI with warning dialogs

**Requirements:**
[PRIVACY-02]

## Phase 11: Desktop Native UX

**Goal:** Make desktop apps feel native with context menus instead of modal sheets, right-click instead of tap-hold, and proper desktop navigation. Preserve ALL mobile UI behavior unchanged.

**Status:** ✅ Planned
**Plans:** 3 plans

### Plans:
- [ ] 11-01-PLAN.md — DesktopContextMenu infrastructure (context menu widget + SecondaryTapHandler)
- [ ] 11-02-PLAN.md — Apply context menu to PostCard + MessageReactions
- [ ] 11-03-PLAN.md — Add right-click support to ChatMessageList

**Requirements:**
[DESKTOP-01, DESKTOP-02]

## Phase 12: Full Story Implementation

**Goal:** Implement full Instagram-style Create Story feature with add/delete text overlays, background support, text styling, filters, drawing tools, M3E icons, visual music picker overhaul with search, draggable music/text positioning, artwork picker, and instant stories bar refresh after posting.

**Status:** 📋 Planned
**Plans:** 4 plans

### Plans:
- [ ] 12-01-PLAN.md — Text overlay system (multi-text, background modes, font styles)
- [x] 12-02-PLAN.md — Music picker fix and visual overhaul
- [ ] 12-03-PLAN.md — Draggable music sticker + instant stories refresh
- [ ] 12-04-PLAN.md â€” M3E icons + adaptive layout

**Requirements:**
[STORY-01, STORY-02, STORY-03, STORY-04, STORY-05]

## Phase 13: Distributed R2 Storage Integration

**Goal:** Implement Backblaze R2 for Feeds/Ripples and Cloudflare R2 for Chat attachments with client-side caching (WhatsApp-style), user-specific isolation, and E2EE for all media.

**Status:** ✅ Implemented (infrastructure complete)
**Notes:** R2 storage exists in lib/services/s3_storage_service.dart and lib/core/config/r2_config.dart. Media upload uses E2EE encryption. 2GB limit for free users already implemented via subscription service.

**Plans:** None (infrastructure complete)

## Phase 14: Couples Connection

**Goal:** Implement couples intimacy and connection features including Bubble Setup (shared spaces), Wrapped Whispers (secret messages), Favor Coupons (IOUs), Pulse/Heartbeat Sync, Flicker (thinking of you), Shared Breath (co-regulation), Mood Glow (emotional presence), Time Capsules, Dream Maps, Memory Layering, Weather themes, Parallel Stream (ambient presence), and Living Garden (relationship growth metaphor).

**Status:** ❌ Skipped (2026-05-05)
**Reason:** Feature bloat - unclear value, adds clutter, better to focus on stability and revenue.

**Plans:** None (not implementing)

---

## Phase 16: Pro Tier & Monetization

**Goal:** Implement Pro subscription tier with exclusive features and House Ads for free tier revenue.

**Status:** 📋 Planned
**Plans:** To be determined

### Features:
- Pro tier ($5/month) with:
  - Unlimited media storage (vs 30-day retention for free)
  - Vibrant color schemes (exclusive themes)
  - Custom icons
  - Higher video call quality (720p+)
  - No House Ads
- House Ads (internal, no third-party data collection)
- Media retention policy enforcement (30 days for free users)

### Requirements:
- Revenue sustainability
- Privacy-preserving ads

