import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

enum Currency { usd, inr, eur, gbp }

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
  static final Map<Currency, Map<String, dynamic>> _pricingData = {
    Currency.usd: {'symbol': '\$', 'monthly': 4.99, 'annual': 34.99},
    Currency.inr: {
      'symbol': '₹',
      'monthly': 5.0, // Testing price
      'annual': 50.0, // Testing price
    },
    Currency.eur: {'symbol': '€', 'monthly': 4.99, 'annual': 34.99},
    Currency.gbp: {'symbol': '£', 'monthly': 4.49, 'annual': 31.99},
  };

  static final Map<String, Currency> _countryToCurrency = {
    'IN': Currency.inr,
    'GB': Currency.gbp,
    'DE': Currency.eur,
    'FR': Currency.eur,
    'IT': Currency.eur,
    'ES': Currency.eur,
    'US': Currency.usd,
  };

  static Future<Currency> detectPPP() async {
    // Priority 1: System Hardware Locale (Highly resistant to VPN)
    final systemCurrency = detectCurrency();

    try {
      // Priority 2: IP-based detection (Used for validation)
      final response = await http
          .get(Uri.parse('https://ipapi.co/json/'))
          .timeout(const Duration(seconds: 3));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final ipCountryCode = data['country_code']?.toString().toUpperCase();

        // Validation: If IP country doesn't match System Locale,
        // it's likely a VPN. Default to USD for safety.
        final systemCountryCode = PlatformDispatcher.instance.locale.countryCode
            ?.toUpperCase();

        if (ipCountryCode != null && systemCountryCode != null) {
          if (ipCountryCode != systemCountryCode) {
            debugPrint(
              'VPN Detected! IP: $ipCountryCode vs Locale: $systemCountryCode. Defaulting to USD.',
            );
            return Currency.usd;
          }
        }

        if (ipCountryCode != null &&
            _countryToCurrency.containsKey(ipCountryCode)) {
          return _countryToCurrency[ipCountryCode]!;
        }
      }
    } catch (e) {
      debugPrint('PPP Detection via IP failed: $e');
    }

    // Fallback to the Hardware Locale detected at the start
    return systemCurrency;
  }

  static Currency detectCurrency() {
    try {
      // First check if we have a valid country code from the system locale
      final countryCode = PlatformDispatcher.instance.locale.countryCode
          ?.toUpperCase();
      if (countryCode != null && _countryToCurrency.containsKey(countryCode)) {
        return _countryToCurrency[countryCode]!;
      }

      // Additional check for common European countries that might not be in our explicit map
      final languageCode = PlatformDispatcher.instance.locale.languageCode
          .toLowerCase();
      if (['de', 'fr', 'it', 'es', 'nl', 'be', 'at'].contains(languageCode)) {
        return Currency.eur;
      }
    } catch (e) {
      debugPrint('Locale detection failed: $e');
    }

    // Fallback: For desktop apps, try to detect via IP (async call - synchronous for compatibility)
    // This is a best-effort fallback. Callers should use detectPPP() for async IP detection.
    return Currency.usd;
  }

  static List<PricingPlan> getPlans(Currency currency) {
    final data = _pricingData[currency]!;
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
