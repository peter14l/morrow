import 'package:flutter/foundation.dart';
import 'package:oasis/core/network/supabase_client.dart';

enum Currency { 
  usd, eur, gbp, aud, cad, 
  jpy, inr, brl, mxn, idr, 
  thb, myr, php, krw 
}

class PricingPlan {
  final String name;
  final double price;
  final String symbol;
  final Currency currency;

  PricingPlan({
    required this.name,
    required this.price,
    required this.symbol,
    required this.currency,
  });
}

class PricingService {
  // PPP Adjusted Pricing Data
  static final Map<Currency, Map<String, dynamic>> _pricingData = {
    // Tier 1 (Base/High GDP)
    Currency.usd: {'symbol': '\$', 'monthly': 4.99, 'annual': 34.99},
    Currency.eur: {'symbol': '€', 'monthly': 4.99, 'annual': 34.99},
    Currency.gbp: {'symbol': '£', 'monthly': 4.49, 'annual': 31.99},
    Currency.aud: {'symbol': 'A\$', 'monthly': 7.99, 'annual': 54.99},
    Currency.cad: {'symbol': 'C\$', 'monthly': 6.99, 'annual': 49.99},
    
    // Tier 2 (Medium PPP)
    Currency.jpy: {'symbol': '¥', 'monthly': 600.0, 'annual': 4200.0},
    Currency.krw: {'symbol': '₩', 'monthly': 4900.0, 'annual': 49000.0},
    
    // Tier 3 (Lower PPP - Emerging Markets)
    Currency.inr: {'symbol': '₹', 'monthly': 149.0, 'annual': 1499.0},
    Currency.brl: {'symbol': 'R\$', 'monthly': 14.90, 'annual': 149.90},
    Currency.mxn: {'symbol': '\$', 'monthly': 49.0, 'annual': 499.0},
    Currency.idr: {'symbol': 'Rp', 'monthly': 39000.0, 'annual': 390000.0},
    Currency.thb: {'symbol': '฿', 'monthly': 99.0, 'annual': 990.0},
    Currency.myr: {'symbol': 'RM', 'monthly': 14.90, 'annual': 149.90},
    Currency.php: {'symbol': '₱', 'monthly': 149.0, 'annual': 1490.0},
  };

  static final Map<String, Currency> _countryToCurrency = {
    // Tier 1
    'US': Currency.usd,
    'GB': Currency.gbp,
    'DE': Currency.eur, 'FR': Currency.eur, 'IT': Currency.eur, 
    'ES': Currency.eur, 'NL': Currency.eur, 'AT': Currency.eur,
    'BE': Currency.eur, 'GR': Currency.eur, 'FI': Currency.eur,
    'AU': Currency.aud,
    'CA': Currency.cad,
    
    // Tier 2
    'JP': Currency.jpy,
    'KR': Currency.krw,

    // Tier 3
    'IN': Currency.inr,
    'BR': Currency.brl,
    'MX': Currency.mxn,
    'ID': Currency.idr,
    'TH': Currency.thb,
    'MY': Currency.myr,
    'PH': Currency.php,
  };

  static Future<Currency> detectPPP() async {
    // Priority 1: System Hardware Locale (Highly resistant to VPN)
    final systemCurrency = detectCurrency();

    try {
      // Priority 2: IP-based detection via Supabase Edge Function (Secure & Scaleable)
      final supabase = SupabaseService().client;
      final response = await supabase.functions.invoke('get-user-country');

      if (response.status == 200 && response.data != null) {
        final ipCountryCode = response.data['country_code']?.toString().toUpperCase();

        // Validation: If IP country doesn't match System Locale,
        // it's likely a VPN. Default to USD for safety.
        final systemCountryCode = PlatformDispatcher.instance.locale.countryCode?.toUpperCase();

        if (ipCountryCode != null && systemCountryCode != null) {
          if (ipCountryCode != systemCountryCode) {
            debugPrint(
              'VPN Detected! IP: $ipCountryCode vs Locale: $systemCountryCode. Defaulting to USD.',
            );
            return Currency.usd;
          }
        }

        if (ipCountryCode != null && _countryToCurrency.containsKey(ipCountryCode)) {
          return _countryToCurrency[ipCountryCode]!;
        }
      }
    } catch (e) {
      debugPrint('PPP Detection via Supabase Edge Function failed: $e');
    }

    // Fallback to the Hardware Locale detected at the start
    return systemCurrency;
  }

  static Currency detectCurrency() {
    try {
      // First check if we have a valid country code from the system locale
      final countryCode = PlatformDispatcher.instance.locale.countryCode?.toUpperCase();
      if (countryCode != null && _countryToCurrency.containsKey(countryCode)) {
        return _countryToCurrency[countryCode]!;
      }

      // Additional check for common European countries that might not be in our explicit map
      final languageCode = PlatformDispatcher.instance.locale.languageCode.toLowerCase();
      if (['de', 'fr', 'it', 'es', 'nl', 'be', 'at'].contains(languageCode)) {
        return Currency.eur;
      }
    } catch (e) {
      debugPrint('Locale detection failed: $e');
    }

    // Fallback
    return Currency.usd;
  }

  static List<PricingPlan> getPlans(Currency currency) {
    // Fallback to USD if for some reason the currency isn't in our data map
    final data = _pricingData[currency] ?? _pricingData[Currency.usd]!;
    
    return [
      PricingPlan(
        name: 'Monthly',
        price: data['monthly'],
        symbol: data['symbol'],
        currency: currency,
      ),
      PricingPlan(
        name: 'Annual',
        price: data['annual'],
        symbol: data['symbol'],
        currency: currency,
      ),
    ];
  }
}
