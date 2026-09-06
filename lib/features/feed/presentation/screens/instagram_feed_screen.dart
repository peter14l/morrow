import 'dart:async';
import 'package:flutter/material.dart';
import 'package:universal_io/io.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:go_router/go_router.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';

class InstagramFeedScreen extends StatefulWidget {
  const InstagramFeedScreen({super.key});

  // Static notifier to communicate tab-bar visibility state to the parent MainLayout router shell
  static final ValueNotifier<bool> showNavBarNotifier = ValueNotifier<bool>(true);

  @override
  State<InstagramFeedScreen> createState() => _InstagramFeedScreenState();
}

class _InstagramFeedScreenState extends State<InstagramFeedScreen> {
  // Static controller cache to keep the webview state alive when navigating away
  static WebViewController? _cachedController;
  
  WebViewController? _controller;
  bool _isLoading = false;
  double _progress = 0;
  bool _canGoBack = false;
  bool _canGoForward = false;

  // Scroll detection tracking variables
  double _lastScrollY = 0;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb && Platform.isAndroid) {
      _requestInitialPermissions();
      if (_cachedController != null) {
        // Reuse existing controller to preserve scroll position and page state
        _controller = _cachedController;
        _updateNavigationState();
        _setupScrollHandler();
      } else {
        _initWebView();
      }
    }
  }

  Future<void> _requestInitialPermissions() async {
    // Request critical permissions for media browsing (photo uploads) and microphone (voice recordings)
    try {
      await [
        Permission.camera,
        Permission.microphone,
        Permission.photos,
        Permission.videos,
        Permission.storage,
      ].request();
    } catch (e) {
      debugPrint('[InstagramWebView] Error requesting permissions: $e');
    }
  }

  void _initWebView() {
    // Pass the permission request handler directly to the WebViewController constructor
    _controller = WebViewController(
      onPermissionRequest: (WebViewPermissionRequest request) async {
        final types = request.types;
        
        // Ensure system permissions are granted before approving the webview request
        for (final type in types) {
          if (type == WebViewPermissionResourceType.microphone) {
            await Permission.microphone.request();
          } else if (type == WebViewPermissionResourceType.camera) {
            await Permission.camera.request();
          }
        }
        
        // Grant the requested resource access to the web app
        try {
          await request.grant();
        } catch (e) {
          debugPrint('[InstagramWebView] Failed to grant webview permission: $e');
        }
      },
    )
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..setUserAgent(
        'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            if (mounted) {
              setState(() {
                _progress = progress / 100.0;
                _isLoading = progress < 100;
              });
            }
          },
          onPageStarted: (String url) {
            if (mounted) {
              setState(() {
                _isLoading = true;
              });
            }
          },
          onPageFinished: (String url) async {
            if (mounted) {
              setState(() {
                _isLoading = false;
              });
              _updateNavigationState();
            }
          },
          onWebResourceError: (WebResourceError error) {
            debugPrint('[InstagramWebView] Error: ${error.description}');
          },
        ),
      );

    // Enable native image & file picker in WebView for Instagram media uploads
    if (_controller!.platform is AndroidWebViewController) {
      final androidController =
          _controller!.platform as AndroidWebViewController;
      androidController.setOnShowFileSelector((FileSelectorParams params) async {
        try {
          final acceptsImages = params.acceptTypes.any(
                (t) => t.contains('image') || t == '*/*',
              ) ||
              params.acceptTypes.isEmpty;
          final acceptsVideos =
              params.acceptTypes.any((t) => t.contains('video'));

          final picker = ImagePicker();
          if (params.mode == FileSelectorMode.openMultiple) {
            if (acceptsImages && !acceptsVideos) {
              final images = await picker.pickMultiImage();
              return images.map((img) => Uri.file(img.path).toString()).toList();
            } else if (acceptsVideos && !acceptsImages) {
              final video = await picker.pickVideo(source: ImageSource.gallery);
              if (video != null) return [Uri.file(video.path).toString()];
            } else {
              final media = await picker.pickMultipleMedia();
              return media.map((m) => Uri.file(m.path).toString()).toList();
            }
          } else {
            if (acceptsVideos && !acceptsImages) {
              final video = await picker.pickVideo(source: ImageSource.gallery);
              if (video != null) return [Uri.file(video.path).toString()];
            } else {
              final image = await picker.pickImage(source: ImageSource.gallery);
              if (image != null) return [Uri.file(image.path).toString()];
            }
          }
        } catch (e) {
          debugPrint('[InstagramWebView] Error selecting media: $e');
        }
        return <String>[];
      });
    }
      
    _setupScrollHandler();
    _controller!.loadRequest(Uri.parse('https://www.instagram.com/'));
    _cachedController = _controller;
  }

  void _setupScrollHandler() {
    _controller!.setOnScrollPositionChange((ScrollPositionChange change) {
      if (!mounted) return;
      final y = change.y;
      final delta = y - _lastScrollY;
      _lastScrollY = y;

      // Filter out micro-scrolls to prevent jitter
      if (delta.abs() > 4) {
        if (delta < 0) {
          // Scroll UP -> Show Oasis navigation bar and set auto-hide timer
          _showNavBarAndScheduleHide();
        } else if (delta > 0) {
          // Scroll DOWN -> Hide Oasis navigation bar
          _hideNavBar();
        }
      }
    });
  }

  void _showNavBarAndScheduleHide() {
    _hideTimer?.cancel();
    if (!InstagramFeedScreen.showNavBarNotifier.value) {
      InstagramFeedScreen.showNavBarNotifier.value = true;
    }
    
    // Auto-hide navigation bar after 7 seconds of no scrolling
    _hideTimer = Timer(const Duration(seconds: 7), () {
      if (mounted) {
        _hideNavBar();
      }
    });
  }

  void _hideNavBar() {
    _hideTimer?.cancel();
    if (InstagramFeedScreen.showNavBarNotifier.value) {
      InstagramFeedScreen.showNavBarNotifier.value = false;
    }
  }

  Future<void> _updateNavigationState() async {
    if (_controller == null) return;
    final canGoBack = await _controller!.canGoBack();
    final canGoForward = await _controller!.canGoForward();
    if (mounted) {
      setState(() {
        _canGoBack = canGoBack;
        _canGoForward = canGoForward;
      });
    }
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    // Always restore the navigation bar state so it is visible by default on other tabs
    InstagramFeedScreen.showNavBarNotifier.value = true;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isAndroid = !kIsWeb && Platform.isAndroid;

    if (!isAndroid) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Instagram Connection'),
          leading: IconButton(
            icon: const Icon(FluentIcons.arrow_left_24_regular),
            onPressed: () => context.go('/feed'),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  FluentIcons.camera_24_regular,
                  size: 64,
                  color: Colors.grey,
                ),
                const SizedBox(height: 16),
                Text(
                  'Android Only Feature',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'The Instagram integration is currently optimized for Android devices. Desktop and Web versions will be enabled in a future release.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => context.go('/feed'),
                  child: const Text('Back to Oasis Feed'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return PopScope(
      canPop: !_canGoBack,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (_controller != null && _canGoBack) {
          await _controller!.goBack();
          _updateNavigationState();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Instagram Web'),
          elevation: 0,
          backgroundColor: theme.colorScheme.surface,
          leading: IconButton(
            icon: const Icon(FluentIcons.arrow_left_24_regular),
            onPressed: () {
              context.go('/feed');
            },
          ),
          actions: [
            IconButton(
              icon: Icon(
                FluentIcons.arrow_left_24_regular,
                color: _canGoBack ? theme.colorScheme.onSurface : Colors.grey,
              ),
              onPressed: _canGoBack
                  ? () async {
                      await _controller?.goBack();
                      _updateNavigationState();
                    }
                  : null,
            ),
            IconButton(
              icon: Icon(
                FluentIcons.arrow_right_24_regular,
                color: _canGoForward ? theme.colorScheme.onSurface : Colors.grey,
              ),
              onPressed: _canGoForward
                  ? () async {
                      await _controller?.goForward();
                      _updateNavigationState();
                    }
                  : null,
            ),
            IconButton(
              icon: const Icon(FluentIcons.arrow_clockwise_24_regular),
              onPressed: () => _controller?.reload(),
            ),
          ],
        ),
        body: Stack(
          children: [
            if (_controller != null)
              Padding(
                // Only pad the system safe navigation area (gesture bar) so Instagram takes full viewport height
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).padding.bottom,
                ),
                child: WebViewWidget(controller: _controller!),
              ),
            if (_isLoading)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: LinearProgressIndicator(
                  value: _progress > 0 ? _progress : null,
                  backgroundColor: theme.colorScheme.surfaceContainer,
                  valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
