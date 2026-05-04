---
phase: 15-home-safe-checkin
plan: "03"
subsystem: home-checkin
tags: [notifications, verification, haptics, fcm]
dependency_graph:
  requires: [geofence_monitor_service, home_location_service, notification_manager]
  provides: [home_checkin_service, verification_dialog, home_checkin_repository]
  affects: [main.dart, lifecycle_manager]
tech_stack:
  - Dart
  - FCM (Firebase Cloud Messaging)
  - SharedPreferences
key_files:
  created:
    - lib/services/home_checkin_service.dart
    - lib/widgets/verification_dialog.dart
    - lib/features/couples/data/home_checkin_repository.dart
  modified:
    - lib/core/utils/haptic_utils.dart
    - lib/main.dart
decisions:
  - Heartbeat haptic plays on "Yes" confirmation
  - Warning haptic plays on "No" denial
  - Only "at home" state sent, never location data
  - Dialog shows once per arrival event (tracked via pending_verification)
metrics:
  duration: ~8 minutes
  completed_date: 2026-05-04
---

# Phase 15 Plan 03: Home Check-In Notifications + Verification Summary

## Objective
Implement home check-in notifications with partner alerts, verification overlay, and custom haptic patterns.

## One-Liner
Home check-in service with partner notifications, verification dialog on app open, and heartbeat haptic pattern.

## Tasks Executed

| Task | Name | Status | Commit |
|------|------|--------|--------|
| 1 | Create HomeCheckinService | Complete | 48105ad |
| 2 | Add heartbeat haptic pattern | Complete | 79a40a1 |
| 3 | Create VerificationDialog widget | Complete | 5563ae7 |
| 4 | Wire verification to app lifecycle | Complete | 5563ae7 |
| 5 | Create couple notification destination | Complete | 4caed84 |
| 6 (checkpoint) | End-to-end verification | Pending | - |

## Implementation Details

### Task 1: HomeCheckinService
- **Service**: `lib/services/home_checkin_service.dart`
- Methods: checkIn(), verifyCheckIn(wasAccurate:), markHomeArrival(), hasPendingVerification()
- Stores check-in state in PrefsStorage
- On checkIn(): calls HomeCheckinRepository to notify partner + plays heartbeat haptic
- On verifyCheckIn(wasAccurate: false): sends warning + plays warning haptic

### Task 2: Heartbeat Haptic Pattern
- **File**: `lib/core/utils/haptic_utils.dart`
- `heartbeatPulse()`: 3 light impacts with 100ms delays (60 BPM feel)
- `homeArrivedVibration()`: escalating light→medium→heavy→medium→light
- `warningPulse()`: 2 heavy impacts with 150ms delay

### Task 3: VerificationDialog
- **Widget**: `lib/widgets/verification_dialog.dart`
- Modal overlay asking "Did you actually reach home?"
- "Yes, I'm home" button (primary, pink) → calls onConfirm callback + heartbeat haptic
- "No, not yet" button (secondary) → calls onDeny callback + warning haptic
- Dark/light mode adaptive colors

### Task 4: App Lifecycle Wiring
- **Modified**: `lib/main.dart`
- Added `_handleHomeArrivalWithVerification()` in LifecycleManager
- Checks for pending verification before showing dialog (prevents duplicates)
- Shows dialog 500ms after app resume if home arrival detected
- On confirm: shows green "❤️ Partner notified" snackbar
- On deny: shows orange "⚠️ Partner warned" snackbar

### Task 5: HomeCheckinRepository
- **Repository**: `lib/features/couples/data/home_checkin_repository.dart`
- `getCouplePartnerId()`: queries couple_bubbles table for active partner
- `getPartnerFcmToken()`: gets partner's fcm_token from profiles
- `sendHomeArrivedNotification()`: pushes "❤️ [User] reached home"
- `sendNotReachedHomeNotification()`: pushes "⚠️ [User] NOT reached home"
- Falls back to local notification if FCM unavailable
- **Privacy**: Only "at home" boolean sent, never location coordinates

## Threat Surface Scan

| Flag | File | Description |
|------|------|-------------|
| threat_flag:fcm_outbound | home_checkin_repository.dart | Notification data sent to FCM for partner delivery |
| threat_flag:state_only | all services | Only state ("at home"), never location data sent |

## Deviation Documentation

None - plan executed as written.

## Known Stubs

- couple_bubbles table assumed to exist (Phase 14 couple feature)
- FCM edge function (`send-home-checkin`) optional - falls back to REST
- If no partner exists, check-in works locally but no notification sent

## Requirements Covered

- HOMESAFE-03: Partner notified when user reaches home
- HOMESAFE-04: User can verify check-in accuracy (“No” button warns partner)
- HOMESAFE-05: Custom haptic pattern plays on confirmation

## Next Steps (Future Phases)

- Background location monitoring (Plan 15-0x)
- Map picker UI for easier home location selection
- Push notification when partner checks in (symmetric flow)