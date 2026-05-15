import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:oasis/routes/app_router.dart';

class DeepLinkService {
  static final DeepLinkService _instance = DeepLinkService._internal();
  factory DeepLinkService() => _instance;
  DeepLinkService._internal();

  late AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;

  void init() {
    _appLinks = AppLinks();

    // Handle links when the app is already running (foreground/background)
    _linkSubscription = _appLinks.uriLinkStream.listen(
      (uri) {
        debugPrint('DeepLinkService: Received link: $uri');
        _handleDeepLink(uri);
      },
      onError: (err) {
        debugPrint('DeepLinkService: Error listening to links: $err');
      },
    );

    // Handle the link that opened the app (cold start)
    _checkInitialLink();
  }

  Future<void> _checkInitialLink() async {
    try {
      final uri = await _appLinks.getInitialLink();
      if (uri != null) {
        debugPrint('DeepLinkService: Initial link: $uri');
        _handleDeepLink(uri);
      }
    } catch (e) {
      debugPrint('DeepLinkService: Error getting initial link: $e');
    }
  }

  void _handleDeepLink(Uri uri) {
    String path = uri.path;

    // For custom schemes like oasis://post/123, the host is 'post' and path is '/123'
    if (uri.scheme == 'oasis') {
      path = '/${uri.host}${uri.path}';
    }

    // Only handle our specific web domain or scheme
    if (uri.host == 'oasis-web-red.vercel.app' || uri.scheme == 'oasis') {
      debugPrint('DeepLinkService: Navigating to path: $path');

      // Ensure we don't navigate if the path is empty or just /
      if (path.isEmpty || path == '/') return;

      // Ignore auth callbacks as they are handled by the Supabase SDK internally
      if (path.startsWith('/auth/callback') ||
          path.startsWith('/auth/apple/callback')) {
        debugPrint(
          'DeepLinkService: Ignoring auth callback path, letting Supabase handle it.',
        );
        return;
      }

      // Use GoRouter to navigate
      AppRouter.router.go(path);
    }
  }

  void dispose() {
    _linkSubscription?.cancel();
  }
}
