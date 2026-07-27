import 'package:universal_io/io.dart';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:oasis/features/messages/presentation/screens/image_preview_screen.dart';
import 'package:oasis/features/messages/presentation/widgets/bubbles/text_bubble.dart';
import 'package:provider/provider.dart';
import 'package:oasis/features/messages/presentation/providers/chat_provider.dart';
import 'package:oasis/services/media_cache_service.dart';
import 'package:oasis/features/messages/data/chat_media_service.dart';
import 'package:oasis/features/messages/domain/models/message.dart';
import 'package:oasis/widgets/spoiler_widget.dart';

class ImageBubble extends StatefulWidget {
  const ImageBubble({
    super.key,
    required this.message,
    required this.isMe,
    this.textColor,
  });

  final Message message;
  final bool isMe;
  final Color? textColor;

  @override
  State<ImageBubble> createState() => _ImageBubbleState();
}

class _ImageBubbleState extends State<ImageBubble> {
  final MediaCacheService _cacheService = MediaCacheService();
  final ChatMediaService _chatMediaService = ChatMediaService();

  String? _localPath;
  bool _isDownloading = false;

  @override
  void initState() {
    super.initState();
    _checkCache();
  }

  @override
  void didUpdateWidget(ImageBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.message.mediaUrl != widget.message.mediaUrl) {
      _checkCache();
    }
  }

  Future<void> _checkCache() async {
    final url = widget.message.mediaUrl;
    if (url == null) return;

    if (!url.startsWith('http')) {
      setState(() => _localPath = url);
      return;
    }

    final path = await _cacheService.getLocalPath(url);
    if (mounted) {
      setState(() => _localPath = path);
    }
  }

  Future<void> _downloadMedia() async {
    final url = widget.message.mediaUrl;
    if (url == null || _isDownloading) return;

    setState(() => _isDownloading = true);

    try {
      final encryptedKeys =
          widget.message.shareData?['media_keys'] as Map<String, dynamic>?;
      final iv = widget.message.shareData?['media_iv'] as String?;

      if (encryptedKeys == null || iv == null) {
        throw Exception('Encryption metadata missing in message');
      }

      // We need a fileId. We can derive it from the URL or use a random one.
      // The original upload used a timestamped UUID. For download, we can use the message ID.
      final fileId = widget.message.id;

      final path = await _chatMediaService.downloadAndDecryptMedia(
        remoteUrl: url,
        type: 'images',
        fileId: fileId,
        iv: iv,
        encryptedKeys: encryptedKeys,
      );

      if (mounted) {
        setState(() {
          _localPath = path;
          _isDownloading = false;
        });
      }
    } catch (e) {
      debugPrint('[ImageBubble] Download Error: $e');
      if (mounted) {
        setState(() => _isDownloading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Download failed: $e')));
      }
    }
  }

  bool get _isRestricted =>
      widget.message.mediaViewMode == 'once' ||
      widget.message.mediaViewMode == 'twice';
  int get _viewLimit => widget.message.mediaViewMode == 'once' ? 1 : 2;
  bool get _isViewed =>
      _isRestricted && widget.message.currentUserViewCount >= _viewLimit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color =
        widget.textColor ??
        (widget.isMe
            ? theme.colorScheme.onPrimaryContainer
            : theme.colorScheme.onSurface);

    if (_isRestricted) {
      return _buildRestrictedUI(theme);
    }

    final Widget mainContent = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: (widget.message.isUploading || _localPath == null)
              ? null
              : () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => ImagePreviewScreen(
                        imageUrl: _localPath!,
                        caption:
                            MessageTextUtils.isDisplayableCaption(
                              widget.message.content,
                            )
                            ? widget.message.content
                            : null,
                      ),
                    ),
                  );
                },
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 300, maxWidth: 300),
              child: _buildImage(context, theme),
            ),
          ),
        ),
        if (MessageTextUtils.isDisplayableCaption(widget.message.content))
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              widget.message.content.trim(),
              style: theme.textTheme.bodyMedium?.copyWith(color: color),
            ),
          ),
      ],
    );

    if (widget.message.isSpoiler) {
      return SpoilerWidget(child: mainContent);
    }

    return mainContent;
  }

  Widget _buildRestrictedUI(ThemeData theme) {
    return GestureDetector(
      onTap: _isViewed || _localPath == null
          ? (_localPath == null ? _downloadMedia : null)
          : () async {
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => ImagePreviewScreen(
                    imageUrl: _localPath!,
                    caption:
                        MessageTextUtils.isDisplayableCaption(
                          widget.message.content,
                        )
                        ? widget.message.content
                        : null,
                    messageId: widget.message.id,
                    mediaViewMode: widget.message.mediaViewMode,
                  ),
                ),
              );
              if (context.mounted) {
                context.read<ChatProvider>().incrementLocalMediaViewCount(
                  widget.message.id,
                );
              }
            },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: widget.isMe
                  ? Colors.white.withValues(alpha: 0.2)
                  : theme.colorScheme.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _localPath == null
                  ? Icons.download_rounded
                  : Icons.camera_alt_rounded,
              size: 20,
              color: _isViewed
                  ? (widget.isMe ? Colors.white54 : Colors.grey)
                  : (widget.isMe ? Colors.white : theme.colorScheme.primary),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            _isViewed
                ? 'Opened'
                : (_localPath == null ? 'Download Photo' : 'Photo'),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: _isViewed
                  ? (widget.isMe ? Colors.white54 : Colors.grey)
                  : (widget.isMe ? Colors.white : theme.colorScheme.onSurface),
              fontWeight: _isViewed ? FontWeight.normal : FontWeight.w600,
            ),
          ),
          const SizedBox(width: 8),
          if (_isDownloading)
            const SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
        ],
      ),
    );
  }

  Widget _buildImage(BuildContext context, ThemeData theme) {
    final url = widget.message.mediaUrl;
    final isEncrypted =
        widget.message.shareData?['media_keys'] != null &&
        widget.message.shareData?['media_iv'] != null;

    return Stack(
      alignment: Alignment.center,
      children: [
        if (_localPath != null)
          Image.file(
            File(_localPath!),
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) =>
                const Icon(Icons.broken_image),
          )
        else if (url != null)
          isEncrypted
              ? Stack(
                  alignment: Alignment.center,
                  children: [
                    // Blurred placeholder
                    CachedNetworkImage(
                      imageUrl: url,
                      imageBuilder: (context, imageProvider) => Container(
                        decoration: BoxDecoration(
                          image: DecorationImage(
                            image: imageProvider,
                            fit: BoxFit.cover,
                          ),
                        ),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                          child: Container(
                            color: Colors.black.withValues(alpha: 0.1),
                          ),
                        ),
                      ),
                      placeholder: (context, url) =>
                          Container(color: Colors.grey[300]),
                      errorWidget: (context, url, error) =>
                          Container(color: Colors.grey[300]),
                    ),
                    if (_isDownloading)
                      const CircularProgressIndicator()
                    else
                      IconButton(
                        icon: const Icon(
                          Icons.download_for_offline,
                          size: 48,
                          color: Colors.white,
                        ),
                        onPressed: _downloadMedia,
                      ),
                  ],
                )
              : CachedNetworkImage(
                  imageUrl: url,
                  fit: BoxFit.cover,
                  placeholder: (context, url) =>
                      Container(color: Colors.grey[300]),
                  errorWidget: (context, url, error) =>
                      Container(color: Colors.grey[300]),
                )
        else
          Container(
            color: Colors.grey[300],
            child: const Icon(Icons.broken_image),
          ),

        if (widget.message.isUploading) ...[
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                color: Colors.black.withValues(alpha: 0.3),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${(widget.message.uploadProgress * 100).toInt()}%',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: LinearProgressIndicator(
              value: widget.message.uploadProgress,
              backgroundColor: Colors.white24,
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              minHeight: 4,
            ),
          ),
        ],
      ],
    );
  }
}
