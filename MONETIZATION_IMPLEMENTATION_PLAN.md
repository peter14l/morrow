# Oasis Monetization Implementation Plan

This document outlines a detailed engineering plan to implement a hybrid monetization engine for Oasis. It combines **Discord-style premium item subscriptions/circle boosting** with **Brave-style privacy-preserving, first-party contextual ads**.

---

## 🗺 System Architecture

```mermaid
graph TD
    subgraph Client (Oasis Flutter App)
        UI[UI Layers: Feed, Profile, Circles] --> AdWidget[Privacy Ad Banner]
        UI --> Shop[Item Shop / Boosting Dialog]
        AdMatch[On-Device Ad Matching Engine] -->|Fetches Catalog| LocalDB[(Hive Cache)]
        AdMatch -->|Selects Ad Locally| AdWidget
        SubService[Subscription & Customization Service]
    end

    subgraph Backend (Supabase / Postgres)
        Catalog[Ad Campaigns Catalog] -->|First-Party Sync| LocalDB
        SubDB[(Profiles & Customizations DB)] <--> SubService
    end
```

---

## 📂 Phase 1: Database Schema Setup (Supabase)

We need tables to track user inventory (cosmetics), Circle boosts, and first-party ad campaigns.

Create migration file: `supabase/migrations/20260529000000_monetization_setup.sql`:

```sql
-- 1. Inventory & Customizations Table
CREATE TABLE public.user_customizations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    item_type VARCHAR(50) NOT NULL, -- 'profile_theme', 'avatar_frame', 'haptic_pack'
    item_id VARCHAR(100) NOT NULL,  -- e.g. 'cyberpunk_glass', 'heartbeat_haptic'
    is_active BOOLEAN DEFAULT false,
    purchased_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()),
    UNIQUE(user_id, item_type, item_id)
);

-- 2. Circle Boosting Table
CREATE TABLE public.circle_boosts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    circle_id UUID REFERENCES public.circles(id) ON DELETE CASCADE,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    boosted_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()),
    expires_at TIMESTAMP WITH TIME ZONE -- NULL if tied to active subscription
);

-- 3. First-Party Contextual Ad Campaigns
CREATE TABLE public.ad_campaigns (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title VARCHAR(255) NOT NULL,
    description TEXT,
    banner_url TEXT NOT NULL,
    destination_url TEXT NOT NULL,
    category_target VARCHAR(100) NOT NULL, -- 'wellness', 'productivity', 'tech'
    start_date TIMESTAMP WITH TIME ZONE NOT NULL,
    end_date TIMESTAMP WITH TIME ZONE NOT NULL,
    is_active BOOLEAN DEFAULT true
);

-- 4. Secure RLS policies
ALTER TABLE public.user_customizations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.circle_boosts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ad_campaigns ENABLE ROW LEVEL SECURITY;

-- Allow users to view all active campaigns
CREATE POLICY "Allow public read of active ads" ON public.ad_campaigns
    FOR SELECT USING (is_active = true AND now() BETWEEN start_date AND end_date);
```

---

## 📦 Phase 2: Brave-Style On-Device Ad Matching Engine

To protect user privacy, ad campaigns are fetched in bulk and matched **locally** based on on-device data. No user data is sent to the server.

### 1. Local Cache Definition (`lib/features/monetization/data/models/ad_campaign.dart`)
Create an immutable model representing the campaign catalog.

### 2. Ad Service (`lib/features/monetization/data/services/privacy_ad_service.dart`)
```dart
class PrivacyAdService {
  final _supabase = SupabaseService().client;
  List<AdCampaign> _cachedCampaigns = [];

  // Sync latest catalog from first-party database
  Future<void> fetchAdCatalog() async {
    try {
      final response = await _supabase
          .from('ad_campaigns')
          .select()
          .eq('is_active', true);
      
      _cachedCampaigns = (response as List)
          .map((json) => AdCampaign.fromJson(json))
          .toList();
    } catch (e) {
      debugPrint('[PrivacyAdService] Failed to fetch catalog: $e');
    }
  }

  // Purely local matching based on current screen context or wellness state
  AdCampaign? matchAdLocally({
    required String screenCategory, // 'wellness', 'chat', 'feed'
    required double userScreenTimeHours,
  }) {
    if (_cachedCampaigns.isEmpty) return null;

    // Filter campaigns matching the current screen category target
    final matches = _cachedCampaigns.where((ad) {
      return ad.categoryTarget == screenCategory;
    }).toList();

    if (matches.isEmpty) return null;

    // Select randomly or match weight without sending tracking telemetry
    final random = Random();
    return matches[random.nextInt(matches.length)];
  }
}
```

---

## 🎨 Phase 3: Discord-Style Subscriptions (Oasis Aura)

### 1. Item Store UI (`lib/features/monetization/presentation/screens/shop_screen.dart`)
Provide a clean glassmorphic shop for cosmetic items:
*   **Custom Themes**: Cyberpunk Glass, E-ink Minimalist, Rose Gold.
*   **Haptic Patterns**: Pulsing heartbeat, syncopated rhythm.
*   **Aura Badge**: A visual tag next to names in messages and feeds.

### 2. Circle Boosting (`lib/features/monetization/presentation/widgets/boost_dialog.dart`)
*   Add a **Boost** button next to Circle details.
*   Display total Circle Boost count with progress steps (e.g., 5 boosts unlock custom headers, 10 boosts unlock high-fidelity voice spaces).

---

## 🚀 Phase 4: Integration Checklist

1.  [x] **Run Migration**: `supabase/migrations/20260529000000_microtransactions_monetization.sql`
2.  [x] **AdCampaign Model**: `lib/features/monetization/data/models/ad_campaign.dart`
3.  [x] **PrivacyAdService**: `lib/features/monetization/data/services/privacy_ad_service.dart`
4.  [x] **PrivacyAdBanner Widget**: `lib/features/monetization/presentation/widgets/privacy_ad_banner.dart`
5.  [x] **BoostDialog Widget**: `lib/features/monetization/presentation/widgets/boost_dialog.dart`
6.  [x] **Feature Flags**: `ENABLE_PRIVACY_ADS` and `ENABLE_OASIS_AURA` added to `AppConfig`
7.  [x] **Provider Registration**: `CustomizationService` and `PrivacyAdService` registered in `AppInitializer`
8.  [x] **Router Integration**: `/oasis-pro` route now points to `ShopScreen`
9.  [x] **Boost Button in Circles**: Rocket icon in `CircleDetailScreen` AppBar opens `BoostDialog`
10. [x] **Ad Catalog Fetch**: `CircleDetailScreen` fetches ad catalog on load for contextual matching
