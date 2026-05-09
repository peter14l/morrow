---
status: investigating
trigger: "Investigate and fix WebRTC calling issues."
created: 2025-01-24T15:00:00Z
updated: 2025-01-24T16:00:00Z
---

## Current Focus

hypothesis: Circular dependency or notifyListeners loop between CallProvider and CallService causing Stack Overflow. Audio failure due to AudioSession config or remote stream attachment.
test: Examine CallProvider and CallService for circularity and notifyListeners triggers. Check AudioSession setup.
expecting: Identify recursive calls or misconfigured audio.
next_action: Read CallProvider and CallService.

## Symptoms

expected: Calls can be answered reliably, ended cleanly, and have bi-directional audio.
actual: Stack Overflow and initialization errors occur after answering. No sound is heard even if the call connects. (Note: Answer button race condition and screen flicker reported fixed by user).
errors: Stack Overflow Error, 'not initialized' error (possibly related to PeerConnection or DI).
reproduction: Use two devices (release builds). A calls B. B attempts to answer or end the call.
started: Audio issues persistent for ~2 months. Answer/End regressions occurred after recent commits (likely ca1b6da or bb791de).

## Eliminated

- hypothesis: Answer button race condition.
  evidence: Reported fixed by user in checkpoint.
  timestamp: 2025-01-24T16:00:00Z
- hypothesis: Call end flicker.
  evidence: Reported fixed by user in checkpoint.
  timestamp: 2025-01-24T16:00:00Z

## Evidence

- timestamp: 2025-01-24T16:00:00Z
  checked: User feedback
  found: Answer button race and screen flicker are fixed. Stack Overflow and audio transmission issues persist.
  implication: Focus shifts to logic loop and audio routing.

## Resolution

root_cause: 
fix: 
verification: 
files_changed: []
