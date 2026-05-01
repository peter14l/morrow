# Oasis — Flutter Onboarding Implementation Spec
> Cross-platform Flutter app. Target: iOS, Android, Web.
> Design language: "Ambient Intentionality" — glassmorphism, organic luxury, layered depth.

---

## 0. Setup & Dependencies

Add to `pubspec.yaml`:

```yaml
dependencies:
  flutter:
    sdk: flutter
  google_fonts: ^6.2.1
  smooth_page_indicator: ^1.1.0
  flutter_animate: ^4.5.0
  lottie: ^3.1.0
  glassmorphism: ^3.0.0
  animated_text_kit: ^4.2.3
  sensors_plus: ^4.0.0

dev_dependencies:
  flutter_launcher_icons: ^0.13.1
```

Import `Cormorant Garamond` via Google Fonts or embed the TTF in `assets/fonts/`.

---

## 1. Global Design Tokens

```dart
// lib/core/theme/oasis_colors.dart
class OasisColors {
  static const deep  = Color(0xFF0D1F1A); // scaffold background
  static const moss  = Color(0xFF1E3A2F); // card surfaces
  static const glow  = Color(0xFF7FFFD4); // CTAs, accents, "life"
  static const sage  = Color(0xFF3D6B55); // borders, dividers
  static const sand  = Color(0xFFE8D9C0); // display headings
  static const mist  = Color(0xFFA8C5B5); // secondary text
  static const deepTransparent = Color(0x800D1F1A); // glass overlays
}
```

```dart
// lib/core/theme/oasis_text_styles.dart

TextStyle onboardingHeadline = GoogleFonts.cormorantGaramond(
  fontSize: 38,
  fontStyle: FontStyle.italic,
  fontWeight: FontWeight.w600,
  color: OasisColors.sand,
  height: 1.15,
);

TextStyle onboardingSubtitle = GoogleFonts.inter(
  fontSize: 16,
  fontWeight: FontWeight.w400,
  color: OasisColors.mist,
  height: 1.6,
);

TextStyle ctaLabel = GoogleFonts.inter(
  fontSize: 15,
  fontWeight: FontWeight.w600,
  color: OasisColors.deep,
  letterSpacing: 0.3,
);
```

---

## 2. Shared Background System

Every page uses the same living background. Build it once as `OasisBackground` and wrap all pages in it.

**Implementation:**

```
OasisBackground widget:
  - Stack with scaffold color OasisColors.deep as base
  - 3 large radial gradient blobs (CustomPainter), positioned off-screen edges:
      Blob 1 → top-left,      color: glow.withOpacity(0.07), radius ~320
      Blob 2 → bottom-right,  color: sage.withOpacity(0.12), radius ~280
      Blob 3 → center-right,  color: moss.withOpacity(0.4),  radius ~200
  - Blobs animate continuously with a slow sine-wave drift using AnimationController
    (duration: 8s, repeat, reverse: true) — offset ±18px on both axes
  - On mobile: connect to sensors_plus gyroscope stream → shift blob positions
    ±12px based on tilt (parallax effect). Clamp values. Wrap in try/catch.
  - Fine particle layer (optional): 24 tiny dots (2px diameter, glow color,
    opacity 0.15–0.35) scattered at random positions, each with its own
    AnimationController for a slow float (translateY ±30px, duration 4–9s, staggered)
```

---

## 3. Shared Navigation Shell

```
OnboardingShell widget:
  - PageController with viewportFraction: 1.0
  - 5 pages in a PageView
  - Bottom overlay (positioned above safe area):
      Left:   Skip button (TextButton, Inter, mist color) — hidden on page 5
      Center: SmoothPageIndicator
                effect: WormEffect(
                  activeDotColor: OasisColors.glow,
                  dotColor: OasisColors.sage,
                  dotHeight: 6, dotWidth: 6, spacing: 8,
                )
      Right:  "Next" IconButton (arrow_forward_ios, glow color) — hidden on page 5
  - On page 5: bottom overlay is replaced by the full CTA buttons
  - Page transitions: use PageView default scroll but add flutter_animate
    on each page's content with .fadeIn + .slideY(begin: 0.04) triggered
    on page become active (listen to PageController)
  - State: currentPage tracked with setState or Riverpod
```

---

## 4. Page Specifications

---

### Page 1 — "The Sanctuary" (Welcome / Hero)

**Concept:** User arrives into silence. The logo breathes. The world is still.

**Layout (top to bottom, centered):**

```
[Top 15% space]

[Logo mark]
  - Custom SVG or Canvas-drawn: a stylized water droplet / oasis ring
  - Size: 88×88
  - Animate on entry:
      scale 0.6 → 1.0, duration 900ms, curve: Curves.elasticOut
      opacity 0 → 1, duration 600ms
  - Idle loop: subtle pulse scale 1.0 → 1.04 → 1.0, duration 3s, repeat

[16px gap]

[Wordmark: "oasis"]
  - Font: Cormorant Garamond, italic, 52px, sand color
  - Animate: AnimatedTextKit typewriter effect, 80ms/char
    OR flutter_animate .fadeIn(delay: 500ms).slideY(begin: 0.1)

[8px gap]

[Tagline]
  - Text: "Your digital sanctuary."
  - Font: Inter, 15px, mist color, letter-spacing 1.8, UPPERCASE
  - Animate: fadeIn delay 1200ms

[48px gap]

[Glass card — "Manifesto Pill"]
  - Width: screenWidth * 0.82
  - Glassmorphism container:
      background:   moss.withOpacity(0.35)
      border:       1px solid sage.withOpacity(0.4)
      borderRadius: 20px
      blur:         16px (BackdropFilter)
  - Padding: 20px horizontal, 18px vertical
  - Content: Inter, 14px, mist, centered, lineHeight 1.65
  - Text: "No algorithms. No data markets.
           Just the people and moments that matter."
  - Animate: slideY(begin: 0.15) + fadeIn, delay 1600ms

[Flexible spacer]

[Bottom hint]
  - Icon: keyboard_arrow_down, glow color, 22px
  - Animate: repeat translateY 0 → 8px → 0, duration 1.4s
  - Text below: "Swipe to explore", Inter 12px, mist, opacity 0.6
```

---

### Page 2 — "Slow Social" (Time Capsules / Intentional Friction)

**Concept:** Introduce the idea that patience is a feature. Show a time capsule card mid-flight.

**Layout:**

```
[Top 12% space]

[Section label]
  - Text: "A New Way to Connect"
  - Font: Inter, 11px, glow color, letter-spacing 2.5, UPPERCASE
  - Animate: fadeIn + slideX(begin: -0.1), duration 500ms

[12px gap]

[Headline]
  - Text: "Meaningful moments\nare worth the wait."
  - Font: Cormorant Garamond italic, 36px, sand, lineHeight 1.2
  - Animate: fadeIn + slideY(begin: 0.06), delay 200ms

[20px gap]

[Time Capsule Illustration Card]
  - Size: screenWidth * 0.78, height ~220px
  - Background: glassmorphism (moss 0.4 opacity, blur 20px, border sage 0.3)
  - borderRadius: 28px
  - Inner content (mimics a real UI card):

      Top row:
        lock icon (glow, 18px)
        + text "Time Capsule" (Inter 13px, sand)
        + right-aligned pill badge "Locked" (sage bg, glow text, 10px)

      Divider: 1px sage 0.3

      Middle:
        Text "Trip to Kyoto 🌸" (Cormorant 20px italic sand)
        Subtext "Opens in 47 days" (Inter 13px mist)

      Progress bar:
        Full width, height 4px, bg sage 0.3
        Filled 62% with glow color, borderRadius pill
        Animate fill: 0% → 62%, duration 1400ms, delay 600ms, curve easeOut

      Bottom row:
        3 avatar circles (overlapping, 28px, moss bg, sage border)
        + "From your Circle" (Inter 11px mist)

  - Card entry: scale 0.88 → 1.0 + fadeIn, delay 400ms, curve easeOutBack, 700ms
  - Idle: float translateY 0 → -6 → 0, duration 4s, repeat

[24px gap]

[Body text]
  - "Send memories, videos, and messages into the future.
     Set them free on the exact moment they matter most."
  - Inter 15px, mist, centered, lineHeight 1.65, width 78%
  - Animate: fadeIn delay 700ms

[Feature pills row — Wrap widget, spacing 8px]
  "🕰 Time Capsules"  |  "🔒 Locked Content"  |  "✨ Unlock Dates"
  - Each: glass bg (moss 0.3), border sage 0.3, radius 20, padding 8×14
  - Font: Inter 12px, sand
  - Stagger: each pill slides up + fades in, 120ms apart, delay starts at 900ms
```

---

### Page 3 — "The Canvas" (Spatial Collaboration)

**Concept:** Show infinite creative space. Sense of depth, floating items.

**Layout:**

```
[Top 10% space]

[Section label]
  - Text: "Oasis Canvas"
  - Same style as Page 2 section label

[10px gap]

[Headline]
  - Text: "Your shared world,\nalive and infinite."
  - Cormorant italic 36px sand

[18px gap]

[Canvas Mockup — Hero Visual]
  - Size: screenWidth * 0.88, height ~260px
  - Background: deep color, subtle dot-grid (CustomPainter, dots 1px,
    sage.withOpacity(0.18), spacing 22px)
  - borderRadius: 24px, border 1px sage 0.25
  - Floating "item" widgets in a Stack (absolutely positioned):

    Item A — Photo block (top-left area)
      60×60px, borderRadius 12, bg moss, border sage 0.4
      Icon: image, glow, 24px
      Label: "Kyoto Trip" Inter 9px mist
      Animate: fadeIn + scale 0.8→1, delay 300ms

    Item B — Text sticky (center-right)
      ~110×44px, bg sand.withOpacity(0.12), border sand 0.2, radius 10px
      Text: "remember this ✨" Inter italic 11px sand
      Animate: fadeIn + slideX(begin: 0.1), delay 500ms

    Item C — Voice note (bottom-left)
      Row: mic icon (glow 14px) + waveform bars (5 bars, heights 8–20px,
           glow color — each bar oscillates height ±4px with staggered
           AnimationControllers, ~600ms each) + "0:32" text
      Animate: fadeIn delay 700ms

    Item D — Doodle squiggle (top-right)
      CustomPainter loose squiggle path, color glow opacity 0.5
      Animate: draw path 0→1 via AnimatedBuilder, delay 900ms

    Item E — Milestone badge (bottom-center)
      Pill: "🎉 1 Year Together" sand bg, deep text Inter 10px bold
      Animate: scale 0→1, delay 1100ms, curve elasticOut

  - Whole card entry: scale 0.92 → 1 + fadeIn, delay 200ms, 800ms

[20px gap]

[Body text]
  - "A living mural of your relationships. Place anything, anywhere.
     Scrub back through time and watch your story unfold."
  - Inter 15px mist centered lineHeight 1.65, width 78%

[Feature icon row — 3 items, Row, evenly spaced]
  [grid_view, glow]   "Infinite Space"
  [history, glow]     "Timeline Scrub"
  [group, glow]       "Shared Circles"
  - Each: Column(icon 20px, 6px gap, Inter 11px mist)
  - Stagger fadeIn, 150ms apart, delay 800ms
```

---

### Page 4 — "Wellbeing" (Digital Energy / Detox)

**Concept:** Calm, restorative. Almost meditative. The app cares about you.

**Layout:**

```
[Top 12% space]

[Section label]
  - Text: "Digital Wellbeing"

[10px gap]

[Headline]
  - Text: "Your attention is\nprecious. We mean it."
  - Cormorant italic 36px sand

[22px gap]

[Energy Meter Illustration — centered, 200×200px]
  - Outer ring (CustomPainter arc):
      Full circle stroke: sage 0.2, strokeWidth 12
      Filled arc: glow, strokeWidth 12, strokeCap round
      Animate sweep: 0 → 210 degrees, duration 1600ms, delay 300ms, easeInOutCubic
  - Inner content (centered inside ring):
      Number: "73" Cormorant italic 48px sand (count up from 0 with delay)
      Label:  "Energy" Inter 12px mist, letter-spacing 1.5, UPPERCASE
  - Caption below ring: "Your focus, beautifully tracked." Inter 13px mist

[28px gap]

[3 Wellbeing Feature Cards — Column, spacing 10px, centered]

  Each card:
    - Width 82%, height 64px
    - Glass: moss 0.35, blur 14, border sage 0.3, borderRadius 16px, padding 16px
    - Row: [leading icon 22px glow] [12px gap] [Column: title Inter 14px sand /
           subtitle Inter 12px mist] [Spacer] [6px glow dot]

  Card 1: bolt_outlined       → "Energy Metering"  / "Visual gauge of your engagement"
  Card 2: palette_outlined    → "Dopamine Detox"   / "Grayscale mode to reset your mind"
  Card 3: school_outlined     → "Study Sessions"   / "Earn XP for focused deep work"

  Animate: slideX(begin: 0.12) + fadeIn, stagger 180ms, starting delay 600ms

[Flexible spacer]

[Ambient quote — bottom of content area]
  - Cormorant italic 18px, sand opacity 0.55, centered
  - Text: "Rest is not a reward. It is a right."
  - Animate: fadeIn delay 1400ms
```

---

### Page 5 — "Enter the Oasis" (CTA / Sign Up)

**Concept:** Culmination. Full-bleed emotional landing. One clear action.

**Layout:**

```
[Flexible spacer — pushes content toward vertical center]

[Logo mark — 72px, with rotating glow ring]
  - Outer ring: CustomPainter dashed circle, glow opacity 0.3, rotates 360°/12s repeat
  - Logo entry: scale 0→1, elasticOut
  - Same idle pulse as Page 1

[20px gap]

[Headline]
  - Text: "You're home."
  - Cormorant italic 52px sand
  - Animate: fadeIn + slideY(begin: 0.08), delay 300ms

[12px gap]

[Subtext]
  - "No noise. No performance. Just you and the people who matter."
  - Inter 16px mist centered lineHeight 1.65, width 75%
  - Animate: fadeIn delay 500ms

[Flexible spacer]

[CTA Section — replaces bottom nav bar entirely]

  Primary Button:
    - Width: screenWidth - 48px, height 58px, borderRadius 18px
    - Background: glow
    - Label: "Create Your Oasis" (Inter 15px semibold, deep color)
    - Leading icon: auto_awesome, deep, 18px
    - Shadow: BoxShadow(color: glow.withOpacity(0.45), blurRadius: 24,
              spreadRadius: 0, offset: Offset(0, 8))
    - Animate: scale 0.9→1 + fadeIn, delay 700ms, elasticOut
    - onTap: AnimatedScale 1.0 → 0.96 on tap down (GestureDetector)

  [12px gap]

  Secondary Button:
    - Same width, height 52px, borderRadius 18px
    - Background: transparent, border 1px sage 0.5
    - Label: "Sign In" Inter 15px mist
    - Animate: fadeIn delay 900ms

  [14px gap]

  Terms text:
    - "By continuing, you agree to our Privacy Promise."
    - Inter 11px, mist opacity 0.5, centered
    - "Privacy Promise" underlined, glow color
    - Animate: fadeIn delay 1100ms

  [Bottom safe area padding]
```

---

## 5. Page Transition & Entry Animation System

Use `flutter_animate` for all per-element animations. Trigger on page become active via `PageController` listener.

```dart
// Pattern for each page — listen in OnboardingShell:
_pageController.addListener(() {
  final page = _pageController.page?.round();
  if (page != _currentPage) {
    setState(() => _currentPage = page!);
    // Notify child pages to start their animation sequence
  }
});

// Each element in a page:
SomeWidget()
  .animate(target: widget.isActive ? 1 : 0)
  .fadeIn(duration: 500.ms, delay: 200.ms)
  .slideY(begin: 0.06, end: 0, duration: 500.ms, delay: 200.ms)
```

**Page-level transition effect:**
Listen to `PageController.page` value (continuous 0.0–4.0). For each page widget, compute its offset from current page. Apply:
- `Transform.scale(scale: 1.0 - (offset.abs() * 0.04))` — very subtle zoom out on exit
- `Opacity(opacity: 1.0 - (offset.abs() * 0.3))` — fade during swipe

This produces a premium "depth" transition rather than a flat slide.

---

## 6. Micro-Interactions

| Element | Behavior |
|---|---|
| All tap targets | `InkWell` splash `glow.withOpacity(0.15)` + `AnimatedScale` 0.96 on tap down |
| Page dots | `WormEffect` — active dot stretches liquidly toward next |
| CTA button | On tap: 280ms ripple + scale-down → then route |
| Logo | `AnimationController(3s, repeat)` → scale 1.0 ↔ 1.04 |
| Progress bar (Page 2) | `Tween<double>(0, 0.62)` on `AnimatedBuilder`, triggers on page entry |
| Energy arc (Page 4) | `Tween<double>(0, 210°)` sweeps on page entry, 1600ms |
| Waveform bars (Page 3) | Each bar: independent `AnimationController`, staggered, oscillates height |
| Floating card (Page 2) | `sin(t) * 6` applied to `Transform.translate` Y offset |

---

## 7. File Structure

```
lib/
  features/
    onboarding/
      onboarding_shell.dart         ← PageView shell, nav bar, skip/next logic
      pages/
        page1_welcome.dart
        page2_slow_social.dart
        page3_canvas.dart
        page4_wellbeing.dart
        page5_cta.dart
      widgets/
        oasis_background.dart       ← Shared animated blob background
        glass_card.dart             ← Reusable BackdropFilter glass container
        time_capsule_card.dart      ← Page 2 illustration widget
        canvas_preview.dart         ← Page 3 faux-infinite canvas
        energy_meter.dart           ← Page 4 CustomPainter arc
        oasis_logo_mark.dart        ← Logo + idle pulse + rotating ring
        feature_pill.dart           ← Tag pill chips
        wellbeing_card.dart         ← Page 4 feature row cards
        waveform_bars.dart          ← Page 3 voice note animation
  core/
    theme/
      oasis_colors.dart
      oasis_text_styles.dart
```

---

## 8. Implementation Notes for AI Coding Tools

- **Glassmorphism:** Use `BackdropFilter(filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16))` inside `ClipRRect`. Always place a `Container(color: moss.withOpacity(0.35))` behind it as the color fill layer. Wrap in `RepaintBoundary` on Android for performance.

- **CustomPainter usage:** Required for: background blobs, canvas dot-grid, energy meter arc, waveform bar heights, doodle squiggle path draw-on animation.

- **Doodle path animation (Page 3):** Use `PathMetric` + `extractPath(0, pathMetric.length * animValue)` inside an `AnimatedBuilder` to animate the path drawing from 0→1.

- **Particle system:** `List<AnimationController>` with `Future.delayed(Duration(milliseconds: i * 300))` start calls. Each drives a `Tween<double>(0, 1)` mapped to a Y translate via `sin`. Dispose all in `dispose()`.

- **Gyroscope parallax:** Wrap in `if (!kIsWeb)` and `try/catch`. Use `sensors_plus` `gyroscopeEventStream()`. Map X/Y rotation to blob offset clamped between -12 and 12.

- **Cormorant Garamond:** `GoogleFonts.cormorantGaramond(fontStyle: FontStyle.italic, ...)` — no separate import needed with `google_fonts` package.

- **Counter animation (Page 4, "73"):** Use `AnimatedBuilder` over a `CurvedAnimation` mapping 0→73 via `lerpDouble`. Start on page entry.

- **SafeArea:** Wrap all pages. On Page 5, CTA sits above `MediaQuery.of(context).padding.bottom`.

- **Web:** Disable gyroscope, ensure `BackdropFilter` is tested (web rendering differs). Use `kIsWeb` guards.

- **All `AnimationController` instances** must be declared in `State`, initialized in `initState`, and disposed in `dispose()`.
