# Project State

## Objective
Finalize and verify the Oasis calling system.

## Current Progress
Fixed major audio transmission issue in calls. Root causes included WebRTC threading violations, missing ICE candidate flushing, and restrictive constraints. UI call buttons have been re-enabled.

## Next Steps
1. Test calling between Android and Windows to verify audio bi-directionality.
2. Monitor for any 'non-platform thread' errors in the logs.
3. Review other features that might have similar threading issues.

Last Updated: 5/1/2026, 10:28:35 PM