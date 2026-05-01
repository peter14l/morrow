import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:oasis/core/network/supabase_client.dart';
import 'package:oasis/features/settings/domain/models/user_settings_entity.dart';
import 'package:oasis/models/feed_layout_strategy.dart';

class SettingsRemoteDatasource {
  final SupabaseClient _client;

  SettingsRemoteDatasource({SupabaseClient? client})
      : _client = client ?? SupabaseService().client;

  Future<bool> syncSettings(UserSettingsEntity settings) async {
    final user = _client.auth.currentUser;
    if (user == null) return false;

    try {
      await _client.from('profiles').update({
        'data_saver': settings.dataSaver,
        'font_size_factor': settings.fontSizeFactor,
        'high_contrast': settings.highContrast,
        'daily_limit_minutes': settings.dailyLimitMinutes,
        'wind_down_enabled': settings.windDownEnabled,
        'mica_enabled': settings.micaEnabled,
        'window_effect': settings.windowEffect,
        'font_family': settings.fontFamily,
        'feed_layout': settings.feedLayout.name,
      }).eq('id', user.id);
      return true;
    } catch (e) {
      // Log error but don't fail the app
      debugPrint('Failed to sync settings to Supabase: $e');
      return false;
    }
  }

  Future<UserSettingsEntity?> fetchSettings() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;

    try {
      final data = await _client
          .from('profiles')
          .select('data_saver, font_size_factor, high_contrast, daily_limit_minutes, wind_down_enabled, mica_enabled, window_effect, font_family, feed_layout')
          .eq('id', user.id)
          .single();
      
      return UserSettingsEntity(
        dataSaver: data['data_saver'] ?? false,
        fontSizeFactor: (data['font_size_factor'] as num?)?.toDouble() ?? 1.0,
        highContrast: data['high_contrast'] ?? false,
        dailyLimitMinutes: data['daily_limit_minutes'] ?? 0,
        windDownEnabled: data['wind_down_enabled'] ?? false,
        micaEnabled: data['mica_enabled'] ?? false,
        windowEffect: data['window_effect'] ?? 'mica',
        fontFamily: data['font_family'] ?? 'Inter',
        feedLayout: FeedLayoutType.values.firstWhere(
          (e) => e.name == data['feed_layout'],
          orElse: () => FeedLayoutType.classic,
        ),
      );
    } catch (e) {
      debugPrint('Failed to fetch settings from Supabase: $e');
      return null;
    }
  }
}
