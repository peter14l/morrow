import 'dart:async';
import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';

class InstagramNotificationOverlay {
  static OverlayEntry? _currentEntry;
  static Timer? _dismissTimer;

  static void show(
    BuildContext context, {
    required String sender,
    required String message,
    required VoidCallback onTap,
  }) {
    _dismissTimer?.cancel();
    if (_currentEntry != null) {
      _currentEntry!.remove();
      _currentEntry = null;
    }

    final overlayState = Overlay.of(context);

    _currentEntry = OverlayEntry(
      builder: (context) {
        return Positioned(
          top: MediaQuery.of(context).padding.top + 12,
          left: 16,
          right: 16,
          child: SafeArea(
            top: false,
            bottom: false,
            child: Material(
              color: Colors.transparent,
              child: Dismissible(
                key: const ValueKey('insta_notif'),
                direction: DismissDirection.up,
                onDismissed: (_) {
                  _dismissTimer?.cancel();
                  _currentEntry = null;
                },
                child: _InstagramNotificationBanner(
                  sender: sender,
                  message: message,
                  onTap: () {
                    _dismissTimer?.cancel();
                    _currentEntry?.remove();
                    _currentEntry = null;
                    onTap();
                  },
                  onDismiss: () {
                    _dismissTimer?.cancel();
                    _currentEntry?.remove();
                    _currentEntry = null;
                  },
                ),
              ),
            ),
          ),
        );
      },
    );

    overlayState.insert(_currentEntry!);
    _dismissTimer = Timer(const Duration(seconds: 4), () {
      if (_currentEntry != null) {
        _currentEntry!.remove();
        _currentEntry = null;
      }
    });
  }
}

class _InstagramNotificationBanner extends StatefulWidget {
  final String sender;
  final String message;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  const _InstagramNotificationBanner({
    required this.sender,
    required this.message,
    required this.onTap,
    required this.onDismiss,
  });

  @override
  State<_InstagramNotificationBanner> createState() =>
      __InstagramNotificationBannerState();
}

class __InstagramNotificationBannerState
    extends State<_InstagramNotificationBanner> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _slideAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );

    _slideAnimation = Tween<double>(begin: -1.0, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0.0, _slideAnimation.value * 100),
          child: Opacity(
            opacity: _opacityAnimation.value,
            child: child,
          ),
        );
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFF833AB4).withValues(alpha: 0.85), // Instagram Purple
                const Color(0xFFFD1D1D).withValues(alpha: 0.85), // Instagram Red
                const Color(0xFFF77737).withValues(alpha: 0.85), // Instagram Orange
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.2),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: Row(
              children: [
                // Instagram Icon container
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    FluentIcons.chat_warning_24_regular,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                // Message Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            widget.sender,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const Text(
                            'Instagram',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 10,
                              fontWeight: FontWeight.w300,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.message,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Dismiss action
                IconButton(
                  icon: const Icon(
                    FluentIcons.dismiss_20_regular,
                    color: Colors.white70,
                    size: 18,
                  ),
                  onPressed: widget.onDismiss,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
