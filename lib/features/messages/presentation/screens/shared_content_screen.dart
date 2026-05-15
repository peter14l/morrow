import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:oasis/features/messages/domain/models/message.dart';
import 'package:oasis/services/media_download_service.dart';
import 'package:oasis/services/auth_service.dart';

class SharedContentScreen extends StatefulWidget {
  final String conversationId;
  final String otherUserName;
  final List<Message> messages;

  const SharedContentScreen({
    super.key,
    required this.conversationId,
    required this.otherUserName,
    required this.messages,
  });

  @override
  State<SharedContentScreen> createState() => _SharedContentScreenState();
}

class _SharedContentScreenState extends State<SharedContentScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final MediaDownloadService _downloadService = MediaDownloadService();
  final urlRegExp = RegExp(r'(https?:\/\/[^\s]+)', caseSensitive: false);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<Message> _getMediaMessages(List<Message> messages) {
    return messages
        .where(
          (m) =>
              (m.messageType == MessageType.image ||
                  m.messageType == MessageType.ripple) &&
              m.mediaUrl != null,
        )
        .toList();
  }

  List<Message> _getFileMessages(List<Message> messages) {
    return messages
        .where(
          (m) => m.messageType == MessageType.document && m.mediaUrl != null,
        )
        .toList();
  }

  List<Map<String, dynamic>> _getLinks(List<Message> messages) {
    final List<Map<String, dynamic>> links = [];
    for (final m in messages) {
      if (m.messageType == MessageType.text ||
          m.messageType == MessageType.ripple) {
        final matches = urlRegExp.allMatches(m.content);
        for (final match in matches) {
          links.add({
            'url': match.group(0),
            'timestamp': m.timestamp,
            'senderName': m.senderName,
          });
        }
      }
    }
    // Sort links by timestamp descending
    links.sort(
      (a, b) =>
          (b['timestamp'] as DateTime).compareTo(a['timestamp'] as DateTime),
    );
    return links;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final messages = widget.messages;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: Text(
          'Media, Files & Links',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(FluentIcons.chevron_left_24_regular),
          onPressed: () => Navigator.pop(context),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 80),
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildMediaGrid(_getMediaMessages(messages)),
                _buildFilesList(_getFileMessages(messages)),
                _buildLinksList(_getLinks(messages)),
              ],
            ),
          ),
          Positioned(
            top: 10,
            left: 16,
            right: 16,
            child: _buildFloatingTabBar(theme, colorScheme),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingTabBar(ThemeData theme, ColorScheme colorScheme) {
    final isM3 = theme.useMaterial3;

    return Container(
      height: 54,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(27),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: colorScheme.primary,
          borderRadius: BorderRadius.circular(23),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: colorScheme.onPrimary,
        unselectedLabelColor: colorScheme.onSurfaceVariant,
        labelStyle: theme.textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.bold,
          letterSpacing: 0.2,
        ),
        unselectedLabelStyle: theme.textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w500,
        ),
        padding: const EdgeInsets.all(4),
        tabs: const [
          Tab(text: 'Media'),
          Tab(text: 'Files'),
          Tab(text: 'Links'),
        ],
      ),
    );
  }

  Widget _buildMediaGrid(List<Message> mediaMessages) {
    if (mediaMessages.isEmpty) {
      return _buildEmptyState(
        FluentIcons.image_24_regular,
        'No shared media yet',
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: mediaMessages.length,
      itemBuilder: (context, index) {
        final msg = mediaMessages[index];
        return GestureDetector(
          onTap: () {
            // Show full screen image/video if needed
          },
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Stack(
              fit: StackFit.expand,
              children: [
                CachedNetworkImage(
                  imageUrl: msg.mediaUrl!,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    color: Theme.of(context).colorScheme.surfaceContainer,
                  ),
                  errorWidget: (context, url, error) => Container(
                    color: Theme.of(context).colorScheme.errorContainer,
                    child: const Icon(FluentIcons.error_circle_24_regular),
                  ),
                ),
                if (msg.messageType == MessageType.ripple)
                  const Center(
                    child: Icon(
                      FluentIcons.play_24_filled,
                      color: Colors.white70,
                      size: 32,
                    ),
                  ),
                Positioned(
                  bottom: 4,
                  right: 4,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: GestureDetector(
                      onTap: () async {
                        final currentUserId = AuthService().currentUser?.id;
                        final isOwn = msg.senderId == currentUserId;
                        if (msg.messageType == MessageType.ripple) {
                          await _downloadService.downloadVideo(
                            msg.mediaUrl!,
                            context,
                            isOwnContent: isOwn,
                          );
                        } else {
                          await _downloadService.downloadImage(
                            msg.mediaUrl!,
                            context,
                            isOwnContent: isOwn,
                          );
                        }
                      },
                      child: const Icon(
                        FluentIcons.arrow_download_16_regular,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFilesList(List<Message> fileMessages) {
    if (fileMessages.isEmpty) {
      return _buildEmptyState(
        FluentIcons.document_24_regular,
        'No shared files yet',
      );
    }

    final colorScheme = Theme.of(context).colorScheme;

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: fileMessages.length,
      itemBuilder: (context, index) {
        final msg = fileMessages[index];
        final fileName = msg.mediaFileName ?? 'File ${index + 1}';
        final fileSize = Message.formatBytes(msg.mediaFileSize);

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
          child: ListTile(
            leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(_getFileIcon(fileName), color: colorScheme.primary),
            ),
            title: Text(
              fileName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              fileSize,
              style: TextStyle(
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                fontSize: 12,
              ),
            ),
            trailing: IconButton(
              icon: const Icon(FluentIcons.arrow_download_24_regular),
              onPressed: () async {
                final currentUserId = AuthService().currentUser?.id;
                final isOwn = msg.senderId == currentUserId;
                await _downloadService.downloadDocument(
                  msg.mediaUrl!,
                  fileName,
                  context,
                  isOwnContent: isOwn,
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildLinksList(List<Map<String, dynamic>> links) {
    if (links.isEmpty) {
      return _buildEmptyState(
        FluentIcons.link_24_regular,
        'No shared links yet',
      );
    }

    final colorScheme = Theme.of(context).colorScheme;

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: links.length,
      itemBuilder: (context, index) {
        final link = links[index];
        final url = link['url'] as String;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
          child: ListTile(
            leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: colorScheme.secondary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                FluentIcons.link_24_regular,
                color: colorScheme.secondary,
              ),
            ),
            title: Text(
              url,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
            subtitle: Text(
              'Shared by ${link['senderName']}',
              style: TextStyle(
                fontSize: 11,
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
              ),
            ),
            trailing: const Icon(FluentIcons.open_24_regular, size: 20),
            onTap: () async {
              final uri = Uri.parse(url);
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(IconData icon, String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 64,
            color: Theme.of(
              context,
            ).colorScheme.onSurfaceVariant.withValues(alpha: 0.2),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              color: Theme.of(
                context,
              ).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getFileIcon(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    switch (ext) {
      case 'pdf':
        return FluentIcons.document_pdf_24_regular;
      case 'doc':
      case 'docx':
        return FluentIcons.document_24_regular;
      case 'xls':
      case 'xlsx':
        return FluentIcons.grid_24_regular;
      case 'ppt':
      case 'pptx':
        return FluentIcons.document_24_regular;
      case 'zip':
      case 'rar':
      case '7z':
        return FluentIcons.archive_24_regular;
      case 'mp3':
      case 'wav':
      case 'm4a':
        return FluentIcons.music_note_2_24_regular;
      default:
        return FluentIcons.document_24_regular;
    }
  }
}
