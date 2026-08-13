# Changelog

All notable changes to the Oasis project will be documented in this file. This project follows [Semantic Versioning](https://semver.org/).

## [1.1.16] - 2026-08-13

### Interface & Design
- **Floating Bottom Navigation Bar** - Redesigned bottom navigation bar to be a floating capsule with glassmorphism/blur effects, margin/padding, and border decoration when transparency effects are on.
- **Stable Chat Input Bar Layout** - Combined the attachment, sticker/GIF, and spoiler toggle buttons into a single fixed-size container to completely prevent layout wrapping jitters and height jumps while typing.

### Push Notifications
- **FCM Permission Request** - Added explicit request for OS-level runtime notifications permission on Android 13+ to ensure FCM messages are received and displayed successfully.

## [1.1.13] - 2026-07-28

### Security & Privacy
- **Stealth Decoy App Mode** - Added a stealth setting to completely disguise the app as a simple "Calendar" app on the home screen (supporting dynamic icon and name rebranding on Android, and dynamic alternate icon on iOS).
- **Multi-Finger Gesture Unlock** - Implemented a secret raw pointer listener requiring a **triple-finger swipe down** to reveal the security PIN sheet on the decoy screen.
- **PIN-Protected Unlock** - Locked decoy calendar screen behind a secure 6-digit PIN bottom sheet verification.
- **Background & Screen-Lock Auto-Locking** - Integrated app lifecycle listeners that instantly lock the app back to its decoy state when minimized or when the device screen locks.
- **Stealth Settings Panel** - Added interface inside Privacy settings to toggle Stealth Mode, setup a 6-digit PIN with double-entry check, and change the PIN.

### Web & Platform Compatibility
- **Web Compilation Refactoring** - Fixed web compilation errors by resolving window effect invocations and titles that rely on non-web package signatures.
- **Database & Migration Updates** - Optimized schema definitions and cleaned up database migration logs.
- **Cleanup** - Evicted massive debug trace files, dump logs, and obsolete plans to optimize repository size.

## [1.1.11] - 2026-05-15

### UI/UX & Theming
- **Liquid Glass Effect** - Full implementation of the experimental glassmorphism engine across all platforms.
- **Micro-animations** - Enhanced interactive feedback and fluid transitions in feed and messaging.
- **Collaborator Support** - Added infrastructure for shared posts and collaboration requests.

### Fixes & Stability
- **WebRTC Calling** - Resolved audio routing issues and improved ICE candidate buffering for more stable connections.
- **E2EE Decryption** - Fixed fallback logic for secure message decryption and notification previews.
- **Cursor Pagination** - Implemented robust cursor-based pagination for feeds and conversations to improve performance.
- **Security Hardening** - Further refinement of RLS policies to prevent recursion and ensure data isolation.

## [1.1.10] - 2026-05-10

### Fixes & Performance
- Initial support for Liquid Glass effects.
- Bug fixes in auth and messaging providers.

## [1.1.9] - 2026-05-09

### Post-Quantum Security (PQ-DR)
- **Hybrid PQ-Aura E2EE** - Integrated Rust-based Post-Quantum encryption layer via `PQ-DR` submodule to protect conversations against future quantum decryption.
- **PQ Session Indicators** - Added visual "Shield" indicators in chat headers to provide real-time verification of post-quantum secure handshakes.
- **Hardened Backend Security** - Comprehensive audit and hardening of Row Level Security (RLS) policies and column-level permissions across all core tables.
- **Multi-Account E2EE Notifications** - Implemented data-only FCM handling that allows for secure, on-the-fly decryption of notification previews even when switching between multiple active accounts.

### UI/UX & Theming (Liquid Glass)
- **Liquid Glass Rendering** - Introduced an experimental glassmorphism engine (Oasis Liquid) for headers, navigation bars, and bottom sheets with settings-toggle support.
- **Liquid FAB Cluster** - Replaced standard FAB with a morphing animation cluster for organic, fluid interaction.
- **Experimental Feed Layouts** - Added four new layout engines for the main feed:
  - **Spatial Glider**: A 2.5D staggered masonry grid with depth-based shadows.
  - **Focused Flow**: Magazine-style vertical snapping with ambient blurred backgrounds.
  - **Living Canvas**: Borderless organic layout with glowing "connecting fibers."
  - **Classic**: The refined, high-performance original layout.
- **Desktop Refinements** - Integrated Mica and Acrylic window effects for Windows/macOS and migrated to native Fluent UI components for desktop-class interactions.

### Feature Enhancements
- **Circles V2** - Major overhaul of the community system:
  - Transitioned from raw User IDs to full profile resolution (Names/Avatars) in member lists.
  - Private Circle feeds ensure only members can view and interact with shared posts.
  - Dedicated circle-specific creation flows and moderation tools.
- **In-App Updater** - Completely rebuilt update infrastructure:
  - Automated APK downloads via public R2 buckets.
  - Integrated `REQUEST_INSTALL_PACKAGES` and `FileProvider` for secure, one-tap installation on Android.
  - Native system-level installation prompts.
- **WebRTC Calling V2** - Significant stability improvements to the calling engine:
  - Hardware-optimized rendering sessions and ICE candidate buffering.
  - Advanced audio routing to resolve focus contention across platforms.
  - Call diagnostics and real-time connectivity status reporting.

### Fixes & Performance
- **Optimized Media Loading** - Integrated `CachedNetworkImage` and optimistic UI states for instant media previews in chat.
- **Parallel Decryption** - Enhanced chat responsiveness by parallelizing E2EE decryption workloads across isolates.
- **Storage Consolidation** - Unified secure storage providers to ensure data persistence and prevent state leakage during account switching.
- **Navigation Resilience** - Resolved GoRouter assertion errors by refactoring full-screen route handling outside of the ShellRoute context.

---

## [1.1.1] - 2026-05-01

### Added
- **Major Overhaul of Circles** - Transitioned to a restricted, feed-centric group conversation system.
- **Private Circle Feeds** - Only circle members can view and interact with circle posts.
- **Dedicated Post FAB** - Create posts directly within specific circles.

### Fixed
- **Row Level Security (RLS)** - Improved security constraints for circle-specific content.
- **Separated Feed Content** - Isolated circle content from the main application feed.

---

## [1.0.0+1] - 2026-04-30

### Added
- **Initial Release** - Welcome to Oasis!
- **End-to-End Encrypted Messaging (Whisper Mode)**.
- **Digital Wellbeing Engine**.
- **Multi-platform Support (Android, iOS, Windows, macOS, Web)**.
