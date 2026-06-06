import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:universal_io/io.dart';
import 'package:oasis/core/network/supabase_client.dart';

class GiphyResult<T> {
  final T? data;
  final String? error;
  bool get isSuccess => error == null;

  GiphyResult.success(this.data) : error = null;
  GiphyResult.failure(this.error) : data = null;
}

class GiphyMedia {
  final String id;
  final String url;
  final String thumbnailUrl;
  final String title;
  final bool isSticker;

  GiphyMedia({
    required this.id,
    required this.url,
    required this.thumbnailUrl,
    required this.title,
    this.isSticker = false,
  });

  factory GiphyMedia.fromJson(
    Map<String, dynamic> json, {
    bool isSticker = false,
  }) {
    final images = json['images'] as Map<String, dynamic>?;
    final original = images?['original'] as Map<String, dynamic>?;
    final fixedHeight = images?['fixed_height'] as Map<String, dynamic>?;
    final downsized = images?['downsized'] as Map<String, dynamic>?;

    return GiphyMedia(
      id: json['id']?.toString() ?? '',
      url: original?['url'] ?? '',
      thumbnailUrl:
          fixedHeight?['url'] ?? downsized?['url'] ?? original?['url'] ?? '',
      title: json['title'] ?? '',
      isSticker: isSticker,
    );
  }
}

class GiphyService {
  String _getPlatformString() {
    if (kIsWeb) return 'web';
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    if (Platform.isWindows) return 'windows';
    if (Platform.isMacOS) return 'macos';
    return 'web';
  }

  Future<GiphyResult<List<GiphyMedia>>> search(
    String query, {
    bool isSticker = false,
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      final response = await SupabaseService().client.functions.invoke(
        'giphy-proxy',
        body: {
          'endpoint': 'search',
          'query': query,
          'isSticker': isSticker,
          'limit': limit,
          'offset': offset,
          'platform': _getPlatformString(),
        },
      );

      if (response.status == 200 && response.data != null) {
        final Map<String, dynamic> data = response.data is String 
            ? json.decode(response.data) 
            : response.data;
        final List results = data['data'] as List? ?? [];
        return GiphyResult.success(
          results
              .map((e) => GiphyMedia.fromJson(e, isSticker: isSticker))
              .toList(),
        );
      }
      return GiphyResult.failure('HTTP ${response.status}: ${response.data}');
    } catch (e) {
      return GiphyResult.failure(e.toString());
    }
  }

  Future<GiphyResult<List<GiphyMedia>>> getTrending({
    bool isSticker = false,
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      final response = await SupabaseService().client.functions.invoke(
        'giphy-proxy',
        body: {
          'endpoint': 'trending',
          'isSticker': isSticker,
          'limit': limit,
          'offset': offset,
          'platform': _getPlatformString(),
        },
      );

      if (response.status == 200 && response.data != null) {
        final Map<String, dynamic> data = response.data is String 
            ? json.decode(response.data) 
            : response.data;
        final List results = data['data'] as List? ?? [];
        return GiphyResult.success(
          results
              .map((e) => GiphyMedia.fromJson(e, isSticker: isSticker))
              .toList(),
        );
      }
      return GiphyResult.failure('HTTP ${response.status}: ${response.data}');
    } catch (e) {
      return GiphyResult.failure(e.toString());
    }
  }

  Future<GiphyResult<List<String>>> getCategories({
    bool isSticker = false,
  }) async {
    // Standard categories that work well
    return GiphyResult.success([
      'Trending',
      'Reactions',
      'Love',
      'Happy',
      'Sad',
      'Angry',
      'Surprised',
      'Dance',
      'High Five',
      'Facepalm',
      'Applause',
      'Goodbye',
      'Hello',
      'Yes',
      'No',
      'Maybe',
      'Hungry',
      'Tired',
    ]);
  }
}
