# Privacy-First Ad Monetization Plan
## Oasis Free Tier Revenue Strategy

> **Status:** Proposed  
> **Date:** 2026-05-07  
> **Scope:** Ad monetization strategy, platform selection, implementation architecture, and setup plan  
> **Core Constraint:** ZERO user data collection — ads must be served without behavioral profiling, cookies, or cross-app tracking  

---

## 1. The Revenue Model

**Contextual-Only Advertising** — ads served based on **the content you're currently viewing**, not your behavioral history. No cookies, no IDFA/GAID, no cross-app profiling, no retargeting.

### Why This Works
- ✅ Aligns with your brand promise — *no data collection = no data-driven ads*
- ✅ Complies with GDPR/CCPA naturally (no consent gate needed for tracking)
- ✅ User privacy advocates and privacy-aware audiences **prefer** and **trust** this model
- ✅ Publishers like Wikipedia, Proton, and Mastodon use this successfully
- ✅ **"Privacy-first" becomes your marketing differentiator**, not a limitation

### Revenue Tiers (Stacking)

| Tier | Format | Placement | Revenue Potential |
|---|---|---|---|
| **1 — Rewarded** | Watch ad → unlock Pro feature | Settings, Wellness Center | Highest ARPU (~$5-15 CPM) |
| **2 — Interstitial** | Full-screen between transitions | Screen navigation flows | Medium ARPU |
| **3 — Native** | In-feed ad cards | Communities, Feed | Medium ARPU |
| **4 — Banner** | Static banner | Communities list, Search results | Low CPM |

---

## 2. Ad Placement Strategy (Privacy-Aligned)

### Where to Place Ads (No Data Needed)

```
Free User Journey:
  /feed          → Native ad cards (every 5-7 ripples)
  /communities   → Banner at top + native ads in list
  /spaces        → Interstitial on space join
  /settings      → Rewarded ad (unlock Pro feature demo)
  /wellness      → Rewarded ad (earn energy)
  /search        → Banner ads in results
```

### Ad Formats That Respect Privacy

| Format | Targeting Signal | Privacy Level |
|---|---|---|
| **Contextual Banner** | Current community/category topic | ✅ Maximum |
| **Native In-Feed** | Feed/Community topic keywords | ✅ Maximum |
| **Interstitial** | Route transition trigger | ✅ Maximum |
| **Rewarded Video** | User-initiated (opt-in) | ✅ Maximum |
| **Search Ad** | Search query keywords | ✅ Maximum |

### What to AVOID
- ❌兴趣图谱 targeting (user behavior profiles)
- ❌ Cross-site/cross-app tracking
- ❌ IDFA/GAID-based demographic targeting
- ❌ Retargeting lookalikes
- ❌ Predictive user scoring

---

## 3. Ad Platform Recommendations

### Tier 1: Privacy-First Ad Networks

| Platform | Best For | Revenue | Privacy Model | Flutter SDK |
|---|---|---|---|---|
| **Google AdSense / AdMob** (restricted) | All formats | ★★★★★ | Content-aware only (opt-in) | ✅ Official |
| **EthicalAds** (ethicalads.io) | Web only | ★★☆☆☆ | Contextual keyword | ✅ Official |
| **Carbon Ads** | Tech/developer audience | ★★☆☆☆ | Contextual | Manual embed |
| **AdBuddiz** | Mobile only | ★★★☆☆ | No tracking | ✅ Android only |
| **Bidscube** | Mobile + web | ★★★☆☆ | GDPR-compliant | ✅ |
| **AdColony** (Alt) | Rewarded video | ★★★★☆ | No IDFA by default | ✅ |

### Recommended Architecture (Multi-Platform)

```
Flutter App
├── google_mobile_ads (AdSense + AdMob)
│   ├── Smart Banner (contextual, no user profiling)
│   ├── Native Advanced (content-matched)
│   ├── Interstitial (transition-based)
│   └── Rewarded Ad (user-initiated)
│
├── EthicalAds Flutter SDK (web-only for ethical appeal)
│   └── Server-side keyword matching (NO CLIENT TRACKING)
│
└── RevenueCat (existing) ← PRO upsell remains the primary conversion path
```

### Why Google AdMob (Restricted Mode) is Your Best Bet

- ✅ Works on all 3 platforms (Android, iOS, Windows)
- ✅ Contextual targeting via page/content keywords — **no IDFA needed**
- ✅ Google handles ad selection server-side — they profile, not you
- ✅ Rewarded ads drive highest revenue for social apps
- ✅ Native ads blend naturally with feed UI
- ✅ You collect **zero** user data from ads
- ⚠️ Google will still profile on their end — **disclose this transparently** in your privacy policy. Your app's *own* backend collects nothing.

### Configuration for Privacy

In AdMob dashboard, enable:
- **Content-Based Targeting Only** (disable remarketing, demographics)
- **Restricted Personalization** (treat all users as non-personalized)
- **CMP integration** — handle consent dialog for EEA users (required by law, not optional)

---

## 4. Implementation Setup Plan

### Phase 1: Platform Setup (1-2 days)

**Google AdMob Account:**
1. Create AdMob account at apps.admob.com
2. Register Android app, iOS app, Windows app
3. Create ad units for each format + placement
4. Request **non-personalized ads** in targeting settings

**Ad Units to Create:**

| Ad Unit ID | Format | Placement | Size |
|---|---|---|---|
| `ca-app-pub-xxxx/feed-native` | Native Advanced | Feed every 5 posts | Match feed card |
| `ca-app-pub-xxxx/feed-banner` | Banner | Feed top | 320×50 / Smart Banner |
| `ca-app-pub-xxxx/community-banner` | Banner | Communities list | 320×50 |
| `ca-app-pub-xxxx/search-banner` | Banner | Search results | 320×50 |
| `ca-app-pub-xxxx/space-interstitial` | Interstitial | Spaces entry | Full screen |
| `ca-app-pub-xxxx/rewarded-pro` | Rewarded | Settings/Wellness | Full screen |
| `ca-app-pub-xxxx/home-interstitial` | Interstitial | App open | Full screen |

**Privacy Policy Updates (Critical):**
1. Add section: "Third-Party Ad Services" disclosing Google AdMob usage
2. State: "We do not share any user data with advertisers"
3. State: "Ads are served based on the content you are currently viewing, not your behavior"
4. Add EEA/GDPR consent notice

### Phase 2: Flutter Integration (3-5 days)

**Package Addition:**
```yaml
# pubspec.yaml
dependencies:
  google_mobile_ads: ^3.0.0          # AdSense + AdMob
  # (RevenueCat, Supabase already exist)
```

**Directory Structure:**
```
lib/
├── services/
│   ├── ad_service.dart              # Ad loading, caching, rotation
│   ├── ad_frequency_cap_service.dart # Server-side frequency cap (local only)
│   └── ad_revenue_tracker.dart      # Track impressions for reporting
├── widgets/
│   ├── ads/
│   │   ├── native_ad_widget.dart    # In-feed native ad
│   │   ├── banner_ad_widget.dart     # Reusable banner
│   │   ├── interstitial_ad_widget.dart
│   │   ├── rewarded_ad_widget.dart
│   │   └── ad_badge.dart            # "Ad" label for compliance
│   └── feed/
│       └── ripple_ad_card.dart      # Native ad styled as ripple
├── providers/
│   └── ad_provider.dart            # Manages ad state, Pro check
└── screens/
    └── ad_settings_screen.dart      # User controls: "Show ads" toggle
```

**Core Architecture (`ad_service.dart`):**
- Load ads server-side based on **CONTEXT** (community, keywords, etc.)
- **NEVER pass user behavioral data**
- Cache ads locally for X hours (no user tracking)
- Rotate ads on interval, **NOT** on user action count
- Track impressions for revenue only (no PII)

**Pro Gate Logic:**
```dart
// In SubscriptionService or new AdProvider:
bool get showAds {
  if (isPro) return false;  // Pro = ad-free
  return true;             // Free tier = ads
}
```

### Phase 3: UI Integration Points (2-3 days)

**Feed (`lib/screens/feed_screen.dart`):**
- Insert native ad card every 5-7 ripples
- Native ad styled to match ripple card exactly
- Marked with "Ad" badge for transparency

**Communities (`lib/screens/community/communities_screen.dart`):**
- Top banner: Static community-topic ad
- List: Native ads every 4-5 communities

**Spaces (WebRTC — `lib/screens/spaces/spaces_screen.dart`):**
- Interstitial on: space join, space end
- Duration: 5-15 seconds non-skippable
- Auto-dismiss on video ready

**Settings (`lib/screens/settings_screen.dart`):**
- Add "Rewarded Ad" card: "Watch an ad to try Pro features free for 1 hour"
- Connects to rewarded ad unit
- Track reward grant in AdRevenueTracker

**Wellness Center (`lib/features/wellness/presentation/screens/wellness_center_screen.dart`):**
- Rewarded ad: "Watch an ad to earn +20 energy"
- Natural fit with digital wellbeing theme

### Phase 4: Privacy Safeguards (Ongoing)

**Frequency Cap Without User Data:**
```dart
// Server-side approach: Supabase edge function
// Store: { device_id, ad_unit, shown_at, session_id }
// Rule: Max 1 interstitial per 3 sessions, max 5 banners per day
// No user profile linking — device-scoped only
```

**GDPR/CCPA Compliance:**
1. **EEA Users**: Show consent dialog before loading any ads — AdMob's UMP SDK handles this
2. **Non-EEA**: No consent needed for non-personalized ads
3. **California (CCPA)**: Add opt-out link in Privacy Policy

**Audit Log Integration:**
```dart
// Extend existing PrivacyAuditService
Future<void> logAdImpression({
  required String adUnitId,
  required String adFormat,
}) async {
  // Log ONLY ad metrics — NO user identifiers linked to this log
  // This is for your revenue reporting, not user profiling
}
```

---

## 5. Revenue Projection

### Conservative Model

| Format | CPM (est.) | Impressions/Day (free user) | Daily Revenue/User |
|---|---|---|---|
| Rewarded | $8-15 | 0.3 (opt-in) | $0.004 |
| Interstitial | $4-8 | 1-2 | $0.01 |
| Native In-Feed | $3-6 | 4-6 | $0.02 |
| Banner | $1-2 | 3-5 | $0.005 |

**Per free user: ~$0.04-0.06/day → $1.50-2.20/user/month**

For 10K active free users: **$15K-22K/month gross ad revenue**

Compare to Pro subscription: ~$5/user/month if 5% convert → $2,500/month  
→ **Ads can 6-8x your free-tier revenue** at scale

### Blended Revenue Stack
- Free users → Ads (revenue)
- Pro users → Subscription (revenue + no ads)
- 1% of free users convert to Pro after experiencing app via rewarded ads

---

## 6. Key Risks & Mitigations

| Risk | Severity | Mitigation |
|---|---|---|
| Google flags non-personalized ads as low revenue | Medium | Supplement with EthicalAds/web |
| Apple App Tracking Transparency blocks IDFA | Low | AdMob handles this; contextual works |
| GDPR enforcement on ad consent | Medium | Use AdMob UMP SDK; don't serve ads to non-consented EEA users |
| User churn from ad annoyance | High | Keep frequency caps strict; UX-first placement |
| Brand perception damage | Medium | Transparent "Ad" labeling; privacy-forward messaging |
| Ad content misaligning with privacy brand | Medium | Use AdMob content filtering; block adult/crypto categories |

---

## 7. Recommended Execution Order

```
1. Setup AdMob account + create ad units
2. Update Privacy Policy (legal requirement)
3. Add google_mobile_ads package
4. Build AdService + AdProvider (architecture backbone)
5. Build reusable ad widgets (Banner, Native, Interstitial, Rewarded)
6. Integrate into Communities screen (banner + native)
7. Integrate into Feed (native in-feed)
8. Integrate into Spaces (interstitial)
9. Add rewarded ad in Settings/Wellness
10. Add "Show ads" user toggle in settings
11. Setup frequency cap via Supabase edge function
12. Setup ad revenue tracking in Supabase
13. A/B test: Ad-free 7-day trial → Pro conversion lift
14. Add EthicalAds for web platform
```

---

## 8. Existing Codebase Reference

### Tech Stack
- **Frontend:** Flutter (Dart) — Android, iOS, Windows (Fluent UI)
- **Backend:** Supabase (PostgreSQL + RLS)
- **Routing:** go_router
- **State Management:** Provider
- **Auth:** Supabase Auth + Google/Apple Sign In
- **Existing Monetization:** RevenueCat (Pro IAP), Razorpay (IN), PayPal

### Key Files
| File | Role |
|---|---|
| `lib/services/subscription_service.dart` | Pro status check — use this to gate ads (`isPro`) |
| `lib/services/revenuecat_service.dart` | RevenueCat integration — already working |
| `lib/services/pricing_service.dart` | PPP pricing detection (reuse for ad geo context) |
| `lib/services/privacy_audit_service.dart` | Extend this for ad impression logging |
| `lib/screens/oasis_pro_screen.dart` | Pro upsell screen — existing, integrate ad-rewarded trial here |
| `lib/screens/feed_screen.dart` | Feed — primary native ad placement |
| `lib/screens/community/communities_screen.dart` | Communities — banner + native placement |
| `lib/screens/spaces/spaces_screen.dart` | Spaces — interstitial placement |
| `lib/screens/settings_screen.dart` | Settings — rewarded ad placement |
| `lib/features/wellness/presentation/screens/wellness_center_screen.dart` | Wellness — rewarded ad placement |
| `lib/main.dart` | App entry — AdMob init goes here |
| `pubspec.yaml` | Add `google_mobile_ads` dependency here |

### Supabase Tables Needed (New)
```sql
-- Ad frequency cap (device-scoped, no user linking)
CREATE TABLE ad_frequency_caps (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  device_id TEXT NOT NULL,
  ad_unit_id TEXT NOT NULL,
  shown_at TIMESTAMPTZ DEFAULT now(),
  session_id TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);
-- Index for fast lookups
CREATE INDEX idx_ad_freq_device ON ad_frequency_caps(device_id, ad_unit_id);

-- Ad revenue tracking (aggregated, no PII)
CREATE TABLE ad_revenue_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  ad_unit_id TEXT NOT NULL,
  ad_format TEXT NOT NULL,
  impression_count INT DEFAULT 1,
  revenue_usd DECIMAL(10,6),
  recorded_at DATE DEFAULT current_date,
  created_at TIMESTAMPTZ DEFAULT now()
);
```

---

## Summary

| Question | Answer |
|---|---|
| **Can ads work without user data?** | ✅ Yes — contextual-only serving is viable and aligns with your brand |
| **Which platform?** | Google AdMob (restricted/non-personalized) + EthicalAds (web supplement) |
| **Which formats?** | Native in-feed > Rewarded > Interstitial > Banner |
| **Where to integrate?** | Feed, Communities, Spaces, Settings, Wellness |
| **How to cap without tracking?** | Device-scoped session counters in Supabase |
| **Revenue potential?** | $1.50-2.20/free user/month — meaningful at scale |
| **Brand risk?** | Low if: transparent "Ad" labels + no behavioral tracking + Pro remains ad-free |
