import 'package:universal_io/io.dart';
import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:oasis/services/media_download_service.dart';
import 'package:screen_protector/screen_protector.dart';
import 'package:oasis/features/messages/data/messaging_service.dart';

class ImagePreviewScreen extends StatefulWidget {
  final String imageUrl;
  final String? caption;
  final String? messageId;
  final String mediaViewMode;

  const ImagePreviewScreen({
    super.key,
    required this.imageUrl,
    this.caption,
    this.messageId,
    this.mediaViewMode = 'unlimited',
  });

  @override
  State<ImagePreviewScreen> createState() => _ImagePreviewScreenState();
}

class _ImagePreviewScreenState extends State<ImagePreviewScreen> {
  final MediaDownloadService _mediaDownloadService = MediaDownloadService();
  final MessagingService _messagingService = MessagingService();
  bool _isRestricted = false;

  @override
  void initState() {
    super.initState();
    _isRestricted = widget.mediaViewMode == 'once' || widget.mediaViewMode == 'twice';

    if (_isRestricted) {
      _enableProtection();
      _trackView();
    }
  }

  Future<void> _enableProtection() async {
    await ScreenProtector.preventScreenshotOn();
  }

  Future<void> _disableProtection() async {
    await ScreenProtector.preventScreenshotOff();
  }

  Future<void> _trackView() async {
    if (widget.messageId != null) {
      await _messagingService.incrementMediaViewCount(widget.messageId!);
    }
  }

  @override
  void dispose() {
    if (_isRestricted) {
      _disableProtection();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool isLocal = !widget.imageUrl.startsWith('http');

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (!_isRestricted)
            IconButton(
              icon: const Icon(Icons.download),
              onPressed: () {
                if (isLocal) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Image is already saved locally.')),
                  );
                } else {
                  _mediaDownloadService.downloadImage(
                    widget.imageUrl,
                    context,
                  );
                }
              },
            ),
        ],
      ),
      body: Stack(
        children: [
          PhotoView(
            imageProvider: isLocal 
                ? FileImage(File(widget.imageUrl)) as ImageProvider
                : CachedNetworkImageProvider(widget.imageUrl),
            minScale: PhotoViewComputedScale.contained,
            maxScale: PhotoViewComputedScale.covered * 2,
            backgroundDecoration: const BoxDecoration(color: Colors.black),
            errorBuilder: (context, error, stackTrace) => Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.broken_image_rounded, color: Colors.white54, size: 64),
                  const SizedBox(height: 16),
                  Text(
                    'Image not available',
                    style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white54),
                  ),
                ],
              ),
            ),
          ),
          if (widget.caption != null && widget.caption!.isNotEmpty)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.8),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Text(
                  widget.caption!,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
