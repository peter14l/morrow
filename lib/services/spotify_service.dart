import 'package:oasis/features/stories/domain/models/story_entity.dart';
import 'package:flutter/foundation.dart';
import 'package:oasis/core/network/supabase_client.dart';

class SpotifyService {
  // Popular tracks for mock/fallback
  static final List<StoryMusicEntity> _featuredTracks = [
    StoryMusicEntity(
      trackId: '0VjIj970nyB7S6tc27JpsO',
      title: 'Blinding Lights',
      artist: 'The Weeknd',
      albumArtUrl:
          'https://i.scdn.co/image/ab67616d0000b2738863bc11fafbf383a54d6d67',
      previewUrl:
          'https://p.scdn.co/mp3-preview/6324268e36785501869811f269a84d413554e4c2',
      artworkStyle: 'original',
    ),
    StoryMusicEntity(
      trackId: '5Y640pS3K99Z766oXv8p7P',
      title: 'Save Your Tears',
      artist: 'The Weeknd',
      albumArtUrl:
          'https://i.scdn.co/image/ab67616d0000b2738863bc11fafbf383a54d6d67',
      previewUrl:
          'https://p.scdn.co/mp3-preview/a91901174620585f6738c823f66299b86be0b155',
      artworkStyle: 'original',
    ),
    StoryMusicEntity(
      trackId: '2693892839283',
      title: 'As It Was',
      artist: 'Harry Styles',
      albumArtUrl:
          'https://i.scdn.co/image/ab67616d0000b273b46b7e8b6267802871ee27a7',
      previewUrl:
          'https://p.scdn.co/mp3-preview/3e0bd2275841774312017366d9817751f78f6920',
      artworkStyle: 'original',
    ),
  ];

  static const List<String> artworkStyles = [
    'original',
    'blurred',
    'circle',
    'full',
  ];

  String? _accessToken;
  DateTime? _tokenExpiry;

  Future<String?> _getValidToken() async {
    if (_accessToken != null &&
        _tokenExpiry != null &&
        DateTime.now().isBefore(_tokenExpiry!)) {
      return _accessToken;
    }

    try {
      // Call our secure backend proxy to get a client credentials token
      final response = await SupabaseService().client.functions.invoke(
        'spotify-auth-proxy',
        body: {}, // Empty body triggers client_credentials flow on backend
      );

      if (response.status == 200 && response.data != null) {
        _accessToken = response.data['access_token'];
        final expiresIn = response.data['expires_in'] as int;
        _tokenExpiry = DateTime.now().add(Duration(seconds: expiresIn - 60));
        return _accessToken;
      }
    } catch (e) {
      debugPrint('Spotify Auth Proxy Error: $e');
    }
    return null;
  }

  Future<List<StoryMusicEntity>> searchTracks(String query) async {
    if (query.isEmpty) return _featuredTracks;

    final token = await _getValidToken();
    if (token == null) {
      // Fallback if auth fails
      return _featuredTracks
          .where(
            (t) =>
                t.title.toLowerCase().contains(query.toLowerCase()) ||
                t.artist.toLowerCase().contains(query.toLowerCase()),
          )
          .toList();
    }

    try {
      // We can call Spotify directly with the token,
      // or route search through backend if we want to hide queries.
      // For now, calling Spotify with a valid token is fine as the SECRET is hidden.
      final response = await SupabaseService().client.functions.invoke(
        'spotify-search',
        body: {'query': query, 'limit': 20},
      );

      if (response.status == 200 && response.data != null) {
        final List<dynamic> items = response.data['tracks']['items'];
        return items.map((item) => _parseTrack(item)).toList();
      }
    } catch (e) {
      debugPrint('Spotify Search Error: $e');
    }

    return _featuredTracks
        .where(
          (t) =>
              t.title.toLowerCase().contains(query.toLowerCase()) ||
              t.artist.toLowerCase().contains(query.toLowerCase()),
        )
        .toList();
  }

  StoryMusicEntity _parseTrack(Map<String, dynamic> item) {
    final images = item['album']['images'] as List;
    return StoryMusicEntity(
      trackId: item['id'],
      title: item['name'] ?? '',
      artist: (item['artists'] as List).map((a) => a['name']).join(', '),
      albumArtUrl: images.isNotEmpty ? images[0]['url'] : '',
      previewUrl: item['preview_url'] ?? '',
      artworkStyle: 'original',
    );
  }

  Future<List<StoryMusicEntity>> getFeaturedTracks() async {
    return _featuredTracks;
  }
}
