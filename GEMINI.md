# Oasis — AI Agent Guide

> **Version:** 1.1.21 · **Framework:** Flutter (Dart SDK ^3.8.0) · **Backend:** Supabase + Firebase  
> This file is the single source of truth for any AI agent working in this repository.  
> Keep it up-to-date when major architecture decisions change.

---

## What Is Oasis?

Oasis is a **cross-platform social media app** (Android, iOS, Web, Windows, macOS, Linux) built with Flutter. It is a feature-rich social platform with:

- Social feed (posts, ripples, stories/capsules, circles)
- Encrypted real-time messaging (Signal Protocol + LiveKit calling)
- Wellness & digital-wellbeing tracking (focus sessions, energy meter, screen time)
- Creative canvas (infinite canvas with collaborative tools)
- Monetization (IAP subscriptions, privacy-first ads)
- Vault (biometric-protected secret space)

---

## Repository Layout

```
oasis/
├── lib/
│   ├── main.dart               # App entry point, theme init, auth subscription
│   ├── core/                   # Shared utilities, theme, result types, constants
│   │   ├── theme/              # OasisColors, OasisTextStyles, AppTheme
│   │   ├── storage/            # HiveService (local persistence)
│   │   └── utils/              # Error parser, responsive layout helpers
│   ├── features/               # Feature-sliced architecture (20 features)
│   │   ├── auth/               # Auth, session, account switching, migration
│   │   ├── calling/            # LiveKit voice/video calls, call entities
│   │   ├── canvas/             # Infinite canvas, shape recognizer, timeline
│   │   ├── capsules/           # Time-locked stories (capsules)
│   │   ├── circles/            # Private group communities
│   │   ├── collections/        # Bookmark collections
│   │   ├── couples/            # Couples-mode feature
│   │   ├── feed/               # Social feed, posts, comments, ripples
│   │   ├── messages/           # Encrypted DMs, group chats, media sharing
│   │   ├── monetization/       # IAP, subscriptions, privacy-first ad service
│   │   ├── notifications/      # Push notifications, local notifications
│   │   ├── onboarding/         # Welcome flow, celebration screen, permissions
│   │   ├── profile/            # User profiles, follow graph, profile management
│   │   ├── ripples/            # Short-video / ripple content type
│   │   ├── search/             # Universal search across content and users
│   │   ├── settings/           # Privacy, account, encryption, font, storage
│   │   ├── sharing/            # Cross-app share targets
│   │   ├── spaces/             # Audio/video social spaces
│   │   ├── stories/            # Ephemeral stories with music
│   │   └── wellness/           # Focus sessions, energy meter, achievements
│   ├── models/                 # Shared data models
│   ├── painters/               # Custom Flutter painters
│   ├── providers/              # Cross-feature state providers
│   ├── routes/                 # Route paths and navigation (go_router style)
│   ├── screens/                # Top-level screens (feed, DMs, profile wrappers)
│   ├── services/               # App-wide services (call, vault, wellness, analytics)
│   ├── themes/                 # ThemeProvider, dynamic theming
│   └── widgets/                # Shared widgets (adaptive scaffold, bubbles, glass card)
├── supabase/                   # Supabase migrations, edge functions, RLS policies
├── database/                   # SQL schema and seed data
├── landing/                    # Web landing page (HTML/TS)
├── assets/                     # Images, fonts, Lottie animations
├── android/ ios/ web/ windows/ # Platform-specific shells
└── graphify-out/               # Knowledge graph (graph.json, GRAPH_REPORT.md, graph.html)
```

---

## Architecture: Feature-Slice + Clean Architecture

Each feature under `lib/features/<feature>/` follows this layered structure:

```
<feature>/
├── data/
│   ├── datasources/       # Remote (Supabase) and local (Hive/SQLite) datasources
│   ├── repositories/      # Repository implementations
│   └── services/          # Feature-specific services
├── domain/
│   ├── models/            # Entities / data classes
│   ├── repositories/      # Repository interfaces (abstract)
│   └── usecases/          # Single-responsibility use cases
└── presentation/
    ├── providers/          # State management (Provider package)
    ├── screens/            # Screen widgets
    └── widgets/            # Feature-specific UI components
```

**State management:** `provider` package (`ChangeNotifier`-based). Providers are registered at the top of the tree in `main.dart`.

**Data flow:** `Screen → Provider → UseCase → Repository → Datasource (Supabase/Hive)`

---

## Key Technology Stack

| Concern | Package / Service |
|---------|-------------------|
| Backend / DB | Supabase (`supabase_flutter ^2.3.4`) |
| Push notifications | Firebase Messaging (`firebase_messaging 16.1.3`) |
| Analytics | Firebase Analytics |
| End-to-end encryption | Signal Protocol (`libsignal_protocol_dart 0.8.0`) |
| Video/voice calling | LiveKit (`livekit_client 2.8.1`) |
| Local storage | Hive (`hive ^2.2.3`) |
| State management | Provider (`provider ^6.1.1`) |
| In-app purchases | `in_app_purchase` (IAP) |
| Notifications (local) | `flutter_local_notifications`, `flutter_callkit_incoming` |
| Media | `video_player`, `camera`, `image_picker`, `file_picker` |
| Auth (biometric) | `local_auth` |
| Audio | `just_audio`, `audio_session` |
| Music metadata | `spotify_sdk` (Spotify service) |
| GIFs | `giphy_get` |
| Animations | `flutter_animate`, `confetti`, `animated_text_kit` |
| Web interop | `dart:js_interop`, `dart:js_interop_unsafe` (for web platform) |

---

## God Nodes — Core Abstractions

These are the most-connected nodes in the knowledge graph. Touch them carefully — changes ripple everywhere.

| Node | Edges | What It Is |
|------|-------|------------|
| `ProfileProvider` | **120** | Central provider for current user profile; consumed by Feed, Calling, Canvas, Settings, Profile screens |
| `ConversationProvider` | 44 | Chat/conversation state; owns message list, typing state, encryption |
| `_widget` | 45 | Generic widget reference — widespread UI composition pattern |
| `CircleProvider` | 35 | State for group circles (communities) |
| `FeedProvider` | 35 | Social feed state; owns posts, pagination, ad injection |
| `RipplesProvider` | 30 | Short-video/ripple content state |
| `_timer` | 29 | Used in Wellness, Sessions, and messaging for debounce/polling |

**Rule:** Before modifying any of these, run `graphify query "<node name>"` to see all dependents.

---

## Surprising Coupling — Things to Know

These connections are non-obvious and were discovered by the knowledge graph:

1. **`calling_screen.dart` → `ProfileProvider`** — The calling screen directly reads the current user's profile via `_loadProfile` and `_buildIncomingControls`. This is a real dependency, not a bug — caller identity is shown on-screen. But be careful: if `ProfileProvider` is async-loading at call time, the calling screen may render incomplete caller info.

2. **`canvas_detail_screen.dart` → `ProfileProvider`** — `_getAuthorId` uses profile state to determine canvas ownership. The canvas feature is user-identity-aware.

3. **`create_canvas_screen.dart` → `ProfileProvider`** — Both `initState` and `build` reference `ProfileProvider`. Canvas creation gates on profile readiness.

4. **Wellness cohesion is split across two communities** — `WellnessService` (service layer, Community 16) and `WellnessRepository` (data layer, Community 8) are detected as separate clusters, which matches the architecture but means wellness changes often span multiple files across both communities.

---

## Feature Map (by Community)

| Community | Key Files |
|-----------|-----------|
| Auth & Session | `lib/features/auth/` — Signal key provisioning, account switching, Instagram migration |
| Messaging & Chat UI | `lib/features/messages/presentation/` — ChatAppBar, ChatInputArea, ChatMessageList |
| Messaging Service | `lib/features/messages/data/` — ChatMessagingService, ConversationService, PQ-Aura E2E |
| Wellness & Achievements | `lib/features/wellness/` — EnergyMeter, focus sessions, achievement unlocks |
| Wellness Service Layer | `lib/services/wellness_service.dart` — SharedPrefs-backed wellness persistence |
| Calling & Audio | `lib/features/calling/` — LiveKit integration, call entity, audio session |
| Canvas & Creative | `lib/features/canvas/` — InfiniteCanvas, ShapeRecognizer, TimelineScrubber |
| Circles | `lib/features/circles/` — Group creation, circle feed, membership |
| Feed / Posts | `lib/features/feed/` — Post creation, feed pagination, ad injection |
| Ripples | `lib/features/ripples/` — Short video content, ripple provider |
| Onboarding | `lib/features/onboarding/` — Permission gates, welcome pages, celebration screen |
| Vault | `lib/services/vault_service.dart` — Biometric auth, PIN, encrypted media |
| Route Paths | `lib/routes/route_paths.dart` — All named routes (60+ routes) |
| Adaptive Scaffold | `lib/widgets/adaptive/adaptive_scaffold.dart` — Responsive layout wrapper |
| App Entry & Theme | `lib/main.dart`, `lib/core/theme/` — Theme caching, auth subscription |
| Supabase Data Layer | `lib/features/*/data/datasources/` — All remote data operations |
| Web & JS Interop | Platform-conditional web code using `dart:js_interop` |
| Privacy & Settings | `lib/features/settings/` — Account, privacy, encryption setup, GDPR data download |

---

## State Management Conventions

- **Providers are `ChangeNotifier` classes.** Always call `notifyListeners()` after state mutations.
- **`AuthService`** is a singleton accessed via `Provider.of<AuthService>(context, listen: false)` in most providers.
- **Async initialization:** Providers typically expose an `_isLoading` bool and an `_error` string. Check these before assuming data is ready.
- **No Riverpod / Bloc** — the codebase uses the `provider` package exclusively. Do not introduce Riverpod.
- **Cross-provider dependencies:** Some providers depend on others (e.g., `ChatProvider` depends on `ConversationProvider`). Look at provider registration order in `main.dart`.

---

## Database / Supabase Conventions

- All Supabase table names are defined as string constants in `lib/features/messages/data/datasources/` (look for `const String *Table`). See Community 32 for the full table catalog.
- **RLS (Row Level Security)** is enforced. If a query returns empty unexpectedly, check RLS policies in `supabase/`.
- Edge functions live in `supabase/functions/`.
- **Real-time subscriptions** are used for chat (`conversationParticipantsChannel`) and live presence.
- **Hive** is used for offline-first caching of feed, profiles, and wellness data.

---

## End-to-End Encryption Notes

- Oasis implements **Signal Protocol** for DM encryption via `libsignal_protocol_dart`.
- Key provisioning happens in `EncryptionProvisioner` / `ProfileManager`.
- **PQ-Aura** (`lib/features/messages/data/pq_aura/`) is a post-quantum encryption layer on top of Signal — treat it as experimental; changes here require careful testing.
- The `VaultService` uses biometric auth + PIN for local encrypted media vault; it is completely separate from Signal key storage.

---

## Wellness System Notes

- Wellness has **two parallel implementations**: `WellnessService` (in `lib/services/`) and `WellnessRepository` (in `lib/features/wellness/`). They partially overlap. When adding wellness features, prefer `WellnessRepository` (clean architecture) over the legacy `WellnessService`.
- Screen time tracking, focus session timers, and break reminders all share `_timer` as a debounce mechanism — the high edge count on `_timer` in the graph reflects this.
- Achievements are awarded via `checkAndAwardAchievements()` — this must be called after any session state change.

---

## Import Cycles

**None detected.** The knowledge graph found zero import cycles — maintain this. If you add a new dependency, verify it doesn't introduce a cycle by checking the direction of imports in the feature layer.

---

## Weak Cohesion Warnings

The following communities have low cohesion scores (< 0.025), meaning they contain loosely related code that may benefit from splitting:

| Community | Score | Recommendation |
|-----------|-------|----------------|
| Auth & Session Management | 0.015 | Consider splitting auth flow from session/key management |
| User Profile & Social Graph | 0.019 | Profile display vs. follow-graph logic are separate concerns |
| Notification System | 0.022 | Push vs. local notifications could live in separate services |
| Study Sessions & Focus | 0.022 | Session tracking vs. UI state could be decoupled |

---

## Common Agent Tasks

### Adding a new feature
1. Create `lib/features/<name>/` with `data/`, `domain/`, `presentation/` sub-folders.
2. Add the feature's provider to `main.dart` `MultiProvider` list.
3. Register routes in `lib/routes/route_paths.dart` and the router.
4. Add Supabase table constants to the datasource file following existing naming conventions.

### Modifying ProfileProvider
- Check all 120+ dependents first: `graphify query "ProfileProvider"`
- Ensure the provider is not being accessed before auth is complete (guard with `_authSub` stream in `main.dart`).

### Adding a new screen
- Wrap in `AdaptiveScaffold` from `lib/widgets/adaptive/adaptive_scaffold.dart` for responsive desktop/mobile behavior.
- Register a named route in `RoutePaths`.
- Use `OasisColors` and `OasisTextStyles` from `lib/core/theme/` — never hardcode colors.

### Adding a Supabase query
- Add the table name constant to the relevant datasource file.
- Implement the method in the datasource, then add it to the repository interface, then implement in `*RepositoryImpl`, then optionally expose via a UseCase.
- Test with `supabase/` edge functions or direct table queries first.

### Working on encryption
- Do **not** change Signal session serialization formats without a migration path — existing sessions will break.
- PQ-Aura sessions are stored in Hive; treat the storage format as immutable unless you also migrate existing data.

---

## Known Issues & Technical Debt

- `AppAnalytics` / `logEvent` have **8,056 weakly-connected nodes** around them — analytics events are called from many places but the tracking logic is not well-integrated into the graph. Review for dead code.
- `_widget` (45 edges) is a generic symbol captured by the AST — not a real class. This inflates its edge count in the graph.
- The `cmake-3.29.3-windows-x86_64/` folder (6,188 files) is a bundled toolchain — it is excluded from the knowledge graph but present in the repo. Consider adding it to `.gitignore` or `.graphifyignore`.

---

## Graphify Knowledge Graph

The `graphify-out/` directory contains a queryable knowledge graph of this codebase.

```bash
# Query the graph
graphify query "how does calling work"
graphify query "what uses ProfileProvider"
graphify path "FeedProvider" "Supabase"
graphify explain "PQAuraBridge"

# Update after code changes
graphify update .
```

Interactive graph: open [`graphify-out/graph.html`](graphify-out/graph.html) in a browser.  
Full report: [`graphify-out/GRAPH_REPORT.md`](graphify-out/GRAPH_REPORT.md)

## Best Practices & UI Stability

### State Management & Realtime Sync
- **Chronological Sorting:** Always sort collections (like messages) chronologically in the provider/state notifier (`setState`). This prevents item-swapping or disappearing glitches caused by out-of-order Realtime events vs HTTP response updates under high-speed operations.
- **Realtime Join Limitations:** Supabase Realtime broadcasts raw table changes and does not include joined database tables. If you need metadata from joins (e.g. reply-to content), resolve it locally from in-memory state or local cache.

### Notification UX & In-app Sync
- **Active Conversation Suppression:** Track the currently open conversation/room ID inside the notification manager and suppress native/local notifications for it.
- **Notification Dismissal:** Ensure that reading or marking messages as read in-app invokes the notification manager to clear/cancel any pending notification groups on the device.

### Layout Stability & Input Fields
- **Avoid Animating Horizontal Dimensions inside Input Bars:** Do not use width transitions (like `SizeTransition` with `Axis.horizontal`) on icons/buttons in input areas that contain auto-wrapping multiline text fields. Width changes force the text field to constantly wrap and fluctuate in height, triggering jitter and bouncing in the reverse ListView above it. Prefer non-resizing transitions like `FadeTransition` or instant switches.

---

## Do Nots

- ❌ Do **not** use Riverpod or Bloc — this project uses `provider` exclusively.
- ❌ Do **not** hardcode colors — use `OasisColors` from `lib/core/theme/oasis_colors.dart`.
- ❌ Do **not** query Supabase directly from a screen widget — go through a provider → usecase → repository.
- ❌ Do **not** modify Signal Protocol session serialization without a migration strategy.
- ❌ Do **not** add new screens without registering them in `RoutePaths`.
- ❌ Do **not** bypass the `AdaptiveScaffold` for new top-level screens — it handles desktop/mobile layout.
- ❌ Do **not** introduce import cycles — none currently exist; keep it that way.
