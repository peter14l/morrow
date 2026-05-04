# Oasis: The Complete Couples Intimacy & Connection Plan

## 🎯 Vision
Oasis is built to be a "Safe Haven." For couples, this means creating a digital environment that feels like a shared home. This plan shifts the focus from "Broadcasting" to "Co-existing," using sensory technology to bridge physical distance and relational rituals to deepen emotional bonds.

---

## 🏛️ Feature Catalog (20 Detailed Experience Specs)

### Cluster 1: Sensory Intimacy (Real-time & Haptic)
1.  **The Pulse (Heartbeat Sync)**
    *   **Experience:** A button in the DM header. Holding it transmits your "pulse" to your partner.
    *   **UI/UX:** Expanding concentric ripples in `oasisGlow` color. 
    *   **Haptics:** `HapticFeedback.lightImpact` in a 60bpm rhythmic loop.
    *   **Tech:** Uses Supabase Broadcast for <50ms latency.

2.  **Digital Cuddle (The Bloom)**
    *   **Experience:** When both are on the "Our Bubble" screen, dragging avatars together triggers a "Cuddle."
    *   **UI/UX:** A full-screen Gaussian blur overlay with a soft `oasisMist` color shift and "Bloom" shader.
    *   **Tech:** Real-time coordinates shared via Presence.

3.  **The Shared Breath**
    *   **Experience:** A collaborative 2-minute calming ritual.
    *   **UI/UX:** Two circles that must overlap. Users "breathe" with a central expanding flower.
    *   **Haptics:** Growing intensity on inhale, sudden stop on exhale.
    *   **Goal:** Physiological co-regulation.

4.  **Flicker (The 'Thinking of You' Light)**
    *   **Experience:** A small candle on the Home Screen widget.
    *   **UI/UX:** Tapping it makes the partner's candle flicker with a warm orange glow (`#FFCC00`).
    *   **Tech:** One-shot Broadcast trigger.

5.  **Our Secret Language**
    *   **Experience:** Custom haptic patterns for private meanings.
    *   **UI/UX:** A "Recording" interface where users tap patterns.
    *   **Logic:** Patterns saved to `couple_bubbles.secret_patterns` (JSONB).

### Cluster 2: Atmospheric Presence (Ambient & Environmental)
6.  **The Parallel Stream**
    *   **Experience:** A low-fidelity presence mode for working "together."
    *   **UI/UX:** A blurred, watercolor-style video silhouette (10% opacity, 50px blur).
    *   **Tech:** WebRTC stream with a custom Fragment Shader for the "painterly" effect.

7.  **Relationship Weather**
    *   **Experience:** The shared space's background reflects the relationship's "warmth."
    *   **Logic:** Calculated via `couple_interactions` frequency over 72 hours.
    *   **Themes:** Golden Hour (Active), Misty Morning (Quiet), Northern Lights (Special Moments).

8.  **Mood Glow**
    *   **Experience:** Visualizing the partner's emotional state without asking.
    *   **UI/UX:** A 20px outer glow around the avatar using `BoxShadow`.
    *   **Color:** Green (Safe), Blue (Quiet), Red (Needs Space), Yellow (Happy).

9.  **The Audio Blanket**
    *   **Experience:** A personalized sleep soundscape.
    *   **Logic:** Weaves 3-5 recorded "Whispers" into a loop of rain/white noise.
    *   **Audio:** Uses `audioplayers` with volume ducking for voice clips.

10. **Shared Soundscapes**
    *   **Experience:** Real-time synchronized ambient music.
    *   **UI/UX:** A shared "Now Playing" pill at the bottom of the screen.
    *   **Tech:** Synced via `couple_bubbles.active_track_timestamp`.

### Cluster 3: Virtual Tokens & Gifts
11. **Wrapped Whispers**
    *   **Experience:** Messages as "Surprise Boxes."
    *   **UI/UX:** A 3D-style box with a "Pull" tab. Recipient must swipe the tab to reveal text.
    *   **Haptics:** Tactile "Click" on unwrap.

12. **The Favor Ledger (Jar of Hearts)**
    *   **Experience:** Tracking small acts of kindness.
    *   **Logic:** `couple_ledger` table tracks items like "Washed the car" or "Made coffee."
    *   **Milestones:** Every 10 hearts triggers a "Celebration" event.

13. **Favor Coupons**
    *   **Experience:** Digital IOUs.
    *   **UI/UX:** Perforated ticket aesthetic. Red-claim button with "tearing" animation.
    *   **Types:** "One Home-Cooked Meal," "15min Massage," "Pick the Movie."

14. **Virtual Treasures**
    *   **Experience:** Digital collectibles for the shared space.
    *   **Items:** "Jar of Fireflies," "Pressed Sage Leaf," "Origami Crane."
    *   **Tech:** SVG/Lottie animations stored in `couple_items`.

### Cluster 4: Shared Stationery & Art
15. **Memory Layering**
    *   **Experience:** Turning a photo into a collaborative canvas.
    *   **UI/UX:** Multi-layer drawing/sticker surface over a shared photo.
    *   **Tech:** Saves JSON paths for drawing data to `couple_items.metadata`.

16. **Scratch-Off Cards**
    *   **Experience:** Hidden messages revealed via scratching.
    *   **UI/UX:** A gray "Foil" layer (Mask) that is removed via `CustomPainter` path tracking.
    *   **Haptics:** "Grainy" vibration during scratching.

17. **The Infinite Card**
    *   **Experience:** A shared vertical journal.
    *   **UI/UX:** A long, scrollable canvas without "Page" breaks.
    *   **Physics:** Smooth, momentum-based scrolling.

### Cluster 5: Long-term Rituals & Growth
18. **Digital Time Capsules**
    *   **Experience:** Content that waits for the right moment.
    *   **Triggers:** `trigger_date`, `trigger_location` (Geofencing), `trigger_mood`.
    *   **Encryption:** Released only when trigger keys are validated.

19. **Dream Maps (Pins of Hope)**
    *   **Experience:** Planning the future together.
    *   **Pins:** Blue (Bucket List), Red (Past Memory), Yellow (Date Idea).
    *   **Integration:** Uses `google_maps_flutter` with custom marker styles.

20. **The Living Garden**
    *   **Experience:** A visual metaphor for relationship care.
    *   **Growth:** Procedural L-System or SVG morphing.
    *   **Logic:** Grows 1 "leaf" per 10 messages; "wilts" (colors fade) after 7 days of zero interaction.

---

## 🛠️ Technical Strategy

### 1. Data Schema (Supabase Migrations)
- `couple_bubbles`: `(id, user_1, user_2, weather_mode, garden_level, created_at)`
- `couple_items`: `(id, bubble_id, type, payload, is_unwrapped, trigger_meta, metadata)`
- `couple_interactions`: `(id, bubble_id, type, timestamp)` (Limited to 30 days retention).

### 2. Encryption (PQ-Aura)
- **Shared Secret:** A 256-bit key derived via PQA-X3DH between the two partners.
- **Payloads:** All `couple_items.payload` entries are AES-256-GCM encrypted.

### 3. Real-time Signaling
- **Broadcast:** 1:1 relay for Pulses.
- **Presence:** `together_in_bubble` boolean and `mood_sync` state.

---

## 🚀 Roadmap

1.  **Phase 1 (The Core):** Bubble Setup, Wrapped Whispers, Favor Coupons.
2.  **Phase 2 (The Senses):** Pulse, Flicker, Shared Breath, Mood Glow.
3.  **Phase 3 (The History):** Time Capsules, Dream Maps, Memory Layering.
4.  **Phase 4 (The Environment):** Weather, Parallel Stream, The Living Garden.
