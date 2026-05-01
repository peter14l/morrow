---
status: verifying
trigger: "Investigate and fix the issue where calling works (connects) but no audio is passed through."
created: 2024-05-17T12:00:00Z
updated: 2024-05-17T13:00:00Z
---

## Current Focus

hypothesis: Audio failure was caused by a combination of (1) WebRTC operations running on non-platform threads, triggering engine errors and state inconsistencies on Windows, (2) missing ICE candidate flushing for the receiver, and (3) over-specified audio constraints failing on some hardware.
test: Apply fixes to `CallService.dart` to ensure threading safety, proper candidate flushing, and simplified audio constraints.
expecting: Audio should now pass through on all platforms.
next_action: request human verification.

## Symptoms

expected: Audio should be transmitted and heard by both participants when a call is connected.
actual: Call connects, but there is total silence.
errors: [ERROR:flutter/shell/common/shell.cc(1183)] The 'FlutterWebRTC/peerConnectionEvent...' channel sent a message from native to Flutter on a non-platform thread.
reproduction: Testing between Android and Windows, and Android to Android.
started: Observed over the past 2 weeks after several changes.

## Eliminated

- hypothesis: Call buttons are missing.
  evidence: User stated they were commented out. Re-enabled them in `chat_screen.dart`.
  timestamp: 2024-05-17T12:00:00Z

## Evidence

- timestamp: 2024-05-17T12:00:00Z
  checked: Initial problem description
  found: Call connects, mic is on, but silence. Issue occurs on Android and Windows.
  implication: Likely a logic or threading issue in the WebRTC implementation.
- timestamp: 2024-05-17T12:30:00Z
  checked: `lib/services/call_service.dart`
  found: `Future.microtask` was used in callbacks. This doesn't escape the background thread if the callback was fired on one. Also, `_flushCandidateQueue` was never called for the receiver, meaning candidates arriving while ringing were lost.
  implication: Threading issues explain the Windows error; missing candidates explain connection instability/low quality; over-specified constraints might explain silence on some drivers.

## Resolution

root_cause: Combination of threading safety violations in WebRTC callbacks, missing ICE candidate flushing for the recipient, and restrictive audio constraints.
fix: (1) Replaced `Future.microtask` with `Future()` to ensure main event loop execution. (2) Added `_flushCandidateQueue` in `createAnswer` and `startSignaling`. (3) Simplified audio constraints to `true`. (4) Explicitly enabled and set volume for remote audio tracks. (5) Re-enabled call buttons in `chat_screen.dart`.
verification:
files_changed: [lib/services/call_service.dart, lib/features/messages/presentation/screens/chat_screen.dart]
