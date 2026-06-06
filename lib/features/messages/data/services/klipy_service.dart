import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:universal_io/io.dart';
import 'package:oasis/core/network/supabase_client.dart';

/// Result wrapper that includes error information for debugging
class KlipyResult<T> {
  final T? data;
  final String? error;
  final int? statusCode;
  bool get isSuccess => error == null && data != null;

  KlipyResult.success(this.data) : error = null, statusCode = 200;

  KlipyResult.failure(this.error, {this.statusCode}) : data = null;
}

class KlipyService {
  final bool _debugMode = true; // Set to false in production

  String _getPlatformString() {
    if (kIsWeb) return 'web';
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    if (Platform.isWindows) return 'windows';
    if (Platform.isMacOS) return 'macos';
    return 'web';
  }

  Future<KlipyResult<List<KlipyMedia>>> search(
    String query, {
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      final response = await SupabaseService().client.functions.invoke(
        'klipy-proxy',
        body: {
          'endpoint': 'search',
          'query': query,
          'limit': limit,
          'offset': offset,
          'platform': _getPlatformString(),
        },
      );

      if (_debugMode) {
        debugPrint('[Klipy] Search response status: ${response.status}');
      }

      if (response.status == 200 && response.data != null) {
        final Map<String, dynamic> data = response.data is String 
            ? json.decode(response.data) 
            : response.data;
        final Map<String, dynamic>? innerData =
            data['data'] as Map<String, dynamic>?;
        final List results = (innerData != null)
            ? (innerData['data'] as List? ?? [])
            : [];
        return KlipyResult.success(
          results.map((e) => KlipyMedia.fromJson(e)).toList(),
        );
      }
      return KlipyResult.failure(
        'HTTP ${response.status}: ${response.data}',
        statusCode: response.status,
      );
    } catch (e) {
      return KlipyResult.failure('Network/Proxy error: $e', statusCode: -1);
    }
  }

  Future<KlipyResult<List<KlipyMedia>>> getTrending({
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      final response = await SupabaseService().client.functions.invoke(
        'klipy-proxy',
        body: {
          'endpoint': 'trending',
          'limit': limit,
          'offset': offset,
          'platform': _getPlatformString(),
        },
      );

      if (_debugMode) {
        debugPrint('[Klipy] Trending response status: ${response.status}');
      }

      if (response.status == 200 && response.data != null) {
        final Map<String, dynamic> data = response.data is String 
            ? json.decode(response.data) 
            : response.data;
        final Map<String, dynamic>? innerData =
            data['data'] as Map<String, dynamic>?;
        final List results = (innerData != null)
            ? (innerData['data'] as List? ?? [])
            : [];
        return KlipyResult.success(
          results.map((e) => KlipyMedia.fromJson(e)).toList(),
        );
      }
      return KlipyResult.failure(
        'HTTP ${response.status}: ${response.data}',
        statusCode: response.status,
      );
    } catch (e) {
      return KlipyResult.failure('Network/Proxy error: $e', statusCode: -1);
    }
  }
}

class KlipyMedia {
  final String id;
  final String url;
  final String thumbnailUrl;
  final String title;

  KlipyMedia({
    required this.id,
    required this.url,
    required this.thumbnailUrl,
    required this.title,
  });

  factory KlipyMedia.fromJson(Map<String, dynamic> json) {
    final fileObj = json['file'] as Map<String, dynamic>?;
    final hd = fileObj?['hd'] as Map<String, dynamic>?;
    final sm = fileObj?['sm'] as Map<String, dynamic>?;

    final String gifUrl = hd?['gif']?['url'] ?? '';
    final String thumbUrl = sm?['webp']?['url'] ?? sm?['gif']?['url'] ?? gifUrl;

    return KlipyMedia(
      id: json['id']?.toString() ?? '',
      url: gifUrl,
      thumbnailUrl: thumbUrl,
      title: json['title'] ?? '',
    );
  }
}
