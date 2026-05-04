# Phase 14: Couples Connection - Context

**Gathered:** 2026-05-04
**Status:** Ready for planning
**Source:** Feature specification document (COUPLES_CONNECTION_PLAN.md)

<domain>
## Phase Boundary

This phase implements the "Couples Intimacy & Connection" system for Oasis, creating a "safe haven" digital environment for couples that bridges physical distance through sensory technology and relational rituals.

### Phase Structure (4 Sub-phases)

**Phase 14.1 (The Core):** Bubble Setup, Wrapped Whispers, Favor Coupons
**Phase 14.2 (The Senses):** Pulse (Heartbeat Sync), Flicker, Shared Breath, Mood Glow
**Phase 14.3 (The History):** Time Capsules, Dream Maps, Memory Layering
**Phase 14.4 (The Environment):** Weather, Parallel Stream, Living Garden

</domain>

<decisions>
## Implementation Decisions

All features from COUPLES_CONNECTION_PLAN.md are locked decisions to implement.

### Cluster 1: Sensory Intimacy (Real-time & Haptic)
- **The Pulse (Heartbeat Sync):** DM header button, expanding concentric ripples in `oasisGlow` color, HapticFeedback.lightImpact at 60bpm, Supabase Broadcast for <50ms latency
- **Digital Cuddle (The Bloom):** Avatars dragging together triggers full-screen Gaussian blur overlay with `oasisMist` color shift and Bloom shader
- **The Shared Breath:** 2-minute collaborative ritual with two overlapping circles, central expanding flower, growing intensity on inhale
- **Flicker (Thinking of You):** Home Screen widget candle, tapping makes partner's candle flicker with warm orange glow (#FFCC00)
- **Our Secret Language:** Custom haptic patterns, recording interface, patterns saved to JSONB

### Cluster 2: Atmospheric Presence (Ambient & Environmental)
- **The Parallel Stream:** Low-fidelity presence mode, watercolor-style video silhouette (10% opacity, 50px blur), WebRTC with custom Fragment Shader
- **Relationship Weather:** Background reflects relationship warmth, calculated via `couple_interactions` frequency over 72 hours
- **Mood Glow:** 20px outer glow around avatar, Green=Safe, Blue=Quiet, Red=Needs Space, Yellow=Happy
- **The Audio Blanket:** Sleep soundscape weaving 3-5 recorded whispers into rain/white noise loop
- **Shared Soundscapes:** Real-time synchronized ambient music via shared timestamp

### Cluster 3: Virtual Tokens & Gifts
- **Wrapped Whispers:** Messages as "Surprise Boxes", 3D-style box with Pull tab, swipe to reveal, tactile click on unwrap
- **The Favor Ledger (Jar of Hearts):** Track acts of kindness, every 10 hearts triggers celebration
- **Favor Coupons:** Digital IOUs with perforated ticket aesthetic, red-claim button with tearing animation
- **Virtual Treasures:** Digital collectibles (Jar of Fireflies, Pressed Sage Leaf, Origami Crane), SVG/Lottie animations

### Cluster 4: Shared Stationery & Art
- **Memory Layering:** Photo into collaborative canvas, multi-layer drawing/sticker surface, JSON paths saved to metadata
- **Scratch-Off Cards:** Gray foil layer removed via CustomPainter path tracking, grainy vibration during scratching
- **The Infinite Card:** Shared vertical journal, long scrollable canvas without page breaks

### Cluster 5: Long-term Rituals & Growth
- **Digital Time Capsules:** Content waiting for right moment, triggers: date, location (geofencing), mood
- **Dream Maps (Pins of Hope):** Planning future together, Blue=bucket list, Red=past memory, Yellow=date idea
- **The Living Garden:** Visual metaphor for relationship care, grows 1 leaf per 10 messages, wilts after 7 days of zero interaction

### Technical Strategy
- **Data Schema:** couple_bubbles, couple_items, couple_interactions tables with 30-day retention
- **Encryption:** 256-bit key derived via PQA-X3DH, AES-256-GCM for all payloads
- **Real-time:** Supabase Broadcast for 1:1 relay, Presence for together_in_bubble

### the agent's Discretion
- Specific animation easing curves (user didn't specify - use standard Flutter curves)
- Exact color values for oasisGlow/oasisMist (use brand-compatible palette from ui-brand.md)
- Haptic pattern intensity levels (use standard HapticFeedback values)
- Error states and offline handling for real-time features

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

- `docs/plans/COUPLES_CONNECTION_PLAN.md` — Feature specification (source of truth)
- `README.md` — Project overview, tech stack (Flutter + Supabase + WebRTC)
- `.opencode/get-shit-done/references/ui-brand.md` — Brand colors and design tokens
- `SECURITY.md` — Existing security architecture for E2EE considerations

</canonical_refs>

<specifics>
## Specific Ideas

- Use `oasisGlow` and `oasisMist` color tokens from brand guidelines
- Supabase Broadcast channel for <50ms latency Pulsing
- Presence system for "together_in_bubble" state
- couple_items.metadata JSONB for flexible per-item storage
- 30-day retention policy on couple_interactions for privacy

</specifics>

<deferred>
## Deferred Ideas

- None — Phase 14 fully specifies all 4 sub-phases

</deferred>

---

*Phase: 14-couples-connection*
*Context gathered: 2026-05-04 via feature specification*