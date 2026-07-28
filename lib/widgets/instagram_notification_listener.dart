import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:universal_io/io.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:webview_flutter/webview_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:oasis/widgets/instagram_notification_overlay.dart';

class InstagramNotificationListenerWidget extends StatefulWidget {
  const InstagramNotificationListenerWidget({super.key});

  @override
  State<InstagramNotificationListenerWidget> createState() =>
      _InstagramNotificationListenerWidgetState();
}

class _InstagramNotificationListenerWidgetState
    extends State<InstagramNotificationListenerWidget> {
  WebViewController? _controller;
  Timer? _sessionCheckTimer;
  String? _lastSender;
  String? _lastText;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb && Platform.isAndroid) {
      _initBackgroundWebView();
    }
  }

  void _initBackgroundWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(
        'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36'
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String url) {
            debugPrint('[InstagramBackground] Page loaded: $url');
            if (url.contains('direct/inbox')) {
              _injectMonitoringScript();
            }
          },
          onWebResourceError: (WebResourceError error) {
            debugPrint('[InstagramBackground] Resource error: ${error.description}');
          },
        ),
      )
      ..addJavaScriptChannel(
        'OasisInstagramDMChannel',
        onMessageReceived: (JavaScriptMessage message) {
          _handleInstagramMessage(message.message);
        },
      )
      ..loadRequest(Uri.parse('https://www.instagram.com/direct/inbox/'));

    // Self-healing session sync: Check if logged in every 20 seconds.
    // If we've been redirected away from direct/inbox (e.g. to a login page),
    // try reloading it. Once logged in on the main webview, this will succeed.
    _sessionCheckTimer = Timer.periodic(const Duration(seconds: 20), (timer) async {
      if (_controller == null) return;
      try {
        final currentUrl = await _controller!.currentUrl();
        if (currentUrl != null && !currentUrl.contains('direct/inbox')) {
          debugPrint('[InstagramBackground] Session sync check: Attempting to reload inbox...');
          await _controller!.loadRequest(Uri.parse('https://www.instagram.com/direct/inbox/'));
        }
      } catch (e) {
        debugPrint('[InstagramBackground] Error in session sync timer: $e');
      }
    });
  }

  void _injectMonitoringScript() {
    if (_controller == null) return;

    // JavaScript to monitor title changes (unread notifications count)
    // and scrape the top unread conversation item for snippet details.
    const monitorScript = '''
      (function() {
        if (window.OasisMonitorActive) return;
        window.OasisMonitorActive = true;
        
        let lastUnreadCount = 0;
        
        setInterval(function() {
          let title = document.title;
          let match = title.match(/\\((\\d+)\\)/);
          let unreadCount = match ? parseInt(match[1]) : 0;
          
          if (unreadCount > lastUnreadCount) {
            let sender = "Instagram";
            let message = "You have a new direct message";
            
            try {
              // Try to find the first unread chat in the direct message list
              let chatLinks = document.querySelectorAll('a[href^="/direct/t/"]');
              for (let link of chatLinks) {
                let isUnread = false;
                let spans = link.querySelectorAll('span');
                
                // Unread messages typically have bold font weight
                for (let span of spans) {
                  let style = window.getComputedStyle(span);
                  if (style.fontWeight === '600' || style.fontWeight === 'bold' || style.fontWeight === '700') {
                    isUnread = true;
                    break;
                  }
                }
                
                if (isUnread || link.querySelector('svg[aria-label="Unread"]') !== null) {
                  if (spans.length > 0) {
                    sender = spans[0].innerText.trim();
                  }
                  if (spans.length > 1) {
                    let text = spans[1].innerText.trim();
                    if (text && text !== sender) {
                      message = text;
                    }
                  }
                  break;
                }
              }
            } catch (e) {
              // Fallback to title unread count
            }
            
            // Notify Flutter
            OasisInstagramDMChannel.postMessage(JSON.stringify({
              sender: sender,
              message: message,
              count: unreadCount
            }));
          }
          
          lastUnreadCount = unreadCount;
        }, 4000);
      })();
    ''';

    _controller!.runJavaScript(monitorScript).catchError((e) {
      debugPrint('[InstagramBackground] Script injection error: $e');
    });
  }

  void _handleInstagramMessage(String jsonPayload) {
    try {
      final Map<String, dynamic> data = jsonDecode(jsonPayload);
      final sender = data['sender'] as String? ?? 'Instagram';
      final message = data['message'] as String? ?? 'New message';

      // Check current navigation path
      final state = GoRouterState.of(context);
      final currentPath = state.uri.path;

      // Skip showing the notification banner if user is already on the Instagram view
      if (currentPath == '/instagram') {
        return;
      }

      // Deduplicate to avoid repeating alerts for the same message content
      if (sender != _lastSender || message != _lastText) {
        _lastSender = sender;
        _lastText = message;

        if (mounted) {
          InstagramNotificationOverlay.show(
            context,
            sender: sender,
            message: message,
            onTap: () {
              context.go('/instagram');
            },
          );
        }
      }
    } catch (e) {
      debugPrint('[InstagramBackground] Error handling msg: $e');
    }
  }

  @override
  void dispose() {
    _sessionCheckTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isAndroid = !kIsWeb && Platform.isAndroid;
    if (!isAndroid || _controller == null) {
      return const SizedBox.shrink();
    }

    return Positioned(
      left: -20,
      top: -20,
      width: 1,
      height: 1,
      child: Visibility(
        visible: false,
        maintainState: true,
        child: SizedBox(
          width: 1,
          height: 1,
          child: WebViewWidget(controller: _controller!),
        ),
      ),
    );
  }
}
