---
phase: 15-home-safe-checkin
plan: "01"
subsystem: home-location
tags: [privacy, local-storage, tdd]
dependency_graph:
  requires: []
  provides: [home_location_model, home_location_service]
  affects: [settings_screen]
tech_stack:
  - Dart
  - SharedPreferences
  - TDD (flutter_test)
key_files:
  created:
    - lib/models/home_location.dart
    - lib/services/home_location_service.dart
    - test/models/home_location_test.dart
    - test/services/home_location_service_test.dart
  modified:
    - lib/screens/settings_screen.dart
decisions:
  - Local-only storage using SharedPreferences (never sent to server)
  - Haversine formula for distance calculation
  - Forward reference route in Settings for future screen
metrics:
  duration: ~5 minutes
  completed_date: 2026-05-04
---

# Phase 15 Plan 01: Home Location Local Storage Summary

## Objective
Create local storage infrastructure for home location and models using TDD. Home location is stored locally via SharedPreferences only - never sent to server.

## One-Liner
Home location stored locally via SharedPreferences with model, service, and Settings UI entry point.

## Tasks Executed

| Task | Name | Status | Commit |
|------|------|--------|--------|
| 1 | Create HomeLocation model (TDD) | Complete | 2490ca0 |
| 2 | Create HomeLocationService (TDD) | Complete | af88dc9 |
| 3 | Add Settings UI entry point | Complete | 7cddbaa |

## Implementation Details

### Task 1: HomeLocation Model
- **Model**: `lib/models/home_location.dart`
- Properties: latitude, longitude, timestamp, address
- JSON serialization via `toJson()`/`fromJson()`
- Haversine distance calculation via `distanceTo()` method
- Validation for lat/lon ranges (-90/90, -180/180)
- Tests: 11 passing

### Task 2: HomeLocationService
- **Service**: `lib/services/home_location_service.dart`
- Uses PrefsStorage for local persistence
- Key: `home_location` in SharedPreferences
- Methods: getHomeLocation(), setHomeLocation(), clearHomeLocation(), hasHomeLocation(), distanceToHome()
- Tests: 9 passing

### Task 3: Settings UI Entry
- **Modified**: `lib/screens/settings_screen.dart`
- Added "Home Location" tile in Privacy & Security section
- Navigation: `/settings/home-location` route
- Placeholder for Plan 15-02 screen implementation

## Verification Results

| Criterion | Status |
|------------|--------|
| HomeLocation model has toJson/fromJson | Pass |
| Distance calculation (559km SF→LA ±10km) | Pass |
| HomeLocationService stores/retrieves | Pass |
| getHomeLocation() returns null when nothing stored | Pass |
| clearHomeLocation() properly removes data | Pass |
| Settings UI has Home Location tile | Pass |

## Deviation Documentation
None - plan executed exactly as written.

## Threat Surface Scan
| Flag | File | Description |
|------|------|-------------|
| threat_flag: local_storage_only | home_location_service.dart | Uses SharedPreferences only; never sends to server |

## Known Stubs
None.

## Commits
- 2490ca0: feat(15-home-safe-checkin): add HomeLocation model with TDD
- af88dc9: feat(15-home-safe-checkin): add HomeLocationService with TDD
- 7cddbaa: feat(15-home-safe-checkin): add Home Location tile in Privacy Settings

## Requirements Covered
- HOMESAFE-01: Home location stored locally only
- HOMESAFE-06: Users can set home in Settings