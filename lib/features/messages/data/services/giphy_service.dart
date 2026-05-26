import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:oasis/features/messages/core/chat_api_config.dart';

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
  final String _baseUrl = 'https://api.giphy.com/v1';

  Future<GiphyResult<List<GiphyMedia>>> search(
    String query, {
    bool isSticker = false,
    int limit = 20,
    int offset = 0,
  }) async {
    final apiKey = ChatApiConfig.giphyApiKey;
    if (apiKey.isEmpty) return GiphyResult.failure('API key missing');

    try {
      final type = isSticker ? 'stickers' : 'gifs';
      final uri = Uri.parse(
        '$_baseUrl/$type/search?api_key=$apiKey&q=$query&limit=$limit&offset=$offset&rating=g',
      );
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List results = data['data'] as List? ?? [];
        return GiphyResult.success(
          results
              .map((e) => GiphyMedia.fromJson(e, isSticker: isSticker))
              .toList(),
        );
      }
      return GiphyResult.failure('HTTP ${response.statusCode}');
    } catch (e) {
      return GiphyResult.failure(e.toString());
    }
  }

  Future<GiphyResult<List<GiphyMedia>>> getTrending({
    bool isSticker = false,
    int limit = 20,
    int offset = 0,
  }) async {
    final apiKey = ChatApiConfig.giphyApiKey;
    if (apiKey.isEmpty) return GiphyResult.failure('API key missing');

    try {
      final type = isSticker ? 'stickers' : 'gifs';
      final uri = Uri.parse(
        '$_baseUrl/$type/trending?api_key=$apiKey&limit=$limit&offset=$offset&rating=g',
      );
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List results = data['data'] as List? ?? [];
        return GiphyResult.success(
          results
              .map((e) => GiphyMedia.fromJson(e, isSticker: isSticker))
              .toList(),
        );
      }
      return GiphyResult.failure('HTTP ${response.statusCode}');
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
