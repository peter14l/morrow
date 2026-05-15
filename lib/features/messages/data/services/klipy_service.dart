import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:oasis/features/messages/core/chat_api_config.dart';

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
  final String _baseUrl = 'https://api.klipy.com/api/v1';
  final bool _debugMode = true; // Set to false in production

  Future<KlipyResult<List<KlipyMedia>>> search(
    String query, {
    int limit = 20,
    int offset = 0,
  }) async {
    if (ChatApiConfig.klipyApiKey.isEmpty) {
      return KlipyResult.failure(
        'API key is empty. Check .env KLIPY keys (KLIPY_WEB_KEY, etc.)',
        statusCode: 0,
      );
    }

    try {
      final apiKey = ChatApiConfig.klipyApiKey;
      final uri = Uri.parse(
        '$_baseUrl/$apiKey/gifs/search?q=$query&limit=$limit&offset=$offset',
      );
      final response = await http.get(uri);

      if (_debugMode) {
        debugPrint('[Klipy] Search request: $uri');
        debugPrint('[Klipy] Search response status: ${response.statusCode}');
        debugPrint(
          '[Klipy] Search response body length: ${response.body.length}',
        );
      }

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final Map<String, dynamic>? innerData =
            data['data'] as Map<String, dynamic>?;
        final List results = (innerData != null)
            ? (innerData['data'] as List? ?? [])
            : [];
        return KlipyResult.success(
          results.map((e) => KlipyMedia.fromJson(e)).toList(),
        );
      } else if (response.statusCode == 204) {
        // No Content - return empty list successfully
        return KlipyResult.success([]);
      }
      return KlipyResult.failure(
        'HTTP ${response.statusCode}: ${response.body}',
        statusCode: response.statusCode,
      );
    } catch (e) {
      return KlipyResult.failure('Network error: $e', statusCode: -1);
    }
  }

  Future<KlipyResult<List<KlipyMedia>>> getTrending({
    int limit = 20,
    int offset = 0,
  }) async {
    if (ChatApiConfig.klipyApiKey.isEmpty) {
      return KlipyResult.failure(
        'API key is empty. Check .env KLIPY keys (KLIPY_WEB_KEY, etc.)',
        statusCode: 0,
      );
    }

    try {
      final apiKey = ChatApiConfig.klipyApiKey;
      final uri = Uri.parse(
        '$_baseUrl/$apiKey/gifs/trending?limit=$limit&offset=$offset',
      );
      final response = await http.get(uri);

      if (_debugMode) {
        debugPrint('[Klipy] Trending request: $uri');
        debugPrint('[Klipy] Trending response status: ${response.statusCode}');
        debugPrint(
          '[Klipy] Trending response body length: ${response.body.length}',
        );
      }

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final Map<String, dynamic>? innerData =
            data['data'] as Map<String, dynamic>?;
        final List results = (innerData != null)
            ? (innerData['data'] as List? ?? [])
            : [];
        return KlipyResult.success(
          results.map((e) => KlipyMedia.fromJson(e)).toList(),
        );
      } else if (response.statusCode == 204) {
        // No Content - return empty list successfully
        return KlipyResult.success([]);
      }
      return KlipyResult.failure(
        'HTTP ${response.statusCode}: ${response.body}',
        statusCode: response.statusCode,
      );
    } catch (e) {
      return KlipyResult.failure('Network error: $e', statusCode: -1);
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
