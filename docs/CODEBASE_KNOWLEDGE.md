# Oasis — Codebase Knowledge Guide

> Written for the vibe coder who wants to actually understand what they built.
> Covers what every directory does, the boot sequence, architecture patterns, and known quirks.
> App version: 1.1.15 · ~626 Dart files / ~132k lines in `lib/`.

---

## What this app is

**Oasis** is a privacy-first social media app (a "calmer, encrypted social network") built with **Flutter**, backed by **Supabase**, with E2EE messaging, short-video ("Ripples"), stories, private group "Circles", collaborative "Canvas" timelines, time capsules, a heavy **digital-wellbeing engine** (energy meters, screen-time limits, study rooms, zen mode), and **monetization** (Oasis Pro subscription + micro-transactions).

**Stack:** Flutter (Dart) → Supabase (PostgreSQL + RLS + Realtime + Edge Functions) → Firebase (push notifications) → LiveKit (WebRTC calls) → Cloudflare R2 (media) → RevenueCat/Razorpay (payments). Plus a Next.js marketing site in `landing/`.

---

## The `lib/` anatomy (top-level)

| Dir | Lines | Job |
|---|---|---|
| `core/` | 3.5k | Shared infrastructure: config, crypto bridge, network, storage, result types, utils |
| `features/` | 85k | **The actual app** — 20 feature modules, each in clean architecture |
| `services/` | 14.5k | App-level singletons (auth, notifications, wellness, calls, IAP…) |
| `screens/` | 8k | Legacy/global screens (settings, search, spaces, community, legal) |
| `widgets/` | 10.8k | Reusable cross-feature widgets |
| `providers/` | 1.2k | Global state: conversations, presence, typing, community |
| `models/` | 2k | Legacy data models (duplicated by newer feature-folder models) |
| `routes/` | 2.4k | go_router config, navigation shell, guards |
| `themes/` | 1.7k | Theme + M3E/HSL/color-palette system |
| `painters/` | 213 | Custom drawing painters (canvas strokes, pulse map) |

### The core rule to remember

Every feature folder follows the same clean-architecture pattern:

```
features/<name>/
  domain/   →  models (freezed/entities), repositories (abstract), usecases
  data/     →  datasources (Supabase/remote/local), repositories (impl)
  presentation/  →  providers (ChangeNotifier), screens, widgets
```

State management is **Provider/ChangeNotifier** (no Riverpod, no Bloc). UI reads providers with `Consumer`/`context.watch`; providers call usecases → repository impls → datasources → Supabase.

---

## `main.dart` — the boot sequence

1. `WidgetsFlutterBinding.ensureInitialized()` → global error handlers that **silence specific network/realtime exceptions** and send everything else to **Sentry**.
2. `AppInitializer.runWithSentry()` → load `.env` (or `--dart-define`) → init **Firebase** (FCM background handler for calls via CallKit).
3. Splash screen → `AppInitializer.initCore()` (in `lib/services/app_initializer.dart`):
   - **Critical phase:** Hive + Supabase + SharedPrefs in parallel; CallKit event listeners; `AuthProvider.restoreSession()`; load theme + user settings.
   - **Background phase:** wellness services (screen time, energy meter, digital wellbeing, study sessions), notification manager, then deferred IAP/RevenueCat/encryption/Signal/PQAura inits (15s timeout, never fatal).
4. `buildProviderTree()` registers ~35 providers via `MultiProvider` (Auth, Theme, Feed, Profile, Conversation, Presence, Call, Circles, Canvas, Capsules, Stories, Collections, Monetization…).
5. `MyApp` renders either a **FluentApp** (Windows/macOS) or **MaterialApp** (mobile/web), with cached themes, Mica/window effects, Windows title bar, and a `CallNavigator` wrapper.
6. On auth change → `_handleInitialization(userId)` fires data loads on a stagger (notifications+presence immediately, conversations +100ms, profile +200ms, circles/canvas/calls +500ms). This staggering is deliberate — it prioritizes the first frame.

**Routes** are defined in `lib/routes/app_router.dart` (~2000 lines). The `redirect` closure is the auth gate: public routes (`/login`, `/register`, `/reset-password`…), onboarding gate, **decoy mode** gate (stealth calendar), login-only route bounce. `MainLayout` is the shell with desktop NavigationRail vs mobile bottom-nav, sliding search/notifications panels, Ctrl+1..6 shortcuts, unread badges, and a **create** FAB (post/ripple/capsule).

---

## Feature-by-feature breakdown

### `messages` (biggest — 24k lines, the heart)

- **Three-layer encryption**, picked at send time by `ChatEncryptionProvider`:
  1. **PQ-Aura** (newest, post-quantum): hybrid X25519 + **ML-KEM-1024** with a Double-Ratchet state machine, backed by a **Rust core** via FFI (`core/crypto/pq_aura_bridge.dart`), WASM on web. Session state persisted (native: encrypted files; web: server-side via `pq-aura-proxy` Edge Function).
  2. **Signal protocol** (`data/signal/`): wraps `libsignal_protocol_dart`, full prekey bundle uploaded to Supabase; sessions stored in SharedPreferences.
  3. **Legacy RSA hybrid** (`data/encryption_service.dart`, 1014 lines): AES-256-GCM per message, AES key wrapped per-recipient with 2048-bit RSA keys, all in isolates via `compute()`. This is still the primary/fallback path.
- **Send flow** (in `ChatProvider.sendMessage`): generate UUID → build **optimistic** message (status `sending`) → encrypt → enqueue to a **SharedPreferences outbox** (`msg_queue_<conversationId>`) for offline → call `send_message_v3` RPC → on realtime echo or RPC return, reconcile via the `clientIdToServerId` map → status `sent`/`delivered`/`read`. Failures stay `failed` and retry with backoff.
- **Receive:** Supabase Realtime channels per conversation (`messages:<id>`), decrypt via `ChatDecryptionService` (PQ-Aura → Signal → RSA), auto-download encrypted media, drop expired ephemerals.
- **Media:** encrypted → uploaded to Cloudflare R2 via presigned-URL Edge Function (`ChatMediaService`).
- **Screens:** `direct_messages_screen.dart` (DM hub with a bento "bubble grid" view), `chat_screen.dart`, `chat_details_screen.dart` (theming/backgrounds), `encryption_setup_screen.dart`, plus bubble renderers for every type (text/image/voice/video/document/location/reply/post-share/system) under `widgets/bubbles/`.
- **Conversations** cached by `lib/providers/conversation_provider.dart`: SharedPreferences cache → instant paint, refresh via RPC `get_user_conversations_v2`, realtime + 10s polling fallback.

### `feed`, `ripples`, `stories` (the social content)

- **Feed:** `FeedProvider` + `FeedState`; **unified feed** RPC (`get_unified_feed`) with cursor (timestamp) pagination, 20/page. `FeedRepositoryImpl` **injects a house ad every 5th post for non-Pro users**. `post_card.dart` (1442 lines) renders everything: media carousels, moods, polls, spoilers, hashtags, collaborators, animated likes. Multiple experimental layouts (`ClassicFeedLayout`, `FocusedFlowLayout`, `SpatialGliderLayout`, `LivingCanvasLayout`, `PulseFeedScreen` with gyroscope parallax).
- **Ripples:** TikTok-style short videos. `RipplesScreen` has a 3D "kinetic card stack" + desktop 3-pane view; `choiceMosaic` grid layout. Ad injection same pattern. **Adaptive lockout**: short sessions → multiplier → longer lockout (wellbeing enforcement). Ripples have NO pagination (one big list).
- **Stories:** Instagram-style, 24h expiry. `create_story_screen.dart` (2808 lines) is a full editor — camera, filters, text/drawing layers, music — that composites layers into one image before upload. `StoryViewScreen` auto-advances with per-story progress bars. Viewers tracking, emoji reactions, "close friends" toggle.

### `auth`, `profile`, `settings`, `onboarding` (identity)

- **Auth:** email (or **username** — resolved via RPC), Google, Apple. `AuthService` (singleton) is the orchestrator: multi-account registry, encryption key provisioning on login, RevenueCat identify, FCM token sync, account switching that **resets all feature providers**. `auth/domain/` holds clean usecases.
- **Encryption provisioning** (`services/auth/encryption_provisioner.dart` + `key_management_service.dart`): RSA keygen in isolates, secure-storage keys per user (`rsa_private_key_<userId>`), encrypted private-key backup in the `profiles` table. **Known vulnerability being fixed:** the legacy backup key was `sha256(userId)`; new path is Argon2id PIN-based v2 (`deriveSecureBackupKey`). `EncryptionStatus` drives the security-upgrade PIN overlay in the shell.
- **Profile:** follow graph, private accounts, followers/following, avatar/banner upload.
- **Settings:** `UserSettingsProvider` (font, Mica, window effects, data saver, font size, feed layout) — remote-first sync to `profiles`. Includes **2FA screen that is a stub** ("feature currently unavailable"), Vault (PIN), privacy heartbeat (audit logs), data export, delete account (RPC), storage usage, stealth settings.
- **Decoy/Stealth mode** (`decoy_provider.dart`): a PIN-protected fake calendar screen that disguises the app; uses a native MethodChannel `oasis/stealth_mode` to change the app icon/label.
- **Onboarding:** 7-page shell with glassmorphism + animated blobs, contacts permission page (numbers hashed locally), and an **Instagram ZIP migration** flow.

### `circles`, `canvas`, `capsules`, `collections`, `couples` (Spaces tab)

- **Circles:** private invite-only friend groups with daily **commitments** and a shared feed. Glass-jar/streak theme, hold-to-fill "mark complete" (1500ms + haptic).
- **Canvas:** NOT a whiteboard — a shared **timeline scrapbook** where members pin photos, voice memos, journals, milestones, doodles at x/y positions on an infinite canvas, with time-locked items and realtime presence. Starry-night background, polaroid scatter, timeline scrubber.
- **Capsules:** E2EE time-locked messages. `openCapsule` flips `is_locked` server-side once `unlockDate` passes; decryption is client-side. Free tier: **2 locked capsules** (Pro unlimited).
- **Collections:** private saved-post folders. Free: **3 collections / 50 items**.
- **Couples:** partner pairing + **home check-in** — geofence detects arrival, app asks "Did you reach home?", sends an "at home" boolean (never the location) to the partner's phone via FCM.

### `wellness` (the signature differentiator)

- **Energy meter:** gamified currency — expanding a post costs 15, viewing 2, liking 1; recovers 5/min. Blocks interactions when empty.
- **Screen time:** per-category tracking, 120-min daily limit, quiet mode, hourly breakdown.
- **Zen mode / Focus sessions / Wind down:** pauses notifications, +50 XP completion / −35 XP early exit, dims the UI after bedtime (Pro), XP/achievements/streaks.
- **Study rooms** (`study_sessions`): create/join shared sessions, 1 XP/min, lock-in penalties.
- **Digital wellbeing UI decay:** near screen-time limits the feed gets progressively grayscale + blurred (`GrayscaleDetox`, `LockoutOverlay`).
- **Duplication warning:** wellness logic exists twice — in `services/*` (what the UI uses) and re-implemented in `features/wellness/*` (clean-architecture layer). They can drift.

### `calling`, `notifications`, `search`, `sharing`, `monetization`

- **Calling:** LiveKit WebRTC (P2P or SFU). **E2EE calls**: a random 32-byte LiveKit key encrypted to the receiver's PQ-Aura public key, delivered over a Realtime broadcast channel. `CallService` handles ringing, stale-call filtering, desktop notifier; `CallKit` on mobile with a separate lightweight `callingMain()` entry point for background incoming calls.
- **Notifications:** `NotificationProvider` (paged), Realtime per-user channel, `NotificationManager` (WinToast on Windows, FCM/local on mobile), **ciphertext-hiding** ("🔒 Encrypted message" until decrypted), Zen-mode suppression, per-conversation grouping.
- **Search:** parallel users/posts/hashtags search + trending hashtags.
- **Sharing:** `receive_sharing_intent` for incoming share intents (queue with retry), `share_plus` external, share-to-DM modal.
- **Monetization:** "Oasis Aura Shop" (`ShopScreen`) — cosmetic themes, circle boost tokens, storage upgrades ($0.99–$2.99). **Privacy-preserving ads** (`PrivacyAdService`): bulk-fetch the campaign catalog, then **match ads locally on-device** — no user data sent to ad servers. Pro subscription via RevenueCat, direct payments via Razorpay.

---

## Infrastructure dirs

### `lib/core/`

- `config/` — `AppConfig` (feature flags via `--dart-define`, pitch mode), `SupabaseConfig` (all table/function/bucket name constants), `FeatureFlags`.
- `crypto/` — `pq_aura_bridge.dart`: FFI bindings to the Rust post-quantum core.
- `network/` — `SupabaseService` singleton wrapper (init, auth, storage, public URLs), retry service.
- `storage/` — `HiveService`, `PrefsStorage` (SharedPreferences), `SecureStorage` (flutter_secure_storage), `CacheService`.
- `pagination/`, `result/`, `errors/`, `extensions/`, `utils/`, `theme/`, `providers/` (`SafeChangeNotifier` base).

### `lib/services/` (67 app-level services)

Auth orchestrator, all wellness services, notifications (3 services), calling, media cache/download/retention, IAP trio (RevenueCat/Razorpay/purchases-flutter), S3/R2 storage, moderation, presence, update checker (auto-update dialog in `main.dart`), deep links, Instagram migration, Spotify (music for stories), voice transcription, smart replies, data export, pricing, session registry, vault. Many are singletons.

### `supabase/` (the real backend)

- **~80 SQL migrations** telling a story of rapid iteration (many `FIX_*`, `*_FINAL`, `HARD_RESET`, `FINAL_FIX_*` files — classic vibe-coding). `old_schema/` holds the entire original schema, superseded by `NEW_BACKEND/MASTER_DATABASE_SCHEMA_FINAL.sql`.
- **Edge Functions** (TypeScript): `generate-livekit-token`, `push-notifications`, `delete-expired-messages`, `razorpay-*`, `revenuecat-webhook`, `pq-aura-proxy`, `transcribe-voice`, `giphy-proxy`, `klipy-proxy`, `spotify-*`, `get-user-country`, `task-runner`, `verify-iap`.
- Key RPCs: `get_unified_feed`, `get_user_conversations_v2`, `send_message_v3`, `get_following_stories`, `increment_xp`, `delete_user_account`.

### `database/sql/` — one-off fix scripts (not the schema source of truth; that's `supabase/`).

### `landing/` — a separate **Next.js 16 + React 19 + Three.js** marketing site (hero, launch countdown, pricing, beta-waitlist form via Supabase, launch-notify API). Deployed to Vercel/Netlify (`vercel.json`, `netlify.toml`). The `/api/check-update` endpoint feeds the in-app update checker.

### Platform dirs

- `android/` — includes a native `OasisMessagingService.kt` that renders encrypted notifications natively (ciphertext shown until decrypted); `OasisCallActivity` for the incoming-call overlay + the `oasis/call_intent` MethodChannel.
- `windows/` — Win32 runner with `windows_title_bar`, Mica/acrylic effects, tray, msix packaging (`msix_config` in pubspec).
- `ios/`, `linux/`, `macos/`, `web/`, `build/` — standard Flutter scaffolding.

### `plugins/`, `fluent_ui/`, `stubs/`

- `plugins/flutter_liquid_glass/` — a **vendored/forked** package (post-quantum-era "Liquid Glass" UI effect).
- `fluent_ui/` — a **forked copy** of the Fluent UI package (dependency override to local path — likely patched for M3E integration).
- `stubs/` — local stubs for `flutter_secure_storage_windows` and `flutter_local_notifications_windows` (because the pub versions broke on Windows). This is a notable maintenance trap: you're pinned to forked/vendored deps.

### Other top-level

- `.github/workflows/` — `release.yml` (build + GitHub release), `pr_checks.yml` (Flutter CI), `build-pq-aura-wasm.yml` (Rust→WASM), `build_macos.yml`.
- `scripts/` — build/packaging PS1 scripts, icon generation, Reddit poster bot (`reddit_poster.py`), version bumping.
- `docs/`, `*.md` plans — `MONETIZATION_IMPLEMENTATION_PLAN.md`, `P0_FIXES_DOCUMENTATION.md`, `STUDY_SESSIONS_PLAN.md`, etc. These read like AI-generated planning artifacts.
- `apks/`, `certs/`, `cmake-3.29.3-windows-x86_64/`, `.sentry-native/` — build artifacts and the packaged Win toast runtime.

---

## Vibe-coder telltales you should know about

1. **Dead/duplicate code:** two `Community` classes, two `AppNotification` models, two `CacheService`/`energy` implementations; `lib/screens/messages/chat_details_screen.dart` is 1218 lines of commented-out legacy; `registration_screen.dart` is a random mock DM screen in the auth folder; `FeedList` is an offline mock; `feed_layout_strategy.dart` + models/ duplicates feature-folder types.
2. **Placeholder features:** 2FA screen is a stub; voice comments in the composer are UI-only ("stubbed pending schema change").
3. **Schema churn:** dozens of `FIX_*`/`*_FINAL` migrations plus a `HARD_RESET_DATABASE.sql` — the database has been repeatedly patched rather than redesigned. RPC overloads (send_message v1/v2/v3) exist to avoid breaking old callers.
4. **Security migration in flight:** the legacy `sha256(userId)` backup-key derivation is explicitly flagged as a vulnerability being replaced by Argon2id PIN-based recovery (`EncryptionStatus.needsSecurityUpgrade` drives the PIN overlay).
5. **Vendored dependencies** (`fluent_ui`, `liquid_glass_renderer`, stubs) pinned via `dependency_overrides` — upstream updates require manual re-forking.
6. **Every big screen is one giant file** (`chat_screen.dart` 1361 lines, `direct_messages_screen.dart` 2305, `post_card.dart` 1442, `create_story_screen.dart` 2808, `profile_screen.dart` ~57KB).
