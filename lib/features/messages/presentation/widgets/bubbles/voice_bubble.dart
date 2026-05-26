import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:oasis/widgets/messages/voice_message_player.dart';
import 'package:oasis/services/voice_transcript_service.dart';
import 'package:oasis/services/media_cache_service.dart';
import 'package:oasis/features/messages/data/chat_media_service.dart';
import 'package:oasis/features/messages/domain/models/message.dart';

class VoiceBubble extends StatefulWidget {
  const VoiceBubble({
    super.key,
    required this.message,
    required this.isMe,
    this.textColor,
  });

  final Message message;
  final bool isMe;
  final Color? textColor;

  @override
  State<VoiceBubble> createState() => _VoiceBubbleState();
}

class _VoiceBubbleState extends State<VoiceBubble> {
  final MediaCacheService _cacheService = MediaCacheService();
  final ChatMediaService _chatMediaService = ChatMediaService();

  VoiceTranscript? _transcript;
  bool _isTranscribing = false;
  String? _localPath;
  bool _isDownloading = false;

  @override
  void initState() {
    super.initState();
    _checkCache();
    if (!widget.message.isUploading) {
      _loadTranscript();
    }
  }

  @override
  void didUpdateWidget(VoiceBubble oldWidget) {
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

      final path = await _chatMediaService.downloadAndDecryptMedia(
        remoteUrl: url,
        type: 'recordings',
        fileId: widget.message.id,
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
      debugPrint('[VoiceBubble] Download Error: $e');
      if (mounted) {
        setState(() => _isDownloading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to download audio: $e')));
      }
    }
  }

  Future<void> _loadTranscript() async {
    final service = context.read<VoiceTranscriptService>();
    final transcript = await service.getTranscript(widget.message.id);
    if (mounted) {
      setState(() {
        _transcript = transcript;
      });
    }
  }

  Future<void> _transcribe() async {
    if (_localPath == null) {
      await _downloadMedia();
      if (_localPath == null) return;
    }

    setState(() => _isTranscribing = true);
    try {
      final service = context.read<VoiceTranscriptService>();
      final transcript = await service.transcribeVoiceMessage(
        widget.message.id,
        _localPath!,
      );
      if (mounted) {
        setState(() {
          _transcript = transcript;
          _isTranscribing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isTranscribing = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Transcription failed: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final color =
        widget.textColor ??
        (widget.isMe ? colorScheme.onPrimaryContainer : colorScheme.onSurface);

    final isEncrypted =
        widget.message.shareData?['media_keys'] != null &&
        widget.message.shareData?['media_iv'] != null;

    if (widget.message.isUploading || (_localPath == null && isEncrypted)) {
      return Container(
        width: 200,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: widget.isMe
              ? Colors.black.withValues(alpha: 0.1)
              : colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.mic_rounded, color: color, size: 24),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        height: 2,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(1),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (widget.message.isUploading) ...[
                  LinearProgressIndicator(
                    value: widget.message.uploadProgress,
                    backgroundColor: color.withValues(alpha: 0.1),
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                    minHeight: 2,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Sending... ${(widget.message.uploadProgress * 100).toInt()}%',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: color.withValues(alpha: 0.7),
                    ),
                  ),
                ] else if (_localPath == null && isEncrypted) ...[
                  InkWell(
                    onTap: _downloadMedia,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _isDownloading
                              ? const SizedBox(
                                  width: 12,
                                  height: 12,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Icon(Icons.download, size: 14, color: color),
                          const SizedBox(width: 6),
                          Text(
                            _isDownloading
                                ? 'Downloading...'
                                : 'Download Voice',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: color,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
            if (widget.message.isUploading)
              Positioned.fill(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
                  child: Container(color: Colors.transparent),
                ),
              ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: widget.isMe
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        VoiceMessagePlayer(
          audioUrl: _localPath!,
          duration: widget.message.voiceDuration,
          isMe: widget.isMe,
          color: color,
        ),
        if (_transcript != null)
          Container(
            margin: const EdgeInsets.only(top: 8, left: 8, right: 8),
            padding: const EdgeInsets.all(12),
            constraints: const BoxConstraints(maxWidth: 250),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withValues(alpha: 0.1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _transcript!.text,
                  textDirection: _transcript!.isRTL
                      ? TextDirection.rtl
                      : TextDirection.ltr,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: color.withValues(alpha: 0.8),
                    fontStyle: FontStyle.italic,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      _transcript!.language.toUpperCase(),
                      style: TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                        color: color.withValues(alpha: 0.4),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 12, right: 12),
            child: InkWell(
              onTap: _isTranscribing ? null : _transcribe,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_isTranscribing)
                      const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.grey,
                          ),
                        ),
                      )
                    else
                      Icon(
                        Icons.translate_rounded,
                        size: 12,
                        color: color.withValues(alpha: 0.5),
                      ),
                    const SizedBox(width: 6),
                    Text(
                      _isTranscribing ? 'Transcribing...' : 'Transcribe',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: color.withValues(alpha: 0.5),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
