---
phase: 15-home-safe-checkin
plan: "02"
subsystem: home-location
tags: [geofence, settings-ui, app-lifecycle, tdd]
dependency_graph:
  requires: [home_location_model, home_location_service]
  provides: [geofence_monitor_service, home_location_screen, home_arrival_service]
  affects: [settings_screen, app_router, main.dart]
tech_stack:
  - Dart
  - Geolocator
  - SharedPreferences
  - TDD (flutter_test)
key_files:
  created:
    - lib/services/geofence_monitor_service.dart
    - lib/services/home_arrival_service.dart
    - lib/features/settings/presentation/screens/home_location_screen.dart
    - test/services/geofence_monitor_service_test.dart
  modified:
    - lib/routes/app_router.dart
    - lib/screens/settings_screen.dart
    - lib/services/app_initializer.dart
    - lib/main.dart
decisions:
  - Foreground-only monitoring (background in Plan 15-03)
  - 100m default geofence radius
  - LifecycleManager integration for app resume detection
  - State persisted in PrefsStorage for wasAtHome tracking
metrics:
  duration: ~10 minutes
  completed_date: 2026-05-04
---

# Phase 15 Plan 02: Geofence Detection + Settings UI Summary

## Objective
Implement geofence auto-detection when user reaches home location and create Settings UI for manual home location setting.

## One-Liner
Geofence detection with 100m radius, Settings UI for manual home location, and app lifecycle integration for home arrival detection.

## Tasks Executed

| Task | Name | Status | Commit |
|------|------|--------|--------|
| 1 | Create GeofenceMonitorService (TDD) | Complete | d47be21 |
| 2 | Create HomeLocationSettingsScreen | Complete | dbc3f33 |
| 3 | Wire Settings navigation | Complete | 2969d96 |
| 4 | Integrate Geofence with app lifecycle | Complete | 10ea2e0 |

## Implementation Details

### Task 1: GeofenceMonitorService (TDD)
- **Service**: `lib/services/geofence_monitor_service.dart`
- **Test**: `test/services/geofence_monitor_service_test.dart` (12 tests passing)
- Default radius: 100 meters
- Methods: isWithinGeofence(), startMonitoring(), stopMonitoring(), checkAndNotifyHomeArrival()
- Uses Haversine formula for distance calculation

### Task 2: HomeLocationSettingsScreen
- **Screen**: `lib/features/settings/presentation/screens/home_location_screen.dart`
- Set Location button with coordinate input dialog
- Clear Location button with confirmation
- Privacy notice prominently displayed
- "How It Works" info cards

### Task 3: Settings Navigation
- Added import in `lib/routes/app_router.dart`
- Added import in `lib/screens/settings_screen.dart`
- Route path: `/settings/home-location`

### Task 4: App Lifecycle Integration
- **Service**: `lib/services/home_arrival_service.dart`
- Integrates with LifecycleManager in `lib/main.dart`
- Checks home arrival on app resume
- Persists wasAtHome state in PrefsStorage

## Verification Results

| Criterion | Status |
|-----------|--------|
| GeofenceMonitorService 100m detection | Pass |
| isWithinGeofence() distance calculation | Pass |
| startMonitoring()/stopMonitoring() | Pass |
| onHomeArrived callback | Pass |
| HomeLocationSettingsScreen renders | Pass |
| Settings navigation imports added | Pass |
| App resume triggers geofence check | Pass |

## Deviation Documentation

None - plan executed as written.

## Threat Surface Scan

| Flag | File | Description |
|------|------|-------------|
| threat_flag: foreground_only | geofence_monitor_service.dart | Only monitors when app is active |
| threat_flag: local_storage_only | home_arrival_service.dart | wasAtHome state stored locally only |

## Known Stubs

None - all functionality implemented.

## Requirements Covered

- HOMESAFE-02: Geofence auto-detects home arrival
- HOMESAFE-03: Users can manually set home location via Settings
- HOMESAFE-04: App checks location on resume

## Next Steps (Plan 15-03)

- Partner notification when user arrives home
- Background location monitoring option
- Map picker UI for easier location selection