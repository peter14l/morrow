import 'dart:convert';
import 'package:universal_io/io.dart';
import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:oasis/core/config/supabase_config.dart';
import 'package:oasis/core/network/supabase_client.dart';
import 'package:uuid/uuid.dart';

class InstagramMigrationService with ChangeNotifier {
  static final InstagramMigrationService _instance = InstagramMigrationService._internal();
  factory InstagramMigrationService() => _instance;
  InstagramMigrationService._internal();

  final SupabaseClient _supabase = SupabaseService().client;
  final _uuid = const Uuid();

  bool _isMigrating = false;
  double _progress = 0.0;
  String _currentStatus = '';
  int _totalPosts = 0;
  int _processedPosts = 0;

  bool get isMigrating => _isMigrating;
  double get progress => _progress;
  String get currentStatus => _currentStatus;
  int get totalPosts => _totalPosts;
  int get processedPosts => _processedPosts;

  // Extracted data model for review
  String? email;
  String? username;
  String? fullName;
  String? bio;
  File? profilePhotoFile;
  List<ArchiveFile> _postMediaFiles = [];
  List<Map<String, dynamic>> _parsedPosts = [];

  void reset() {
    _isMigrating = false;
    _progress = 0.0;
    _currentStatus = '';
    _totalPosts = 0;
    _processedPosts = 0;
    email = null;
    username = null;
    fullName = null;
    bio = null;
    profilePhotoFile = null;
    _postMediaFiles = [];
    _parsedPosts = [];
    notifyListeners();
  }

  /// Parses the ZIP file to extract profile data and post metadata before account creation.
  Future<bool> preProcessZip(String zipPath) async {
    reset();
    _isMigrating = true;
    _currentStatus = 'Reading ZIP file...';
    notifyListeners();

    try {
      final bytes = await File(zipPath).readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);
      final tempDir = await getTemporaryDirectory();

      // Look for profile info and posts json
      for (final file in archive) {
        if (!file.isFile) continue;

        final path = file.name.toLowerCase();

        // 1. Personal Information (Email, Full Name)
        if (path.contains('personal_information') && path.endsWith('.json')) {
          try {
            final content = utf8.decode(file.content as List<int>);
            final data = json.decode(content);
            // Handle different Instagram JSON structures
            if (data is Map) {
              final info = data['profile_user_settings'] ?? data['personal_information'] ?? data;
              if (info is List && info.isNotEmpty) {
                final first = info.first;
                if (first is Map && first['string_map_data'] is Map) {
                  final map = first['string_map_data'] as Map;
                  email = map['Email']?['value'] ?? map['email']?['value'];
                  fullName = map['Name']?['value'] ?? map['name']?['value'];
                }
              } else if (info is Map) {
                email = info['email'] ?? info['Email'];
                fullName = info['full_name'] ?? info['name'];
              }
            }
          } catch (e) {
            debugPrint('[Migration] Error parsing personal info: $e');
          }
        }

        // 2. Profile Details (Username, Bio, Profile Photo Name)
        if ((path.contains('profile_details') || path.endsWith('profile.json')) && path.endsWith('.json')) {
          try {
            final content = utf8.decode(file.content as List<int>);
            final data = json.decode(content);
            if (data is Map) {
              final profile = data['profile_user_settings'] ?? data;
              if (profile is Map) {
                username = profile['username'];
                bio = profile['biography'] ?? profile['bio'];
                if (fullName == null && profile['name'] != null) {
                  fullName = profile['name'];
                }
              }
            }
          } catch (e) {
            debugPrint('[Migration] Error parsing profile: $e');
          }
        }

        // 3. Profile Photo Extraction
        if (path.contains('profile_photo') && (path.endsWith('.jpg') || path.endsWith('.png') || path.endsWith('.jpeg'))) {
          try {
            final photoFile = File('${tempDir.path}/temp_profile_photo.jpg');
            await photoFile.writeAsBytes(file.content as List<int>);
            profilePhotoFile = photoFile;
          } catch (e) {
            debugPrint('[Migration] Error extracting profile photo: $e');
          }
        }

        // 4. Store references to post media files and post metadata files
        if (path.contains('posts_1.json') || path.endsWith('posts.json') || path.contains('your_posts')) {
          try {
            final content = utf8.decode(file.content as List<int>);
            final data = json.decode(content);
            if (data is List) {
              for (var item in data) {
                if (item is Map) {
                  _parsedPosts.add(Map<String, dynamic>.from(item));
                }
              }
            }
          } catch (e) {
            debugPrint('[Migration] Error parsing posts JSON: $e');
          }
        }
      }

      // Collect all post media files in memory/archive pointer
      for (final file in archive) {
        if (!file.isFile) continue;
        final path = file.name.toLowerCase();
        if (path.contains('media/posts/') || path.contains('posts/media/')) {
          _postMediaFiles.add(file);
        }
      }

      _totalPosts = _parsedPosts.length;
      _currentStatus = 'Zip analyzed. Found $_totalPosts posts.';
      _isMigrating = false;
      notifyListeners();
      return true;
    } catch (e) {
      _currentStatus = 'Failed to parse ZIP: $e';
      _isMigrating = false;
      notifyListeners();
      return false;
    }
  }

  /// Starts the post-migration process in the background.
  Future<void> startBackgroundPostMigration(String userId) async {
    if (_parsedPosts.isEmpty) {
      _currentStatus = 'No posts to migrate.';
      notifyListeners();
      return;
    }

    _isMigrating = true;
    _processedPosts = 0;
    _progress = 0.0;
    _currentStatus = 'Starting background post sync...';
    notifyListeners();

    final tempDir = await getTemporaryDirectory();

    // Process posts sequentially in the background
    Future.microtask(() async {
      try {
        for (var i = 0; i < _parsedPosts.length; i++) {
          final post = _parsedPosts[i];
          final mediaList = post['media'] as List?;
          if (mediaList == null || mediaList.isEmpty) continue;

          final firstMedia = mediaList.first as Map?;
          final uri = firstMedia?['uri'] as String?;
          final title = firstMedia?['title'] as String? ?? '';
          final timestamp = firstMedia?['creation_timestamp'] as int?;

          if (uri == null) continue;

          // Find the file in the media list
          final matchingFile = _postMediaFiles.firstWhere(
            (f) => f.name.toLowerCase().contains(uri.toLowerCase()) || uri.toLowerCase().contains(f.name.toLowerCase()),
            orElse: () => ArchiveFile('', 0, null),
          );

          String? publicUrl;
          if (matchingFile.name.isNotEmpty && matchingFile.content != null) {
            // Write to a temporary file
            final ext = uri.split('.').last;
            final fileName = '${_uuid.v4()}.$ext';
            final tempFile = File('${tempDir.path}/$fileName');
            await tempFile.writeAsBytes(matchingFile.content as List<int>);

            // Upload to Supabase Storage
            final path = '$userId/$fileName';
            await _supabase.storage
                .from(SupabaseConfig.postImagesBucket)
                .upload(path, tempFile);

            publicUrl = _supabase.storage
                .from(SupabaseConfig.postImagesBucket)
                .getPublicUrl(path);

            // Clean up temp file
            await tempFile.delete();
          }

          // Create the post in database
          final postId = _uuid.v4();
          final postData = {
            'id': postId,
            'user_id': userId,
            'content': title,
            'image_url': publicUrl,
            'media_urls': publicUrl != null ? [publicUrl] : [],
            'media_types': ['image'],
            'created_at': timestamp != null 
                ? DateTime.fromMillisecondsSinceEpoch(timestamp * 1000).toIso8601String()
                : DateTime.now().toIso8601String(),
            'storage_provider': 'supabase',
          };

          await _supabase.from(SupabaseConfig.postsTable).insert(postData);

          _processedPosts++;
          _progress = _processedPosts / _totalPosts;
          _currentStatus = 'Syncing posts ($_processedPosts/$_totalPosts)...';
          notifyListeners();
        }

        _currentStatus = 'Instagram migration complete! $_processedPosts posts synced.';
        _isMigrating = false;
        notifyListeners();
      } catch (e) {
        debugPrint('[Migration] Error in background sync: $e');
        _currentStatus = 'Background sync paused due to error: $e';
        _isMigrating = false;
        notifyListeners();
      }
    });
  }

  /// Helper to upload profile photo to Supabase storage.
  Future<String?> uploadProfilePhoto(String userId) async {
    if (profilePhotoFile == null) return null;
    try {
      final fileName = '${_uuid.v4()}.jpg';
      final path = '$userId/$fileName';
      
      await _supabase.storage
          .from(SupabaseConfig.profilePicturesBucket)
          .upload(path, profilePhotoFile!);

      return _supabase.storage
          .from(SupabaseConfig.profilePicturesBucket)
          .getPublicUrl(path);
    } catch (e) {
      debugPrint('[Migration] Error uploading profile photo: $e');
      return null;
    }
  }
}
