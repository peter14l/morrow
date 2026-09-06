import 'package:flutter/material.dart';
import 'package:oasis/services/media_cache_service.dart';
import 'package:oasis/features/messages/data/chat_media_service.dart';
import 'package:oasis/features/messages/domain/models/message.dart';
import 'package:open_filex/open_filex.dart';

import 'package:oasis/widgets/spoiler_widget.dart';

class DocumentBubble extends StatefulWidget {
  const DocumentBubble({
    super.key,
    required this.message,
    required this.isMe,
    this.textColor,
  });

  final Message message;
  final bool isMe;
  final Color? textColor;

  @override
  State<DocumentBubble> createState() => _DocumentBubbleState();
}

class _DocumentBubbleState extends State<DocumentBubble> {
  final MediaCacheService _cacheService = MediaCacheService();
  final ChatMediaService _chatMediaService = ChatMediaService();

  String? _localPath;
  bool _isDownloading = false;

  @override
  void initState() {
    super.initState();
    _checkCache();
    MediaCacheService.cacheVersion.addListener(_checkCache);
  }

  @override
  void dispose() {
    MediaCacheService.cacheVersion.removeListener(_checkCache);
    super.dispose();
  }

  @override
  void didUpdateWidget(DocumentBubble oldWidget) {
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
          widget.message.shareData?['media_keys'] as Map<String, dynamic>? ??
          (widget.message.encryptedKeys != null
              ? Map<String, dynamic>.from(widget.message.encryptedKeys!)
              : null);
      final iv = widget.message.shareData?['media_iv'] as String? ??
          widget.message.iv;

      if (encryptedKeys == null || iv == null) {
        throw Exception('Encryption metadata missing in message');
      }

      final path = await _chatMediaService.downloadAndDecryptMedia(
        remoteUrl: url,
        iv: iv,
        encryptedKeys: encryptedKeys,
        senderId: widget.message.senderId,
      );

      if (mounted) {
        setState(() {
          _localPath = path;
          _isDownloading = false;
        });
      }
    } catch (e) {
      debugPrint('[DocumentBubble] Download Error: $e');
      if (mounted) {
        setState(() => _isDownloading = false);
      }
    }
  }

  Future<void> _openFile() async {
    if (_localPath == null) return;
    try {
      await OpenFilex.open(_localPath!);
    } catch (e) {
      debugPrint('Error opening file: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not open file: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final fileName = widget.message.mediaFileName ?? 'File';
    final extension = fileName.split('.').last.toLowerCase();

    // Determine icon and color based on extension
    IconData fileIcon = Icons.insert_drive_file;
    Color iconColor = widget.isMe ? Colors.white : colorScheme.onSurfaceVariant;

    if (!widget.isMe) {
      if (extension == 'pdf') {
        fileIcon = Icons.picture_as_pdf;
        iconColor = Colors.red;
      } else if (extension == 'doc' || extension == 'docx') {
        fileIcon = Icons.description;
        iconColor = Colors.blue;
      } else if (extension == 'xls' ||
          extension == 'xlsx' ||
          extension == 'csv') {
        fileIcon = Icons.grid_on;
        iconColor = Colors.green;
      } else if (extension == 'ppt' || extension == 'pptx') {
        fileIcon = Icons.slideshow;
        iconColor = Colors.orange;
      }
    }

    final color =
        widget.textColor ??
        (widget.isMe
            ? theme.colorScheme.onPrimaryContainer
            : theme.colorScheme.onSurface);

    final encryptedKeys =
        widget.message.shareData?['media_keys'] as Map<String, dynamic>? ??
        (widget.message.encryptedKeys != null
            ? Map<String, dynamic>.from(widget.message.encryptedKeys!)
            : null);
    final iv = widget.message.shareData?['media_iv'] as String? ??
        widget.message.iv;
    final isEncrypted = encryptedKeys != null && iv != null;

    final Widget mainContent = InkWell(
      onTap: _localPath != null || !isEncrypted ? _openFile : null,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 250,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: widget.isMe
              ? Colors.black.withValues(alpha: 0.1)
              : colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: widget.isMe
                        ? Colors.white.withValues(alpha: 0.2)
                        : iconColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    fileIcon,
                    color: widget.isMe ? Colors.white : iconColor,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fileName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: color,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            extension.toUpperCase(),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: color.withValues(alpha: 0.7),
                            ),
                          ),
                          if (widget.message.mediaFileSize != null) ...[
                            Text(
                              ' • ',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: color.withValues(alpha: 0.7),
                              ),
                            ),
                            Text(
                              Message.formatBytes(
                                widget.message.mediaFileSize,
                              ),
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: color.withValues(alpha: 0.7),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (widget.message.isUploading) ...[
              const SizedBox(height: 4),
              LinearProgressIndicator(
                value: widget.message.uploadProgress,
                backgroundColor: color.withValues(alpha: 0.1),
                valueColor: AlwaysStoppedAnimation<Color>(color),
                minHeight: 2,
              ),
              const SizedBox(height: 4),
              Center(
                child: Text(
                  'Uploading... ${(widget.message.uploadProgress * 100).toInt()}%',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: color.withValues(alpha: 0.7),
                  ),
                ),
              ),
            ] else if (_localPath == null && isEncrypted) ...[
              Divider(height: 1, color: color.withValues(alpha: 0.1)),

              InkWell(
                onTap: _downloadMedia,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _isDownloading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(Icons.download, size: 16, color: color),
                      const SizedBox(width: 8),
                      Text(
                        _isDownloading ? 'Downloading...' : 'Download',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: color,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ] else ...[
              Divider(height: 1, color: color.withValues(alpha: 0.1)),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.remove_red_eye, size: 16, color: color),
                    const SizedBox(width: 8),
                    Text(
                      'View',
                      style: theme.textTheme.labelLarge?.copyWith(color: color),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );

    if (widget.message.isSpoiler) {
      return SpoilerWidget(child: mainContent);
    }
    return mainContent;
  }
}
