# P0 Critical Fixes - Implementation Documentation

**Date:** 2025-07-19  
**Last Updated:** 2025-07-20  
**Scope:** 7 P0 fixes (calling, capsules, monetization) + 11 codebase scan fixes across 20+ files

---

## Summary

**P0 Fixes (7):** Screen flickering, audio routing, capsule crash, mock purchases, broken buttons, calls disabled, data export migration.

**Codebase Scan Fixes (11):** Conversation repo dead methods, Zen Feed dead code, LiquidGlassMode wrong default, Supabase URL empty, update check URL empty, message expiry filter, voice comments, passkey auth errors, Google Sign-In dead code, call service stubs, app repair/reset.

**P1 Fixes (2):** Unread message counter (REPLICA IDENTITY + publication + hardcoded 0), Call notifications (missing trigger on calls table).

**Total:** 20 fixes across 22+ files, ~370+ lines changed.

---

## Fix 1: Gate Mock Customization Purchases

**File:** `lib/features/monetization/data/services/customization_service.dart`

**Changes:**
- Added import for `AppConfig`
- Modified `purchaseItem()` to return `false` early if `AppConfig.enableOasisAura` is false
- Modified `purchaseCircleBoosts()` with same guard
- Added debug logging when gated

**Rationale:** Prevents mock purchases from being processed in production builds unless the Oasis Aura feature flag is explicitly enabled. The mock implementation directly upserts to the database without payment verification.

**Code:**
```dart
Future<bool> purchaseItem(String itemId, String itemType) async {
  if (!AppConfig.enableOasisAura) {
    debugPrint('[CustomizationService] Oasis Aura is disabled');
    return false;
  }
  // ... existing logic
}
```

---

## Fix 2: Capsule Contribution Crash

**Files:** 
- `lib/features/capsules/data/datasources/capsule_remote_datasource.dart`
- `lib/features/capsules/data/repositories/capsule_repository_impl.dart`

**Changes:**
- Replaced `throw UnimplementedError(...)` with working Supabase update implementation
- The implementation updates `content`, `media_url`, and `media_type` columns on the `time_capsules` table
- Returns the updated `TimeCapsule` object after fetching with profile data

**Rationale:** The "Contribute to Capsule" feature was completely unimplemented and crashed the app with `UnimplementedError` when invoked. Now it performs a basic content update.

**Code (capsule_remote_datasource.dart):**
```dart
Future<TimeCapsule> contributeToCapsule({
  required String capsuleId,
  required String content,
  String? mediaUrl,
  String mediaType = 'none',
}) async {
  try {
    await _supabase
        .from(SupabaseConfig.timeCapsulesTable)
        .update({
          'content': content,
          if (mediaUrl != null) 'media_url': mediaUrl,
          'media_type': mediaType,
        })
        .eq('id', capsuleId);
    
    // Fetch and return updated capsule
    final response = await _supabase
        .from(SupabaseConfig.timeCapsulesTable)
        .select()
        .eq('id', capsuleId)
        .single();
    
    // ... merge with profile and return TimeCapsule
  } catch (e) {
    debugPrint('Error contributing to capsule: $e');
    rethrow;
  }
}
```

---

## Fix 3: Disable Broken Buttons

**Files:**
- `lib/features/circles/presentation/screens/circle_detail_screen.dart` (line 136)
- `lib/features/feed/presentation/widgets/post/post_header.dart` (line 60)

**Changes:**
- Circle Settings button: `onPressed: null` with `tooltip: 'Coming soon'`
- Post More-Options button: `onPressed: null` with `tooltip: 'Coming soon'`

**Rationale:** Both buttons had `TODO` comments but no implementation. Setting `onPressed: null` disables them visually (greys out the icon) while showing a tooltip explaining they're not yet implemented. This prevents user confusion and accidental crashes.

---

## Fix 4: Data Export Requests Table

**File:** `supabase/migrations/20260411000000_add_data_export_requests.sql` (verified)

**Status:** Migration already exists and is correct. No code changes needed.

**Table Schema:**
```sql
CREATE TABLE IF NOT EXISTS public.data_export_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    status TEXT NOT NULL DEFAULT 'pending',
    requested_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    processed_at TIMESTAMPTZ,
    download_url TEXT
);

ALTER TABLE public.data_export_requests ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can insert their own export requests"
ON public.data_export_requests FOR INSERT
WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can view their own export requests"
ON public.data_export_requests FOR SELECT
USING (auth.uid() = user_id);
```

**Note:** The migration must be applied to the database (`supabase db push` or via Supabase dashboard).

---

## Fix 5: Screen Flickering During Call Connection (Major)

**Root Cause:** 5+ LiveKit events firing `notifyListeners()` in rapid succession during call connection, each propagating through `CallProvider` → `CallNavigator` (at app root) → full widget tree rebuild.

**Files Modified:**

### 5a. `lib/services/call_service.dart`
- Added `_notifyDebounce` Timer field
- Added `_scheduleNotify()` method with 16ms debounce (one frame)
- Replaced 5 individual `notifyListeners()` calls in `_setupRoomListeners` with `_scheduleNotify()`
- Removed redundant `notifyListeners()` in `initLocalStream()` and `startSignaling()`
- Added `_isDisposed` field and guard in dispose
- Cancel debounce timer in `_cleanup()` and `dispose()`

### 5b. `lib/widgets/call_navigator.dart`
- Replaced `context.watch<CallProvider>()` with 5 targeted `context.select` calls:
  - `hasActiveCall`, `hasIncomingCall`, `isMinimized`, `activeCallId`, `incomingCallId`
- Only rebuilds when these specific boolean/string values change

### 5c. `lib/features/calling/presentation/screens/calling_screen.dart`
- Changed `ParticipantDisplay` to use `context.select<CallProvider, Room?>((p) => p.room)`

### 5d. `lib/features/calling/presentation/widgets/floating_call_overlay.dart`
- Already using `context.select` for `isMinimized`, `hasActiveCall`, `hasIncomingCall`

### 5e. `lib/features/calling/presentation/providers/call_provider.dart`
- Replaced `_isProcessingUpdate` boolean guard (which silently dropped 4 of 5 events) with frame-based debounce using `addPostFrameCallback`
- Now all events update internal state, but `notifyListeners()` fires at most once per frame

**Expected Result:** Call connection now triggers at most 1-2 widget rebuilds instead of 9-14, eliminating visible flickering.

---

## Fix 6: Audio Routing Implementation

**File:** `lib/services/call_service.dart`

**Changes:**
- Added `audio_session` package import
- Added `_configureCallAudioSession()` method that configures `AudioSession.instance` with `AudioSessionConfiguration.speech()`
- Called `_configureCallAudioSession()` in `startSignaling()` after room creation
- Completely rewrote `toggleSpeakerphone()` to use `AudioSession.instance.setDevicePreferences()`:
  - Speaker on: `AudioDeviceType.speaker`
  - Speaker off: `AudioDeviceType.builtInSpeaker` (earpiece on mobile)
- Added Android-specific audio attributes for voice communication

**Code:**
```dart
Future<void> _configureCallAudioSession() async {
  if (kIsWeb) return;
  final session = await AudioSession.instance;
  await session.configure(const AudioSessionConfiguration.speech());
}

Future<void> toggleSpeakerphone() async {
  _isSpeakerphoneOn = !_isSpeakerphoneOn;
  
  if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
    final session = await AudioSession.instance;
    await session.setDevicePreferences(
      _isSpeakerphoneOn
          ? const AudioDevicePreferences(type: AudioDeviceType.speaker)
          : const AudioDevicePreferences(type: AudioDeviceType.builtInSpeaker),
    );
    
    if (Platform.isAndroid) {
      await session.setAndroidAudioAttributes(
        const AndroidAudioAttributes(
          usage: AndroidAudioUsage.voiceCommunication,
          contentType: AndroidAudioContentType.speech,
        ),
      );
    }
  }
  
  _scheduleNotify();
}
```

**Rationale:** The previous implementation only toggled a boolean flag with no actual audio routing calls. The new implementation uses the platform audio session APIs to properly route audio to speaker or earpiece, and supports Bluetooth headsets via the `audio_session` package configuration.

---

## Fix 7: Re-enable Calls

**File:** `lib/core/config/app_config.dart` (line 14)

**Change:**
```dart
// Before:
static bool enableCalls = false;

// After:
static bool enableCalls = true;
```

**Rationale:** Calls were globally disabled with a comment about "major platform stability fixes." With the flickering and audio fixes complete, calls can be re-enabled for testing and release.

---

## Codebase Scan Fixes (2025-07-20)

The following 11 fixes were identified via full codebase scan and implemented:

### Fix 8: Conversation Repo Empty Methods

**Files:**
- `lib/features/messages/data/datasources/conversation_remote_datasource.dart`
- `lib/features/messages/data/repositories/conversation_repository_impl.dart`

**Changes:**
- Added `toggleMute()` and `toggleArchive()` methods to `ConversationRemoteDatasource` — updates `is_muted`/`is_archived` columns on `conversations` table and returns the new state
- Implemented `markAsRead()` in `ConversationRepositoryImpl` — gets current user ID from Supabase client, delegates to datasource's existing `markConversationAsRead()`
- Implemented `toggleMute()` in `ConversationRepositoryImpl` — fetches current mute state, delegates to datasource toggle
- Implemented `toggleArchive()` in `ConversationRepositoryImpl` — fetches current archive state, delegates to datasource toggle
- Added `SupabaseClient?` parameter to `ConversationRepositoryImpl` for user ID resolution

**Rationale:** Three repository methods were empty placeholders (`// This would need userId from somewhere - placeholder`). Mute, archive, and mark-as-read are core messaging features that silently did nothing.

---

### Fix 9: Remove Zen Feed Dead Code

**Files:**
- `lib/features/feed/presentation/screens/zen_feed_screen.dart` (deleted)
- `lib/screens/feed_screen.dart`

**Changes:**
- Deleted `zen_feed_screen.dart` — 498 lines, 100% commented out
- Removed broken import `package:oasis/screens/zen_feed_screen.dart` (file didn't exist at that path)
- Removed `ZenFeedScreen` usage from `_buildFeedContent()` — when `FeedLayoutType.zenCarousel` was selected, it tried to instantiate a commented-out class

**Rationale:** Dead code file with broken import path. Would cause compile error if the commented class were ever uncommented without fixing the import.

---

### Fix 10: LiquidGlassMode Default

**File:** `lib/features/settings/domain/models/user_settings_entity.dart`

**Change:**
```dart
// Before:
this.liquidGlassMode = LiquidGlassMode.fake, // Changed for testing

// After:
this.liquidGlassMode = LiquidGlassMode.real,
```

**Rationale:** Default was changed to `fake` for testing and never reverted. The `liquid_glass_wrapper.dart` already handles platform fallback (fake on desktop, real on mobile), so the default should be `real` to match production intent.

---

### Fix 11: Supabase URL Debug Fallback

**File:** `lib/core/config/supabase_config.dart`

**Change:** Added `localhost:54321` fallback for debug builds when `SUPABASE_URL` env var is empty.

**Rationale:** Without env var, the URL was empty string, causing silent failures in all Supabase function calls during local development.

---

### Fix 12: Update Check URL Release Fallback

**File:** `lib/core/config/app_config.dart`

**Change:** Added `https://oasis-web-red.vercel.app/api/check-update` as production fallback when `UPDATE_CHECK_URL` env var is empty.

**Rationale:** Empty URL in release builds meant update checking silently failed. Now falls back to the production web URL.

---

### Fix 13: Message Expiry Filter

**File:** `lib/features/messages/data/messaging_service.dart`

**Change:** `filterExpiredMessages()` now actually filters out messages where `expiresAt` is in the past, instead of returning all messages unconditionally.

**Rationale:** Placeholder returned all messages regardless of expiry. Ephemeral/disappearing messages would persist forever in the UI.

---

### Fix 14: Voice Comments Error Handling

**File:** `lib/features/feed/presentation/screens/comments_screen.dart`

**Changes:**
- Replaced vague "coming soon" snackbar with actionable message explaining schema update is needed
- Added temp file cleanup after failed upload
- Added `universal_io` import for `File` access

**Rationale:** Voice recording was captured but the upload was a no-op placeholder. Temp files accumulated on device. Now shows clear message and cleans up.

---

### Fix 15: Passkey Auth Error Messages

**File:** `lib/services/auth/auth_providers_delegate.dart`

**Changes:**
- Changed `throw UnimplementedError(...)` to `throw UnsupportedError(...)` with actionable message explaining what's needed (WebAuthn backend support + passkeys package)

**Rationale:** `UnimplementedError` suggests the developer forgot to implement it. `UnsupportedError` correctly communicates that the feature requires additional backend infrastructure.

---

### Fix 16: Google Sign-In Dead Delegate Method

**File:** `lib/services/auth/auth_providers_delegate.dart`

**Change:** Removed `signInWithGoogle()` method that threw `UnimplementedError`. The actual Google Sign-In is implemented directly in `AuthRemoteDatasource` using the `google_sign_in` package.

**Rationale:** Dead code that confused maintainers. The datasource bypasses the delegate entirely for Google auth.

---

### Fix 17: Call Service Stub Methods

**File:** `lib/services/call_service.dart`

**Change:** `createOffer()` and `createAnswer()` now throw `UnsupportedError` instead of silently returning empty maps.

**Rationale:** These legacy stubs returned `{}` which would cause confusing downstream failures if accidentally called. The actual call flow uses LiveKit signaling.

---

### Fix 18: App Repair/Reset Logic

**File:** `lib/main.dart`

**Changes:**
- Added `flutter_cache_manager` and `shared_preferences` imports
- Repair button now clears image cache (`CachedNetworkImage.evictFromCache`, `DefaultCacheManager().emptyCache`)
- Clears all SharedPreferences data
- Signs out of Supabase session
- Then calls `main()` to reinitialize

**Rationale:** Previous implementation only called `main()` without clearing any state. Corrupted preferences or cached data would persist through the "reset."

---

## P1 Fixes (2025-07-20)

### Fix 19: Unread Message Counter Not Updating

**Root Cause:** `conversation_participants` table was never added to the `supabase_realtime` publication and had no `REPLICA IDENTITY FULL`. This meant:
1. The realtime subscription in `ConversationService.subscribeToConversations()` never fired — unread count changes were invisible to the UI
2. DELETE events would have incomplete payloads (only primary key)
3. Additionally, `ConversationRepositoryImpl._conversationFromJson()` hardcoded `unreadCount: 0`

**Files:**
- `supabase/migrations/20260720000000_fix_unread_counter_realtime.sql` (new)
- `lib/features/messages/data/repositories/conversation_repository_impl.dart`

**Migration Changes:**
```sql
-- Enable REPLICA IDENTITY FULL so realtime payloads include all columns
ALTER TABLE public.conversation_participants REPLICA IDENTITY FULL;

-- Add to realtime publication so Postgres changes are broadcast
ALTER PUBLICATION supabase_realtime ADD TABLE public.conversation_participants;

-- Also ensure messages and conversations tables are in the publication
-- (needed by get_user_conversations_v2 dynamic unread calculation)
ALTER PUBLICATION supabase_realtime ADD TABLE public.messages;
ALTER PUBLICATION supabase_realtime ADD TABLE public.conversations;
```

**Code Changes:**
- `_conversationFromJson()` now reads `unread_count` from JSON instead of hardcoding 0
- Also reads `other_user_id`, `other_user_name`, `other_user_avatar` from JSON when available

**Rationale:** Without the publication entry, Supabase Realtime never broadcasts changes to `conversation_participants`, so the Flutter app's `onPostgresChanges` subscription silently never fires. The unread badge on the messages tab never updates until the user manually pulls-to-refresh.

---

### Fix 20: Call Notifications Never Sent for Backgrounded Users

**Root Cause:** The V2 calling migration (`20260422000000`) dropped the `call_participants` table, which had the `handle_call_notification()` trigger. No replacement trigger was added to the new `calls` table. When a call was inserted with status `ringing`, no notification record was created, so the `notify_push_service` trigger on `notifications` never fired, and the `push-notifications` edge function was never invoked.

**Files:**
- `supabase/migrations/20260720000001_fix_call_notifications.sql` (new)

**Migration Changes:**
```sql
-- Ensure REPLICA IDENTITY FULL on calls for complete realtime payloads
ALTER TABLE public.calls REPLICA IDENTITY FULL;

-- Create trigger function that inserts a notification for incoming calls
CREATE OR REPLACE FUNCTION public.handle_call_insert_notification()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.status = 'ringing' THEN
    INSERT INTO public.notifications (user_id, type, actor_id, content, read)
    VALUES (
      NEW.receiver_id, 'call', NEW.caller_id,
      jsonb_build_object('call_id', NEW.id, 'type', NEW.type, 'conversation_id', NEW.conversation_id)::text,
      false
    );
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Attach trigger to calls table
CREATE TRIGGER trigger_handle_call_insert_notification
  AFTER INSERT ON public.calls
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_call_insert_notification();
```

**Notification Pipeline (after fix):**
1. Caller initiates call → row inserted into `calls` with status `ringing`
2. New trigger fires → inserts record into `notifications` with type `call`
3. Existing `notify_push_service` trigger on `notifications` fires → calls `push-notifications` edge function
4. Edge function sends FCM data-only message with `call_id` and `call_type`
5. Background FCM handler (`firebaseMessagingBackgroundHandler`) receives message → shows `FlutterCallkitIncoming` native call UI
6. Foreground path (unchanged): Supabase Realtime on `calls` table → `CallService.startIncomingCallListener()` → in-app overlay

**Rationale:** The V2 migration destroyed the notification pathway for incoming calls. Foreground users still received calls via Supabase Realtime, but backgrounded/killed users got nothing. This was the primary blocking issue for the calling feature.

---

## Files Modified Summary (All Fixes)

| File | Fix # | Lines Changed |
|------|-------|---------------|
| `lib/features/monetization/data/services/customization_service.dart` | 1 | ~15 |
| `lib/features/capsules/data/datasources/capsule_remote_datasource.dart` | 2 | ~25 |
| `lib/features/capsules/data/repositories/capsule_repository_impl.dart` | 2 | ~10 |
| `lib/features/circles/presentation/screens/circle_detail_screen.dart` | 3 | ~5 |
| `lib/features/feed/presentation/widgets/post/post_header.dart` | 3 | ~5 |
| `lib/services/call_service.dart` | 5, 6, 17 | ~90 |
| `lib/widgets/call_navigator.dart` | 5 | ~30 |
| `lib/features/calling/presentation/screens/calling_screen.dart` | 5 | ~5 |
| `lib/features/calling/presentation/providers/call_provider.dart` | 5 | ~25 |
| `lib/core/config/app_config.dart` | 7, 12 | ~5 |
| `lib/features/messages/data/datasources/conversation_remote_datasource.dart` | 8 | ~25 |
| `lib/features/messages/data/repositories/conversation_repository_impl.dart` | 8 | ~25 |
| `lib/features/feed/presentation/screens/zen_feed_screen.dart` | 9 | deleted (498 lines) |
| `lib/screens/feed_screen.dart` | 9 | ~5 |
| `lib/features/settings/domain/models/user_settings_entity.dart` | 10 | 1 |
| `lib/core/config/supabase_config.dart` | 11 | ~3 |
| `lib/features/messages/data/messaging_service.dart` | 13 | ~8 |
| `lib/features/feed/presentation/screens/comments_screen.dart` | 14 | ~12 |
| `lib/services/auth/auth_providers_delegate.dart` | 15, 16 | ~20 |
| `lib/main.dart` | 18 | ~15 |
| `supabase/migrations/20260720000000_fix_unread_counter_realtime.sql` | 19 | new (30 lines) |
| `lib/features/messages/data/repositories/conversation_repository_impl.dart` | 19 | ~10 |
| `supabase/migrations/20260720000001_fix_call_notifications.sql` | 20 | new (40 lines) |

**Total: 22 files, ~370+ lines changed/deleted/added**

---

## Testing Checklist

Before release, verify:

1. **Calling Flow**
   - [ ] Outgoing voice call connects without screen flickering
   - [ ] Outgoing video call connects without screen flickering
   - [ ] Incoming call shows overlay, accepts without flickering
   - [ ] Speakerphone toggle routes audio to speaker
   - [ ] Speakerphone off routes audio to earpiece
   - [ ] Bluetooth headset routes audio correctly
   - [ ] Call end cleans up properly

2. **Capsules**
   - [ ] Create capsule works
   - [ ] Contribute to capsule updates content (no crash)
   - [ ] Open capsule at unlock date works

3. **Monetization**
   - [ ] Customization purchases fail gracefully when Oasis Aura disabled
   - [ ] Circle Boost purchases fail gracefully when Oasis Aura disabled

4. **UI Buttons**
   - [ ] Circle Settings button shows disabled state with tooltip
   - [ ] Post More-Options button shows disabled state with tooltip

5. **Data Export**
   - [ ] Apply migration `20260411000000_add_data_export_requests.sql`
   - [ ] Request data export works
   - [ ] View export requests works

6. **Messaging (Fix 8)**
   - [ ] Mark conversation as read updates read status
   - [ ] Mute toggle persists mute state
   - [ ] Archive toggle persists archive state

7. **Feed (Fix 9)**
   - [ ] Feed layout switcher works (Standard, Pulse Map)
   - [ ] No compile errors from removed Zen Feed import

8. **Settings (Fix 10)**
   - [ ] Liquid Glass defaults to real on mobile
   - [ ] Liquid Glass falls back to fake on desktop

9. **Auth (Fixes 15, 16)**
   - [ ] Passkey buttons show UnsupportedError message (if exposed in UI)
   - [ ] Google Sign-In works via datasource (not delegate)

10. **App Recovery (Fix 18)**
    - [ ] Repair & Reset clears image cache
    - [ ] Repair & Reset clears SharedPreferences
    - [ ] Repair & Reset signs out of Supabase
    - [ ] App re-initializes cleanly after reset

11. **Unread Counter (Fix 19)**
    - [ ] Apply migration `20260720000000_fix_unread_counter_realtime.sql`
    - [ ] Send a message from User A to User B (backgrounded)
    - [ ] User B's unread badge updates without pull-to-refresh
    - [ ] Open conversation → unread count resets to 0
    - [ ] Badge count matches actual unread messages

12. **Call Notifications (Fix 20)**
    - [ ] Apply migration `20260720000001_fix_call_notifications.sql`
    - [ ] User A calls User B (User B in background)
    - [ ] User B receives native incoming call UI (CallKit on iOS, CallKit on Android)
    - [ ] Accept/Decline from native UI works correctly
    - [ ] Foreground calls still work via in-app overlay

---

## Remaining Known Issues (Post-P0 / P1)

These issues were identified during the codebase scan and remain unresolved:

1. **Vault lock-on-chat-exit not working** — 2 debug issues in `.planning/debug/` (vault-lock-logic-issue, vault-lock-staying-unlocked)
2. **Circle post deletion infinite recursion** — Circular reference in deletion logic
3. **Messaging realtime sync failing silently** — Mitigated with polling fallback but not fully resolved
4. **Legacy auto-restore key migration edge cases** — Signal Protocol key migration can fail on some edge cases
5. **PQ-Aura Web encryption returns null** — Falls back to Signal/RSA; requires WASM build + server-side proxy (feature work)
6. **Voice comments require schema migration** — `comments` table needs `media_url` column + Comment model update
7. **Passkey authentication not connected** — Delegate methods throw `UnsupportedError`; requires WebAuthn backend setup
8. **Spotify fallback uses fake track ID** — Third fallback track has invalid Spotify ID (cosmetic only)
9. **Client-side Pro status check** — `vault_service.dart` reads Pro status from `userMetadata` instead of server verification (security concern)

---

## Rollback Plan

If critical regressions occur:

1. **Calls:** Set `AppConfig.enableCalls = false` in `app_config.dart`
2. **Audio Routing:** Revert `toggleSpeakerphone()` to boolean-only toggle
3. **Flickering:** Revert `CallService._scheduleNotify()` to direct `notifyListeners()`
4. **Capsules:** Revert `contributeToCapsule` to `throw UnimplementedError`
5. **Conversation Repo:** Revert `markAsRead`/`toggleMute`/`toggleArchive` to empty bodies
6. **Zen Feed:** Restore deleted file and re-add import in `feed_screen.dart`
7. **LiquidGlassMode:** Change default back to `LiquidGlassMode.fake`
8. **App Reset:** Revert repair button to simple `main()` call
9. **Passkey Auth:** Revert to `throw UnimplementedError`
10. **Unread Counter:** `DROP TABLE IF EXISTS` and re-add without publication, or `ALTER PUBLICATION supabase_realtime DROP TABLE conversation_participants`
11. **Call Notifications:** `DROP TRIGGER IF EXISTS trigger_handle_call_insert_notification ON calls`

All changes are localized and can be reverted individually.